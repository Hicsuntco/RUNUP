import Foundation
import Observation

/// The signed-in user's identity as the server sees it — `xpTotal` is the account's real,
/// server-side XP total (see `api/me.js`), the source of truth for the Club leaderboard once
/// signed in (as opposed to `UserProfile.xp`, which stays purely local for the app's own
/// gamification UI outside Club).
struct AuthenticatedUser: Codable, Equatable {
    var id: String
    var name: String
    var xpTotal: Int
    /// This account's own shareable code (see `api/auth/[action].js`) — nil only in the brief
    /// window before the very first sign-in response comes back, or for very old accounts on a
    /// backend that hasn't run the referral migration yet.
    var referralCode: String?
    /// Nil until she sets one (`ClubService.updateProfile`) or Apple provided it at first sign-in
    /// — neither signup nor onboarding asks for it. Exists so "Mes amis" search can disambiguate
    /// "which Léo?" without relying on first name alone (see `api/friends/[action].js` search).
    var lastName: String?
    /// A chosen, unique handle — nil until she sets one. The only fully reliable way to find one
    /// specific person by search, same reasoning as `lastName`.
    var username: String?
}

enum AuthServiceError: Error {
    case network(Error)
    case badResponse(Int, String)
    case notSignedIn
}

/// Talks to RunUp's account backend — the same Vercel project as the coach proxy (see
/// `api/auth/*.js`, `api/me.js`, `api/account/[action].js`). Holds the signed-in user + session
/// token (Keychain-backed, so it survives relaunches) so `ClubService` and `ClubView` can tell
/// whether there's a real account behind the Club tab. Signing in is scoped to Club only — the
/// rest of the app works fully offline, no account required.
///
/// `@MainActor` : `currentUser` et `token` sont observés par SwiftUI, et `onSignOut` ci-dessous
/// est une fermeture fournie par `AppState` (lui-même isolé sur l'acteur principal). Sans cette
/// annotation, `signOut()` pouvait appeler cette fermeture — donc muter l'état de l'app et son
/// contexte SwiftData — depuis n'importe quel fil. Les `await URLSession` restent, eux, hors du
/// fil principal ; seule la reprise après chaque `await` y revient.
@MainActor
@Observable
final class AuthService {
    private(set) var currentUser: AuthenticatedUser?
    private(set) var token: String?

    /// Appelé juste avant que la session ne soit effacée, sur les DEUX chemins de déconnexion
    /// (le bouton des réglages et la suppression de compte, qui appelle `signOut()`). Posé par
    /// `AppState.init` pour vider la file d'activités en attente : sans ça, les sorties d'un
    /// compte survivaient à sa déconnexion et étaient publiées sous le compte suivant connecté
    /// sur le même téléphone.
    ///
    /// Un rappel plutôt qu'un appel direct à `AppState` : ce service ne connaît pas l'état de
    /// l'app et n'a aucune raison de le connaître.
    var onSignOut: (() -> Void)?

    /// Appelé chaque fois qu'un compte devient le compte courant — connexion, inscription, et
    /// aussi la reprise de session au lancement.
    ///
    /// La reprise en fait partie volontairement : c'est par là que les profils créés avant que
    /// `UserProfile.ownerAccountID` n'existe se font adopter par leur compte, sans que personne
    /// n'ait à se reconnecter. Sans ça, ils resteraient sans propriétaire jusqu'à la prochaine
    /// déconnexion — c'est-à-dire précisément jusqu'au moment où l'on aurait eu besoin de savoir.
    var onAuthenticated: ((AuthenticatedUser) -> Void)?

    private static let baseURL = URL(string: "https://runup-nu.vercel.app")!

    init() {
        token = KeychainService.loadToken()
    }

    var isSignedIn: Bool { token != nil }

    /// `lastName` is sent separately from `name` (not pre-joined) so the server can store it as
    /// real, structured `last_name` — Apple only ever provides both on this account's very first
    /// sign-in, so this is the one chance to capture it at all.
    func signInWithApple(identityToken: String, name: String?, lastName: String? = nil, referralCode: String? = nil) async throws {
        try await authenticate(path: "api/auth/apple", body: ["identityToken": identityToken, "name": name ?? "", "lastName": lastName ?? "", "referralCode": referralCode ?? ""])
    }

    func signUp(email: String, password: String, name: String, lastName: String? = nil, referralCode: String? = nil) async throws {
        try await authenticate(path: "api/auth/signup", body: ["email": email, "password": password, "name": name, "lastName": lastName ?? "", "referralCode": referralCode ?? ""])
    }

    func logIn(email: String, password: String) async throws {
        try await authenticate(path: "api/auth/login", body: ["email": email, "password": password])
    }

    /// Refreshes `currentUser` (name, real `xpTotal`) from the server — call after sign-in and
    /// whenever Club needs a fresh number, since the server (not this device) owns that total
    /// once an account exists.
    @discardableResult
    func refreshMe() async throws -> AuthenticatedUser {
        guard let token else { throw AuthServiceError.notSignedIn }
        var request = URLRequest(url: Self.baseURL.appending(path: "api/me"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let decoded: MeResponse = try await send(request)
        let user = AuthenticatedUser(
            id: decoded.id, name: decoded.name, xpTotal: decoded.xpTotal, referralCode: decoded.referralCode,
            lastName: decoded.lastName, username: decoded.username
        )
        currentUser = user
        onAuthenticated?(user)
        return user
    }

    /// Uploads (or clears, if `dataURI` is nil) her profile photo so other club members see it
    /// too — a full data URI ("data:image/jpeg;base64,...."), already resized/compressed
    /// client-side (see `ProfileView.setAvatar`). Local-only storage (`UserProfile.avatarImageData`)
    /// covers the always-available case; this is purely additive for when Club is signed in.
    func updateAvatar(dataURI: String?) async throws {
        guard let token else { throw AuthServiceError.notSignedIn }
        var request = URLRequest(url: Self.baseURL.appending(path: "api/account/avatar"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["avatarDataURI": dataURI as Any])
        let _: OkResponse = try await send(request)
    }

    /// Deletes the account server-side (cascades to club membership/activities/kudos — see
    /// `api/account/[action].js`) then signs out locally. Required by App Store guideline
    /// 5.1.1(v): an app that offers account creation must offer in-app account deletion too.
    func deleteAccount() async throws {
        guard let token else { throw AuthServiceError.notSignedIn }
        var request = URLRequest(url: Self.baseURL.appending(path: "api/account/delete"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let _: OkResponse = try await send(request)
        signOut()
    }

    func signOut() {
        // Fire-and-forget with the token captured NOW (the Keychain entry is deleted below,
        // before the Task necessarily runs) — the device must stop receiving this account's
        // pushes once she signs out, and the token itself must stop working server-side.
        if let authToken = token {
            Task { await NotificationService.shared.unregisterDeviceToken(authToken: authToken) }
            Task { await Self.revokeSession(authToken: authToken) }
        }
        onSignOut?()
        token = nil
        currentUser = nil
        KeychainService.deleteToken()
    }

    /// Revokes the session token server-side (`api/auth/signout` files its `jti` in
    /// `revoked_tokens`). Deleting the local copy above was never enough on its own: the token
    /// stayed valid for its full lifetime, so any copy of it that survived elsewhere (a shared
    /// device, a device backup) kept full access to the account. Same token-passed-in reasoning as
    /// `unregisterDeviceToken`. Failure is silent on purpose — signing out must always work
    /// locally, offline included; the token then just expires on its own.
    private static func revokeSession(authToken: String) async {
        var request = URLRequest(url: baseURL.appending(path: "api/auth/signout"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: -

    private func authenticate(path: String, body: [String: String]) async throws {
        var request = URLRequest(url: Self.baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let decoded: AuthResponse = try await send(request)
        token = decoded.token
        currentUser = decoded.user
        KeychainService.saveToken(decoded.token)
        onAuthenticated?(decoded.user)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthServiceError.network(error)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AuthServiceError.badResponse(status, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct AuthResponse: Decodable {
    var token: String
    var user: AuthenticatedUser
}

private struct MeResponse: Decodable {
    var id: String
    var name: String
    var xpTotal: Int
    var referralCode: String?
    var clubId: String?
    var lastName: String?
    var username: String?
}

private struct OkResponse: Decodable {
    var ok: Bool
}
