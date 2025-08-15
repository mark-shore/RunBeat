//
//  HeartRateViewModel.swift
//  pulseprompt
//
//  MVVM ViewModel for heart rate zone settings UI state
//  Handles zone configuration, persistence, and UI binding
//

import Foundation
import Combine

class HeartRateViewModel: ObservableObject {
    
    // MARK: - Published UI State
    
    // Core heart rate settings
    @Published var restingHR: Int = 60 {
        didSet { saveZoneSettings() }
    }
    
    @Published var maxHR: Int = 190 {
        didSet { saveZoneSettings() }
    }
    
    @Published var useAutoZones: Bool = true {
        didSet {
            // When switching to manual zones, populate with current auto values
            if !useAutoZones && oldValue == true {
                updateManualZonesFromAuto()
            }
            saveZoneSettings()
        }
    }
    
    // Manual heart rate zones (used when useAutoZones is false)
    @Published var zone1Lower: Int = 60 {
        didSet { saveZoneSettings() }
    }
    
    @Published var zone1Upper: Int = 70 {
        didSet { saveZoneSettings() }
    }
    
    @Published var zone2Upper: Int = 80 {
        didSet { saveZoneSettings() }
    }
    
    @Published var zone3Upper: Int = 90 {
        didSet { saveZoneSettings() }
    }
    
    @Published var zone4Upper: Int = 100 {
        didSet { saveZoneSettings() }
    }
    
    @Published var zone5Upper: Int = 110 {
        didSet { saveZoneSettings() }
    }
    
    // MARK: - Dependencies
    
    private let userDefaults = UserDefaults.standard
    private var saveDebouncer: AnyCancellable?
    
    // MARK: - Initialization
    
    init() {
        loadZoneSettings()
    }
    
    // MARK: - Public API
    
    /// Get current zone settings for training manager
    func getCurrentZoneSettings() -> (restingHR: Int, maxHR: Int, useAutoZones: Bool, manualZones: (zone1Lower: Int, zone1Upper: Int, zone2Upper: Int, zone3Upper: Int, zone4Upper: Int, zone5Upper: Int)) {
        return (
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            manualZones: (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
        )
    }
    
    /// Get zone limits for display purposes
    var currentZoneLimits: (zone1Lower: Int, zone1Upper: Int, zone2Upper: Int, zone3Upper: Int, zone4Upper: Int, zone5Upper: Int) {
        return HeartRateZoneCalculator.getZoneLimits(
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            manualZones: (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
        )
    }
    
    /// Check if heart rate values are valid
    var isConfigurationValid: Bool {
        return restingHR > 0 && maxHR > restingHR && maxHR <= 220
    }
    
    /// Get validation error message if configuration is invalid
    var validationErrorMessage: String? {
        if restingHR <= 0 {
            return "Resting heart rate must be greater than 0"
        }
        if maxHR <= restingHR {
            return "Max heart rate must be greater than resting heart rate"
        }
        if maxHR > 220 {
            return "Max heart rate seems unusually high (>220 BPM)"
        }
        return nil
    }
    
    // MARK: - Zone Settings Persistence
    
    private func loadZoneSettings() {
        // Load heart rate settings
        restingHR = userDefaults.object(forKey: "restingHR") as? Int ?? 60
        maxHR = userDefaults.object(forKey: "maxHR") as? Int ?? 190
        useAutoZones = userDefaults.object(forKey: "useAutoZones") as? Bool ?? true
        
        // Load manual zone settings
        zone1Lower = userDefaults.object(forKey: "zone1Lower") as? Int ?? 60
        zone1Upper = userDefaults.object(forKey: "zone1Upper") as? Int ?? 70
        zone2Upper = userDefaults.object(forKey: "zone2Upper") as? Int ?? 80
        zone3Upper = userDefaults.object(forKey: "zone3Upper") as? Int ?? 90
        zone4Upper = userDefaults.object(forKey: "zone4Upper") as? Int ?? 100
        zone5Upper = userDefaults.object(forKey: "zone5Upper") as? Int ?? 110
        
        HeartRateZoneCalculator.logZoneSettings(
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            manualZones: (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
        )
    }
    
    private func saveZoneSettings() {
        // Debounce saves to avoid excessive UserDefaults writes
        saveDebouncer?.cancel()
        saveDebouncer = Just(())
            .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performSave()
            }
    }
    
    private func performSave() {
        // Save heart rate settings
        userDefaults.set(restingHR, forKey: "restingHR")
        userDefaults.set(maxHR, forKey: "maxHR")
        userDefaults.set(useAutoZones, forKey: "useAutoZones")
        
        // Save manual zone settings
        userDefaults.set(zone1Lower, forKey: "zone1Lower")
        userDefaults.set(zone1Upper, forKey: "zone1Upper")
        userDefaults.set(zone2Upper, forKey: "zone2Upper")
        userDefaults.set(zone3Upper, forKey: "zone3Upper")
        userDefaults.set(zone4Upper, forKey: "zone4Upper")
        userDefaults.set(zone5Upper, forKey: "zone5Upper")
        
        HeartRateZoneCalculator.logZoneSettings(
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            manualZones: (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
        )
    }
    
    /// Update manual zone values from current auto calculations
    private func updateManualZonesFromAuto() {
        let autoZones = HeartRateZoneCalculator.calculateAutoZones(restingHR: restingHR, maxHR: maxHR)
        zone1Lower = autoZones.0
        zone1Upper = autoZones.1
        zone2Upper = autoZones.2
        zone3Upper = autoZones.3
        zone4Upper = autoZones.4
        zone5Upper = autoZones.5
        print("📊 Manual zones updated from auto calculation: Z1(\(zone1Lower)-\(zone1Upper)), Z2(\(zone1Upper+1)-\(zone2Upper)), Z3(\(zone2Upper+1)-\(zone3Upper)), Z4(\(zone3Upper+1)-\(zone4Upper)), Z5(\(zone4Upper+1)-\(zone5Upper))")
    }
    
    // MARK: - Computed Properties for UI
    
    /// Heart rate reserve for display
    var heartRateReserve: Int {
        return maxHR - restingHR
    }
    
    /// Zone descriptions for UI display
    var zoneDescriptions: [String] {
        let limits = currentZoneLimits
        return [
            "Zone 1: \(limits.zone1Lower)-\(limits.zone1Upper) BPM (Recovery)",
            "Zone 2: \(limits.zone1Upper + 1)-\(limits.zone2Upper) BPM (Base)",
            "Zone 3: \(limits.zone2Upper + 1)-\(limits.zone3Upper) BPM (Aerobic)",
            "Zone 4: \(limits.zone3Upper + 1)-\(limits.zone4Upper) BPM (Threshold)", 
            "Zone 5: \(limits.zone4Upper + 1)-\(limits.zone5Upper) BPM (VO2 Max)"
        ]
    }
}
