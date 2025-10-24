# AI Assistant Context for RunBeat

## What You're Working On
Audio-first iOS heart rate training app. Users start workout, put phone away, get audio cues.

## Current Project State
✅ **Stable & Production Ready**:
- **Apple Music Integration** - Full MusicKit integration for VO2 Max training with playlist switching
- **Firebase Anonymous Auth** - Automatic user creation and management (no backend needed)
- Heart rate monitoring with CoreBluetooth and shared services architecture
- **Dual training mode system** with mutual exclusion (Free Training + VO2 Max Training)
- **Shared services** eliminate code duplication: HeartRateService + ZoneAnnouncementCoordinator
- Background execution for phone-away training
- **Instant zone announcements** - Pre-warmed AVAudioPlayer eliminates 4-5 second delay
- Audio announcements during training with per-mode controls
- Structured logging with AppLogger (rate limiting, environment-aware levels)

## Current Priorities
1. **Training Analytics** - Add workout history and performance tracking
2. **UI Polish** - Training mode descriptions and visual improvements
3. **User Onboarding** - Guide new users through setup

## Don't Touch (Working Perfectly)
- `HeartRateManager.swift` - CoreBluetooth heart rate monitoring
- **Shared services architecture** - HeartRateService and ZoneAnnouncementCoordinator working reliably
- **Dual training mode coordination** - AppState mutual exclusion system
- Background execution logic for continuous monitoring
- **Zone announcement pre-warming** - SpeechAnnouncer initializes AVAudioPlayer on app launch
- Audio announcement timing and cooldown system
- **Apple Music integration** - MusicKitService with audio session configuration for proper ducking
- **Firebase anonymous auth** - Automatic user creation with no backend required

## Apple Music Integration Status
✅ **Production-Ready Architecture**:
- `MusicKitService.swift` - Full Apple Music API integration with authorization, playlist fetching, playback control
- `MusicViewModel.swift` - ViewModel with playlist selection and persistence
- `MusicPlaylist` model - Data structures for Apple Music library playlists
- VO2 Max Training integration - Automatic playlist switching between high intensity and rest
- **Audio session configuration** - `.mixWithOthers` and `.duckOthers` for proper zone announcement ducking
- Play/pause controls during training and completion screens
- Persistent playlist selection via UserDefaults

## Testing Requirements
- Background modes need physical device testing
- Firebase anonymous auth testing requires clean app installs
- **Apple Music requires Apple Music subscription** for playlist playback
- UI updates must use main thread (`@MainActor` or `DispatchQueue.main.async`)
- Test untethered from Xcode for realistic background behavior
- Test zone announcements duck music properly during VO2 training

## Tech Stack
- SwiftUI + MVVM architecture
- CoreBluetooth for HR monitoring
- **MusicKit for Apple Music integration**
- Firebase (anonymous auth only)
- UserDefaults for settings persistence
- Combine for reactive state management
- **AppLogger for structured logging**

## Architecture Notes
- **Shared Services Pattern**: HeartRateService + ZoneAnnouncementCoordinator eliminate duplication between training modes
- **Dual Training Architecture**: AppState coordinates mutual exclusion between Free Training and VO2 Max Training
- **Heart Rate**: Pure CoreBluetooth with shared processing service and background execution
- **Apple Music**: MusicKit integration with ApplicationMusicPlayer for library playlist playback
- **Training**: Two independent modes using shared services for consistent HR processing
- **UI**: Design system with `AppColors`, `AppTypography`, `AppButton`, etc.
- **Logging**: AppLogger with rate limiting, environment-aware levels (VERBOSE in debug, INFO in production)

## Development Tips
- **Shared Services**: Use HeartRateService and ZoneAnnouncementCoordinator for consistent HR processing
- **Training Modes**: Only one can be active at a time - check AppState.activeTrainingMode
- **Apple Music**: Use MusicViewModel for playlist selection and playback control
- **Logging**: Use AppLogger instead of print() - appropriate log levels (ERROR, WARN, INFO, DEBUG, VERBOSE)
- **Zone Announcements**: Pre-warmed in SpeechAnnouncer.init() for instant playback
- Use design system components consistently
- Test on physical device for background modes
- Test dual training mode mutual exclusion scenarios
- Verify zone announcements duck Apple Music properly
