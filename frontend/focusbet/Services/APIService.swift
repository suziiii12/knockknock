import Foundation

// MARK: - Public result types (used by ViewModels)

struct UserProfile {
    let id: Int
    let sessionCount: Int
    let totalMinutes: Int
    let avgFocusScore: Double
    let totalScore: Double
    let kingBuildingIds: [Int]
}

struct SessionStartResult {
    let sessionId: Int
    let challengeId: Int
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

    private let baseURL = "http://127.0.0.1:8000"
    private var authToken: String?

    // MARK: - Token management

    func setToken(_ token: String) { authToken = token }
    func clearToken()              { authToken = nil }

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
        guard var req = makeRequest(path: path, method: method) else {
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
            return TerritoryEntry(
                id: "t\(entry.rank)",
                userId: String(entry.userId),
                userName: "User #\(entry.userId)",
                userInitials: "#\(entry.userId)",
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
        "walc":   1,
        "hicks":  2,
        "haas":   3,
    ]

    private static let buildingIdToSlug: [Int: String] = Dictionary(
        uniqueKeysWithValues: buildingSlugToId.map { ($1, $0) }
    )

    // MARK: - User profile

    func fetchUserProfile() async throws -> UserProfile {
        let raw = try await fetch(APIUserMe.self, path: "/users/me")
        return UserProfile(
            id: raw.id,
            sessionCount: raw.sessionCount,
            totalMinutes: raw.totalMinutes,
            avgFocusScore: raw.avgFocusScore,
            totalScore: raw.totalScore,
            kingBuildingIds: raw.kingBuildingIds
        )
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
                    buildingScore: score,
                    gazeScore: score,
                    postureScore: score,
                    blinkScore: score,
                    keyMouseScore: score,
                    tabScore: score,
                    checkInScore: score,
                    isComplete: true
                )
            }
        } catch {
            return MockData.sessionHistory
        }
    }

    // MARK: - Sessions

    func startSession(challengeId: Int) async throws -> SessionStartResult {
        let raw = try await fetch(
            APISessionOut.self,
            path: "/sessions/start",
            method: "POST",
            body: ["challenge_id": challengeId]
        )
        return SessionStartResult(sessionId: raw.id, challengeId: raw.challengeId)
    }

    func postScore(sessionId: Int, gazeScore: Double, tabScore: Double, checkinScore: Double) async throws {
        _ = try await fetch(
            APIScoreOut.self,
            path: "/sessions/\(sessionId)/score",
            method: "POST",
            body: [
                "gaze_score":    gazeScore,
                "tab_score":     tabScore,
                "checkin_score": checkinScore,
            ]
        )
    }

    /// Ends the current user's active session. Returns the final composite score.
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
    let totalScore: Double
    enum CodingKeys: String, CodingKey {
        case rank
        case userId      = "user_id"
        case totalScore  = "total_score"
    }
}

private struct APISessionOut: Decodable {
    let id: Int
    let challengeId: Int
    let userId: Int
    let startedAt: String
    let endedAt: String?
    let finalScore: Double?
    enum CodingKeys: String, CodingKey {
        case id, startedAt = "started_at", endedAt = "ended_at", finalScore = "final_score"
        case challengeId = "challenge_id"
        case userId      = "user_id"
    }
}

private struct APIScoreOut: Decodable {
    let id: Int
    let compositeScore: Double
    enum CodingKeys: String, CodingKey {
        case id
        case compositeScore = "composite_score"
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

private struct APIUserMe: Decodable {
    let id: Int
    let nullifierHash: String
    let sessionCount: Int
    let totalMinutes: Int
    let avgFocusScore: Double
    let totalScore: Double
    let kingBuildingIds: [Int]
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id, createdAt = "created_at"
        case nullifierHash   = "nullifier_hash"
        case sessionCount    = "session_count"
        case totalMinutes    = "total_minutes"
        case avgFocusScore   = "avg_focus_score"
        case totalScore      = "total_score"
        case kingBuildingIds = "king_building_ids"
    }
}
