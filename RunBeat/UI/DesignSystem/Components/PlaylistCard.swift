//
//  PlaylistCard.swift
//  RunBeat
//
//  Spotify-style playlist card component with proper square proportions
//

import SwiftUI

struct PlaylistCard: View {
    let playlist: SpotifyPlaylist
    let selectionBadge: PlaylistBadge?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Main card content
                VStack(spacing: 0) {
                    // Square artwork section
                    artworkSection
                    
                    // Playlist name overlay
                    nameOverlay
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Selection badge in top-right
                if let badge = selectionBadge {
                    VStack {
                        HStack {
                            Spacer()
                            SelectionBadge(badge: badge)
                                .offset(x: -8, y: 8)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .aspectRatio(1, contentMode: .fit) // Perfect square
    }
    
    // MARK: - Artwork Section
    
    private var artworkSection: some View {
        GeometryReader { geometry in
            if let imageURL = playlist.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width * 0.75)
                        .clipped()
                } placeholder: {
                    PlaylistMosaicView(imageURLs: [])
                        .frame(width: geometry.size.width, height: geometry.size.width * 0.75)
                }
            } else {
                PlaylistMosaicView(imageURLs: [])
                    .frame(width: geometry.size.width, height: geometry.size.width * 0.75)
            }
        }
        .aspectRatio(4/3, contentMode: .fit) // 4:3 ratio for artwork area
    }
    
    // MARK: - Name Overlay
    
    private var nameOverlay: some View {
        VStack {
            Spacer() // Push text to center
            
            HStack {
                Text(playlist.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            
            Spacer() // Balance the spacing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Mosaic View for 2x2 Grid

struct PlaylistMosaicView: View {
    let imageURLs: [String]
    
    var body: some View {
        if imageURLs.isEmpty {
            // Solid color placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.6))
                )
        } else if imageURLs.count == 1 {
            // Single image
            AsyncImage(url: URL(string: imageURLs[0])) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        } else {
            // 2x2 grid for multiple images
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    MosaicQuadrant(imageURL: imageURLs.first)
                    MosaicQuadrant(imageURL: imageURLs.count > 1 ? imageURLs[1] : nil)
                }
                GridRow {
                    MosaicQuadrant(imageURL: imageURLs.count > 2 ? imageURLs[2] : nil)
                    MosaicQuadrant(imageURL: imageURLs.count > 3 ? imageURLs[3] : nil)
                }
            }
        }
    }
}

// MARK: - Mosaic Quadrant

struct MosaicQuadrant: View {
    let imageURL: String?
    
    var body: some View {
        Group {
            if let imageURL = imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .aspectRatio(1, contentMode: .fit) // Perfect square for each quadrant
    }
}

// MARK: - Selection Badge

struct SelectionBadge: View {
    let badge: PlaylistBadge
    
    var body: some View {
        ZStack {
            Circle()
                .fill(badge.color)
                .frame(width: 20, height: 20)
            
            Text(badge.letter)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .shadow(radius: 2)
    }
}

// MARK: - Badge Type

enum PlaylistBadge {
    case highIntensity
    case rest
    
    var letter: String {
        switch self {
        case .highIntensity: return "H"
        case .rest: return "R"
        }
    }
    
    var color: Color {
        switch self {
        case .highIntensity: return Color(red: 1.0, green: 0.27, blue: 0.0) // RunBeat primary
        case .rest: return Color.blue
        }
    }
}

// MARK: - Preview

#Preview {
    let samplePlaylist = SpotifyPlaylist(
        id: "123",
        name: "High Energy Workout Mix",
        description: "Get pumped",
        trackCount: 25,
        imageURL: nil,
        isPublic: true,
        owner: "Mark Shore"
    )
    
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ], spacing: 12) {
        PlaylistCard(
            playlist: samplePlaylist,
            selectionBadge: .highIntensity
        ) { }
        
        PlaylistCard(
            playlist: samplePlaylist,
            selectionBadge: .rest
        ) { }
        
        PlaylistCard(
            playlist: samplePlaylist,
            selectionBadge: nil
        ) { }
        
        PlaylistCard(
            playlist: samplePlaylist,
            selectionBadge: nil
        ) { }
    }
    .padding(12)
    .background(Color.black)
}
