# Playlist Selection Implementation for VO2 Max Training

## Overview

This implementation adds playlist selection functionality to the VO2 Max training feature, allowing users to choose their own Spotify playlists for high-intensity and rest intervals instead of relying on hardcoded playlist IDs.

## Files Added/Modified

### New Files Created

1. **`RunBeat/Features/Spotify/SpotifyPlaylist.swift`**
   - Data models for Spotify playlist information
   - API response parsing structures
   - Playlist selection storage model

2. **`RunBeat/Features/Spotify/PlaylistSelectionView.swift`**
   - SwiftUI view for playlist selection interface
   - Grid-based playlist display with selection
   - Connection status and error handling

### Modified Files

1. **`RunBeat/Features/Spotify/SpotifyService.swift`**
   - Added `fetchUserPlaylists()` method
   - Added error handling for playlist API calls
   - Extended with playlist management functionality

2. **`RunBeat/Features/Spotify/SpotifyViewModel.swift`**
   - Added playlist management state
   - Added playlist selection persistence via UserDefaults
   - Updated training methods to use selected playlists

3. **`RunBeat/Features/VO2Training/VO2MaxTrainingView.swift`**
   - Updated Spotify status section to require playlist selection
   - Added playlist selection sheet presentation
   - Added training validation to ensure playlists are configured

## Key Features

### 1. Playlist Fetching
- Fetches user's Spotify playlists via Web API
- Handles authentication and error states
- Displays playlist metadata (name, track count, description)

### 2. Playlist Selection Interface
- Clean, grid-based playlist selection UI
- Separate selection for high-intensity and rest playlists
- Visual indicators for selection status
- Auto-advance to next selection step

### 3. Persistent Storage
- Stores playlist selections in UserDefaults
- Automatically loads saved selections on app launch
- Fallback to Config.plist values for backward compatibility

### 4. Training Integration
- Requires playlist selection before starting VO2 training
- Shows current selections in training view
- Allows changing selections via "Change" button
- Seamless integration with existing training flow

## Setup Instructions

### 1. Add Files to Xcode Project

The following new files need to be added to the Xcode project:

```
RunBeat/Features/Spotify/SpotifyPlaylist.swift
RunBeat/Features/Spotify/PlaylistSelectionView.swift
```

**Steps:**
1. Right-click on `RunBeat/Features/Spotify/` in Xcode
2. Select "Add Files to 'RunBeat'"
3. Navigate to the files and add them
4. Ensure they're added to the main target

### 2. Required Spotify Scopes

Ensure your Spotify app configuration includes the `playlist-read-private` scope:

```swift
let scopes: SPTScope = [
    .playlistReadPrivate,  // <- This is required for playlist fetching
    .userReadPlaybackState,
    .userModifyPlaybackState,
    .userReadCurrentlyPlaying,
    .streaming,
    .appRemoteControl
]
```

### 3. API Permissions

The implementation uses the Spotify Web API to fetch playlists. Make sure your Spotify Developer App has the correct permissions and your access token includes the required scopes.

## User Flow

### First Time Setup
1. User opens VO2 Max Training
2. Sees "Spotify Required" status if not connected
3. Taps "Connect Spotify" and completes OAuth flow
4. Sees "Playlists Required" status
5. Taps "Select Playlists" to open playlist selection
6. Selects high-intensity playlist from grid
7. Automatically advances to rest playlist selection
8. Selects rest playlist
9. Returns to training view with "Spotify Ready" status
10. Can now start training

### Subsequent Uses
1. User opens VO2 Max Training
2. Sees "Spotify Ready" with selected playlist names
3. Can tap "Change" to modify selections
4. Can immediately start training

## Technical Details

### Playlist Data Structure

```swift
struct SpotifyPlaylist: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let trackCount: Int
    let imageURL: String?
    let isPublic: Bool
    let owner: String
}
```

### Selection Storage

```swift
struct PlaylistSelection: Codable {
    var highIntensityPlaylistID: String?
    var restPlaylistID: String?
    
    var isComplete: Bool {
        return highIntensityPlaylistID != nil && restPlaylistID != nil
    }
}
```

### State Management

The `SpotifyViewModel` manages:
- `availablePlaylists: [SpotifyPlaylist]` - Fetched user playlists
- `playlistSelection: PlaylistSelection` - Current selections
- `playlistFetchStatus: PlaylistFetchStatus` - Loading/error states

### Persistence

Playlist selections are stored in UserDefaults with the key `"SpotifyPlaylistSelection"` as JSON data.

## Error Handling

### Connection Errors
- Shows "Connect Spotify" button if not authenticated
- Displays connection status and error messages

### Playlist Fetch Errors
- Shows loading indicator during fetch
- Displays error messages with retry button
- Handles empty playlist scenarios

### Training Validation
- Disables "Start Training" button until playlists are selected
- Shows clear status indicators for missing requirements

## Design System Integration

All UI components use the established RunBeat design system:
- `AppColors` for consistent color palette
- `AppTypography` for text styles
- `AppSpacing` for layout spacing
- `AppButton` and `AppCard` components

## Backward Compatibility

The implementation maintains backward compatibility with existing Config.plist playlist configurations:

```swift
func playHighIntensityPlaylist() {
    let playlistID = playlistSelection.highIntensityPlaylistID ?? 
                    configurationManager.spotifyHighIntensityPlaylistID
    spotifyService.playHighIntensityPlaylist(playlistID: playlistID)
}
```

## Testing Considerations

### Manual Testing Steps
1. Test playlist fetching with various account states
2. Verify selection persistence across app restarts
3. Test error handling with network issues
4. Verify training flow with selected playlists
5. Test fallback to Config.plist values

### Recommended Test Data
- Account with 0 playlists
- Account with 1-5 playlists
- Account with 50+ playlists
- Playlists with special characters in names
- Private vs public playlists

## Future Enhancements

### Potential Improvements
1. **Playlist Filtering**: Filter by tempo, genre, or energy level
2. **Playlist Preview**: Play snippet before selection
3. **Smart Recommendations**: Suggest playlists based on BPM
4. **Playlist Creation**: Create playlists directly from the app
5. **Multiple Selections**: Allow multiple playlists per phase

### Performance Optimizations
1. **Caching**: Cache playlist data locally
2. **Pagination**: Handle large playlist collections
3. **Image Loading**: Optimize playlist artwork loading

## Troubleshooting

### Common Issues

**"Cannot find 'SpotifyPlaylist' in scope"**
- Ensure `SpotifyPlaylist.swift` is added to Xcode project
- Check target membership

**"No playlists found"**
- Verify Spotify app has `playlist-read-private` scope
- Check user has created playlists in Spotify

**"Playlists not saving"**
- Verify UserDefaults permissions
- Check JSON encoding/decoding in playlist selection

**Training won't start**
- Ensure both playlists are selected
- Check `hasPlaylistsConfigured` computed property
- Verify Spotify connection status

This implementation provides a complete playlist selection system that enhances the VO2 Max training experience while maintaining the app's design consistency and user-friendly approach.
