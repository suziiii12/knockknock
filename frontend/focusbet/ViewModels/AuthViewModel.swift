import Foundation
import Security

// MARK: - Notification

extension Notification.Name {
    static let authTokenExpired = Notification.Name("com.focusbet.authTokenExpired")
    static let sessionDidEnd     = Notification.Name("com.focusbet.sessionDidEnd")
}

// MARK: - Keychain error

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    var errorDescription: String? {
        if case .saveFailed(let s) = self { return "Keychain save failed (OSStatus \(s))" }
        return nil
    }
}

// MARK: - AuthViewModel

@Observable
@MainActor
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading       = false
    var errorMessage:  String?
    var currentUserId: String?
    var connectorURL:  URL?    // set by WorldIDService during QR code flow

    private let keychainService = "com.focusbet.auth"
    private let keychainAccount = "jwt_token"

    init() {
        // Listen for 401 responses posted by APIService and auto-logout
        Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .authTokenExpired) {
                self?.logout()
            }
        }
    }

    // MARK: - Public interface

    /// Triggers the IDKit World ID proof flow, verifies with backend, and
    /// stores the returned JWT in Keychain.
    func triggerWorldIDFlow(mode: LoginMode = .worldID) async {
        guard !isLoading else { return }
        isLoading     = true
        errorMessage  = nil
        connectorURL  = nil

        do {
            let token = try await WorldIDService.shared.requestVerification(
                mode: mode,
                onConnectorURL: { [weak self] url in self?.connectorURL = url }
            )
            connectorURL = nil
            try saveToKeychain(token)
            currentUserId   = extractUserId(from: token)
            await APIService.shared.setToken(token)
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            isAuthenticated = true
        } catch {
            connectorURL = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Called on app launch. Reads the Keychain JWT and restores auth state
    /// without requiring the user to re-verify if the token is still valid.
    func restoreAuthState() {
        guard let token = loadFromKeychain() else {
            // No token — make sure UserDefaults is consistent
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            return
        }
        guard !isTokenExpired(token) else {
            clearKeychain()
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            return
        }
        currentUserId = extractUserId(from: token)
        Task { await APIService.shared.setToken(token) }
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "isProfileComplete")
        isAuthenticated = true
    }

    /// Clears all auth state and returns the user to the Welcome screen.
    func logout() {
        clearKeychain()
        currentUserId   = nil
        errorMessage    = nil
        isAuthenticated = false
        Task { await APIService.shared.clearToken() }
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.set(false, forKey: "isProfileComplete")
    }

    // MARK: - Keychain

    private func saveToKeychain(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { return }

        let base: [String: Any] = [
            kSecClass      as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        // Delete any stale item first (update-or-insert pattern)
        SecItemDelete(base as CFDictionary)

        var attrs = base
        attrs[kSecValueData as String] = data
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService  as String: keychainService,
            kSecAttrAccount  as String: keychainAccount,
            kSecReturnData   as String: true,
            kSecMatchLimit   as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data  = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    private func clearKeychain() {
        let query: [String: Any] = [
            kSecClass      as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - JWT helpers

    /// Decodes the JWT payload (middle segment) and returns the `sub` claim.
    private func extractUserId(from token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1])
        // JWT base64url → base64: replace chars and pad
        b64 = b64.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub  = json["sub"] as? String else { return nil }
        return sub
    }

    /// Returns true if the JWT `exp` claim is in the past.
    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return true }
        var b64 = String(parts[1])
        b64 = b64.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp  = json["exp"] as? TimeInterval else { return true }
        return Date().timeIntervalSince1970 >= exp
    }
}
