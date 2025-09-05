import SwiftUI

struct BPMDisplayView: View {
    let bpm: Int
    let zone: Int
    
    @State private var isAnimating = false
    
    var body: some View {
        // Main BPM circle display
        ZStack {
            // Zone-colored background circle
            Circle()
                .fill(getZoneColor(for: zone))
                .frame(width: 150, height: 150)
                .scaleEffect(isAnimating ? 1.05 : 0.9)
                .animation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // BPM number and heart icon
            VStack(spacing: 4) {
                Text("\(bpm)")
                    .font(AppTypography.hrDisplay)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                
                Image(systemName: "heart.fill")
                    .font(AppTypography.hrIcon)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private func getZoneColor(for zone: Int) -> Color {
        switch zone {
        case 0: return AppColors.zone0
        case 1: return AppColors.zone1
        case 2: return AppColors.zone2
        case 3: return AppColors.zone3
        case 4: return AppColors.zone4
        case 5: return AppColors.zone5
        default: return AppColors.zone0
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        BPMDisplayView(bpm: 85, zone: 1)
        BPMDisplayView(bpm: 142, zone: 3)
        BPMDisplayView(bpm: 175, zone: 5)
    }
    .padding()
    .background(AppColors.background)
}