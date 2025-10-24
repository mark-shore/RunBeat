import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var musicViewModel = MusicViewModel.shared
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
                                        
                                        Image(systemName: appState.isSessionActive ? AppIcons.stop : AppIcons.play)
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
                                        
                                        Image(systemName: AppIcons.flame)
                                            .font(AppTypography.title2)
                                            .foregroundColor(AppColors.onBackground)
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Apple Music Test Section (Temporary)
                        appleMusicTestSection
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
                    AppIconButton.settings {
                        showingSettings = true
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

    // MARK: - Apple Music Test Section

    private var appleMusicTestSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Header
                HStack {
                    Text("🎵 Apple Music Test")
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.onBackground)

                    Spacer()

                    // Auth button
                    if !musicViewModel.isAuthorized {
                        Button("Authorize") {
                            Task {
                                await musicViewModel.authorize()
                                if musicViewModel.isAuthorized {
                                    await musicViewModel.fetchPlaylists()
                                }
                            }
                        }
                        .font(AppTypography.caption.weight(.medium))
                        .foregroundColor(AppColors.primary)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                    }
                }

                // Playlist selection
                if musicViewModel.isAuthorized && !musicViewModel.availablePlaylists.isEmpty {
                    Divider()
                        .background(AppColors.secondary.opacity(0.3))

                    // High Intensity picker
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("High Intensity:")
                            .font(AppTypography.caption.weight(.medium))
                            .foregroundColor(AppColors.primary)

                        Menu {
                            ForEach(musicViewModel.availablePlaylists) { playlist in
                                Button(playlist.name) {
                                    musicViewModel.selectHighIntensityPlaylist(playlist)
                                }
                            }
                        } label: {
                            HStack {
                                Text(musicViewModel.selectedHighIntensityPlaylist?.name ?? "Select playlist")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.onBackground)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(AppTypography.caption2)
                                    .foregroundColor(AppColors.secondary)
                            }
                            .padding(AppSpacing.sm)
                            .background(AppColors.surface)
                            .cornerRadius(8)
                        }
                    }

                    // Rest picker
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Rest:")
                            .font(AppTypography.caption.weight(.medium))
                            .foregroundColor(AppColors.zone1)

                        Menu {
                            ForEach(musicViewModel.availablePlaylists) { playlist in
                                Button(playlist.name) {
                                    musicViewModel.selectRestPlaylist(playlist)
                                }
                            }
                        } label: {
                            HStack {
                                Text(musicViewModel.selectedRestPlaylist?.name ?? "Select playlist")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.onBackground)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(AppTypography.caption2)
                                    .foregroundColor(AppColors.secondary)
                            }
                            .padding(AppSpacing.sm)
                            .background(AppColors.surface)
                            .cornerRadius(8)
                        }
                    }

                    // Playback controls
                    if musicViewModel.hasPlaylistsConfigured {
                        Divider()
                            .background(AppColors.secondary.opacity(0.3))

                        HStack(spacing: AppSpacing.sm) {
                            // Play High Intensity
                            Button(action: {
                                musicViewModel.playHighIntensityMusic()
                            }) {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                    Text("High")
                                }
                                .font(AppTypography.caption.weight(.medium))
                                .foregroundColor(AppColors.onBackground)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(AppColors.primary)
                                .cornerRadius(6)
                            }

                            // Play Rest
                            Button(action: {
                                musicViewModel.playRestMusic()
                            }) {
                                HStack {
                                    Image(systemName: "leaf.fill")
                                    Text("Rest")
                                }
                                .font(AppTypography.caption.weight(.medium))
                                .foregroundColor(AppColors.onBackground)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(AppColors.zone1)
                                .cornerRadius(6)
                            }

                            Spacer()

                            // Play/Pause
                            Button(action: {
                                musicViewModel.togglePlayPause()
                            }) {
                                Image(systemName: musicViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppColors.onBackground)
                            }
                        }
                    }

                    // Current track info
                    if musicViewModel.isPlaying || !musicViewModel.currentTrack.isEmpty {
                        Divider()
                            .background(AppColors.secondary.opacity(0.3))

                        HStack(spacing: AppSpacing.sm) {
                            // Artwork
                            if let artwork = musicViewModel.currentAlbumArtwork {
                                Image(uiImage: artwork)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(4)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.surface)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.secondary)
                                    )
                            }

                            // Track info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(musicViewModel.currentTrack.isEmpty ? "No track" : musicViewModel.currentTrack)
                                    .font(AppTypography.caption.weight(.medium))
                                    .foregroundColor(AppColors.onBackground)
                                    .lineLimit(1)

                                Text(musicViewModel.currentArtist.isEmpty ? "Unknown artist" : musicViewModel.currentArtist)
                                    .font(AppTypography.caption2)
                                    .foregroundColor(AppColors.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Playing indicator
                            if musicViewModel.isPlaying {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                }

                // Status text
                if musicViewModel.isAuthorized {
                    Text(statusText)
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.secondary)
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var statusText: String {
        switch musicViewModel.playlistFetchStatus {
        case .notStarted:
            return "Ready to fetch"
        case .fetching:
            return "Loading..."
        case .loaded:
            return "\(musicViewModel.availablePlaylists.count) playlists loaded"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
