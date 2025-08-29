# AI Assistant Context for RunBeat

## What You're Working On
Audio-first iOS heart rate training app. Users start workout, put phone away, get audio cues.

## Current Project State
✅ **Stable & Production Ready**:
- Heart rate monitoring with CoreBluetooth and shared services architecture
- **Dual training mode system** with mutual exclusion (Free Training + VO2 Max Training)
- **Shared services** eliminate code duplication: HeartRateService + ZoneAnnouncementCoordinator
- Background execution for phone-away training  
- Audio announcements during training with per-mode controls
- **Spotify integration** - fully refactored with centralized token refresh, reconnection observers, and training-aware foreground handling
- **Backend service** - FastAPI backend with Railway deployment for centralized token management
- **Playlist restart fix** - eliminated automatic music interruptions when switching between apps

## Current Priorities
1. **Apple Music Integration** - Consider adding as alternative to Spotify
2. **Live HR Display** - Show current BPM on training screens
3. **Training Analytics** - Add workout history and performance tracking
4. **UI Polish** - Training mode descriptions and visual improvements
5. **User Onboarding** - Guide new users through setup

## Don't Touch (Working Perfectly)
- `HeartRateManager.swift` - CoreBluetooth heart rate monitoring
- **Shared services architecture** - HeartRateService and ZoneAnnouncementCoordinator working reliably
- **Dual training mode coordination** - AppState mutual exclusion system
- Background execution logic for continuous monitoring
- Audio announcement timing and cooldown system
- **Spotify architecture** - centralized token refresh, reconnection observers, training-aware handling
- **Backend service** - FastAPI backend with intelligent token caching and Railway deployment
- **Playlist restart elimination** - App switching no longer interrupts music playback

## Backend Integration Status
✅ **Production-Ready Backend Service**:
- `BackendService.swift` - iOS client with intelligent token caching based on app lifecycle
- `DeviceIDManager.swift` - consistent device identification for multi-device token management  
- FastAPI backend with Firebase token storage and automatic refresh scheduling
- Railway deployment with admin endpoints for monitoring and management
- Token caching: 1 backend call on startup/foreground, 0 calls during active sessions
- Offline fallback with keychain storage when backend unavailable

## Spotify Integration Status
✅ **Production-Ready Architecture** with Recent Improvements:
- `SpotifyConnectionManager` - unified state management with background-aware error handling
- `SpotifyDataCoordinator` - intelligent data source prioritization  
- `SpotifyErrorHandler` - structured error recovery with background execution support
- `KeychainWrapper` - persistent authentication (no repeated OAuth)
- **Centralized Token Refresh** - `makeAuthenticatedAPICall()` handles automatic token refresh on 401s
- **Playlist Restart Elimination** - App switching no longer interrupts music playback
- **Backend Token Integration** - Seamless backend/local token coordination with automatic fallback
- Training integration works seamlessly in foreground and background
- Background playlist switching reliable during phone-away workouts

## Common Issues
- Background modes need physical device testing
- Spotify requires premium account for full functionality
- UI updates must use main thread (`@MainActor` or `DispatchQueue.main.async`)
- Test untethered from Xcode for realistic background behavior

## Tech Stack
- SwiftUI + MVVM architecture
- CoreBluetooth for HR monitoring
- SpotifyiOS SDK with Web API fallback
- Keychain for secure token storage
- UserDefaults for settings persistence
- Combine for reactive state management

## Architecture Notes
- **Shared Services Pattern**: HeartRateService + ZoneAnnouncementCoordinator eliminate duplication between training modes
- **Dual Training Architecture**: AppState coordinates mutual exclusion between Free Training and VO2 Max Training
- **Heart Rate**: Pure CoreBluetooth with shared processing service and background execution
- **Spotify**: Modular design with centralized token refresh and automatic reconnection
- **Training**: Two independent modes using shared services for consistent HR processing
- **UI**: Design system with `AppColors`, `AppTypography`, `AppButton`, etc.

## Development Tips
- **Shared Services**: Use HeartRateService and ZoneAnnouncementCoordinator for consistent HR processing
- **Training Modes**: Only one can be active at a time - check AppState.activeTrainingMode
- **Backend Integration**: Use `BackendService.shared.getFreshSpotifyToken()` for centralized token management
- **Spotify API Calls**: Use `makeAuthenticatedAPICall()` for automatic token refresh on new endpoints
- **Token Caching**: Backend tokens cached intelligently based on app lifecycle - check cache status
- Use design system components consistently
- Test on physical device for background modes
- Check Console app for backend token requests and caching behavior
- Spotify testing requires installed app and premium account
- Test dual training mode mutual exclusion scenarios
- Test app switching scenarios to verify no playlist interruptions