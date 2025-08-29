# Backend Integration Test Guide

This guide outlines how to test the FastAPI backend integration with the RunBeat iOS app for Spotify token management.

## Prerequisites

1. **Backend Service Running**
   ```bash
   cd backend
   source venv/bin/activate
   uvicorn main:app --host 0.0.0.0 --port 8001 --reload
   ```

2. **Device Setup**
   - iOS device or simulator with RunBeat app
   - Backend URL configured in Config.plist: `http://localhost:8001`
   - Spotify app installed on device (for App Remote functionality)

## Test Scenarios

### 1. Device ID Generation and Persistence

**Test**: Device ID is generated and persists across app launches

**Steps**:
1. Fresh app install or reset simulator
2. Launch RunBeat app
3. Check device ID is generated: `DeviceIDManager.shared.deviceID`
4. Force close app and relaunch
5. Verify same device ID is used

**Expected**: Device ID remains consistent across app launches

**Debug**: Add logging to DeviceIDManager to verify UUID generation and persistence

### 2. OAuth Token Storage to Backend

**Test**: Tokens are sent to backend after successful Spotify OAuth

**Steps**:
1. In RunBeat app, navigate to Spotify settings
2. Tap "Connect to Spotify"
3. Complete OAuth flow in Spotify app/web
4. Monitor backend logs for token storage
5. Verify tokens are stored in Firebase via admin endpoint

**Expected**: 
- Backend logs show: "Storing Spotify tokens for device [device_id]"
- Admin endpoint shows tokens stored: `GET /api/v1/admin/token-overview`

**Backend Verification**:
```bash
curl http://localhost:8001/api/v1/admin/token-overview
```

### 3. Backend Token Retrieval

**Test**: App gets fresh tokens from backend instead of local refresh

**Steps**:
1. Complete OAuth and ensure tokens are stored in backend
2. Wait for token to approach expiration (or manually trigger refresh)
3. Make a Spotify API call (play playlist, get current track)
4. Monitor logs for backend token retrieval

**Expected**:
- iOS logs show: "Using fresh token from backend for API call"
- Backend logs show: "Getting Spotify token for device [device_id]"
- No local token refresh attempts

### 4. Background Playlist Switching

**Test**: Playlist switching works during VO2 training with backend tokens

**Critical Test**: This is the core use case - ensure background music control works

**Steps**:
1. Complete Spotify OAuth integration
2. Start VO2 Max training session
3. Background the app (home button or app switcher)
4. Wait for interval transitions (high intensity ↔ rest)
5. Verify playlists switch automatically in background
6. Monitor token usage during background operations

**Expected**:
- Background playlist switches occur at correct intervals
- Backend provides fresh tokens for playlist control
- No token expiration errors during training

**Debug Commands**:
```bash
# Monitor backend token requests during training
tail -f backend_logs.txt | grep "spotify-token"

# Check token refresh activity
curl http://localhost:8001/api/v1/admin/refresh-status
```

### 5. Offline/Network Error Handling

**Test**: App falls back to local token refresh when backend unavailable

**Steps**:
1. Complete OAuth with backend available
2. Stop backend service
3. Wait for token to expire
4. Attempt Spotify operations
5. Verify local token refresh fallback works

**Expected**:
- iOS logs show: "Backend unavailable, attempting local token refresh fallback"
- Local Spotify token refresh succeeds
- Music operations continue working

### 6. Network Resilience Testing

**Test**: App handles intermittent network connectivity

**Steps**:
1. Start training with backend available
2. Simulate network interruption (airplane mode, disconnect WiFi)
3. Re-enable network after 30 seconds
4. Continue training and verify playlist switching

**Expected**:
- App continues using cached/local tokens during network outage
- Resumes backend token usage when network returns
- No interruption to music playback

### 7. Token Cleanup on Logout

**Test**: Tokens are removed from backend when user logs out

**Steps**:
1. Complete OAuth integration
2. Navigate to Spotify settings in app
3. Tap "Disconnect" or "Logout"
4. Verify tokens are deleted from backend

**Expected**:
- Backend logs show: "Deleting Spotify tokens for device [device_id]"
- Admin endpoint shows no tokens for device

**Verification**:
```bash
curl http://localhost:8001/api/v1/admin/token-overview
```

## Integration Point Checklist

### ✅ DeviceIDManager Integration
- [ ] Device UUID generation works
- [ ] Device ID persists across app launches
- [ ] UserDefaults fallback works correctly

### ✅ BackendService Integration  
- [ ] HTTP communication with FastAPI works
- [ ] Token storage API calls succeed
- [ ] Token retrieval API calls succeed
- [ ] Network error handling works
- [ ] Retry logic functions correctly

### ✅ SpotifyService Integration
- [ ] Tokens sent to backend after OAuth
- [ ] makeAuthenticatedAPICall() uses backend tokens
- [ ] Fallback to local tokens when backend unavailable
- [ ] Local token refresh works as fallback
- [ ] Background operations use backend tokens

### ✅ Configuration Integration
- [ ] Backend URL loaded from Config.plist
- [ ] URL can be changed for different environments

### ✅ Background Functionality
- [ ] VO2 training playlist switching works
- [ ] Background token refresh maintains session
- [ ] No token expiration during training
- [ ] Playlist control works phone-away

## Debug Tools

### Backend Admin Endpoints
```bash
# System health
curl http://localhost:8001/api/v1/admin/system-health

# Token overview  
curl http://localhost:8001/api/v1/admin/token-overview

# Refresh system status
curl http://localhost:8001/api/v1/admin/refresh-status

# Trigger manual refresh
curl -X POST http://localhost:8001/api/v1/admin/refresh-trigger
```

### iOS Debug Logging
Add these debug statements to key integration points:

```swift
// In DeviceIDManager
print("🆔 Device ID: \(deviceID)")

// In BackendService  
print("🌐 Backend request: \(request.httpMethod ?? "GET") \(url)")
print("🌐 Backend response: \(httpResponse.statusCode)")

// In SpotifyService
print("🎵 Token source: \(tokenSource)")
print("🎵 Background operation: \(isBackgroundMode)")
```

## Success Criteria

The integration is successful if:

1. **Token Management**: All Spotify tokens are managed by backend with local fallback
2. **Background Reliability**: VO2 training playlist switching works seamlessly in background
3. **Network Resilience**: App handles backend outages gracefully
4. **Performance**: No noticeable delay in token operations
5. **Security**: Sensitive token refresh handled server-side

## Troubleshooting Common Issues

### Backend Connection Issues
- Verify backend is running on correct port (8001)
- Check backend URL in Config.plist
- Test backend health endpoint
- Review backend service logs

### Token Refresh Failures  
- Check backend Firebase configuration
- Verify Spotify API credentials
- Review backend token refresh logs
- Test manual token refresh

### Background Playlist Issues
- Ensure background modes are enabled
- Verify Spotify app is installed and logged in
- Check iOS background app refresh settings
- Review playlist switching logs

### Integration Testing
- Use iOS Simulator for rapid iteration
- Test on physical device for background modes
- Monitor both iOS and backend logs simultaneously
- Test various network conditions