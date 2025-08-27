import SwiftUI

struct AppColors {
    // Brand
    static let primary = Color(red: 1.0, green: 0.27, blue: 0.0) // #FF4500 red-orange
    
    // Backgrounds
    static let background = Color.black
    static let surface = Color(red: 0.17, green: 0.17, blue: 0.18) // #2C2C2E dark gray
    
    // Text
    static let onBackground = Color.white
    static let secondary = Color(.systemGray)
    static let tertiary = Color(UIColor.systemGray2)
    
    // HR Zones - use iOS system colors for accessibility
    static let zone1 = Color(.systemBlue)      // Recovery
    static let zone2 = Color(.systemGreen)     // Aerobic Base
    static let zone3 = Color(.systemYellow)    // Aerobic
    static let zone4 = Color(.systemOrange)    // Threshold
    static let zone5 = Color(.systemRed)       // VO2 Max
    
    // Status
    static let success = Color(.systemGreen)
    static let warning = Color(.systemOrange)
    static let error = Color(.systemRed)
    
    // Third-party brand colors
    static let spotify = Color(red: 0.11, green: 0.73, blue: 0.33) // #1DB954
}
