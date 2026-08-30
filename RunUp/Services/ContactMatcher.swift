import Contacts
import CryptoKit
import Foundation

/// Lit le carnet d'adresses et n'en fait sortir que des empreintes.
///
/// Un carnet d'adresses est la donnée la plus sensible qu'une app puisse demander : il contient les
/// relations de quelqu'un, et pas seulement les siennes — les gens qui y figurent n'ont jamais rien
/// accepté. Rien de tout ça ne doit quitter le téléphone.
///
/// Ce qui sort d'ici, ce sont des SHA-256 d'adresses e-mail normalisées, et rien d'autre : ni nom,
/// ni numéro, ni adresse en clair. Le serveur compare des empreintes à des empreintes
/// (`users.email_sha256`, une colonne générée par Postgres), ne peut pas remonter d'une empreinte à
/// l'adresse qui l'a produite, et ne conserve rien de ce qu'on lui envoie. Une empreinte qui ne
/// correspond à personne ne laisse aucune trace nulle part.
///
/// Les numéros de téléphone ne sont pas lus, et pas par oubli : aucun compte n'en porte, donc les
/// hacher ne servirait qu'à faire sortir davantage du carnet pour zéro correspondance.
enum ContactMatcher {

    enum Failure: Error {
        /// L'autorisation a été refusée. Il n'y a plus rien à demander : iOS ne repose pas la
        /// question, c'est aux Réglages de reprendre la main.
        case denied
        case unavailable
    }

    static var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Demande l'accès si personne ne l'a encore fait, puis rend les empreintes des adresses.
    ///
    /// Plafonné à mille : c'est ce que le serveur accepte par appel, et au-delà on transmettrait
    /// surtout du bruit — un carnet de plusieurs milliers d'entrées contient des listes de diffusion
    /// et des adresses professionnelles qui n'ont jamais eu de compte ici.
    static func emailHashes(limit: Int = 1000) async throws -> [String] {
        let store = CNContactStore()

        switch authorizationStatus {
        case .notDetermined:
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else { throw Failure.denied }
        case .denied, .restricted:
            throw Failure.denied
        default:
            break
        }

        let keys = [CNContactEmailAddressesKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var hashes = Set<String>()

        try store.enumerateContacts(with: request) { contact, stop in
            for email in contact.emailAddresses {
                if let hash = hash(email: email.value as String) {
                    hashes.insert(hash)
                    if hashes.count >= limit { stop.pointee = true; return }
                }
            }
        }
        return Array(hashes)
    }

    /// L'empreinte d'une adresse, normalisée exactement comme la colonne générée côté Postgres :
    /// minuscules, espaces de bord retirés. Toute divergence entre les deux normalisations ferait
    /// silencieusement rater des correspondances — c'est le genre de panne qui ne lève aucune
    /// erreur et qu'on ne remarque qu'en se demandant pourquoi personne n'est jamais trouvé.
    static func hash(email: String) -> String? {
        let normalised = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalised.contains("@"), let data = normalised.data(using: .utf8) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
