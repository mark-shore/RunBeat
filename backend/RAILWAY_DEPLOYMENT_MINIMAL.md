# Minimal Railway Deployment for RunBeat Backend

## Essential Environment Variables Only

The backend has been optimized to require only essential environment variables. All other variables have sensible defaults.

### Required Variables (Backend will not start without these):

```bash
# Firebase (for token storage)
FIREBASE_API_KEY=AIzaSyAbXWmYYuffr3A8YdI-MxUcbuAqP9I4K2Y
FIREBASE_PROJECT_ID=runbeat-64b83

# Spotify (for token refresh) 
SPOTIFY_CLIENT_ID=5f95e15c837b447bbc6aed4ec83776b6
SPOTIFY_CLIENT_SECRET=0757e194891d4f8db9e280f868de0d05

# Security (generate unique key for production)
SECRET_KEY=your-unique-secret-key-here

# Production settings
ENVIRONMENT=production
DEBUG=false
```

### Quick Deploy Commands:

```bash
# Login to Railway
railway login

# Initialize project
railway init

# Set essential variables
railway variables set FIREBASE_API_KEY=AIzaSyAbXWmYYuffr3A8YdI-MxUcbuAqP9I4K2Y
railway variables set FIREBASE_PROJECT_ID=runbeat-64b83
railway variables set SPOTIFY_CLIENT_ID=5f95e15c837b447bbc6aed4ec83776b6
railway variables set SPOTIFY_CLIENT_SECRET=0757e194891d4f8db9e280f868de0d05
railway variables set SECRET_KEY="$(openssl rand -base64 32)"
railway variables set ENVIRONMENT=production
railway variables set DEBUG=false
railway variables set ALLOWED_ORIGINS="https://runbeat.app,*"

# Deploy
railway up
```

### Variables with Defaults (Optional):
- `SPOTIFY_REDIRECT_URI` → `"runbeat://callback"`
- `PORT` → `8000`
- `HOST` → `"0.0.0.0"`
- `LOG_LEVEL` → `"INFO"`
- `RATE_LIMIT_REQUESTS` → `100`
- `HEALTH_CHECK_TIMEOUT` → `5`

### User-Specific Variables (Optional):
- `SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID` → Set to your high-energy playlist ID
- `SPOTIFY_REST_PLAYLIST_ID` → Set to your calm/recovery playlist ID

**Note:** These playlist IDs are personal to each user. The backend will only return playlist defaults if you explicitly configure your own playlist IDs. Otherwise, the iOS app should handle its own playlist management.

This minimal configuration ensures the backend starts successfully and provides token refresh functionality.