# RunBeat

An audio-first iOS app for heart rate zone training and VO2 max intervals with Apple Music integration. Designed for serious athletes to train with audio cues while keeping their phone away.

## Core Features

### 🎧 Audio-First Training
- Real-time voice announcements for heart rate zones
- Train without looking at your phone
- Configurable announcement frequency and cooldown periods
- Background audio session management for uninterrupted training
- **Instant announcements** - Pre-warmed AVAudioPlayer eliminates delays

### 🏃 Zone Training
- Continuous heart rate monitoring via Bluetooth
- Audio alerts when transitioning between heart rate zones
- Customizable zones using Karvonen formula or manual settings
- Automatic zone calculation based on resting and max heart rate

### 🔥 VO2 Max Intervals
- Guided 4x4 minute high-intensity interval training
- Automatic Apple Music playlist switching between work and rest periods
- Play/pause controls during training and completion screens
- Background execution for phone-away training
- Synchronized with heart rate monitoring for zone tracking

### 🎵 Apple Music Integration
- Full MusicKit integration for library playlist access
- Authorize once, playlists stay selected
- Automatic playlist switching during VO2 intervals
- Music properly ducks during zone announcements
- Play/pause controls during training

## Requirements

- iOS 17.0+
- Xcode 15.0+
- **Apple Music subscription** for playlist playback
- Bluetooth heart rate monitor compatible with CoreBluetooth

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

```
RunBeat/
├── UI/
│   ├── DesignSystem/
│   │   ├── AppColors.swift       # Color palette
│   │   ├── AppTypography.swift   # Typography scales
│   │   ├── AppSpacing.swift      # Spacing system
│   │   ├── AppIcons.swift        # SF Symbol constants
│   │   └── Components/
│   │       ├── AppButton.swift   # Unified button component
│   │       ├── AppCard.swift     # Card container component
│   │       ├── BPMDisplayView.swift # Animated heart rate display
│   │       ├── BPMValueBox.swift # Styled container for editable heart rate values
│   │       ├── PickerModal.swift # Unified modal component
│   │       └── ZoneDisplay.swift # Heart rate zone display
```

## Architecture Overview

RunBeat follows the **MVVM (Model-View-ViewModel)** architecture pattern with clean separation of concerns:

- **Models**: Data structures and business logic
- **Views**: SwiftUI UI components with design system integration
- **ViewModels**: UI state management and business logic coordination
- **Services**: Core functionality and external integrations

## Project Structure

```
RunBeat/
├── Core/                          # Core application services and utilities
│   ├── Services/                  # Core business services
│   │   ├── AudioService.swift     # Audio session management
│   │   ├── SpeechAnnouncer.swift  # Voice announcements with pre-warming
│   │   ├── HeartRateService.swift # Shared HR processing and zone calculation
│   │   ├── ZoneAnnouncementCoordinator.swift # Per-training-mode announcement management
│   │   └── AppLogger.swift        # Centralized logging system with rate limiting
│   ├── Models/                    # Data models
│   └── Utils/                     # Utility classes
│       ├── ConfigurationManager.swift # App configuration management
│       └── TimeProvider.swift     # Time abstraction for testing
├── Features/                      # Feature-specific modules
│   ├── HeartRate/                 # Heart rate monitoring and training
│   │   ├── HeartRateManager.swift        # CoreBluetooth heart rate monitoring
│   │   ├── HeartRateViewModel.swift      # Heart rate settings UI state
│   │   └── HeartRateZoneCalculator.swift # Zone calculation logic
│   ├── FreeTraining/              # Free training mode
│   │   └── FreeTrainingManager.swift    # Simple background HR monitoring
│   ├── Music/                     # Apple Music integration
│   │   ├── MusicKitService.swift         # Core Apple Music API integration
│   │   ├── MusicViewModel.swift          # Apple Music UI state management
│   │   └── Models/
│   │       └── MusicPlaylist.swift      # Apple Music playlist model
│   ├── VO2Training/               # VO2 max interval training
│   │   ├── VO2MaxTrainingManager.swift   # Training session logic
│   │   ├── VO2MaxTrainingView.swift      # Training UI
│   │   ├── VO2IntervalState.swift        # Interval state model
│   │   ├── VO2Config.swift               # Training configuration
│   │   ├── VO2SettingsManager.swift      # VO2-specific settings
│   │   └── Components/
│   │       ├── VO2TrainingBottomDrawer.swift # Context-aware bottom drawer
│   │       └── VO2SettingsView.swift         # Zone announcement settings
│   └── Settings/                  # App settings
│       └── SettingsView.swift            # Heart rate settings with unified auto/manual interface
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
├── AppDelegate.swift             # UIKit app delegate
├── AppState.swift                # Dual training mode coordinator with mutual exclusion
├── RunBeatApp.swift              # SwiftUI app entry point
├── Info.plist                    # App configuration
├── Config.plist                  # Feature configuration
└── Assets.xcassets/              # App assets
```

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

#### SpeechAnnouncer
- Provides voice announcements for heart rate zones using AVAudioPlayer
- **Pre-warming** - Initializes AVAudioPlayer on app launch for instant playback
- MP3-based zone announcements (zone0.mp3 through zone5.mp3)
- Proper audio session management for ducking music during announcements

#### AudioService
- Manages audio session configuration for announcements
- Handles volume restoration after voice prompts
- Coordinates with background music playback
- Configured with `.mixWithOthers` and `.duckOthers` options

#### AppLogger
- Centralized structured logging system
- Log levels: ERROR, WARN, INFO, DEBUG, VERBOSE
- Environment-aware defaults (INFO in production, VERBOSE in debug)
- Automatic rate limiting prevents spam (5-second windows)
- Specialized methods: `playerState()`, `apiResponse()`, `rateLimited()`

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
- Unified settings interface with bidirectional zone adjustment

#### FreeTrainingManager
- **Uses shared services architecture** - HeartRateService and ZoneAnnouncementCoordinator
- Simple background HR monitoring with zone announcements
- Independent announcement controls separate from VO2 training
- Lightweight training mode for general HR monitoring

#### HeartRateZoneCalculator
- Pure, stateless heart rate zone calculations
- Implements Karvonen formula for zone determination
- Maps BPM values to training zones

### Apple Music Module

The Apple Music integration uses MusicKit for native iOS music library access:

#### MusicKitService
- Full Apple Music API integration (authorization, playlist fetching, playback control)
- Uses `ApplicationMusicPlayer` for library playlist playback
- Manages audio session with proper `.mixWithOthers` and `.duckOthers` configuration
- Play/pause, resume, stop controls
- Queue management with repeat mode for training sessions
- Background playback support

#### MusicViewModel
- Apple Music UI state management with `@Published` properties
- Authorization status tracking
- Playlist selection and persistence via UserDefaults
- Play/pause state management
- Computed properties for playlist configuration status

#### MusicPlaylist Model
- Data structure for Apple Music library playlists
- Maps from MusicKit `Playlist` type
- Codable for UserDefaults persistence
- Contains: id, name, track count, artwork

### VO2 Max Training Module

#### VO2MaxTrainingManager
- Manages 4x4 interval training sessions
- Automatic playlist switching via MusicViewModel
- Background-aware timer system using wall clock
- Phase tracking (high intensity / rest)
- Interval counting and progression
- Uses shared HeartRateService and ZoneAnnouncementCoordinator

#### VO2MaxTrainingView
- Full-screen navigation-based training UI
- State-driven interface (setup / active / complete)
- Real-time BPM and zone display
- Timer display with phase information
- Integrated with VO2TrainingBottomDrawer

#### VO2TrainingBottomDrawer
- Context-aware bottom drawer UI
- States: Connect Music → Playlist Selection → Track Info
- Auto-expands for playlist selection when needed
- Collapsible during training
- Persistent during completion screen for music controls
- Playlist assignment via action sheets

#### VO2SettingsManager
- Simple settings management for VO2-specific controls
- Zone announcement toggles per zone (1-5)
- Persistent via UserDefaults

### App State Management

#### AppState
- Coordinates dual training mode mutual exclusion
- Only one training mode active at a time (Free or VO2 Max)
- Routes heart rate data to appropriate training manager
- Manages zone announcement flow via NotificationCenter
- Bridges VO2 training UI state from manager to views

### Settings Module

#### SettingsView
- Heart rate zone configuration with unified auto/manual interface
- Two-card professional layout (Heart Rate Settings + Heart Rate Zones)
- Bidirectional zone adjustment with proper boundary validation
- Consistent editable value styling via BPMValueBox
- Professional table formatting with left-aligned columns

## Tech Stack

- **SwiftUI** - UI framework
- **MVVM** - Architecture pattern
- **CoreBluetooth** - Heart rate monitor integration
- **MusicKit** - Apple Music integration
- **Firebase** - Anonymous authentication only (no backend)
- **Combine** - Reactive state management
- **AVFoundation** - Audio playback and session management
- **UserDefaults** - Settings persistence

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

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd RunBeat
   ```

2. **Open in Xcode**
   ```bash
   open RunBeat.xcodeproj
   ```

3. **Configure signing**
   - Select the RunBeat target in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team

4. **Install on device**
   - Connect your iOS device
   - Select your device as the build target
   - Click Run (⌘R)

5. **Enable Apple Music**
   - Launch the app
   - Navigate to VO2 Max Training
   - Tap "Authorize Apple Music"
   - Grant permission when prompted

6. **Select playlists**
   - After authorization, expand the bottom drawer
   - Tap playlists to assign them to Work or Recovery
   - Selected playlists persist across app restarts

7. **Connect heart rate monitor**
   - Put your Bluetooth HR monitor in pairing mode
   - The app will automatically discover and connect
   - Grant Bluetooth permission when prompted

## Testing Requirements

- **Physical device required** for realistic testing:
  - Background modes don't work properly in iOS Simulator
  - Heart rate monitoring requires real Bluetooth devices
  - Apple Music playback needs device

- **Test scenarios**:
  - Start zone training → background app → verify announcements continue
  - Start VO2 training → verify playlist switches at intervals
  - Connect HR monitor → verify real-time updates
  - Test audio announcements over music playback
  - Verify zone announcements duck Apple Music properly

- **Untethered testing**:
  - Test without Xcode connected for realistic background behavior
  - Use Console app to view logs if needed

## Critical Configuration

### Info.plist Requirements
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>RunBeat needs Bluetooth access to connect to your heart rate monitor for training.</string>

<key>NSAppleMusicUsageDescription</key>
<string>RunBeat needs access to Apple Music to play playlists during VO2 max training.</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>audio</string>
</array>
```

### Entitlements
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

## Architecture Patterns

### Shared Services Pattern
- HeartRateService and ZoneAnnouncementCoordinator eliminate code duplication
- Both Free Training and VO2 Max Training use the same core services
- Single source of truth for HR processing and announcements

### Dual Training Mode Architecture
- AppState enforces mutual exclusion (only one mode active at a time)
- Independent managers for each mode (FreeTrainingManager, VO2MaxTrainingManager)
- Shared services for consistent behavior across modes

### Pre-warming Pattern
- SpeechAnnouncer pre-warms AVAudioPlayer on app launch
- Eliminates 4-5 second delay on first announcement
- Loads zone1.mp3 during initialization to prime audio subsystem

### Audio Session Management
- MusicKitService configures session with `.mixWithOthers` and `.duckOthers` from start
- Zone announcements use existing session without reconfiguration
- Prevents 3-6 second hangs from session reconfiguration during playback

## Known Limitations

- **Apple Music subscription required** for playlist playback
- **Physical device required** for background execution testing
- **Bluetooth HR monitor required** for heart rate features
- **iOS 17.0+** required for MusicKit integration

## Contributing

When contributing to RunBeat:

1. **Use the design system** - Always use AppColors, AppTypography, AppButton, etc.
2. **Follow MVVM** - Keep business logic in ViewModels, not Views
3. **Use AppLogger** - Replace print() with appropriate log levels
4. **Test on device** - Background modes require physical device testing
5. **Check CLAUDE.md** - Read development guidelines before making changes