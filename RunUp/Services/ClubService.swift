import Foundation

struct ClubInfo: Decodable {
    var id: String
    var name: String
    var memberCount: Int
    /// Un club fermé n'apparaît dans aucune recherche et ne se rejoint plus. Ses membres
    /// actuels ne sont pas touchés : fermer n'est pas vider.
    ///
    /// Optionnel pour une seule raison, qui vaut pour les trois champs ajoutés ici : la fenêtre
    /// entre le déploiement du serveur et celui de l'app n'est jamais nulle, et un `decode`
    /// strict déconnecterait du Club tous ceux qui n'ont pas encore mis à jour.
    var isOpen: Bool?
    /// L'interrupteur n'est montré qu'à la personne qui a créé le club. Le serveur le revérifie.
    var isOwner: Bool?
    /// CE QUI FAIT D'UN CLUB UN LIEU ET PLUS UN NOM. Optionnels pour la même raison que les deux
    /// champs ci-dessus — et parce qu'un club peut parfaitement n'avoir rien écrit.
    var description: String?
    var city: String?
    /// La bannière du club. Une URL de stockage, jamais l'image : une ligne de `clubs` est relue
    /// à chaque ouverture de l'écran, par chaque membre.
    var coverUrl: String?
}

/// Un club trouvé par la recherche — tout ce qu'il faut pour décider de le rejoindre, et rien de
/// plus. Le nombre de membres n'est pas décoratif : rien n'empêche deux clubs de porter le même
/// nom, et c'est la seule chose qui permette de les distinguer d'un coup d'œil.
struct ClubSearchResult: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    /// Deux clubs peuvent porter le même nom. Sans la ville, « Les Foulées » de Lyon et celles
    /// de Nantes sont le même résultat, et on en rejoint une à l'autre bout du pays.
    var city: String?
    var memberCount: Int
}

struct LeaderboardRow: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    /// « owner » | « organiser » | « member ». Dit par le serveur plutôt que déduit ici : la
    /// créatrice est organisatrice par construction, sans ligne de rôle à elle, et porter cette
    /// règle une deuxième fois dans l'app serait l'occasion qu'elles divergent.
    ///
    /// Optionnel : la fenêtre entre le déploiement du serveur et celui de l'app n'est jamais
    /// nulle, et un décodage strict viderait le Club de tous ceux qui n'ont pas encore mis à jour.
    var role: String?
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
    /// CE QUI FAIT VIVRE UN VRAI CREW : la séance qui revient. « Le mardi 19h30 » est UNE chose,
    /// pas cinquante-deux sorties à reposter. Optionnels au décodage : le serveur peut être en
    /// avance sur l'app installée, et une séance sans ces champs reste une sortie valide.
    var repeatsWeekly: Bool?
    /// Les groupes d'allure proposés par qui organise — « 4:30 », « 5:15 », « 6:00 et on
    /// discute ». Vide pour une sortie qui part d'un seul bloc.
    var paceGroups: [String]?
    /// Le mien, quand j'ai répondu présente.
    var myPaceGroup: String?
    /// Combien de personnes par groupe. C'est la seule information dont l'organisateur a besoin
    /// — combien de meneurs prévoir — et celle qui dit à chacun s'il courra accompagné.
    var paceCounts: [String: Int]?
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
    /// CE QU'IL FAUT POUR DÉROULER LA SORTIE, et pas seulement la résumer.
    ///
    /// Les temps au kilomètre, au format « m:ss » — ceux de `RunRecord.splits`, repris tels quels
    /// plutôt que recalculés depuis un cumul, pour la même raison que l'allure moyenne : le fil
    /// doit montrer le chiffre qu'elle a vu à l'arrivée.
    var splits: [String] = []
    /// Mesurées par la montre ou par Santé. Nil quand personne ne les a mesurées, jamais 0 : « pas
    /// de cardio » et « 0 bpm » ne sont pas la même phrase.
    var avgHeartRate: Int?
    var kcal: Int?

    static let none = ActivityMetrics()

    /// Les trois derniers paramètres sont EN FIN DE LISTE et portent une valeur par défaut : un
    /// initialiseur Swift se remplit dans l'ordre déclaré, et les insérer au milieu aurait
    /// demandé de retoucher chaque appel pour rien.
    init(distanceKm: Double? = nil, durationSeconds: Int? = nil, avgPace: String? = nil,
         elevationGainM: Int? = nil, isPersonalRecord: Bool = false,
         splits: [String] = [], avgHeartRate: Int? = nil, kcal: Int? = nil) {
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.avgPace = avgPace
        self.elevationGainM = elevationGainM
        self.isPersonalRecord = isPersonalRecord
        self.splits = splits
        self.avgHeartRate = avgHeartRate
        self.kcal = kcal
    }

    /// Décodage tolérant : cette structure est ENREGISTRÉE, dans la file d'envoi au club que
    /// `PendingClubActivity` range dans `UserDefaults`. Un seul champ non optionnel suffisait à
    /// faire échouer la relecture de toute la file après une mise à jour qui l'aurait ajouté —
    /// et une file illisible est une sortie qui ne part jamais. Voir `ci_scripts/check_decodage.py`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm)
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        avgPace = try c.decodeIfPresent(String.self, forKey: .avgPace)
        elevationGainM = try c.decodeIfPresent(Int.self, forKey: .elevationGainM)
        isPersonalRecord = try c.decodeIfPresent(Bool.self, forKey: .isPersonalRecord) ?? false
        splits = try c.decodeIfPresent([String].self, forKey: .splits) ?? []
        avgHeartRate = try c.decodeIfPresent(Int.self, forKey: .avgHeartRate)
        kcal = try c.decodeIfPresent(Int.self, forKey: .kcal)
    }

    private enum CodingKeys: String, CodingKey {
        case distanceKm, durationSeconds, avgPace, elevationGainM, isPersonalRecord
        case splits, avgHeartRate, kcal
    }
}

/// LA PHRASE D'UNE SORTIE, DANS LA LANGUE DE QUI LA LIT.
///
/// `text` arrive du serveur déjà rédigé — « a couru 8,2 km · Sortie longue » — dans la langue de
/// celle qui a posté. Une app vendue en trois langues servait donc un fil français à ses
/// lectrices anglophones, jusque dans le titre de séance. `contentKey` dit CE QUE la sortie
/// raconte sous une forme qui ne dépend d'aucune langue, et l'appareil qui lit refabrique la
/// phrase chez lui.
///
/// À part, parce que deux écrans en ont besoin : la carte du fil, et la page d'une sortie
/// ouverte depuis le fil. Deux copies de cette logique auraient fini par ne plus dire tout à
/// fait la même chose de la même course, sur deux écrans qu'on atteint d'un seul geste.
enum PhraseDeSortie {
    static func localisee(text: String, contentKey: String?, distanceKm: Double?) -> String {
        guard let contentKey else { return text }
        if contentKey == "daily_goals" { return String(localized: "a bouclé ses 3 objectifs du jour") }
        guard let kind = SessionKind(rawValue: contentKey) else { return text }
        let sessionTitle = String(localized: String.LocalizationValue(kind.titleKey))
        guard let distanceKm, distanceKm > 0.05 else {
            return String(localized: "a fait sa séance · \(sessionTitle)")
        }
        let distance = String(format: "%.1f", locale: Locale.current, distanceKm)
        return String(localized: "a couru \(distance) km · \(sessionTitle)")
    }
}

/// La provenance d'une sortie dans le mur : pourquoi elle y figure.
///
/// Sans elle, un fil mélangé ne dit plus pourquoi telle personne s'y trouve — et c'est ce qui
/// sépare un réseau d'un annuaire. Optionnelle parce que les deux anciens fils ne la renvoient
/// pas, et que l'app doit continuer de les décoder.
struct FeedItem: Decodable, Identifiable {
    /// « moi » | « club » | « amis ». Nil quand la réponse vient d'un ancien fil.
    var source: String?
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
    /// Ce que ce post raconte, sous une forme qui ne dépend d'aucune langue : la valeur brute d'un
    /// `SessionKind` pour une course, `daily_goals` pour le badge des trois objectifs. Voir
    /// `localizedText` juste en dessous, et `activities.content_key` dans db/schema.sql.
    ///
    /// `nil` pour les activités antérieures à ce champ et pour une séance hors plan — la phrase du
    /// serveur reste alors la meilleure chose disponible.
    var contentKey: String?
    var kudos: Int
    var kudoedByMe: Bool
    var commentsCount: Int
    /// Le titre que l'autrice a donné à sa sortie, et sa note. `text` reste la phrase FABRIQUÉE
    /// (« a couru 8,2 km · Sortie longue ») : elle décrit ce qui s'est passé, ces deux-ci disent
    /// ce qu'elle en pense. `nil` tant qu'elle n'a rien écrit, ce qui sera le cas le plus fréquent.
    var title: String?
    var note: String?
    /// Non-nil dès la première modification. Affiché, pas caché : un fil où un texte peut changer
    /// sans laisser de trace est un fil dont on ne peut rien citer.
    var editedAt: Date?
    /// Le tracé, déjà rogné de ses extrémités AVANT d'être envoyé — voir `RouteGeometry.feedTrace`.
    /// `nil` pour une sortie sans GPS, trop courte pour survivre au rognage, ou dont l'autrice a
    /// retiré le tracé après coup.
    var routePreview: [RunRecord.RoutePoint]?
    /// La photo de la sortie, quand son autrice en a mis une. Une URL de stockage, jamais
    /// l'image : `AsyncImage` va la chercher, le fil ne la transporte pas.
    var photoUrl: String?
    /// Trois noms au plus parmi ceux qui ont aimé — ce qui transforme « 7 » en gens. Le compte
    /// complet reste `kudos` ; ces noms n'en sont pas l'ordre, seulement un échantillon.
    var kudosNames: [String]
    /// Le dernier commentaire, en aperçu.
    var lastComment: FeedComment?

    struct FeedComment: Decodable, Equatable {
        var name: String
        var text: String
    }

    private enum CodingKeys: String, CodingKey {
        case id, userId, name, avatarUrl, avatarBase64, text, createdAt
        case distanceKm, durationSeconds, avgPace, elevationGainM, isPersonalRecord, contentKey
        case kudos, kudoedByMe, commentsCount
        case title, note, editedAt, routePreview, kudosNames, lastComment
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
        contentKey = try c.decodeIfPresent(String.self, forKey: .contentKey)
        kudos = try c.decode(Int.self, forKey: .kudos)
        kudoedByMe = try c.decode(Bool.self, forKey: .kudoedByMe)
        commentsCount = try c.decode(Int.self, forKey: .commentsCount)
        // Tolérants, pour la même raison que les métriques au-dessus : le serveur et l'app ne se
        // déploient jamais en même temps, et un `decode` strict sur une clé pas encore renvoyée
        // viderait le fil entier plutôt qu'une carte.
        title = try c.decodeIfPresent(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
        kudosNames = try c.decodeIfPresent([String].self, forKey: .kudosNames) ?? []
        lastComment = try c.decodeIfPresent(FeedComment.self, forKey: .lastComment)
        // Le tracé voyage en [[lat, lng], …] — la forme que la base stocke et que le serveur
        // renvoie telle quelle. Une paire mal formée fait tomber le tracé entier plutôt que de
        // dessiner une ligne qui saute : mieux vaut une carte sans dessin qu'un dessin faux.
        if let pairs = try c.decodeIfPresent([[Double]].self, forKey: .routePreview),
           pairs.count > 1, pairs.allSatisfy({ $0.count == 2 }) {
            routePreview = pairs.map { RunRecord.RoutePoint(lat: $0[0], lng: $0[1]) }
        } else {
            routePreview = nil
        }
    }

    /// La phrase du fil, dans la langue de celle qui LIT.
    ///
    /// `text` arrive du serveur déjà rédigé — « a couru 8,2 km · Sortie longue » — dans la langue
    /// de celle qui a posté. Une app vendue en trois langues servait donc un fil français à ses
    /// lectrices anglophones, jusque dans le titre de séance : `RunRecord.title` porte le libellé
    /// affiché pendant la course, donc déjà traduit — dans SA langue à elle.
    ///
    /// Avec `contentKey`, rien de tout ça n'a besoin de voyager : on connaît le type de séance et
    /// la distance, et la phrase se refabrique ici avec les chaînes locales. Les deux formats sont
    /// exactement ceux qu'emploie `DebriefSheet` au moment de poster — même clé de catalogue, donc
    /// mêmes traductions, sans rien à retraduire.
    ///
    /// Sans `contentKey` — activité d'avant ce champ, séance hors plan — on garde `text` : la
    /// phrase de l'autrice reste très au-dessus d'une carte vide.
    var localizedText: String {
        PhraseDeSortie.localisee(text: text, contentKey: contentKey, distanceKm: distanceKm)
    }

    /// Vrai dès qu'au moins une métrique existe — la ligne KM / ALLURE / D+ de la carte
    /// n'apparaît que dans ce cas, et jamais pour un post de type « badge ».
    var hasMetrics: Bool {
        distanceKm != nil || durationSeconds != nil || avgPace != nil || elevationGainM != nil
    }

    /// « 48 min », « 1 h 12 » — la durée telle qu'on la dit, pas un chronomètre à la seconde.
    var durationDisplay: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        return TimeFormat.duree(durationSeconds)
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
    /// Pourquoi ce compte est proposé — « club » ou « follower ». Non nil seulement dans les
    /// suggestions : une liste de noms sans explication ressemble à un annuaire, et on ne suit
    /// pas un annuaire.
    var reason: String?
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

/// Rendu par `createClub`. Ne porte plus de code d'invitation : on rejoint un club par son nom.
struct ClubCreatedResponse: Decodable {
    var id: String
    var name: String
}

struct ClubJoinedResponse: Decodable {
    var id: String
    var name: String
}

enum ClubServiceError: Error {
    case network(Error)
    case badResponse(Int, String)
    case notSignedIn

    /// La phrase à afficher vit sur `PanneReseau`, et non ici.
    ///
    /// Elle y a déménagé parce que les trois services — Club, authentification, coach — portent
    /// chacun les mêmes formes d'erreur, et qu'un classificateur qui ne connaît qu'une seule des
    /// trois énumérations renvoie « RUNUP ne répond pas » pour une vraie coupure de réseau
    /// survenue sur les deux autres. C'était le cas de cette fonction.

    /// Le texte a été refusé par le filtre de contenu, et non par une panne.
    ///
    /// La distinction compte pour la personne en face : dans un cas il faut réécrire, dans l'autre
    /// réessayer. Les confondre en « une erreur est survenue » la laisse relancer indéfiniment un
    /// texte qui ne passera jamais.
    var isObjectionableContent: Bool {
        guard case let .badResponse(status, body) = self else { return false }
        return status == 422 && body.contains("objectionable_content")
    }
}

/// Talks to RunUp's real club backend (`api/clubs/*.js`, `api/activities/*.js`) — replaces
/// `ClubMockData`. Every call needs a session token from `AuthService`, since a club only means
/// something once there's a real account behind it.
struct ClubService {
    var auth: AuthService
    private static let baseURL = URL(string: "https://runup-nu.vercel.app")!

    /// Les gestes délibérés du Club, et la liste fermée de ce qui en est un.
    ///
    /// Ici plutôt que dans chaque vue : ce service est le passage obligé de tous les appels du
    /// Club, donc un geste ne peut pas être ajouté demain en oubliant de le compter — alors
    /// qu'une vue nouvelle n'a aucune raison de penser à l'analytique. Et compté APRÈS l'appel
    /// réussi : un kudos qui n'est jamais arrivé au serveur n'a pas eu lieu.
    ///
    /// Ce qui n'y figure pas, et pourquoi, est écrit en entier sur `Analytics.EventName
    /// .clubActionTaken` — en deux mots : ni les publications automatiques (elles partent après
    /// chaque course et mesureraient l'app, pas le Club), ni les suppressions, ni les gestes de
    /// sécurité (un club qu'on fuit paraîtrait vivant).
    private enum Geste: String {
        case kudos
        case commentaire = "comment"
        case itineraireRendu = "route_published"
        case itineraireGarde = "route_saved"
        case defi = "challenge_created"
        case sortie = "event_created"
        case jySerai = "event_rsvp"
        case abonnement = "follow"
    }

    private func compte(_ geste: Geste) {
        Analytics.shared.track(.clubActionTaken, ["kind": .string(geste.rawValue)])
    }

    func fetchBoard() async throws -> ClubBoard {
        try await send(path: "api/clubs/mine", method: "GET")
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
        let challenge: ClubChallenge = try await send(
            path: "api/clubs/createChallenge",
            method: "POST",
            body: ["clientId": clientId.uuidString, "title": title, "targetKm": targetKm, "endDate": formatter.string(from: endDate)]
        )
        compte(.defi)
        return challenge
    }

    /// Proposes a sortie de groupe — the server auto-RSVPs the creator and pushes the club.
    /// `clientId` defaults to a fresh UUID, same idempotency pattern as `createChallenge` above.
    /// `repeatsWeekly` et `paceGroups` en fin de liste avec une valeur par défaut : un
    /// initialiseur Swift se remplit dans l'ordre déclaré, et les insérer au milieu aurait
    /// demandé de retoucher chaque appel pour rien.
    func createEvent(clientId: UUID = UUID(), title: String, location: String?, startsAt: Date,
                     repeatsWeekly: Bool = false, paceGroups: [String] = []) async throws -> ClubEvent {
        var body: [String: Any] = [
            "clientId": clientId.uuidString,
            "title": title,
            "startsAt": ISO8601DateFormatter().string(from: startsAt),
        ]
        if repeatsWeekly { body["repeatsWeekly"] = true }
        if !paceGroups.isEmpty { body["paceGroups"] = paceGroups }
        if let location, !location.isEmpty { body["location"] = location }
        let event: ClubEvent = try await send(path: "api/clubs/createEvent", method: "POST", body: body)
        compte(.sortie)
        return event
    }

    /// Toggles "J'y serai" — returns the new state + the fresh count.
    /// `paceGroup` dit AUSSI « je change de groupe » : répondre avec un autre groupe que le sien
    /// ne se décommande pas, ça déplace. Le serveur refuse un libellé qui n'est pas un de ceux
    /// de la séance.
    func toggleEventRsvp(eventId: String, paceGroup: String? = nil) async throws -> (going: Bool, count: Int, paceGroup: String?) {
        var body: [String: Any] = ["eventId": eventId]
        if let paceGroup { body["paceGroup"] = paceGroup }
        let response: RsvpResponse = try await send(path: "api/clubs/rsvpEvent", method: "POST", body: body)
        // Une bascule : seule la montée compte. Se désinscrire d'une sortie n'est pas un geste
        // d'usage, et compter les deux sens donnerait deux points à qui hésite.
        if response.going { compte(.jySerai) }
        return (response.going, response.count, response.paceGroup)
    }

    /// Cancels a sortie — creator only (the server enforces it).
    func deleteEvent(eventId: String) async throws {
        let _: OkResponse = try await send(path: "api/clubs/deleteEvent", method: "POST", body: ["eventId": eventId])
    }

    /// Rejoint un club trouvé par la recherche. L'identifiant ne remplace pas le code : il ne
    /// sert à rien à qui ne l'a pas obtenu par `searchClubs`, et le serveur revérifie que le
    /// club est bien ouvert.
    func joinClub(clubId: String) async throws -> ClubJoinedResponse {
        try await send(path: "api/clubs/join", method: "POST", body: ["clubId": clubId])
    }

    /// Cherche un club par son nom — accents, casse et traits d'union ignorés, comme pour les
    /// personnes. Ne rend que les clubs ouverts, et jamais celui dont on est déjà membre.
    func searchClubs(query: String) async throws -> [ClubSearchResult] {
        let response: ClubSearchResponse = try await send(path: "api/clubs/search", method: "GET", query: ["q": query])
        return response.items
    }

    /// Nommer un organisateur, ou lui retirer le rôle. RÉSERVÉ à qui a créé le club — pas aux
    /// organisateurs eux-mêmes : l'un d'eux pourrait sinon destituer la fondatrice, et un club se
    /// prendrait en otage en deux gestes. Le serveur applique la même règle.
    func setMemberRole(memberId: String, organiser: Bool) async throws {
        let _: OkResponse = try await send(
            path: "api/clubs/setRole", method: "POST",
            body: ["memberId": memberId, "role": organiser ? "organiser" : "member"]
        )
    }

    /// Ce que le club est, et où il court. Réservé à qui l'a créé — le serveur refuse les autres.
    func setClubProfile(description: String?, city: String?) async throws {
        let _: OkResponse = try await send(
            path: "api/clubs/setClubProfile", method: "POST",
            body: ["description": description ?? "", "city": city ?? ""]
        )
    }

    // MARK: - Le mur du club

    func fetchClubPosts() async throws -> [ClubPost] {
        let reponse: ClubPostsResponse = try await send(path: "api/clubs/posts", method: "GET")
        return reponse.posts
    }

    func postClubMessage(text: String, parentId: String? = nil) async throws {
        var body: [String: Any] = ["text": text]
        if let parentId { body["parentId"] = parentId }
        let _: CreatedResponse = try await send(path: "api/clubs/post", method: "POST", body: body)
    }

    /// Applaudir, ou retirer — le MÊME appel, comme partout ailleurs dans l'app. Rend l'état
    /// d'après, dit par le serveur : deviner localement, c'est afficher une main pleine sur un
    /// appareil et vide sur l'autre.
    func toggleClubPostKudos(postId: String) async throws -> Bool {
        let reponse: KudosResponse = try await send(path: "api/clubs/postKudos", method: "POST",
                                                    body: ["postId": postId])
        return reponse.kudoed
    }

    func deleteClubPost(postId: String) async throws {
        let _: OkResponse = try await send(path: "api/clubs/deletePost", method: "POST",
                                           body: ["postId": postId])
    }

    /// La bannière du club — un data URI JPEG déjà redimensionné par l'app, ou nil pour l'effacer.
    /// Réservée à qui a créé le club ; le serveur le revérifie.
    func setClubCover(dataURI: String?) async throws {
        // `NSNull()` et non `nil` : un optionnel vide emballé dans `Any` n'est pas une valeur
        // JSON, et `JSONSerialization` lève une exception Objective-C qu'aucun `try` Swift
        // n'attrape. Le serveur lit `null` comme une demande de retrait.
        let valeur: Any = dataURI.map { $0 as Any } ?? NSNull()
        let _: OkResponse = try await send(path: "api/clubs/cover", method: "POST",
                                           body: ["coverDataURI": valeur])
    }

    /// Ouvre ou ferme son club. Réservé à la personne qui l'a créé — le serveur refuse les autres.
    func setClubOpen(_ isOpen: Bool) async throws {
        let _: ClubOpenResponse = try await send(path: "api/clubs/setOpen", method: "POST", body: ["isOpen": isOpen])
    }

    func leaveClub() async throws {
        let _: OkResponse = try await send(path: "api/clubs/leave", method: "POST")
    }

    /// LE MUR : tout ce qui arrive, d'où que ça vienne.
    ///
    /// `scope` restreint — « tout », « club », « amis », « courses ». Il ne sert pas à TROUVER
    /// (c'est le travail du fil complet) mais à répondre à une question précise.
    ///
    /// `avant` est la date de la DERNIÈRE entrée déjà affichée — sortie ou message de course,
    /// peu importe : le serveur applique le même curseur aux deux sources, donc repartir de la
    /// plus ancienne des deux ne saute rien. Nil demande la première page.
    func fetchWall(scope: String = "tout", avant: Date? = nil) async throws -> WallPage {
        var query = ["scope": scope]
        if let avant { query["before"] = ISO8601DateFormatter().string(from: avant) }
        return try await send(path: "api/activities/wall", method: "GET", query: query)
    }

    /// UNE SORTIE, EN ENTIER.
    ///
    /// Un appel à part, et pas trois champs de plus dans le fil : les splits et les altitudes
    /// d'une sortie pèsent plus que tout le reste de sa carte, et le fil en charge cinquante
    /// d'un coup. On ne paie ce poids que pour la sortie qu'on ouvre vraiment.
    func fetchActivityDetail(id: String) async throws -> ActivityDetail {
        try await send(path: "api/activities/detail", method: "GET", query: ["id": id])
    }

    /// LA PAGE PUBLIQUE D'UN CLUB, SANS JETON.
    ///
    /// Le seul appel de l'app qui n'en demande pas, parce que c'est le seul point d'entrée du
    /// serveur qui n'en demande pas : on arrive ici depuis un lien, avant d'être connectée,
    /// peut-être même avant d'avoir un compte. Rend `nil` plutôt que de lever : un lien mort ne
    /// doit pas faire apparaître une erreur à quelqu'un qui vient juste d'ouvrir l'app.
    static func clubPublic(id: String) async -> PublicClub? {
        var url = baseURL.appending(path: "api/clubs/public")
        url.append(queryItems: [URLQueryItem(name: "id", value: id)])
        guard let (data, reponse) = try? await URLSession.shared.data(from: url),
              let http = reponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        return try? JSONDecoder().decode(PublicClub.self, from: data)
    }

    /// CE QU'UN CLUB A ET QU'UN CLASSEMENT N'A PAS : ce qu'il prépare, et ce qu'il a fait de
    /// mieux. Un appel à part du tableau de bord, qui part quand l'aperçu s'affiche.
    func fetchClubHighlights() async throws -> ClubHighlights {
        try await send(path: "api/clubs/highlights", method: "GET")
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
        if response.kudoed { compte(.kudos) }
        return response.kudoed
    }

    /// Oldest-first — a comment thread reads top-down, same as any chat/comment UI.
    func fetchComments(activityId: String) async throws -> [CommentItem] {
        let response: CommentsResponse = try await send(path: "api/activities/comments", method: "GET", query: ["activityId": activityId])
        return response.items
    }

    @discardableResult
    func postComment(activityId: String, text: String) async throws -> CommentItem {
        let comment: CommentItem = try await send(path: "api/activities/comments", method: "POST", body: ["activityId": activityId, "text": text])
        compte(.commentaire)
        return comment
    }

    /// Renomme sa propre sortie, lui met une note, ou lui retire son tracé.
    ///
    /// Le corps porte l'état FINAL des champs modifiables, pas seulement ceux qui changent : un
    /// titre vidé veut dire « plus de titre ». C'est ce que produit un formulaire, qui est le seul
    /// appelant — et la seule alternative, un `PATCH` partiel, obligerait à distinguer « absent »
    /// de « vidé » des deux côtés du réseau.
    func updateActivity(activityId: String, title: String?, note: String?, removeRoute: Bool) async throws {
        var body: [String: Any] = ["activityId": activityId, "removeRoute": removeRoute]
        if let title, !title.isEmpty { body["title"] = title }
        if let note, !note.isEmpty { body["note"] = note }
        let _: OkResponse = try await send(path: "api/activities/update", method: "POST", body: body)
    }

    /// Posts one completed activity to the club feed and credits its XP to the account's real
    /// server-side total. `clientId` is a fresh UUID per call so a retried request (flaky
    /// network) never double-counts the XP or duplicates the feed entry — see
    /// `api/activities/create.js`. `metrics` (run activities only) feeds real club-challenge
    /// progress server-side and the KM / ALLURE / D+ line on the feed card.
    ///
    /// `trace` est DÉJÀ rogné : il vient de `RouteGeometry.feedTrace`, appelé une seule fois, au
    /// moment où la sortie entre dans la file d'envoi (`postClubActivity`). Le rognage n'est pas
    /// idempotent — l'appliquer une seconde fois retirerait 300 m de plus à chaque bout — donc il
    /// ne peut pas vivre à la fois ici et là-bas. Il vit là-bas, parce que c'est aussi ce qui est
    /// écrit sur le disque en attendant le réseau : la file ne garde jamais un tracé complet.
    func postActivity(clientId: UUID = UUID(), type: String, text: String, xpEarned: Int, contentKey: String? = nil, metrics: ActivityMetrics = .none, trace: [RunRecord.RoutePoint] = []) async throws {
        var body: [String: Any] = ["clientId": clientId.uuidString, "type": type, "text": text, "xpEarned": xpEarned]
        // `text` part quand même : c'est lui que reçoit la notification push, composée côté
        // serveur, qui n'a aucune langue de destinataire à consulter. `contentKey` s'y ajoute pour
        // le fil, où l'appareil qui lit peut, lui, faire mieux.
        if let contentKey { body["contentKey"] = contentKey }
        // Chaque métrique n'est envoyée que si elle a été réellement mesurée : une clé absente
        // devient NULL en base, ce que le fil sait afficher comme « pas de donnée ». Envoyer 0
        // ferait apparaître « 0 D+ » sur une sortie dont le dénivelé n'a simplement jamais été
        // capté.
        if let distanceKm = metrics.distanceKm { body["distanceKm"] = distanceKm }
        if let durationSeconds = metrics.durationSeconds { body["durationSeconds"] = durationSeconds }
        if let avgPace = metrics.avgPace { body["avgPace"] = avgPace }
        if let elevationGainM = metrics.elevationGainM { body["elevationGainM"] = elevationGainM }
        if metrics.isPersonalRecord { body["isPersonalRecord"] = true }
        // Absente plutôt que vide quand la sortie est trop courte pour un tracé rogné : la colonne
        // reste NULL, et la carte du fil s'affiche sans dessin au lieu d'un cadre vide.
        if trace.count > 1 {
            body["routePreview"] = trace.map { [$0.lat, $0.lng] }
            // LES ALTITUDES VOYAGENT À CÔTÉ DU TRACÉ, PAS DEDANS.
            //
            // Les glisser dans les mêmes tableaux en ferait des triplets, et toutes les versions
            // de l'app déjà installées décodent ce champ en paires STRICTES (`$0.count == 2`) :
            // leur tracé aurait cessé de se dessiner du jour au lendemain, en silence. Un champ
            // à part s'ignore tout seul.
            //
            // Même longueur que le tracé, trous compris — le serveur refuse en entier une liste
            // d'une autre longueur, parce qu'un profil décalé d'un cran est un profil faux.
            let altitudes = trace.map { $0.altitude }
            if altitudes.contains(where: { $0 != nil }) {
                // `NSNull()` et non `nil` : un optionnel vide emballé dans `Any` n'est pas une
                // valeur JSON, et `JSONSerialization` lève une exception Objective-C qu'aucun
                // `try` Swift n'attrape (la même qui terminait l'app en retirant sa photo).
                body["routeAltitudes"] = altitudes.map { (a: Double?) -> Any in
                    guard let a else { return NSNull() }
                    return a
                }
            }
        }
        // Les kilomètres un par un, le cœur, les calories. Chacun absent plutôt que nul.
        if !metrics.splits.isEmpty { body["splits"] = metrics.splits }
        if let avgHeartRate = metrics.avgHeartRate, avgHeartRate > 0 { body["avgHeartRate"] = avgHeartRate }
        if let kcal = metrics.kcal, kcal > 0 { body["kcal"] = kcal }
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
        compte(.itineraireRendu)
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
        if saved { compte(.itineraireGarde) }
        return response.savesCount
    }

    /// Attache (ou retire) la photo d'un itinéraire dont je suis l'autrice.
    ///
    /// Séparé de `publishRoute` volontairement : la photo a besoin de l'identifiant de
    /// l'itinéraire, donc elle ne peut partir qu'après. Et surtout, un échec d'envoi de photo ne
    /// doit pas emporter la publication avec lui — un itinéraire sans photo reste utile, une
    /// publication perdue ne l'est pas.
    @discardableResult
    /// Pose ou retire la photo d'une sortie. `nil` la retire — sans condition, parce que
    /// quelqu'un qui réalise après coup que l'image en dit trop ne doit pas avoir à choisir entre
    /// la garder et effacer sa sortie.
    func setActivityPhoto(activityId: String, dataURI: String?) async throws -> String? {
        let response: RoutePhotoResponse = try await send(
            path: "api/activities/photo", method: "POST",
            body: ["activityId": activityId, "photoDataURI": Self.pourJSON(dataURI)]
        )
        return response.photoUrl
    }

    func setRoutePhoto(routeId: String, dataURI: String?) async throws -> String? {
        let response: RoutePhotoResponse = try await send(
            path: "api/activities/routePhoto", method: "POST",
            body: ["routeId": routeId, "photoDataURI": Self.pourJSON(dataURI)]
        )
        return response.photoUrl
    }

    /// `nil` rendu en `NSNull`, LE SEUL NIL QUE JSON ACCEPTE.
    ///
    /// `dataURI as Any` avec un optionnel vide range un `Optional<String>.none` dans le
    /// dictionnaire. `JSONSerialization` ne le considère pas comme un objet JSON valide et lève
    /// une exception Objective-C — que Swift ne rattrape pas : l'app S'ARRÊTE, elle ne rend pas
    /// une erreur. C'est ce qu'écrivait `setRoutePhoto`, sans conséquence jusqu'ici parce que son
    /// unique appelant garde un `if let` et ne passe jamais rien de vide. Retirer la photo d'une
    /// sortie, en revanche, consiste précisément à passer `nil` — le piège était armé pour le
    /// prochain appelant, qui est celui que je viens d'écrire.
    ///
    /// Et `null` ne peut pas être remplacé par une clé ABSENTE : côté serveur, absente veut dire
    /// « ne touche à rien », `null` veut dire « retire-la ». Les deux routes lisent la différence.
    private static func pourJSON(_ valeur: String?) -> Any {
        valeur ?? NSNull()
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

    /// Les gens qu'on n'a pas besoin de chercher : les membres de ses clubs qu'elle ne suit pas
    /// encore, et celles et ceux qui la suivent sans retour.
    ///
    /// La meilleure recherche est celle qu'on n'a pas à taper. L'écran affichait « Personne à
    /// suivre pour l'instant » et un champ de recherche à quelqu'un dont le club était plein de
    /// gens à suivre : le serveur savait déjà qui proposer, personne ne le lui demandait.
    /// La page de quelqu'un : qui elle est, ses chiffres, ses badges, et ses dernières sorties
    /// quand elle les laisse voir. Un compte bloqué d'un côté ou de l'autre rend 404, exprès
    /// indistinguable d'un compte qui n'existe pas.
    func fetchProfile(userId: String) async throws -> PublicProfilePage {
        try await send(path: "api/friends/profile", method: "GET", query: ["userId": userId])
    }

    func suggestions() async throws -> [PublicUser] {
        let response: PublicUserListResponse = try await send(path: "api/friends/suggestions", method: "GET")
        return response.items
    }

    /// Retrouve, parmi les comptes existants, ceux dont l'adresse est dans le carnet d'adresses —
    /// à partir d'empreintes, jamais d'adresses.
    ///
    /// Le hachage a lieu sur le téléphone (`ContactMatcher`), et c'est ce qui rend l'échange
    /// acceptable : le serveur reçoit des empreintes SHA-256, ne peut pas remonter aux adresses,
    /// et ne garde rien de ce qu'on lui envoie. Le carnet d'adresses ne quitte jamais l'appareil.
    func matchContacts(emailHashes: [String]) async throws -> [PublicUser] {
        guard !emailHashes.isEmpty else { return [] }
        let response: PublicUserListResponse = try await send(
            path: "api/friends/matchContacts", method: "POST", body: ["hashes": emailHashes]
        )
        return response.items
    }

    /// Follows a real account — instant ("accepted") unless they've gone private, in which case
    /// the server returns "pending" and she'll sit in their incoming requests until approved.
    @discardableResult
    func followUser(userId: String) async throws -> String {
        let response: FollowStatusResponse = try await send(path: "api/friends/follow", method: "POST", body: ["userId": userId])
        // Compté même quand le compte est privé et que la demande reste en attente : le geste a
        // été fait, et c'est lui qu'on mesure, pas la réponse de l'autre.
        compte(.abonnement)
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
    ///
    /// `name` est le PRÉNOM, et il ne peut pas être vidé : la colonne est `NOT NULL` côté
    /// serveur, qui refuse une chaîne vide par un 400. Il est modifiable depuis que « Se
    /// connecter avec Apple » s'est révélé muet sur le nom dès la deuxième autorisation — les
    /// comptes concernés étaient rangés sous « Coureur », introuvables par leur vrai prénom et
    /// incorrigibles.
    func updateProfile(name: String? = nil, username: String? = nil, lastName: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let username { body["username"] = username }
        if let lastName { body["lastName"] = lastName }
        let _: OkResponse = try await send(path: "api/friends/updateProfile", method: "POST", body: body)
    }

    // MARK: - Courses (chaque course officielle a sa page)

    /// Cherche une course par son nom ou sa ville. Ne rend jamais une course passée : une page de
    /// course sert à la préparer, et une fois qu'elle a eu lieu elle n'a plus personne à réunir.
    func searchRaces(query: String) async throws -> [RaceEvent] {
        let response: RaceListResponse = try await send(path: "api/races/search", method: "GET", query: ["q": query])
        return response.items
    }

    /// Ce qu'on propose quand rien n'est tapé : les courses les plus suivies qui approchent, et
    /// jamais celles qu'on prépare déjà. La meilleure recherche est celle qu'on n'a pas à taper.
    func upcomingRaces() async throws -> [RaceEvent] {
        let response: RaceListResponse = try await send(path: "api/races/upcoming", method: "GET")
        return response.items
    }

    /// Les courses que je prépare. Il peut y en avoir plusieurs — un 10 km en mars et un marathon
    /// en octobre, c'est même le cas le plus courant d'une saison.
    func myRaces() async throws -> [RaceEvent] {
        let response: RaceListResponse = try await send(path: "api/races/mine", method: "GET")
        return response.items
    }

    func racePage(raceId: String) async throws -> RacePage {
        try await send(path: "api/races/page", method: "GET", query: ["raceId": raceId])
    }

    /// Crée une course, OU rend celle qui existait déjà.
    ///
    /// Le serveur ne refuse pas un nom déjà pris : il renvoie la course existante avec
    /// `created: false`. Toute la valeur de la fonctionnalité tient à ce que deux personnes qui
    /// préparent la même course atterrissent sur la MÊME page — un refus les laisserait chacune
    /// sur la sienne.
    func createRace(name: String, city: String?, raceDate: String, distanceKm: Double?,
                    elevationGainM: Int?, discipline: String, website: String?) async throws -> RaceEvent {
        var body: [String: Any] = ["name": name, "raceDate": raceDate, "discipline": discipline]
        if let city, !city.isEmpty { body["city"] = city }
        if let distanceKm { body["distanceKm"] = distanceKm }
        if let elevationGainM { body["elevationGainM"] = elevationGainM }
        if let website, !website.isEmpty { body["website"] = website }
        let response: RaceCreatedResponse = try await send(path: "api/races/create", method: "POST", body: body)
        return response.race
    }

    /// Suivre une course, ou mettre à jour ce qu'on y a déclaré — c'est le même appel, donc
    /// cocher « je cherche un partenaire » plus tard ne demande pas de se désinscrire d'abord.
    ///
    /// `sharesTraining` est un choix explicite : quand il est faux, le serveur ne CALCULE même pas
    /// le volume d'entraînement, il ne se contente pas de ne pas l'envoyer.
    func followRace(raceId: String, targetChrono: String?, targetPaceSecPerKm: Int?,
                    sharesTraining: Bool, lookingForPartner: Bool) async throws {
        var body: [String: Any] = [
            "raceId": raceId,
            "sharesTraining": sharesTraining,
            "lookingForPartner": lookingForPartner,
        ]
        if let targetChrono, !targetChrono.isEmpty { body["targetChrono"] = targetChrono }
        if let targetPaceSecPerKm { body["targetPaceSecPerKm"] = targetPaceSecPerKm }
        let _: OkResponse = try await send(path: "api/races/follow", method: "POST", body: body)
    }

    func unfollowRace(raceId: String) async throws {
        let _: OkResponse = try await send(path: "api/races/unfollow", method: "POST", body: ["raceId": raceId])
    }

    /// Écrit dans le fil de la course. `kind` vaut « message », « partner », « bib_offer » ou
    /// « bib_wanted » ; une réponse (`parentId` non nil) est toujours un simple message.
    func postToRace(raceId: String, kind: String, text: String, parentId: String? = nil) async throws {
        var body: [String: Any] = ["raceId": raceId, "kind": kind, "text": text]
        if let parentId { body["parentId"] = parentId }
        let _: RacePostCreatedResponse = try await send(path: "api/races/post", method: "POST", body: body)
    }

    /// Retire son annonce : le dossard est parti, le partenaire est trouvé. On marque, on ne
    /// supprime pas — les réponses sous une annonce effacée deviendraient des messages sans
    /// contexte.
    /// Applaudir un message du mur d'une course, ou retirer son applaudissement — c'est le MÊME
    /// appel. Le serveur rend le compte réel plutôt qu'un « +1 » appliqué ici : deux personnes qui
    /// applaudissent en même temps feraient sinon diverger les deux écrans.
    func toggleRacePostKudos(postId: String) async throws -> (kudoed: Bool, kudos: Int) {
        let reponse: RaceKudosResponse = try await send(path: "api/races/kudos", method: "POST",
                                                        body: ["postId": postId])
        return (reponse.kudoed, reponse.kudos)
    }

    /// Ce qu'on sait d'un itinéraire et que le tracé ne dit pas : les racines après le pont, la
    /// fontaine qui marche, le chemin fermé en hiver.
    func fetchRouteComments(routeId: String) async throws -> [CommentItem] {
        let reponse: CommentsResponse = try await send(path: "api/activities/routeComments",
                                                       method: "GET", query: ["routeId": routeId])
        return reponse.items
    }

    func postRouteComment(routeId: String, text: String) async throws {
        let _: RacePostCreatedResponse = try await send(path: "api/activities/routeComment",
                                                        method: "POST",
                                                        body: ["routeId": routeId, "text": text])
    }

    func closeRacePost(postId: String) async throws {
        let _: OkResponse = try await send(path: "api/races/closePost", method: "POST", body: ["postId": postId])
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
            // Le seul endroit de l'app par où passent tous les appels authentifiés au Club, donc
            // le seul où un jeton refusé peut être constaté une fois pour toutes. Voir
            // `AuthService.sessionRejected` : on l'observe, on n'efface rien.
            if status == 401 || status == 403 { await auth.markSessionRejected() }
            throw ClubServiceError.badResponse(status, String(data: data, encoding: .utf8) ?? "")
        }

        // Le jeton a servi : s'il avait été refusé plus tôt, ce n'est plus vrai.
        await auth.markSessionAccepted()
        // Et s'il approchait de sa fin, le serveur vient d'en joindre un neuf. L'en-tête est lu
        // ICI, hors de l'acteur principal, et seule la chaîne y saute : `HTTPURLResponse` est une
        // classe qui ne traverse pas les acteurs, une `String?` oui.
        await auth.adopt(renewedToken: http.value(forHTTPHeaderField: SessionRenewal.header))

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

/// Ce que rend le mur : les sorties, et les messages des pages de course que je prépare.
///
/// DEUX TABLEAUX ET NON UN SEUL, et c'est délibéré : une sortie et un message de course sont deux
/// formes différentes. Les forcer dans la même rendrait chaque champ optionnel des deux côtés, et
/// la carte devrait deviner ce qu'elle affiche. Le client les entrelace par date.
struct WallPage: Decodable {
    var items: [FeedItem]
    var racePosts: [WallRacePost]
    /// Vrai quand les DEUX sources sont épuisées. Une page vide de sorties ne suffit pas à
    /// conclure : elle peut encore porter deux messages de course.
    ///
    /// OPTIONNEL, ET PAS « = false » : Swift synthétise `decode` pour toute propriété non
    /// optionnelle, valeur par défaut ou non (voir ci_scripts/check_decodage.py). Un serveur
    /// pas encore déployé ne renvoie pas la clé, et le fil entier échouerait à se décoder pour
    /// un drapeau de pagination. Nil se lit « on ne sait pas » : on redemande une page pour
    /// rien, une fois, plutôt que de ne plus rien afficher du tout.
    var fin: Bool?
}

/// UN MESSAGE DU MUR DU CLUB.
///
/// Le club pouvait publier des sorties, applaudir et commenter. Il ne pouvait pas PARLER : « qui
/// a un dossard en trop pour dimanche ? », « la berge est fermée jusqu'au 12 », « bienvenue à
/// Sarah » — rien de tout cela n'est une sortie, rien n'est un commentaire sous la sortie de
/// quelqu'un, et il n'existait aucun endroit pour l'écrire.
///
/// La forme est celle de `RacePost`, volontairement : deux murs qui se ressemblent se corrigent
/// ensemble. Sans le genre ni le drapeau « réglé », qui appartiennent aux dossards d'une course.
struct ClubPost: Decodable, Identifiable, Hashable {
    var id: String
    /// Non nil pour une réponse. Deux niveaux, pas plus : au-delà on ne sait plus à qui l'on parle.
    var parentId: String?
    var text: String
    var isMine: Bool
    var kudos: Int
    var kudoedByMe: Bool
    var createdAt: Date
    var author: PublicUser
}

struct ClubPostsResponse: Decodable {
    var posts: [ClubPost]
}

/// Ce qu'un club montre de lui à quelqu'un qui n'est pas encore entré. Aucun nom de membre :
/// la page d'où vient cette structure est publique au sens le plus fort — partageable, lisible
/// par n'importe qui — et personne n'a consenti à y figurer en rejoignant un club.
struct PublicClub: Decodable {
    var id: String
    var name: String
    var city: String?
    var description: String?
    var coverUrl: String?
    var memberCount: Int
}

/// CE QUE LE CLUB PRÉPARE, ET CE QU'IL A FAIT DE MIEUX.
///
/// Un classement hebdomadaire dit qui court le plus. Il ne dit ni ce que le club prépare, ni ce
/// qu'il a déjà réussi — deux choses qui ne demandaient aucune donnée nouvelle : elles étaient
/// dans les courses suivies et dans les sorties publiées, elles n'avaient jamais été regardées
/// ensemble.
struct ClubHighlights: Decodable {
    var races: [ClubRace]
    var records: [ClubRecord]
    /// Le seul record qui n'appartienne à personne : ce que le club a fait ENSEMBLE dans sa
    /// meilleure semaine. Nil tant qu'aucune semaine ENTIÈRE n'a été courue — celle en cours est
    /// exclue, sinon un lundi matin battrait le record de l'année.
    var bestWeek: ClubBestWeek?
}

struct ClubBestWeek: Decodable {
    var startsAt: Date
    var km: Double
    var runners: Int
}

/// Une course que plusieurs membres préparent. `race` est le MÊME `RaceEvent` que partout
/// ailleurs : il sait déjà écrire sa date et compter les jours qui restent, deux calculs qui ont
/// coûté deux bugs de fuseau et qu'on ne réécrit pas pour un deuxième écran.
struct ClubRace: Decodable, Identifiable {
    var race: RaceEvent
    var members: Int
    var runners: [ClubRunner]
    var id: String { race.id }
}

/// Juste de quoi dessiner un visage et ouvrir une page. Pas un `PublicUser` : celui-ci porte des
/// champs — compte privé, relation de suivi — qu'une pile d'avatars n'a aucune raison de
/// demander au serveur.
struct ClubRunner: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var avatarUrl: String?
    var avatarBase64: String?
}

/// Un record du club : une vraie sortie, avec qui l'a courue.
struct ClubRecord: Decodable, Identifiable {
    /// « distance » | « allure » | « denivele ».
    var genre: String
    var activityId: String
    var userId: String
    var name: String
    var avatarUrl: String?
    var avatarBase64: String?
    var createdAt: Date
    var distanceKm: Double?
    var durationSeconds: Int?
    var elevationGainM: Int?
    /// Les secondes au kilomètre, CALCULÉES par le serveur depuis la durée et la distance.
    /// `avg_pace` est du texte (« 5:38 ») : trié comme tel, « 10:12 » passerait avant « 9:30 ».
    var secPerKm: Double?
    var id: String { genre }
}

/// LA SORTIE DÉROULÉE.
///
/// Ce que `FeedItem` ne porte pas : les kilomètres un par un, le profil du terrain, le cœur et
/// les calories. Un `FeedItem` décrit une carte de fil ; celui-ci décrit une course.
///
/// Tout y est optionnel ou vide par défaut, et pas par prudence de façade : une sortie publiée
/// par une version de l'app qui n'envoyait pas encore ces champs, une séance saisie à la main,
/// une course sans montre cardio — les trois existent, et l'écran dit « pas mesuré » au lieu
/// d'afficher un zéro qui passerait pour une mesure.
struct ActivityDetail: Decodable, Identifiable {
    var id: String
    var userId: String
    var name: String
    var lastName: String?
    var username: String?
    var avatarUrl: String?
    var avatarBase64: String?
    var text: String
    var contentKey: String?
    var createdAt: Date
    var editedAt: Date?
    var distanceKm: Double?
    var durationSeconds: Int?
    var avgPace: String?
    var elevationGainM: Int?
    var isPersonalRecord: Bool
    var title: String?
    var note: String?
    var photoUrl: String?
    /// « m:ss » par kilomètre, dans l'ordre.
    var splits: [String]
    var avgHeartRate: Int?
    var kcal: Int?
    var kudos: Int
    var kudoedByMe: Bool
    var commentsCount: Int
    var isMine: Bool
    /// Le tracé, reconstruit à partir des deux champs que le serveur garde côte à côte : les
    /// paires lat/lng, et les altitudes dans le même ordre. Les altitudes manquent souvent — une
    /// sortie d'avant ce champ, ou un GPS dont la précision verticale n'était pas digne de foi.
    var route: [RunRecord.RoutePoint]
    var nomComplet: String {
        guard let lastName, !lastName.isEmpty else { return name }
        return "\(name) \(lastName)"
    }

    var localizedText: String {
        PhraseDeSortie.localisee(text: text, contentKey: contentKey, distanceKm: distanceKm)
    }

    var durationDisplay: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        return TimeFormat.duree(durationSeconds)
    }

    /// Y a-t-il quelque chose à DÉROULER ? Sans splits ni profil ni cardio, la page ne dirait
    /// rien de plus que la carte du fil, et il vaut mieux l'annoncer que la laisser ouvrir sur
    /// une répétition.
    var aDuDetail: Bool {
        !splits.isEmpty || avgHeartRate != nil || kcal != nil || route.contains { $0.altitude != nil }
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, name, lastName, username, avatarUrl, avatarBase64, text, contentKey
        case createdAt, editedAt, distanceKm, durationSeconds, avgPace, elevationGainM
        case isPersonalRecord, title, note, photoUrl, splits, avgHeartRate, kcal
        case kudos, kudoedByMe, commentsCount, isMine, routePreview, routeAltitudes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        avatarBase64 = try c.decodeIfPresent(String.self, forKey: .avatarBase64)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        contentKey = try c.decodeIfPresent(String.self, forKey: .contentKey)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
        distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm)
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        avgPace = try c.decodeIfPresent(String.self, forKey: .avgPace)
        elevationGainM = try c.decodeIfPresent(Int.self, forKey: .elevationGainM)
        isPersonalRecord = try c.decodeIfPresent(Bool.self, forKey: .isPersonalRecord) ?? false
        title = try c.decodeIfPresent(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        splits = try c.decodeIfPresent([String].self, forKey: .splits) ?? []
        avgHeartRate = try c.decodeIfPresent(Int.self, forKey: .avgHeartRate)
        kcal = try c.decodeIfPresent(Int.self, forKey: .kcal)
        kudos = try c.decodeIfPresent(Int.self, forKey: .kudos) ?? 0
        kudoedByMe = try c.decodeIfPresent(Bool.self, forKey: .kudoedByMe) ?? false
        commentsCount = try c.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0
        isMine = try c.decodeIfPresent(Bool.self, forKey: .isMine) ?? false

        // Le tracé et ses altitudes se rejoignent ICI, et seulement s'ils sont d'accord sur leur
        // longueur. Le serveur les échantillonne ensemble et refuse déjà les listes mal
        // appariées ; une vérification de plus coûte une ligne et évite de dessiner un profil
        // qui désignerait les mauvais kilomètres.
        let paires = try c.decodeIfPresent([[Double]].self, forKey: .routePreview) ?? []
        let altitudes = try c.decodeIfPresent([Double?].self, forKey: .routeAltitudes) ?? []
        if paires.count > 1, paires.allSatisfy({ $0.count >= 2 }) {
            let alignees = altitudes.count == paires.count ? altitudes : []
            route = paires.enumerated().map { index, p in
                RunRecord.RoutePoint(lat: p[0], lng: p[1],
                                     altitude: index < alignees.count ? alignees[index] : nil)
            }
        } else {
            route = []
        }
    }
}

/// Un message d'une page de course, tel qu'il apparaît dans le mur : il porte le NOM de sa course,
/// sinon il arriverait sans contexte au milieu des sorties.
struct WallRacePost: Decodable, Identifiable, Hashable {
    var id: String
    var raceId: String
    var raceName: String
    var raceDate: String
    var discipline: String
    var kind: String
    var text: String
    var closed: Bool
    var kudos: Int
    var kudoedByMe: Bool
    var createdAt: Date
    var author: PublicUser
}

private struct RsvpResponse: Decodable {
    var going: Bool
    var count: Int
    /// Le groupe retenu par le serveur — nil quand la séance n'en propose aucun, ou quand on
    /// vient de se décommander.
    var paceGroup: String?
}

private struct KudosResponse: Decodable {
    var kudoed: Bool
}

/// Ce que rend une création de message : le serveur répond 201 avec l'identifiant et la date, et
/// l'app recharge le mur — elle ne reconstruit pas la ligne de son côté, sinon deux appareils
/// afficheraient deux versions du même message.
private struct CreatedResponse: Decodable {
    var id: String
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

private struct ClubSearchResponse: Decodable {
    var items: [ClubSearchResult]
}

private struct ClubOpenResponse: Decodable {
    var isOpen: Bool
}

private struct PublicUserListResponse: Decodable {
    var items: [PublicUser]
}

private struct FollowStatusResponse: Decodable {
    var status: String
}

private struct RaceListResponse: Decodable {
    var items: [RaceEvent]
}

private struct RaceCreatedResponse: Decodable {
    var race: RaceEvent
    /// Faux quand la course existait déjà. L'app n'en fait rien d'autre qu'une mesure : voir
    /// `createRace`, où le doublon évité est précisément ce qu'on veut.
    var created: Bool
}

private struct RaceKudosResponse: Decodable {
    var kudoed: Bool
    var kudos: Int
}

private struct RacePostCreatedResponse: Decodable {
    var id: String
    var createdAt: Date
}
