//
//  TrackDisplayWithControls.swift
//  RunBeat
//
//  Reusable component for displaying current track info with play/pause controls
//

import SwiftUI

struct TrackDisplayWithControls: View {
    let trackInfo: SpotifyTrackInfo?
    let isPlaying: Bool
    let showControls: Bool
    let onPlayPauseToggle: () -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Album artwork
            if let trackInfo = trackInfo,
               let artworkURL = URL(string: trackInfo.artworkURL) {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    albumArtworkPlaceholder
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs + 2))
            } else {
                albumArtworkPlaceholder
                    .frame(width: 50, height: 50)
            }
            
            // Track info
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if let trackInfo = trackInfo {
                    Text(trackInfo.name)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.onBackground)
                        .lineLimit(1)
                    
                    Text(trackInfo.artist)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(1)
                } else {
                    Text("No track playing")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.secondary)
                    
                    Text("Music will appear here during training")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }
            
            Spacer()
            
            // Play/Pause controls
            if showControls {
                Button(action: onPlayPauseToggle) {
                    Image(systemName: isPlaying ? AppIcons.pause : AppIcons.play)
                        .font(AppTypography.title3.weight(.medium))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.surface)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }
    
    private var albumArtworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: AppSpacing.xs + 2)
            .fill(AppColors.surfaceSecondary)
            .overlay(
                Image(systemName: AppIcons.musicNote)
                    .font(AppTypography.caption.weight(.medium))
                    .foregroundColor(AppColors.secondary)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        // With track info and controls
        TrackDisplayWithControls(
            trackInfo: SpotifyTrackInfo(
                name: "Song Title",
                artist: "Artist Name",
                uri: "spotify:track:example",
                artworkURL: "",
                duration: 210.0,
                position: 45.0,
                isPlaying: true,
                source: .optimistic
            ),
            isPlaying: true,
            showControls: true,
            onPlayPauseToggle: {}
        )
        
        // Without track info
        TrackDisplayWithControls(
            trackInfo: nil,
            isPlaying: false,
            showControls: true,
            onPlayPauseToggle: {}
        )
        
        // Without controls
        TrackDisplayWithControls(
            trackInfo: SpotifyTrackInfo(
                name: "Song Title",
                artist: "Artist Name",
                uri: "spotify:track:example",
                artworkURL: "",
                duration: 210.0,
                position: 90.0,
                isPlaying: false,
                source: .optimistic
            ),
            isPlaying: false,
            showControls: false,
            onPlayPauseToggle: {}
        )
    }
    .padding()
    .background(AppColors.background)
}