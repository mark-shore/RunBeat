# Railway Deployment Guide for RunBeat Backend

## Prerequisites
- Railway CLI installed: `npm install -g @railway/cli`
- Railway account created at https://railway.app

## Deployment Steps

### 1. Login to Railway
```bash
railway login
```

### 2. Initialize Railway Project
```bash
cd backend
railway init
```
- Choose "Create new project"
- Name it "runbeat-backend"

### 3. Set Environment Variables
Set the following environment variables in Railway dashboard or via CLI:

#### Required Firebase Variables:
```bash
railway variables set FIREBASE_API_KEY=AIzaSyAbXWmYYuffr3A8YdI-MxUcbuAqP9I4K2Y
railway variables set FIREBASE_PROJECT_ID=runbeat-64b83
railway variables set FIREBASE_STORAGE_BUCKET=runbeat-64b83.firebasestorage.app
railway variables set FIREBASE_SENDER_ID=351570203287
```

#### Required Spotify Variables:
```bash
railway variables set SPOTIFY_CLIENT_ID=5f95e15c837b447bbc6aed4ec83776b6
railway variables set SPOTIFY_CLIENT_SECRET=0757e194891d4f8db9e280f868de0d05
railway variables set SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID=4OVrwFYrBP03lXStlTkbDK
railway variables set SPOTIFY_REST_PLAYLIST_ID=5TZiprVS1hx8i8DmnF1U9i
```

#### Security Variables:
```bash
railway variables set SECRET_KEY="$(openssl rand -base64 32)"
railway variables set SPOTIFY_REDIRECT_URI=runbeat://callback
```

#### Additional Configuration:
```bash
railway variables set ENVIRONMENT=production
railway variables set DEBUG=false
railway variables set LOG_LEVEL=INFO
railway variables set ALLOWED_ORIGINS="https://runbeat.app,*"
```

### 4. Deploy
```bash
railway up
```

### 5. Get Deployment URL
After deployment, get the URL with:
```bash
railway status
```

The deployment URL will be something like: `https://runbeat-backend-production-xxxx.up.railway.app`

## Files Prepared for Deployment
- ✅ `railway.toml` - Railway configuration
- ✅ `Procfile` - Process definition
- ✅ `runtime.txt` - Python version specification
- ✅ `requirements.txt` - Python dependencies
- ✅ App configured to bind to `0.0.0.0:$PORT`

## Post-Deployment
1. Test the health endpoint: `https://your-railway-url.railway.app/api/v1/health`
2. Update iOS Config.plist with the Railway URL
3. Test iOS app connectivity