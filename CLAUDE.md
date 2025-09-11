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
- **User-scoped authentication**: Production-ready Firebase anonymous auth with backend token management and authentication timing resolution
- **Spotify architecture**: Complete with intent-based lifecycle management, robust connection management, error recovery, and persistent authentication

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
- `BackendService.swift`: FastAPI backend integration with user-scoped token management, intelligent caching, and authentication state coordination
- `FirebaseService.swift`: Firebase anonymous authentication with automatic user ID propagation and authentication completion notifications
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
- **Token Management**: Centralized `makeAuthenticatedAPICall()` method handles automatic token refresh on 401 responses with authentication timing coordination
- Features: Seamless training integration, reliable background playlist switching, automatic activation tracking

#### VO2 Training Module (`Features/VO2Training/`)
- `VO2MaxTrainingManager.swift`: 4x4 interval training coordination with shared HR services and Spotify reconnection observers
- `VO2MaxTrainingView.swift`: Training UI with design system integration
- `VO2TrainingBottomDrawer.swift`: Context-aware bottom drawer with smooth content-based animations
- **Spotify Integration**: Automatic music resumption when Spotify reconnects during training
- **Smart Drawer Interface**: State-aware UI showing Connect Spotify, track info, or playlist selection based on context
- Features: Structured intervals, Spotify playlist switching, configurable zone announcements, phase-aware music recovery

#### Settings Module (`Features/Settings/`)
- `SettingsView.swift`: Heart rate zone configuration and app settings with unified auto/manual display
- **Heart Rate Settings Interface**: Professional two-card layout with consistent editable value styling
- **Unified Zone Management**: Bidirectional zone adjustment with proper boundary validation
- **Custom Navigation**: Uses `AppBackButton` with `.navigationBarBackButtonHidden(true)` for white back button styling
- **Navigation Flow**: Integrated with navigation-based presentation (replaced modal .sheet)
- **Eliminates Dual UI**: Replaced separate AutoZonesDisplay/ManualZonesSettings with single unified interface

### Design System (`UI/DesignSystem/`)
- `AppColors.swift`: Brand colors (primary: #FF4500)
- `AppTypography.swift`: Typography scales
- `AppSpacing.swift`: Spacing system
- `Components/`: Reusable UI components (AppButton, AppCard, AppBackButton, etc.)
  - `AppBackButton.swift`: Custom navigation back button with white arrow.left icon
  - `BPMValueBox.swift`: Styled container for editable heart rate values with state-based interaction hints
  - `PickerModal.swift`: Unified modal component for heart rate value selection with consistent presentation

## Development Guidelines

### Threading Requirements
- UI updates MUST use `@MainActor` or `DispatchQueue.main.async`
- Background services handle their own threading
- ViewModels use `@Published` properties for reactive updates

### Design System Usage
- Always use design system components: `AppButton`, `AppCard`, `AppBackButton`, `AppColors`, etc.
- Follow existing spacing patterns from `AppSpacing`
- Maintain dark theme consistency
- Use `AppBackButton` for custom navigation when system back button styling doesn't match design requirements

### State Management
- **Dual Training Architecture**: Free Training and VO2 Max Training are independent modes
- **AppState**: Coordinates training mode mutual exclusion (only one active at a time)
- **Shared Services**: HeartRateService and ZoneAnnouncementCoordinator used by both training modes
- ViewModels manage UI state with `@Published` properties
- Services handle business logic and external integrations
- UserDefaults for settings persistence (preserve existing keys)

### Current Priority Issues
1. **User Onboarding**: Guide new users through HR zone setup
2. **Training Analytics**: Add workout history and performance tracking
3. **Apple Music Integration**: Consider adding as alternative to Spotify

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
- **Authentication Timing Testing**: Cold app start → verify token operations wait for Firebase auth completion → verify automatic retry
- **User-Scoped Testing**: Verify Firebase anonymous auth → backend user ID propagation → token refresh cycles
- **Background Token Refresh Testing**: Leave app closed for hours → verify backend automatically refreshes user tokens

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

### Production-Ready Systems
- ✅ **Authentication Timing Resolution**: Firebase auth completion detection with operation queueing and automatic retry
- ✅ **User-Scoped Authentication**: Complete Firebase anonymous auth with backend integration
- ✅ **Background Token Refresh**: Automatic user-scoped token refresh service runs server-side
- ✅ **Token Expiration During Training**: Fixed with centralized token refresh and graceful error handling
- ✅ **Foreground Playlist Restart**: Fixed with training-aware foreground handling
- ✅ **Music Recovery After Reconnection**: Fixed with automatic Spotify reconnection observers
- ✅ **Playlist Restart Interruptions**: Fixed automatic playlist restarts when switching between apps
- ✅ **Backend Service Integration**: Production-ready FastAPI backend with user-scoped endpoints and Railway deployment
- ✅ **Logging System**: Structured AppLogger system with rate limiting and environment-aware log levels

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
- **User-Scoped Architecture**: Complete Firebase anonymous auth with authentication timing resolution - production-ready and stable
- **Authentication Timing**: All backend operations automatically handle Firebase auth delays via operation queueing - no manual handling needed
- **Token Management**: Use `makeAuthenticatedAPICall()` for new Spotify API calls to get automatic token refresh with auth coordination
- **Backend Integration**: Use `BackendService.shared` for all backend communication - handles user ID routing and auth state automatically
- **Logging**: Use `AppLogger` instead of `print()` statements for all new code
- Test on physical device for realistic behavior
- Use design system components consistently

## Production Architecture (2025)

The following systems have been implemented and are production-ready:

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

### User-Scoped Backend Architecture (2025)

**System Overview**: Complete user-scoped authentication and token management system with authentication timing resolution.

**Architecture Components**:
1. **Firebase Anonymous Authentication** (`FirebaseService.swift`)
   - Automatic anonymous user creation on app launch
   - User ID propagation to backend services
   - Seamless authentication without user friction
   - Production-ready with error handling and retry logic

2. **User-Scoped Backend** (`backend/`) with Railway deployment
   - User-based token storage: `/api/v1/users/{user_id}/spotify-tokens`
   - Automatic background token refresh service
   - Admin endpoints for user-based monitoring
   - Firebase Firestore integration with user-scoped documents

3. **Intelligent iOS Token Management** (`BackendService.swift`)
   - User ID-aware endpoint routing with device fallback
   - App lifecycle-aware caching (30-minute cache during active sessions)
   - 1 backend call on startup/foreground, 0 calls during active use
   - Automatic cache invalidation on app suspension
   - Offline fallback with keychain storage

4. **Background Token Refresh Service** (`backend/app/services/token_refresh_service.py`)
   - Runs every 15 minutes server-side
   - Refreshes user tokens before expiration
   - Retry logic for failed refreshes
   - Admin monitoring and manual trigger endpoints

**Technical Benefits**: Users get seamless authentication, server handles token refresh automatically, eliminates client-side OAuth friction, provides scalable user-based architecture.

### Authentication Timing Resolution (2025)

**Problem Solved**: Spotify token refresh failed during app startup because Firebase authentication hadn't completed yet, causing unnecessary token deletion and user re-authentication.

**Error Sequence Eliminated**:
- App starts → Validates stored Spotify token (fails with 401)
- Tries to refresh token via backend → Backend requires user ID
- Firebase auth still in progress → Backend throws "Authentication required"
- Token refresh fails → App deletes all stored tokens ❌
- Firebase auth completes → But tokens are already gone ❌

**Solutions Implemented**:
1. **Authentication State Management** (`BackendService.swift`)
   - `AuthenticationState` enum: `.notStarted`, `.inProgress`, `.authenticated(userID)`, `.failed`
   - Operation queueing system for delayed token operations
   - Graceful handling with `handleTokenRefreshDuringAuth()` method

2. **Firebase Authentication Coordination** (`FirebaseService.swift`)
   - Notifies `BackendService` of authentication state changes
   - Posts "FirebaseAuthenticationCompleted" notifications
   - Automatic user ID propagation on auth completion

3. **Spotify Token Preservation** (`SpotifyService.swift`)
   - Firebase authentication notification observer
   - `retryTokenOperationsAfterAuth()` method for deferred operations
   - Preserves tokens during authentication timing issues (no premature deletion)

**Current Flow**:
- App starts → Validates stored Spotify token (fails with 401)
- Tries to refresh token via backend → Backend detects auth in progress
- Operations queued until Firebase auth completes ✅
- Firebase auth completes → Notification triggers queued operations ✅
- Token refresh succeeds with user ID → Tokens preserved ✅

**Technical Benefits**: Eliminates unnecessary user re-authentication, preserves valid tokens during startup timing, maintains clean user-scoped architecture without fallbacks.

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

### VO2 Max Training Navigation Architecture (2025)

**Problem Solved**: VO2 Max Training was presented as a modal that could be accidentally dismissed during serious 28-minute athletic training sessions, creating poor UX.

**Solutions Implemented**:
1. **Full-Screen Navigation Architecture** (`ContentView.swift`)
   - Replaced `.sheet()` modal presentation with `.navigationDestination()`
   - Updated from `NavigationView` to `NavigationStack` for modern iOS 16+ navigation compatibility
   - Implemented state-based navigation with `isPresented` binding for reliable button interaction

2. **Training Session Protection** (`VO2MaxTrainingView.swift`)
   - Hidden navigation back button during active training (`navigationBarBackButtonHidden`)
   - Proper navigation titles and toolbar management
   - Removed modal-specific presentation modifiers

3. **Unified Training Termination** (`VO2MaxTrainingManager.swift`)
   - Created single `endTraining()` method for consistent cleanup behavior
   - Fixed Spotify behavior inconsistency - both manual stop and natural completion continue music playback
   - Added `@MainActor` annotations for proper Swift concurrency handling
   - Maintained backward compatibility with legacy `stopTraining()` method

4. **Consistent State Management** (`AppState.swift`)
   - Updated to use unified `endTraining()` method throughout
   - Added `cleanupVO2Training()` convenience method for consistent termination

**Technical Benefits**: Eliminates accidental workout dismissal during serious training, provides consistent music behavior, maintains all existing background execution and Spotify integration while modernizing navigation patterns for iOS 16+ compatibility.

### Heart Rate Settings Interface Redesign (2025)

**Problem Solved**: Heart rate zone picker interface had verbose modal designs, inconsistent styling, and confusing dual UI structure that required scrolling.

**Solutions Implemented**:
1. **Reusable PickerModal Component** (`UI/DesignSystem/Components/PickerModal.swift`)
   - Unified modal component replacing individual verbose picker views
   - Consistent presentation with 500px height and auto-save callbacks
   - Eliminates misleading "SAVE" buttons with immediate value updates

2. **BPMValueBox Component** (`UI/DesignSystem/Components/BPMValueBox.swift`)
   - Standard design system component for all heart rate values
   - State-based styling: editable (AppColors.tertiary) vs non-editable (AppColors.surfaceSecondary)
   - Consistent padding, typography, and interaction hints across interface

3. **Unified Settings Interface** (`Features/Settings/SettingsView.swift`)
   - Two-card professional layout: Heart Rate Settings + Heart Rate Zones
   - Bidirectional zone adjustment with proper boundary validation (5 BPM minimum widths)
   - Auto/Manual toggle with clear zone calculation labeling
   - Professional table formatting with left-aligned columns and proper spacing

4. **Eliminated UI Complexity**
   - Replaced separate AutoZonesDisplay/ManualZonesSettings with single unified component
   - Consolidated multiple cards to eliminate scrolling requirements
   - Consistent editable value styling across both foundational settings and zone configuration

**Technical Benefits**: Creates unified interaction language for all heart rate values, eliminates UI inconsistencies, provides professional table design with clear visual hierarchy, and maintains all bidirectional editing functionality while simplifying the interface architecture.