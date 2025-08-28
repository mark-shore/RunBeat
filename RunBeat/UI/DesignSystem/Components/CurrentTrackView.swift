import SwiftUI

struct CurrentTrackView: View {
    let track: SpotifyTrackInfo?
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Album artwork
            AsyncImage(url: URL(string: track?.artworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppColors.surfaceSecondary)
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))
            
            // Track info
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(track?.name ?? "No track playing")
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.onBackground)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                Text(track?.artist ?? "")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: 60)
        .background(Color.clear)
    }
}

#Preview {
    VStack(spacing: 20) {
        CurrentTrackView(track: SpotifyTrackInfo(
            name: "Bohemian Rhapsody",
            artist: "Queen",
            uri: "spotify:track:abc123",
            artworkURL: "https://example.com/artwork.jpg",
            duration: 355,
            position: 120,
            isPlaying: true,
            source: .webAPI
        ))
        
        CurrentTrackView(track: nil)
    }
    .padding()
    .background(AppColors.background)
}