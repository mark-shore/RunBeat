//
//  MusicPlaylistCards.swift
//  RunBeat
//
//  Reusable Apple Music playlist card components
//

import SwiftUI

// MARK: - Selected Playlist Card (Same as Available with Border)

struct SelectedMusicPlaylistCard: View {
    let playlist: MusicPlaylist
    let type: MusicPlaylistType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Square artwork (60x60) - same as available
                if let imageURL = playlist.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                    } placeholder: {
                        placeholderArtwork
                    }
                } else {
                    placeholderArtwork
                }

                // Playlist name
                VStack(alignment: .leading) {
                    Spacer()
                    Text(playlist.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .padding(.leading, 12)
                        .padding(.trailing, 12)
                    Spacer()
                }

                Spacer(minLength: 0)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(type.color, lineWidth: 2) // Colored border to show selection
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - Available Playlist Card (Horizontal with Artwork)

struct AvailableMusicPlaylistCard: View {
    let playlist: MusicPlaylist
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Square artwork (60x60)
                if let imageURL = playlist.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                    } placeholder: {
                        placeholderArtwork
                    }
                } else {
                    placeholderArtwork
                }

                // Playlist name
                VStack(alignment: .leading) {
                    Spacer()
                    Text(playlist.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .padding(.leading, 12)
                        .padding(.trailing, 12)
                    Spacer()
                }

                Spacer(minLength: 0) // Push content and ensure all cards same width
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity, alignment: .leading) // Fill available width
            .background(AppColors.surfaceSecondary)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - Empty Selection Card

struct EmptyMusicPlaylistCard: View {
    let type: MusicPlaylistType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(type.color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            type.color,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                )
                .opacity(0.7)
        }
    }
}

// MARK: - Playlist Type

enum MusicPlaylistType {
    case highIntensity
    case rest

    var color: Color {
        switch self {
        case .highIntensity: return AppColors.primary
        case .rest: return AppColors.zone1
        }
    }

    var backgroundColor: Color {
        switch self {
        case .highIntensity: return AppColors.primary.opacity(0.2)
        case .rest: return AppColors.zone1.opacity(0.2)
        }
    }
}

// MARK: - Preview

#Preview {
    let samplePlaylist = MusicPlaylist(
        id: "123",
        name: "High Energy Workout",
        trackCount: 25,
        description: "Pump it up",
        imageURL: nil
    )

    VStack(spacing: 16) {
        // Selected cards
        HStack(spacing: 16) {
            SelectedMusicPlaylistCard(
                playlist: samplePlaylist,
                type: .highIntensity
            ) { }

            SelectedMusicPlaylistCard(
                playlist: samplePlaylist,
                type: .rest
            ) { }
        }

        // Empty cards
        HStack(spacing: 16) {
            EmptyMusicPlaylistCard(type: .highIntensity) { }
            EmptyMusicPlaylistCard(type: .rest) { }
        }

        // Available cards
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            AvailableMusicPlaylistCard(playlist: samplePlaylist) { }
            AvailableMusicPlaylistCard(playlist: samplePlaylist) { }
        }
    }
    .padding()
    .background(AppColors.background)
}
