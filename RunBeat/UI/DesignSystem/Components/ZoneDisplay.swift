//
//  ZoneDisplay.swift
//  RunBeat
//
//  Created by Mark Shore on 8/26/25.
//


import SwiftUI

struct ZoneDisplay: View {
    let zone: Int
    let zoneName: String
    let bpmRange: String
    let isActive: Bool
    
    private var zoneColor: Color {
        switch zone {
        case 1: return AppColors.zone1
        case 2: return AppColors.zone2
        case 3: return AppColors.zone3
        case 4: return AppColors.zone4
        case 5: return AppColors.zone5
        default: return AppColors.secondary
        }
    }
    
    var body: some View {
        AppCard(style: isActive ? .active : .default) {
            HStack {
                // Zone indicator
                Circle()
                    .fill(zoneColor)
                    .frame(width: 12, height: 12)
                
                // Zone info
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Zone \(zone): \(zoneName)")
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.onBackground)
                    
                    Text(bpmRange)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                }
                
                Spacer()
                
                // Active indicator
                if isActive {
                    Image(systemName: "heart.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.system(size: 24))
                        .symbolEffect(.pulse)
                }
            }
        }
    }
}