import Foundation

/// Client for the LSTM engagement scoring backend at localhost:8000.
/// Manages session lifecycle and reads engagement scores from exported CSVs.
class LSTMService {
    let baseURL = "http://localhost:8000"
    private var sessionId: Int?

    func startSession(contentType: String = "studying") async {
        guard let url = URL(string: "\(baseURL)/sessions/start") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "content_type": contentType,
            "external_session_id": "focusbet_\(Int(Date().timeIntervalSince1970))"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["session_id"] as? Int {
                sessionId = id
                print("[lstm] Session started — id=\(id)")
            }
        } catch {
            print("[lstm] Failed to start: \(error)")
        }
    }

    func stopSession() async -> String? {
        guard let id = sessionId,
              let url = URL(string: "\(baseURL)/sessions/\(id)/stop") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let path = json["csv_export"] as? String {
                print("[lstm] Session \(id) stopped — export: \(path)")
                sessionId = nil
                return path
            }
        } catch {
            print("[lstm] Stop failed: \(error)")
        }
        sessionId = nil
        return nil
    }

    /// Reads engagement scores from a CSV file exported by the LSTM pipeline.
    func readScores(from csvPath: String) -> [Double] {
        let expanded = (csvPath as NSString).expandingTildeInPath
        guard let content = try? String(contentsOfFile: expanded, encoding: .utf8) else {
            print("[lstm] Could not read CSV at: \(expanded)")
            return []
        }
        var scores: [Double] = []
        for line in content.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
            let cleaned = line.replacingOccurrences(of: "\"", with: "")
            let parts = cleaned.components(separatedBy: ",")
            if parts.first?.trimmingCharacters(in: .whitespaces).lowercased() == "scores" {
                for part in parts.dropFirst() {
                    if let v = Double(part.trimmingCharacters(in: .whitespaces)) { scores.append(v) }
                }
                continue
            }
            for part in parts {
                if let v = Double(part.trimmingCharacters(in: .whitespaces)) { scores.append(v) }
            }
        }
        print("[lstm] Read \(scores.count) scores from CSV")
        return scores
    }

    func engagementForClip(index: Int, scores: [Double]) -> Double {
        guard !scores.isEmpty else { return 65.0 }
        return scores[min(index, scores.count - 1)]
    }

    /// Finds the most recently created CSV in the EngagementScoreAI exports folder.
    func findLatestCSV() -> String? {
        let exportsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("knockknock/EngagementScoreAI/exports")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: exportsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            print("[lstm] Exports dir not found: \(exportsDir.path)")
            return nil
        }
        let csvFiles = files.filter { $0.pathExtension == "csv" }
        let latest = csvFiles.max(by: { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return aDate < bDate
        })
        return latest?.path
    }

    func reset() { sessionId = nil }
}
