# MVVM Refactoring Plan for RunBeat

## Overview

This document outlines a comprehensive plan to refactor RunBeat from its current mixed architecture to a pure MVVM (Model-View-ViewModel) pattern. The goal is to achieve better separation of concerns, improved testability, and enhanced maintainability.

## Current Architecture Analysis

### Current State (~70% MVVM)

**✅ Good MVVM Examples:**
- `HeartRateViewModel`: Pure UI state management for HR zone settings
- `SpotifyViewModel`: Manages Spotify connection and playlist state
- `VO2MaxTrainingManager`: Observable object with published properties

**❌ MVVM Violations:**
- `AppState`: "God object" mixing view state, business logic, and infrastructure
- Views directly accessing multiple managers/services
- Missing dedicated ViewModels for complex views
- Business logic scattered across Views and mixed objects

### Architecture Problems to Solve

1. **Fat Controllers**: `AppState` handles too many responsibilities
2. **Tight Coupling**: Views directly depend on multiple services
3. **Poor Testability**: Business logic mixed with UI concerns
4. **Inconsistent Patterns**: Some MVVM, some direct service access

## Target MVVM Architecture

### MVVM Layer Definitions

```
┌─────────────────┐
│     VIEWS       │ ← SwiftUI Views (UI only)
│   (SwiftUI)     │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│   VIEWMODELS    │ ← UI State + User Actions
│ (@ObservableObject) │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│    SERVICES     │ ← Business Logic + Data Operations  
│   (Pure Swift)  │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│     MODELS      │ ← Data Structures
│   (Structs)     │
└─────────────────┘
```

### Responsibility Matrix

| Layer | Responsibilities | What NOT to Include |
|-------|-----------------|-------------------|
| **Views** | UI layout, user interactions, navigation | Business logic, data processing, service calls |
| **ViewModels** | UI state, user action handling, data formatting | Direct hardware access, file I/O, complex algorithms |
| **Services** | Business logic, data operations, external APIs | UI state, SwiftUI dependencies |
| **Models** | Data structures, computed properties | Business logic, UI formatting |

## Refactoring Plan

### Phase 1: Service Layer Creation

**Objective**: Extract business logic from AppState into focused services

#### 1.1 Create Core Services

**TrainingCoordinatorService**
```swift
protocol TrainingCoordinatorService {
    var activeMode: CurrentValueSubject<TrainingMode, Never> { get }
    func startFreeTraining() async throws
    func startVO2Training() async throws  
    func stopCurrentTraining() async throws
}

class DefaultTrainingCoordinatorService: TrainingCoordinatorService {
    private let heartRateService: HeartRateService
    private let audioService: AudioService
    private let freeTrainingService: FreeTrainingService
    private let vo2TrainingService: VO2TrainingService
    
    // Pure business logic, no UI concerns
}
```

**HeartRateMonitoringService**
```swift
protocol HeartRateMonitoringService {
    var currentBPM: CurrentValueSubject<Int, Never> { get }
    var connectionStatus: CurrentValueSubject<ConnectionStatus, Never> { get }
    func startMonitoring() async throws
    func stopMonitoring() async
}

class DefaultHeartRateMonitoringService: HeartRateMonitoringService {
    private let heartRateManager: HeartRateManager
    // Wraps HeartRateManager with service interface
}
```

**ZoneAnnouncementService**
```swift
protocol ZoneAnnouncementService {
    func configureAnnouncements(for mode: TrainingMode, enabled: Bool)
    func announceZone(_ zone: Int, for mode: TrainingMode) async
    func resetAnnouncements()
}

class DefaultZoneAnnouncementService: ZoneAnnouncementService {
    private let speechAnnouncer: SpeechAnnouncer
    private let audioService: AudioService
    private let coordinator: ZoneAnnouncementCoordinator
}
```

#### 1.2 Service Dependencies

```swift
// Service Registry for dependency injection
class ServiceRegistry {
    lazy var trainingCoordinator: TrainingCoordinatorService = DefaultTrainingCoordinatorService(
        heartRateService: heartRateService,
        audioService: audioService,
        freeTrainingService: freeTrainingService,
        vo2TrainingService: vo2TrainingService
    )
    
    lazy var heartRateMonitoring: HeartRateMonitoringService = DefaultHeartRateMonitoringService(
        heartRateManager: HeartRateManager()
    )
    
    lazy var zoneAnnouncement: ZoneAnnouncementService = DefaultZoneAnnouncementService(
        speechAnnouncer: SpeechAnnouncer(),
        audioService: AudioService(),
        coordinator: ZoneAnnouncementCoordinator()
    )
    
    // ... other services
}
```

### Phase 2: ViewModel Creation

**Objective**: Create focused ViewModels for each major view

#### 2.1 ContentViewModel

```swift
class ContentViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentBPM: Int = 0
    @Published var isTrainingActive: Bool = false
    @Published var trainingMode: TrainingMode = .none
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Dependencies  
    private let trainingCoordinator: TrainingCoordinatorService
    private let heartRateMonitoring: HeartRateMonitoringService
    private var cancellables = Set<AnyCancellable>()
    
    init(
        trainingCoordinator: TrainingCoordinatorService,
        heartRateMonitoring: HeartRateMonitoringService
    ) {
        self.trainingCoordinator = trainingCoordinator
        self.heartRateMonitoring = heartRateMonitoring
        setupBindings()
    }
    
    // MARK: - User Actions
    func startFreeTraining() {
        Task {
            try await trainingCoordinator.startFreeTraining()
        }
    }
    
    func stopTraining() {
        Task {
            try await trainingCoordinator.stopCurrentTraining()
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        heartRateMonitoring.currentBPM
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentBPM)
            
        trainingCoordinator.activeMode
            .receive(on: DispatchQueue.main)
            .map { $0 != .none }
            .assign(to: &$isTrainingActive)
    }
}
```

#### 2.2 VO2TrainingViewModel  

```swift
class VO2TrainingViewModel: ObservableObject {
    // MARK: - Published State
    @Published var trainingState: TrainingState = .setup
    @Published var currentPhase: TrainingPhase = .notStarted  
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentInterval: Int = 0
    @Published var currentBPM: Int = 0
    @Published var currentZone: Int? = nil
    @Published var announcementsEnabled: Bool = true
    
    // MARK: - Dependencies
    private let vo2TrainingService: VO2TrainingService
    private let heartRateMonitoring: HeartRateMonitoringService
    private let zoneAnnouncementService: ZoneAnnouncementService
    private let spotifyService: SpotifyService
    
    // MARK: - User Actions  
    func startTraining() {
        Task {
            try await vo2TrainingService.startTraining()
        }
    }
    
    func stopTraining() {
        Task {
            await vo2TrainingService.stopTraining()
        }
    }
    
    func toggleAnnouncements() {
        announcementsEnabled.toggle()
        zoneAnnouncementService.configureAnnouncements(
            for: .vo2Max, 
            enabled: announcementsEnabled
        )
    }
}
```

#### 2.3 SettingsViewModel

```swift
class SettingsViewModel: ObservableObject {
    // MARK: - Published State  
    @Published var restingHR: Int = 60
    @Published var maxHR: Int = 190
    @Published var useAutoZones: Bool = true
    @Published var manualZones: ManualZones = ManualZones.default
    @Published var announcementsEnabled: Bool = true
    
    // MARK: - Dependencies
    private let settingsService: SettingsService
    private let zoneAnnouncementService: ZoneAnnouncementService
    
    // MARK: - User Actions
    func saveSettings() {
        Task {
            let settings = HeartRateSettings(
                restingHR: restingHR,
                maxHR: maxHR, 
                useAutoZones: useAutoZones,
                manualZones: manualZones
            )
            try await settingsService.saveHeartRateSettings(settings)
        }
    }
    
    func resetToDefaults() {
        Task {
            let defaults = await settingsService.getDefaultHeartRateSettings()
            await MainActor.run {
                self.restingHR = defaults.restingHR
                self.maxHR = defaults.maxHR
                // ... update other properties
            }
        }
    }
}
```

### Phase 3: View Refactoring

**Objective**: Simplify views to only handle UI concerns

#### 3.1 ContentView Refactoring

**Before (Current):**
```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var spotifyViewModel = SpotifyViewModel.shared
    
    var body: some View {
        // Direct access to multiple services
        if appState.isSessionActive {
            // Business logic in view
        }
    }
}
```

**After (Pure MVVM):**
```swift
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    
    init(viewModel: ContentViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            HeartRateDisplayView(
                bpm: viewModel.currentBPM,
                zone: viewModel.currentZone
            )
            
            TrainingControlsView(
                isActive: viewModel.isTrainingActive,
                onStart: viewModel.startFreeTraining,
                onStop: viewModel.stopTraining
            )
        }
        .navigationTitle("RunBeat")
    }
}
```

#### 3.2 View Component Extraction

```swift
// Extract reusable view components
struct HeartRateDisplayView: View {
    let bpm: Int
    let zone: Int?
    
    var body: some View {
        // Pure UI component
    }
}

struct TrainingControlsView: View {
    let isActive: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        // Pure UI component with callbacks
    }
}
```

### Phase 4: Model Layer Enhancement

**Objective**: Create proper model objects for data transfer

#### 4.1 Core Models

```swift
// Training Models
struct TrainingSession {
    let id: UUID
    let mode: TrainingMode
    let startTime: Date
    let endTime: Date?
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let timeInZones: [Int: TimeInterval]
}

struct TrainingState {
    let mode: TrainingMode
    let phase: TrainingPhase?
    let currentInterval: Int?
    let timeRemaining: TimeInterval?
    let isActive: Bool
}

// Heart Rate Models  
struct HeartRateSettings {
    let restingHR: Int
    let maxHR: Int
    let useAutoZones: Bool
    let manualZones: ManualZones
}

struct ManualZones {
    let zone1Lower: Int
    let zone1Upper: Int  
    let zone2Upper: Int
    let zone3Upper: Int
    let zone4Upper: Int
    let zone5Upper: Int
    
    static let `default` = ManualZones(
        zone1Lower: 60, zone1Upper: 70,
        zone2Upper: 80, zone3Upper: 90, 
        zone4Upper: 100, zone5Upper: 110
    )
}

// Spotify Models (if not already proper models)
struct SpotifyTrack {
    let id: String
    let name: String
    let artist: String
    let albumArt: URL?
    let duration: TimeInterval
}

struct SpotifyPlaylist {
    let id: String
    let name: String
    let trackCount: Int
    let imageURL: URL?
    let isOwned: Bool
}
```

#### 4.2 Result/Error Types

```swift
enum TrainingError: LocalizedError {
    case heartRateMonitorNotConnected
    case trainingAlreadyActive
    case spotifyNotConnected
    case configurationInvalid
    
    var errorDescription: String? {
        switch self {
        case .heartRateMonitorNotConnected:
            return "Heart rate monitor not connected"
        case .trainingAlreadyActive:
            return "Training session already active"
        case .spotifyNotConnected:
            return "Spotify not connected"
        case .configurationInvalid:
            return "Training configuration is invalid"
        }
    }
}

enum ConnectionStatus {
    case disconnected
    case connecting  
    case connected
    case failed(Error)
}
```

### Phase 5: Dependency Injection Setup

**Objective**: Establish clean dependency injection

#### 5.1 Dependency Container

```swift
class DependencyContainer {
    // MARK: - Services
    lazy var serviceRegistry = ServiceRegistry()
    
    // MARK: - ViewModels
    func makeContentViewModel() -> ContentViewModel {
        ContentViewModel(
            trainingCoordinator: serviceRegistry.trainingCoordinator,
            heartRateMonitoring: serviceRegistry.heartRateMonitoring
        )
    }
    
    func makeVO2TrainingViewModel() -> VO2TrainingViewModel {
        VO2TrainingViewModel(
            vo2TrainingService: serviceRegistry.vo2TrainingService,
            heartRateMonitoring: serviceRegistry.heartRateMonitoring,
            zoneAnnouncementService: serviceRegistry.zoneAnnouncementService,
            spotifyService: serviceRegistry.spotifyService
        )
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsService: serviceRegistry.settingsService,
            zoneAnnouncementService: serviceRegistry.zoneAnnouncementService
        )
    }
}
```

#### 5.2 App Integration

```swift
@main
struct RunBeatApp: App {
    private let dependencies = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: dependencies.makeContentViewModel()
            )
        }
    }
}
```

### Phase 6: Testing Strategy

**Objective**: Enable comprehensive unit testing

#### 6.1 Service Testing

```swift
@testable import RunBeat
import XCTest
import Combine

class TrainingCoordinatorServiceTests: XCTestCase {
    var sut: DefaultTrainingCoordinatorService!
    var mockHeartRateService: MockHeartRateService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockHeartRateService = MockHeartRateService()
        sut = DefaultTrainingCoordinatorService(
            heartRateService: mockHeartRateService,
            audioService: MockAudioService(),
            freeTrainingService: MockFreeTrainingService(),
            vo2TrainingService: MockVO2TrainingService()
        )
        cancellables = Set<AnyCancellable>()
    }
    
    func testStartFreeTraining_UpdatesActiveMode() async throws {
        // Given
        let expectation = expectation(description: "Active mode updated")
        sut.activeMode
            .dropFirst()
            .sink { mode in
                XCTAssertEqual(mode, .free)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        try await sut.startFreeTraining()
        
        // Then  
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
```

#### 6.2 ViewModel Testing

```swift
class ContentViewModelTests: XCTestCase {
    var sut: ContentViewModel!
    var mockTrainingCoordinator: MockTrainingCoordinatorService!
    var mockHeartRateMonitoring: MockHeartRateMonitoringService!
    
    override func setUp() {
        super.setUp()
        mockTrainingCoordinator = MockTrainingCoordinatorService()
        mockHeartRateMonitoring = MockHeartRateMonitoringService()
        sut = ContentViewModel(
            trainingCoordinator: mockTrainingCoordinator,
            heartRateMonitoring: mockHeartRateMonitoring
        )
    }
    
    func testStartFreeTraining_CallsTrainingCoordinator() {
        // When
        sut.startFreeTraining()
        
        // Then
        XCTAssertTrue(mockTrainingCoordinator.startFreeTrainingCalled)
    }
    
    func testHeartRateUpdate_UpdatesBPMProperty() {
        // Given
        let expectedBPM = 75
        
        // When
        mockHeartRateMonitoring.currentBPMSubject.send(expectedBPM)
        
        // Then
        XCTAssertEqual(sut.currentBPM, expectedBPM)
    }
}
```

## Implementation Timeline

### Week 1: Foundation
- **Day 1-2**: Create service protocols and basic implementations
- **Day 3-4**: Set up dependency injection container
- **Day 5**: Create core model objects

### Week 2: Service Layer  
- **Day 1-2**: Implement TrainingCoordinatorService
- **Day 3**: Implement HeartRateMonitoringService
- **Day 4**: Implement ZoneAnnouncementService  
- **Day 5**: Service integration testing

### Week 3: ViewModel Layer
- **Day 1-2**: Create and integrate ContentViewModel
- **Day 3**: Create and integrate VO2TrainingViewModel
- **Day 4**: Create and integrate SettingsViewModel
- **Day 5**: ViewModel integration testing

### Week 4: View Refactoring
- **Day 1-2**: Refactor ContentView and extract components
- **Day 3**: Refactor VO2MaxTrainingView  
- **Day 4**: Refactor SettingsView
- **Day 5**: End-to-end testing and cleanup

### Week 5: Testing & Polish
- **Day 1-3**: Write comprehensive unit tests
- **Day 4**: Performance testing and optimization
- **Day 5**: Documentation and code review

## Migration Strategy

### Incremental Approach
1. **Parallel Development**: Build new MVVM components alongside existing code
2. **Feature Flags**: Use conditional compilation to switch between old/new implementations
3. **Gradual Migration**: Migrate one view at a time, starting with least complex
4. **Backward Compatibility**: Maintain existing interfaces during transition

### Risk Mitigation
- **Comprehensive Testing**: Unit tests for all new components before migration
- **Feature Parity**: Ensure new implementation matches all existing functionality  
- **Rollback Plan**: Ability to revert to previous implementation if issues arise
- **Staged Deployment**: Test each migration step thoroughly before proceeding

## Success Criteria

### Technical Metrics
- **Test Coverage**: >90% unit test coverage for ViewModels and Services
- **Build Performance**: No regression in build times
- **Runtime Performance**: No regression in app performance
- **Memory Usage**: No increase in memory footprint

### Code Quality Metrics  
- **Cyclomatic Complexity**: Reduce average complexity per class
- **Lines of Code**: Reduce LoC in view controllers/managers
- **Dependency Count**: Reduce number of dependencies per class
- **MVVM Compliance**: 100% of views follow pure MVVM pattern

### Functional Requirements
- **Feature Parity**: All existing functionality preserved
- **Background Execution**: No regression in background HR monitoring
- **Announcement System**: Zone announcements work identically
- **Spotify Integration**: No regression in music control features

## Future Benefits

### Developer Experience
- **Faster Development**: Clear patterns reduce decision fatigue
- **Easier Testing**: Isolated components enable comprehensive unit testing
- **Better Collaboration**: Clear boundaries improve team productivity
- **Reduced Bugs**: Separation of concerns reduces coupling-related issues

### Maintainability  
- **Single Responsibility**: Each class has one clear purpose
- **Easier Refactoring**: Changes isolated to appropriate layer
- **Better Documentation**: Clear interfaces document expected behavior
- **Scalability**: Architecture supports adding new features easily

### User Experience
- **Reliability**: Better testing leads to fewer crashes
- **Performance**: Optimized data flow reduces unnecessary updates  
- **Consistency**: Unified patterns create predictable behavior
- **Future Features**: Architecture supports advanced features (testing, analytics, etc.)

---

**Document Status**: Ready for Review and Approval  
**Estimated Effort**: 4-5 weeks full-time development  
**Risk Level**: Medium (incremental approach mitigates most risks)  
**Dependencies**: None (can be implemented alongside existing code)