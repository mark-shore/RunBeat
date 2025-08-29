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
│   │   ├── BackendService.swift   # FastAPI backend integration with intelligent caching
│   │   ├── DeviceIDManager.swift  # Device identification for backend communication
│   │   └── FirebaseService.swift  # Firebase integration (legacy)
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
└── backend/                      # FastAPI backend service
    ├── app/                      # Backend application code
    │   ├── api/v1/routes/        # REST API endpoints
    │   ├── core/                 # Configuration and logging
    │   ├── services/             # Token refresh and Firebase services
    │   └── models/               # Data models
    ├── main.py                   # FastAPI application entry point
    ├── requirements.txt          # Python dependencies
    └── deploy.sh                 # Railway deployment script

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

## Backend Integration

#### FastAPI Backend Service
- **Centralized Token Management**: Backend handles Spotify OAuth and refresh cycles
- **Firebase Integration**: Token storage with automatic cleanup of expired tokens
- **Railway Deployment**: Production-ready backend with monitoring and admin endpoints
- **Device Organization**: Multi-device token management with unique device identification
- **Intelligent Caching**: iOS app caches tokens based on app lifecycle to minimize API calls

#### Token Management Flow
1. **iOS Authentication**: User completes OAuth, tokens sent to backend immediately
2. **Backend Storage**: Tokens stored in Firebase with expiration tracking
3. **Automatic Refresh**: Backend scheduler refreshes tokens before expiration
4. **iOS Caching**: App requests fresh tokens only on startup/foreground, caches during active use
5. **Offline Fallback**: Keychain storage provides offline token access when backend unavailable

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
1. **Spotify Token Management**: Client-only OAuth creates UX friction - backend service planned to resolve
2. **Heart Rate Display**: Live BPM not visible on main training screens

### Planned Improvements
1. **Backend Service**: Add backend to handle Spotify OAuth and token management 
2. **Live Heart Rate Display**: Add current BPM to active training cards
3. **Training History**: Add workout history and statistics tracking with Firebase integration
4. **Audio Settings**: Make announcement settings more accessible
5. **Onboarding Flow**: Guide new users through HR zone setup

## Development Guidelines

### Design System Usage
- Use `AppColors` for all color values
- Apply `AppTypography` for consistent text styling
- Use `AppSpacing` for margins and padding
- Implement `AppButton` for all interactive buttons
- Wrap content sections in `AppCard` components

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
- Check Console app for background execution logs
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
1. **Dual Training Mode Testing**:
   - Start Free training → try to start VO2 training → should be prevented
   - Stop Free training → start VO2 training → should work normally
   - Force-quit app during training → verify proper cleanup on restart

2. **Shared Services Testing**:
   - Start Free training → verify HR processing and announcements
   - Stop and start VO2 training → verify same HR data but independent announcements
   - Change HR zones → verify both training modes use updated zones

3. **Background Execution Testing**:
   - Start zone training → background app → verify announcements continue
   - Start VO2 training → verify playlist switches at intervals
   - Connect HR monitor → verify real-time updates
   - Test audio announcements over music playback

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
1. Launch app and navigate to Settings
2. Configure your resting and max heart rate
3. Choose automatic or manual zone configuration
4. Connect your Bluetooth heart rate monitor
5. For VO2 training: Connect Spotify and select playlists

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