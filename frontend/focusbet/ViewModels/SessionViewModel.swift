import Foundation

@Observable
@MainActor
class SessionViewModel {
    var isActive         = false
    var remainingSeconds = 0
    var scores           = FocusScoreData(screenCapture: 0, motionDetection: 0)
    var buildingId       = ""
    var duration         = 0

    // Optional engagement data from EngagementScoreAI pipeline
    var engagementScores: [Double]?
    var avgEngagement: Double?
    var studyPct: Double?
    var distractionCount: Int?

    // TRIBE v2 analysis state
    private(set) var tribeAnalysis = TribeAnalysisService()
    private(set) var sessionSummary: SessionSummary?
    var encodingType: EncodingType { tribeAnalysis.encodingType }
    var contentLabel: String { tribeAnalysis.contentLabel }
    var contentReason: String { tribeAnalysis.contentReason }
    var tribeStatusMessage: String { tribeAnalysis.statusMessage }
    var tribeClipCount: Int { tribeAnalysis.clips.count }

    private(set) var sessionId: Int?

    private var sessionStartTask: Task<Void, Never>?
    private var focusPostingTask: Task<Void, Never>?
    private var screenCaptureService: ScreenCaptureService?
    private var focusTrackingService: FocusTrackingService?
    private let lstm = LSTMService()

    // MARK: - Computed

    var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var focusScore: Int { scores.focusLevel }

    var sessionScore: Int {
        FocusScoreData.sessionScore(focusLevel: scores.focusLevel, durationMinutes: duration)
    }

    // MARK: - Session lifecycle

    func startSession(
        duration: Int,
        buildingId: String,
        focusTracking: FocusTrackingService,
        screenCapture: ScreenCaptureService
    ) {
        self.duration             = duration
        self.buildingId           = buildingId
        self.remainingSeconds     = duration * 60
        self.isActive             = true
        self.scores               = FocusScoreData(screenCapture: 85, motionDetection: 85)
        self.focusTrackingService = focusTracking
        self.screenCaptureService = screenCapture
        self.sessionSummary       = nil

        // Request permissions, then start monitoring and TRIBE v2 recording
        Task {
            await PermissionService.shared.requestAllPermissions()
            screenCapture.startMonitoring(focusTrackingService: focusTracking)
            focusTracking.startTracking()

            // Start TRIBE v2 screen recording + analysis loop (after permissions granted)
            tribeAnalysis.startAnalysis(
                sessionIdProvider: { [weak self] in self?.sessionId },
                screenCapture: screenCapture,
                focusTracking: focusTracking
            )
        }

        // Start LSTM engagement scoring session
        lstm.reset()
        Task { await lstm.startSession(contentType: "studying") }

        print("[SessionViewModel] startSession — duration:\(duration) building:\(buildingId)")
        sessionStartTask = Task {
            do {
                let sid = try await APIService.shared.startSoloSession(
                    durationMinutes: duration,
                    buildingSlug: buildingId.isEmpty ? nil : buildingId
                )
                sessionId = sid
                startPeriodicFocusPosting()
                print("[SessionViewModel] Session started: id=\(sid)")
            } catch {
                print("[SessionViewModel] startSoloSession error: \(error.localizedDescription)")
            }
        }
    }

    func endSession() {
        isActive = false
        focusPostingTask?.cancel()
        focusPostingTask = nil
        screenCaptureService?.stopMonitoring()
        focusTrackingService?.stopTracking()
        screenCaptureService = nil
        focusTrackingService = nil

        // Stop the timer and recorder — no new captures will start
        tribeAnalysis.stopAnalysis()

        // Prepare result store with loading state (ResultView shows spinner)
        let resultStore = SessionResultStore.shared
        resultStore.clear()
        resultStore.isFetchingFeedback = true

        let startTask = sessionStartTask
        sessionStartTask = nil

        // All remaining work happens async — ResultView shows loading until ready
        Task {
            // 1. Wait for any in-progress TRIBE clip analysis to finish
            print("[SessionViewModel] Waiting for in-progress analysis to complete...")
            var waited = 0
            while tribeAnalysis.isAnalyzing && waited < 120 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                waited += 1
            }
            print("[SessionViewModel] Analysis done — \(tribeAnalysis.clips.count) clips collected (waited \(waited * 500)ms)")

            // 2. Stop LSTM and fetch engagement export
            _ = await lstm.stopSession()

            // 3. Build session summary with real engagement scores
            let summary = tribeAnalysis.buildSummary(lstm: lstm)
            sessionSummary = summary

            // 4. Populate engagement data
            if !summary.clips.isEmpty {
                engagementScores = summary.clips.map(\.engagement)
                avgEngagement = summary.averageEngagement
                studyPct = summary.studyingFraction * 100
                distractionCount = summary.distractionCount
            }

            // 5. End session on backend — wait for start to finish first
            await startTask?.value
            var finalScore: Double = summary.sessionScore
            if let sid = sessionId {
                await postFocusLevel(sessionId: sid)
                do {
                    finalScore = try await APIService.shared.endSession(
                        engagementScores: engagementScores,
                        avgEngagement: avgEngagement,
                        studyPct: studyPct,
                        distractionCount: distractionCount
                    )
                    print("[SessionViewModel] Session \(sid) ended — final score: \(finalScore)")
                    NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
                } catch {
                    print("[SessionViewModel] endSession error: \(error.localizedDescription)")
                }
            }

            // 6. Now populate result store — this makes ResultView transition from loading to content
            resultStore.finalScore = finalScore
            resultStore.summary = summary
            print("[SessionViewModel] ResultStore populated — \(summary.clips.count) clips, score=\(finalScore)")

            // 7. Fetch Claude feedback AFTER summary is fully built
            if !summary.clips.isEmpty {
                await fetchClaudeFeedback(summary: summary)
            } else {
                resultStore.claudeFeedback = "No clips were recorded during this session."
                resultStore.isFetchingFeedback = false
            }
        }
    }

    // MARK: - Claude Feedback

    private func fetchClaudeFeedback(summary: SessionSummary) async {
        let resultStore = SessionResultStore.shared
        let serverURL = tribeAnalysis.serverURL

        guard let url = URL(string: "\(serverURL)/report") else {
            resultStore.isFetchingFeedback = false
            return
        }

        struct ClipPayload: Encodable {
            let timestamp: String
            let focus_score: Double
            let engagement: Double
            let gate: Double
            let encoding_type: String
            let content_label: String
            let content_reason: String
            let pfc: Double
            let dmn: Double
            let lang: Double
        }

        struct ReportPayload: Encodable {
            let duration_minutes: Double
            let clips: [ClipPayload]
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let clipsData = summary.clips.map { clip in
            ClipPayload(
                timestamp: formatter.string(from: clip.timestamp),
                focus_score: clip.focusScore,
                engagement: clip.engagement,
                gate: clip.gate,
                encoding_type: clip.encodingType.rawValue,
                content_label: clip.contentLabel,
                content_reason: clip.contentReason,
                pfc: clip.pfc, dmn: clip.dmn, lang: clip.lang
            )
        }

        let payload = ReportPayload(
            duration_minutes: summary.durationMinutes,
            clips: clipsData
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
            request.timeoutInterval = 60

            let (data, _) = try await URLSession.shared.data(for: request)

            struct ReportResponse: Decodable {
                let feedback: String?
                let error: String?
            }
            let result = try JSONDecoder().decode(ReportResponse.self, from: data)
            resultStore.claudeFeedback = result.feedback ?? result.error ?? "No feedback returned"
            print("[SessionViewModel] Claude feedback received")
        } catch {
            resultStore.claudeFeedback = "Feedback unavailable: \(error.localizedDescription)"
            print("[SessionViewModel] Claude feedback error: \(error)")
        }
        resultStore.isFetchingFeedback = false
    }

    // MARK: - Score updates (called by SessionView timer)

    func updateScores(from data: FocusScoreData) {
        scores = data
    }

    // MARK: - Check-in

    func postCheckInSnapshot() {
        guard let sid = sessionId else {
            print("[SessionViewModel] postCheckInSnapshot: no sessionId yet")
            return
        }
        Task { await postFocusLevel(sessionId: sid) }
    }

    // MARK: - Private

    private func startPeriodicFocusPosting() {
        focusPostingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled, let sid = self.sessionId else { break }
                await self.postFocusLevel(sessionId: sid)
            }
        }
    }

    private func postFocusLevel(sessionId: Int) async {
        let level = Double(scores.focusLevel) / 100.0
        do {
            try await APIService.shared.postFocusLevel(sessionId: sessionId, level: level)
        } catch {
            print("[SessionViewModel] postFocusLevel error: \(error.localizedDescription)")
        }
    }
}
