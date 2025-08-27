import SwiftUI

struct AppTypography {
    // Standard iOS styles
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title1 = Font.title.weight(.semibold)
    static let title2 = Font.title2.weight(.semibold)
    static let title3 = Font.title3.weight(.semibold)
    static let headline = Font.headline.weight(.medium)
    static let body = Font.body
    static let callout = Font.callout
    static let caption = Font.caption
    static let caption2 = Font.caption2
    
    // Custom styles for specific use cases
    static let hrDisplay = Font.system(size: 48, weight: .bold, design: .rounded)
    static let timerDisplay = Font.system(size: 36, weight: .medium, design: .monospaced)
    static let zoneLabel = Font.system(size: 20, weight: .semibold)
    static let buttonText = Font.system(size: 17, weight: .semibold)
}
