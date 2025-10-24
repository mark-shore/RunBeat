//
//  AudioService.swift
//  RunBeat
//
//  Extracted from AppState.swift - handles audio session management for announcements
//

import Foundation
import AVFoundation

protocol AudioServiceDelegate: AnyObject {
    func audioServiceDidRestoreMusicVolume()
}

class AudioService {
    static let shared = AudioService()

    weak var delegate: AudioServiceDelegate?

    private var isSessionActive = false
    
    func setupAudioSessionForAnnouncement() {
        #if os(iOS)
        do {
            // Set audio category for mixing and ducking
            // DON'T call setActive(true) - that causes hangs when music is playing
            // AVAudioPlayer will activate the session automatically when needed
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            print("🔊 Audio session category configured (mix with others + duck)")
        } catch {
            print("❌ Failed to set audio session: \(error)")
        }
        #else
        print("🔊 Audio session setup (iOS only)")
        #endif
    }
    
    func deactivateAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🔇 Audio session deactivated - music restored to normal volume")
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
        #else
        print("🔇 Audio session deactivated (iOS only)")
        #endif
    }
    
    func restoreMusicVolume(isTrainingSessionActive: Bool) {
        // Only restore music volume if we're still in an active training session
        guard isTrainingSessionActive else { return }
        
        #if os(iOS)
        do {
            // Deactivate to restore music volume - don't reactivate until next announcement
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🎵 Music volume restored - session inactive until next announcement")
            delegate?.audioServiceDidRestoreMusicVolume()
        } catch {
            print("❌ Failed to restore music volume: \(error)")
        }
        #else
        print("🎵 Music volume restored (iOS only)")
        #endif
    }
}
