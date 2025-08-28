# AI Assistant Context for RunBeat

## What You're Working On
Audio-first iOS heart rate training app. Users start workout, put phone away, get audio cues.

## Current Project State
✅ **Stable & Production Ready**:
- Heart rate monitoring with CoreBluetooth
- Background execution for phone-away training  
- Audio announcements during training
- **Spotify integration** - fully refactored with persistent auth, unified state management, error recovery

## Current Priorities
1. **Apple Music Integration** - Consider adding as alternative to Spotify
2. **Live HR Display** - Show current BPM on training screens
3. **UI Polish** - Training mode descriptions and visual improvements
4. **User Onboarding** - Guide new users through setup

## Don't Touch (Working Perfectly)
- `HeartRateManager.swift` - CoreBluetooth heart rate monitoring
- Background execution logic for continuous monitoring
- Audio announcement timing and cooldown system
- **Spotify architecture** - recently refactored and stable

## Spotify Integration Status
✅ **Solid Architecture** (Phase 1-4 refactor complete):
- `SpotifyConnectionManager` - unified state management
- `SpotifyDataCoordinator` - intelligent data source prioritization  
- `SpotifyErrorHandler` - structured error recovery
- `KeychainWrapper` - persistent authentication (no repeated OAuth)
- Training integration works seamlessly without music interruption

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
- **Heart Rate**: Pure CoreBluetooth with background execution
- **Spotify**: Modular design with connection/data/error components
- **Training**: Coordinates HR monitoring with music control
- **UI**: Design system with `AppColors`, `AppTypography`, `AppButton`, etc.

## Development Tips
- Use design system components consistently
- Test on physical device for background modes
- Check Console app for background execution logs
- Spotify testing requires installed app and premium account