import Foundation
import Security

/// Minimal Keychain wrapper for the user-supplied Anthropic API key (see Profile → Réglages).
/// v1 stores the key entered by the user rather than a bundled/server-side key — see IOS_SETUP.md
/// for why, and how to swap in a backend proxy later without touching call sites (`CoachService`
/// is the only consumer).
enum KeychainService {
    private static let service = "com.hicsuntco.runup.anthropic"
    private static let account = "api-key"

    static func saveAPIKey(_ key: String) {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !key.isEmpty else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clearAPIKey() {
        saveAPIKey("")
    }
}
