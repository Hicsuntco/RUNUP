import Foundation
import Security

/// Minimal Keychain wrapper for the one secret this app now stores: the signed-in user's session
/// token (see `AuthService`). Re-added for the real backend — an earlier version of this file,
/// holding a user-supplied Anthropic API key, was deleted when the coach moved behind a server
/// proxy; this one has nothing to do with that and isn't a revival of it.
enum KeychainService {
    private static let service = "com.hicsuntco.runup.session"
    private static let account = "sessionToken"

    static func saveToken(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(token.utf8)
        // `ThisDeviceOnly` EXCLUT LE JETON DES SAUVEGARDES. Sans classe d'accessibilité, l'élément
        // prend `WhenUnlocked` : il part dans les sauvegardes chiffrées iTunes/Finder et se
        // restaure sur un AUTRE appareil. Une sauvegarde récupérée — ordinateur familial, partagé,
        // revendu — plus son mot de passe rend un jeton porteur valable trente jours, sans second
        // facteur : lecture et publication d'activités, itinéraires, amis, suppression du compte.
        // Elle n'en saurait rien, et la liste des jetons révoqués ne se remplit que si ELLE se
        // déconnecte.
        //
        // `AfterFirstUnlock` plutôt que `WhenUnlocked` : les notifications et l'envoi différé
        // doivent pouvoir lire le jeton écran verrouillé.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func loadToken() -> String? {
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

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
