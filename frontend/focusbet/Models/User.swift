import Foundation
import SwiftUI

struct User: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let initials: String
    let colorIndex: Int
    var totalScore: Int
    var totalSessions: Int
    var totalHours: Double
    var avgFocusScore: Int
    var weeklyConsistency: Double
    var kingBuildings: [String]
    var isDeviceVerified: Bool

    var color: Color {
        AppColors.userColors[colorIndex % AppColors.userColors.count]
    }
}
