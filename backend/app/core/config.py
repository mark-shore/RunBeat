"""
Configuration management for RunBeat Backend API

Loads configuration from .env file using python-decouple for proper
separation of iOS and backend configuration.
"""

import os
from typing import List, Optional
from decouple import config, AutoConfig
from functools import lru_cache

# Load configuration from .env file in backend directory
# This ensures proper separation from iOS configuration files
ENV_CONFIG = AutoConfig(search_path=os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

class Settings:
    """Application settings loaded from .env file"""
    
    # Server Configuration
    PORT: int = ENV_CONFIG("PORT", default=8000, cast=int)
    HOST: str = ENV_CONFIG("HOST", default="0.0.0.0")
    ENVIRONMENT: str = ENV_CONFIG("ENVIRONMENT", default="development")
    DEBUG: bool = ENV_CONFIG("DEBUG", default=True, cast=bool)
    
    # CORS Configuration
    ALLOWED_ORIGINS: List[str] = ENV_CONFIG(
        "ALLOWED_ORIGINS",
        default="http://localhost:3000,http://127.0.0.1:3000,https://runbeat.app",
        cast=lambda v: [origin.strip() for origin in v.split(",")]
    )
    
    # Firebase Configuration - Only API_KEY and PROJECT_ID are essential for REST API
    FIREBASE_API_KEY: str = ENV_CONFIG("FIREBASE_API_KEY")
    FIREBASE_PROJECT_ID: str = ENV_CONFIG("FIREBASE_PROJECT_ID")
    FIREBASE_STORAGE_BUCKET: Optional[str] = ENV_CONFIG("FIREBASE_STORAGE_BUCKET", default=None)  # Not used in REST API
    FIREBASE_SENDER_ID: Optional[str] = ENV_CONFIG("FIREBASE_SENDER_ID", default=None)  # Not used in REST API
    
    # Firebase Admin SDK (optional for advanced server-side operations)
    FIREBASE_ADMIN_SDK_PATH: Optional[str] = ENV_CONFIG("FIREBASE_ADMIN_SDK_PATH", default=None)
    FIREBASE_ADMIN_CREDENTIALS: Optional[str] = ENV_CONFIG("FIREBASE_ADMIN_CREDENTIALS", default=None)
    
    # Spotify Configuration - Essential for token refresh
    SPOTIFY_CLIENT_ID: str = ENV_CONFIG("SPOTIFY_CLIENT_ID")
    SPOTIFY_CLIENT_SECRET: str = ENV_CONFIG("SPOTIFY_CLIENT_SECRET")
    SPOTIFY_REDIRECT_URI: str = ENV_CONFIG("SPOTIFY_REDIRECT_URI", default="runbeat://callback")  # OAuth handled by iOS
    
    # Default Spotify playlists - Optional, used for config endpoint
    SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID: Optional[str] = ENV_CONFIG("SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID", default=None)
    SPOTIFY_REST_PLAYLIST_ID: Optional[str] = ENV_CONFIG("SPOTIFY_REST_PLAYLIST_ID", default=None)
    
    # Spotify API Configuration
    SPOTIFY_API_BASE_URL: str = "https://api.spotify.com/v1"
    SPOTIFY_ACCOUNTS_BASE_URL: str = "https://accounts.spotify.com"
    SPOTIFY_TOKEN_REFRESH_MARGIN: int = ENV_CONFIG("SPOTIFY_TOKEN_REFRESH_MARGIN", default=300, cast=int)  # 5 minutes
    
    # Security Configuration - SECRET_KEY optional for token management only service
    SECRET_KEY: str = ENV_CONFIG("SECRET_KEY", default="dev-key-not-for-production")  # Default for development
    ALGORITHM: str = ENV_CONFIG("ALGORITHM", default="HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = ENV_CONFIG("ACCESS_TOKEN_EXPIRE_MINUTES", default=30, cast=int)
    
    # Database Configuration (optional)
    DATABASE_URL: Optional[str] = ENV_CONFIG("DATABASE_URL", default=None)
    
    # Redis Configuration (for caching)
    REDIS_URL: Optional[str] = ENV_CONFIG("REDIS_URL", default=None)
    
    # Logging Configuration
    LOG_LEVEL: str = ENV_CONFIG("LOG_LEVEL", default="INFO")
    LOG_FORMAT: str = ENV_CONFIG("LOG_FORMAT", default="json")
    
    # Rate Limiting
    RATE_LIMIT_REQUESTS: int = ENV_CONFIG("RATE_LIMIT_REQUESTS", default=100, cast=int)
    RATE_LIMIT_WINDOW: int = ENV_CONFIG("RATE_LIMIT_WINDOW", default=60, cast=int)  # seconds
    
    # Background Task Configuration
    SCHEDULER_TIMEZONE: str = ENV_CONFIG("SCHEDULER_TIMEZONE", default="UTC")
    TOKEN_CLEANUP_INTERVAL: int = ENV_CONFIG("TOKEN_CLEANUP_INTERVAL", default=3600, cast=int)  # 1 hour
    
    # Health Check Configuration
    HEALTH_CHECK_TIMEOUT: int = ENV_CONFIG("HEALTH_CHECK_TIMEOUT", default=5, cast=int)
    
    @property
    def is_production(self) -> bool:
        """Check if running in production environment"""
        return self.ENVIRONMENT.lower() == "production"
    
    @property
    def is_development(self) -> bool:
        """Check if running in development environment"""
        return self.ENVIRONMENT.lower() == "development"
    
    def validate_firebase_config(self) -> bool:
        """Validate Firebase configuration - Only API_KEY and PROJECT_ID required for REST API"""
        required_fields = [
            self.FIREBASE_API_KEY,
            self.FIREBASE_PROJECT_ID
        ]
        return all(field for field in required_fields)
    
    def validate_spotify_config(self) -> bool:
        """Validate Spotify configuration"""
        required_fields = [
            self.SPOTIFY_CLIENT_ID,
            self.SPOTIFY_CLIENT_SECRET
        ]
        return all(field for field in required_fields)

@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()

# Global settings instance
settings = get_settings()

# Environment-specific configurations
class DevelopmentSettings(Settings):
    """Development environment settings"""
    DEBUG = True
    LOG_LEVEL = "DEBUG"

class ProductionSettings(Settings):
    """Production environment settings"""
    DEBUG = False
    LOG_LEVEL = "INFO"
    
    # Override with more secure defaults for production
    ALLOWED_ORIGINS = ["https://runbeat.app", "https://api.runbeat.app"]

def get_environment_settings() -> Settings:
    """Get environment-specific settings"""
    env = os.getenv("ENVIRONMENT", "development").lower()
    
    if env == "production":
        return ProductionSettings()
    else:
        return DevelopmentSettings()