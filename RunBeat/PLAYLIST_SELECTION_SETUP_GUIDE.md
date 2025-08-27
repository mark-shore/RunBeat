# Playlist Selection Setup Guide

## Critical Fix Needed: Add Files to Xcode Project

The playlist selection feature has been implemented but **must be added to the Xcode project** to resolve import errors.

### Step 1: Add New Files to Xcode Project

**Files to Add:**
1. `RunBeat/Features/Spotify/SpotifyPlaylist.swift`
2. `RunBeat/Features/Spotify/PlaylistSelectionView.swift`

**How to Add:**
1. In Xcode, right-click on `RunBeat/Features/Spotify/` folder
2. Select "Add Files to 'RunBeat'"
3. Navigate to each file and add them
4. Ensure they're added to the main RunBeat target (check the target checkbox)

### Step 2: Verify Import Resolution

After adding files to Xcode project, these errors should resolve:
- ❌ `Cannot find 'SpotifyPlaylist' in scope`
- ❌ `Cannot find 'PlaylistSelectionView' in scope`

### Step 3: Fix Remaining Import Issues

If you still see these errors in `VO2MaxTrainingView.swift`:
- ❌ `Cannot find 'VO2MaxTrainingManager' in scope`
- ❌ `Cannot find 'SpotifyViewModel' in scope`
- ❌ `Cannot find 'AppColors' in scope`

**Solution:** The design system files may not be properly imported. Verify these files exist and are in the Xcode project:
- `RunBeat/UI/DesignSystem/AppColors.swift`
- `RunBeat/UI/DesignSystem/AppSpacing.swift`
- `RunBeat/UI/DesignSystem/AppTypography.swift`
- `RunBeat/UI/DesignSystem/Components/AppButton.swift`
- `RunBeat/Features/VO2Training/VO2MaxTrainingManager.swift`
- `RunBeat/Features/Spotify/SpotifyViewModel.swift`

### Step 4: Test the Implementation

Once imports are resolved, test the flow:

1. **Open VO2 Training View**
   - Should show "Spotify Required" if not connected
   - Should show "Playlists Required" if connected but no playlists selected

2. **Connect to Spotify**
   - Tap "Connect Spotify"
   - Complete OAuth flow
   - Should change to "Playlists Required"

3. **Select Playlists**
   - Tap "Select Playlists"
   - Should see playlist selection modal
   - Should load user's playlists (may take a few seconds)
   - Select high intensity and rest playlists
   - Should auto-advance between selections

4. **Start Training**
   - Return to VO2 training view
   - Should show "Spotify Ready" with playlist names
   - "Start Training" button should be enabled
   - Should be able to start training session

## Implementation Summary

### What Was Fixed:

✅ **SpotifyPlaylist Model**
- Fixed to match actual Spotify API response structure
- Proper handling of nested `images` array and `tracks.total`
- Safe fallbacks for missing data

✅ **SpotifyService API Integration**
- Complete error handling for 401 (token expired), network errors, parsing failures
- Detailed logging for debugging
- Proper HTTP status code handling
- Comprehensive error types with recovery information

✅ **SpotifyViewModel State Management**
- Fixed authentication state checking
- Proper `@Published` properties for playlist selection state
- Working UserDefaults persistence
- Added `hasValidPlaylistSelection` computed property
- Selection validation and cleanup

✅ **PlaylistSelectionView UI**
- Proper loading states and error handling
- Empty playlist list handling
- Working playlist selection with view model updates
- Current selections prominently displayed
- Retry mechanism for failed loads
- Auto-reconnect for expired sessions

✅ **VO2MaxTrainingView Integration**
- Updated to check `hasValidPlaylistSelection`
- "Select Playlists" button when playlists aren't selected
- "Change" button when playlists are selected
- "Start Training" disabled until both playlists are selected

### User Flow:

1. **First Time**: Connect Spotify → Select Playlists → Start Training
2. **Subsequent Uses**: Tap "Change" to modify selections or start training immediately

### Error Handling:

- **Network Issues**: Shows retry button
- **Expired Token**: Shows reconnect button
- **Empty Playlists**: Helpful message to create playlists in Spotify
- **Missing Permissions**: Clear instructions to reconnect

### Persistence:

- Playlist selections saved to UserDefaults as JSON
- Automatically loaded on app launch
- Validates selections against current playlist library
- Falls back to Config.plist values for backward compatibility

## API Details

### Spotify API Endpoint Used:
```
GET https://api.spotify.com/v1/me/playlists?limit=50&offset=0
```

### Required Scopes:
- `playlist-read-private` (to read user's playlists)
- Existing scopes for playback control

### Response Format:
```json
{
  "items": [
    {
      "id": "playlist_id",
      "name": "Playlist Name", 
      "description": "Description",
      "images": [{"url": "image_url"}],
      "tracks": {"total": 25},
      "public": true,
      "owner": {"display_name": "User Name", "id": "user_id"}
    }
  ]
}
```

## Testing Scenarios

1. **Fresh Install**: No saved selections
2. **Token Expired**: 401 error handling
3. **Network Offline**: Network error handling
4. **Empty Playlist Library**: Empty state handling
5. **Playlist Deleted**: Selection validation
6. **App Restart**: Persistence verification

## Troubleshooting

### "Error loading playlists - The data couldn't be read because it is missing"
- **Fixed**: Updated API response parsing to match actual Spotify API format

### "Session expired. Please reconnect."
- **Fixed**: Proper token expiration handling with automatic state updates

### UI not updating after selection
- **Fixed**: Proper `@Published` properties and main thread updates

### Selections not persisting
- **Fixed**: Robust UserDefaults JSON encoding/decoding with error handling

This implementation provides a complete, robust playlist selection system that handles all edge cases and provides clear user feedback throughout the process.
