# PulsePrompt

A SwiftUI iOS app for heart rate-based training with Spotify integration and VO2 max interval training.

## Architecture Overview

PulsePrompt follows the **MVVM (Model-View-ViewModel)** architecture pattern with clean separation of concerns:

- **Models**: Data structures and business logic
- **Views**: SwiftUI UI components
- **ViewModels**: UI state management and business logic coordination
- **Services**: Core functionality and external integrations

## Project Structure

```
pulseprompt/
├── Core/                          # Core application services and utilities
│   ├── Services/                  # Core business services
│   │   ├── AudioService.swift     # Audio session management
│   │   └── SpeechAnnouncer.swift  # Voice announcements
│   ├── Models/                    # Data models
│   └── Utils/                     # Utility classes
├── Features/                      # Feature-specific modules
│   ├── HeartRate/                 # Heart rate monitoring and training
│   │   ├── HeartRateManager.swift        # CoreBluetooth heart rate monitoring
│   │   ├── HeartRateViewModel.swift      # Heart rate settings UI state
│   │   ├── HeartRateTrainingManager.swift # Training session management
│   │   └── HeartRateZoneCalculator.swift # Zone calculation logic
│   ├── Spotify/                   # Spotify integration
│   │   ├── SpotifyService.swift          # Spotify API and playback logic
│   │   ├── SpotifyViewModel.swift        # Spotify UI state management
│   │   └── SpotifyManager.swift          # Compatibility wrapper
│   ├── VO2Training/               # VO2 max interval training
│   │   ├── VO2MaxTrainingManager.swift   # Training session logic
│   │   ├── VO2MaxTrainingView.swift      # Training UI
│   │   ├── VO2IntervalState.swift        # Interval state model
│   │   └── VO2Config.swift               # Training configuration
│   └── Settings/                  # App settings
│       └── SettingsView.swift            # Settings UI
├── UI/                           # UI layer
│   ├── Views/                    # SwiftUI views
│   │   └── ContentView.swift     # Main app view
│   └── ViewModels/               # ViewModels (currently empty)
├── Resources/                    # App resources
│   └── Audio/                    # Audio files
│       ├── zone1.mp3
│       ├── zone2.mp3
│       ├── zone3.mp3
│       ├── zone4.mp3
│       └── zone5.mp3
├── AppState.swift                # App coordinator and state management
├── pulsepromptApp.swift          # App entry point
├── Info.plist                    # App configuration
├── Config.plist                  # Feature configuration
└── Assets.xcassets/              # App assets
```

## Key Components

### Core Services

#### AudioService
- Manages audio session configuration for announcements
- Handles volume restoration after voice prompts
- Coordinates with background music playback

#### SpeechAnnouncer
- Provides voice announcements for heart rate zones
- Manages speech synthesis and timing

### Heart Rate Module

#### HeartRateManager
- CoreBluetooth-based heart rate monitoring
- Manages device scanning, connection, and data processing
- Handles background execution for continuous monitoring

#### HeartRateViewModel
- Manages all heart rate zone settings UI state
- Handles persistence via UserDefaults
- Provides validation for heart rate calculations
- Coordinates with HeartRateTrainingManager for real-time updates

#### HeartRateTrainingManager
- Manages active training session state
- Handles zone announcement timing and cooldowns
- Coordinates with AudioService for voice prompts

#### HeartRateZoneCalculator
- Pure, stateless heart rate zone calculations
- Implements Karvonen formula for zone determination
- Maps BPM values to training zones

### Spotify Module

#### SpotifyService
- Handles Spotify OAuth authentication
- Manages API calls and device activation
- Controls playback and playlist switching
- Handles background task coordination

#### SpotifyViewModel
- Manages Spotify connection UI state
- Coordinates with SpotifyService for operations
- Provides reactive updates for UI components

#### SpotifyManager
- Compatibility wrapper for existing code
- Delegates to SpotifyViewModel for all operations
- Maintains backward compatibility during migration

### VO2 Training Module

#### VO2MaxTrainingManager
- Manages VO2 max interval training sessions
- Handles interval timing and phase transitions
- Coordinates with Spotify for playlist switching
- Manages training state and UI updates

#### VO2MaxTrainingView
- Training session UI
- Displays current phase, time remaining, and status
- Provides controls for starting/pausing training

#### VO2Config & VO2IntervalState
- Training configuration and interval state models
- Defines training phases and durations

### Settings Module

#### SettingsView
- Comprehensive settings UI
- Heart rate zone configuration
- Spotify connection management
- App preferences and configuration

## Background Execution Strategy

### Heart Rate Monitoring
- Uses CoreBluetooth background mode for continuous monitoring
- VO2 timing is wall-clock based and advanced by HR events
- Foreground UI uses 1s Timer purely for display updates

### Spotify Integration
- **Foreground**: App Remote preferred with Web API fallback
- **Background**: Web API only (wrapped in background tasks)
- Idempotent playlist switching (one switch per interval)

### Audio Management
- Audio session configured for announcements
- Automatic volume restoration after voice prompts
- Background audio session management

## Configuration

### Required Setup
1. **Spotify Credentials**: Add to `Config.plist`
   - Client ID and Client Secret
   - Playlist IDs for different training zones

2. **Info.plist Background Modes**:
   - `bluetooth-central` for heart rate monitoring
   - `audio` for voice announcements

3. **Entitlements**:
   - Background modes enabled
   - Bluetooth usage description

### Environment Configuration
- Development vs production Spotify credentials
- Heart rate zone defaults
- Training interval configurations

## Development Guidelines

### MVVM Principles
- **Separation of Concerns**: Each component has a single responsibility
- **Dependency Injection**: Services are injected rather than created internally
- **Reactive Programming**: Use Combine for state management and updates
- **Testability**: Services and ViewModels are easily testable

### Threading
- UI updates must occur on the main thread
- Use `DispatchQueue.main.async` for @Published property updates
- Background services handle their own threading

### State Management
- ViewModels manage UI state with @Published properties
- Services handle business logic and external integrations
- AppState coordinates between different modules

## Troubleshooting

### Common Issues

1. **Spotify Playlists Not Switching in Background**
   - Ensure heart rate session is active during VO2 training
   - Verify Spotify access token is valid
   - Check device activation path in logs

2. **Heart Rate Not Updating**
   - Verify Bluetooth permissions
   - Check device connection status
   - Ensure background modes are properly configured

3. **Audio Announcements Not Working**
   - Check audio session configuration
   - Verify microphone permissions
   - Ensure volume is not muted

4. **UI Not Updating**
   - Verify @Published properties are updated on main thread
   - Check Combine subscription chains
   - Ensure ViewModels are properly observed

### Debug Tips
- Use Xcode's Debug Navigator to monitor background tasks
- Check Console app for background execution logs
- Verify entitlements and Info.plist configuration
- Test on physical device for background behavior

## Building and Deployment

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ deployment target
- Spotify Developer Account
- Physical device for testing (background modes)

### Build Process
1. Configure Spotify credentials in `Config.plist`
2. Set up background modes in Info.plist
3. Build and deploy to device
4. Test background execution thoroughly

### Deployment Notes
- Force-quit app after deployment to clear development state
- Test untethered operation for realistic background behavior
- Verify all background modes work as expected


