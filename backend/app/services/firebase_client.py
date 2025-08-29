"""
Firebase Firestore REST API client

Handles token storage and retrieval using Firestore REST API endpoints.
This implementation uses direct HTTP requests to Firestore rather than the Admin SDK.
"""

import httpx
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
import json
from urllib.parse import quote

from app.core.config import settings
from app.core.logging_config import get_logger

logger = get_logger(__name__)

class FirebaseError(Exception):
    """Base exception for Firebase operations"""
    pass

class DocumentNotFoundError(FirebaseError):
    """Document not found in Firestore"""
    pass

class FirebaseAuthError(FirebaseError):
    """Firebase authentication error"""
    pass

class FirebaseClient:
    """
    Firebase Firestore REST API client
    
    Provides methods for CRUD operations on Firestore documents
    using REST API endpoints with API key authentication.
    """
    
    def __init__(self):
        self.api_key = settings.FIREBASE_API_KEY
        self.project_id = settings.FIREBASE_PROJECT_ID
        self.base_url = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents"
        
        if not self.api_key or not self.project_id:
            raise FirebaseError("Firebase API key and project ID are required")
    
    async def store_spotify_tokens(
        self, 
        device_id: str, 
        access_token: str, 
        refresh_token: str,
        expires_at: datetime
    ) -> bool:
        """
        Store Spotify tokens for a device in Firestore
        
        Args:
            device_id: Unique device identifier
            access_token: Spotify access token
            refresh_token: Spotify refresh token
            expires_at: Token expiration timestamp
            
        Returns:
            True if successful, raises FirebaseError on failure
        """
        
        logger.info("Storing Spotify tokens", device_id=device_id)
        
        document_data = {
            "fields": {
                "access_token": {
                    "stringValue": access_token
                },
                "refresh_token": {
                    "stringValue": refresh_token
                },
                "expires_at": {
                    "timestampValue": expires_at.isoformat() + "Z"
                },
                "created_at": {
                    "timestampValue": datetime.utcnow().isoformat() + "Z"
                },
                "updated_at": {
                    "timestampValue": datetime.utcnow().isoformat() + "Z"
                }
            }
        }
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                url = f"{self.base_url}/spotify_tokens/{quote(device_id)}"
                params = {"key": self.api_key}
                
                response = await client.patch(
                    url,
                    params=params,
                    json=document_data,
                    headers={"Content-Type": "application/json"}
                )
                
                if response.status_code == 200:
                    logger.info("Spotify tokens stored successfully", device_id=device_id)
                    return True
                else:
                    error_detail = response.text
                    logger.error(
                        "Failed to store Spotify tokens",
                        device_id=device_id,
                        status_code=response.status_code,
                        error=error_detail
                    )
                    raise FirebaseError(f"Failed to store tokens: {error_detail}")
                    
        except httpx.TimeoutException:
            logger.error("Timeout storing Spotify tokens", device_id=device_id)
            raise FirebaseError("Request timeout")
            
        except Exception as e:
            logger.error("Unexpected error storing tokens", device_id=device_id, error=str(e))
            raise FirebaseError(f"Unexpected error: {str(e)}")
    
    async def get_spotify_tokens(self, device_id: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve Spotify tokens for a device from Firestore
        
        Args:
            device_id: Unique device identifier
            
        Returns:
            Dictionary containing token data or None if not found
            
        Raises:
            FirebaseError: On API errors
        """
        
        logger.info("Retrieving Spotify tokens", device_id=device_id)
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                url = f"{self.base_url}/spotify_tokens/{quote(device_id)}"
                params = {"key": self.api_key}
                
                response = await client.get(url, params=params)
                
                if response.status_code == 404:
                    logger.info("Spotify tokens not found", device_id=device_id)
                    return None
                    
                elif response.status_code == 200:
                    document = response.json()
                    
                    # Extract values from Firestore document format
                    fields = document.get("fields", {})
                    
                    token_data = {
                        "access_token": fields.get("access_token", {}).get("stringValue"),
                        "refresh_token": fields.get("refresh_token", {}).get("stringValue"),
                        "expires_at": fields.get("expires_at", {}).get("timestampValue"),
                        "created_at": fields.get("created_at", {}).get("timestampValue"),
                        "updated_at": fields.get("updated_at", {}).get("timestampValue")
                    }
                    
                    logger.info("Spotify tokens retrieved successfully", device_id=device_id)
                    return token_data
                    
                else:
                    error_detail = response.text
                    logger.error(
                        "Failed to retrieve Spotify tokens",
                        device_id=device_id,
                        status_code=response.status_code,
                        error=error_detail
                    )
                    raise FirebaseError(f"Failed to retrieve tokens: {error_detail}")
                    
        except httpx.TimeoutException:
            logger.error("Timeout retrieving Spotify tokens", device_id=device_id)
            raise FirebaseError("Request timeout")
            
        except Exception as e:
            logger.error("Unexpected error retrieving tokens", device_id=device_id, error=str(e))
            raise FirebaseError(f"Unexpected error: {str(e)}")
    
    async def delete_spotify_tokens(self, device_id: str) -> bool:
        """
        Delete Spotify tokens for a device from Firestore
        
        Args:
            device_id: Unique device identifier
            
        Returns:
            True if successful or document didn't exist
            
        Raises:
            FirebaseError: On API errors
        """
        
        logger.info("Deleting Spotify tokens", device_id=device_id)
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                url = f"{self.base_url}/spotify_tokens/{quote(device_id)}"
                params = {"key": self.api_key}
                
                response = await client.delete(url, params=params)
                
                if response.status_code in [200, 404]:
                    logger.info("Spotify tokens deleted successfully", device_id=device_id)
                    return True
                else:
                    error_detail = response.text
                    logger.error(
                        "Failed to delete Spotify tokens",
                        device_id=device_id,
                        status_code=response.status_code,
                        error=error_detail
                    )
                    raise FirebaseError(f"Failed to delete tokens: {error_detail}")
                    
        except httpx.TimeoutException:
            logger.error("Timeout deleting Spotify tokens", device_id=device_id)
            raise FirebaseError("Request timeout")
            
        except Exception as e:
            logger.error("Unexpected error deleting tokens", device_id=device_id, error=str(e))
            raise FirebaseError(f"Unexpected error: {str(e)}")
    
    async def is_token_expired(self, device_id: str, margin_seconds: int = 300) -> Optional[bool]:
        """
        Check if stored access token is expired or will expire within margin
        
        Args:
            device_id: Unique device identifier
            margin_seconds: Safety margin in seconds (default 5 minutes)
            
        Returns:
            True if expired/expiring, False if valid, None if no token found
        """
        
        token_data = await self.get_spotify_tokens(device_id)
        
        if not token_data or not token_data.get("expires_at"):
            return None
            
        try:
            # Parse ISO timestamp (remove Z if present)
            expires_at_str = token_data["expires_at"].rstrip("Z")
            expires_at = datetime.fromisoformat(expires_at_str)
            
            # Add margin for safety
            expires_with_margin = expires_at - timedelta(seconds=margin_seconds)
            
            is_expired = datetime.utcnow() >= expires_with_margin
            
            logger.info(
                "Token expiration check",
                device_id=device_id,
                expires_at=expires_at.isoformat(),
                is_expired=is_expired
            )
            
            return is_expired
            
        except (ValueError, TypeError) as e:
            logger.error("Failed to parse token expiration", device_id=device_id, error=str(e))
            return True  # Assume expired if we can't parse the date
    
    async def cleanup_expired_tokens(self, batch_size: int = 100) -> int:
        """
        Clean up expired tokens from Firestore
        
        Args:
            batch_size: Maximum number of documents to process
            
        Returns:
            Number of tokens cleaned up
        """
        
        logger.info("Starting expired token cleanup")
        
        try:
            # Query all spotify_tokens documents
            async with httpx.AsyncClient(timeout=60.0) as client:
                url = f"{self.base_url}/spotify_tokens"
                params = {
                    "key": self.api_key,
                    "pageSize": batch_size
                }
                
                response = await client.get(url, params=params)
                
                if response.status_code != 200:
                    logger.error("Failed to query tokens for cleanup", status_code=response.status_code)
                    return 0
                
                documents = response.json().get("documents", [])
                
                cleaned_count = 0
                now = datetime.utcnow()
                
                for doc in documents:
                    try:
                        # Extract device ID from document name
                        doc_name = doc.get("name", "")
                        device_id = doc_name.split("/")[-1]
                        
                        # Extract expiration timestamp
                        fields = doc.get("fields", {})
                        expires_at_str = fields.get("expires_at", {}).get("timestampValue")
                        
                        if expires_at_str:
                            expires_at = datetime.fromisoformat(expires_at_str.rstrip("Z"))
                            
                            if now >= expires_at:
                                await self.delete_spotify_tokens(device_id)
                                cleaned_count += 1
                                logger.info("Cleaned up expired token", device_id=device_id)
                                
                    except Exception as e:
                        logger.error("Error processing document for cleanup", error=str(e))
                        continue
                
                logger.info("Expired token cleanup completed", cleaned_count=cleaned_count)
                return cleaned_count
                
        except Exception as e:
            logger.error("Unexpected error during token cleanup", error=str(e))
            return 0

# Global Firebase client instance
firebase_client = FirebaseClient()