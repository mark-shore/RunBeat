//
//  AppCard.swift
//  RunBeat
//
//  Created by Mark Shore on 8/26/25.
//


import SwiftUI

struct AppCard<Content: View>: View {
    let content: () -> Content
    let style: CardStyle
    let padding: CGFloat
    
    enum CardStyle {
        case `default`    // Dark gray surface
        case highlighted  // With red-orange accent
        case active      // Red-orange border/glow
        
        var backgroundColor: Color {
            switch self {
            case .default, .highlighted, .active:
                return AppColors.surface
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .active: return AppColors.primary
            case .highlighted: return AppColors.primary.opacity(0.3)
            default: return nil
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .active: return 2
            case .highlighted: return 1
            default: return 0
            }
        }
    }
    
    init(
        style: CardStyle = .default,
        padding: CGFloat = AppSpacing.cardPadding,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(padding)
            .background(style.backgroundColor)
            .cornerRadius(AppSpacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                    .stroke(style.borderColor ?? Color.clear, lineWidth: style.borderWidth)
            )
            .shadow(
                color: style == .active ? AppColors.primary.opacity(0.3) : Color.clear,
                radius: style == .active ? 8 : 0
            )
    }
}
