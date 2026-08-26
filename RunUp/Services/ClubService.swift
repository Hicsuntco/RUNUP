import Foundation

struct ClubInfo: Decodable {
    var id: String
    var name: String
    var inviteCode: String
    var memberCount: Int
    /// Le club figure-t-il dans l'annuaire public. Optionnel, comme `city` et `isOwner` :
    /// l'app et le backend ne se déploient jamais en même temps, et un décodage strict de ces
    /// trois clés viderait tout l'onglet Club pendant la fenêtre où le serveur ne les renvoie
    /// pas encore.
    var isPublic: Bool?
    var city: String?
    /// Seul le créateur du club peut le publier ou le retirer. Renseigné par le serveur, qui
    /// revérifie de toute façon à l'écriture.
    var isOwner: Bool?
}

/// Un club de l'annuaire, vu par quelqu'un qui n'en est pas membre : juste de quoi décider s'il
/// vaut la peine d'être rejoint. Ni code d'invitation, ni liste de membres.
struct DiscoverableClub: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var city: String?
    var memberCount: Int
}

private struct DiscoverResponse: Decodable {
    var clubs: [DiscoverableClub]
}

struct LeaderboardRow: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var xp: Int
    var rank: Int
    var isMe: Bool
    /// Short, optional, self-authored status — editable only for `isMe` (see `ClubService.updateBio`).
    var bio: String?
    /// A real Blob storage URL since the avatar migration — `AvatarView` fetches it directly.
    /// Nil falls back to the initial-letter circle every avatar spot already used.
    var avatarUrl: String?
    /// Legacy fallback for an account that uploaded a photo before the Blob migration and hasn't
    /// re-uploaded since — `"data:image/jpeg;base64,...."`, decoded by `AvatarView`.
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
    var avatarUrl: String?
    var avatarBase64: String?
    var weekKm: Double
    var rank: Int
    var isMe: Bool
    /// This member's own client-computed weekly plan (see `UserProfile.plannedWeeklyKm`, synced
    /// via `syncWeeklyTarget`) — nil for anyone who hasn't opened Club since this shipped, or
    /// whose program has no fixed weekly target (course libre).
    var targetKm: Double?
    /// `round(weekKm / targetKm * 100)`, server-computed — nil whenever `targetKm` is nil so the
    /// UI can fall back to raw km for that one row instead of a misleading "0%".
    var pctOfTarget: Int?
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

/// Ce qu'une sortie terminée a réellement mesuré, au moment de la poster. Tout est optionnel
/// séparément : une séance de renfo n'a pas de distance, une sortie sans GPS n'a pas de dénivelé,
/// un post de badge n'a rien du tout. `.none` est le cas normal pour tout ce qui n'est pas une
/// course.
struct ActivityMetrics: Codable, Equatable {
    var distanceKm: Double?
    var durationSeconds: Int?
    /// Format « m:ss » — celui affiché sur l'écran de debrief, repris tel quel plutôt que
    /// recalculé, pour que le fil montre exactement le chiffre qu'elle a vu.
    var avgPace: String?
    var elevationGainM: Int?
    /// Renseigné par le client à partir de son propre historique (`RunRecord`), la seule source
    /// qui connaisse ses sorties passées. Le serveur ne le recalcule pas.
    var isPersonalRecord: Bool = false

    static let none = ActivityMetrics()
}

struct FeedItem: Decodable, Identifiable {
    var id: String
    var userId: String
    var name: String
    var avatarUrl: String?
    var avatarBase64: String?
    var text: String
    var createdAt: Date
    // Les métriques réelles de la sortie, chacune indépendamment absente. Un post `badge` n'est
    // pas une course, une activité d'avant la migration n'a rien de mesuré, et une sortie saisie
    // sans montre n'a ni dénivelé ni allure. `ActivityFeedRow` n'affiche que les colonnes
    // présentes : pas de « 0 km » ni de « --:-- » qui feraient passer une absence de mesure pour
    // une mesure.
    var distanceKm: Double?
    var durationSeconds: Int?
    /// Déjà formatée « m:ss » côté serveur, telle qu'elle a été enregistrée à la fin de la sortie
    /// — la recalculer ici depuis distance/durée donnerait une valeur légèrement différente de
    /// celle que la coureuse a vue sur son écran de debrief.
    var avgPace: String?
    var elevationGainM: Int?
    var isPersonalRecord: Bool
    var kudos: Int
    var kudoedByMe: Bool
    var commentsCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, userId, name, avatarUrl, avatarBase64, text, createdAt
        case distanceKm, durationSeconds, avgPace, elevationGainM, isPersonalRecord
        case kudos, kudoedByMe, commentsCount
    }

    /// Décodage volontairement tolérant sur les seuls champs de métrique. Le déploiement du
    /// backend et celui de l'app ne sont jamais simultanés : pendant la fenêtre où le serveur ne
    /// renvoie pas encore ces clés, un `decode` strict sur `isPersonalRecord` ferait échouer le
    /// décodage de TOUT le tableau et viderait le fil. Les champs historiques restent stricts —
    /// un fil sans `id` ou sans `text` est une vraie anomalie, pas une transition.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        avatarBase64 = try c.decodeIfPresent(String.self, forKey: .avatarBase64)
        text = try c.decode(String.self, forKey: .text)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm)
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        avgPace = try c.decodeIfPresent(String.self, forKey: .avgPace)
        elevationGainM = try c.decodeIfPresent(Int.self, forKey: .elevationGainM)
        isPersonalRecord = try c.decodeIfPresent(Bool.self, forKey: .isPersonalRecord) ?? false
        kudos = try c.decode(Int.self, forKey: .kudos)
        kudoedByMe = try c.decode(Bool.self, forKey: .kudoedByMe)
        commentsCount = try c.decode(Int.self, forKey: .commentsCount)
    }

    /// Vrai dès qu'au moins une métrique existe — la ligne KM / ALLURE / D+ de la carte
    /// n'apparaît que dans ce cas, et jamais pour un post de type « badge ».
    var hasMetrics: Bool {
        distanceKm != nil || durationSeconds != nil || avgPace != nil || elevationGainM != nil
    }

    /// « 48 min », « 1 h 12 » — la durée telle qu'on la dit, pas un chronomètre à la seconde.
    var durationDisplay: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        let minutes = durationSeconds / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }
}

/// A real comment on a club-mate's activity — several per activity/user, unlike kudos (one toggle
/// per user per activity).
struct CommentItem: Decodable, Identifiable {
    var id: String
    var userId: String
    var name: String
    var avatarUrl: String?
    var avatarBase64: String?
    var text: String
    var createdAt: Date
}

/// A real account found via search, or listed in a following/followers/requests list —
/// `followStatus` reflects the CALLER's own relationship to this person (is SHE following them):
/// nil (not following), "pending" (request sent, awaiting approval — only for a private account),
/// or "accepted". Only meaningful on search results; the following/followers/incomingRequests
/// lists are already scoped to one specific status by construction.
struct PublicUser: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    /// Nil unless she's set it — lets a search result show "Charlotte Grudé" instead of just
    /// "Charlotte" to help pick the right person among several matches.
    var lastName: String?
    /// Nil unless she's chosen one — shown as "@pseudo" under the name in search results, the
    /// only fully unambiguous identifier a result can carry.
    var username: String?
    var avatarUrl: String?
    var avatarBase64: String?
    var isPrivate: Bool
    var followStatus: String?
}

/// The caller's own follow graph, independent of any club — see `ClubService.fetchFriendsList`.
struct FriendsList: Decodable {
    var isPrivate: Bool
    var following: [PublicUser]
    var followers: [PublicUser]
    /// Only ever non-empty when `isPrivate` is true — a public account auto-accepts, so nothing
    /// waits for approval.
    var incomingRequests: [PublicUser]
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

/// Real km run this week across EVERY opted-in user on the platform — not scoped to her own
/// club. `optedIn` reflects whether SHE is currently visible in it, since opting out still needs
/// to fetch this once to show the right toggle state.
struct GlobalWeeklyBoard: Decodable {
    var optedIn: Bool
    var entries: [WeeklyRow]
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

    func fetchGlobalWeekly() async throws -> GlobalWeeklyBoard {
        try await send(path: "api/clubs/globalWeekly", method: "GET")
    }

    func setGlobalLeaderboardOptIn(_ optedIn: Bool) async throws {
        let _: OkResponse = try await send(path: "api/clubs/setGlobalOptIn", method: "POST", body: ["optedIn": optedIn])
    }

    func createClub(name: String) async throws -> ClubCreatedResponse {
        try await send(path: "api/clubs/create", method: "POST", body: ["name": name])
    }

    /// Sets the club's active challenge — replaces whichever one was active before (a club has at
    /// most one at a time). `endDate` is sent as a plain "YYYY-MM-DD" to match the DB's DATE column.
    /// `clientId` defaults to a fresh UUID — the server dedupes on it (`ON CONFLICT (client_id) DO
    /// NOTHING`), same idempotency pattern as `postActivity`, so a caller can safely retry with the
    /// same id after a timeout instead of risking a duplicate challenge on every retry.
    func createChallenge(clientId: UUID = UUID(), title: String, targetKm: Double, endDate: Date) async throws -> ClubChallenge {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return try await send(
            path: "api/clubs/createChallenge",
            method: "POST",
            body: ["clientId": clientId.uuidString, "title": title, "targetKm": targetKm, "endDate": formatter.string(from: endDate)]
        )
    }

    /// Proposes a sortie de groupe — the server auto-RSVPs the creator and pushes the club.
    /// `clientId` defaults to a fresh UUID, same idempotency pattern as `createChallenge` above.
    func createEvent(clientId: UUID = UUID(), title: String, location: String?, startsAt: Date) async throws -> ClubEvent {
        var body: [String: Any] = [
            "clientId": clientId.uuidString,
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

    /// Rejoindre un club de l'annuaire, sans code. Le serveur n'accepte l'identifiant que si le
    /// club est effectivement publié — un identifiant connu ne remplace pas un code d'invitation.
    func joinPublicClub(id: String) async throws -> ClubJoinedResponse {
        try await send(path: "api/clubs/join", method: "POST", body: ["clubId": id])
    }

    /// L'annuaire. `query` vide renvoie les clubs les plus fournis ; sinon une recherche sur le
    /// nom ou la ville.
    func discoverClubs(query: String = "") async throws -> [DiscoverableClub] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let response: DiscoverResponse = try await send(
            path: "api/clubs/discover",
            method: "GET",
            query: trimmed.isEmpty ? nil : ["q": trimmed]
        )
        return response.clubs
    }

    /// Publier son club dans l'annuaire, ou l'en retirer. Réservé à son créateur.
    func setClubVisibility(isPublic: Bool, city: String?) async throws {
        var body: [String: Any] = ["isPublic": isPublic]
        if let city, !city.trimmingCharacters(in: .whitespaces).isEmpty { body["city"] = city }
        let _: OkResponse = try await send(path: "api/clubs/setVisibility", method: "POST", body: body)
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
    /// `api/activities/create.js`. `metrics` (run activities only) feeds real club-challenge
    /// progress server-side and the KM / ALLURE / D+ line on the feed card.
    func postActivity(clientId: UUID = UUID(), type: String, text: String, xpEarned: Int, metrics: ActivityMetrics = .none) async throws {
        var body: [String: Any] = ["clientId": clientId.uuidString, "type": type, "text": text, "xpEarned": xpEarned]
        // Chaque métrique n'est envoyée que si elle a été réellement mesurée : une clé absente
        // devient NULL en base, ce que le fil sait afficher comme « pas de donnée ». Envoyer 0
        // ferait apparaître « 0 D+ » sur une sortie dont le dénivelé n'a simplement jamais été
        // capté.
        if let distanceKm = metrics.distanceKm { body["distanceKm"] = distanceKm }
        if let durationSeconds = metrics.durationSeconds { body["durationSeconds"] = durationSeconds }
        if let avgPace = metrics.avgPace { body["avgPace"] = avgPace }
        if let elevationGainM = metrics.elevationGainM { body["elevationGainM"] = elevationGainM }
        if metrics.isPersonalRecord { body["isPersonalRecord"] = true }
        let _: OkResponse = try await send(
            path: "api/activities/create",
            method: "POST",
            body: body
        )
    }

    // MARK: - Itinéraires partagés

    /// Publie un itinéraire à partir d'une sortie déjà courue.
    ///
    /// Prend le tracé BRUT et applique `RouteGeometry.shareablePayload` ici, en un seul endroit :
    /// aucun écran n'a à se souvenir de rogner, et aucun ne peut l'oublier. Rend `nil` — sans rien
    /// envoyer — quand le parcours est trop court pour survivre au rognage.
    @discardableResult
    func publishRoute(clientId: UUID = UUID(),
                      name: String,
                      notes: String?,
                      route: [RunRecord.RoutePoint],
                      distanceKm: Double,
                      elevationGainM: Int?,
                      durationSeconds: Int?,
                      locality: String?,
                      countryCode: String?) async throws -> String? {
        guard let payload = RouteGeometry.shareablePayload(route) else { return nil }

        var body: [String: Any] = [
            "clientId": clientId.uuidString,
            "name": name,
            "distanceKm": distanceKm,
            "points": payload.points.map { [$0.lat, $0.lng] },
            "preview": payload.preview.map { [$0.lat, $0.lng] },
        ]
        // Mêmes règles que `postActivity` : une clé absente devient NULL, là où un 0 ferait passer
        // une absence de mesure pour une mesure.
        if let notes, !notes.isEmpty { body["notes"] = notes }
        if let elevationGainM { body["elevationGainM"] = elevationGainM }
        if let durationSeconds { body["durationSeconds"] = durationSeconds }
        if let locality, !locality.isEmpty { body["locality"] = locality }
        if let countryCode, !countryCode.isEmpty { body["countryCode"] = countryCode }

        let response: RoutePublishResponse = try await send(
            path: "api/activities/routePublish", method: "POST", body: body
        )
        return response.id
    }

    /// Les itinéraires dont le départ tombe dans la zone affichée, du plus enregistré au plus
    /// récent. `distMin`/`distMax` répondent à la vraie demande : « je veux 10 km ici ».
    func fetchRoutesNearby(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double,
                           distMin: Double? = nil, distMax: Double? = nil) async throws -> [SharedRoute] {
        var query: [String: String] = [
            "minLat": String(minLat), "maxLat": String(maxLat),
            "minLng": String(minLng), "maxLng": String(maxLng),
        ]
        if let distMin { query["distMin"] = String(distMin) }
        if let distMax { query["distMax"] = String(distMax) }
        let response: SharedRoutesResponse = try await send(
            path: "api/activities/routesNearby", method: "GET", query: query
        )
        return response.routes
    }

    /// Le tracé complet d'un itinéraire — payé seulement quand on l'ouvre vraiment.
    func fetchRoute(id: String) async throws -> SharedRoute {
        let response: SharedRouteResponse = try await send(
            path: "api/activities/routeDetail", method: "GET", query: ["id": id]
        )
        return response.route
    }

    @discardableResult
    func setRouteSaved(routeId: String, saved: Bool) async throws -> Int {
        let response: RouteSaveResponse = try await send(
            path: "api/activities/routeSave", method: "POST",
            body: ["routeId": routeId, "saved": saved]
        )
        return response.savesCount
    }

    /// Attache (ou retire) la photo d'un itinéraire dont je suis l'autrice.
    ///
    /// Séparé de `publishRoute` volontairement : la photo a besoin de l'identifiant de
    /// l'itinéraire, donc elle ne peut partir qu'après. Et surtout, un échec d'envoi de photo ne
    /// doit pas emporter la publication avec lui — un itinéraire sans photo reste utile, une
    /// publication perdue ne l'est pas.
    @discardableResult
    func setRoutePhoto(routeId: String, dataURI: String?) async throws -> String? {
        let response: RoutePhotoResponse = try await send(
            path: "api/activities/routePhoto", method: "POST",
            body: ["routeId": routeId, "photoDataURI": dataURI as Any]
        )
        return response.photoUrl
    }

    /// Ceux que j'ai publiés, et ceux que j'ai enregistrés pour plus tard.
    func fetchMyRoutes() async throws -> (published: [SharedRoute], saved: [SharedRoute]) {
        let response: MyRoutesResponse = try await send(path: "api/activities/routesMine", method: "GET")
        return (response.published, response.saved)
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

    /// Pushes up this device's own computed `UserProfile.plannedWeeklyKm` — the one number only
    /// the client can compute (real program/session data), feeding the "% objectif" weekly
    /// leaderboard mode server-side. Fire-and-forget, same as `syncBadges`: harmless to call with
    /// the same value repeatedly.
    func syncWeeklyTarget(_ targetKm: Double) async throws {
        let _: OkResponse = try await send(path: "api/clubs/syncWeeklyTarget", method: "POST", body: ["targetKm": targetKm])
    }

    // MARK: Friends (a real follow graph, independent of any club)

    /// Finds real accounts by name — 2+ characters, server-side, capped at 20 results. Each
    /// result's `followStatus` reflects whether SHE already follows them, so the client can show
    /// the right button state without a second round trip per row.
    func searchUsers(query: String) async throws -> [PublicUser] {
        let response: PublicUserListResponse = try await send(path: "api/friends/search", method: "GET", query: ["q": query])
        return response.items
    }

    /// Follows a real account — instant ("accepted") unless they've gone private, in which case
    /// the server returns "pending" and she'll sit in their incoming requests until approved.
    @discardableResult
    func followUser(userId: String) async throws -> String {
        let response: FollowStatusResponse = try await send(path: "api/friends/follow", method: "POST", body: ["userId": userId])
        return response.status
    }

    func unfollowUser(userId: String) async throws {
        let _: OkResponse = try await send(path: "api/friends/unfollow", method: "POST", body: ["userId": userId])
    }

    /// Approves or declines an incoming follow request — only ever relevant while her account is
    /// private (a public account auto-accepts, see `setPrivateAccount`).
    func respondToFollowRequest(followerId: String, accept: Bool) async throws {
        let _: OkResponse = try await send(path: "api/friends/respond", method: "POST", body: ["userId": followerId, "accept": accept])
    }

    /// Removes someone following HER without unfollowing them back the other way — same
    /// distinction most social apps make between "unfollow" and "remove follower".
    func removeFollower(userId: String) async throws {
        let _: OkResponse = try await send(path: "api/friends/removeFollower", method: "POST", body: ["userId": userId])
    }

    func fetchFriendsList() async throws -> FriendsList {
        try await send(path: "api/friends/list", method: "GET")
    }

    /// Same response shape as `fetchFeed` (the club feed) — both render through the same
    /// `ActivityFeedRow`/kudos/comments plumbing, just sourced from the follow graph instead of
    /// club membership.
    func fetchFriendsFeed() async throws -> [FeedItem] {
        let response: FeedResponse = try await send(path: "api/friends/feed", method: "GET")
        return response.items
    }

    /// Toggles Instagram-style privacy: while private, a new follow needs her approval
    /// (`respondToFollowRequest`) before it counts; existing accepted followers are unaffected.
    func setPrivateAccount(_ isPrivate: Bool) async throws {
        let _: OkResponse = try await send(path: "api/friends/setPrivate", method: "POST", body: ["isPrivate": isPrivate])
    }

    /// Sets her chosen handle and/or last name — either can be sent alone (the other stays
    /// unchanged), and either can be cleared by passing an empty string. Throws
    /// `ClubServiceError.badResponse(409, _)` if the username is already taken by someone else,
    /// `(400, _)` if it fails the format check (lowercase letters/digits/underscore, 3-20 chars).
    func updateProfile(username: String? = nil, lastName: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let username { body["username"] = username }
        if let lastName { body["lastName"] = lastName }
        let _: OkResponse = try await send(path: "api/friends/updateProfile", method: "POST", body: body)
    }

    // MARK: -

    private func send<T: Decodable>(path: String, method: String, body: [String: Any]? = nil, query: [String: String]? = nil) async throws -> T {
        // `await` : `AuthService` est isolé sur l'acteur principal (il porte l'état de session
        // observé par l'interface). Cette fonction, elle, est volontairement non isolée pour que
        // la sérialisation et le réseau restent hors du fil principal — seule la lecture du jeton
        // y saute, le temps d'un accès.
        guard let token = await auth.token else { throw ClubServiceError.notSignedIn }
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

private struct PublicUserListResponse: Decodable {
    var items: [PublicUser]
}

private struct FollowStatusResponse: Decodable {
    var status: String
}
