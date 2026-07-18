import Foundation

struct ClubInfo: Decodable {
    var id: String
    var name: String
    var inviteCode: String
    var memberCount: Int
}

struct LeaderboardRow: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var xp: Int
    var rank: Int
    var isMe: Bool
}

struct ClubBoard: Decodable {
    var club: ClubInfo?
    var leaderboard: [LeaderboardRow]
    var challenge: ClubChallenge?
}

/// A member-set club challenge (distance target by a deadline) — `progressKm` is a real sum
/// computed server-side over every 'run' activity logged to the club since the challenge was
/// created, not a running counter tracked client-side.
struct ClubChallenge: Decodable, Identifiable {
    var id: String
    var title: String
    var targetKm: Double
    var progressKm: Double
    var endDate: Date
}

struct FeedItem: Decodable, Identifiable {
    var id: String
    var userId: String
    var name: String
    var text: String
    var createdAt: Date
    var kudos: Int
    var kudoedByMe: Bool
}

/// Returned by `createClub` — used by the caller to show the invite code to share.
struct ClubCreatedResponse: Decodable {
    var id: String
    var name: String
    var inviteCode: String
}

struct ClubJoinedResponse: Decodable {
    var id: String
    var name: String
}

enum ClubServiceError: Error {
    case network(Error)
    case badResponse(Int, String)
    case notSignedIn
}

/// Talks to RunUp's real club backend (`api/clubs/*.js`, `api/activities/*.js`) — replaces
/// `ClubMockData`. Every call needs a session token from `AuthService`, since a club only means
/// something once there's a real account behind it.
struct ClubService {
    var auth: AuthService
    private static let baseURL = URL(string: "https://runup-nu.vercel.app")!

    func fetchBoard() async throws -> ClubBoard {
        try await send(path: "api/clubs/mine", method: "GET")
    }

    func createClub(name: String) async throws -> ClubCreatedResponse {
        try await send(path: "api/clubs/create", method: "POST", body: ["name": name])
    }

    /// Sets the club's active challenge — replaces whichever one was active before (a club has at
    /// most one at a time). `endDate` is sent as a plain "YYYY-MM-DD" to match the DB's DATE column.
    func createChallenge(title: String, targetKm: Double, endDate: Date) async throws -> ClubChallenge {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return try await send(
            path: "api/clubs/createChallenge",
            method: "POST",
            body: ["title": title, "targetKm": targetKm, "endDate": formatter.string(from: endDate)]
        )
    }

    func joinClub(inviteCode: String) async throws -> ClubJoinedResponse {
        try await send(path: "api/clubs/join", method: "POST", body: ["inviteCode": inviteCode])
    }

    func leaveClub() async throws {
        let _: OkResponse = try await send(path: "api/clubs/leave", method: "POST")
    }

    func fetchFeed() async throws -> [FeedItem] {
        let response: FeedResponse = try await send(path: "api/activities/feed", method: "GET")
        return response.items
    }

    @discardableResult
    func toggleKudos(activityId: String) async throws -> Bool {
        let response: KudosResponse = try await send(path: "api/activities/kudos", method: "POST", body: ["activityId": activityId])
        return response.kudoed
    }

    /// Posts one completed activity to the club feed and credits its XP to the account's real
    /// server-side total. `clientId` is a fresh UUID per call so a retried request (flaky
    /// network) never double-counts the XP or duplicates the feed entry — see
    /// `api/activities/create.js`. `distanceKm` (run activities only) feeds real club-challenge
    /// progress server-side.
    func postActivity(clientId: UUID = UUID(), type: String, text: String, xpEarned: Int, distanceKm: Double? = nil) async throws {
        var body: [String: Any] = ["clientId": clientId.uuidString, "type": type, "text": text, "xpEarned": xpEarned]
        if let distanceKm { body["distanceKm"] = distanceKm }
        let _: OkResponse = try await send(
            path: "api/activities/create",
            method: "POST",
            body: body
        )
    }

    /// Flags a club name, display name, or activity as objectionable — lands in the `reports`
    /// table for manual review (App Store guideline 1.2). `targetType` is "user", "club", or
    /// "activity"; `targetId` the relevant id.
    func report(targetType: String, targetId: String, reason: String) async throws {
        let _: OkResponse = try await send(
            path: "api/moderation/report",
            method: "POST",
            body: ["targetType": targetType, "targetId": targetId, "reason": reason]
        )
    }

    /// Stops seeing a specific person's leaderboard entry and feed activity — the other half of
    /// guideline 1.2 alongside `report`. Doesn't require leaving the club.
    func blockUser(userId: String) async throws {
        let _: OkResponse = try await send(path: "api/moderation/block", method: "POST", body: ["userId": userId])
    }

    func unblockUser(userId: String) async throws {
        let _: OkResponse = try await send(path: "api/moderation/unblock", method: "POST", body: ["userId": userId])
    }

    // MARK: -

    private func send<T: Decodable>(path: String, method: String, body: [String: Any]? = nil) async throws -> T {
        guard let token = auth.token else { throw ClubServiceError.notSignedIn }
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
            throw ClubServiceError.network(error)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClubServiceError.badResponse(status, String(data: data, encoding: .utf8) ?? "")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

private struct FeedResponse: Decodable {
    var items: [FeedItem]
}

private struct KudosResponse: Decodable {
    var kudoed: Bool
}

private struct OkResponse: Decodable {
    var ok: Bool
}
