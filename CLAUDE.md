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

### Core Modules

#### Heart Rate Module (`Features/HeartRate/`)
- `HeartRateManager.swift`: CoreBluetooth integration for HR monitoring
- `HeartRateTrainingManager.swift`: Training session state management
- `HeartRateZoneCalculator.swift`: Pure zone calculation logic
- `HeartRateViewModel.swift`: UI state and settings persistence

#### Spotify Module (`Features/Spotify/`)
- `SpotifyService.swift`: OAuth, API calls, and playbook control
- `SpotifyViewModel.swift`: UI state management for authentication
- Handles both foreground (App Remote) and background (Web API) playback

#### VO2 Training Module (`Features/VO2Training/`)
- `VO2MaxTrainingManager.swift`: 4x4 interval training coordination
- `VO2MaxTrainingView.swift`: Training UI with design system integration
- Automatic playlist switching during intervals

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
- ViewModels manage UI state with `@Published` properties
- Services handle business logic and external integrations
- UserDefaults for settings persistence (preserve existing keys)

### Current Priority Issues
1. **Playlist Selection UI**: VO2 training requires user-selectable playlists
2. **Live HR Display**: Add current BPM to training screens
3. **Training Mode Clarity**: Improve mode names and descriptions

## Testing Requirements

### Physical Device Required
- Background modes don't work in iOS Simulator
- Heart rate monitoring requires real Bluetooth devices
- Spotify App Remote needs installed Spotify app

### Test Scenarios
- Start zone training → background app → verify announcements continue
- Start VO2 training → verify playlist switches at intervals
- Connect HR monitor → verify real-time updates
- Test audio announcements over music playback

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

### Current Problems
- Playlist selection UI missing for VO2 training (blocks feature)
- Live BPM not displayed during training sessions

### Development Rules
- Never modify `HeartRateManager`'s core Bluetooth logic
- Preserve all background execution functionality
- Keep audio announcement timing unchanged
- Test on physical device for realistic behavior
- Don't break Spotify authentication flow