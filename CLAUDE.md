# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
```bash
# Build the project
xcodebuild -scheme RunBeat -configuration Debug build

# Run tests
xcodebuild -scheme RunBeat -destination 'platform=iOS Simulator,name=iPhone 15' test

# Clean build
xcodebuild -scheme RunBeat clean
```

### Project Structure
- Main project: `RunBeat.xcodeproj`
- Scheme: `RunBeat`
- Deployment target: iOS 17.0+
- Dependencies: SpotifyiOS SDK (via SPM)

## Architecture Overview

RunBeat is an iOS heart rate training app built with **SwiftUI + MVVM architecture**. The app is designed for "phone-away" training with real-time audio announcements.

### Key Architectural Principles
- **Feature-based modules** in `Features/` directory
- **Design system** with reusable components in `UI/DesignSystem/`
- **Service layer** for external integrations (Bluetooth, Spotify)
- **Background execution** for continuous heart rate monitoring

### Critical Systems (DO NOT MODIFY)
- `HeartRateManager`: CoreBluetooth heart rate monitoring - working perfectly
- Background execution logic for continuous monitoring
- Audio announcement timing and cooldown system
- **Spotify architecture**: Recently refactored (Phase 1-4) with robust connection management, error recovery, and persistent authentication

### Core Modules

#### Heart Rate Module (`Features/HeartRate/`)
- `HeartRateManager.swift`: CoreBluetooth integration for HR monitoring
- `HeartRateZoneCalculator.swift`: Pure zone calculation logic
- `HeartRateViewModel.swift`: UI state and settings persistence

#### Core Services (`Core/Services/`)
- `HeartRateService.swift`: Shared HR processing and zone calculation service
- `ZoneAnnouncementCoordinator.swift`: Per-training-mode announcement management
- `SpeechAnnouncer.swift`: Audio announcement execution
- `AudioService.swift`: Audio session and volume management

#### Free Training Module (`Features/FreeTraining/`)
- `FreeTrainingManager.swift`: Simple background HR monitoring with announcements (replaces legacy HeartRateTrainingManager)
- **Uses shared services**: HeartRateService and ZoneAnnouncementCoordinator instead of duplicating logic

#### Spotify Module (`Features/Spotify/`)
- `SpotifyService.swift`: Core orchestration and business logic with centralized token refresh
- `SpotifyConnectionManager.swift`: Unified connection state management with background-aware error handling
- `SpotifyDataCoordinator.swift`: Intelligent data source prioritization
- `SpotifyErrorHandler.swift`: Structured error recovery with background execution support
- `SpotifyViewModel.swift`: UI state management with persistent authentication
- `KeychainWrapper.swift`: Secure token storage (eliminates repeated OAuth)
- **Token Management**: Centralized `makeAuthenticatedAPICall()` method handles automatic token refresh on 401 responses
- Features: Seamless training integration, reliable background playlist switching, automatic activation tracking

#### VO2 Training Module (`Features/VO2Training/`)
- `VO2MaxTrainingManager.swift`: 4x4 interval training coordination with shared HR services and Spotify reconnection observers
- `VO2MaxTrainingView.swift`: Training UI with design system integration
- **Spotify Integration**: Automatic music resumption when Spotify reconnects during training
- Features: Structured intervals, Spotify playlist switching, configurable zone announcements, phase-aware music recovery

### Design System (`UI/DesignSystem/`)
- `AppColors.swift`: Brand colors (primary: #FF4500)
- `AppTypography.swift`: Typography scales
- `AppSpacing.swift`: Spacing system
- `Components/`: Reusable UI components (AppButton, AppCard, etc.)

## Development Guidelines

### Threading Requirements
- UI updates MUST use `@MainActor` or `DispatchQueue.main.async`
- Background services handle their own threading
- ViewModels use `@Published` properties for reactive updates

### Design System Usage
- Always use design system components: `AppButton`, `AppCard`, `AppColors`, etc.
- Follow existing spacing patterns from `AppSpacing`
- Maintain dark theme consistency

### State Management
- **Dual Training Architecture**: Free Training and VO2 Max Training are independent modes
- **AppState**: Coordinates training mode mutual exclusion (only one active at a time)
- **Shared Services**: HeartRateService and ZoneAnnouncementCoordinator used by both training modes
- ViewModels manage UI state with `@Published` properties
- Services handle business logic and external integrations
- UserDefaults for settings persistence (preserve existing keys)

### Current Priority Issues
1. **Backend Service**: Add backend to handle Spotify OAuth and token management (planned)
2. **Apple Music Integration**: Consider adding as alternative to Spotify
3. **Live HR Display**: Add current BPM to training screens
4. **User Onboarding**: Guide new users through HR zone setup
5. **UI Polish**: Improve training mode descriptions and visual clarity

## Testing Requirements

### Physical Device Required
- Background modes don't work in iOS Simulator
- Heart rate monitoring requires real Bluetooth devices
- Spotify App Remote needs installed Spotify app

### Test Scenarios
- Start zone training → background app → verify announcements continue
- Start VO2 training → verify playlist switches at intervals (works reliably in background)
- Connect HR monitor → verify real-time updates
- Test audio announcements over music playback
- Background playlist switching during phone-away training sessions
- **Token Expiration Testing**: Leave app closed for 2+ hours → start VO2 training → verify graceful token refresh
- **Reconnection Testing**: Start training → force Spotify disconnect → verify music resumes when reconnected

## Configuration

### Required Setup
- Spotify credentials in `Config.plist` (Client ID, Secret, Redirect URI)
- Background modes in `Info.plist`: `bluetooth-central`, `audio`
- Heart rate zones: Auto-calculated via Karvonen formula or manual override

### Critical Files
- `Config.plist`: Spotify API configuration
- `runbeat.entitlements`: Background execution permissions
- `Info.plist`: Bluetooth usage descriptions and background modes

## Known Issues

### Recently Resolved
- ✅ **Token Expiration During Training**: Fixed with centralized token refresh and graceful error handling
- ✅ **Foreground Playlist Restart**: Fixed with training-aware foreground handling
- ✅ **Music Recovery After Reconnection**: Fixed with automatic Spotify reconnection observers

### Current Areas for Improvement
- **Spotify Token Management**: Client-only OAuth creates UX friction - backend service planned to resolve
- Live BPM not displayed during training screens
- User onboarding could be more guided for new users
- Apple Music integration not available (Spotify-only currently)

### Development Rules
- Never modify `HeartRateManager`'s core Bluetooth logic
- Preserve all background execution functionality (working reliably)
- Keep audio announcement timing unchanged
- **Spotify Architecture**: Recent improvements to token management and error handling - architecture is stable
- **Token Management**: Use `makeAuthenticatedAPICall()` for new Spotify API calls to get automatic token refresh
- Test on physical device for realistic behavior
- Use design system components consistently

## Recent Architecture Changes (2025)

### Spotify Token Management Improvements

**Problem Solved**: Expired Spotify tokens were causing training interruptions and opening Spotify app mid-session.

**Solutions Implemented**:
1. **Centralized Token Refresh** (`SpotifyService.makeAuthenticatedAPICall()`)
   - Automatically detects 401 responses
   - Refreshes tokens using existing refresh token
   - Retries original API call with new token
   - Gracefully disconnects if refresh fails

2. **Training-Aware Foreground Handling** (`SpotifyService.handleAppWillEnterForeground()`)
   - Prevents automatic playlist restart during active training sessions
   - Maintains music continuity when returning from background

3. **Spotify Reconnection Observers** (`VO2MaxTrainingManager.setupSpotifyReconnectionObserver()`)
   - Monitors Spotify connection state during training
   - Automatically resumes appropriate playlist when Spotify reconnects
   - Phase-aware music resumption (high intensity vs rest)
   - Proper observer cleanup on training completion

**API Calls Updated**: Track polling, playlist control, and playlist fetching now use centralized token management.

**Future Improvement**: Backend service planned to eliminate client-side token management complexity entirely.