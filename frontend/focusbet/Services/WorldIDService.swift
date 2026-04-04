import Foundation

// MARK: - Errors

enum WorldIDError: LocalizedError {
    case proofGenerationCancelled
    case proofGenerationFailed(String)
    case backendVerificationFailed(String)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .proofGenerationCancelled:
            return "World ID verification was cancelled."
        case .proofGenerationFailed(let msg):
            return "Proof generation failed: \(msg)"
        case .backendVerificationFailed(let msg):
            return "Verification rejected: \(msg)"
        case .invalidResponse:
            return "Unexpected response from server."
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}

// MARK: - Service

/// Handles the full World ID verification flow:
///   1. Generate a ZK proof via IDKit (QR/deeplink to World App)
///   2. POST proof to the backend /auth/verify-world-id
///   3. Return the JWT access_token on success
@MainActor
final class WorldIDService {
    static let shared = WorldIDService()
    private init() {}

    private let backendURL = "http://127.0.0.1:8000"
    private let action    = "focus_session"

    // MARK: - Public

    /// Runs the full flow and returns a JWT on success.
    func requestVerification() async throws -> String {
        let proof = try await generateProof()
        return try await verifyWithBackend(proof: proof)
    }

    // MARK: - Step 1: Proof generation

    private func generateProof() async throws -> WorldIDProofResult {
        // ── IDKit Integration ─────────────────────────────────────────────
        //
        // After adding the idkit-swift package via Xcode → File → Add Package
        // Dependencies → https://github.com/worldcoin/idkit-swift
        //
        // Replace this entire function body with the real IDKit call, e.g.:
        //
        //   import IDKit
        //
        //   return try await withCheckedThrowingContinuation { continuation in
        //       IDKit.launchVerification(
        //           app_id: appID,
        //           action: action,
        //           signal: "",
        //           credential_types: [.orb, .device]
        //       ) { result in
        //           switch result {
        //           case .success(let proof):
        //               continuation.resume(returning: WorldIDProofResult(
        //                   nullifierHash:     proof.nullifier_hash,
        //                   merkleRoot:        proof.merkle_root,
        //                   proof:             proof.proof,
        //                   verificationLevel: proof.credential_type.rawValue
        //               ))
        //           case .failure(let err):
        //               continuation.resume(throwing: WorldIDError.proofGenerationFailed(err.localizedDescription))
        //           }
        //       }
        //   }
        //
        // ─────────────────────────────────────────────────────────────────
        //
        // DEV STUB: Backend auth.py accepts any nullifier_hash starting with
        // "test_" in dev mode (WORLD_ID_APP_ID unset or "dev"). This lets the
        // full auth flow run end-to-end without a real World App or IDKit SDK.

        let testHash = "test_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        return WorldIDProofResult(
            nullifierHash:     testHash,
            merkleRoot:        "0x" + String(repeating: "a", count: 64),
            proof:             "0x" + String(repeating: "b", count: 128),
            verificationLevel: "device"
        )
    }

    // MARK: - Step 2: Backend verification

    private func verifyWithBackend(proof: WorldIDProofResult) async throws -> String {
        guard let url = URL(string: "\(backendURL)/auth/verify-world-id") else {
            throw WorldIDError.invalidResponse
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "nullifier_hash":     proof.nullifierHash,
            "merkle_root":        proof.merkleRoot,
            "proof":              proof.proof,
            "verification_level": proof.verificationLevel,
            "action":             action,
            "signal":             ""
        ]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw WorldIDError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw WorldIDError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let detail = (try? JSONDecoder().decode(BackendError.self, from: data))?.detail
                ?? "HTTP \(http.statusCode)"
            throw WorldIDError.backendVerificationFailed(detail)
        }

        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard decoded.success, let token = decoded.data?.accessToken else {
            throw WorldIDError.invalidResponse
        }
        return token
    }
}

// MARK: - Private response models

private struct WorldIDProofResult {
    let nullifierHash:     String
    let merkleRoot:        String
    let proof:             String
    let verificationLevel: String
}

private struct AuthResponse: Decodable {
    let success: Bool
    let data: TokenData?

    struct TokenData: Decodable {
        let accessToken: String
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }
}

private struct BackendError: Decodable {
    let detail: String
}
