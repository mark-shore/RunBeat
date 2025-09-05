import SwiftUI

struct AppTypography {
    // Standard iOS styles
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title1 = Font.title.weight(.semibold)
    static let title2 = Font.title2.weight(.semibold)
    static let title3 = Font.title3.weight(.semibold)
    static let headline = Font.headline.weight(.medium)
    static let body = Font.body
    static let bodyLarge = Font.body.weight(.medium)
    static let bodyMedium = Font.callout.weight(.medium)
    static let callout = Font.callout
    static let caption = Font.caption
    static let caption2 = Font.caption2
    
    // Custom styles for specific use cases
    static let hrDisplay = Font.system(size: 56, weight: .bold, design: .rounded)
    static let hrIcon = Font.system(size: 24, weight: .medium)
    static let timerDisplay = Font.system(size: 36, weight: .medium, design: .monospaced)
    static let zoneLabel = Font.system(size: 20, weight: .semibold)
    static let buttonText = Font.system(size: 17, weight: .semibold)
    
    // Additional display sizes
    static let displayMedium = Font.system(size: 32, weight: .bold, design: .rounded)
    static let headlineMedium = Font.headline.weight(.medium)
    static let bodySmall = Font.footnote
}
