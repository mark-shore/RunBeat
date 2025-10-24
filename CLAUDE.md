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
- Dependencies: None (native iOS frameworks only)

## Architecture Overview

RunBeat is an iOS heart rate training app built with **SwiftUI + MVVM architecture**. The app is designed for "phone-away" training with real-time audio announcements.

### Key Architectural Principles
- **Feature-based modules** in `Features/` directory
- **Design system** with reusable components in `UI/DesignSystem/`
- **Service layer** for external integrations (Bluetooth, Apple Music)
- **Background execution** for continuous heart rate monitoring

### Critical Systems (DO NOT MODIFY)
- `HeartRateManager`: CoreBluetooth heart rate monitoring - working perfectly
- Background execution logic for continuous monitoring
- Audio announcement timing and cooldown system
- **Zone announcement pre-warming**: SpeechAnnouncer initializes AVAudioPlayer on app launch for instant playback
- **Apple Music integration**: MusicKitService with proper audio session configuration for zone announcement ducking

### Core Modules

#### Heart Rate Module (`Features/HeartRate/`)
- `HeartRateManager.swift`: CoreBluetooth integration for HR monitoring
- `HeartRateZoneCalculator.swift`: Pure zone calculation logic
- `HeartRateViewModel.swift`: UI state and settings persistence

#### Core Services (`Core/Services/`)
- `HeartRateService.swift`: Shared HR processing and zone calculation service
- `ZoneAnnouncementCoordinator.swift`: Per-training-mode announcement management with UserDefaults persistence
- `SpeechAnnouncer.swift`: Audio announcement execution with pre-warming for instant playback
- `AudioService.swift`: Audio session and volume management
- `AppLogger.swift`: Centralized logging system with rate limiting and structured output

#### Free Training Module (`Features/FreeTraining/`)
- `FreeTrainingManager.swift`: Simple background HR monitoring with announcements (replaces legacy HeartRateTrainingManager)
- **Uses shared services**: HeartRateService and ZoneAnnouncementCoordinator instead of duplicating logic

#### Apple Music Module (`Features/Music/`)
- `MusicKitService.swift`: Core Apple Music API integration with authorization, playlist fetching, and playback control
- `MusicViewModel.swift`: UI state management with playlist selection and persistence
- `MusicPlaylist.swift`: Data model for Apple Music library playlists
- **Audio Session Management**: Configured with `.mixWithOthers` and `.duckOthers` from startup to prevent reconfiguration hangs
- **ApplicationMusicPlayer**: Native iOS music player for library playlist playback
- Features: Authorization flow, playlist selection, automatic playlist switching during VO2 intervals, play/pause controls

#### VO2 Training Module (`Features/VO2Training/`)
- `VO2MaxTrainingManager.swift`: 4x4 interval training coordination with shared HR services and Apple Music integration
- `VO2MaxTrainingView.swift`: Training UI with design system integration and VO2-specific settings access
- `VO2TrainingBottomDrawer.swift`: Context-aware bottom drawer with smooth content-based animations
- `VO2SettingsManager.swift`: Simple settings management for VO2-specific announcements with UserDefaults persistence
- `VO2SettingsView.swift`: Navigation-based settings screen for zone announcement controls
- **Apple Music Integration**: Automatic playlist switching between high intensity and rest periods
- **Smart Drawer Interface**: State-aware UI showing playlist selection with persistent preferences
- **Training Completion**: Bottom drawer remains visible with music playback controls during completion screen
- **VO2 Settings**: Gear icon in setup state provides access to zone announcement controls with persistent preferences
- Features: Structured intervals, Apple Music playlist switching, configurable zone announcements, play/pause controls

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
- `AppIcons.swift`: Centralized SF Symbol constants for consistent iconography
- `Components/`: Reusable UI components (AppButton, AppCard, AppBackButton, etc.)
  - `AppBackButton.swift`: Custom navigation back button with white arrow.left icon
  - `AppIconButton.swift`: Standardized icon button component with size variants and convenience methods
  - `AppToggle.swift`: Consistent toggle styling with design system colors and scaling
  - `BPMValueBox.swift`: Styled container for editable heart rate values with state-based interaction hints
  - `PickerModal.swift`: Unified modal component for heart rate value selection with consistent presentation
  - `CurrentTrackView.swift`: Display component for current playing track from Apple Music

## Development Guidelines

### Threading Requirements
- UI updates MUST use `@MainActor` or `DispatchQueue.main.async`
- Background services handle their own threading
- ViewModels use `@Published` properties for reactive updates

### Design System Usage
- Always use design system components: `AppButton`, `AppCard`, `AppBackButton`, `AppIconButton`, `AppToggle`, `AppColors`, etc.
- **Icons**: Use `AppIcons` constants for all SF Symbols and `AppIconButton` for standardized icon buttons
- **Toggles**: Use `AppToggle` component instead of custom Toggle styling to maintain consistency
- Follow existing spacing patterns from `AppSpacing`
- Use consistent spacing constants instead of hardcoded values
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
1. **User Onboarding**: Guide new users through HR zone setup and Apple Music authorization
2. **Training Analytics**: Add workout history and performance tracking
3. **UI Polish**: Training mode descriptions and visual improvements

## Testing Requirements

### Physical Device Required
- Background modes don't work in iOS Simulator
- Heart rate monitoring requires real Bluetooth devices
- **Apple Music requires Apple Music subscription** for playlist playback

### Test Scenarios
- Start zone training → background app → verify announcements continue
- Start VO2 training → verify playlist switches at intervals (works reliably in background)
- Connect HR monitor → verify real-time updates
- Test audio announcements over music playback
- **Apple Music Testing**: Verify zone announcements duck music properly during VO2 training
- **Playlist Switching**: Start VO2 training → verify automatic playlist switching between work and rest periods
- **Authorization Flow**: First launch → authorize Apple Music → select playlists → verify persistence

## Configuration

### Required Setup
- **Apple Music subscription** for playlist playback
- Background modes in `Info.plist`: `bluetooth-central`, `audio`
- Heart rate zones: Auto-calculated via Karvonen formula or manual override
- Apple Music authorization: First-time users must authorize via in-app prompt

### Critical Files
- `Config.plist`: App configuration (currently empty after Spotify removal)
- `runbeat.entitlements`: Background execution permissions
- `Info.plist`: Bluetooth and Apple Music usage descriptions, background modes

## Known Issues

### Production-Ready Systems
- ✅ **Zone Announcement Pre-warming**: AVAudioPlayer initialized on app launch eliminates 4-5 second delay
- ✅ **Apple Music Integration**: Full MusicKit integration with authorization, playlist fetching, and playback control
- ✅ **Audio Session Management**: Proper `.mixWithOthers` and `.duckOthers` configuration prevents reconfiguration hangs
- ✅ **Playlist Switching**: Automatic playlist switching during VO2 Max intervals works reliably in background
- ✅ **Logging System**: Structured AppLogger system with rate limiting and environment-aware log levels

### Current Areas for Improvement
- Live BPM not displayed during training screens
- User onboarding could be more guided for new users
- Training analytics and workout history tracking

### Logging Guidelines
- **Use AppLogger instead of print()**: All logging should use `AppLogger` with appropriate log levels
- **Log Levels**: ERROR (production issues), WARN (recoverable issues), INFO (key events), DEBUG (development info), VERBOSE (detailed debugging)
- **Rate Limiting**: AppLogger automatically prevents spam with 5-second rate limiting windows
- **Specialized Methods**: Use `AppLogger.apiResponse()` for API calls, `AppLogger.rateLimited()` for high-frequency events
- **Environment Aware**: Production defaults to INFO level, debug builds use VERBOSE

### Development Rules
- Never modify `HeartRateManager`'s core Bluetooth logic
- Preserve all background execution functionality (working reliably)
- Keep audio announcement timing unchanged
- **Audio Session Configuration**: Never reconfigure audio session during music playback - causes 3-6 second hangs
- **Pre-warming Pattern**: Maintain SpeechAnnouncer pre-warming on app launch for instant announcements
- **Logging**: Use `AppLogger` instead of `print()` statements for all new code
- Test on physical device for realistic behavior
- Use design system components consistently

## Production Architecture (2025)

The following systems have been implemented and are production-ready:

### Apple Music Integration (2025)

**System Overview**: Complete Apple Music integration using MusicKit for library playlist access and playback control.

**Architecture Components**:
1. **MusicKitService** (`Features/Music/MusicKitService.swift`)
   - Full Apple Music API integration (authorization, playlist fetching, playback control)
   - Uses `ApplicationMusicPlayer` for library playlist playback
   - Proper audio session configuration with `.mixWithOthers` and `.duckOthers` from startup
   - Play/pause, resume, stop controls
   - Queue management with repeat mode for training sessions
   - Background playback support

2. **MusicViewModel** (`Features/Music/MusicViewModel.swift`)
   - Apple Music UI state management with `@Published` properties
   - Authorization status tracking
   - Playlist selection and persistence via UserDefaults
   - Play/pause state management
   - Computed properties for playlist configuration status

3. **MusicPlaylist Model** (`Features/Music/Models/MusicPlaylist.swift`)
   - Data structure for Apple Music library playlists
   - Maps from MusicKit `Playlist` type
   - Codable for UserDefaults persistence
   - Contains: id, name, track count, artwork

**VO2 Max Training Integration**:
- Automatic playlist switching between high intensity and rest periods
- Play/pause controls during training and completion screens
- Persistent playlist selection across app restarts
- Background-aware playlist switching for phone-away training

**Technical Benefits**: Native iOS integration, no backend required, seamless playlist access, proper audio ducking for zone announcements, reliable background execution.

### Zone Announcement Pre-warming (2025)

**Problem Solved**: First zone announcement had 4-5 second delay due to lazy AVAudioPlayer initialization.

**Solution Implemented**:
- **SpeechAnnouncer Pre-warming** (`Core/Services/SpeechAnnouncer.swift`)
  - Initializes AVAudioPlayer on app launch
  - Loads zone1.mp3 during init() to prime audio subsystem
  - Eliminates lazy initialization delay
  - Comprehensive timing logs with AppLogger

**Technical Benefits**: Instant zone announcements from first use, eliminates user-perceived delay, maintains audio quality, simple implementation.

### Audio Session Management (2025)

**Problem Solved**: Reconfiguring audio session during music playback caused 3-6 second hangs.

**Solution Implemented**:
- **MusicKitService Configuration** (`Features/Music/MusicKitService.swift`)
  - Audio session configured with `.mixWithOthers` and `.duckOthers` from startup
  - Session configuration never changed during playback
  - Zone announcements use existing session without reconfiguration

**Technical Benefits**: Eliminates hangs during zone announcements, proper music ducking, seamless audio mixing, reliable background execution.

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
   - Consistent music behavior - both manual stop and natural completion continue music playback
   - Added `@MainActor` annotations for proper Swift concurrency handling
   - Maintained backward compatibility with legacy `stopTraining()` method

4. **Consistent State Management** (`AppState.swift`)
   - Updated to use unified `endTraining()` method throughout
   - Added `cleanupVO2Training()` convenience method for consistent termination

**Technical Benefits**: Eliminates accidental workout dismissal during serious training, provides consistent music behavior, maintains all existing background execution and Apple Music integration while modernizing navigation patterns for iOS 16+ compatibility.

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
