//
//  VO2MaxTrainingView.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import SwiftUI
import Foundation
import Combine

struct VO2MaxTrainingView: View {
    @StateObject private var trainingManager = VO2MaxTrainingManager.shared
    @StateObject private var spotifyViewModel = SpotifyViewModel.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var startedHRSession = false
    @State private var showingPlaylistSelection = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.xl) {
                    // Header
                    VStack(spacing: AppSpacing.sm) {
                        Text("VO₂ Max Training")
                            .font(AppTypography.largeTitle)
                            .foregroundColor(AppColors.onBackground)
                        
                        Text("4 min High Intensity • 3 min Rest • 4 Intervals")
                            .font(AppTypography.callout)
                            .foregroundColor(AppColors.secondary)
                    }
                    
                    Spacer()
                    
                    // Timer Display
                    VStack(alignment: .center, spacing: AppSpacing.md) {
                        // Timer text
                        Text(trainingManager.formattedTimeRemaining())
                            .font(.system(size: 28, weight: .medium, design: .monospaced))
                            .foregroundColor(getPhaseColor(for: trainingManager.currentPhase))
                        
                        if trainingManager.isTraining {
                            // Heart rate information during training
                            HStack(spacing: AppSpacing.lg) {
                                // BPM display
                                VStack(spacing: AppSpacing.xs) {
                                    Text("\(appState.currentBPM)")
                                        .font(AppTypography.displayMedium)
                                        .foregroundColor(AppColors.onBackground)
                                    
                                    Text("BPM")
                                        .font(AppTypography.bodySmall)
                                        .foregroundColor(AppColors.secondary)
                                }
                                
                                // Current zone
                                Text(getCurrentZoneText())
                                    .font(AppTypography.headlineMedium)
                                    .foregroundColor(getCurrentZoneColor())
                            }
                        } else {
                            // Ready to Start text when not training
                            Text(trainingManager.getPhaseDescription())
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(getPhaseColor(for: trainingManager.currentPhase))
                        }
                        
                        // Interval counter
                        Text("Interval \(trainingManager.currentInterval)/\(trainingManager.totalIntervals)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    
                    Spacer()
                    
                    // Buttons Section
                    VStack(spacing: AppSpacing.md) {
                        // Select Playlists button (only when not training)
                        if !trainingManager.isTraining {
                            AppButton("Select Playlists", style: .secondary) {
                                showingPlaylistSelection = true
                            }
                        }
                        
                        // Training Control Buttons
                        switch trainingManager.trainingState {
                        case .setup:
                            // Setup State: Show start button
                            AppButton("Start Training", style: .primary) {
                                if !appState.isSessionActive {
                                    appState.startSession()
                                    startedHRSession = true
                                }
                                trainingManager.startTraining()
                            }
                            
                        case .active:
                            // Active State: Show stop button only
                            HStack(spacing: AppSpacing.lg) {
                                Button(action: {
                                    trainingManager.stopTraining()
                                    if startedHRSession {
                                        appState.stopSession()
                                        startedHRSession = false
                                    }
                                }) {
                                    Image(systemName: "stop.fill")
                                        .font(AppTypography.title2)
                                        .foregroundColor(AppColors.onBackground)
                                        .frame(width: 60, height: 60)
                                        .background(AppColors.error)
                                        .clipShape(Circle())
                                }
                            }
                            
                        case .complete:
                            // Complete State: Show restart button
                            VStack(spacing: AppSpacing.sm) {
                                Text("Training Complete!")
                                    .font(AppTypography.title2)
                                    .foregroundColor(AppColors.success)
                                    .fontWeight(.bold)
                                
                                AppButton("Start New Session", style: .primary) {
                                    trainingManager.resetToSetup()
                                    if !appState.isSessionActive {
                                        appState.startSession()
                                        startedHRSession = true
                                    }
                                    trainingManager.startTraining()
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: AppSpacing.md)
                    
                    // Current Track Display (bottommost element)
                    CurrentTrackView(track: spotifyViewModel.currentTrackInfo)
                }
                .padding(.horizontal, 12) // Reduced horizontal padding for wider cards
                .padding(.vertical, AppSpacing.screenMargin)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.onBackground)
                }
            }
        }
        .sheet(isPresented: $showingPlaylistSelection) {
            PlaylistSelectionView()
        }
        .onAppear {
            print("VO2 Max Training view appeared")
            
            // Ensure playlist fetch happens if connected
            if spotifyViewModel.isConnected {
                if spotifyViewModel.availablePlaylists.isEmpty {
                    print("🎵 Auto-fetching playlists for training view")
                    spotifyViewModel.fetchPlaylists()
                } else if (spotifyViewModel.selectedHighIntensityPlaylist == nil || spotifyViewModel.selectedRestPlaylist == nil) &&
                          (spotifyViewModel.playlistSelection.highIntensityPlaylistID != nil || spotifyViewModel.playlistSelection.restPlaylistID != nil) {
                    print("🎵 Refreshing playlists to resolve missing selections")
                    spotifyViewModel.fetchPlaylists()
                }
                
                // Only refresh current track info if we're in setup or active state
                // Don't refresh when coming back to complete state (preserves last track display)
                if trainingManager.trainingState == .setup {
                    print("🎵 Refreshing current track for setup state")
                    spotifyViewModel.refreshCurrentTrack()
                }
            }
        }
        .onChange(of: trainingManager.trainingState) { oldValue, newValue in
            switch newValue {
            case .active:
                // Training started - polling is handled by VO2MaxTrainingManager
                print("🎵 [VO2View] Training started - polling managed by training manager")
                
            case .setup, .complete:
                // Training stopped - ensure polling stops
                print("🎵 [VO2View] Training stopped - ensuring track polling stopped")
                spotifyViewModel.stopTrackPolling()
            }
        }
        .onDisappear {
            // Ensure polling stops when view disappears (training manager handles its own polling)
            if trainingManager.trainingState == .setup || trainingManager.trainingState == .complete {
                spotifyViewModel.stopTrackPolling()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentZoneText() -> String {
        guard appState.currentBPM > 0 else { return "Zone 0" }
        
        let currentZone = HeartRateZoneCalculator.calculateZone(
            for: appState.currentBPM,
            restingHR: appState.heartRateViewModel.restingHR,
            maxHR: appState.heartRateViewModel.maxHR,
            useAutoZones: appState.heartRateViewModel.useAutoZones,
            manualZones: (
                zone1Lower: appState.heartRateViewModel.zone1Lower,
                zone1Upper: appState.heartRateViewModel.zone1Upper,
                zone2Upper: appState.heartRateViewModel.zone2Upper,
                zone3Upper: appState.heartRateViewModel.zone3Upper,
                zone4Upper: appState.heartRateViewModel.zone4Upper,
                zone5Upper: appState.heartRateViewModel.zone5Upper
            )
        )
        
        return currentZone != nil ? "Zone \(currentZone!)" : "Zone 0"
    }
    
    private func getCurrentZoneColor() -> Color {
        guard appState.currentBPM > 0 else { return AppColors.zone0 }
        
        let currentZone = HeartRateZoneCalculator.calculateZone(
            for: appState.currentBPM,
            restingHR: appState.heartRateViewModel.restingHR,
            maxHR: appState.heartRateViewModel.maxHR,
            useAutoZones: appState.heartRateViewModel.useAutoZones,
            manualZones: (
                zone1Lower: appState.heartRateViewModel.zone1Lower,
                zone1Upper: appState.heartRateViewModel.zone1Upper,
                zone2Upper: appState.heartRateViewModel.zone2Upper,
                zone3Upper: appState.heartRateViewModel.zone3Upper,
                zone4Upper: appState.heartRateViewModel.zone4Upper,
                zone5Upper: appState.heartRateViewModel.zone5Upper
            )
        )
        
        guard let zone = currentZone else { return AppColors.zone0 }
        
        switch zone {
        case 0: return AppColors.zone0
        case 1: return AppColors.zone1
        case 2: return AppColors.zone2
        case 3: return AppColors.zone3
        case 4: return AppColors.zone4
        case 5: return AppColors.zone5
        default: return AppColors.zone0
        }
    }
    
    private func getPhaseColor(for phase: VO2MaxTrainingManager.TrainingPhase) -> Color {
        switch phase {
        case .notStarted:
            return AppColors.success // Green for ready state
        case .highIntensity:
            return AppColors.primary // Red-orange for high intensity
        case .rest:
            return AppColors.zone1 // Blue for rest periods
        case .completed:
            return AppColors.success // Green for completed
        }
    }
    
    private var albumArtworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.gray.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            )
    }
}

#Preview {
    VO2MaxTrainingView()
}
