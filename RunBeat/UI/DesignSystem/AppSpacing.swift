import SwiftUI

struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    
    // Layout specific
    static let screenMargin: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let minTouchTarget: CGFloat = 44
    static let cornerRadius: CGFloat = 12
}

// MARK: - Container Responsibility System

enum ContainerType {
    case screen        // Top-level screen container
    case modal         // Modal/sheet presentation
    case section       // Content sections within screens
    case component     // Individual UI components
    
    var horizontalPadding: CGFloat {
        switch self {
        case .screen: return 4      // Minimal for full-screen
        case .modal: return 4       // Same as screen for consistency
        case .section: return 0     // No additional padding
        case .component: return 0   // Internal spacing only
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .screen: return 8      // Minimal top/bottom
        case .modal: return 8       // Same as screen
        case .section: return 0     // No additional padding
        case .component: return 0   // Internal spacing only
        }
    }
}
