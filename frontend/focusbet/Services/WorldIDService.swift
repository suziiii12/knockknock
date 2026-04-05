import Foundation

// MARK: - Errors

enum WorldIDError: LocalizedError {
    case idKitNotAvailable
    case invalidProofFormat
    case proofGenerationFailed(String)
    case backendVerificationFailed(String)
    case invalidResponse
    case networkError(Error)
    case selfieCheckFailed(String)

    var errorDescription: String? {
        switch self {
        case .idKitNotAvailable:                  return "World ID SDK is not available in this build."
        case .invalidProofFormat:                 return "World ID proof format is not supported."
        case .proofGenerationFailed(let msg):     return "Proof generation failed: \(msg)"
        case .backendVerificationFailed(let msg): return "Verification rejected: \(msg)"
        case .invalidResponse:                    return "Unexpected response from server."
        case .networkError(let err):              return "Network error: \(err.localizedDescription)"
        case .selfieCheckFailed(let msg):         return "Selfie check failed: \(msg)"
        }
    }
}

// MARK: - Service

#if IDKIT_ENABLED
import IDKit
#endif

@MainActor
final class WorldIDService {
    static let shared = WorldIDService()
    private init() {}

    private let backendURL = AppConfig.backendURL
    private let loginAction   = "focus_session"
    private let selfieAction  = "session_verify"

    // MARK: - Login verification (Orb)

    func requestVerification(
        mode: LoginMode,
        onConnectorURL: ((URL?) -> Void)? = nil
    ) async throws -> String {
        switch mode {
        case .dev:
            return try await verifyWithBackend(proof: makeDevProof())

        case .worldID:
#if IDKIT_ENABLED
            let result = try await performIDKitFlow(
                action: loginAction,
                presetFactory: { config in try IDKit.request(config: config).preset(orbLegacy()) },
                onConnectorURL: onConnectorURL
            )
            return try await verifyWithBackend(proof: result)
#else
            throw WorldIDError.idKitNotAvailable
#endif
        }
    }

    // MARK: - Selfie Check (session-start continuity)

    func requestSelfieVerification(
        authToken: String,
        onConnectorURL: ((URL?) -> Void)? = nil
    ) async throws -> Bool {
#if IDKIT_ENABLED
        let result = try await performIDKitFlow(
            action: selfieAction,
            presetFactory: { config in try IDKit.request(config: config).preset(selfieCheckLegacy()) },
            onConnectorURL: onConnectorURL
        )
        return try await verifySelfieWithBackend(proof: result, authToken: authToken)
#else
        throw WorldIDError.idKitNotAvailable
#endif
    }

    // MARK: - IDKit shared flow

#if IDKIT_ENABLED
    private func performIDKitFlow(
        action: String,
        presetFactory: (IDKitRequestConfig) throws -> IDKitRequest,
        onConnectorURL: ((URL?) -> Void)?
    ) async throws -> Data {
        let session = try await fetchSession(action: action)

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
        let request = try presetFactory(config)
        onConnectorURL?(request.connectorURL)

        let completion = await request.pollUntilCompletion()
        onConnectorURL?(nil)

        switch completion {
        case .success(let result):
            return try JSONEncoder().encode(result)
        case .failure(let error):
            throw WorldIDError.proofGenerationFailed(error.rawValue)
        }
    }
#endif

    // MARK: - Backend calls

    func fetchSession(action: String? = nil) async throws -> SessionConfig {
        var urlString = "\(backendURL)/auth/create-session"
        if let action {
            urlString += "?action=\(action)"
        }
        guard let url = URL(string: urlString) else {
            throw WorldIDError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WorldIDError.invalidResponse
        }

        let wrapper = try JSONDecoder().decode(SessionConfigResponse.self, from: data)
        return wrapper.data
    }

    private func verifyWithBackend(proof: WorldIDProofPayload) async throws -> String {
        guard let url = URL(string: "\(backendURL)/auth/verify-world-id") else {
            throw WorldIDError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(proof)

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

    private func verifyWithBackend(proof: Data) async throws -> String {
        guard let url = URL(string: "\(backendURL)/auth/verify-world-id") else {
            throw WorldIDError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = proof

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

    private func verifySelfieWithBackend(proof: Data, authToken: String) async throws -> Bool {
        guard let url = URL(string: "\(backendURL)/auth/verify-selfie") else {
            throw WorldIDError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = proof

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: req) }
        catch { throw WorldIDError.networkError(error) }

        guard let http = response as? HTTPURLResponse else { throw WorldIDError.invalidResponse }
        guard http.statusCode == 200 else {
            let detail = (try? JSONDecoder().decode(BackendError.self, from: data))?.detail
                ?? "HTTP \(http.statusCode)"
            throw WorldIDError.selfieCheckFailed(detail)
        }

        let decoded = try JSONDecoder().decode(SelfieResponse.self, from: data)
        return decoded.success && (decoded.data?.verified == true)
    }

    // MARK: - Dev stub

    private func makeDevProof() -> WorldIDProofPayload {
        let hash = "test_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        return WorldIDProofPayload(
            nullifierHash:     hash,
            merkleRoot:        "0x" + String(repeating: "a", count: 64),
            proof:             "0x" + String(repeating: "b", count: 128),
            verificationLevel: "device",
            action:            loginAction,
            signal:            ""
        )
    }
}

// MARK: - Login mode

enum LoginMode {
    case worldID
    case dev
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

private struct SelfieResponse: Decodable {
    let success: Bool
    let data:    SelfieData?
    struct SelfieData: Decodable {
        let verified: Bool
    }
}

private struct BackendError: Decodable { let detail: String }
