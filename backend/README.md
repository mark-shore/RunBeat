# RunBeat Backend API

FastAPI backend service for the RunBeat iOS heart rate training app. Handles Spotify token management, device registration, and provides background-safe API proxying.

## Features

- 🎵 **Spotify Token Management**: Server-side token refresh eliminates iOS background limitations
- 📱 **Device Registration**: Track and manage iOS app installations
- 🔥 **Firebase Integration**: User data storage and real-time workout tracking
- 🛡️ **Background-Safe API**: Proxy Spotify API calls with automatic token handling
- 🏥 **Health Checks**: Kubernetes-ready health endpoints
- 📊 **Structured Logging**: JSON logging with request tracing

## Quick Start

### Prerequisites

- Python 3.9+
- Firebase project (already configured)
- Spotify Developer App credentials

### Installation

1. **Clone and setup**:
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Environment configuration**:
   ```bash
   cp .env.example .env
   # Update .env with your credentials (already populated with defaults)
   ```

3. **Run development server**:
   ```bash
   python main.py
   # or
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

4. **Test the API**:
   ```bash
   curl http://localhost:8000/api/v1/health
   ```

## API Endpoints

### Health & Status
- `GET /api/v1/health` - Basic health check
- `GET /api/v1/health/detailed` - Detailed health with dependency checks
- `GET /api/v1/health/ready` - Kubernetes readiness probe
- `GET /api/v1/health/live` - Kubernetes liveness probe

### Device Management
- `POST /api/v1/devices/register` - Register iOS device
- `GET /api/v1/devices/{device_id}` - Get device info
- `PUT /api/v1/devices/{device_id}/heartbeat` - Update device last seen
- `DELETE /api/v1/devices/{device_id}` - Unregister device

### Spotify Integration
- `POST /api/v1/spotify/refresh-token` - Refresh Spotify access token
- `POST /api/v1/spotify/api-proxy` - Proxy Spotify API calls (planned)
- `GET /api/v1/spotify/playlists/default` - Get default training playlists
- `GET /api/v1/spotify/config` - Get Spotify client configuration

## Configuration

### Environment Variables

Key configurations (see `.env.example` for full list):

```bash
# Server
PORT=8000
ENVIRONMENT=development
DEBUG=true

# Firebase Configuration
FIREBASE_PROJECT_ID=runbeat-64b83
FIREBASE_API_KEY=your-firebase-key

# Spotify Configuration
SPOTIFY_CLIENT_ID=your-spotify-client-id
SPOTIFY_CLIENT_SECRET=your-spotify-client-secret
```

### Environment Configuration

The backend uses `.env` file configuration following Python best practices. 
Copy `.env.example` to `.env` and update with your actual credentials:

- **Firebase**: Configure your Firebase project credentials
  - API_KEY: Your Firebase API key
  - PROJECT_ID: Your Firebase project ID

- **Spotify**: Configure your Spotify application credentials
  - CLIENT_ID: `5f95e15c837b447bbc6aed4ec83776b6`
  - CLIENT_SECRET: `0757e194891d4f8db9e280f868de0d05`

## Deployment

### Railway Deployment

1. **Configure Railway**:
   ```bash
   # Install Railway CLI
   npm install -g @railway/cli
   
   # Login and deploy
   railway login
   railway up
   ```

2. **Set environment variables** in Railway dashboard:
   - FIREBASE_API_KEY
   - SPOTIFY_CLIENT_SECRET
   - SECRET_KEY (generate new for production)

3. **Railway configuration** is in `railway.toml` with:
   - Health check endpoint: `/api/v1/health`
   - Automatic restart on failure
   - Production environment defaults

## Project Structure

```
backend/
├── main.py                 # FastAPI application entry point
├── requirements.txt        # Python dependencies
├── railway.toml           # Railway deployment config
├── .env.example           # Environment variables template
└── app/
    ├── api/v1/routes/     # API route handlers
    │   ├── health.py      # Health check endpoints
    │   ├── devices.py     # Device management
    │   └── spotify.py     # Spotify integration
    ├── core/              # Core configuration
    │   ├── config.py      # Settings and environment management
    │   └── logging_config.py # Structured logging setup
    ├── models/            # Pydantic data models
    ├── services/          # Business logic services
    └── utils/             # Utility functions
```

## iOS Integration

### Token Refresh Flow

The backend eliminates iOS background token refresh issues:

```swift
// iOS app calls backend instead of Spotify directly
let response = await backendService.refreshSpotifyToken(
    deviceId: deviceId,
    refreshToken: currentRefreshToken
)
```

### Device Registration

iOS app registers on launch:
```swift
await backendService.registerDevice(
    deviceId: UIDevice.current.identifierForVendor?.uuidString,
    platform: "ios",
    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
)
```

## Development

### Running Tests
```bash
pytest
```

### Code Quality
```bash
# Install development dependencies
pip install pytest pytest-asyncio black isort flake8

# Format code
black .
isort .

# Lint code
flake8 .
```

### Debugging
- Set `DEBUG=true` in `.env`
- Logs are structured JSON for easy parsing
- Health endpoints provide detailed dependency status

## Production Considerations

- Set secure `SECRET_KEY` in production
- Use environment variables for all sensitive data
- Enable CORS only for your domain
- Consider Redis for caching (optional)
- Monitor health endpoints for uptime
- Set up log aggregation for structured logs