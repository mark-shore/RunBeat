"""
Spotify integration endpoints for token management and API proxying
User-scoped implementation using Firebase anonymous authentication
"""

from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
from pydantic import BaseModel, Field
import httpx
import base64
import re

from app.core.config import settings
from app.core.logging_config import get_logger
from app.services.firebase_client import firebase_client, FirebaseError

router = APIRouter()
logger = get_logger(__name__)

class SpotifyTokenRequest(BaseModel):
    """Spotify token refresh request model"""
    user_id: str = Field(..., description="Firebase anonymous user ID")
    refresh_token: str = Field(..., description="Spotify refresh token")

class SpotifyTokenResponse(BaseModel):
    """Spotify token response model"""
    access_token: str
    refresh_token: Optional[str] = None
    expires_in: int
    token_type: str = "Bearer"
    expires_at: str

class SpotifyTokenStoreRequest(BaseModel):
    """Store Spotify tokens request model"""
    access_token: str = Field(..., description="Spotify access token")
    refresh_token: str = Field(..., description="Spotify refresh token")
    expires_in: int = Field(..., description="Token expiration time in seconds")

class SpotifyAPIRequest(BaseModel):
    """Generic Spotify API request model"""
    user_id: str = Field(..., description="Firebase anonymous user ID")
    endpoint: str = Field(..., description="Spotify API endpoint (without base URL)")
    method: str = Field(default="GET", description="HTTP method")
    data: Optional[Dict[str, Any]] = Field(None, description="Request body data")

def validate_user_id(user_id: str) -> bool:
    """
    Validate Firebase anonymous user ID format
    Firebase UIDs are typically 28 characters long and contain alphanumeric characters
    """
    if not user_id or len(user_id) < 20 or len(user_id) > 36:
        return False
    
    # Allow alphanumeric characters only (Firebase UID pattern)
    return re.match(r'^[a-zA-Z0-9]+$', user_id) is not None

@router.post("/users/{user_id}/spotify-tokens")
async def store_spotify_tokens(user_id: str, request: SpotifyTokenStoreRequest) -> Dict[str, Any]:
    """
    Store Spotify tokens for a specific user
    
    This endpoint allows the iOS app to store initial Spotify tokens
    after successful OAuth authentication.
    """
    
    if not validate_user_id(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID format")
    
    logger.info("Storing Spotify tokens for user", user_id=user_id)
    
    try:
        # Calculate expiration time
        expires_at = datetime.utcnow() + timedelta(seconds=request.expires_in)
        
        # Store tokens in Firebase
        await firebase_client.store_spotify_tokens(
            user_id=user_id,
            access_token=request.access_token,
            refresh_token=request.refresh_token,
            expires_at=expires_at
        )
        
        logger.info("Spotify tokens stored successfully", user_id=user_id)
        
        return {
            "success": True,
            "message": "Tokens stored successfully",
            "expires_at": expires_at.isoformat() + "Z"
        }
        
    except FirebaseError as e:
        logger.error("Failed to store Spotify tokens", user_id=user_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to store tokens: {str(e)}")
    
    except Exception as e:
        logger.error("Unexpected error storing tokens", user_id=user_id, error=str(e))
        raise HTTPException(status_code=500, detail="Failed to store tokens")

@router.get("/users/{user_id}/spotify-token")
async def get_spotify_token(user_id: str) -> SpotifyTokenResponse:
    """
    Get a fresh Spotify access token for a user
    
    This endpoint retrieves the stored token if it's still valid,
    or automatically refreshes it if expired.
    """
    
    if not validate_user_id(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID format")
    
    logger.info("Getting Spotify token for user", user_id=user_id)
    
    try:
        # Check if token exists and is expired
        is_expired = await firebase_client.is_token_expired(
            user_id, 
            margin_seconds=settings.SPOTIFY_TOKEN_REFRESH_MARGIN
        )
        
        if is_expired is None:
            raise HTTPException(
                status_code=404, 
                detail="No tokens found for this user"
            )
        
        # Get current tokens
        token_data = await firebase_client.get_spotify_tokens(user_id)
        
        if not token_data:
            raise HTTPException(
                status_code=404,
                detail="No tokens found for this user"
            )
        
        # If token is not expired, return it
        if not is_expired:
            expires_at_str = token_data["expires_at"].rstrip("Z")
            expires_at = datetime.fromisoformat(expires_at_str)
            expires_in = int((expires_at - datetime.utcnow()).total_seconds())
            
            logger.info("Returning existing valid token", user_id=user_id)
            
            return SpotifyTokenResponse(
                access_token=token_data["access_token"],
                refresh_token=token_data["refresh_token"],
                expires_in=expires_in,
                expires_at=expires_at.isoformat() + "Z"
            )
        
        # Token is expired, refresh it
        logger.info("Token expired, refreshing", user_id=user_id)
        
        refresh_request = SpotifyTokenRequest(
            user_id=user_id,
            refresh_token=token_data["refresh_token"]
        )
        
        return await refresh_spotify_token(refresh_request)
        
    except HTTPException:
        raise
    except FirebaseError as e:
        logger.error("Firebase error getting token", user_id=user_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to retrieve token: {str(e)}")
    except Exception as e:
        logger.error("Unexpected error getting token", user_id=user_id, error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve token")

@router.delete("/users/{user_id}/spotify-tokens")
async def delete_spotify_tokens(user_id: str) -> Dict[str, Any]:
    """
    Delete stored Spotify tokens for a user
    
    This endpoint removes all stored tokens for the user,
    useful for logout or cleanup operations.
    """
    
    if not validate_user_id(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID format")
    
    logger.info("Deleting Spotify tokens for user", user_id=user_id)
    
    try:
        await firebase_client.delete_spotify_tokens(user_id)
        
        logger.info("Spotify tokens deleted successfully", user_id=user_id)
        
        return {
            "success": True,
            "message": "Tokens deleted successfully"
        }
        
    except FirebaseError as e:
        logger.error("Failed to delete Spotify tokens", user_id=user_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to delete tokens: {str(e)}")
    
    except Exception as e:
        logger.error("Unexpected error deleting tokens", user_id=user_id, error=str(e))
        raise HTTPException(status_code=500, detail="Failed to delete tokens")

@router.post("/spotify/refresh-token")
async def refresh_spotify_token(request: SpotifyTokenRequest) -> SpotifyTokenResponse:
    """
    Refresh Spotify access token using refresh token
    
    This endpoint handles the OAuth token refresh flow server-side,
    eliminating the need for the iOS app to manage token refresh directly.
    """
    
    if not validate_user_id(request.user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID format")
    
    logger.info(
        "Spotify token refresh request",
        user_id=request.user_id
    )
    
    try:
        # Prepare authorization header
        auth_string = f"{settings.SPOTIFY_CLIENT_ID}:{settings.SPOTIFY_CLIENT_SECRET}"
        auth_bytes = auth_string.encode('utf-8')
        auth_b64 = base64.b64encode(auth_bytes).decode('utf-8')
        
        # Prepare token refresh request
        headers = {
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/x-www-form-urlencoded"
        }
        
        data = {
            "grant_type": "refresh_token",
            "refresh_token": request.refresh_token
        }
        
        # Make token refresh request
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{settings.SPOTIFY_ACCOUNTS_BASE_URL}/api/token",
                headers=headers,
                data=data
            )
        
        if response.status_code != 200:
            logger.error(
                "Spotify token refresh failed",
                user_id=request.user_id,
                status_code=response.status_code,
                response=response.text
            )
            raise HTTPException(
                status_code=400,
                detail=f"Token refresh failed: {response.text}"
            )
        
        token_data = response.json()
        
        # Calculate expiration time
        expires_in = token_data.get("expires_in", 3600)
        expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
        
        # Prepare response
        token_response = SpotifyTokenResponse(
            access_token=token_data["access_token"],
            refresh_token=token_data.get("refresh_token"),  # May be None
            expires_in=expires_in,
            expires_at=expires_at.isoformat() + "Z"
        )
        
        logger.info(
            "Spotify token refreshed successfully",
            user_id=request.user_id,
            expires_in=expires_in
        )
        
        # Store new tokens in Firebase for the user
        try:
            await firebase_client.store_spotify_tokens(
                user_id=request.user_id,
                access_token=token_data["access_token"],
                refresh_token=token_data.get("refresh_token", request.refresh_token),
                expires_at=expires_at
            )
        except FirebaseError as e:
            logger.error(
                "Failed to store refreshed tokens",
                user_id=request.user_id,
                error=str(e)
            )
            # Continue without failing the request - token refresh succeeded
        
        return token_response
        
    except httpx.TimeoutException:
        logger.error("Spotify token refresh timeout", user_id=request.user_id)
        raise HTTPException(status_code=408, detail="Token refresh request timed out")
    
    except Exception as e:
        logger.error(
            "Unexpected error during token refresh",
            user_id=request.user_id,
            error=str(e)
        )
        raise HTTPException(status_code=500, detail="Token refresh failed")

@router.post("/spotify/api-proxy")
async def spotify_api_proxy(request: SpotifyAPIRequest) -> Dict[str, Any]:
    """
    Proxy Spotify API requests with automatic token management
    
    This endpoint allows the iOS app to make Spotify API calls through the backend,
    which can handle token refresh transparently.
    """
    
    if not validate_user_id(request.user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID format")
    
    logger.info(
        "Spotify API proxy request",
        user_id=request.user_id,
        endpoint=request.endpoint,
        method=request.method
    )
    
    try:
        # Get fresh access token for user
        token_response = await get_spotify_token(request.user_id)
        
        # Prepare request to Spotify API
        headers = {
            "Authorization": f"Bearer {token_response.access_token}",
            "Content-Type": "application/json"
        }
        
        url = f"{settings.SPOTIFY_API_BASE_URL}/{request.endpoint.lstrip('/')}"
        
        # Make API request
        async with httpx.AsyncClient(timeout=30.0) as client:
            if request.method.upper() == "GET":
                response = await client.get(url, headers=headers)
            elif request.method.upper() == "POST":
                response = await client.post(url, headers=headers, json=request.data)
            elif request.method.upper() == "PUT":
                response = await client.put(url, headers=headers, json=request.data)
            elif request.method.upper() == "DELETE":
                response = await client.delete(url, headers=headers)
            else:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unsupported HTTP method: {request.method}"
                )
        
        # Return response
        if response.status_code < 400:
            try:
                return response.json()
            except:
                return {"data": response.text}
        else:
            logger.error(
                "Spotify API request failed",
                user_id=request.user_id,
                endpoint=request.endpoint,
                status_code=response.status_code,
                error=response.text
            )
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Spotify API error: {response.text}"
            )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            "Unexpected error in API proxy",
            user_id=request.user_id,
            endpoint=request.endpoint,
            error=str(e)
        )
        raise HTTPException(status_code=500, detail="API proxy request failed")

@router.get("/spotify/playlists/default")
async def get_default_playlists() -> Dict[str, Any]:
    """Get default training playlists configuration - only returns if explicitly configured"""
    
    response = {}
    
    # Only include playlist configs if they're explicitly set (not personal defaults)
    if settings.SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID:
        response["high_intensity"] = {
            "playlist_id": settings.SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID,
            "name": "High Intensity Training",
            "description": "High-energy tracks for intense training phases"
        }
    
    if settings.SPOTIFY_REST_PLAYLIST_ID:
        response["rest"] = {
            "playlist_id": settings.SPOTIFY_REST_PLAYLIST_ID,
            "name": "Rest & Recovery", 
            "description": "Calm tracks for rest and recovery phases"
        }
    
    return response

@router.get("/spotify/config")
async def get_spotify_config() -> Dict[str, Any]:
    """Get Spotify configuration for client setup"""
    
    return {
        "client_id": settings.SPOTIFY_CLIENT_ID,
        "redirect_uri": settings.SPOTIFY_REDIRECT_URI,
        "scopes": [
            "user-read-private",
            "user-read-email",
            "playlist-read-private",
            "playlist-read-collaborative",
            "user-read-playback-state",
            "user-modify-playback-state",
            "streaming"
        ]
    }