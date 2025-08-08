import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var showingSettings = false
    @State private var showingVO2MaxTraining = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background similar to WHOOP
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Header subtitle
                    VStack(spacing: 8) {
                        Text("Heart Rate Zone Training")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .tracking(1)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Session button section
                    VStack(spacing: 24) {
                        Button(action: {
                            if appState.isSessionActive {
                                appState.stopSession()
                            } else {
                                appState.startSession()
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(appState.isSessionActive ? "Training Session Active" : "Start Training Session")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text(appState.isSessionActive ? "Tap to stop monitoring" : "Heart rate monitoring & zone announcements")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Session status icon
                                ZStack {
                                    Circle()
                                        .fill(appState.isSessionActive ? Color.red : Color.green)
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: appState.isSessionActive ? "stop.fill" : "play.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(appState.isSessionActive ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(appState.isSessionActive ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // VO2 Max Training Button
                        Button(action: {
                            showingVO2MaxTraining = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("VO₂ Max Training")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("4 min high-intensity intervals with Spotify")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // VO2 Max icon
                                ZStack {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.orange.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Status indicator
                    VStack(spacing: 8) {
                        Circle()
                            .fill(appState.isSessionActive ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.3), value: appState.isSessionActive)
                        
                        Text(appState.isSessionActive ? "SESSION ACTIVE" : "READY TO START")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(appState.isSessionActive ? .green : .gray)
                            .tracking(1)
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("PULSE PROMPT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationView {
                    SettingsView(appState: appState)
                }
            }
            .sheet(isPresented: $showingVO2MaxTraining) {
                VO2MaxTrainingView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}