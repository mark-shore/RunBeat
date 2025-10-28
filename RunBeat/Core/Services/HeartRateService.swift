//
//  HeartRateService.swift
//  RunBeat
//
//  Core heart rate processing service - stateless zone calculations and change detection
//  Extracted from HeartRateTrainingManager to be shared between training modes
//

import Foundation

@MainActor
class HeartRateService: ObservableObject {
    static let shared = HeartRateService()
    
    // Zone settings
    private var restingHR: Int = 60
    private var maxHR: Int = 190
    private var useAutoZones: Bool = true
    private var manualZones: (zone1Lower: Int, zone1Upper: Int, zone2Upper: Int, zone3Upper: Int, zone4Upper: Int, zone5Upper: Int) = (60, 70, 80, 90, 100, 110)
    
    // Current state
    @Published private(set) var currentZone: Int?
    
    private init() {}
    
    func updateZoneSettings(restingHR: Int, maxHR: Int, useAutoZones: Bool,
                          zone1Lower: Int = 60, zone1Upper: Int = 70,
                          zone2Upper: Int = 80, zone3Upper: Int = 90,
                          zone4Upper: Int = 100, zone5Upper: Int = 110) {
        // Detect if zones actually changed (user-initiated changes, not initial sync)
        let changed = self.restingHR != restingHR ||
                      self.maxHR != maxHR ||
                      self.useAutoZones != useAutoZones ||
                      self.manualZones.zone1Lower != zone1Lower ||
                      self.manualZones.zone1Upper != zone1Upper ||
                      self.manualZones.zone2Upper != zone2Upper ||
                      self.manualZones.zone3Upper != zone3Upper ||
                      self.manualZones.zone4Upper != zone4Upper ||
                      self.manualZones.zone5Upper != zone5Upper

        self.restingHR = restingHR
        self.maxHR = maxHR
        self.useAutoZones = useAutoZones
        self.manualZones = (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)

        // Only log when zones actually change - provides user feedback without startup spam
        if changed {
            AppLogger.info("Zone settings updated", component: "HeartRate")
            HeartRateZoneCalculator.logZoneSettings(
                restingHR: restingHR,
                maxHR: maxHR,
                useAutoZones: useAutoZones,
                manualZones: manualZones
            )
        }
    }
    
    func processHeartRate(_ bpm: Int) -> (currentZone: Int?, didChangeZone: Bool, oldZone: Int?) {
        let newZone = HeartRateZoneCalculator.calculateZone(
            for: bpm,
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            manualZones: manualZones
        )
        
        let didChange = newZone != currentZone
        let oldZone = currentZone
        currentZone = newZone
        
        return (newZone, didChange, oldZone)
    }
    
    func resetState() {
        currentZone = nil
        print("🔋 Heart rate service state reset")
    }
    
    func getCurrentZone() -> Int? {
        return currentZone
    }
    
    func getManualZonesFromAuto() -> (Int, Int, Int, Int, Int, Int) {
        return HeartRateZoneCalculator.calculateAutoZones(restingHR: restingHR, maxHR: maxHR)
    }
}