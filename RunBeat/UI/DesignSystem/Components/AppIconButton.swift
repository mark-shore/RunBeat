//
//  AppIconButton.swift
//  RunBeat
//
//  Standardized icon button component for consistent styling
//

import SwiftUI

struct AppIconButton: View {
    let icon: String
    let action: () -> Void
    let size: IconSize
    
    enum IconSize {
        case small      // AppTypography.callout
        case medium     // AppTypography.headline  
        case large      // AppTypography.title2
        
        var font: Font {
            switch self {
            case .small: return AppTypography.callout
            case .medium: return AppTypography.headline
            case .large: return AppTypography.title2
            }
        }
    }
    
    init(_ icon: String, size: IconSize = .large, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(size.font)
                .foregroundColor(AppColors.onBackground)
        }
    }
}

// MARK: - Convenience Initializers for Common Patterns

extension AppIconButton {
    // Settings button (most common pattern)
    static func settings(action: @escaping () -> Void) -> AppIconButton {
        AppIconButton(AppIcons.settings, size: .large, action: action)
    }
    
    // Close button
    static func close(action: @escaping () -> Void) -> AppIconButton {
        AppIconButton(AppIcons.close, size: .large, action: action)
    }
    
    // Back button (though AppBackButton component exists)
    static func back(action: @escaping () -> Void) -> AppIconButton {
        AppIconButton(AppIcons.back, size: .large, action: action)
    }
}