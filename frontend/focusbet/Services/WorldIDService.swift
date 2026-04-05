import Foundation

// MARK: - Errors

enum WorldIDError: LocalizedError {
    case idKitNotAvailable
    case invalidProofFormat
    case proofGenerationFailed(String)
    case backendVerificationFailed(String)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .idKitNotAvailable:               return "World ID SDK is not available in this build."
        case .invalidProofFormat:              return "World ID proof format is not supported."
        case .proofGenerationFailed(let msg):   return "Proof generation failed: \(msg)"
        case .backendVerificationFailed(let msg): return "Verification rejected: \(msg)"
        case .invalidResponse:                  return "Unexpected response from server."
        case .networkError(let err):            return "Network error: \(err.localizedDescription)"
        }
    }
}

// MARK: - Service

/// Handles World ID verification.
///
/// **Production** — real World App QR code flow via IDKit:
///   1. Fetch rpContext  from  GET /auth/create-session
///   2. IDKit generates a connectorURL → display as QR code
///   3. User scans with World App → proof arrives via polling
///   4. POST proof to  POST /auth/verify-world-id → JWT
///
/// **Dev** — instant stub, no World App needed:
///   Sends a test_ nullifier hash that the backend accepts when
///   WORLD_ID_APP_ID is unset or the hash starts with "test_".
///
/// To enable production:
///   1. Xcode → File → Add Package Dependencies
///      https://github.com/worldcoin/idkit-swift
///   2. Uncomment `import IDKit` below and the IDKit block in requestVerification()
///   3. Set WORLD_ID_PRIVATE_KEY in backend/.env (from Worldcoin Developer Portal)
///


#if IDKIT_ENABLED
import IDKit
#endif

@MainActor
final class WorldIDService {
    static let shared = WorldIDService()
    private init() {}

    private let backendURL = "http://35.206.125.242:8080"
    private let action     = "focus_session"

    // MARK: - Public

    func requestVerification(
        mode: LoginMode,
        onConnectorURL: ((URL?) -> Void)? = nil
    ) async throws -> String {
        switch mode {
        case .dev:
            return try await verifyWithBackend(proof: makeDevProof())

        case .worldID:
#if IDKIT_ENABLED
            let session = try await fetchSession()

            let rpContext = try RpContext(
                rpId:      session.rpId,
                nonce:     session.nonce,
                createdAt: UInt64(session.createdAt),
                expiresAt: UInt64(session.expiresAt),
                signature: session.signature
            )
            let config = IDKitRequestConfig(
                appId:                 session.appId,
                action:                action,
                rpContext:             rpContext,
                actionDescription:     nil,
                bridgeUrl:             nil,
                allowLegacyProofs:     true,
                overrideConnectBaseUrl: nil,
                returnTo:              nil,
                environment:           nil,
                connectUrlMode:        nil
            )
            let request = try IDKit.request(config: config).preset(orbLegacy())
            onConnectorURL?(request.connectorURL)

            let completion = await request.pollUntilCompletion()
            onConnectorURL?(nil)

            switch completion {
            case .success(let result):
                guard let firstResponse = result.responses.first else {
                    throw WorldIDError.invalidProofFormat
                }

                let nullifierHash: String
                let merkleRoot: String
                let proofHex: String
                let levelString: String

                switch firstResponse {
                case .v3(_, _, let proof, let root, let nullifier):
                    nullifierHash = nullifier
                    merkleRoot = root
                    proofHex = proof
                    levelString = "orb"
                case .v4:
                    throw WorldIDError.invalidProofFormat
                case .session:
                    throw WorldIDError.invalidProofFormat
                }

                let proof = WorldIDProofPayload(
                    nullifierHash:     nullifierHash,
                    merkleRoot:        merkleRoot,
                    proof:             proofHex,
                    verificationLevel: levelString,
                    action:            action,
                    signal:            ""
                )
                return try await verifyWithBackend(proof: proof)
            case .failure(let error):
                throw WorldIDError.proofGenerationFailed(error.rawValue)
            }
#else
            throw WorldIDError.idKitNotAvailable
#endif
        }
    }

    // MARK: - Backend

    func fetchSession() async throws -> SessionConfig {
        guard let url = URL(string: "\(backendURL)/auth/create-session") else {
            throw WorldIDError.invalidResponse
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let wrapper   = try JSONDecoder().decode(SessionConfigResponse.self, from: data)
        return wrapper.data
    }

    private func verifyWithBackend(proof: WorldIDProofPayload) async throws -> String {
        guard let url = URL(string: "\(backendURL)/auth/verify-world-id") else {
            throw WorldIDError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody   = try JSONEncoder().encode(proof)

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: req) }
        catch { throw WorldIDError.networkError(error) }

        guard let http = response as? HTTPURLResponse else { throw WorldIDError.invalidResponse }
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

    // MARK: - Dev stub

    private func makeDevProof() -> WorldIDProofPayload {
        let hash = "test_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        return WorldIDProofPayload(
            nullifierHash:     hash,
            merkleRoot:        "0x" + String(repeating: "a", count: 64),
            proof:             "0x" + String(repeating: "b", count: 128),
            verificationLevel: "device",
            action:            action,
            signal:            ""
        )
    }
}

// MARK: - Login mode

enum LoginMode {
    case worldID   // real QR code flow via World App
    case dev       // instant stub for development
}

// MARK: - Models

struct SessionConfig: Decodable {
    let appId:     String
    let rpId:      String
    let nonce:     String
    let createdAt: Int
    let expiresAt: Int
    let signature: String

    enum CodingKeys: String, CodingKey {
        case appId = "app_id", rpId = "rp_id"
        case nonce, createdAt = "created_at", expiresAt = "expires_at", signature
    }
}

private struct SessionConfigResponse: Decodable {
    let success: Bool
    let data:    SessionConfig
}

private struct WorldIDProofPayload: Encodable {
    let nullifierHash:     String
    let merkleRoot:        String
    let proof:             String
    let verificationLevel: String
    var action:            String?
    var signal:            String?

    enum CodingKeys: String, CodingKey {
        case nullifierHash = "nullifier_hash", merkleRoot = "merkle_root"
        case proof, verificationLevel = "verification_level", action, signal
    }
}

private struct AuthResponse: Decodable {
    let success: Bool
    let data:    TokenData?
    struct TokenData: Decodable {
        let accessToken: String
        enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
    }
}

private struct BackendError: Decodable { let detail: String }
