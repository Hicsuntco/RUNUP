import Foundation
import AuthenticationServices
import UIKit
import Observation

/// Real Strava OAuth connect + activity import (see `api/strava/[action].js`) — the app only ever
/// holds the public Client ID; the client secret stays server-side (`lib/strava.js`), so tokens
/// are exchanged/refreshed there, never on-device.
///
/// **Not functional until two things happen** (real code either way — this just can't complete a
/// real handshake without them):
///  1. Create a Strava API application at https://www.strava.com/settings/api and set
///     `Self.clientID` below to its real Client ID (safe to hardcode — it's public).
///  2. Set `STRAVA_CLIENT_ID`/`STRAVA_CLIENT_SECRET` in Vercel (Project Settings → Environment
///     Variables) from that same application.
@Observable
final class StravaService: NSObject {
    static let clientID = "REPLACE_WITH_STRAVA_CLIENT_ID"
    private static let redirectURI = "runup://strava-callback"
    private static let baseURL = URL(string: "https://runup-nu.vercel.app")!

    private var auth: AuthService
    private var authSession: ASWebAuthenticationSession?

    init(auth: AuthService) {
        self.auth = auth
    }

    var isConfigured: Bool { Self.clientID != "REPLACE_WITH_STRAVA_CLIENT_ID" }

    /// Opens Strava's real authorization page in a system browser sheet, then exchanges the
    /// one-time code it redirects back with for real tokens (stored server-side, see
    /// `api/strava/connect`).
    @MainActor
    func connect() async throws {
        guard isConfigured else { throw StravaServiceError.notConfigured }

        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "activity:read_all")
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: "runup") { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? StravaServiceError.cancelled)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            authSession = session
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw StravaServiceError.missingCode
        }

        let _: OkResponse = try await send(path: "api/strava/connect", method: "POST", body: ["code": code])
    }

    func disconnect() async throws {
        let _: OkResponse = try await send(path: "api/strava/disconnect", method: "POST")
    }

    func status() async throws -> Bool {
        let response: StatusResponse = try await send(path: "api/strava/status", method: "GET")
        return response.connected
    }

    /// Real recent running history from Strava — caller (`ProfileView`) inserts each as a local
    /// `RunRecord`, deduped against `stravaActivityId`s already present locally so re-importing
    /// (to pick up newer Strava activity) is always safe.
    func importActivities() async throws -> [StravaImportedRun] {
        let response: ImportResponse = try await send(path: "api/strava/importActivities", method: "POST")
        return response.items
    }

    // MARK: -

    private func send<T: Decodable>(path: String, method: String, body: [String: Any]? = nil) async throws -> T {
        guard let token = auth.token else { throw StravaServiceError.notSignedIn }
        var request = URLRequest(url: Self.baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw StravaServiceError.network(error)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw StravaServiceError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

extension StravaService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}

struct StravaImportedRun: Decodable {
    var stravaActivityId: Int
    var title: String
    var distanceKm: Double
    var durationSeconds: Int
    var date: Date
    var elevationGainM: Int
    var avgHeartRate: Int
}

enum StravaServiceError: Error {
    case notConfigured
    case notSignedIn
    case cancelled
    case missingCode
    case network(Error)
    case badResponse(Int)
}

private struct OkResponse: Decodable { var ok: Bool }
private struct StatusResponse: Decodable { var connected: Bool }
private struct ImportResponse: Decodable { var items: [StravaImportedRun] }
