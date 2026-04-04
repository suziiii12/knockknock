import SwiftUI

enum AppColors {
    // Backgrounds
    static let bgPrimary = Color(red: 245/255, green: 245/255, blue: 245/255)       // #F5F5F5 White Smoke
    static let bgSecondary = Color.white                                              // #FFFFFF Cards
    static let bgTertiary = Color(red: 238/255, green: 238/255, blue: 238/255)       // #EEEEEE Slightly darker

    // Text
    static let textPrimary = Color(red: 0/255, green: 61/255, blue: 58/255)          // #003D3A Pine Teal
    static let textSecondary = Color(red: 100/255, green: 116/255, blue: 115/255)    // Muted teal-gray
    static let textMuted = Color(red: 160/255, green: 170/255, blue: 169/255)        // Light gray

    // Functional
    static let accent = Color(red: 0/255, green: 61/255, blue: 58/255)              // #003D3A Pine Teal
    static let accentLight = Color(red: 0/255, green: 143/255, blue: 136/255)       // #008F88 Dark Cyan (secondary)
    static let warning = Color(red: 245/255, green: 166/255, blue: 35/255)           // Amber
    static let danger = Color(red: 220/255, green: 53/255, blue: 53/255)             // Red

    // Borders
    static let border = Color(red: 220/255, green: 224/255, blue: 224/255)           // Light gray border

    // Shadow
    static let cardShadow = Color.black.opacity(0.06)

    // Territory user colors
    static let userColors: [Color] = [
        Color(red: 0/255, green: 143/255, blue: 136/255),     // Teal
        Color(red: 124/255, green: 92/255, blue: 252/255),     // Purple
        Color(red: 245/255, green: 130/255, blue: 49/255),     // Orange
        Color(red: 36/255, green: 123/255, blue: 245/255),     // Blue
        Color(red: 230/255, green: 73/255, blue: 128/255),     // Pink
        Color(red: 245/255, green: 189/255, blue: 0/255),      // Yellow
        Color(red: 16/255, green: 185/255, blue: 129/255),     // Emerald
        Color(red: 99/255, green: 102/255, blue: 241/255),     // Indigo
        Color(red: 244/255, green: 63/255, blue: 94/255),      // Rose
        Color(red: 132/255, green: 204/255, blue: 22/255),     // Lime
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
    static let cornerRadiusCard: CGFloat = 16
    static let cornerRadiusButton: CGFloat = 10
    static let spacing: CGFloat = 8
    static let windowMinWidth: CGFloat = 900
    static let windowMinHeight: CGFloat = 600
    static let windowDefaultWidth: CGFloat = 1200
    static let windowDefaultHeight: CGFloat = 800
}
