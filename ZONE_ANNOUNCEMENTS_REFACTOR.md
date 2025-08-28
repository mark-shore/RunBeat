# Zone Announcements Refactoring Plan

## Overview

This document outlines the plan to decouple heart rate monitoring from zone announcements, allowing VO2 training to maintain background HR monitoring while disabling audio announcements.

## Current Architecture Analysis

### Heart Rate Monitoring Flow
1. **HeartRateManager** (CoreBluetooth) → **AppState.setupHeartRateMonitoring()** at `AppState.swift:38`
2. **AppState** processes HR data → calls **trainingManager.processHeartRate(bpm)** at `AppState.swift:42`
3. **HeartRateTrainingManager.processHeartRate()** (`HeartRateTrainingManager.swift:52-78`) calculates zones and triggers announcements
4. Zone announcements use delegate pattern: **HeartRateTrainingDelegate** protocol (`HeartRateTrainingManager.swift:11-15`)
5. **AppState** implements delegate (`AppState.swift:132-146`) and controls announcements via **shouldAnnounceZone()** (`AppState.swift:137-140`)
6. Actual announcements executed via **SpeechAnnouncer.announceZone()** (`SpeechAnnouncer.swift:12-30`)

### Key Files & Relationships
- `HeartRateManager.swift`: CoreBluetooth HR monitoring (DO NOT MODIFY)
- `HeartRateTrainingManager.swift`: Zone calculation + announcement triggering
- `AppState.swift`: Central coordinator, implements HeartRateTrainingDelegate
- `VO2MaxTrainingManager.swift`: Only receives HR updates via tick() at `AppState.swift:43`
- `SpeechAnnouncer.swift`: Audio announcement execution

## Problem Statement

**Current Issue:** VO2 training requires continuous HR monitoring for background execution but doesn't need zone announcements, which can interfere with training audio cues.

**Goal:** Make zone announcements configurable while maintaining HR monitoring for all training modes.

## Implementation Plan

### Phase 1: Add Announcement Control Infrastructure
- [ ] **AppState.swift:8** - Add `@Published var announcementsEnabled = true` property
- [ ] **AppState.swift:137-140** - Modify `shouldAnnounceZone()` to check `announcementsEnabled` flag
  ```swift
  func heartRateTraining(_ manager: HeartRateTrainingManager, shouldAnnounceZone zone: Int) -> Bool {
      return isSessionActive && announcementsEnabled
  }
  ```

### Phase 2: Wire VO2 Training Controls  
- [ ] **VO2MaxTrainingManager.swift:52** - Add `private weak var appState: AppState?` property
- [ ] **VO2MaxTrainingManager.swift** - Add announcement control methods:
  ```swift
  func setAnnouncementsEnabled(_ enabled: Bool) {
      appState?.announcementsEnabled = enabled
  }
  ```
- [ ] **VO2MaxTrainingManager.swift:67-84** - Disable announcements in `startTraining()` after line 83:
  ```swift
  // Disable zone announcements during VO2 training
  setAnnouncementsEnabled(false)
  ```
- [ ] **VO2MaxTrainingManager.swift:118-142** - Re-enable announcements in `stopTraining()` after line 141:
  ```swift
  // Re-enable zone announcements  
  setAnnouncementsEnabled(true)
  ```
- [ ] **VO2MaxTrainingManager.swift:145-159** - Re-enable announcements in `resetToSetup()` after line 158:
  ```swift
  // Re-enable zone announcements
  setAnnouncementsEnabled(true)
  ```

### Phase 3: AppState Integration
- [ ] **AppState.swift** - Inject AppState reference into VO2MaxTrainingManager.shared
- [ ] **AppState.swift** - Ensure proper initialization order

## Testing Checklist

### Functional Testing
- [ ] **Normal Training Mode**: Start session → verify zone announcements work as before
- [ ] **VO2 Training Mode**: Start VO2 training → verify no zone announcements
- [ ] **VO2 to Normal**: Start VO2 → stop → start normal training → verify announcements resume
- [ ] **Background HR Monitoring**: All modes continue HR monitoring when app backgrounded
- [ ] **Zone Calculation**: HR zones still calculated correctly in all modes (check logs)

### Integration Testing  
- [ ] **Spotify Integration**: VO2 training playlist switching works without announcement interference
- [ ] **Audio Ducking**: Normal training announcements still duck Spotify properly
- [ ] **State Persistence**: App restart maintains correct announcement settings

### Edge Cases
- [ ] **Rapid Mode Switching**: Normal → VO2 → Normal → VO2 (verify state consistency)
- [ ] **App Backgrounding**: Mode switches while app backgrounded
- [ ] **HR Device Disconnect**: Reconnection maintains proper announcement state

## Rollback Plan

### If Issues Arise:
1. **Immediate Rollback**: Revert `shouldAnnounceZone()` to original implementation
2. **Remove New Properties**: Delete `announcementsEnabled` and related code
3. **Verify Core Functions**: Ensure HR monitoring and announcements work as before
4. **Test Critical Path**: Normal training mode functionality intact

### Backup Critical Files:
- [ ] **AppState.swift** - Copy current version before modifications
- [ ] **VO2MaxTrainingManager.swift** - Copy current version before modifications

## Success Criteria

- ✅ HR monitoring continues running in background for all training modes
- ✅ Normal training sessions have zone announcements (existing behavior)  
- ✅ VO2 training sessions have no zone announcements
- ✅ Clean transitions between training modes
- ✅ No regression in existing functionality
- ✅ Code maintains current architecture patterns

## Risk Assessment

**Low Risk Changes:**
- Adding `announcementsEnabled` flag (additive change)
- Modifying delegate method logic (isolated impact)

**Medium Risk Changes:**  
- VO2MaxTrainingManager reference injection (affects initialization)

**Mitigation:**
- Test on physical device (background modes required)
- Verify with real HR monitor and Spotify integration
- Incremental implementation with testing at each phase

---

**Status:** Planning Complete
**Next Step:** Begin Phase 1 Implementation