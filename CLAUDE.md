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
- **Spotify architecture**: Recently refactored (Phase 1-6) with intent-based lifecycle management, robust connection management, error recovery, and persistent authentication

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
- `BackendService.swift`: FastAPI backend integration with intelligent token caching
- `DeviceIDManager.swift`: Consistent device identification for backend communication
- `AppLogger.swift`: Centralized logging system with rate limiting and structured output

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
- **Intent-Based Architecture**: SpotifyIntent enum (.training, .idle, .background) controls AppRemote lifecycle and eliminates wasteful background reconnection cycles
- **AppState Bridging**: Moved from direct trainingManager access in views to AppState-mediated access, eliminating dual ownership patterns
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
1. **Apple Music Integration**: Consider adding as alternative to Spotify
2. **Live HR Display**: Add current BPM to training screens
3. **User Onboarding**: Guide new users through HR zone setup
4. **UI Polish**: Improve training mode descriptions and visual clarity
5. **Training Analytics**: Add workout history and performance tracking

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
- **App Switching Testing**: Start training → switch to Spotify briefly → return to RunBeat → verify music continues uninterrupted
- **Backend Integration Testing**: Monitor backend token caching and refresh cycles

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
- ✅ **Playlist Restart Interruptions**: Fixed automatic playlist restarts when switching between apps
- ✅ **Backend Service Integration**: Implemented FastAPI backend with intelligent token caching and Railway deployment
- ✅ **Logging System Overhaul**: Replaced 642+ print statements with structured AppLogger system featuring rate limiting and environment-aware log levels

### Current Areas for Improvement
- Live BPM not displayed during training screens
- User onboarding could be more guided for new users
- Apple Music integration not available (Spotify-only currently)
- Training analytics and workout history tracking

### Logging Guidelines
- **Use AppLogger instead of print()**: All logging should use `AppLogger` with appropriate log levels
- **Log Levels**: ERROR (production issues), WARN (recoverable issues), INFO (key events), DEBUG (development info), VERBOSE (detailed debugging)
- **Rate Limiting**: AppLogger automatically prevents spam with 5-second rate limiting windows
- **Specialized Methods**: Use `AppLogger.playerState()` for Spotify state, `AppLogger.apiResponse()` for API calls
- **Environment Aware**: Production defaults to INFO level, debug builds use VERBOSE

### Development Rules
- Never modify `HeartRateManager`'s core Bluetooth logic
- Preserve all background execution functionality (working reliably)
- Keep audio announcement timing unchanged
- **Spotify Architecture**: Recent improvements to token management and error handling - architecture is stable
- **Token Management**: Use `makeAuthenticatedAPICall()` for new Spotify API calls to get automatic token refresh
- **Logging**: Use `AppLogger` instead of `print()` statements for all new code
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

### Backend Service Integration (2025)

**Problem Solved**: Client-only OAuth created UX friction and redundant API calls during active sessions.

**Solutions Implemented**:
1. **FastAPI Backend** (`backend/`) with Railway deployment
   - Centralized Spotify token storage in Firebase
   - Automatic token refresh scheduling
   - Admin endpoints for monitoring and management
   - Device-based token organization

2. **Intelligent iOS Token Caching** (`BackendService.swift`)
   - App lifecycle-aware caching (30-minute cache during active sessions)
   - 1 backend call on startup/foreground, 0 calls during active use
   - Automatic cache invalidation on app suspension
   - Offline fallback with keychain storage

3. **Playlist Restart Elimination** (`SpotifyViewModel.swift`, `VO2MaxTrainingManager.swift`)
   - Removed automatic playlist restarts on app switching
   - Fixed connection state handlers to only ensure track polling
   - Music continues uninterrupted when switching between apps
   - Maintained legitimate playlist changes during training phase transitions

**Technical Implementation**: Backend handles token refresh automatically while users sleep/suspend app, iOS requests fresh tokens only when needed, eliminating redundant API calls and playlist interruptions.

### Logging System Implementation (2025)

**Problem Solved**: Unstructured print statements created noise in development and production, making debugging difficult.

**Solutions Implemented**:
1. **Centralized AppLogger System** (`Core/Services/AppLogger.swift`)
   - Structured log levels: ERROR, WARN, INFO, DEBUG, VERBOSE
   - Environment-aware defaults (INFO in production, VERBOSE in debug)
   - Thread-safe implementation with proper queuing

2. **Automatic Rate Limiting**
   - Prevents duplicate logs within 5-second windows
   - Shows "...repeated X times" counters for suppressed logs
   - Eliminates spam from repetitive operations

3. **Specialized Logging Methods**
   - `playerState()`: Consolidates Spotify track/artist/playing status with deduplication
   - `apiResponse()`: Concise API summaries instead of full JSON dumps
   - `rateLimited()`: Built-in spam prevention for high-frequency events

**Impact**: Replaced 642+ print statements across 21 files with clean, structured logging that adapts between development (verbose) and production (clean) environments while maintaining all critical debugging information.