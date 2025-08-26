//
//  HeartRateTrainingManager.swift
//  RunBeat
//
//  Manages heart rate training session state, announcements, and cooldowns
//  Depends on HeartRateZoneCalculator for zone calculations
//

import Foundation

protocol HeartRateTrainingDelegate: AnyObject {
    func heartRateTraining(_ manager: HeartRateTrainingManager, didDetectZoneChange newZone: Int, fromZone oldZone: Int?)
    func heartRateTraining(_ manager: HeartRateTrainingManager, shouldAnnounceZone zone: Int) -> Bool
    func heartRateTraining(_ manager: HeartRateTrainingManager, didRequestZoneAnnouncement zone: Int)
}

class HeartRateTrainingManager {
    weak var delegate: HeartRateTrainingDelegate?
    
    // Zone settings for calculations
    private var restingHR: Int = 60
    private var maxHR: Int = 190
    private var useAutoZones: Bool = true
    private var manualZones: (zone1Lower: Int, zone1Upper: Int, zone2Upper: Int, zone3Upper: Int, zone4Upper: Int, zone5Upper: Int) = (60, 70, 80, 90, 100, 110)
    
    // Training session state
    private var currentZone: Int?
    private var lastAnnouncedZone: Int?
    private var lastAnnouncementTime: Date?
    private var cooldownTimer: Timer?
    private let announcementCooldown: TimeInterval = 5.0
    
    // MARK: - Public API
    
    func updateZoneSettings(restingHR: Int, maxHR: Int, useAutoZones: Bool, 
                          zone1Lower: Int = 60, zone1Upper: Int = 70, 
                          zone2Upper: Int = 80, zone3Upper: Int = 90, 
                          zone4Upper: Int = 100, zone5Upper: Int = 110) {
        self.restingHR = restingHR
        self.maxHR = maxHR
        self.useAutoZones = useAutoZones
        self.manualZones = (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
        
        HeartRateZoneCalculator.logZoneSettings(
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            manualZones: manualZones
        )
    }
    
    func processHeartRate(_ bpm: Int) {
        let newZone = HeartRateZoneCalculator.calculateZone(
            for: bpm,
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            manualZones: manualZones
        )
        
        if let newZone = newZone, newZone != currentZone {
            let oldZone = currentZone
            currentZone = newZone
            
            delegate?.heartRateTraining(self, didDetectZoneChange: newZone, fromZone: oldZone)
            
            // Check if we should announce this zone change
            if shouldAnnounce() {
                if newZone != lastAnnouncedZone {
                    requestZoneAnnouncement(newZone)
                } else {
                    print("🔇 Zone \(newZone) equals last announced; skipping immediate announce")
                }
            } else {
                print("🔇 Zone \(newZone) detected during cooldown; will evaluate at cooldown expiry")
            }
        }
    }
    
    func resetSessionState() {
        currentZone = nil
        lastAnnouncementTime = nil
        lastAnnouncedZone = nil
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        print("🔋 Heart rate training session state reset")
    }
    
    func getCurrentZone() -> Int? {
        return currentZone
    }
    
    func getManualZonesFromAuto() -> (Int, Int, Int, Int, Int, Int) {
        return HeartRateZoneCalculator.calculateAutoZones(restingHR: restingHR, maxHR: maxHR)
    }
    
    // MARK: - Announcement Logic
    
    private func shouldAnnounce() -> Bool {
        guard let lastTime = lastAnnouncementTime else {
            return true // First announcement, always allow
        }
        
        let timeSinceLastAnnouncement = Date().timeIntervalSince(lastTime)
        return timeSinceLastAnnouncement >= announcementCooldown
    }
    
    private func requestZoneAnnouncement(_ zone: Int) {
        delegate?.heartRateTraining(self, didRequestZoneAnnouncement: zone)
        lastAnnouncementTime = Date()
        lastAnnouncedZone = zone
        
        // Cancel existing timer and start new cooldown timer
        cooldownTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cooldownTimer?.invalidate()
            let timer = Timer(timeInterval: self.announcementCooldown, repeats: false) { [weak self] _ in
                self?.handleCooldownExpired()
            }
            self.cooldownTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🔊 Zone \(zone) announcement requested (cooldown active for \(Int(announcementCooldown))s)")
    }
    
    private func handleCooldownExpired() {
        print("⏰ Announcement cooldown expired")
        
        if let currentZone = currentZone, currentZone != lastAnnouncedZone {
            // Ask delegate if we should announce the current zone
            if delegate?.heartRateTraining(self, shouldAnnounceZone: currentZone) == true {
                requestZoneAnnouncement(currentZone)
                print("🔊 Announced current zone \(currentZone) at cooldown expiry")
            }
        } else {
            print("🔇 Cooldown expired; no new zone to announce")
        }
    }
    
    deinit {
        cooldownTimer?.invalidate()
    }
}
