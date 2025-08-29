"""
Spotify Token Refresh Background Service

Proactively refreshes Spotify tokens before they expire to ensure uninterrupted
service during training sessions. Runs as a scheduled background job.
"""

import asyncio
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
import spotipy
from spotipy.oauth2 import SpotifyOAuth
import httpx

from app.core.config import settings
from app.core.logging_config import get_logger
from app.services.firebase_client import firebase_client, FirebaseError

logger = get_logger(__name__)

class TokenRefreshStats:
    """Statistics tracking for token refresh operations"""
    
    def __init__(self):
        self.total_refreshes = 0
        self.successful_refreshes = 0
        self.failed_refreshes = 0
        self.invalid_tokens_cleaned = 0
        self.retry_attempts = 0
        self.last_run_time: Optional[datetime] = None
        self.last_error: Optional[str] = None
        self.tokens_checked = 0
        self.tokens_requiring_refresh = 0
    
    def reset_run_stats(self):
        """Reset stats for current run"""
        self.tokens_checked = 0
        self.tokens_requiring_refresh = 0
        self.last_error = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert stats to dictionary for API responses"""
        return {
            "total_refreshes": self.total_refreshes,
            "successful_refreshes": self.successful_refreshes,
            "failed_refreshes": self.failed_refreshes,
            "invalid_tokens_cleaned": self.invalid_tokens_cleaned,
            "retry_attempts": self.retry_attempts,
            "last_run_time": self.last_run_time.isoformat() if self.last_run_time else None,
            "last_error": self.last_error,
            "tokens_checked_last_run": self.tokens_checked,
            "tokens_requiring_refresh_last_run": self.tokens_requiring_refresh,
            "success_rate": (
                self.successful_refreshes / self.total_refreshes 
                if self.total_refreshes > 0 else 0
            )
        }

class SpotifyTokenRefreshService:
    """
    Background service for proactive Spotify token refresh
    
    Runs every 15 minutes to refresh tokens that will expire within 45 minutes,
    ensuring continuous service during training sessions. Failed refreshes are
    automatically retried after 5 minutes.
    """
    
    def __init__(self):
        self.scheduler: Optional[AsyncIOScheduler] = None
        self.stats = TokenRefreshStats()
        self.is_running = False
        
        # Track failed refresh attempts for retry logic
        self.failed_devices: Dict[str, datetime] = {}  # device_id -> failure_time
        
        # Spotify OAuth setup for token refresh
        self.spotify_oauth = SpotifyOAuth(
            client_id=settings.SPOTIFY_CLIENT_ID,
            client_secret=settings.SPOTIFY_CLIENT_SECRET,
            redirect_uri=settings.SPOTIFY_REDIRECT_URI,
            scope=None  # Not needed for token refresh
        )
    
    def start_scheduler(self):
        """Start the background scheduler"""
        
        if self.scheduler is not None:
            logger.warning("Token refresh scheduler already started")
            return
        
        logger.info("Starting Spotify token refresh scheduler")
        
        self.scheduler = AsyncIOScheduler()
        
        # Schedule token refresh every 15 minutes
        self.scheduler.add_job(
            func=self._refresh_expiring_tokens,
            trigger=IntervalTrigger(minutes=15),
            id="spotify_token_refresh",
            name="Spotify Token Refresh",
            max_instances=1,  # Prevent overlapping runs
            coalesce=True,    # Merge missed runs
            misfire_grace_time=300  # 5 minutes grace for missed runs
        )
        
        self.scheduler.start()
        logger.info("Token refresh scheduler started successfully")
    
    def _schedule_retry(self, device_id: str):
        """
        Schedule a retry attempt for a failed device refresh after 5 minutes
        
        Args:
            device_id: Device that failed to refresh
        """
        
        if not self.scheduler:
            logger.warning("Cannot schedule retry - scheduler not running")
            return
        
        retry_job_id = f"retry_refresh_{device_id}"
        
        # Remove existing retry job if present
        try:
            self.scheduler.remove_job(retry_job_id)
        except:
            pass  # Job doesn't exist, that's fine
        
        # Schedule retry in 5 minutes
        retry_time = datetime.now() + timedelta(minutes=5)
        
        self.scheduler.add_job(
            func=self._retry_single_device,
            trigger="date",
            run_date=retry_time,
            args=[device_id],
            id=retry_job_id,
            name=f"Retry Token Refresh - {device_id}",
            max_instances=1
        )
        
        logger.info(
            "Scheduled token refresh retry",
            device_id=device_id,
            retry_time=retry_time.isoformat()
        )
    
    def stop_scheduler(self):
        """Stop the background scheduler"""
        
        if self.scheduler is None:
            logger.warning("Token refresh scheduler not running")
            return
        
        logger.info("Stopping Spotify token refresh scheduler")
        self.scheduler.shutdown(wait=True)
        self.scheduler = None
        logger.info("Token refresh scheduler stopped")
    
    async def _retry_single_device(self, device_id: str):
        """
        Retry token refresh for a single device that previously failed
        
        Args:
            device_id: Device to retry refresh for
        """
        
        logger.info("Retrying token refresh for device", device_id=device_id)
        
        try:
            # Get current token data
            token_data = await firebase_client.get_spotify_tokens(device_id)
            
            if not token_data:
                logger.warning("No token data found for retry", device_id=device_id)
                # Remove from failed devices since token doesn't exist
                self.failed_devices.pop(device_id, None)
                return
            
            # Attempt refresh
            await self._refresh_single_token(device_id, token_data)
            
            # Success - remove from failed devices and update stats
            self.failed_devices.pop(device_id, None)
            self.stats.retry_attempts += 1
            
            logger.info("Token refresh retry successful", device_id=device_id)
            
        except Exception as e:
            logger.error(
                "Token refresh retry failed",
                device_id=device_id,
                error=str(e)
            )
            
            # Don't schedule another retry to avoid infinite loops
            # The regular refresh cycle will pick it up again
            self.failed_devices.pop(device_id, None)
    
    async def _refresh_expiring_tokens(self):
        """
        Main background job: find and refresh tokens expiring within 45 minutes
        """
        
        if self.is_running:
            logger.warning("Token refresh job already running, skipping")
            return
        
        self.is_running = True
        self.stats.reset_run_stats()
        self.stats.last_run_time = datetime.utcnow()
        
        logger.info("Starting proactive token refresh cycle")
        
        try:
            # Get all tokens that need refreshing
            expiring_tokens = await self._find_expiring_tokens()
            
            if not expiring_tokens:
                logger.info("No tokens require refresh at this time")
                return
            
            logger.info(f"Found {len(expiring_tokens)} tokens requiring refresh")
            self.stats.tokens_requiring_refresh = len(expiring_tokens)
            
            # Refresh each token
            for device_id, token_data in expiring_tokens.items():
                try:
                    await self._refresh_single_token(device_id, token_data)
                    self.stats.successful_refreshes += 1
                    
                    # Remove from failed devices if previously failed
                    self.failed_devices.pop(device_id, None)
                    
                except Exception as e:
                    logger.error(
                        "Failed to refresh token for device",
                        device_id=device_id,
                        error=str(e)
                    )
                    self.stats.failed_refreshes += 1
                    
                    # Check if this is a retryable error (not invalid refresh token)
                    error_str = str(e).lower()
                    is_invalid_token = "invalid_grant" in error_str or "invalid refresh token" in error_str
                    
                    if not is_invalid_token:
                        # Track failed device and schedule retry
                        self.failed_devices[device_id] = datetime.utcnow()
                        self._schedule_retry(device_id)
                        
                        logger.info(
                            "Scheduled retry for failed token refresh",
                            device_id=device_id
                        )
                    else:
                        logger.info(
                            "Not scheduling retry for invalid refresh token",
                            device_id=device_id
                        )
                    
                self.stats.total_refreshes += 1
                
                # Small delay between refreshes to avoid rate limiting
                await asyncio.sleep(1)
            
            logger.info(
                "Token refresh cycle completed",
                successful=self.stats.successful_refreshes,
                failed=self.stats.failed_refreshes,
                total=self.stats.total_refreshes
            )
            
        except Exception as e:
            error_msg = f"Token refresh cycle failed: {str(e)}"
            logger.error("Token refresh cycle error", error=error_msg)
            self.stats.last_error = error_msg
            
        finally:
            self.is_running = False
    
    async def _find_expiring_tokens(self) -> Dict[str, Dict[str, Any]]:
        """
        Find all tokens that will expire within the next 45 minutes
        
        Returns:
            Dictionary mapping device_id to token data
        """
        
        try:
            # Query all spotify_tokens documents from Firebase
            async with httpx.AsyncClient(timeout=60.0) as client:
                url = f"https://firestore.googleapis.com/v1/projects/{settings.FIREBASE_PROJECT_ID}/databases/(default)/documents/spotify_tokens"
                params = {
                    "key": settings.FIREBASE_API_KEY,
                    "pageSize": 1000  # Adjust based on expected token count
                }
                
                response = await client.get(url, params=params)
                
                if response.status_code != 200:
                    logger.error("Failed to query tokens for refresh", status_code=response.status_code)
                    return {}
                
                documents = response.json().get("documents", [])
                self.stats.tokens_checked = len(documents)
                
                expiring_tokens = {}
                cutoff_time = datetime.utcnow() + timedelta(minutes=45)
                
                for doc in documents:
                    try:
                        # Extract device ID from document name
                        doc_name = doc.get("name", "")
                        device_id = doc_name.split("/")[-1]
                        
                        # Extract token data
                        fields = doc.get("fields", {})
                        expires_at_str = fields.get("expires_at", {}).get("timestampValue")
                        refresh_token = fields.get("refresh_token", {}).get("stringValue")
                        access_token = fields.get("access_token", {}).get("stringValue")
                        
                        if not all([expires_at_str, refresh_token, access_token]):
                            logger.warning(
                                "Token document missing required fields",
                                device_id=device_id
                            )
                            continue
                        
                        # Parse expiration time
                        expires_at = datetime.fromisoformat(expires_at_str.rstrip("Z"))
                        
                        # Check if token expires within 45 minutes
                        if expires_at <= cutoff_time:
                            expiring_tokens[device_id] = {
                                "access_token": access_token,
                                "refresh_token": refresh_token,
                                "expires_at": expires_at
                            }
                            
                            logger.debug(
                                "Token expires soon",
                                device_id=device_id,
                                expires_at=expires_at.isoformat(),
                                minutes_until_expiry=(expires_at - datetime.utcnow()).total_seconds() / 60
                            )
                        
                    except Exception as e:
                        logger.error(
                            "Error processing token document",
                            device_id=device_id if 'device_id' in locals() else "unknown",
                            error=str(e)
                        )
                        continue
                
                logger.info(
                    "Token expiration check completed",
                    total_tokens=len(documents),
                    expiring_tokens=len(expiring_tokens)
                )
                
                return expiring_tokens
                
        except Exception as e:
            logger.error("Failed to find expiring tokens", error=str(e))
            return {}
    
    async def _refresh_single_token(self, device_id: str, token_data: Dict[str, Any]):
        """
        Refresh a single Spotify token using spotipy
        
        Args:
            device_id: Device identifier
            token_data: Current token data including refresh_token
        """
        
        logger.info("Refreshing token for device", device_id=device_id)
        
        try:
            refresh_token = token_data["refresh_token"]
            
            # Use spotipy to refresh the token
            try:
                new_token_info = self.spotify_oauth.refresh_access_token(refresh_token)
                
                if not new_token_info or "access_token" not in new_token_info:
                    raise Exception("Invalid token response from Spotify")
                
                # Calculate new expiration time
                expires_in = new_token_info.get("expires_in", 3600)
                expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
                
                # Use the new refresh token if provided, otherwise keep the old one
                new_refresh_token = new_token_info.get("refresh_token", refresh_token)
                
                # Store updated tokens in Firebase
                await firebase_client.store_spotify_tokens(
                    device_id=device_id,
                    access_token=new_token_info["access_token"],
                    refresh_token=new_refresh_token,
                    expires_at=expires_at
                )
                
                logger.info(
                    "Token refreshed successfully",
                    device_id=device_id,
                    new_expires_at=expires_at.isoformat()
                )
                
            except spotipy.SpotifyException as e:
                # Handle Spotify API errors (e.g., invalid refresh token)
                if e.http_status == 400 and "invalid_grant" in str(e):
                    logger.warning(
                        "Refresh token invalid, cleaning up stored tokens",
                        device_id=device_id
                    )
                    
                    # Remove invalid tokens
                    await firebase_client.delete_spotify_tokens(device_id)
                    self.stats.invalid_tokens_cleaned += 1
                    
                    raise Exception(f"Invalid refresh token for device {device_id}, tokens cleaned up")
                else:
                    raise Exception(f"Spotify API error: {str(e)}")
            
        except FirebaseError as e:
            raise Exception(f"Firebase error during token refresh: {str(e)}")
        
        except Exception as e:
            logger.error(
                "Token refresh failed",
                device_id=device_id,
                error=str(e)
            )
            raise
    
    async def manual_refresh_cycle(self) -> Dict[str, Any]:
        """
        Manually trigger a refresh cycle (for admin/testing purposes)
        
        Returns:
            Dictionary with refresh results
        """
        
        logger.info("Manual token refresh cycle triggered")
        
        if self.is_running:
            return {
                "status": "error",
                "message": "Token refresh already in progress"
            }
        
        try:
            await self._refresh_expiring_tokens()
            
            return {
                "status": "success",
                "message": "Manual refresh cycle completed",
                "stats": self.stats.to_dict()
            }
            
        except Exception as e:
            return {
                "status": "error", 
                "message": f"Manual refresh failed: {str(e)}",
                "stats": self.stats.to_dict()
            }
    
    def get_stats(self) -> Dict[str, Any]:
        """Get current refresh statistics"""
        
        # Get retry job information
        retry_jobs = []
        if self.scheduler:
            for job in self.scheduler.get_jobs():
                if job.id.startswith("retry_refresh_"):
                    device_id = job.id.replace("retry_refresh_", "")
                    retry_jobs.append({
                        "device_id": device_id,
                        "retry_time": job.next_run_time.isoformat() if job.next_run_time else None
                    })
        
        return {
            "scheduler_running": self.scheduler is not None and self.scheduler.running,
            "refresh_in_progress": self.is_running,
            "next_run_time": (
                self.scheduler.get_job("spotify_token_refresh").next_run_time.isoformat()
                if self.scheduler and self.scheduler.get_job("spotify_token_refresh")
                else None
            ),
            "pending_retries": len(self.failed_devices),
            "retry_jobs": retry_jobs,
            "failed_devices": {
                device_id: failure_time.isoformat() 
                for device_id, failure_time in self.failed_devices.items()
            },
            "stats": self.stats.to_dict()
        }

# Global service instance
token_refresh_service = SpotifyTokenRefreshService()