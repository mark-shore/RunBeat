import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var showingSettings = false
    @State private var showingVO2MaxTraining = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background using design system
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.xxl) {
                    // Header subtitle
                    VStack(spacing: AppSpacing.sm) {
                        Text("Heart Rate Zone Training")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.secondary)
                            .tracking(1)
                    }
                    .padding(.top, AppSpacing.xxl)
                    
                    Spacer()
                    
                    // Session button section
                    VStack(spacing: AppSpacing.lg) {
                        Button(action: {
                            if appState.isSessionActive {
                                appState.stopSession()
                            } else {
                                appState.startSession()
                            }
                        }) {
                            AppCard(style: appState.isSessionActive ? .active : .default) {
                                HStack {
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        Text(appState.isSessionActive ? "Training Session Active" : "Start Training Session")
                                            .font(AppTypography.title2)
                                            .foregroundColor(AppColors.onBackground)
                                        
                                        Text(appState.isSessionActive ? "Tap to stop monitoring" : "Heart rate monitoring & zone announcements")
                                            .font(AppTypography.callout)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Session status icon
                                    ZStack {
                                        Circle()
                                            .fill(appState.isSessionActive ? AppColors.error : AppColors.success)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: appState.isSessionActive ? "stop.fill" : "play.fill")
                                            .font(AppTypography.title2)
                                            .foregroundColor(AppColors.onBackground)
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // VO2 Max Training Button
                        Button(action: {
                            showingVO2MaxTraining = true
                        }) {
                            AppCard(style: .highlighted) {
                                HStack {
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        Text("VO₂ Max Training")
                                            .font(AppTypography.title2)
                                            .foregroundColor(AppColors.onBackground)
                                        
                                        Text("4 min high-intensity intervals with Spotify")
                                            .font(AppTypography.callout)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // VO2 Max icon
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.primary)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "flame.fill")
                                            .font(AppTypography.title2)
                                            .foregroundColor(AppColors.onBackground)
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    
                    Spacer()
                    
                    // Status indicator
                    VStack(spacing: AppSpacing.sm) {
                        Circle()
                            .fill(appState.isSessionActive ? AppColors.success : AppColors.secondary.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.3), value: appState.isSessionActive)
                        
                        Text(appState.isSessionActive ? "SESSION ACTIVE" : "READY TO START")
                            .font(AppTypography.caption.weight(.bold))
                            .foregroundColor(appState.isSessionActive ? AppColors.success : AppColors.secondary)
                            .tracking(1)
                    }
                    .padding(.bottom, AppSpacing.xxl + AppSpacing.lg)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(AppTypography.title2)
                            .foregroundColor(AppColors.onBackground)
                    }
                }
            }
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView(appState: appState, heartRateViewModel: appState.heartRateViewModel)
            }
            .navigationDestination(isPresented: $showingVO2MaxTraining) {
                VO2MaxTrainingView(isPresented: $showingVO2MaxTraining)
                    .environmentObject(appState)
            }
        }
    }
}
