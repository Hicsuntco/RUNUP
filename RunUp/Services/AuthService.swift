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
}

enum AuthServiceError: Error {
    case network(Error)
    case badResponse(Int, String)
    case notSignedIn
}

/// Talks to RunUp's account backend — the same Vercel project as the coach proxy (see
/// `api/auth/*.js`, `api/me.js`, `api/account/delete.js`). Holds the signed-in user + session
/// token (Keychain-backed, so it survives relaunches) so `ClubService` and `ClubView` can tell
/// whether there's a real account behind the Club tab. Signing in is scoped to Club only — the
/// rest of the app works fully offline, no account required.
@Observable
final class AuthService {
    private(set) var currentUser: AuthenticatedUser?
    private(set) var token: String?

    private static let baseURL = URL(string: "https://runup-nu.vercel.app")!

    init() {
        token = KeychainService.loadToken()
    }

    var isSignedIn: Bool { token != nil }

    func signInWithApple(identityToken: String, name: String?, referralCode: String? = nil) async throws {
        try await authenticate(path: "api/auth/apple", body: ["identityToken": identityToken, "name": name ?? "", "referralCode": referralCode ?? ""])
    }

    func signUp(email: String, password: String, name: String, referralCode: String? = nil) async throws {
        try await authenticate(path: "api/auth/signup", body: ["email": email, "password": password, "name": name, "referralCode": referralCode ?? ""])
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
        let user = AuthenticatedUser(id: decoded.id, name: decoded.name, xpTotal: decoded.xpTotal, referralCode: decoded.referralCode)
        currentUser = user
        return user
    }

    /// Deletes the account server-side (cascades to club membership/activities/kudos — see
    /// `api/account/delete.js`) then signs out locally. Required by App Store guideline
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
        token = nil
        currentUser = nil
        KeychainService.deleteToken()
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
}

private struct OkResponse: Decodable {
    var ok: Bool
}
