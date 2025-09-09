# RunBeat

An audio-first iOS app for heart rate zone training and VO2 max intervals with Spotify integration. Designed for serious athletes to train with audio cues while keeping their phone away.

## Core Features

### 🎧 Audio-First Training
- Real-time voice announcements for heart rate zones
- Train without looking at your phone  
- Configurable announcement frequency and cooldown periods
- Background audio session management for uninterrupted training

### 🏃 Zone Training
- Continuous heart rate monitoring via Bluetooth
- Audio alerts when transitioning between heart rate zones
- Customizable zones using Karvonen formula or manual settings
- Automatic zone calculation based on resting and max heart rate

### 🔥 VO2 Max Intervals  
- Guided 4x4 minute high-intensity interval training
- Automatic Spotify playlist switching between work and rest periods
- Background execution for phone-away training
- Synchronized with heart rate monitoring for zone tracking

## Design System

### Visual Identity
- **Primary Brand Color**: Red-Orange (#FF4500) 
- **Theme**: Dark mode with true black backgrounds
- **Typography**: iOS-native font system with custom weights for displays
  - `hrDisplay`: 56px bold rounded for heart rate numbers
  - `hrIcon`: 24px medium weight for heart rate icons
  - `timerDisplay`: 36px medium monospace for training timers
- **Components**: Card-based UI with native iOS button styles

### Design System Structure

RunBeat/
├── UI/
│   ├── DesignSystem/
│   │   ├── AppColors.swift       # Color palette
│   │   ├── AppTypography.swift   # Typography scales
│   │   ├── AppSpacing.swift      # Spacing system
│   │   └── Components/
│   │       ├── AppButton.swift   # Unified button component
│   │       ├── AppCard.swift     # Card container component
│   │       ├── BPMDisplayView.swift # Animated heart rate display with zone colors
│   │       └── ZoneDisplay.swift # Heart rate zone display

## Architecture Overview

RunBeat follows the **MVVM (Model-View-ViewModel)** architecture pattern with clean separation of concerns:

- **Models**: Data structures and business logic
- **Views**: SwiftUI UI components with design system integration
- **ViewModels**: UI state management and business logic coordination
- **Services**: Core functionality and external integrations

## Project Structure

RunBeat/
├── Core/                          # Core application services and utilities
│   ├── Services/                  # Core business services
│   │   ├── AudioService.swift     # Audio session management
│   │   ├── SpeechAnnouncer.swift  # Voice announcements
│   │   ├── HeartRateService.swift # Shared HR processing and zone calculation
│   │   ├── ZoneAnnouncementCoordinator.swift # Per-training-mode announcement management
│   │   ├── BackendService.swift   # User-scoped FastAPI backend integration with intelligent caching
│   │   ├── FirebaseService.swift  # Firebase anonymous authentication with user ID propagation
│   │   └── AppLogger.swift        # Centralized logging system with rate limiting
│   ├── Models/                    # Data models
│   └── Utils/                     # Utility classes
│       ├── KeychainWrapper.swift  # Secure token storage for Spotify
│       ├── ConfigurationManager.swift # App configuration management
│       └── TimeProvider.swift     # Time abstraction for testing
├── Features/                      # Feature-specific modules
│   ├── HeartRate/                 # Heart rate monitoring and training
│   │   ├── HeartRateManager.swift        # CoreBluetooth heart rate monitoring
│   │   ├── HeartRateViewModel.swift      # Heart rate settings UI state
│   │   └── HeartRateZoneCalculator.swift # Zone calculation logic
│   ├── FreeTraining/              # Free training mode
│   │   └── FreeTrainingManager.swift    # Simple background HR monitoring
│   ├── Spotify/                   # Spotify integration
│   │   ├── SpotifyService.swift          # Core orchestration and business logic
│   │   ├── SpotifyConnectionManager.swift # Unified connection state management
│   │   ├── SpotifyDataCoordinator.swift  # Data source coordination
│   │   ├── SpotifyErrorHandler.swift     # Structured error recovery
│   │   ├── SpotifyViewModel.swift        # Spotify UI state management
│   │   └── SpotifyManager.swift          # Legacy compatibility wrapper
│   ├── VO2Training/               # VO2 max interval training
│   │   ├── VO2MaxTrainingManager.swift   # Training session logic
│   │   ├── VO2MaxTrainingView.swift      # Training UI
│   │   ├── VO2IntervalState.swift        # Interval state model
│   │   └── VO2Config.swift               # Training configuration
│   └── Settings/                  # App settings
│       └── SettingsView.swift            # Settings UI
├── UI/                           # UI layer
│   ├── DesignSystem/             # Design system (see above)
│   └── Views/                    # SwiftUI views
│       └── ContentView.swift     # Main app view
├── Resources/                    # App resources
│   └── Audio/                    # Audio files for zone announcements
│       ├── zone0.mp3
│       ├── zone1.mp3
│       ├── zone2.mp3
│       ├── zone3.mp3
│       ├── zone4.mp3
│       └── zone5.mp3
├── AppDelegate.swift             # UIKit app delegate for backend services
├── AppState.swift                # Dual training mode coordinator with mutual exclusion
├── RunBeatApp.swift              # SwiftUI app entry point
├── Info.plist                    # App configuration
├── Config.plist                  # Feature configuration
├── Assets.xcassets/              # App assets
├── .gitignore                    # iOS/Swift project ignore rules
└── backend/                      # FastAPI backend service
    ├── app/                      # Backend application code
    │   ├── __init__.py
    │   ├── api/                  # REST API endpoints
    │   │   ├── __init__.py
    │   │   └── v1/
    │   │       ├── __init__.py
    │   │       └── routes/
    │   │           ├── __init__.py
    │   │           ├── admin.py          # Admin endpoints
    │   │           ├── devices.py        # Device management
    │   │           ├── health.py         # Health check endpoints
    │   │           └── spotify.py        # Spotify token management
    │   ├── core/                 # Configuration and logging
    │   │   ├── __init__.py
    │   │   ├── config.py                 # App configuration
    │   │   └── logging_config.py         # Logging setup
    │   ├── models/               # Data models
    │   │   └── __init__.py
    │   ├── services/             # Business logic services
    │   │   ├── __init__.py
    │   │   ├── firebase_client.py        # Firebase integration
    │   │   └── token_refresh_service.py  # Token refresh logic
    │   └── utils/                # Utility functions
    │       └── __init__.py
    ├── main.py                   # FastAPI application entry point
    ├── requirements.txt          # Python dependencies
    ├── runtime.txt               # Python version specification
    ├── railway.toml              # Railway deployment config
    ├── Procfile                  # Process definition for Railway
    ├── deploy.sh                 # Railway deployment script
    ├── README.md                 # Backend-specific documentation
    ├── RAILWAY_DEPLOYMENT.md     # Deployment guide
    ├── test_endpoints.py         # API endpoint tests
    ├── test_ios_integration.py   # iOS integration tests
    ├── test_refresh_system.py    # Token refresh tests
    ├── test_timing_updates.py    # Timing system tests
    └── .gitignore                # Python/backend specific ignore rules

## Key Components

### Core Services

#### HeartRateService (Shared Processing)
- **Shared across all training modes** - eliminates duplication
- Real-time zone calculation and BPM processing
- Manages heart rate settings and zone configuration
- Thread-safe zone state management
- Central hub for all heart rate data processing

#### ZoneAnnouncementCoordinator (Per-Training Management)
- **Per-training-mode announcement logic** with independent settings
- Manages cooldown periods and announcement frequency for each mode
- NotificationCenter-based announcement routing to AppState
- Prevents announcement conflicts between training modes
- Configurable per-mode announcement controls

#### AudioService
- Manages audio session configuration for announcements
- Handles volume restoration after voice prompts
- Coordinates with background music playback
- Ensures announcements work during Spotify playback

#### SpeechAnnouncer
- Provides voice announcements for heart rate zones
- Manages speech synthesis and timing
- Receives announcements via NotificationCenter from coordinators

### Heart Rate Module

#### HeartRateManager
- CoreBluetooth-based heart rate monitoring
- Manages device scanning, connection, and data processing
- Handles background execution for continuous monitoring
- Publishes real-time BPM updates

#### HeartRateViewModel
- Manages heart rate zone settings UI state
- Handles persistence via UserDefaults
- Provides validation for heart rate calculations
- Supports both automatic (Karvonen) and manual zone configuration

#### FreeTrainingManager (Replaces Legacy HeartRateTrainingManager)
- **Uses shared services architecture** - HeartRateService and ZoneAnnouncementCoordinator
- Simple background HR monitoring with zone announcements
- Independent announcement controls separate from VO2 training
- Lightweight training mode for general HR monitoring
- Delegates to shared services instead of duplicating logic

#### HeartRateZoneCalculator
- Pure, stateless heart rate zone calculations
- Implements Karvonen formula for zone determination
- Maps BPM values to training zones

### Spotify Module

The Spotify integration uses a modular architecture with specialized components:

#### SpotifyService
- Core orchestration and business logic coordination
- Intent-based lifecycle management with SpotifyIntent (.training, .idle, .background)
- OAuth authentication with persistent keychain storage
- Device activation and automatic playlist management
- Coordinates between connection manager, data coordinator, and error handler

#### SpotifyConnectionManager
- Unified connection state management with single source of truth
- State machine: `disconnected` → `authenticating` → `authenticated` → `connecting` → `connected`
- Eliminates multiple boolean connection flags
- Handles state transitions and error recovery

#### SpotifyDataCoordinator
- Intelligent data source prioritization (AppRemote > Web API > Optimistic)
- Deduplication logic prevents redundant UI updates
- Thread-safe data processing with standardized `SpotifyTrackInfo` model
- Consolidates track information from multiple sources

#### SpotifyErrorHandler
- Structured error recovery with context-aware strategies
- Intent-aware error recovery that respects current context (no recovery during .idle)
- Exponential backoff retry logic for network issues
- Training-aware error handling (more aggressive during workouts)
- User-friendly error messages and recovery guidance

#### Authentication & Persistence
- **Keychain Integration**: Tokens persist across app restarts - no repeated OAuth flows
- **Automatic Restoration**: Validates and restores sessions on app launch
- **Smart Activation**: Prevents duplicate playlist starts during device activation

#### VO2 Training Integration
- Seamless playlist switching during intervals without music interruption
- User-selectable playlists for high intensity and rest periods
- Automatic activation tracking prevents duplicate starts during Spotify wakeup
- Background-safe playlist changes synchronized with training phases

### VO2 Training Module

#### VO2MaxTrainingManager
- **Uses shared services architecture** - HeartRateService and ZoneAnnouncementCoordinator
- Manages 4x4 minute interval training sessions with independent announcement controls
- Handles interval timing and phase transitions
- Coordinates with Spotify for playlist switching
- Spotify reconnection observers for automatic music recovery during training
- Manages training state with visual and audio feedback

## Architecture: Shared Services + Dual Training Modes

### Shared Services Architecture
**Problem Solved**: Eliminates code duplication between Free Training and VO2 Max Training modes.

**Design Pattern**: 
```
FreeTrainingManager ──┐
                      ├── HeartRateService (shared processing)
                      └── ZoneAnnouncementCoordinator (per-mode settings)
VO2MaxTrainingManager ─┘
```

**Benefits**:
- **Single source of truth** for HR zone calculations
- **Independent announcement controls** per training mode
- **Consistent zone logic** across all training types
- **Easier testing and maintenance** with centralized processing

### Dual Training Mode System
**Coordinated by AppState**: Ensures only one training mode active at a time

**Training Modes**:
- `.none` - No active training
- `.free` - Simple background HR monitoring with announcements  
- `.vo2Max` - Structured 4x4 interval training with Spotify integration

**Mutual Exclusion**: AppState prevents simultaneous training sessions
**Shared Resources**: Both modes use HeartRateService and ZoneAnnouncementCoordinator
**Independent Settings**: Each mode maintains separate announcement preferences

## User-Scoped Backend Integration

#### Firebase Anonymous Authentication
- **Seamless User Creation**: Automatic anonymous authentication on app launch
- **User ID Propagation**: Firebase user IDs automatically sent to backend services
- **No User Friction**: Authentication happens transparently without login screens
- **Production-Ready**: Error handling, retry logic, and graceful fallback

#### User-Scoped FastAPI Backend Service
- **User-Based Endpoints**: `/api/v1/users/{user_id}/spotify-tokens` replace device-based storage
- **Background Token Refresh**: Server-side service runs every 15 minutes for all users
- **Firebase Integration**: User-scoped Firestore documents with automatic cleanup
- **Railway Deployment**: Production-ready backend with user-based admin endpoints
- **Intelligent Caching**: iOS app caches tokens based on app lifecycle to minimize API calls

#### User-Scoped Token Management Flow
1. **Firebase Authentication**: Anonymous user created automatically on app launch
2. **User ID Propagation**: User ID sent to backend for all token operations
3. **Backend Storage**: Tokens stored in Firebase under user-scoped paths
4. **Automatic Background Refresh**: Server refreshes user tokens every 15 minutes before expiration
5. **iOS Caching**: App requests fresh tokens only on startup/foreground, caches during active use
6. **Offline Fallback**: Keychain storage provides offline token access when backend unavailable

#### Background Token Refresh Service
- **Server-Side Processing**: Runs independently of iOS app state
- **User-Scoped Refresh**: Processes tokens for all authenticated users
- **Retry Logic**: Failed refreshes automatically retried after 5 minutes
- **Admin Monitoring**: User-based endpoints for monitoring token refresh status

## Background Execution Strategy

### Heart Rate Monitoring
- **Shared HeartRateService** processes all BPM data regardless of training mode
- Uses CoreBluetooth background mode for continuous monitoring
- Wall-clock based timing advanced by HR events
- Maintains connection during phone sleep

### Spotify Integration
- **Unified Data Sources**: SpotifyDataCoordinator intelligently prioritizes AppRemote, Web API, and optimistic updates
- **Persistent Authentication**: Keychain storage eliminates repeated OAuth flows
- **Smart State Management**: Connection state machine handles complex scenarios gracefully
- **Background Support**: Structured error recovery maintains functionality across app states
- **Training-Optimized**: Automatic activation tracking prevents music interruption during workouts

### Audio Management
- Audio session configured for mixing with other apps
- Duck music volume during announcements
- Automatic volume restoration after voice prompts

## Configuration

### Required Setup

1. **Spotify Credentials**: Add to `Config.plist`
   - Client ID and Client Secret from Spotify Developer Dashboard
   - Redirect URI for OAuth flow
   - User must select playlists for VO2 training zones

2. **Info.plist Background Modes**:
   - `bluetooth-central` for heart rate monitoring
   - `audio` for voice announcements
   - Required usage descriptions for Bluetooth and Spotify

3. **Heart Rate Zones Configuration**:
   - Default zones calculated using Karvonen formula
   - Manual override available for all zones
   - Persistent storage in UserDefaults

## Known Issues & Planned Improvements

### Current Issues
1. **User Onboarding**: Could be more guided for new users

### Production-Ready Systems (2025)
1. ✅ **User-Scoped Authentication**: Complete Firebase anonymous auth with seamless backend integration
2. ✅ **Background Token Refresh**: Server-side service automatically manages user tokens every 15 minutes
3. ✅ **Backend Service**: Production-ready FastAPI backend with user-scoped endpoints and Railway deployment
4. ✅ **Spotify Token Management**: Fixed token expiration and playlist restart issues with centralized refresh system
5. ✅ **Logging System**: Structured AppLogger system with rate limiting and environment-aware levels

### Planned Improvements  
1. **Training History**: Add workout history and statistics tracking leveraging user-scoped Firebase integration
2. **Audio Settings**: Make announcement settings more accessible
3. **Onboarding Flow**: Guide new users through HR zone setup
4. **Apple Music Integration**: Consider adding as alternative to Spotify

## Development Guidelines

### Design System Usage
- Use `AppColors` for all color values
- Apply `AppTypography` for consistent text styling  
- Use `AppSpacing` for margins and padding
- Implement `AppButton` for all interactive buttons
- Use `BPMDisplayView` for heart rate displays with zone indication
- Wrap content sections in `AppCard` components

### UI Components

#### BPMDisplayView
- **Animated heart rate display** with zone-colored background circle
- **Real-time visual feedback** during training with pulse animation (0.9-1.05 scale)
- **Zone color integration** using AppColors.zone0-zone5 for instant zone recognition
- **Training-optimized sizing**: 56px BPM number with 24px heart icon in 150px circle
- **Reusable component** accepts BPM value and zone as parameters
- **Enhanced glanceability** designed for quick reads during intense VO2 intervals

### MVVM Principles
- **Separation of Concerns**: Each component has a single responsibility
- **Dependency Injection**: Services are injected rather than created internally
- **Reactive Programming**: Use Combine for state management and updates
- **Testability**: Services and ViewModels are easily testable

### Threading
- UI updates must occur on the main thread
- Use `DispatchQueue.main.async` for @Published property updates
- Background services handle their own threading
- Use `@MainActor` for ViewModel updates

### State Management
- **AppState coordinates dual training modes** with mutual exclusion (only one active at a time)
- **AppState bridging** eliminates dual ownership patterns where views had both @StateObject trainingManager and @EnvironmentObject appState
- **Shared services pattern** eliminates duplication between training modes
- **NotificationCenter routing** for announcements from coordinators to AppState to SpeechAnnouncer
- ViewModels manage UI state with `@Published` properties
- Services handle business logic and external integrations

## Troubleshooting

### Common Issues

1. **Training Mode Conflicts**
   - Only one training mode can be active at a time (enforced by AppState)
   - If training won't start, check that previous session was properly stopped
   - Look for "Cannot start X training - another mode is active" messages
   - Verify AppState.activeTrainingMode shows `.none` before starting new session

2. **Shared Services Issues**
   - HR processing issues affect both Free and VO2 training modes
   - Check HeartRateService logs for zone calculation problems
   - Verify ZoneAnnouncementCoordinator delegate setup for announcement routing
   - Ensure NotificationCenter announcements are reaching AppState

3. **Spotify Connection Issues**
   - Check connection state in SpotifyConnectionManager (should show `connected`)
   - Verify keychain token persistence is working (no repeated OAuth prompts)
   - Look for error recovery actions in SpotifyErrorHandler logs
   - Ensure proper state transitions: disconnected → authenticating → authenticated → connected

2. **Spotify Playlists Not Switching**
   - Verify VO2 training session is active
   - Check SpotifyDataCoordinator for data source conflicts
   - Ensure automatic activation tracking isn't preventing playlist starts
   - Look for duplicate connection prevention in logs

2. **Heart Rate Not Updating**
   - Verify Bluetooth permissions in Settings
   - Check device connection status
   - Ensure background modes are properly configured
   - Try re-pairing the heart rate monitor

3. **Audio Announcements Not Working**
   - Check audio session configuration
   - Verify volume is not muted
   - Test with different audio output devices
   - Ensure voice synthesis is enabled in iOS settings

4. **UI Not Updating During Training**
   - Verify @Published properties are updated on main thread
   - Check Combine subscription chains
   - Ensure ViewModels are properly observed
   - Use `DispatchQueue.main.async` for UI updates from background threads

### Debug Tips
- Use Xcode's Debug Navigator to monitor background tasks
- Check Console app for background execution logs using structured AppLogger output
- Monitor log levels: ERROR (issues), WARN (recoverable), INFO (key events), DEBUG/VERBOSE (development)
- Use AppLogger's rate limiting to reduce log spam from repetitive operations
- Verify entitlements and Info.plist configuration
- Test on physical device (background modes don't work in simulator)
- Force-quit app after deployment to clear development state
- Test untethered from Xcode for realistic background behavior

## Testing Approach

### Physical Device Testing Required
- Background modes don't work properly in simulator
- Bluetooth heart rate monitoring requires real devices
- Spotify App Remote requires installed Spotify app

### Test Scenarios
1. **User-Scoped Authentication Testing**:
   - Fresh app install → verify Firebase anonymous user creation
   - Backend integration → verify user ID propagation to endpoints
   - Token management → verify user-scoped token storage and refresh
   - Multiple devices → verify independent user-based token management

2. **Dual Training Mode Testing**:
   - Start Free training → try to start VO2 training → should be prevented
   - Stop Free training → start VO2 training → should work normally
   - Force-quit app during training → verify proper cleanup on restart

3. **Shared Services Testing**:
   - Start Free training → verify HR processing and announcements
   - Stop and start VO2 training → verify same HR data but independent announcements
   - Change HR zones → verify both training modes use updated zones

4. **Background Execution Testing**:
   - Start zone training → background app → verify announcements continue
   - Start VO2 training → verify playlist switches at intervals
   - Connect HR monitor → verify real-time updates
   - Test audio announcements over music playback
   - Background token refresh → leave app closed for hours, verify server-side token refresh

## Building and Deployment

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ deployment target
- Spotify Developer Account
- Physical iOS device for testing
- Bluetooth heart rate monitor (for full testing)

### Build Process
1. Configure Spotify credentials in `Config.plist`
2. Set development team in project settings
3. Enable required capabilities (Background Modes)
4. Build and deploy to physical device
5. Authorize Spotify on first launch

### Deployment Notes
- Test background execution by fully backgrounding app
- Verify audio announcements work over other audio
- Test with various heart rate monitors for compatibility
- Ensure Spotify playlist switching works in background

## User Guide

### Getting Started
1. Launch app - Firebase anonymous authentication happens automatically
2. Navigate to Settings and configure your resting and max heart rate
3. Choose automatic or manual zone configuration
4. Connect your Bluetooth heart rate monitor
5. For VO2 training: Connect Spotify and select playlists (tokens automatically managed by backend)

### Training Modes

#### Zone Training
- Continuous heart rate monitoring with audio alerts
- Announces when you change zones
- Configurable cooldown between announcements
- Best for steady-state cardio and long runs

#### VO2 Max Intervals
- 4 minutes high intensity → 3 minutes rest → repeat 4x
- Automatic playlist switching
- Designed for improving VO2 max
- Total workout time: ~28 minutes

### Tips for Best Experience
- Adjust phone volume before starting workout
- Test audio announcements before putting phone away
- Ensure heart rate monitor is properly connected
- For VO2 training, create dedicated high-energy and recovery playlists