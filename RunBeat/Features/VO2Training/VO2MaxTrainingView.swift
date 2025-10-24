//
//  VO2MaxTrainingView.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import SwiftUI
import Foundation

struct VO2MaxTrainingView: View {
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
                        Text(getTimerText())
                            .font(AppTypography.timerDisplay)
                            .foregroundColor(AppColors.onBackground)
                        
                        // Phase with interval count
                        Text(appState.vo2TrainingState == .active ? getPhaseDisplayText() : "4x4 INTERVAL TRAINING")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.onBackground)
                    }
                    .padding(.top, AppSpacing.xxxl)
                    
                    // Heart rate display
                    BPMDisplayView(bpm: appState.currentBPM, zone: getCurrentZone())
                        .id("bpm-display")
                        .animation(.none, value: appState.currentBPM)
                        .padding(.top, AppSpacing.xxl)
                    
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
            AppLogger.debug("VO2 Max Training view appeared", component: "VO2Training")

            // Start HR monitoring for setup and completion screens
            if appState.vo2TrainingState == .setup || appState.vo2TrainingState == .complete {
                AppLogger.debug("Starting HR monitoring for VO2 \(appState.vo2TrainingState) screen", component: "VO2Training")
                appState.hrManager.startMonitoring()
            }

            // Apple Music playlist management is handled by VO2TrainingBottomDrawer
        }
        .onDisappear {
            // Stop HR monitoring when leaving setup or completion screens
            if appState.vo2TrainingState == .setup || appState.vo2TrainingState == .complete {
                AppLogger.debug("Stopping HR monitoring for VO2 \(appState.vo2TrainingState) screen", component: "VO2Training")
                appState.hrManager.stopMonitoring()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if appState.vo2TrainingState == .setup || appState.vo2TrainingState == .complete {
                AppLogger.debug("App backgrounding - stopping HR monitoring for VO2 \(appState.vo2TrainingState) screen", component: "VO2Training")
                appState.hrManager.stopMonitoring()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if appState.vo2TrainingState == .setup || appState.vo2TrainingState == .complete {
                AppLogger.debug("App foregrounding - resuming HR monitoring for VO2 \(appState.vo2TrainingState) screen", component: "VO2Training")
                appState.hrManager.startMonitoring()
            }
        }
    }
    
    // MARK: - Helper Methods

    private func getTimerText() -> String {
        switch appState.vo2TrainingState {
        case .active:
            return appState.vo2FormattedTimeRemaining
        case .complete:
            return "0:00"
        case .setup:
            return "4:00"
        }
    }

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
