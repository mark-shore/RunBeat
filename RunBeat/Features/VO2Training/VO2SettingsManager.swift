//
//  VO2SettingsManager.swift
//  RunBeat
//
//  Simple settings management for VO2 Max training
//

import Foundation

class VO2SettingsManager: ObservableObject {
    @Published var announcementsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(announcementsEnabled, forKey: "vo2TrainingAnnouncementsEnabled")
            VO2MaxTrainingManager.shared.setAnnouncementsEnabled(announcementsEnabled)
        }
    }
    
    init() {
        announcementsEnabled = UserDefaults.standard.object(forKey: "vo2TrainingAnnouncementsEnabled") as? Bool ?? true
        VO2MaxTrainingManager.shared.setAnnouncementsEnabled(announcementsEnabled)
    }
}