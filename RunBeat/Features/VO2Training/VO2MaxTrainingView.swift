//
//  VO2MaxTrainingView.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import SwiftUI
import Foundation

struct VO2MaxTrainingView: View {
    // ✅ View only talks to coordination layer - no direct manager access
    @StateObject private var spotifyViewModel = SpotifyViewModel.shared
    @EnvironmentObject var appState: AppState
    @State private var showingPlaylistSelection = false
    
    var body: some View {
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
                        Text(appState.vo2FormattedTimeRemaining)
                            .font(.system(size: 28, weight: .medium, design: .monospaced))
                            .foregroundColor(getPhaseColor(for: appState.vo2CurrentPhase))
                        
                        if appState.vo2TrainingState == .active {
                            // Heart rate information during training with animated zone-colored display
                            BPMDisplayView(bpm: appState.currentBPM, zone: getCurrentZone())
                        } else {
                            // Ready to Start text when not training
                            Text(appState.vo2PhaseDescription)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(getPhaseColor(for: appState.vo2CurrentPhase))
                        }
                        
                        // Interval counter
                        Text("Interval \(appState.vo2CurrentInterval)/\(appState.vo2TotalIntervals)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    
                    Spacer()
                    
                    // Buttons Section
                    VStack(spacing: AppSpacing.md) {
                        // Select Playlists button (only when not training)
                        if appState.vo2TrainingState != .active {
                            AppButton("Select Playlists", style: .secondary) {
                                showingPlaylistSelection = true
                            }
                        }
                        
                        // Training Control Buttons
                        switch appState.vo2TrainingState {
                        case .setup:
                            // Setup State: Show start button
                            AppButton("Start Training", style: .primary) {
                                appState.startVO2Training()
                            }
                            
                        case .active:
                            // Active State: Show stop button only
                            HStack(spacing: AppSpacing.lg) {
                                Button(action: {
                                    // ✅ Single source of truth - only AppState controls training
                                    appState.stopVO2Training()
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
                                    // ✅ AppState will coordinate reset and start
                                    appState.startVO2Training()
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
            .navigationTitle("VO₂ Max Training")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(appState.vo2TrainingState == .active)
            .toolbar {
                if appState.vo2TrainingState != .active {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("") // Empty toolbar item when not training
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
                
                // Track info will be refreshed when training actually starts
                // No need to make API calls just for viewing the screen
            }
        }
        .onChange(of: appState.vo2TrainingState) { oldValue, newValue in
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
            if appState.vo2TrainingState == .setup || appState.vo2TrainingState == .complete {
                spotifyViewModel.stopTrackPolling()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentZone() -> Int {
        guard appState.currentBPM > 0 else { return 0 }
        
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
        
        return currentZone ?? 0
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
