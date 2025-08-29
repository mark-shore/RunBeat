#!/bin/bash

# RunBeat Backend Deployment Script for Railway

echo "🚀 Deploying RunBeat Backend to Railway..."

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Installing..."
    npm install -g @railway/cli
fi

# Verify we're in the backend directory
if [ ! -f "main.py" ]; then
    echo "❌ Error: Please run this script from the backend directory"
    exit 1
fi

echo "✅ Railway CLI ready"

# Check if already logged in
if ! railway whoami &> /dev/null; then
    echo "🔑 Please login to Railway..."
    railway login
fi

# Initialize project if needed
if [ ! -f ".railway" ]; then
    echo "🆕 Initializing Railway project..."
    railway init
fi

echo "⚙️  Setting ESSENTIAL environment variables..."

# Set ONLY essential environment variables (others have defaults)
railway variables set FIREBASE_API_KEY=AIzaSyAbXWmYYuffr3A8YdI-MxUcbuAqP9I4K2Y
railway variables set FIREBASE_PROJECT_ID=runbeat-64b83

railway variables set SPOTIFY_CLIENT_ID=5f95e15c837b447bbc6aed4ec83776b6
railway variables set SPOTIFY_CLIENT_SECRET=0757e194891d4f8db9e280f868de0d05

# Generate secure secret key
SECRET_KEY=$(openssl rand -base64 32)
railway variables set SECRET_KEY="$SECRET_KEY"

# Set production configuration
railway variables set ENVIRONMENT=production
railway variables set DEBUG=false
railway variables set LOG_LEVEL=INFO
railway variables set ALLOWED_ORIGINS="https://runbeat.app,*"

echo "ℹ️  User-specific optional variables:"
echo "   To set your own playlists (replace with your playlist IDs):"
echo "   railway variables set SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID=your-high-energy-playlist-id"
echo "   railway variables set SPOTIFY_REST_PLAYLIST_ID=your-calm-playlist-id"

echo "🚀 Deploying to Railway..."
railway up --detach

echo "⏳ Waiting for deployment to complete..."
sleep 10

echo "📊 Getting deployment status..."
railway status

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔗 Your backend URL:"
railway status | grep "URL" || echo "Check Railway dashboard for URL"
echo ""
echo "🧪 Test your deployment:"
echo "curl https://your-railway-url/api/v1/health"
echo ""
echo "📱 Next steps:"
echo "1. Update iOS Config.plist with the Railway URL"
echo "2. Test the iOS app with the deployed backend"