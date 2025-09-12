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
    @Binding var isPresented: Bool
    @State private var showingVO2Settings = false
    
    var body: some View {
            ZStack {
                // Dark background
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Timer and phase info (always shown)
                    VStack(alignment: .center, spacing: AppSpacing.xs) {
                        // Timer
                        Text(appState.vo2TrainingState == .active ? appState.vo2FormattedTimeRemaining : "4:00")
                            .font(AppTypography.timerDisplay)
                            .foregroundColor(AppColors.onBackground)
                        
                        // Phase with interval count
                        Text(appState.vo2TrainingState == .active ? getPhaseDisplayText() : "4x4 INTERVAL TRAINING")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.onBackground)
                    }
                    .padding(.top, AppSpacing.xxxl)
                    
                    // Heart rate display
                    if appState.vo2TrainingState != .complete {
                        BPMDisplayView(bpm: appState.currentBPM, zone: getCurrentZone())
                            .id("bpm-display")
                            .animation(.none, value: appState.currentBPM)
                            .padding(.top, AppSpacing.xxl)
                    }
                    
                    // Buttons
                    VStack(spacing: AppSpacing.md) {
                        switch appState.vo2TrainingState {
                        case .setup:
                            AppButton("Start Training", style: .primary) {
                                appState.startVO2Training()
                            }
                            
                        case .active:
                            Button(action: {
                                appState.stopVO2Training()
                            }) {
                                Image(systemName: AppIcons.stop)
                                    .font(AppTypography.title2)
                                    .foregroundColor(AppColors.onBackground)
                                    .frame(width: 60, height: 60)
                                    .background(AppColors.error)
                                    .clipShape(Circle())
                            }
                            
                        case .complete:
                            VStack(spacing: AppSpacing.lg) {
                                Text("Training Complete")
                                    .font(AppTypography.title2)
                                    .foregroundColor(AppColors.onBackground)
                                
                                AppButton("Done", style: .primary) {
                                    appState.dismissVO2CompletionScreen()
                                    isPresented = false
                                }
                            }
                        }
                    }
                    .padding(.top, AppSpacing.xxl)
                    
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.screenMargin)
                .padding(.vertical, AppSpacing.screenMargin)
                
                // Bottom drawer positioned at ZStack level (setup, active, and complete states)
                if appState.vo2TrainingState == .setup || appState.vo2TrainingState == .active || appState.vo2TrainingState == .complete {
                    VStack {
                        Spacer() // Push drawer to bottom of screen
                        VO2TrainingBottomDrawer()
                    }
                    .ignoresSafeArea(.container, edges: [.leading, .trailing, .bottom])
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: appState.vo2TrainingState)
                }
            }
            .navigationTitle("VO₂ Max Training")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if appState.vo2TrainingState == .setup {
                    ToolbarItem(placement: .navigationBarLeading) {
                        AppCloseButton {
                            appState.cleanupVO2Training()
                            isPresented = false
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AppIconButton.settings {
                            showingVO2Settings = true
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showingVO2Settings) {
                VO2SettingsView(isPresented: $showingVO2Settings)
            }
        .onAppear {
            print("VO2 Max Training view appeared")
            
            // Start HR monitoring for setup screen
            if appState.vo2TrainingState == .setup {
                print("💓 Starting HR monitoring for VO2 setup screen")
                appState.hrManager.startMonitoring()
            }
            
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
            // Stop HR monitoring only if we're leaving from setup state (not after completion)
            if appState.vo2TrainingState == .setup && appState.vo2CurrentPhase != .completed {
                print("💓 Stopping HR monitoring for VO2 setup screen")
                appState.hrManager.stopMonitoring()
            }
            
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
    
    private func getPhaseDisplayText() -> String {
        let intervalNumber = (appState.vo2CurrentInterval + 1) / 2
        
        switch appState.vo2CurrentPhase {
        case .notStarted:
            return "READY TO START"
        case .highIntensity:
            return "WORK \(intervalNumber)/4"
        case .rest:
            return "RECOVERY \(intervalNumber)/4"
        case .completed:
            return "TRAINING COMPLETE"
        }
    }
    
}

#Preview {
    VO2MaxTrainingView(isPresented: .constant(true))
}
