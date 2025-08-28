# Spotify Setup Guide

Get your RunBeat app connected to Spotify for seamless music control during VO2 Max training sessions.

## What You'll Need

- **Spotify Premium account** (required for music control)
- **10 minutes** to set up your developer credentials
- **Your favorite workout playlists** (or we'll help you create them)

## Quick Setup Steps

### 1. Create Your Spotify Developer App

1. Visit [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Click **"Create App"**
3. Fill out the form:
   - **App name**: `RunBeat`
   - **App description**: `Heart rate training with music`
   - **Redirect URI**: `runbeat://spotify-login-callback`
   - **API/SDKs**: Check both "iOS SDK" and "Web Playback SDK"
4. Click **"Save"**

### 2. Get Your App Credentials

1. Copy your **Client ID** (visible on your app dashboard)
2. Click **"Show client secret"** and copy your **Client Secret**
3. Keep these handy for the next step

### 3. Add Credentials to RunBeat

1. In your RunBeat project, copy `Config.sample.plist` to `Config.plist`
2. Replace the placeholder values with your real credentials:

```xml
<key>spotifyClientID</key>
<string>your_client_id_here</string>
<key>spotifyClientSecret</key>
<string>your_client_secret_here</string>
```

## 4. Using RunBeat with Spotify

### First Time Setup
1. **Launch RunBeat** and navigate to **VO₂ Max Training**
2. **Connect Spotify**: Tap the Connect button and log in with your Premium account
3. **Choose Your Music**: Select playlists for high-intensity and rest intervals
   - **High-intensity**: Pick energetic playlists (rock, electronic, hip-hop)
   - **Rest intervals**: Choose calmer music (ambient, acoustic, downtempo)
4. **You're ready!** Your playlist choices are saved for future workouts

### How Training Works
RunBeat automatically manages your music during VO₂ Max intervals:

**🔥 4 minutes high-intensity** → Your energetic playlist plays  
**😌 3 minutes rest** → Your calm playlist plays  
**Repeat 4 times** for a complete 28-minute workout

### What You'll Experience
✅ **Seamless music switching** between workout phases  
✅ **Background playback** continues when you put your phone away  
✅ **Persistent login** - authenticate once, train anytime  
✅ **Your music, your way** - use any playlists you want

## Troubleshooting

**Connection issues?**  
- Double-check your Client ID and Client Secret in `Config.plist`
- Make sure you have Spotify Premium (free accounts won't work)
- Verify the redirect URI is exactly: `runbeat://spotify-login-callback`

**Can't select playlists?**  
- Ensure you're logged into Spotify first
- Make sure you have playlists in your Spotify account
- Try disconnecting and reconnecting if needed

**No music during workouts?**  
- Install the Spotify app on your device
- Check that your selected playlists have songs
- Verify your Premium subscription is active

## Tips for Great Workouts

🎵 **Playlist Ideas**:
- **High-intensity**: Electronic, rock, hip-hop with driving beats
- **Rest periods**: Ambient, acoustic, or downtempo music

🔄 **Change anytime**: Swap playlists from the VO₂ Max Training screen

📱 **Background ready**: Music continues when you put your phone away and focus on training

---

*Ready to train? Your heart rate zones and Spotify playlists will work together to power your best workouts yet.*