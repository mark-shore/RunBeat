"""
Health check endpoints for RunBeat Backend API
"""

from fastapi import APIRouter, HTTPException
from typing import Dict, Any
from datetime import datetime
import asyncio
import httpx

from app.core.config import settings
from app.core.logging_config import get_logger

router = APIRouter()
logger = get_logger(__name__)

@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """Basic health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT
    }

@router.get("/health/detailed")
async def detailed_health_check() -> Dict[str, Any]:
    """Detailed health check with dependency checks"""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
        "checks": {}
    }
    
    # Check Firebase configuration
    health_status["checks"]["firebase"] = {
        "status": "healthy" if settings.validate_firebase_config() else "unhealthy",
        "configured": settings.validate_firebase_config()
    }
    
    # Check Spotify configuration
    health_status["checks"]["spotify"] = {
        "status": "healthy" if settings.validate_spotify_config() else "unhealthy",
        "configured": settings.validate_spotify_config()
    }
    
    # Check Spotify API connectivity
    spotify_api_status = await check_spotify_api()
    health_status["checks"]["spotify_api"] = spotify_api_status
    
    # Determine overall status
    unhealthy_checks = [
        check for check in health_status["checks"].values() 
        if check["status"] != "healthy"
    ]
    
    if unhealthy_checks:
        health_status["status"] = "degraded"
        logger.warning("Health check found issues", unhealthy_checks=len(unhealthy_checks))
    
    return health_status

async def check_spotify_api() -> Dict[str, Any]:
    """Check Spotify API connectivity"""
    try:
        async with httpx.AsyncClient(timeout=settings.HEALTH_CHECK_TIMEOUT) as client:
            response = await client.get(f"{settings.SPOTIFY_API_BASE_URL}/")
            return {
                "status": "healthy" if response.status_code in [200, 404] else "unhealthy",
                "response_time_ms": response.elapsed.total_seconds() * 1000,
                "status_code": response.status_code
            }
    except Exception as e:
        logger.error("Spotify API health check failed", error=str(e))
        return {
            "status": "unhealthy",
            "error": str(e)
        }

@router.get("/health/ready")
async def readiness_check() -> Dict[str, Any]:
    """Kubernetes-style readiness check"""
    # Check if all required configurations are present
    ready = (
        settings.validate_firebase_config() and 
        settings.validate_spotify_config()
    )
    
    if not ready:
        raise HTTPException(status_code=503, detail="Service not ready")
    
    return {
        "status": "ready",
        "timestamp": datetime.utcnow().isoformat()
    }

@router.get("/health/live")
async def liveness_check() -> Dict[str, Any]:
    """Kubernetes-style liveness check"""
    return {
        "status": "alive",
        "timestamp": datetime.utcnow().isoformat()
    }