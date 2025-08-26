# Spotify Integration Setup Guide

This guide will help you set up the Spotify integration for the VO2 Max training feature.

## Prerequisites

1. A Spotify account
2. A Spotify Developer account (free)

## Step 1: Create a Spotify App

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Click "Create App"
3. Fill in the app details:
   - **App name**: RunBeat
   - **App description**: Heart rate zone training app with Spotify integration
   - **Website**: (optional)
   - **Redirect URIs**: `runbeat://spotify-login-callback`
   - **API/SDKs**: Select "iOS SDK"
4. Click "Save"

## Step 2: Get Your Client ID

1. After creating the app, you'll see your Client ID
2. Copy this Client ID - you'll need it for the next step

## Step 3: Configure Environment Variables

### Option A: Using .env file (Development)

1. Edit the `.env` file in the project root
2. Replace the placeholder values with your actual credentials:

```bash
# Spotify Configuration
SPOTIFY_CLIENT_ID=your_actual_client_id_here

# High Intensity Playlist (4-minute intervals)
SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID=your_high_intensity_playlist_id_here

# Rest Playlist (3-minute intervals)
SPOTIFY_REST_PLAYLIST_ID=your_rest_playlist_id_here
```

### Option B: Using Config.plist (Production)

1. Copy `RunBeat/Config.sample.plist` to `RunBeat/Config.plist`
2. Replace the placeholder values in `Config.plist` with your actual credentials

## Step 4: Create Spotify Playlists

### High-Intensity Playlist
1. Create a new playlist in Spotify for high-intensity workouts
2. Add energetic, fast-paced songs (140-180 BPM recommended)
3. Get the playlist ID from the URL: `spotify:playlist:PLAYLIST_ID`

### Rest Playlist
1. Create a new playlist in Spotify for rest/recovery
2. Add calming, slower songs (60-100 BPM recommended)
3. Get the playlist ID from the URL: `spotify:playlist:PLAYLIST_ID`

## Step 5: Get Playlist IDs

1. Open your playlist in Spotify
2. Click "Share" → "Copy link to playlist"
3. The playlist ID is the string after the last `/` in the URL
4. Example: `https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M` → `37i9dQZF1DXcBWIGoYBM5M`

## Step 6: Test the Integration

1. Build and run the app
2. Tap "VO₂ Max Training"
3. Tap "Connect Spotify"
4. Authorize the app in Spotify
5. Start a training session

## How It Works

The VO2 Max training feature follows this pattern:
- **4 minutes**: High-intensity interval (plays high-intensity playlist)
- **3 minutes**: Rest interval (plays rest playlist)
- **Repeats 4 times** for a total of 28 minutes

The app automatically:
- Switches between playlists based on the current phase
- Shows a visual progress indicator
- Displays the current track information
- Provides play/pause/stop controls

## Security Notes

- The `.env` and `Config.plist` files are excluded from git to keep your credentials secure
- Never commit your actual Client ID or playlist IDs to the repository
- Use different playlists for development and production if needed

## Troubleshooting

### "Spotify connection failed"
- Make sure your Client ID is correct
- Verify the redirect URI matches exactly: `runbeat://spotify-login-callback`
- Check that you've authorized the app in Spotify

### "Playlist not found"
- Verify your playlist IDs are correct
- Make sure the playlists are public or you're the owner
- Check that the playlists contain songs

### "No music playing"
- Ensure Spotify is installed and logged in
- Check that you have an active Spotify Premium subscription (required for SDK)
- Verify the playlist IDs are valid

## Features

✅ **Automatic Playlist Switching** - High-intensity and rest playlists  
✅ **Visual Progress Indicator** - Circular progress bar with color coding  
✅ **Timer Display** - Large, easy-to-read countdown timer  
✅ **Spotify Integration** - Real-time track information and controls  
✅ **Pause/Resume/Stop** - Full control over training sessions  
✅ **Secure Configuration** - Environment-based credential management
