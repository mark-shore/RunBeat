//
//  VO2MaxTrainingView.swift
//  pulseprompt
//
//  Created by Mark Shore on 7/25/25.
//

import SwiftUI

struct VO2MaxTrainingView: View {
    @StateObject private var trainingManager = VO2MaxTrainingManager.shared
    @StateObject private var spotifyManager = SpotifyManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var startedHRSession = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background similar to WHOOP
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Text("VO₂ Max Training")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("4 min High Intensity • 3 min Rest • 4 Intervals")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Timer Display
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 15)
                                .frame(width: 250, height: 250)
                            
                            Circle()
                                .trim(from: 0, to: trainingManager.getProgressPercentage())
                                .stroke(
                                    trainingManager.currentPhase == .highIntensity ? Color.red : Color.green,
                                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                                )
                                .frame(width: 250, height: 250)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1), value: trainingManager.getProgressPercentage())
                            
                            VStack(spacing: 5) {
                                Text(trainingManager.formattedTimeRemaining())
                                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                                    .foregroundColor(trainingManager.currentPhase == .highIntensity ? .red : .green)
                                
                                Text(trainingManager.getPhaseDescription())
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(trainingManager.currentPhase == .highIntensity ? .red : .green)
                                
                                Text("Interval \(trainingManager.currentInterval)/\(trainingManager.totalIntervals)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Spotify Status
                    if spotifyManager.isConnected {
                        VStack(spacing: 5) {
                            HStack {
                                Image(systemName: "music.note")
                                    .foregroundColor(.green)
                                Text("Spotify Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            if !spotifyManager.currentTrack.isEmpty {
                                Text(spotifyManager.currentTrack)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Button("Connect Spotify") {
                            spotifyManager.connect()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.green)
                    }
                    
                    // Control Buttons
                    HStack(spacing: 20) {
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
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(trainingManager.isPaused ? Color.green : Color.orange)
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
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        } else {
                            if trainingManager.currentPhase == .completed {
                                Button("Start New Session") {
                                    trainingManager.startTraining()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            } else {
                                Button("Start Training") {
                                    if !appState.isSessionActive {
                                        appState.startSession()
                                        startedHRSession = true
                                    }
                                    trainingManager.startTraining()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            // Don't automatically connect - let user tap the button
            print("VO2 Max Training view appeared")
        }
    }
}

#Preview {
    VO2MaxTrainingView()
}
