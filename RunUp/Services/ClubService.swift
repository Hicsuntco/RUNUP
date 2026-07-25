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
    /// Short, optional, self-authored status — editable only for `isMe` (see `ClubService.updateBio`).
    var bio: String?
    /// Her real uploaded photo, if she's set one — `"data:image/jpeg;base64,...."`, decoded by
    /// `AvatarView`. Nil falls back to the initial-letter circle every avatar spot already used.
    var avatarBase64: String?
    /// Real membership date (`club_members.joined_at`) — was tracked in the DB from day one but
    /// never surfaced anywhere in the UI until now.
    var joinedAt: Date
    /// Real count of this member's activities posted to *this* club, alongside their XP.
    var activitiesCount: Int
    /// Real, permanent achievement keys synced server-side (see `ClubBadgeCatalog`) — what makes
    /// badges visible on every member's profile, not just the device that earned them.
    var badgeKeys: [String]
}

/// One row of the WEEKLY board — real km run this week (Monday reset, server-computed), the
/// fresh race a newcomer can win even against members with months of XP.
struct WeeklyRow: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var avatarBase64: String?
    var weekKm: Double
    var rank: Int
    var isMe: Bool
}

/// Club-wide pulse for the current week — total km + how many members actually ran.
struct ClubWeekStats: Decodable {
    var totalKm: Double
    var activeMembers: Int
}

/// A sortie de groupe — a member proposes a run (title, meeting point, date), others RSVP.
struct ClubEvent: Decodable, Identifiable {
    var id: String
    var title: String
    var location: String?
    var startsAt: Date
    var going: Int
    var goingByMe: Bool
    var isMine: Bool
}

struct ClubBoard: Decodable {
    var club: ClubInfo?
    var leaderboard: [LeaderboardRow]
    // Optional (not just empty-default) so a response from a backend build predating these
    // fields still decodes instead of taking the whole Club tab down.
    var weekly: [WeeklyRow]?
    var weekStats: ClubWeekStats?
    var events: [ClubEvent]?
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
    var avatarBase64: String?
    var text: String
    var createdAt: Date
    var kudos: Int
    var kudoedByMe: Bool
    var commentsCount: Int
}

/// A real comment on a club-mate's activity — several per activity/user, unlike kudos (one toggle
/// per user per activity).
struct CommentItem: Decodable, Identifiable {
    var id: String
    var userId: String
    var name: String
    var avatarBase64: String?
    var text: String
    var createdAt: Date
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

    /// Proposes a sortie de groupe — the server auto-RSVPs the creator and pushes the club.
    func createEvent(title: String, location: String?, startsAt: Date) async throws -> ClubEvent {
        var body: [String: Any] = [
            "title": title,
            "startsAt": ISO8601DateFormatter().string(from: startsAt),
        ]
        if let location, !location.isEmpty { body["location"] = location }
        return try await send(path: "api/clubs/createEvent", method: "POST", body: body)
    }

    /// Toggles "J'y serai" — returns the new state + the fresh count.
    func toggleEventRsvp(eventId: String) async throws -> (going: Bool, count: Int) {
        let response: RsvpResponse = try await send(path: "api/clubs/rsvpEvent", method: "POST", body: ["eventId": eventId])
        return (response.going, response.count)
    }

    /// Cancels a sortie — creator only (the server enforces it).
    func deleteEvent(eventId: String) async throws {
        let _: OkResponse = try await send(path: "api/clubs/deleteEvent", method: "POST", body: ["eventId": eventId])
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

    /// Removes one of MY activities from the club feed — the server enforces ownership.
    func deleteActivity(activityId: String) async throws {
        let _: OkResponse = try await send(path: "api/activities/delete", method: "POST", body: ["activityId": activityId])
    }

    @discardableResult
    func toggleKudos(activityId: String) async throws -> Bool {
        let response: KudosResponse = try await send(path: "api/activities/kudos", method: "POST", body: ["activityId": activityId])
        return response.kudoed
    }

    /// Oldest-first — a comment thread reads top-down, same as any chat/comment UI.
    func fetchComments(activityId: String) async throws -> [CommentItem] {
        let response: CommentsResponse = try await send(path: "api/activities/comments", method: "GET", query: ["activityId": activityId])
        return response.items
    }

    @discardableResult
    func postComment(activityId: String, text: String) async throws -> CommentItem {
        try await send(path: "api/activities/comments", method: "POST", body: ["activityId": activityId, "text": text])
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

    /// Sets the caller's own club-profile status — always the caller's own row (there's no
    /// targetId, the auth token is the identity), same moderation as club names/challenge titles.
    @discardableResult
    func updateBio(_ bio: String) async throws -> String? {
        let response: BioResponse = try await send(path: "api/clubs/updateBio", method: "POST", body: ["bio": bio])
        return response.bio
    }

    /// Upserts real, permanent achievements from keys computed locally (streak, run history,
    /// elevation — data only this device has). Fire-and-forget from the caller's point of view:
    /// harmless to call with the same already-earned keys repeatedly (`ON CONFLICT DO NOTHING`
    /// server-side).
    func syncBadges(_ badgeKeys: [String]) async throws {
        let _: OkResponse = try await send(path: "api/clubs/syncBadges", method: "POST", body: ["badgeKeys": badgeKeys])
    }

    // MARK: -

    private func send<T: Decodable>(path: String, method: String, body: [String: Any]? = nil, query: [String: String]? = nil) async throws -> T {
        guard let token = auth.token else { throw ClubServiceError.notSignedIn }
        var url = Self.baseURL.appending(path: path)
        if let query, !query.isEmpty {
            url.append(queryItems: query.map { URLQueryItem(name: $0.key, value: $0.value) })
        }
        var request = URLRequest(url: url)
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
        decoder.dateDecodingStrategy = Self.serverDateStrategy
        return try decoder.decode(T.self, from: data)
    }

    /// The backend (Neon → JSON.stringify) serializes every timestamp WITH fractional seconds
    /// ("2026-07-24T09:15:32.123Z") — which plain `.iso8601` cannot parse at all, so every date
    /// field in the Club API used to throw `DecodingError` and take the whole response down with
    /// it (the Club tab stuck on "Chargement du club…" forever). Accept both forms.
    private static let serverDateStrategy: JSONDecoder.DateDecodingStrategy = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = fractional.date(from: raw) ?? plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date non reconnue: \(raw)")
        }
    }()
}

private struct FeedResponse: Decodable {
    var items: [FeedItem]
}

private struct RsvpResponse: Decodable {
    var going: Bool
    var count: Int
}

private struct KudosResponse: Decodable {
    var kudoed: Bool
}

private struct CommentsResponse: Decodable {
    var items: [CommentItem]
}

private struct OkResponse: Decodable {
    var ok: Bool
}

private struct BioResponse: Decodable {
    var ok: Bool
    var bio: String?
}
