import Foundation

enum MockData {

    // MARK: - Current User

    static let currentUser = User(
        id: "user-me",
        name: "Yewon",
        initials: "YC",
        colorIndex: 0,
        totalScore: 2450,
        totalSessions: 47,
        totalHours: 62.5,
        avgFocusScore: 82,
        weeklyConsistency: 0.71,
        kingBuildings: ["walc", "knoy", "corec"],
        isDeviceVerified: true
    )

    // MARK: - Users

    static let users: [User] = [
        currentUser,
        User(id: "user-1", name: "NakJun", initials: "NJ", colorIndex: 1, totalScore: 2280, totalSessions: 42, totalHours: 58.0, avgFocusScore: 88, weeklyConsistency: 0.86, kingBuildings: ["lawson", "hovde"], isDeviceVerified: true),
        User(id: "user-2", name: "Suji", initials: "SJ", colorIndex: 2, totalScore: 2100, totalSessions: 38, totalHours: 51.0, avgFocusScore: 79, weeklyConsistency: 0.71, kingBuildings: ["hicks", "lilly"], isDeviceVerified: true),
        User(id: "user-3", name: "Eunho", initials: "EH", colorIndex: 3, totalScore: 1950, totalSessions: 35, totalHours: 45.0, avgFocusScore: 85, weeklyConsistency: 0.57, kingBuildings: [], isDeviceVerified: true),
        User(id: "user-4", name: "Alex", initials: "AK", colorIndex: 4, totalScore: 1820, totalSessions: 33, totalHours: 42.0, avgFocusScore: 76, weeklyConsistency: 0.86, kingBuildings: ["pmu"], isDeviceVerified: false),
        User(id: "user-5", name: "Jordan", initials: "JT", colorIndex: 5, totalScore: 1700, totalSessions: 30, totalHours: 38.0, avgFocusScore: 81, weeklyConsistency: 0.43, kingBuildings: [], isDeviceVerified: true),
        User(id: "user-6", name: "Casey", initials: "CR", colorIndex: 6, totalScore: 1580, totalSessions: 28, totalHours: 35.0, avgFocusScore: 73, weeklyConsistency: 0.57, kingBuildings: [], isDeviceVerified: true),
        User(id: "user-7", name: "Riley", initials: "RM", colorIndex: 7, totalScore: 1420, totalSessions: 25, totalHours: 30.0, avgFocusScore: 77, weeklyConsistency: 0.43, kingBuildings: [], isDeviceVerified: false),
        User(id: "user-8", name: "Morgan", initials: "ML", colorIndex: 8, totalScore: 1300, totalSessions: 22, totalHours: 27.0, avgFocusScore: 70, weeklyConsistency: 0.29, kingBuildings: [], isDeviceVerified: true),
        User(id: "user-9", name: "Taylor", initials: "TS", colorIndex: 9, totalScore: 1150, totalSessions: 20, totalHours: 24.0, avgFocusScore: 68, weeklyConsistency: 0.43, kingBuildings: [], isDeviceVerified: true),
    ]

    // MARK: - Buildings (17 Purdue campus buildings)

    // MARK: - Building Floor Plans (normalized 0-1 polygons)

    static let floorPlans: [String: BuildingFloorPlan] = [
        "walc": BuildingFloorPlan(points: [
            (0.05, 0.05), (0.65, 0.05), (0.65, 0.45),
            (0.95, 0.45), (0.95, 0.95), (0.35, 0.95),
            (0.35, 0.55), (0.05, 0.55),
        ]),
        "lawson": BuildingFloorPlan(points: [
            (0.05, 0.05), (0.95, 0.05), (0.95, 0.60),
            (0.70, 0.60), (0.70, 0.95), (0.30, 0.95),
            (0.30, 0.60), (0.05, 0.60),
        ]),
        "hicks": BuildingFloorPlan(points: [
            (0.25, 0.03), (0.75, 0.03), (0.75, 0.97), (0.25, 0.97),
        ]),
        "haas": BuildingFloorPlan(points: [
            (0.10, 0.10), (0.90, 0.10), (0.90, 0.65),
            (0.70, 0.90), (0.10, 0.90),
        ]),
        "knoy": BuildingFloorPlan(points: [
            (0.03, 0.15), (0.97, 0.15), (0.97, 0.85), (0.03, 0.85),
        ]),
        "pmu": BuildingFloorPlan(points: [
            (0.25, 0.05), (0.75, 0.05), (0.75, 0.35),
            (0.95, 0.35), (0.95, 0.95), (0.05, 0.95),
            (0.05, 0.35), (0.25, 0.35),
        ]),
        "krach": BuildingFloorPlan(points: [
            (0.08, 0.08), (0.92, 0.08), (0.92, 0.92),
            (0.55, 0.92), (0.55, 0.55), (0.40, 0.55),
            (0.40, 0.92), (0.08, 0.92),
        ]),
        "heavilon": BuildingFloorPlan(points: [
            (0.50, 0.05), (0.92, 0.30), (0.80, 0.92),
            (0.20, 0.92), (0.08, 0.30),
        ]),
        "lilly": BuildingFloorPlan(points: [
            (0.02, 0.25), (0.98, 0.25), (0.98, 0.75), (0.02, 0.75),
        ]),
        "stanley": BuildingFloorPlan(points: [
            (0.30, 0.05), (0.70, 0.05), (0.70, 0.30),
            (0.95, 0.30), (0.95, 0.70), (0.70, 0.70),
            (0.70, 0.95), (0.30, 0.95), (0.30, 0.70),
            (0.05, 0.70), (0.05, 0.30), (0.30, 0.30),
        ]),
        "rec": BuildingFloorPlan(points: [
            (0.03, 0.12), (0.97, 0.12), (0.97, 0.88), (0.03, 0.88),
        ]),
        "krannert": BuildingFloorPlan(points: [
            (0.05, 0.05), (0.35, 0.05), (0.35, 0.60),
            (0.65, 0.60), (0.65, 0.05), (0.95, 0.05),
            (0.95, 0.95), (0.05, 0.95),
        ]),
        "corec": BuildingFloorPlan(points: [
            (0.03, 0.10), (0.75, 0.10), (0.75, 0.40),
            (0.97, 0.40), (0.97, 0.90), (0.03, 0.90),
        ]),
        "hovde": BuildingFloorPlan(points: [
            (0.12, 0.12), (0.88, 0.12), (0.88, 0.88), (0.12, 0.88),
        ]),
        "stewart": BuildingFloorPlan(points: [
            (0.05, 0.10), (0.95, 0.10), (0.95, 0.90), (0.05, 0.90),
        ]),
        "ee": BuildingFloorPlan(points: [
            (0.08, 0.10), (0.92, 0.10), (0.92, 0.90), (0.08, 0.90),
        ]),
        "arms": BuildingFloorPlan(points: [
            (0.05, 0.05), (0.60, 0.05), (0.60, 0.50),
            (0.95, 0.50), (0.95, 0.95), (0.05, 0.95),
        ]),
    ]

    // Coordinates from OpenStreetMap Overpass API (building centroids)
    static let buildings: [Building] = [
        // Claimed buildings
        Building(id: "walc", name: "Wilmeth Active Learning Center", abbreviation: "WALC", position: BuildingPosition(x: 32, y: 32), kingUserId: "user-me", kingName: "Yewon", totalScore: 12450, sessionsCount: 234, colorIndex: 0, floorPlan: floorPlans["walc"]!, latitude: 40.4273891, longitude: -86.9132292),
        Building(id: "lawson", name: "Lawson Computer Science Building", abbreviation: "LWSN", position: BuildingPosition(x: 14, y: 32), kingUserId: "user-1", kingName: "NakJun", totalScore: 10890, sessionsCount: 198, colorIndex: 1, floorPlan: floorPlans["lawson"]!, latitude: 40.4277959, longitude: -86.916995),
        Building(id: "hicks", name: "Hicks Undergraduate Library", abbreviation: "HIKS", position: BuildingPosition(x: 56, y: 42), kingUserId: "user-2", kingName: "Suji", totalScore: 9500, sessionsCount: 167, colorIndex: 2, floorPlan: floorPlans["hicks"]!, latitude: 40.4245347, longitude: -86.9126572),
        Building(id: "knoy", name: "Knoy Hall", abbreviation: "KNOY", position: BuildingPosition(x: 32, y: 18), kingUserId: "user-me", kingName: "Yewon", totalScore: 6800, sessionsCount: 98, colorIndex: 0, floorPlan: floorPlans["knoy"]!, latitude: 40.4278077, longitude: -86.9110906),
        Building(id: "pmu", name: "Purdue Memorial Union", abbreviation: "PMU", position: BuildingPosition(x: 38, y: 48), kingUserId: "user-4", kingName: "Mia K.", totalScore: 8900, sessionsCount: 156, colorIndex: 4, floorPlan: floorPlans["pmu"]!, latitude: 40.4250293, longitude: -86.9111556),
        Building(id: "hovde", name: "Hovde Hall", abbreviation: "HOVD", position: BuildingPosition(x: 32, y: 46), kingUserId: "user-1", kingName: "NakJun", totalScore: 3100, sessionsCount: 44, colorIndex: 1, floorPlan: floorPlans["hovde"]!, latitude: 40.4282374, longitude: -86.914441),
        Building(id: "corec", name: "France A. Cordova Rec Center", abbreviation: "COREC", position: BuildingPosition(x: 10, y: 80), kingUserId: "user-me", kingName: "Yewon", totalScore: 2200, sessionsCount: 32, colorIndex: 0, floorPlan: floorPlans["corec"]!, latitude: 40.428422, longitude: -86.9224466),
        Building(id: "lilly", name: "Lilly Hall", abbreviation: "LILY", position: BuildingPosition(x: 16, y: 62), kingUserId: "user-2", kingName: "Suji", totalScore: 3800, sessionsCount: 54, colorIndex: 2, floorPlan: floorPlans["lilly"]!, latitude: 40.4232248, longitude: -86.9182529),
        // Unclaimed buildings
        Building(id: "haas", name: "Haas Hall", abbreviation: "HAAS", position: BuildingPosition(x: 56, y: 32), kingUserId: nil, kingName: nil, totalScore: 7200, sessionsCount: 120, colorIndex: 3, floorPlan: floorPlans["haas"]!, latitude: 40.4268235, longitude: -86.9163111),
        Building(id: "krach", name: "Krach Leadership Center", abbreviation: "KRCH", position: BuildingPosition(x: 70, y: 32), kingUserId: nil, kingName: nil, totalScore: 5400, sessionsCount: 78, colorIndex: 5, floorPlan: floorPlans["krach"]!, latitude: 40.427589, longitude: -86.9212455),
        Building(id: "heavilon", name: "Heavilon Hall", abbreviation: "HEAV", position: BuildingPosition(x: 72, y: 44), kingUserId: nil, kingName: nil, totalScore: 4200, sessionsCount: 65, colorIndex: 6, floorPlan: floorPlans["heavilon"]!, latitude: 40.4258, longitude: -86.9138),
        Building(id: "stanley", name: "Stanley Coulter Hall", abbreviation: "SC", position: BuildingPosition(x: 40, y: 62), kingUserId: nil, kingName: nil, totalScore: 3500, sessionsCount: 48, colorIndex: 8, floorPlan: floorPlans["stanley"]!, latitude: 40.4249, longitude: -86.9146),
        Building(id: "rec", name: "Recitation Building", abbreviation: "REC", position: BuildingPosition(x: 56, y: 62), kingUserId: nil, kingName: nil, totalScore: 2900, sessionsCount: 40, colorIndex: 9, floorPlan: floorPlans["rec"]!, latitude: 40.4270, longitude: -86.9139),
        Building(id: "krannert", name: "Krannert Building", abbreviation: "KRAN", position: BuildingPosition(x: 80, y: 62), kingUserId: nil, kingName: nil, totalScore: 4100, sessionsCount: 60, colorIndex: 6, floorPlan: floorPlans["krannert"]!, latitude: 40.4236819, longitude: -86.9109362),
        Building(id: "stewart", name: "Stewart Center", abbreviation: "STEW", position: BuildingPosition(x: 38, y: 55), kingUserId: nil, kingName: nil, totalScore: 2800, sessionsCount: 38, colorIndex: 9, floorPlan: floorPlans["stewart"]!, latitude: 40.4250842, longitude: -86.9127108),
        Building(id: "ee", name: "Electrical Engineering Building", abbreviation: "EE", position: BuildingPosition(x: 50, y: 18), kingUserId: nil, kingName: nil, totalScore: 2400, sessionsCount: 34, colorIndex: 3, floorPlan: floorPlans["ee"]!, latitude: 40.4293415, longitude: -86.9126703),
        Building(id: "arms", name: "Neil Armstrong Hall", abbreviation: "ARMS", position: BuildingPosition(x: 60, y: 35), kingUserId: nil, kingName: nil, totalScore: 2600, sessionsCount: 36, colorIndex: 5, floorPlan: floorPlans["arms"]!, latitude: 40.4309179, longitude: -86.9149836),
    ]

    // MARK: - WALC Territory Data (Top 10)

    static let walcTerritory: [TerritoryEntry] = [
        TerritoryEntry(id: "t1", userId: "user-me", userName: "Yewon", userInitials: "YC", colorIndex: 0, score: 2450, ownershipPercent: 22.5, isStudying: false, rank: 1),
        TerritoryEntry(id: "t2", userId: "user-1", userName: "NakJun", userInitials: "NJ", colorIndex: 1, score: 2100, ownershipPercent: 19.3, isStudying: true, rank: 2),
        TerritoryEntry(id: "t3", userId: "user-2", userName: "Suji", userInitials: "SJ", colorIndex: 2, score: 1850, ownershipPercent: 17.0, isStudying: false, rank: 3),
        TerritoryEntry(id: "t4", userId: "user-3", userName: "Eunho", userInitials: "EH", colorIndex: 3, score: 1420, ownershipPercent: 13.1, isStudying: true, rank: 4),
        TerritoryEntry(id: "t5", userId: "user-4", userName: "Alex", userInitials: "AK", colorIndex: 4, score: 980, ownershipPercent: 9.0, isStudying: false, rank: 5),
        TerritoryEntry(id: "t6", userId: "user-5", userName: "Jordan", userInitials: "JT", colorIndex: 5, score: 720, ownershipPercent: 6.6, isStudying: false, rank: 6),
        TerritoryEntry(id: "t7", userId: "user-6", userName: "Casey", userInitials: "CR", colorIndex: 6, score: 540, ownershipPercent: 5.0, isStudying: false, rank: 7),
        TerritoryEntry(id: "t8", userId: "user-7", userName: "Riley", userInitials: "RM", colorIndex: 7, score: 380, ownershipPercent: 3.5, isStudying: false, rank: 8),
        TerritoryEntry(id: "t9", userId: "user-8", userName: "Morgan", userInitials: "ML", colorIndex: 8, score: 280, ownershipPercent: 2.6, isStudying: false, rank: 9),
        TerritoryEntry(id: "t10", userId: "user-9", userName: "Taylor", userInitials: "TS", colorIndex: 9, score: 160, ownershipPercent: 1.4, isStudying: false, rank: 10),
    ]

    // MARK: - Activity Feed

    static let activityFeed: [ActivityFeedItem] = [
        ActivityFeedItem(id: "a1", message: "NakJun finished 2h session (+85pts)", timestamp: Date().addingTimeInterval(-120), type: .sessionComplete),
        ActivityFeedItem(id: "a2", message: "Suji is studying now...", timestamp: Date().addingTimeInterval(-300), type: .studying),
        ActivityFeedItem(id: "a3", message: "Eunho overtook Alex! Now #4", timestamp: Date().addingTimeInterval(-600), type: .overtake),
        ActivityFeedItem(id: "a4", message: "Yewon claimed WALC King!", timestamp: Date().addingTimeInterval(-1800), type: .kingTakeover),
        ActivityFeedItem(id: "a5", message: "Jordan finished 1h session (+42pts)", timestamp: Date().addingTimeInterval(-2400), type: .sessionComplete),
        ActivityFeedItem(id: "a6", message: "Casey started studying", timestamp: Date().addingTimeInterval(-3000), type: .studying),
        ActivityFeedItem(id: "a7", message: "Riley finished 4h session (+120pts)", timestamp: Date().addingTimeInterval(-3600), type: .sessionComplete),
        ActivityFeedItem(id: "a8", message: "NakJun is studying now...", timestamp: Date().addingTimeInterval(-4200), type: .studying),
    ]

    // MARK: - Session History

    static let sessionHistory: [StudySession] = [
        StudySession(id: "s1", userId: "user-me", buildingId: "walc", buildingName: "WALC", startTime: Date().addingTimeInterval(-3600), duration: 120, focusScore: 87, buildingScore: 72, gazeScore: 91, postureScore: 85, blinkScore: 88, keyMouseScore: 82, tabScore: 79, checkInScore: 95, isComplete: true),
        StudySession(id: "s2", userId: "user-me", buildingId: "lawson", buildingName: "LWSN", startTime: Date().addingTimeInterval(-86400), duration: 60, focusScore: 74, buildingScore: 48, gazeScore: 78, postureScore: 70, blinkScore: 75, keyMouseScore: 69, tabScore: 72, checkInScore: 80, isComplete: true),
        StudySession(id: "s3", userId: "user-me", buildingId: "walc", buildingName: "WALC", startTime: Date().addingTimeInterval(-172800), duration: 240, focusScore: 91, buildingScore: 88, gazeScore: 94, postureScore: 89, blinkScore: 92, keyMouseScore: 87, tabScore: 85, checkInScore: 98, isComplete: true),
        StudySession(id: "s4", userId: "user-me", buildingId: "hicks", buildingName: "HIKS", startTime: Date().addingTimeInterval(-259200), duration: 120, focusScore: 68, buildingScore: 52, gazeScore: 72, postureScore: 65, blinkScore: 70, keyMouseScore: 63, tabScore: 60, checkInScore: 78, isComplete: true),
        StudySession(id: "s5", userId: "user-me", buildingId: "pmu", buildingName: "PMU", startTime: Date().addingTimeInterval(-345600), duration: 60, focusScore: 82, buildingScore: 55, gazeScore: 85, postureScore: 80, blinkScore: 83, keyMouseScore: 78, tabScore: 76, checkInScore: 90, isComplete: true),
        StudySession(id: "s6", userId: "user-me", buildingId: "walc", buildingName: "WALC", startTime: Date().addingTimeInterval(-432000), duration: 120, focusScore: 79, buildingScore: 64, gazeScore: 82, postureScore: 77, blinkScore: 80, keyMouseScore: 75, tabScore: 73, checkInScore: 87, isComplete: true),
        StudySession(id: "s7", userId: "user-me", buildingId: "lawson", buildingName: "LWSN", startTime: Date().addingTimeInterval(-518400), duration: 240, focusScore: 93, buildingScore: 90, gazeScore: 96, postureScore: 91, blinkScore: 94, keyMouseScore: 89, tabScore: 87, checkInScore: 100, isComplete: true),
        StudySession(id: "s8", userId: "user-me", buildingId: "krach", buildingName: "KRCH", startTime: Date().addingTimeInterval(-604800), duration: 60, focusScore: 65, buildingScore: 42, gazeScore: 68, postureScore: 62, blinkScore: 66, keyMouseScore: 60, tabScore: 58, checkInScore: 76, isComplete: true),
        StudySession(id: "s9", userId: "user-me", buildingId: "walc", buildingName: "WALC", startTime: Date().addingTimeInterval(-691200), duration: 120, focusScore: 85, buildingScore: 70, gazeScore: 88, postureScore: 83, blinkScore: 86, keyMouseScore: 80, tabScore: 78, checkInScore: 93, isComplete: true),
        StudySession(id: "s10", userId: "user-me", buildingId: "hicks", buildingName: "HIKS", startTime: Date().addingTimeInterval(-777600), duration: 60, focusScore: 77, buildingScore: 50, gazeScore: 80, postureScore: 75, blinkScore: 78, keyMouseScore: 73, tabScore: 71, checkInScore: 85, isComplete: true),
    ]

    // MARK: - Roads

    struct Road: Sendable {
        let name: String
        let isHorizontal: Bool
        let position: Double // y for horizontal, x for vertical (percentage)
    }

    static let roads: [Road] = [
        Road(name: "Third Street", isHorizontal: true, position: 28),
        Road(name: "State Street", isHorizontal: true, position: 56),
        Road(name: "Stadium Ave", isHorizontal: true, position: 76),
        Road(name: "N University St", isHorizontal: false, position: 26),
        Road(name: "N Grant St", isHorizontal: false, position: 52),
        Road(name: "Russell St", isHorizontal: false, position: 78),
    ]

    // MARK: - Weekly Stats

    static let weekNumber = 14
    static let weekResetTimeInterval: TimeInterval = 4 * 86400 + 13 * 3600 // 4d 13h

    static let pastWeeks: [(week: Int, score: Int, sessions: Int, kingBuildings: [String])] = [
        (13, 2180, 12, ["lawson"]),
        (12, 1950, 10, []),
        (11, 2320, 14, ["walc", "hicks"]),
    ]

    static let streakDays = 5
    static let streakDots: [Bool] = [true, true, true, true, true, false, false] // Mon-Sun
}
