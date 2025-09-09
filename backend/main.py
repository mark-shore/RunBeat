"""
RunBeat FastAPI Backend

This backend service handles:
- User-scoped Spotify token management and refresh
- Firebase anonymous authentication integration
- Background token refresh service
- User-based API endpoints for iOS app
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
import logging
from datetime import datetime

from app.core.config import settings
from app.api.v1.routes import health, spotify, admin
from app.core.logging_config import setup_logging
from app.services.token_refresh_service import token_refresh_service

# Setup logging
setup_logging()
logger = logging.getLogger(__name__)

# Create FastAPI application
app = FastAPI(
    title="RunBeat Backend API",
    description="Backend service for RunBeat iOS heart rate training app",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(health.router, prefix="/api/v1", tags=["health"])
app.include_router(spotify.router, prefix="/api/v1", tags=["spotify"])
app.include_router(admin.router, prefix="/api/v1/admin", tags=["admin"])

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("🚀 Starting RunBeat Backend API")
    logger.info(f"📊 Environment: {settings.ENVIRONMENT}")
    logger.info(f"🔧 Debug mode: {settings.DEBUG}")
    logger.info(f"🎵 Spotify integration: {'enabled' if settings.SPOTIFY_CLIENT_ID else 'disabled'}")
    logger.info(f"🔥 Firebase integration: {'enabled' if settings.FIREBASE_PROJECT_ID else 'disabled'}")
    
    # Start background token refresh scheduler
    try:
        token_refresh_service.start_scheduler()
        logger.info("⏰ Token refresh scheduler started")
    except Exception as e:
        logger.error(f"Failed to start token refresh scheduler: {str(e)}")
        # Don't fail startup if scheduler fails - service can still work without it

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("🛑 Shutting down RunBeat Backend API")
    
    # Stop background scheduler
    try:
        token_refresh_service.stop_scheduler()
        logger.info("⏰ Token refresh scheduler stopped")
    except Exception as e:
        logger.error(f"Error stopping token refresh scheduler: {str(e)}")

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Global HTTP exception handler"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "timestamp": datetime.utcnow().isoformat(),
            "path": str(request.url)
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """Global exception handler for unexpected errors"""
    logger.error(f"Unexpected error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "timestamp": datetime.utcnow().isoformat(),
            "path": str(request.url)
        }
    )

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with basic API information"""
    return {
        "name": "RunBeat Backend API",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.utcnow().isoformat(),
        "endpoints": {
            "health": "/api/v1/health",
            "devices": "/api/v1/devices",
            "spotify": "/api/v1/spotify",
            "admin": "/api/v1/admin",
            "docs": "/docs"
        }
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(settings.PORT),
        reload=settings.DEBUG,
        log_level="info" if settings.DEBUG else "warning"
    )