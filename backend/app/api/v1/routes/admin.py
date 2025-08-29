"""
Admin endpoints for monitoring and managing backend services

These endpoints provide administrative access to monitor token refresh operations,
scheduler status, and manually trigger refresh cycles.
"""

from fastapi import APIRouter, HTTPException
from typing import Dict, Any
from datetime import datetime

from app.core.logging_config import get_logger
from app.core.config import settings
from app.services.token_refresh_service import token_refresh_service
from app.services.firebase_client import firebase_client

router = APIRouter()
logger = get_logger(__name__)

@router.get("/refresh-status")
async def get_refresh_status() -> Dict[str, Any]:
    """
    Get current status of the token refresh system
    
    Returns:
        - Scheduler running status
        - Refresh statistics
        - Next scheduled run time
        - Current refresh operation status
    """
    
    logger.info("Admin refresh status requested")
    
    try:
        status = token_refresh_service.get_stats()
        
        return {
            "status": "success",
            "timestamp": datetime.utcnow().isoformat(),
            "refresh_system": status
        }
        
    except Exception as e:
        logger.error("Failed to get refresh status", error=str(e))
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get refresh status: {str(e)}"
        )

@router.post("/refresh-trigger")
async def trigger_manual_refresh() -> Dict[str, Any]:
    """
    Manually trigger a token refresh cycle
    
    This endpoint allows administrators to force a token refresh cycle
    outside of the normal scheduled intervals. Useful for testing
    or handling urgent refresh needs.
    """
    
    logger.info("Manual token refresh triggered via admin endpoint")
    
    try:
        result = await token_refresh_service.manual_refresh_cycle()
        
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "manual_refresh": result
        }
        
    except Exception as e:
        logger.error("Failed to trigger manual refresh", error=str(e))
        raise HTTPException(
            status_code=500,
            detail=f"Failed to trigger manual refresh: {str(e)}"
        )

@router.get("/token-overview")
async def get_token_overview() -> Dict[str, Any]:
    """
    Get overview of all stored tokens
    
    Returns summary information about stored tokens without exposing
    sensitive token data.
    """
    
    logger.info("Admin token overview requested")
    
    try:
        # Query all spotify_tokens documents from Firebase
        import httpx
        from app.core.config import settings
        from datetime import timedelta
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            url = f"https://firestore.googleapis.com/v1/projects/{settings.FIREBASE_PROJECT_ID}/databases/(default)/documents/spotify_tokens"
            params = {
                "key": settings.FIREBASE_API_KEY,
                "pageSize": 1000
            }
            
            response = await client.get(url, params=params)
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=500,
                    detail=f"Firebase query failed: {response.status_code}"
                )
            
            documents = response.json().get("documents", [])
            
            # Process token data for overview
            token_summary = {
                "total_tokens": len(documents),
                "tokens_by_status": {
                    "valid": 0,
                    "expiring_soon": 0,  # Within 1 hour
                    "expired": 0
                },
                "devices": []
            }
            
            now = datetime.utcnow()
            one_hour_from_now = now + timedelta(hours=1)
            
            for doc in documents:
                try:
                    # Extract basic info
                    doc_name = doc.get("name", "")
                    device_id = doc_name.split("/")[-1]
                    
                    fields = doc.get("fields", {})
                    expires_at_str = fields.get("expires_at", {}).get("timestampValue")
                    created_at_str = fields.get("created_at", {}).get("timestampValue")
                    
                    if expires_at_str:
                        expires_at = datetime.fromisoformat(expires_at_str.rstrip("Z"))
                        
                        # Categorize token status
                        if expires_at <= now:
                            status = "expired"
                            token_summary["tokens_by_status"]["expired"] += 1
                        elif expires_at <= one_hour_from_now:
                            status = "expiring_soon"
                            token_summary["tokens_by_status"]["expiring_soon"] += 1
                        else:
                            status = "valid"
                            token_summary["tokens_by_status"]["valid"] += 1
                        
                        # Add device info
                        device_info = {
                            "device_id": device_id,
                            "status": status,
                            "expires_at": expires_at.isoformat(),
                            "minutes_until_expiry": int((expires_at - now).total_seconds() / 60)
                        }
                        
                        if created_at_str:
                            created_at = datetime.fromisoformat(created_at_str.rstrip("Z"))
                            device_info["created_at"] = created_at.isoformat()
                            device_info["age_hours"] = int((now - created_at).total_seconds() / 3600)
                        
                        token_summary["devices"].append(device_info)
                
                except Exception as e:
                    logger.warning(
                        "Failed to process token for overview",
                        device_id=device_id if 'device_id' in locals() else "unknown",
                        error=str(e)
                    )
                    continue
            
            # Sort devices by expiry time
            token_summary["devices"].sort(
                key=lambda x: x.get("minutes_until_expiry", float('inf'))
            )
            
            return {
                "status": "success",
                "timestamp": datetime.utcnow().isoformat(),
                "token_overview": token_summary
            }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to get token overview", error=str(e))
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get token overview: {str(e)}"
        )

@router.delete("/token-cleanup")
async def cleanup_expired_tokens() -> Dict[str, Any]:
    """
    Manually trigger cleanup of expired tokens
    
    This endpoint removes all expired tokens from Firebase storage.
    """
    
    logger.info("Manual token cleanup triggered via admin endpoint")
    
    try:
        cleaned_count = await firebase_client.cleanup_expired_tokens()
        
        return {
            "status": "success",
            "timestamp": datetime.utcnow().isoformat(),
            "cleanup_result": {
                "tokens_cleaned": cleaned_count,
                "message": f"Successfully cleaned up {cleaned_count} expired tokens"
            }
        }
        
    except Exception as e:
        logger.error("Failed to cleanup expired tokens", error=str(e))
        raise HTTPException(
            status_code=500,
            detail=f"Failed to cleanup expired tokens: {str(e)}"
        )

@router.get("/system-health")
async def get_system_health() -> Dict[str, Any]:
    """
    Get overall system health status
    
    Returns health information for all backend services.
    """
    
    logger.info("System health check requested")
    
    try:
        health_status = {
            "timestamp": datetime.utcnow().isoformat(),
            "services": {
                "token_refresh": {
                    "status": "healthy" if token_refresh_service.scheduler and token_refresh_service.scheduler.running else "unhealthy",
                    "scheduler_running": token_refresh_service.scheduler is not None and token_refresh_service.scheduler.running,
                    "refresh_in_progress": token_refresh_service.is_running,
                    "last_run": token_refresh_service.stats.last_run_time.isoformat() if token_refresh_service.stats.last_run_time else None,
                    "last_error": token_refresh_service.stats.last_error
                },
                "firebase": {
                    "status": "unknown",  # We'd need to test a Firebase connection to determine this
                    "project_id": settings.FIREBASE_PROJECT_ID,
                    "api_configured": bool(settings.FIREBASE_API_KEY)
                },
                "spotify": {
                    "status": "configured" if settings.SPOTIFY_CLIENT_ID and settings.SPOTIFY_CLIENT_SECRET else "not_configured",
                    "client_configured": bool(settings.SPOTIFY_CLIENT_ID),
                    "secret_configured": bool(settings.SPOTIFY_CLIENT_SECRET)
                }
            }
        }
        
        # Overall system status
        all_healthy = all(
            service.get("status") in ["healthy", "configured"]
            for service in health_status["services"].values()
        )
        
        health_status["overall_status"] = "healthy" if all_healthy else "degraded"
        
        return health_status
        
    except Exception as e:
        logger.error("Failed to get system health", error=str(e))
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get system health: {str(e)}"
        )