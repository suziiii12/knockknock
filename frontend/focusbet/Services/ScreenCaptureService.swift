import AppKit

/// Monitors the frontmost application every 5 seconds to compute a tab-focus score.
///
/// Score definition:
///   100 — A study/productivity app is active (Xcode, Safari, Notes, etc.)
///    40 — A neutral app is active (Finder, System Preferences, etc.)
///     0 — A distraction app is active (YouTube, TikTok, Messages, Discord, etc.)
///
/// The computed score is published via `tabScore` and forwarded to FocusTrackingService.
@Observable
final class ScreenCaptureService {

    private(set) var tabScore:     Int    = 100
    private(set) var activeAppName: String = ""

    private var monitorTask: Task<Void, Never>?
    private var isMonitoring = false

    // MARK: - App classification

    private static let studyApps: Set<String> = [
        "Xcode", "Code", "Visual Studio Code", "Safari", "Notes", "Terminal",
        "Preview", "Pages", "Notion", "Obsidian", "TextEdit", "Numbers",
        "Keynote", "Word", "Excel", "PowerPoint", "Bear", "Typora",
        "iTerm2", "iTerm", "Ghostty", "Warp", "Zed", "Nova",
        "Simulator", "Instruments", "RStudio", "MATLAB", "Jupyter"
    ]

    private static let distractionApps: Set<String> = [
        "YouTube", "TikTok", "Instagram", "Messages", "Discord",
        "Twitter", "X", "Facebook", "Reddit", "Netflix", "Spotify",
        "Twitch", "Snapchat", "WhatsApp", "Telegram", "Signal",
        "FaceTime", "Game Center", "Steam", "Chess", "Solitaire"
    ]

    // MARK: - Public interface

    func startMonitoring(focusTrackingService: FocusTrackingService) {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitorTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.isMonitoring {
                await self.checkFrontmostApp(focusTrackingService: focusTrackingService)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
    }

    // MARK: - Private

    @MainActor
    private func checkFrontmostApp(focusTrackingService: FocusTrackingService) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let name = app.localizedName else { return }

        activeAppName = name
        let score     = Self.scoreForApp(name: name)
        tabScore      = score
        focusTrackingService.currentScores = FocusScoreData(
            screenCapture: score,
            motionDetection: focusTrackingService.currentScores.motionDetection
        )
    }

    private static func scoreForApp(name: String) -> Int {
        if studyApps.contains(name)      { return 100 }
        if distractionApps.contains(name) { return 0   }
        return 40   // neutral
    }
}
