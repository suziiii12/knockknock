import Foundation

enum MockData {

    // MARK: - Current User

    static let currentUser = User(
        id: "user-me",
        name: "Yewon",
        initials: "YC",
        colorIndex: 0,
        totalScore: 260,           // this week: HIKS 130 + WALC 80 + LWSN 50
        totalSessions: 47,
        totalHours: 62.5,
        avgFocusScore: 82,
        kingBuildings: ["walc", "knoy", "corec"],
        isDeviceVerified: true
    )

    // MARK: - Users

    static let users: [User] = [
        currentUser,
        User(id: "user-1", name: "NakJun", initials: "NJ", colorIndex: 1, totalScore: 318, totalSessions: 42, totalHours: 58.0, avgFocusScore: 88, kingBuildings: ["lawson", "hovde"], isDeviceVerified: true),
        User(id: "user-2", name: "Suji", initials: "SJ", colorIndex: 2, totalScore: 285, totalSessions: 38, totalHours: 51.0, avgFocusScore: 79, kingBuildings: ["hicks", "lilly"], isDeviceVerified: true),
        User(id: "user-3", name: "Eunho", initials: "EH", colorIndex: 3, totalScore: 241, totalSessions: 35, totalHours: 45.0, avgFocusScore: 85, kingBuildings: [], isDeviceVerified: true),
        User(id: "user-4", name: "Alex", initials: "AK", colorIndex: 4, totalScore: 198, totalSessions: 33, totalHours: 42.0, avgFocusScore: 76, kingBuildings: ["pmu"], isDeviceVerified: false),
        User(id: "user-5", name: "Jordan", initials: "JT", colorIndex: 5, totalScore: 174, totalSessions: 30, totalHours: 38.0, avgFocusScore: 81, kingBuildings: [], isDeviceVerified: true),
        User(id: "user-6", name: "Casey", initials: "CR", colorIndex: 6, totalScore: 152, totalSessions: 28, totalHours: 35.0, avgFocusScore: 73, kingBuildings: [], isDeviceVerified: true),
        User(id: "user-7", name: "Riley", initials: "RM", colorIndex: 7, totalScore: 138, totalSessions: 25, totalHours: 30.0, avgFocusScore: 77, kingBuildings: [], isDeviceVerified: false),
        User(id: "user-8", name: "Morgan", initials: "ML", colorIndex: 8, totalScore: 119, totalSessions: 22, totalHours: 27.0, avgFocusScore: 70, kingBuildings: [], isDeviceVerified: true),
        User(id: "user-9", name: "Taylor", initials: "TS", colorIndex: 9, totalScore: 98, totalSessions: 20, totalHours: 24.0, avgFocusScore: 68, kingBuildings: [], isDeviceVerified: true),
    ]

    // MARK: - Weekly building score breakdown (current user, this week)
    // Used by ProfileView to show per-building contribution
    static let weeklyBuildingScores: [(buildingId: String, abbreviation: String, score: Int)] = [
        ("hicks",  "HIKS", 130),   // 2 sessions: 89 + 41
        ("walc",   "WALC",  80),   // 1 session
        ("lawson", "LWSN",  50),   // 1 session
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
        "lilly": BuildingFloorPlan(points: [
            (0.02, 0.25), (0.98, 0.25), (0.98, 0.75), (0.02, 0.75),
        ]),
        "stanley": BuildingFloorPlan(points: [
            (0.30, 0.05), (0.70, 0.05), (0.70, 0.30),
            (0.95, 0.30), (0.95, 0.70), (0.70, 0.70),
            (0.70, 0.95), (0.30, 0.95), (0.30, 0.70),
            (0.05, 0.70), (0.05, 0.30), (0.30, 0.30),
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
        "heavilon": BuildingFloorPlan(points: [
            (0.10, 0.10), (0.90, 0.10), (0.90, 0.90), (0.10, 0.90),
        ]),
        "rec": BuildingFloorPlan(points: [
            (0.08, 0.08), (0.92, 0.08), (0.92, 0.92), (0.08, 0.92),
        ]),
    ]

    // Coordinates from OpenStreetMap Overpass API (building centroids)
    // Coordinates from Purdue ArcGIS campus map (ESRI feature service, WGS84)
    // https://purdueuniversity.maps.arcgis.com/apps/instant/basic/index.html?appid=d7e5d06fb5344f5fb53819c42d3e91ed
    // Coordinates from Purdue ArcGIS campus map (ESRI feature service, WGS84)
    // https://purdueuniversity.maps.arcgis.com/apps/instant/basic/index.html?appid=d7e5d06fb5344f5fb53819c42d3e91ed
    static let buildings: [Building] = [
        Building(id: "walc",     name: "Wilmeth Active Learning Center",       abbreviation: "WALC",  position: BuildingPosition(x: 32, y: 32), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 0, floorPlan: floorPlans["walc"]!,     latitude: 40.427404, longitude: -86.913219),
        Building(id: "lawson",   name: "Lawson Computer Science Building",      abbreviation: "LWSN",  position: BuildingPosition(x: 14, y: 32), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 1, floorPlan: floorPlans["lawson"]!,   latitude: 40.427787, longitude: -86.917025),
        Building(id: "hicks",    name: "Hicks Undergraduate Library",           abbreviation: "HIKS",  position: BuildingPosition(x: 56, y: 42), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 2, floorPlan: floorPlans["hicks"]!,    latitude: 40.424533, longitude: -86.912658),
        Building(id: "haas",     name: "Felix Haas Hall",                       abbreviation: "HAAS",  position: BuildingPosition(x: 56, y: 32), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 3, floorPlan: floorPlans["haas"]!,     latitude: 40.426827, longitude: -86.916340),
        Building(id: "knoy",     name: "Knoy Hall of Technology",               abbreviation: "KNOY",  position: BuildingPosition(x: 32, y: 18), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 4, floorPlan: floorPlans["knoy"]!,     latitude: 40.427754, longitude: -86.911131),
        Building(id: "pmu",      name: "Purdue Memorial Union",                 abbreviation: "PMU",   position: BuildingPosition(x: 38, y: 48), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 5, floorPlan: floorPlans["pmu"]!,      latitude: 40.424975, longitude: -86.911285),
        Building(id: "hovde",    name: "Hovde Hall of Administration",          abbreviation: "HOVD",  position: BuildingPosition(x: 32, y: 46), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 6, floorPlan: floorPlans["hovde"]!,    latitude: 40.428241, longitude: -86.914432),
        Building(id: "corec",    name: "Córdova Recreational Sports Center",    abbreviation: "COREC", position: BuildingPosition(x: 10, y: 80), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 7, floorPlan: floorPlans["corec"]!,    latitude: 40.428500, longitude: -86.922400),
        Building(id: "lilly",    name: "Lilly Hall of Life Sciences",           abbreviation: "LILY",  position: BuildingPosition(x: 16, y: 62), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 8, floorPlan: floorPlans["lilly"]!,    latitude: 40.423395, longitude: -86.918161),
        Building(id: "krach",    name: "Krach Leadership Center",               abbreviation: "KRCH",  position: BuildingPosition(x: 70, y: 32), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 9, floorPlan: floorPlans["krach"]!,    latitude: 40.427580, longitude: -86.921270),
        Building(id: "heavilon", name: "Heavilon Hall",                         abbreviation: "HEAV",  position: BuildingPosition(x: 72, y: 44), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 0, floorPlan: floorPlans["heavilon"]!, latitude: 40.425800, longitude: -86.913800),
        Building(id: "stanley",  name: "Stanley Coulter Hall",                  abbreviation: "SC",    position: BuildingPosition(x: 40, y: 62), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 1, floorPlan: floorPlans["stanley"]!,  latitude: 40.426530, longitude: -86.914379),
        Building(id: "rec",      name: "Recitation Building",                   abbreviation: "REC",   position: BuildingPosition(x: 56, y: 62), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 2, floorPlan: floorPlans["rec"]!,      latitude: 40.427000, longitude: -86.913900),
        Building(id: "krannert", name: "Krannert Building",                     abbreviation: "KRAN",  position: BuildingPosition(x: 80, y: 62), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 3, floorPlan: floorPlans["krannert"]!, latitude: 40.423693, longitude: -86.910956),
        Building(id: "stewart",  name: "Stewart Center",                        abbreviation: "STEW",  position: BuildingPosition(x: 38, y: 55), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 4, floorPlan: floorPlans["stewart"]!,  latitude: 40.425052, longitude: -86.912749),
        Building(id: "ee",       name: "Materials & Electrical Engineering",    abbreviation: "MSEE",  position: BuildingPosition(x: 50, y: 18), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 5, floorPlan: floorPlans["ee"]!,       latitude: 40.429345, longitude: -86.912669),
        Building(id: "arms",     name: "Neil Armstrong Hall of Engineering",    abbreviation: "ARMS",  position: BuildingPosition(x: 60, y: 35), kingUserId: nil, kingName: nil, totalScore: 0, sessionsCount: 0, colorIndex: 6, floorPlan: floorPlans["arms"]!,     latitude: 40.430975, longitude: -86.914995),
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
        // This week — contributes to weeklyBuildingScores (WALC 80, HIKS 130, LWSN 50)
        // sessionScore = Int(focusLevel * 0.8 + min(duration/240*100, 100) * 0.2)
        StudySession(id: "s1", userId: "user-me", buildingId: "walc",   buildingName: "WALC", startTime: Date().addingTimeInterval(-3600),   duration: 120, focusScore: 88, sessionScore: 80, screenCapture: 88, motionDetection: 88, isComplete: true),
        StudySession(id: "s2", userId: "user-me", buildingId: "hicks",  buildingName: "HIKS", startTime: Date().addingTimeInterval(-86400),  duration: 180, focusScore: 93, sessionScore: 89, screenCapture: 94, motionDetection: 92, isComplete: true),
        StudySession(id: "s3", userId: "user-me", buildingId: "hicks",  buildingName: "HIKS", startTime: Date().addingTimeInterval(-172800), duration: 60,  focusScore: 45, sessionScore: 41, screenCapture: 46, motionDetection: 44, isComplete: true),
        StudySession(id: "s4", userId: "user-me", buildingId: "lawson", buildingName: "LWSN", startTime: Date().addingTimeInterval(-259200), duration: 120, focusScore: 50, sessionScore: 50, screenCapture: 52, motionDetection: 48, isComplete: true),
        // Previous weeks
        StudySession(id: "s5", userId: "user-me", buildingId: "walc",   buildingName: "WALC", startTime: Date().addingTimeInterval(-345600), duration: 240, focusScore: 81, sessionScore: 84, screenCapture: 82, motionDetection: 80, isComplete: true),
        StudySession(id: "s6", userId: "user-me", buildingId: "hicks",  buildingName: "HIKS", startTime: Date().addingTimeInterval(-432000), duration: 120, focusScore: 68, sessionScore: 64, screenCapture: 68, motionDetection: 68, isComplete: true),
        StudySession(id: "s7", userId: "user-me", buildingId: "pmu",    buildingName: "PMU",  startTime: Date().addingTimeInterval(-518400), duration: 60,  focusScore: 79, sessionScore: 68, screenCapture: 78, motionDetection: 80, isComplete: true),
        StudySession(id: "s8", userId: "user-me", buildingId: "lawson", buildingName: "LWSN", startTime: Date().addingTimeInterval(-604800), duration: 240, focusScore: 91, sessionScore: 92, screenCapture: 92, motionDetection: 90, isComplete: true),
        StudySession(id: "s9", userId: "user-me", buildingId: "krach",  buildingName: "KRCH", startTime: Date().addingTimeInterval(-691200), duration: 60,  focusScore: 63, sessionScore: 55, screenCapture: 64, motionDetection: 62, isComplete: true),
        StudySession(id: "s10",userId: "user-me", buildingId: "walc",   buildingName: "WALC", startTime: Date().addingTimeInterval(-777600), duration: 120, focusScore: 84, sessionScore: 77, screenCapture: 84, motionDetection: 84, isComplete: true),
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

    // Streak tracking removed — consistency is no longer part of scoring
}
