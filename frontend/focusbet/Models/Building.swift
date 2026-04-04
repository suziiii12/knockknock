import Foundation
import SwiftUI
import CoreLocation

struct BuildingPosition: Hashable, Sendable {
    let x: Double
    let y: Double
}

/// Normalized polygon points (0-1) defining a building's floor plan outline.
struct BuildingFloorPlan: Hashable, Sendable {
    let points: [(Double, Double)]

    func hash(into hasher: inout Hasher) {
        for (x, y) in points { hasher.combine(x); hasher.combine(y) }
    }

    static func == (lhs: BuildingFloorPlan, rhs: BuildingFloorPlan) -> Bool {
        guard lhs.points.count == rhs.points.count else { return false }
        return zip(lhs.points, rhs.points).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
    }

    /// Ray-casting point-in-polygon test.
    func contains(x: Double, y: Double) -> Bool {
        let n = points.count
        guard n >= 3 else { return false }
        var inside = false
        var j = n - 1
        for i in 0..<n {
            let (xi, yi) = points[i]
            let (xj, yj) = points[j]
            if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}

struct Building: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let abbreviation: String
    let position: BuildingPosition
    var kingUserId: String?
    var kingName: String?
    var totalScore: Int
    var sessionsCount: Int
    var colorIndex: Int
    var floorPlan: BuildingFloorPlan
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var color: Color {
        if kingUserId != nil {
            return AppColors.userColors[colorIndex % AppColors.userColors.count]
        }
        return AppColors.textMuted
    }
}
