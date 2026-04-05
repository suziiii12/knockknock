import Foundation

// MARK: - Public result types (used by ViewModels)

struct UserProfile {
    let id: Int
    let name: String?
    let school: String?
    let major: String?
    let year: String?
    let gender: String?
    let sessionCount: Int
    let totalMinutes: Double
    let avgFocusScore: Double
    let totalScore: Double
    let weeklyScore: Double
    let kingBuildingIds: [Int]
}

struct SessionStartResult {
    let sessionId: Int
}

struct CheckInAPIResult {
    let passed: Bool
    let feedback: String
    let scoreDelta: Double
}

// MARK: - Errors

enum APIError: LocalizedError {
    case badURL
    case badResponse
    case unauthorized
    case notFound
    case serverError(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .badURL:            return "Invalid URL."
        case .badResponse:       return "Unexpected server response."
        case .unauthorized:      return "Session expired. Please sign in again."
        case .notFound:          return "Resource not found."
        case .serverError(let m): return m
        case .decodingError(let e): return "Decode error: \(e.localizedDescription)"
        }
    }
}

// MARK: - APIService

actor APIService {
    static let shared = APIService()
    private init() {}

    /// Set to true to skip all network calls and use MockData only (frontend dev mode).
    static let useMockOnly = false

    private let baseURL = "http://127.0.0.1:8000"
    private var authToken: String?

    // MARK: - Token management

    func setToken(_ token: String) { authToken = token }
    func clearToken()              { authToken = nil }

    /// DEV ONLY — creates/fetches the test user and sets the auth token automatically.
    /// Call once on app launch during development to skip World ID auth.
    func authenticateAsDevUser() async {
        guard authToken == nil || authToken!.isEmpty else {
            print("[APIService] DEV TOKEN already set — skipping")
            return
        }
        guard let url = URL(string: "\(baseURL)/dev/create-test-user") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                authToken = token
                print("[APIService] DEV TOKEN SET: \(token.prefix(20))… user_id=\(json["user_id"] ?? "?")")
            } else {
                print("[APIService] authenticateAsDevUser: unexpected response body")
            }
        } catch {
            print("[APIService] authenticateAsDevUser failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private helpers

    private func makeRequest(path: String, method: String = "GET") -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func handleUnauthorized() {
        authToken = nil
        Task { @MainActor in
            NotificationCenter.default.post(name: .authTokenExpired, object: nil)
        }
    }

    /// Generic fetch: sends a request, validates status, unwraps `{success, data}` envelope.
    private func fetch<T: Decodable>(
        _ type: T.Type,
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        if Self.useMockOnly { throw APIError.serverError("Mock-only mode") }
        print("[APIService] \(method) \(path) — token:\(authToken != nil ? "set" : "NIL ⚠️")")
        guard var req = makeRequest(path: path, method: method) else {
            print("[APIService] ⚠️ bad URL for path: \(path)")
            throw APIError.badURL
        }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }

        if http.statusCode == 401 {
            handleUnauthorized()
            throw APIError.unauthorized
        }
        if http.statusCode == 404 { throw APIError.notFound }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ServerErrorBody.self, from: data))?.detail
                ?? "HTTP \(http.statusCode)"
            throw APIError.serverError(detail)
        }

        do {
            let wrapped = try JSONDecoder().decode(APIWrapped<T>.self, from: data)
            guard wrapped.success, let result = wrapped.data else { throw APIError.badResponse }
            return result
        } catch let e as DecodingError {
            throw APIError.decodingError(e)
        }
    }

    // MARK: - Buildings

    /// Returns the full building list using MockData as the source of truth for visual
    /// data (floor plans, positions, coordinates). The backend doesn't store these fields.
    func fetchBuildings() async throws -> [Building] {
        return MockData.buildings
    }

    // MARK: - Building king

    /// Returns the name of the top-ranked user for a building, or nil if no data.
    func fetchBuildingKing(buildingSlug: String) async -> String? {
        guard let backendId = Self.buildingSlugToId[buildingSlug] else { return nil }
        guard let entries = try? await fetch(
            [APILeaderboardEntry].self,
            path: "/buildings/\(backendId)/leaderboard"
        ), let top = entries.first else { return nil }
        return top.userName ?? "User #\(top.userId)"
    }

    // MARK: - Territory / Leaderboard

    /// Fetches real territory rankings from the backend and maps them to TerritoryEntry.
    /// Falls back to MockData on any failure so the UI is never broken.
    func fetchTerritory(buildingId: String) async throws -> [TerritoryEntry] {
        guard let backendId = Self.buildingSlugToId[buildingId] else {
            throw APIError.notFound
        }
        let entries = try await fetch(
            [APILeaderboardEntry].self,
            path: "/buildings/\(backendId)/leaderboard"
        )
        return entries.map { entry in
            // Map integer userId → display strings where possible
            let colorIdx = (entry.rank - 1) % AppColors.userColors.count
            let displayName = entry.userName ?? "User #\(entry.userId)"
            let initials = entry.userName.map { name in
                name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
            } ?? "#\(entry.userId)"
            return TerritoryEntry(
                id: "t\(entry.rank)",
                userId: String(entry.userId),
                userName: displayName,
                userInitials: initials,
                colorIndex: colorIdx,
                score: Int(entry.totalScore),
                ownershipPercent: 0,          // computed below
                isStudying: false,
                rank: entry.rank
            )
        }
        .enumerated()
        .map { idx, t in
            // Re-compute ownership % once we have all scores
            let total = entries.map(\.totalScore).reduce(0, +)
            let pct = total > 0 ? (entries[idx].totalScore / total) * 100 : 0
            return TerritoryEntry(
                id: t.id, userId: t.userId, userName: t.userName,
                userInitials: t.userInitials, colorIndex: t.colorIndex,
                score: t.score, ownershipPercent: pct,
                isStudying: t.isStudying, rank: t.rank
            )
        }
    }

    // Mapping from frontend string slug → backend integer building ID.
    // Matches the rows inserted by backend/seed.py (WALC=1, Hicks=2, HAAS=3).
    // Extend this map as more buildings are seeded.
    private static let buildingSlugToId: [String: Int] = [
        "walc":     1,
        "hicks":    2,
        "haas":     3,
        "lawson":   7,
        "knoy":     8,
        "pmu":      9,
        "hovde":   10,
        "corec":   11,
        "lilly":   12,
        "krach":   13,
        "heavilon": 14,
        "stanley": 15,
        "rec":     16,
        "krannert": 17,
        "stewart": 18,
        "ee":      19,
        "arms":    20,
    ]

    private static let buildingIdToSlug: [Int: String] = Dictionary(
        uniqueKeysWithValues: buildingSlugToId.map { ($1, $0) }
    )

    // MARK: - User profile

    func saveProfile(
        name: String,
        school: String,
        major: String,
        year: String,
        expectedGraduation: String,
        gender: String
    ) async throws {
        var body: [String: Any] = [:]
        if !name.isEmpty               { body["name"]                = name }
        if !school.isEmpty             { body["school"]              = school }
        if !major.isEmpty              { body["major"]               = major }
        if !year.isEmpty               { body["year"]                = year }
        if !expectedGraduation.isEmpty { body["expected_graduation"] = expectedGraduation }
        if !gender.isEmpty             { body["gender"]              = gender }
        _ = try await fetch(APIProfileOut.self, path: "/users/me/profile", method: "PATCH", body: body)
    }

    func fetchUserProfile() async throws -> UserProfile {
        let raw = try await fetch(APIUserMe.self, path: "/users/me")
        return UserProfile(
            id: raw.id,
            name: raw.name,
            school: raw.school,
            major: raw.major,
            year: raw.year,
            gender: raw.gender,
            sessionCount: raw.sessionCount,
            totalMinutes: raw.totalMinutes,
            avgFocusScore: raw.avgFocusScore,
            totalScore: raw.totalScore,
            weeklyScore: raw.weeklyScore,
            kingBuildingIds: raw.kingBuildingIds
        )
    }

    /// Maps a backend building integer ID to the frontend slug used by MockData.
    static func buildingSlug(for backendId: Int) -> String? {
        buildingIdToSlug[backendId]
    }

    /// Returns the current user's weekly score for this week.
    /// Falls back to 0 if the user has no score yet this week.
    func fetchWeeklyScore() async throws -> Int {
        let raw = try await fetch(APIWeeklyScoreOut.self, path: "/users/me/weekly-score")
        return Int(raw.weeklyScore.rounded())
    }

    // MARK: - Session history

    func fetchSessionHistory() async throws -> [StudySession] {
        // Falls back to MockData until backend exposes GET /sessions/history
        do {
            let entries = try await fetch([APISessionHistoryEntry].self, path: "/sessions/history")
            return entries.compactMap { entry in
                guard let endedAt = entry.endedAt,
                      let startDate = ISO8601DateFormatter().date(from: entry.startedAt),
                      let endDate = ISO8601DateFormatter().date(from: endedAt) else { return nil }
                let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
                let score = Int(entry.finalScore ?? 0)
                let buildingSlug = Self.buildingIdToSlug[entry.buildingId ?? 0] ?? "unknown"
                let buildingAbbr = MockData.buildings.first(where: { $0.id == buildingSlug })?.abbreviation ?? buildingSlug.uppercased()
                return StudySession(
                    id: String(entry.id),
                    userId: String(entry.userId),
                    buildingId: buildingSlug,
                    buildingName: buildingAbbr,
                    startTime: startDate,
                    duration: durationMinutes,
                    focusScore: score,
                    sessionScore: score,
                    screenCapture: score,
                    motionDetection: score,
                    isComplete: true
                )
            }
        } catch {
            return MockData.sessionHistory
        }
    }

    // MARK: - Sessions

    /// Starts a new solo session. Returns the backend session ID.
    func startSoloSession(durationMinutes: Int, buildingSlug: String?) async throws -> Int {
        var body: [String: Any] = ["duration": Double(durationMinutes)]
        if let slug = buildingSlug, let bid = Self.buildingSlugToId[slug] {
            body["building_id"] = bid
        }
        let raw = try await fetch(APISessionOut.self, path: "/sessions/start", method: "POST", body: body)
        return raw.id
    }

    /// Posts a focus level snapshot (0.0–1.0) for an active session.
    func postFocusLevel(sessionId: Int, level: Double) async throws {
        _ = try await fetch(
            APIFocusLevelOut.self,
            path: "/sessions/\(sessionId)/focus-level",
            method: "POST",
            body: ["level": max(0.0, min(1.0, level))]
        )
    }

    /// Ends the current user's active session. Returns the final score (0–100).
    func endSession() async throws -> Double {
        let raw = try await fetch(APISessionOut.self, path: "/sessions/end", method: "POST")
        return raw.finalScore ?? 0.0
    }

    // MARK: - Check-in

    func evaluateCheckIn(sessionId: Int, prompt: String, answer: String) async throws -> CheckInAPIResult {
        let raw = try await fetch(
            APICheckInResult.self,
            path: "/checkin/evaluate",
            method: "POST",
            body: [
                "session_id": sessionId,
                "prompt":     prompt,
                "answer":     answer,
            ]
        )
        return CheckInAPIResult(
            passed:     raw.passed,
            feedback:   raw.feedback,
            scoreDelta: raw.scoreDelta
        )
    }

    // MARK: - WebSocket

    /// Opens a WebSocket to `/ws/challenge/{challengeId}` and starts receiving messages.
    /// The caller receives decoded `[String: Any]` payloads via `onMessage`.
    /// Call `.cancel()` on the returned task to disconnect.
    nonisolated func connectWebSocket(
        challengeId: Int,
        onMessage: @escaping @Sendable ([String: Any]) -> Void
    ) -> URLSessionWebSocketTask? {
        let wsBase = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://",  with: "ws://")
        guard let url = URL(string: "\(wsBase)/ws/challenge/\(challengeId)") else { return nil }

        var req = URLRequest(url: url)
        // Note: The backend WS endpoint doesn't require auth, but we attach it anyway.
        Task {
            if let tok = await authToken {
                req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            }
        }

        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()

        // Start receive loop
        func receive() {
            task.receive { result in
                switch result {
                case .success(.string(let text)):
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        onMessage(json)
                    }
                    receive()
                case .success(.data(let data)):
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        onMessage(json)
                    }
                    receive()
                case .failure:
                    break   // connection closed or error — caller can reconnect
                @unknown default:
                    receive()
                }
            }
        }
        receive()
        return task
    }
}

// MARK: - Private Decodable response shapes

private struct APIWrapped<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
}

private struct ServerErrorBody: Decodable {
    let detail: String
}

private struct APILeaderboardEntry: Decodable {
    let rank: Int
    let userId: Int
    let userName: String?
    let totalScore: Double
    enum CodingKeys: String, CodingKey {
        case rank
        case userId      = "user_id"
        case userName    = "user_name"
        case totalScore  = "total_score"
    }
}

private struct APISessionOut: Decodable {
    let id: Int
    let userId: Int
    let buildingId: Int?
    let startedAt: String
    let endedAt: String?
    let duration: Double
    let finalScore: Double?
    enum CodingKeys: String, CodingKey {
        case id, duration
        case userId     = "user_id"
        case buildingId = "building_id"
        case startedAt  = "started_at"
        case endedAt    = "ended_at"
        case finalScore = "final_score"
    }
}

private struct APIFocusLevelOut: Decodable {
    let id: Int
    let sessionId: Int
    let level: Double
    let timestamp: String
    enum CodingKeys: String, CodingKey {
        case id, level, timestamp
        case sessionId = "session_id"
    }
}

private struct APICheckInResult: Decodable {
    let passed: Bool
    let feedback: String
    let scoreDelta: Double
    enum CodingKeys: String, CodingKey {
        case passed, feedback
        case scoreDelta = "score_delta"
    }
}

private struct APISessionHistoryEntry: Decodable {
    let id: Int
    let userId: Int
    let buildingId: Int?
    let startedAt: String
    let endedAt: String?
    let finalScore: Double?
    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case buildingId = "building_id"
        case startedAt  = "started_at"
        case endedAt    = "ended_at"
        case finalScore = "final_score"
    }
}

private struct APIProfileOut: Decodable {
    let id: Int
    let name: String?
    let school: String?
    let major: String?
    let year: String?
    let expectedGraduation: String?
    let gender: String?
    enum CodingKeys: String, CodingKey {
        case id, name, school, major, year, gender
        case expectedGraduation = "expected_graduation"
    }
}

private struct APIUserMe: Decodable {
    let id: Int
    let nullifierHash: String
    let name: String?
    let school: String?
    let major: String?
    let year: String?
    let expectedGraduation: String?
    let gender: String?
    let sessionCount: Int
    let totalMinutes: Double
    let avgFocusScore: Double
    let totalScore: Double
    let weeklyScore: Double
    let kingBuildingIds: [Int]
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id, name, school, major, year, gender
        case createdAt           = "created_at"
        case nullifierHash       = "nullifier_hash"
        case expectedGraduation  = "expected_graduation"
        case sessionCount        = "session_count"
        case totalMinutes        = "total_minutes"
        case avgFocusScore       = "avg_focus_score"
        case totalScore          = "total_score"
        case weeklyScore         = "weekly_score"
        case kingBuildingIds     = "king_building_ids"
    }
}

private struct APIWeeklyScoreOut: Decodable {
    let month: Int
    let week: Int
    let weeklyScore: Double
    enum CodingKeys: String, CodingKey {
        case month, week
        case weeklyScore = "weekly_score"
    }
}
