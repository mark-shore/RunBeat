//
//  VO2MaxTrainingView.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import SwiftUI

struct VO2MaxTrainingView: View {
    @StateObject private var trainingManager = VO2MaxTrainingManager.shared
    @StateObject private var spotifyViewModel = SpotifyViewModel.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var startedHRSession = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background using design system
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
                    VStack(spacing: AppSpacing.lg) {
                        ZStack {
                            Circle()
                                .stroke(AppColors.surface, lineWidth: 15)
                                .frame(width: 250, height: 250)
                            
                            Circle()
                                .trim(from: 0, to: trainingManager.getProgressPercentage())
                                .stroke(
                                    getPhaseColor(for: trainingManager.currentPhase),
                                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                                )
                                .frame(width: 250, height: 250)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1), value: trainingManager.getProgressPercentage())
                            
                            VStack(spacing: AppSpacing.xs) {
                                Text(trainingManager.formattedTimeRemaining())
                                    .font(AppTypography.timerDisplay)
                                    .foregroundColor(getPhaseColor(for: trainingManager.currentPhase))
                                
                                Text(trainingManager.getPhaseDescription())
                                    .font(AppTypography.title2)
                                    .foregroundColor(getPhaseColor(for: trainingManager.currentPhase))
                                
                                Text("Interval \(trainingManager.currentInterval)/\(trainingManager.totalIntervals)")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Spotify Status
                    if spotifyViewModel.isConnected {
                        VStack(spacing: AppSpacing.xs) {
                            HStack {
                                Image(systemName: "music.note")
                                    .foregroundColor(AppColors.success)
                                Text("Spotify Connected")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.success)
                            }
                            
                            if !spotifyViewModel.currentTrack.isEmpty {
                                Text(spotifyViewModel.currentTrack)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        AppButton("Connect Spotify", style: .spotify) {
                            spotifyViewModel.connect()
                        }
                    }
                    
                    // Control Buttons
                    HStack(spacing: AppSpacing.lg) {
                        if trainingManager.isTraining {
                            // Pause/Resume button
                            Button(action: {
                                if trainingManager.isPaused {
                                    trainingManager.resumeTraining()
                                } else {
                                    trainingManager.pauseTraining()
                                }
                            }) {
                                Image(systemName: trainingManager.isPaused ? "play.fill" : "pause.fill")
                                    .font(AppTypography.title2)
                                    .foregroundColor(AppColors.onBackground)
                                    .frame(width: 60, height: 60)
                                    .background(trainingManager.isPaused ? AppColors.success : AppColors.warning)
                                    .clipShape(Circle())
                            }
                            
                            // Stop button
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
                        } else {
                            if trainingManager.currentPhase == .completed {
                                AppButton("Start New Session", style: .primary) {
                                    trainingManager.startTraining()
                                }
                            } else {
                                AppButton("Start Training", style: .primary) {
                                    if !appState.isSessionActive {
                                        appState.startSession()
                                        startedHRSession = true
                                    }
                                    trainingManager.startTraining()
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(AppSpacing.screenMargin)
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
        .onAppear {
            // Don't automatically connect - let user tap the button
            print("VO2 Max Training view appeared")
        }
    }
    
    // MARK: - Helper Methods
    
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
}

#Preview {
    VO2MaxTrainingView()
}
