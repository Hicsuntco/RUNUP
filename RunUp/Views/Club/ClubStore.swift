import Foundation
import Observation

/// LES DONNÉES DU CLUB ET CE QUI VA LES CHERCHER, sortis de `ClubView`.
///
/// # POURQUOI UN MAGASIN, ET PAS UNE VUE DE PLUS
///
/// `ClubView` faisait 2 721 lignes et portait trente états. Le relevé, région par région, dit
/// où est le nœud : six états sur trente sont touchés par trois régions ou plus — `board`,
/// `posts`, `feed`, `isLoading`, et les deux cibles de modération — et ce sont exactement les
/// données et le réseau. Tout le reste appartient à UNE région et pouvait rester où il était.
///
/// Découper les vues sans toucher à ces six-là donnait des fichiers plus courts et aussi noués
/// les uns aux autres qu'avant : chacun aurait eu besoin d'écrire dans l'état du voisin. Deux
/// régions sont déjà sorties sans magasin — le classement et, un temps, les pépites — et la
/// seconde a dû revenir, parce qu'elle portait sa propre donnée et son propre chargement.
///
/// # CE QUI EST ICI, ET CE QUI N'Y EST PAS
///
/// Ici : ce que le serveur rend, et les requêtes qui l'obtiennent. Pas ici : l'onglet affiché,
/// les feuilles ouvertes, les brouillons de saisie, les confirmations en attente. Un magasin
/// qui effacerait un champ de texte saurait trop de choses sur l'écran qui l'emploie — c'est
/// pourquoi `createClub` et `joinClub` rendent un booléen au lieu de vider la saisie.
///
/// # L'ÉTAT DE L'APPLICATION ENTRE PAR LE CONSTRUCTEUR
///
/// Onze des dix-huit fonctions lisent ou écrivent `appState` : le cache du tableau de bord, les
/// notifications, les compteurs vus du profil, les messages éphémères. Le passer à chaque
/// appel aurait voulu dire dix-huit signatures alourdies et autant d'appels — et surtout, les
/// corps auraient tous changé, ce qui transforme un déménagement vérifiable en réécriture.
///
/// Il est donc gardé. `ClubView` le construit dans son `init` à partir de l'environnement que
/// `SocialView` lui passe, et `@State` le garde en vie tant que l'écran existe. L'application
/// n'a qu'un `AppState`, créé au lancement : la référence ne peut pas devenir périmée.
@MainActor
@Observable
final class ClubStore {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    private var profile: UserProfile { appState.profile }
    private var auth: AuthService { appState.auth }
    private var clubService: ClubService { ClubService(auth: auth) }

    var board = ClubBoard(club: nil, leaderboard: [])

    /// SEULE DANS SON CLUB — et c'est alors son seul sujet.
    ///
    /// La règle était écrite deux fois mot pour mot dans `ClubView`, une fois dans l'Aperçu et
    /// une fois dans le fil (chantier 37). Elle y a été nommée une fois ; elle descend ici parce
    /// que le mur, en sortant dans son propre fichier, en avait besoin aussi — et la recopier
    /// une troisième fois aurait refait exactement le défaut qu'on venait de corriger.
    ///
    /// C'est un fait sur le club, pas sur un écran : c'est donc le magasin qui le porte.
    var seuleDansSonClub: Bool {
        board.club.map { $0.memberCount <= 1 } == true
    }

    /// LE MUR DU CLUB : ce qu'on se dit entre deux sorties. Les messages vivent dans le même
    /// onglet que les activités et s'y entrelacent par date — un mur à part aurait fait un
    /// quatrième onglet pour une conversation de dix lignes.
    var posts: [ClubPost] = []

    var feed: [FeedItem] = []

    var isLoading = true

    var errorMessage: String?

    var clubResultats: [ClubSearchResult] = []

    var clubSearchEnCours = false

    /// Les cinq clubs proposés quand le champ est vide. Chargés une fois par visite de l'écran :
    /// ils ne dépendent de rien qu'on tape, et les recharger à chaque frappe ferait une requête
    /// par lettre pour une liste qui ne bouge pas.
    var clubSuggestions: [ClubSearchResult] = []

    private var suggestionsChargees = false

    private var clubSearchTask: Task<Void, Never>?

    /// Set only when `syncBadgesIfNeeded` finds a key `badges` reports earned that isn't yet in
    /// `profile.seenBadgeKeys` — i.e. genuinely just crossed the threshold this load, not merely
    /// "earned at some point before this feature existed." Drives `BadgeUnlockedView`.
    var unlockedBadge: ClubBadge?

    /// Ce que le club prépare, et ce qu'il a fait de mieux. Chargé à part du tableau de bord :
    /// celui-ci part à chaque ouverture du Club, celui-là seulement quand l'aperçu s'affiche.
    var highlights: ClubHighlights?

    /// Y A-T-IL QUELQUE CHOSE À MONTRER DANS LES TROIS SECTIONS DE PÉPITES ?
    ///
    /// La question existe parce que `ClubHighlightsSections` les regroupe en un seul enfant de
    /// la pile de l'aperçu, là où elles en étaient trois. Trois sections vides ne laissent
    /// aucun blanc — une pile n'espace pas autour du vide ; une pile VIDE, elle, est un enfant
    /// de hauteur nulle que le parent espacerait quand même.
    ///
    /// La condition reprend donc celle de chaque section, et elle est tenue ICI, à côté de la
    /// donnée qui la décide, plutôt que dans la vue qui l'emploie.
    var aDesPepites: Bool {
        !(highlights?.races.isEmpty ?? true)
            || (highlights?.sessionHistory?.total ?? 0) > 0
            || !(highlights?.records.isEmpty ?? true)
            || highlights?.bestWeek != nil
    }

    func chargerLesPepites() async {
        if Demonstration.enCours {
            highlights = appState.cachedClubHighlights
            return
        }
        guard highlights == nil, auth.isSignedIn else { return }
        // Silencieux en cas d'échec, et c'est voulu : ce sont deux sections EN PLUS. Une
        // bannière d'erreur pour elles ferait croire que tout l'aperçu est en panne alors que
        // le niveau, la semaine, le défi et les sorties sont là.
        highlights = try? await clubService.fetchClubHighlights()
    }

    /// `badges` pour la même raison que dans `syncBadgesIfNeeded`, qui est appelé plus bas.
    func loadIfSignedIn(badges: [ClubBadge]) async {
        guard auth.isSignedIn else { return }
        // Opportunistic: retries anything still stuck in the local outbox from a prior failed
        // `postClubActivity` (see ClubActivityOutbox.swift) — e.g. a run posted on a spotty
        // connection right before she opened Club to check the leaderboard.
        appState.retryPendingClubActivities()
        // A cached board/feed from a prior visit (see `AppState.cachedClubBoard`) renders
        // immediately instead of blanking to the loading spinner on every single re-visit — the
        // fetch below still runs to catch up, it just doesn't need to gate the UI this time.
        if let cachedBoard = appState.cachedClubBoard {
            board = cachedBoard
            isLoading = false
        }
        if let cachedFeed = appState.cachedClubFeed {
            feed = cachedFeed
        }
        // EN DÉMONSTRATION, LE CACHE EST TOUT.
        //
        // Il n'y a pas de serveur en face d'un simulateur : les trois requêtes ci-dessous
        // échoueraient, et l'écran afficherait une ligne d'erreur en rose sous le classement —
        // dans la capture, en bonne place. Le club posé par `CaptureSeed` est déjà là, complet ;
        // il n'y a rien à aller chercher. Voir `Demonstration`.
        if Demonstration.enCours {
            posts = appState.cachedClubPosts ?? []
            isLoading = false
            return
        }
        errorMessage = nil
        // These three requests used to run one after another (refreshMe → fetchBoard → feed),
        // each paying its own network/cold-start latency on top of the last — the real cause of
        // the ~5s wait before this tab showed anything (the create/join form sat there the whole
        // time). None of them actually depends on another's result, so firing them concurrently
        // cuts the wait to the slowest single request instead of the sum of all three.
        // `Result` ET NON `try?`, ET C'EST TOUT L'OBJET DU CORRECTIF. `try?` efface la cause :
        // les deux branches d'erreur ci-dessous n'avaient plus qu'un `nil` à interpréter, donc
        // elles affirmaient « vérifie ta connexion » pour une session expirée comme pour un
        // serveur en panne. Voir `PanneReseau`.
        async let meAttempt = try? await auth.refreshMe()
        async let boardAttempt = chargeBoard()
        async let feedAttempt = chargeFeed()
        // Le mur part avec les trois autres plutôt qu'après : il appartient au même onglet que
        // les sorties, et une quatrième attente en série rendrait l'onglet Activité plus lent
        // que les deux autres pour une liste de dix lignes.
        async let murAttempt = try? await clubService.fetchClubPosts()
        let (_, boardResult, feedResult, murResult) = await (meAttempt, boardAttempt, feedAttempt, murAttempt)
        if let murResult { posts = murResult }

        switch boardResult {
        case .success(let chargé):
            board = chargé
            appState.cachedClubBoard = chargé
            syncBadgesIfNeeded(badges: badges)
            syncWeeklyTargetIfNeeded()
        case .failure(let echec):
            // Only surface the error when there's nothing already on screen to fall back to — a
            // background refresh failing quietly behind still-valid cached content beats replacing
            // it with an error banner over data that was fine a moment ago.
            if appState.cachedClubBoard == nil {
                errorMessage = PanneReseau.phrase(pour: echec)
            }
        }
        // Piggyback a kudos check on every Club tab open, not just when switching to the
        // "Fil d'activité" segment — otherwise a new kudos notification only ever surfaces if she
        // happens to tap into the feed specifically.
        switch feedResult {
        case .success(let chargé):
            feed = chargé
            appState.cachedClubFeed = chargé
            notifyNewKudos(in: chargé)
            notifyNewComments(in: chargé)
        case .failure(let echec):
            // Board can still have loaded fine while this alone failed — without this, a failed
            // feed fetch left `feed` empty with zero indication, so "Fil d'activité" read as a
            // genuinely empty club instead of a failed load.
            if errorMessage == nil, appState.cachedClubFeed == nil {
                errorMessage = PanneReseau.phrase(pour: echec)
            }
        }
        isLoading = false
    }

    /// Les deux chargements, rendus en `Result` pour garder la CAUSE de l'échec.
    ///
    /// Deux petites fonctions plutôt qu'un `do`/`catch` autour de chaque `async let` : `async let`
    /// veut une expression, et les deux appels doivent rester lancés en parallèle — c'est ce qui
    /// fait que l'onglet Club s'ouvre en un aller-retour et non deux.
    private func chargeBoard() async -> Result<ClubBoard, Error> {
        do { return .success(try await clubService.fetchBoard()) }
        catch { return .failure(error) }
    }

    private func chargeFeed() async -> Result<[FeedItem], Error> {
        do { return .success(try await clubService.fetchFeed()) }
        catch { return .failure(error) }
    }

    func loadFeed() async {
        // En démonstration, le mur vient de la graine : pas de serveur en face d'un simulateur.
        if Demonstration.enCours {
            posts = appState.cachedClubPosts ?? []
            return
        }
        do {
            feed = try await clubService.fetchFeed()
            notifyNewKudos(in: feed)
            notifyNewComments(in: feed)
        } catch {
            errorMessage = PanneReseau.phrase(pour: error)
        }
        // Le mur, à part et sans bruit : un onglet Activité qui afficherait une erreur parce que
        // le mur n'a pas répondu alors que les sorties sont là serait faux deux fois.
        posts = (try? await clubService.fetchClubPosts()) ?? posts
    }

    /// Real kudos notifications — compares each of *your own* posts' current kudos count against
    /// what was last seen (`profile.kudosSeenCounts`, keyed by activity id) and posts one bell
    /// notification per post that gained new kudos since. Only ever moves forward (kudos are
    /// additive from this client's point of view), so a post that lost kudos some other way isn't
    /// treated as new claps by mistake.
    private func notifyNewKudos(in feed: [FeedItem]) {
        guard let myId = auth.currentUser?.id else { return }
        for item in feed where item.userId == myId {
            let seen = profile.kudosSeenCounts[item.id] ?? 0
            if item.kudos > seen {
                let gained = item.kudos - seen
                appState.notify(
                    icon: "hands.clap.fill", colorHex: 0xFF3B6B,
                    title: String(localized: "Nouveaux encouragements"),
                    text: Pluriel.choisir(gained,
                        String(localized: "Quelqu'un a applaudi ta séance."),
                        String(localized: "\(gained) personnes ont applaudi ta séance."))
                )
            }
            profile.kudosSeenCounts[item.id] = item.kudos
        }
    }

    /// Rend `true` quand le club a bien été créé, pour que le champ de saisie — qui appartient
    /// à la vue et non au magasin — sache s'il doit se vider. C'était `newClubName = ""` ici :
    /// un magasin qui efface un champ de texte sait trop de choses sur l'écran qui l'emploie.
    @discardableResult
    func createClub(nom: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        var reussi = false
        do {
            _ = try await clubService.createClub(name: nom.trimmingCharacters(in: .whitespaces))
            // Inside the `do`, after the call succeeded — an attempt that 422'd on the name, or
            // never left the device, is not a club created.
            Analytics.shared.track(.clubCreated)
            // `reussi` EST POSÉ ICI ET NON APRÈS `fetchBoard`, parce que c'est là que
            // `newClubName = ""` se trouvait. Le club est créé ; si le rechargement du tableau
            // échoue ensuite, le nom reste tout de même effacé — le comportement d'avant.
            reussi = true
            board = try await clubService.fetchBoard()
        } catch ClubServiceError.badResponse(422, _) {
            errorMessage = String(localized: "Ce nom n'est pas autorisé — choisis-en un autre.")
        } catch {
            errorMessage = String(localized: "Impossible de créer le club.")
        }
        isLoading = false
        return reussi
    }

    /// Sets the club's active challenge and updates `board` immediately so the card on the main
    /// page reflects it without a full refetch. Throws (rather than setting `errorMessage`, which
    /// lives on the page underneath) so the create-challenge form — its own sheet stacked on top
    /// of "Gestion du club" — can show its own inline error.
    func createChallenge(title: String, targetKm: Double, endDate: Date) async throws {
        let challenge = try await clubService.createChallenge(title: title, targetKm: targetKm, endDate: endDate)
        board.challenge = challenge
    }

    /// Appelé par la carte « Rejoindre un club » quand elle apparaît.
    ///
    /// `suggestionsChargees` et non « la liste est vide » : un compte sans aucun club ouvert à
    /// proposer rendrait une liste vide, et la liste vide relancerait la requête à chaque
    /// réapparition de la carte. On retient qu'on a demandé, pas ce qu'on a reçu.
    func chargerLesClubsSuggeres() async {
        guard auth.isSignedIn, !suggestionsChargees else { return }
        suggestionsChargees = true
        clubSuggestions = await clubService.suggestedClubs()
    }

    func chercherUnClub(_ texte: String) {
        clubSearchTask?.cancel()
        let propre = texte.trimmingCharacters(in: .whitespaces)
        guard propre.count >= 2 else {
            clubResultats = []
            clubSearchEnCours = false
            return
        }
        clubSearchEnCours = true
        clubSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let trouves = (try? await clubService.searchClubs(query: propre)) ?? []
            guard !Task.isCancelled else { return }
            await MainActor.run {
                clubResultats = trouves
                clubSearchEnCours = false
            }
        }
    }

    /// Rend `true` quand le club a bien été rejoint — même raison que `createClub` : le champ
    /// de recherche appartient à la vue.
    @discardableResult
    func joinClub(_ club: ClubSearchResult) async -> Bool {
        isLoading = true
        var reussi = false
        errorMessage = nil
        do {
            _ = try await clubService.joinClub(clubId: club.id)
            // Same placement rule as `createClub` — a club that closed between the search and
            // the tap (404) isn't a join. Created vs joined are tracked apart on purpose: a club
            // that fills up and a club that gets created are two different signals, and one
            // without the other says the invitation isn't landing.
            Analytics.shared.track(.clubJoined)
            clubResultats = []
            // Même règle que dans `createClub` : posé là où `clubQuery = ""` se trouvait.
            reussi = true
            board = try await clubService.fetchBoard()
        } catch ClubServiceError.badResponse(404, _) {
            // Le club a été fermé ou supprimé entre la recherche et l'appui. Rare, mais c'est
            // la seule chose que ce code puisse vouloir dire maintenant.
            errorMessage = String(localized: "Ce club n'est plus ouvert.")
        } catch {
            errorMessage = String(localized: "Impossible de rejoindre ce club.")
        }
        isLoading = false
        return reussi
    }

    func leaveClub() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            try await clubService.leaveClub()
            board = ClubBoard(club: nil, leaderboard: [])
            feed = []
            // Without this, re-opening Club after leaving would briefly show the OLD club's cached
            // board/feed (see AppState.cachedClubBoard) before the next fetch caught up.
            appState.cachedClubBoard = nil
            appState.cachedClubFeed = nil
            // Both dictionaries are keyed by activity UUIDs from the club she's leaving — none of
            // those ids can ever appear in a feed she can see again, so without this they'd just
            // accumulate permanently in UserProfile across every club she's ever cycled through.
            profile.kudosSeenCounts.removeAll()
            profile.commentsSeenCounts.removeAll()
        } catch {
            errorMessage = String(localized: "Impossible de quitter le club.")
        }
        isLoading = false
    }

    func toggleKudos(_ item: FeedItem) async {
        guard let index = feed.firstIndex(where: { $0.id == item.id }) else { return }
        let wasKudoed = feed[index].kudoedByMe
        feed[index].kudoedByMe.toggle()
        feed[index].kudos += wasKudoed ? -1 : 1
        do {
            try await clubService.toggleKudos(activityId: item.id)
        } catch {
            // Roll back on failure — the optimistic toggle above was wrong. With feedback: a clap
            // that silently un-claps itself just reads as a broken button.
            //
            // L'index est RECHERCHÉ À NOUVEAU, jamais celui capturé avant l'`await` : le fil a pu
            // rétrécir pendant la requête (suppression d'une de ses propres activités, blocage
            // d'un membre, rafraîchissement qui rend une liste plus courte), et écrire à l'ancien
            // index terminait alors le processus. Si l'activité a disparu entre-temps, il n'y a
            // plus rien à annuler — l'entrée n'est plus à l'écran.
            guard let current = feed.firstIndex(where: { $0.id == item.id }) else { return }
            feed[current].kudoedByMe = wasKudoed
            feed[current].kudos += wasKudoed ? 1 : -1
            // Un kudos perdu parce que la session a expiré n'a rien à voir avec le réseau.
            appState.toast(PanneReseau.phrase(pour: error))
        }
    }

    /// Optimistic local bump after posting a comment — avoids a full feed refetch just to reflect
    /// the +1 this device already knows about.
    func bumpCommentsCount(_ activityId: String) {
        guard let index = feed.firstIndex(where: { $0.id == activityId }) else { return }
        feed[index].commentsCount += 1
        if let myId = auth.currentUser?.id, feed[index].userId == myId {
            profile.commentsSeenCounts[activityId] = feed[index].commentsCount
        }
    }

    /// Same idea as `notifyNewKudos`: compares each of your own posts' current comment count
    /// against what was last seen and posts one bell notification per post that gained new
    /// comments since — never for comments left by yourself in `ActivityCommentsSheet`, since
    /// `bumpCommentsCount` above already advances the "seen" mark for those.
    private func notifyNewComments(in feed: [FeedItem]) {
        guard let myId = auth.currentUser?.id else { return }
        for item in feed where item.userId == myId {
            let seen = profile.commentsSeenCounts[item.id] ?? 0
            if item.commentsCount > seen {
                let gained = item.commentsCount - seen
                appState.notify(
                    icon: "bubble.left.fill", colorHex: 0xFF3B6B,
                    title: String(localized: "Nouveaux commentaires"),
                    text: Pluriel.choisir(gained,
                        String(localized: "Quelqu'un a commenté ta séance."),
                        String(localized: "\(gained) personnes ont commenté ta séance."))
                )
            }
            profile.commentsSeenCounts[item.id] = item.commentsCount
        }
    }

    /// Saves the caller's own club-profile status and mirrors it into the local leaderboard so
    /// re-opening "Gestion du club" reflects it immediately, without a full refetch.
    func updateBio(_ bio: String) async throws {
        let saved = try await clubService.updateBio(bio)
        if let index = board.leaderboard.firstIndex(where: { $0.isMe }) {
            board.leaderboard[index].bio = saved
        }
    }

    /// Syncs whichever of `badges` are currently earned up to the server — harmless to call every
    /// time the board loads (the server upserts with `ON CONFLICT DO NOTHING`), and it's what
    /// makes an achievement earned on this device show up on this member's profile for everyone
    /// else in the club, not just locally. Also the one place that can tell a badge crossing its
    /// threshold JUST NOW apart from one that's simply been sitting earned since before
    /// `seenBadgeKeys` existed — see `BadgeUnlockedView`.
    /// `badges` ENTRE PAR LA PORTE, et c'est la seule raison qui l'y oblige : il se calcule à
    /// partir de `runs`, que `ClubView` obtient par `@Query` — une propriété qui n'existe que
    /// dans une vue SwiftUI. Un magasin ne peut pas interroger SwiftData de cette façon.
    func syncBadgesIfNeeded(badges: [ClubBadge]) {
        let earned = badges.filter { $0.earned }
        guard !earned.isEmpty else { return }
        let earnedKeys = earned.map { $0.key }
        Task { try? await clubService.syncBadges(earnedKeys) }

        // First-ever pass on this device: seed `seenBadgeKeys` with whatever's already earned
        // silently, no celebration — otherwise every pre-existing badge reads as "just unlocked!"
        // the moment this feature first ships to someone who's been running for months.
        guard profile.didBackfillSeenBadges else {
            profile.seenBadgeKeys = earnedKeys
            profile.didBackfillSeenBadges = true
            return
        }

        let seen = Set(profile.seenBadgeKeys)
        let newlyEarned = earned.filter { !seen.contains($0.key) }
        guard !newlyEarned.isEmpty else { return }
        // Mark every genuinely-new key seen up front (not just the one shown) — a batch of several
        // badges crossed at once (e.g. right after importing old runs) celebrates one, not a stack
        // of full-screen covers queued behind it, but none of the others should re-trigger later.
        profile.seenBadgeKeys.append(contentsOf: newlyEarned.map { $0.key })
        if unlockedBadge == nil {
            unlockedBadge = newlyEarned.first
        }
    }

    /// Keeps the server's copy of `plannedWeeklyKm` fresh so the "% objectif" leaderboard mode
    /// reflects THIS week's real plan, not a stale one from whenever she last opened Club. Cheap
    /// and safe to call on every load — same fire-and-forget spirit as `syncBadgesIfNeeded`.
    func syncWeeklyTargetIfNeeded() {
        let target = profile.plannedWeeklyKm
        Task { try? await clubService.syncWeeklyTarget(target) }
    }

    func submitReport(_ target: ReportTarget, reason: String) async {
        do {
            try await clubService.report(targetType: target.targetType, targetId: target.targetId, reason: reason)
            appState.toast(String(localized: "Signalement envoyé — merci"))
        } catch {
            appState.toast(String(localized: "Impossible d'envoyer le signalement, réessaie."))
        }
    }

    func confirmBlock(_ userId: String) async {
        do {
            try await clubService.blockUser(userId: userId)
            // Refresh so the blocked person disappears from the leaderboard/feed immediately —
            // both refetches only depend on blockUser having completed, not on each other, so
            // they run concurrently instead of paying two round trips back to back.
            async let boardAttempt = clubService.fetchBoard()
            async let feedAttempt = clubService.fetchFeed()
            (board, feed) = try await (boardAttempt, feedAttempt)
        } catch {
            errorMessage = String(localized: "Impossible de bloquer cette personne.")
        }
    }

    // MARK: Le mur

    /// Rend `true` quand le message est parti, pour que le brouillon et la réponse en cours —
    /// qui appartiennent à la vue — sachent qu'ils peuvent se vider. Même règle que
    /// `createClub` : un magasin n'efface pas un champ de saisie.
    @discardableResult
    func publier(texte brut: String, enReponseA parent: ClubPost?) async -> Bool {
        let texte = brut.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texte.isEmpty else { return false }
        do {
            try await clubService.postClubMessage(text: texte, parentId: parent?.id)
            // On RECHARGE plutôt que de fabriquer la ligne localement : le serveur décide de
            // l'identifiant et de la date, et deux appareils afficheraient sinon deux versions
            // du même message.
            posts = (try? await clubService.fetchClubPosts()) ?? posts
            return true
        } catch {
            appState.toast(PanneReseau.phrase(pour: error))
            return false
        }
    }

    func applaudirLeMessage(_ message: ClubPost) async {
        guard let index = posts.firstIndex(where: { $0.id == message.id }) else { return }
        do {
            let maintenant = try await clubService.toggleClubPostKudos(postId: message.id)
            posts[index].kudoedByMe = maintenant
            posts[index].kudos += maintenant ? 1 : -1
            Haptics.impact(.light)
        } catch {
            appState.toast(PanneReseau.phrase(pour: error))
        }
    }

    func supprimerLeMessage(_ message: ClubPost) async {
        do {
            try await clubService.deleteClubPost(postId: message.id)
            // Les réponses partent avec lui côté serveur (ON DELETE CASCADE) : on fait pareil ici
            // plutôt que de laisser des réponses orphelines jusqu'au prochain chargement.
            posts.removeAll { $0.id == message.id || $0.parentId == message.id }
        } catch {
            appState.toast(PanneReseau.phrase(pour: error))
        }
    }

    /// Le texte d'un message déjà publié. La vue garde la feuille d'édition ; le magasin garde
    /// la liste et l'appel.
    func modifierLeMessage(_ message: ClubPost, texte: String) async throws {
        try await clubService.updateClubPost(postId: message.id, text: texte)
        if let i = posts.firstIndex(where: { $0.id == message.id }) {
            posts[i].text = texte
        }
    }

    // MARK: Les réglages du club

    // LES QUATRE RÉGLAGES ONT LA MÊME FORME : l'appel, puis une relecture du tableau de bord.
    // Le tableau vient du serveur, et on le relit plutôt que de deviner le nouvel état, pour
    // que l'écran dise ce que le serveur a retenu. `badges` entre par la porte, comme partout
    // où `loadIfSignedIn` est appelé — voir `syncBadgesIfNeeded`.

    func ouvrirLeClub(_ ouvert: Bool, badges: [ClubBadge]) async throws {
        try await clubService.setClubOpen(ouvert)
        await loadIfSignedIn(badges: badges)
    }

    func reglerLaFiche(description: String, ville: String, badges: [ClubBadge]) async throws {
        try await clubService.setClubProfile(description: description, city: ville)
        await loadIfSignedIn(badges: badges)
    }

    /// `dataURI` est OPTIONNEL : retirer la couverture, c'est en poser une qui n'existe pas.
    /// `ClubManagementView.onSetClubCover` et `ClubService.setClubCover` le disent tous les
    /// deux ; je l'avais resserré en `String` en recopiant, et le compilateur l'a refusé.
    func reglerLaCouverture(dataURI: String?, badges: [ClubBadge]) async throws {
        try await clubService.setClubCover(dataURI: dataURI)
        await loadIfSignedIn(badges: badges)
    }

    func reglerLeRole(memberId: String, organisateur: Bool, badges: [ClubBadge]) async throws {
        try await clubService.setMemberRole(memberId: memberId, organiser: organisateur)
        await loadIfSignedIn(badges: badges)
    }

    /// Retirer une de ses propres activités du fil du club.
    func confirmDeleteActivity(_ item: FeedItem) async {
        do {
            try await clubService.deleteActivity(activityId: item.id)
            feed.removeAll { $0.id == item.id }
            appState.toast(String(localized: "Activité supprimée du fil."))
        } catch {
            appState.toast(String(localized: "Suppression impossible — réessaie."))
        }
    }

    // MARK: Les sorties de groupe

    func toggleRsvp(_ event: ClubEvent, groupe: String? = nil) {
        Haptics.selection()
        Task {
            do {
                let result = try await clubService.toggleEventRsvp(eventId: event.id, paceGroup: groupe)
                // LES `MainActor.run` ONT DISPARU EN ARRIVANT ICI. Ils étaient nécessaires dans
                // la vue — une structure dont seules certaines parties sont isolées — et ne
                // disent plus rien dans une classe `@MainActor` : tout y est déjà sur le fil
                // principal, et un saut qui ne saute nulle part masque le code qu'il enveloppe.
                if let index = board.events?.firstIndex(where: { $0.id == event.id }) {
                    board.events?[index].goingByMe = result.going
                    board.events?[index].going = result.count
                    board.events?[index].myPaceGroup = result.paceGroup
                    // Le compte par groupe vient du serveur au prochain chargement ; en
                    // attendant, on bouge le sien pour que la pastille choisie réponde tout
                    // de suite. Un chiffre qui attend l'aller-retour se lit comme un geste
                    // qui n'a pas pris.
                    var comptes = board.events?[index].paceCounts ?? [:]
                    if let avant = event.myPaceGroup { comptes[avant] = max(0, (comptes[avant] ?? 1) - 1) }
                    if let apres = result.paceGroup { comptes[apres] = (comptes[apres] ?? 0) + 1 }
                    board.events?[index].paceCounts = comptes
                }
            } catch ClubServiceError.badResponse(404, _) {
                // The event was already cancelled/expired server-side — leaving it in the local
                // list would just let her tap it again and fail identically every time.
                board.events?.removeAll { $0.id == event.id }
            } catch {
                appState.toast(String(localized: "Impossible de répondre — réessaie."))
            }
        }
    }

    func deleteEvent(_ event: ClubEvent) {
        Task {
            do {
                try await clubService.deleteEvent(eventId: event.id)
                board.events?.removeAll { $0.id == event.id }
            } catch ClubServiceError.badResponse(404, _) {
                // Already gone server-side — still fine to drop it locally.
                board.events?.removeAll { $0.id == event.id }
            } catch {
                // A real failure (network, 403 not-the-creator, ...) — keep it in the list rather
                // than silently pretending the cancel worked when it didn't.
                appState.toast(String(localized: "Impossible d'annuler la sortie — réessaie."))
            }
        }
    }

    // LA BANDE DE BADGES A QUITTÉ L'ONGLET CLASSEMENT.
    //
    // Elle y affichait MES badges, sous le titre « Derniers badges », au bas d'un classement du
    // CLUB — une deuxième statistique personnelle posée sur une page collective, après la carte
    // de niveau. Et elle était déjà, en mieux, sur le Profil : les seize badges avec leur nom et
    // leur progression, au lieu de six vignettes qu'il fallait faire défiler latéralement.
    //
    // Le calcul (`badges`) reste : c'est lui qui alimente la synchronisation vers le serveur et
    // la célébration d'un badge débloqué.

    /// Une sortie de groupe créée : insérée à sa place dans la liste plutôt que de relire tout
    /// le tableau — le serveur rend la sortie telle qu'il l'a enregistrée, il n'y a rien d'autre
    /// à apprendre de lui.
    /// `location` est OPTIONNEL : une sortie peut n'avoir pas encore de lieu. Même erreur de
    /// recopie que pour la couverture ci-dessus.
    func creerLaSortie(title: String, location: String?, startsAt: Date,
                       repeatsWeekly: Bool, paceGroups: [String]) async throws {
        let created = try await clubService.createEvent(title: title, location: location,
                                                        startsAt: startsAt,
                                                        repeatsWeekly: repeatsWeekly,
                                                        paceGroups: paceGroups)
        var events = board.events ?? []
        events.append(created)
        events.sort { $0.startsAt < $1.startsAt }
        board.events = events
    }

    /// Une sortie modifiée, suivie d'une relecture complète — voir le commentaire à l'appel.
    func modifierLaSortie(_ event: ClubEvent, title: String, location: String?, startsAt: Date,
                          repeatsWeekly: Bool, paceGroups: [String],
                          badges: [ClubBadge]) async throws {
        try await clubService.updateEvent(eventId: event.id, title: title, location: location,
                                          startsAt: startsAt, repeatsWeekly: repeatsWeekly,
                                          paceGroups: paceGroups)
        await loadIfSignedIn(badges: badges)
    }
}
