//
//  ZoneAnnouncementCoordinator.swift
//  RunBeat
//
//  Zone announcement coordination service with per-training-mode controls
//  Handles cooldowns, announcement decisions, and routing to audio system
//

import Foundation

enum TrainingMode {
    case none
    case free
    case vo2Max
}

protocol ZoneAnnouncementDelegate: AnyObject {
    func announceZone(_ zone: Int)
}

class ZoneAnnouncementCoordinator {
    weak var delegate: ZoneAnnouncementDelegate?
    private let userDefaults = UserDefaults.standard
    
    // Announcement state per training mode
    private var announcementsEnabled: [TrainingMode: Bool] = [:] {
        didSet { saveSettings() }
    }
    
    init() {
        loadSettings()
    }
    
    // Cooldown management
    private var lastAnnouncedZone: Int?
    private var lastAnnouncementTime: Date?
    private var cooldownTimer: Timer?
    private let announcementCooldown: TimeInterval = 5.0
    
    func setAnnouncementsEnabled(_ enabled: Bool, for mode: TrainingMode) {
        announcementsEnabled[mode] = enabled
        print("🎛️ Announcements for \(mode): \(enabled)")
    }
    
    func handleZoneChange(_ newZone: Int, from oldZone: Int?, for mode: TrainingMode) {
        guard let enabled = announcementsEnabled[mode], enabled else {
            print("🔇 Zone announcements disabled for \(mode)")
            return
        }
        
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
    
    func resetState() {
        lastAnnouncementTime = nil
        lastAnnouncedZone = nil
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        print("🔋 Zone announcement coordinator state reset")
    }
    
    private func shouldAnnounce() -> Bool {
        guard let lastTime = lastAnnouncementTime else {
            return true // First announcement, always allow
        }
        
        let timeSinceLastAnnouncement = Date().timeIntervalSince(lastTime)
        return timeSinceLastAnnouncement >= announcementCooldown
    }
    
    private func requestZoneAnnouncement(_ zone: Int) {
        delegate?.announceZone(zone)
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
        
        // Check if current zone is different from last announced zone
        Task { @MainActor in
            guard let currentZone = HeartRateService.shared.getCurrentZone() else {
                print("⏰ No current zone available after cooldown")
                return
            }
            
            if currentZone != lastAnnouncedZone {
                print("⏰ Current zone (\(currentZone)) differs from last announced (\(lastAnnouncedZone ?? -1)), announcing now")
                requestZoneAnnouncement(currentZone)
            } else {
                print("⏰ Current zone (\(currentZone)) same as last announced, no announcement needed")
            }
        }
    }
    
    private func loadSettings() {
        announcementsEnabled = [
            .free: userDefaults.object(forKey: "freeTrainingAnnouncementsEnabled") as? Bool ?? true,
            .vo2Max: userDefaults.object(forKey: "vo2TrainingAnnouncementsEnabled") as? Bool ?? true
        ]
    }
    
    private func saveSettings() {
        userDefaults.set(announcementsEnabled[.free], forKey: "freeTrainingAnnouncementsEnabled")
        userDefaults.set(announcementsEnabled[.vo2Max], forKey: "vo2TrainingAnnouncementsEnabled")
    }
    
    deinit {
        cooldownTimer?.invalidate()
    }
}