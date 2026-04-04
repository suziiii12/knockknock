import SwiftUI

enum AppColors {
    static let bgPrimary = Color(red: 15/255, green: 17/255, blue: 23/255)
    static let bgSecondary = Color(red: 26/255, green: 29/255, blue: 39/255)
    static let bgTertiary = Color(red: 22/255, green: 25/255, blue: 34/255)
    static let border = Color(red: 42/255, green: 45/255, blue: 55/255)
    static let accent = Color(red: 110/255, green: 231/255, blue: 183/255)
    static let warning = Color(red: 251/255, green: 191/255, blue: 36/255)
    static let danger = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let textPrimary = Color(red: 225/255, green: 226/255, blue: 230/255)
    static let textSecondary = Color(red: 156/255, green: 163/255, blue: 175/255)
    static let textMuted = Color(red: 107/255, green: 114/255, blue: 128/255)

    static let userColors: [Color] = [
        Color(red: 110/255, green: 231/255, blue: 183/255), // Mint
        Color(red: 167/255, green: 139/255, blue: 250/255), // Purple
        Color(red: 251/255, green: 146/255, blue: 60/255),  // Orange
        Color(red: 96/255, green: 165/255, blue: 250/255),  // Blue
        Color(red: 244/255, green: 114/255, blue: 182/255), // Pink
        Color(red: 251/255, green: 191/255, blue: 36/255),  // Yellow
        Color(red: 52/255, green: 211/255, blue: 153/255),  // Emerald
        Color(red: 129/255, green: 140/255, blue: 248/255), // Indigo
        Color(red: 251/255, green: 113/255, blue: 133/255), // Rose
        Color(red: 163/255, green: 230/255, blue: 53/255),  // Lime
    ]
}

enum AppFonts {
    static let title = Font.system(size: 24, weight: .bold)
    static let heading = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let small = Font.system(size: 10, weight: .regular)
    static let scoreLarge = Font.system(size: 36, weight: .bold, design: .rounded)
}

enum AppDimensions {
    static let cornerRadiusCard: CGFloat = 12
    static let cornerRadiusButton: CGFloat = 8
    static let spacing: CGFloat = 8
    static let windowMinWidth: CGFloat = 900
    static let windowMinHeight: CGFloat = 600
    static let windowDefaultWidth: CGFloat = 1200
    static let windowDefaultHeight: CGFloat = 800
}
