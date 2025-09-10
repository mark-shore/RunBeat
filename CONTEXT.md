# AI Assistant Context for RunBeat

## What You're Working On
Audio-first iOS heart rate training app. Users start workout, put phone away, get audio cues.

## Current Project State
✅ **Stable & Production Ready**:
- **User-scoped authentication** - Firebase anonymous auth with backend integration
- Heart rate monitoring with CoreBluetooth and shared services architecture
- **Dual training mode system** with mutual exclusion (Free Training + VO2 Max Training)
- **Shared services** eliminate code duplication: HeartRateService + ZoneAnnouncementCoordinator
- Background execution for phone-away training  
- Audio announcements during training with per-mode controls
- **Spotify integration** - fully refactored with centralized token refresh, reconnection observers, and training-aware foreground handling
- **User-scoped backend service** - FastAPI backend with user-based endpoints and automatic background token refresh
- **Playlist restart fix** - eliminated automatic music interruptions when switching between apps

## Current Priorities
1. **Training Analytics** - Add workout history and performance tracking
2. **UI Polish** - Training mode descriptions and visual improvements
3. **User Onboarding** - Guide new users through setup
4. **Apple Music Integration** - Consider adding as alternative to Spotify

## Don't Touch (Working Perfectly)
- `HeartRateManager.swift` - CoreBluetooth heart rate monitoring
- **Shared services architecture** - HeartRateService and ZoneAnnouncementCoordinator working reliably
- **Dual training mode coordination** - AppState mutual exclusion system
- Background execution logic for continuous monitoring
- Audio announcement timing and cooldown system
- **User-scoped authentication** - Firebase anonymous auth with automatic user ID propagation
- **Spotify architecture** - intent-based lifecycle management, centralized token refresh, reconnection observers, training-aware handling
- **User-scoped backend service** - FastAPI backend with user-based endpoints, automatic background token refresh, and Railway deployment
- **Playlist restart elimination** - App switching no longer interrupts music playback

## User-Scoped Architecture Status
✅ **Production-Ready User-Scoped System**:
- `FirebaseService.swift` - Firebase anonymous authentication with automatic user creation
- `BackendService.swift` - User-aware iOS client with intelligent token caching based on app lifecycle
- FastAPI backend with user-scoped endpoints: `/api/v1/users/{user_id}/spotify-tokens`
- Background token refresh service runs server-side every 15 minutes for all users
- Railway deployment with user-based admin endpoints for monitoring
- Token caching: 1 backend call on startup/foreground, 0 calls during active sessions
- Offline fallback with keychain storage when backend unavailable
- Seamless user ID propagation from Firebase → Backend → Firestore

## Spotify Integration Status
✅ **Production-Ready Architecture** with Recent Improvements:
- `SpotifyConnectionManager` - unified state management with background-aware error handling
- `SpotifyDataCoordinator` - intelligent data source prioritization  
- `SpotifyErrorHandler` - structured error recovery with background execution support
- `KeychainWrapper` - persistent authentication (no repeated OAuth)
- **Centralized Token Refresh** - `makeAuthenticatedAPICall()` handles automatic token refresh on 401s
- **Playlist Restart Elimination** - App switching no longer interrupts music playback
- **User-Scoped Backend Integration** - Seamless Firebase user ID → backend user endpoints with automatic fallback
- Training integration works seamlessly in foreground and background
- Background playlist switching reliable during phone-away workouts

## Testing Requirements
- Background modes need physical device testing
- Firebase anonymous auth testing requires clean app installs
- Spotify requires premium account for full functionality
- UI updates must use main thread (`@MainActor` or `DispatchQueue.main.async`)
- Test untethered from Xcode for realistic background behavior
- User-scoped testing: verify user ID propagation through Firebase → Backend → Firestore

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
- **Spotify**: Intent-based architecture with SpotifyIntent enum controls lifecycle, AppState bridging eliminates dual ownership patterns, centralized error recovery respects training context
- **Training**: Two independent modes using shared services for consistent HR processing
- **UI**: Design system with `AppColors`, `AppTypography`, `AppButton`, etc.

## Development Tips
- **Shared Services**: Use HeartRateService and ZoneAnnouncementCoordinator for consistent HR processing
- **Training Modes**: Only one can be active at a time - check AppState.activeTrainingMode
- **User-Scoped Backend**: Use `BackendService.shared.getFreshSpotifyToken()` for user-aware token management
- **Firebase Auth**: User ID automatically propagated to backend on authentication
- **Spotify API Calls**: Use `makeAuthenticatedAPICall()` for automatic token refresh on new endpoints
- **Token Caching**: Backend tokens cached intelligently based on app lifecycle - check cache status
- **Background Token Refresh**: Server-side service automatically refreshes user tokens every 15 minutes
- Use design system components consistently
- Test on physical device for background modes
- Check Console app for backend token requests and caching behavior
- Spotify testing requires installed app and premium account
- Test dual training mode mutual exclusion scenarios
- Test app switching scenarios to verify no playlist interruptions