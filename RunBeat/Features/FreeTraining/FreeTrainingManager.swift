//
//  FreeTrainingManager.swift
//  RunBeat
//
//  Free training mode manager - extracted from HeartRateTrainingManager
//  Provides simple background HR monitoring with configurable zone announcements
//

import Foundation

class FreeTrainingManager: ObservableObject {
    @Published var isActive = false
    
    private let hrService = HeartRateService()
    private let announcements = ZoneAnnouncementCoordinator()
    
    init() {
        announcements.delegate = self
    }
    
    func start() {
        isActive = true
        hrService.resetState()
        announcements.resetState()
        print("🏃 Free training started")
    }
    
    func stop() {
        isActive = false
        hrService.resetState()
        announcements.resetState()
        print("⏹️ Free training stopped")
    }
    
    func processHeartRate(_ bpm: Int) {
        let result = hrService.processHeartRate(bpm)
        
        if let newZone = result.currentZone, result.didChangeZone {
            announcements.handleZoneChange(newZone, from: result.oldZone, for: .free)
        }
    }
    
    func setAnnouncementsEnabled(_ enabled: Bool) {
        announcements.setAnnouncementsEnabled(enabled, for: .free)
    }
    
    func updateZoneSettings(restingHR: Int, maxHR: Int, useAutoZones: Bool, 
                          zone1Lower: Int = 60, zone1Upper: Int = 70, 
                          zone2Upper: Int = 80, zone3Upper: Int = 90, 
                          zone4Upper: Int = 100, zone5Upper: Int = 110) {
        hrService.updateZoneSettings(
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            zone1Lower: zone1Lower,
            zone1Upper: zone1Upper,
            zone2Upper: zone2Upper,
            zone3Upper: zone3Upper,
            zone4Upper: zone4Upper,
            zone5Upper: zone5Upper
        )
    }
    
    func getCurrentZone() -> Int? {
        return hrService.getCurrentZone()
    }
    
    func getManualZonesFromAuto() -> (Int, Int, Int, Int, Int, Int) {
        return hrService.getManualZonesFromAuto()
    }
}

extension FreeTrainingManager: ZoneAnnouncementDelegate {
    func announceZone(_ zone: Int) {
        // Route announcements through NotificationCenter for now
        // This will be wired to AppState's announcement infrastructure in Phase 4
        NotificationCenter.default.post(name: .announceZone, object: zone)
        print("🔊 Free training requesting zone \(zone) announcement")
    }
}

extension Notification.Name {
    static let announceZone = Notification.Name("announceZone")
}