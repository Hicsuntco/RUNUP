import SwiftUI
import SwiftData

/// Social/club screen — a real, server-backed club (see `ClubService`, `api/clubs/*.js`,
/// `api/activities/*.js`), not `ClubMockData`: the leaderboard is computed from real members' XP,
/// the feed is real posted activities, kudos persist per-user. Requires a real account
/// (`AuthService`) — the rest of the app works fully offline, this is the one feature that
/// intrinsically needs one, so sign-in is gated here rather than forced at onboarding.
struct ClubView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]

    /// L'APERÇU EST LE BON ONGLET POUR DE VRAIES GENS, ET LE MAUVAIS POUR UNE CAPTURE.
    ///
    /// Il montre les kilomètres du club cette semaine, le défi en cours et les sorties de
    /// groupe prévues — trois choses qu'un club inventé n'a pas, donc trois états vides sous
    /// une accroche qui parle du fil du club. Le fil, lui, est plein. Voir `Demonstration`.
    @State private var tab: Tab = Tab.auDemarrage
    @State private var board = ClubBoard(club: nil, leaderboard: [])
    /// Ce que le club prépare, et ce qu'il a fait de mieux. Chargé à part du tableau de bord :
    /// celui-ci part à chaque ouverture du Club, celui-là seulement quand l'aperçu s'affiche.
    @State private var highlights: ClubHighlights?
    /// LE MUR DU CLUB : ce qu'on se dit entre deux sorties. Les messages vivent dans le même
    /// onglet que les activités et s'y entrelacent par date — un mur à part aurait fait un
    /// quatrième onglet pour une conversation de dix lignes.
    @State private var posts: [ClubPost] = []
    @State private var brouillonDuClub = ""
    @State private var reponseA: ClubPost?
    @State private var envoiDuMessage = false
    @State private var feed: [FeedItem] = []
    // Starts true (not false) so the very first render — before `.task` below has had a chance to
    // run — reads as "checking for your club" rather than immediately flashing the create/join
    // form. `.id(appState.screen)` on the parent means a fresh ClubView (and fresh isLoading=true)
    // is created every time this tab is opened, so this covers every visit, not just the first.
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSignIn = false
    @State private var newClubName = ""
    @State private var clubQuery = ""
    @State private var clubResultats: [ClubSearchResult] = []
    @State private var clubSearchEnCours = false
    @State private var clubSearchTask: Task<Void, Never>?
    @State private var reportTarget: ReportTarget?
    @State private var pendingBlock: (userId: String, name: String)?
    @State private var showManagement = false
    @State private var commentsActivity: FeedItem?
    /// La sortie en cours de modification — la sienne uniquement, le serveur le vérifie de son côté.
    @State private var editingActivity: FeedItem?
    /// Set only when `syncBadgesIfNeeded` finds a key `badges` reports earned that isn't yet in
    /// `profile.seenBadgeKeys` — i.e. genuinely just crossed the threshold this load, not merely
    /// "earned at some point before this feature existed." Drives `BadgeUnlockedView`.
    @State private var unlockedBadge: ClubBadge?
    @State private var showLeaveConfirm = false
    @State private var showCreateEvent = false
    /// My own feed activity pending delete confirmation (appui long → Supprimer).
    @State private var pendingDeleteActivity: FeedItem?
    /// Lequel des deux classements l'onglet montre : la course aux kilomètres de la semaine, ou
    /// l'XP de toujours.
    @State private var boardMode: BoardMode = .week

    /// LE CLASSEMENT MONDIAL EST PARTI, ET C'EST UNE DÉCISION DE FOND.
    ///
    /// Un club de course est LOCAL. Se comparer aux kilomètres de quelqu'un qu'on ne croisera
    /// jamais, dans une ville qu'on ne connaît pas, ne fait pas courir — ça ne fait même pas un
    /// classement, ça fait un palmarès mondial où personne ne se reconnaît. Ce que le club
    /// compare, c'est ses membres entre eux, et c'est tout ce qui a du sens.
    ///
    /// Partent avec lui : la pastille « Mondial », son contenu, son interrupteur de
    /// participation et ses deux appels au serveur. La colonne `global_leaderboard_opt_in`
    /// reste en base — la retirer serait une migration destructrice pour rien.
    private enum BoardMode { case week, general }
    /// Only meaningful within `BoardMode.week` — raw km (server-ranked) vs. each member's own %
    /// of their real weekly plan (`WeeklyRow.pctOfTarget`, client-ranked — see `weekBoardContent`).
    /// The whole reason this mode exists: a mixed-level club (a beginner on 15 km/week next to a
    /// marathoner on 60) stays motivating for everyone, not just whoever runs the most raw distance.
    @State private var weeklyDisplayMode: WeeklyDisplayMode = .km
    // Same `CaseIterable, Identifiable` shape as `StatsView.StatsRange` — lets the picker below use
    // `ForEach(WeeklyDisplayMode.allCases)` directly instead of a hand-rolled `id:` keypath.
    private enum WeeklyDisplayMode: CaseIterable, Identifiable, Equatable {
        case km, pctObjectif
        var id: Self { self }
    }
    /// Drives the feed rows' staggered entrance — flipped once the first feed load lands, after
    /// which each row's own per-index delay takes over (same pattern as `RecapView`'s splits).
    @State private var feedRevealed = false

    /// Trois destinations, pas un mur (`.club-tabs` dans la maquette).
    ///
    /// L'écran empilait auparavant, AU-DESSUS de son sélecteur à deux positions : la carte de
    /// niveau, le pouls de la semaine, le défi, les sorties de groupe et la ligne d'adhésion. En
    /// clair, il fallait faire défiler cinq blocs avant d'atteindre le classement — et exactement
    /// les mêmes cinq avant d'atteindre le fil. Rien de tout cela n'était mauvais, c'était juste
    /// toujours là, quelle que soit la raison pour laquelle on ouvrait l'écran.
    ///
    /// C'est le seul endroit où j'ai vraiment restructuré un écran qui marchait, et c'est parce
    /// que le volume de contenu le justifie : ces cinq blocs représentent plus d'une hauteur
    /// d'écran à eux seuls. Ils forment un ensemble cohérent — « où en est le club en ce moment »
    /// — qui devient l'onglet Aperçu, pendant que Classement et Activité deviennent atteignables
    /// en un seul geste depuis le haut de la page.
    private enum Tab {
        case overview, board, feed

        /// L'onglet d'ouverture. En démonstration, le fil — le seul des trois qu'un club inventé
        /// remplit vraiment — sauf quand les captures en demandent un autre par `--onglet=`.
        static var auDemarrage: Tab {
            #if DEBUG
            switch CaptureSeed.ongletDuClub {
            case "apercu": return .overview
            case "classement": return .board
            case "activite": return .feed
            default: break
            }
            #endif
            return Demonstration.enCours ? .feed : .overview
        }
    }

    private var profile: UserProfile { appState.profile }
    private var auth: AuthService { appState.auth }
    private var clubService: ClubService { ClubService(auth: auth) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                banniere
                header
                // Pleine largeur, SOUS l'en-tête et pas dedans : à côté du nom, elle aurait eu
                // la moitié de la ligne et se serait tronquée au premier mot intéressant.
                if let texte = board.club?.description, !texte.isEmpty {
                    Text(texte)
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !auth.isSignedIn {
                    signInPrompt
                } else if isLoading && board.club == nil {
                    // Without this, the ~few seconds `loadIfSignedIn` takes to fetch her real
                    // club read as "the create/join form flashes, then flips to the leaderboard" —
                    // confusing when she already has a club (looks like it vanished, not loaded).
                    loadingCard
                } else if board.club == nil {
                    clubSetupCard
                } else {
                    clubTabs
                    Group {
                        switch tab {
                        case .overview: overviewContent
                        case .board: boardContent
                        case .feed: feedContent
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let errorMessage {
                    // Was color-only (rose text, no icon) — reads as regular text rather than an
                    // error, especially on a light theme with a pale accent swatch selected.
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                        Text(errorMessage).font(RUFont.sans(.small))
                    }
                    .foregroundColor(RUColor.rose)
                    .padding(.top, 4)
                }

                if auth.isSignedIn {
                    // Published contact info, surfaced directly here rather than only buried in
                    // the privacy policy — App Store guideline 1.2.
                    Link("Signaler un problème ou nous contacter", destination: URL(string: "mailto:charlottegrudep@gmail.com")!)
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .task { await loadIfSignedIn() }
        // Arrivée par le lien public d'un club : la recherche s'ouvre déjà remplie de son nom,
        // donc le bouton « Rejoindre » est à un geste. Le nom est consommé pour qu'un retour sur
        // l'onglet ne le réécrive pas par-dessus une recherche en cours.
        .onChange(of: appState.clubDepuisUnLien) { _, nom in
            guard let nom else { return }
            clubQuery = nom
            appState.clubDepuisUnLien = nil
        }
        .onAppear {
            if let nom = appState.clubDepuisUnLien {
                clubQuery = nom
                appState.clubDepuisUnLien = nil
            }
        }
        // Même temporisation que la recherche de personnes : on cherche À LA FRAPPE, mais on
        // n'envoie pas une requête par lettre.
        .onChange(of: clubQuery) { _, nouveau in chercherUnClub(nouveau) }
        .refreshable { await loadIfSignedIn() }
        .onChange(of: feed.count) { _, count in
            if count > 0 { feedRevealed = true }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
                .runUpSheetStyle(detents: [.large])
        }
        .sheet(item: $editingActivity) { activity in
            EditActivitySheet(item: activity, onSaved: { Task { await loadFeed() } })
                .runUpSheetStyle()
        }
        .sheet(item: $commentsActivity) { activity in
            ActivityCommentsSheet(
                activityId: activity.id,
                currentUserId: auth.currentUser?.id,
                clubService: clubService,
                onCommentPosted: { bumpCommentsCount(activity.id) },
                onReport: { comment in
                    commentsActivity = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        reportTarget = ReportTarget(targetType: "comment", targetId: comment.id, displayName: String(localized: "le commentaire de \(comment.name)"))
                    }
                },
                onBlock: { comment in
                    commentsActivity = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        pendingBlock = (comment.userId, comment.name)
                    }
                }
            )
                .runUpSheetStyle(detents: [.large])
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { Task { await loadIfSignedIn() } }
        }
        // Report reason picker — App Store guideline 1.2. `reportTarget` is set by the context
        // menus on leaderboard rows / feed items / the club itself.
        .confirmationDialog(
            "Signaler",
            isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }),
            presenting: reportTarget
        ) { target in
            Button("Contenu inapproprié") { Task { await submitReport(target, reason: "Contenu inapproprié") } }
            Button("Harcèlement") { Task { await submitReport(target, reason: "Harcèlement") } }
            Button("Spam") { Task { await submitReport(target, reason: "Spam") } }
            Button("Annuler", role: .cancel) {}
        } message: { target in
            Text("Pourquoi signales-tu \(target.displayName) ?")
        }
        // Quitter le club — le bouton vit maintenant dans la feuille de gestion, qui se ferme
        // avant de demander confirmation ; le dialogue doit donc être porté par une vue qui, elle,
        // reste à l'écran. `leaveClub()` garde son propre garde-fou contre le double appel.
        .confirmationDialog("Quitter le club ?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Quitter", role: .destructive) { Task { await leaveClub() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tu devras redemander le code d'invitation pour revenir.")
        }
        // Block confirmation — the other half of guideline 1.2, doesn't require leaving the club.
        .alert(
            "Bloquer \(pendingBlock?.name ?? "") ?",
            isPresented: Binding(get: { pendingBlock != nil }, set: { if !$0 { pendingBlock = nil } })
        ) {
            // Same synchronous capture as the delete alert below — the alert's dismissal nils
            // `pendingBlock` before an async Task body would read it (silent no-op otherwise).
            Button("Bloquer", role: .destructive) {
                if let target = pendingBlock {
                    Task { await confirmBlock(target.userId) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tu ne verras plus son score ni ses activités, sans avoir à quitter le club.")
        }
        // Deleting my own feed post — permanent (kudos et commentaires partent avec), so it
        // confirms instead of firing straight from the context menu.
        .alert(
            "Supprimer cette activité ?",
            isPresented: Binding(get: { pendingDeleteActivity != nil }, set: { if !$0 { pendingDeleteActivity = nil } })
        ) {
            // The item is captured SYNCHRONOUSLY here: dismissing the alert nils
            // `pendingDeleteActivity` before an async Task body would get to read it, which made
            // the whole action a silent no-op.
            Button("Supprimer", role: .destructive) {
                if let item = pendingDeleteActivity {
                    Task { await confirmDeleteActivity(item) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Elle disparaîtra du fil du club, avec ses applaudissements et commentaires. Tes XP restent acquis.")
        }
        .fullScreenCover(item: $unlockedBadge) { badge in
            BadgeUnlockedView(badge: badge, onDismiss: { unlockedBadge = nil })
        }
    }

    private func confirmDeleteActivity(_ item: FeedItem) async {
        do {
            try await clubService.deleteActivity(activityId: item.id)
            await MainActor.run {
                feed.removeAll { $0.id == item.id }
                appState.toast(String(localized: "Activité supprimée du fil."))
            }
        } catch {
            await MainActor.run { appState.toast(String(localized: "Suppression impossible — réessaie.")) }
        }
    }

    /// The club's name doubles as the entry point to "Gestion du club" (invite code, member
    /// list, member profiles) — those used to be scattered across the main page (the invite code
    /// in particular sat as its own card, which read as clutter on a screen that's really about
    /// the leaderboard and feed).
    private var header: some View {
        // ALIGNÉ EN HAUT : le bloc de gauche fait trois lignes (le sourcil, le nom, la ville) et
        // la pastille une seule. Centrée, elle tombait en face du NOM, c'est-à-dire nulle part —
        // ni sur la première ligne ni sur la dernière. En haut, elle partage la ligne du sourcil.
        HStack(alignment: .top) {
            if let club = board.club {
                Button(action: { showManagement = true }) {
                    VStack(alignment: .leading, spacing: 2) {
                        // « LE CLUB » EST UN SOURCIL, ET IL ÉTAIT ÉCRIT COMME UN INTERTITRE.
                        //
                        // `RUCardHeader` le posait à la taille d'une section — donc « Le Club »
                        // avait exactement le corps de « Les records du club », deux points
                        // sous le nom du club juste en dessous. Trois lignes de la même
                        // importance apparente en tête de page.
                        //
                        // `EyebrowLabel` est le jeton prévu pour ça, et sa définition le dit :
                        // « 9 px, interlettrage 3, capitales, graisse 700, posé AU-DESSUS des
                        // titres de section ». L'icône de page reste — c'est une décision
                        // écrite plus haut dans ce fichier, et elle vaut toujours — mais elle
                        // descend à la taille de ce qu'elle accompagne.
                        HStack(spacing: 5) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(RUColor.rose)
                            EyebrowLabel(text: "Le Club")
                        }
                        HStack(spacing: 6) {
                            Text(club.name).displayStyle(24).foregroundColor(RUColor.textPrimary).lineLimit(1).minimumScaleFactor(0.6)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(RUColor.text3)
                        }
                        // CE QUE LE CLUB EST, ET OÙ IL COURT. Sans ces deux lignes, la page
                        // s'ouvrait sur un nom et un compte de membres — ce qui ne dit ni où
                        // l'on court, ni à quelle heure, ni si on y est le bienvenu quand on
                        // débute, c'est-à-dire tout ce qu'on cherche à savoir d'un club.
                        if let ville = club.city, !ville.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin").font(.system(size: 9))
                                Text(ville).font(RUFont.sans(.small, weight: .semibold))
                            }
                            .foregroundColor(RUColor.text2)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(RUColor.rose)
                        EyebrowLabel(text: "Le Club")
                    }
                    Text("Rejoins un club").displayStyle(24).foregroundColor(RUColor.textPrimary)
                }
            }
            Spacer()
            if let club = board.club {
                StatChip(text: Pluriel.choisir(club.memberCount,
                                               String(localized: "\(club.memberCount) membre"),
                                               String(localized: "\(club.memberCount) membres")),
                         color: RUColor.text2, background: RUColor.card)
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showManagement) {
            if let club = board.club {
                ClubManagementView(
                    club: club,
                    members: board.leaderboard,
                    challenge: board.challenge,
                    onCreateChallenge: { title, targetKm, endDate in
                        try await createChallenge(title: title, targetKm: targetKm, endDate: endDate)
                    },
                    onReport: { member in
                        // Dismiss the sheet first, then set the target once its dismiss animation
                        // is out of the way — setting both in the same tick makes SwiftUI try to
                        // dismiss the sheet and present the confirmationDialog simultaneously,
                        // and one of the two silently loses.
                        showManagement = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            reportTarget = ReportTarget(targetType: "user", targetId: member.id, displayName: member.name)
                        }
                    },
                    onBlock: { member in
                        showManagement = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            pendingBlock = (member.id, member.name)
                        }
                    },
                    onUpdateBio: { bio in try await updateBio(bio) },
                    onSetOpen: { ouvert in
                        try await clubService.setClubOpen(ouvert)
                        // Le tableau vient du serveur : on le relit plutôt que de deviner le
                        // nouvel état, pour que l'écran dise ce que le serveur a retenu.
                        await loadIfSignedIn()
                    },
                    onSetClubProfile: { description, ville in
                        try await clubService.setClubProfile(description: description, city: ville)
                        await loadIfSignedIn()
                    },
                    onSetClubCover: { dataURI in
                        try await clubService.setClubCover(dataURI: dataURI)
                        await loadIfSignedIn()
                    },
                    onSetMemberRole: { memberId, organisateur in
                        try await clubService.setMemberRole(memberId: memberId, organiser: organisateur)
                        await loadIfSignedIn()
                    },
                    // Même précaution que `onReport` ci-dessus : fermer la feuille, puis présenter
                    // le dialogue une fois son animation de fermeture passée.
                    onReportClub: {
                        showManagement = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            reportTarget = ReportTarget(targetType: "club", targetId: club.id, displayName: String(localized: "le club \(club.name)"))
                        }
                    },
                    onLeaveClub: {
                        showManagement = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            showLeaveConfirm = true
                        }
                    }
                )
            }
        }
    }

    // MARK: Loading — signed in, real club status not back from the server yet

    /// A spinner + explicit "Chargement du club…" — the skeleton-rows version read as a broken/
    /// empty "Rejoins un club" screen (owner's call: the plain message says what's happening).
    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(RUColor.rose)
            Text("Chargement du club…")
                .font(RUFont.sans(.label, weight: .semibold))
                .foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .ruCard()
    }

    // MARK: Not signed in

    private var signInPrompt: some View {
        VStack(spacing: 12) {
            AppMarkView(size: 44)
            Text("Le Club, c'est mieux à plusieurs").font(RUFont.sans(.emphasis, weight: .bold)).foregroundColor(RUColor.textPrimary)
            Text("Connecte-toi pour rejoindre un vrai club, avec un classement et un fil d'activité alimentés par de vraies personnes.")
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).multilineTextAlignment(.center)
            Button("SE CONNECTER") { showSignIn = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .ruCard()
    }

    // MARK: Signed in, no club yet

    private var clubSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                RUCardHeader(icon: "plus.circle.fill", tint: RUColor.rose2, title: "Créer un club", subtitle: "Tu en seras l'administratrice")
                HStack {
                    TextField("Nom du club", text: $newClubName)
                        .textFieldStyle(.plain)
                        .font(RUFont.sans(.emphasis))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                    Button("Créer") { Task { await createClub() } }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: newClubName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading))
                        .disabled(newClubName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }

            // ON CHERCHE UN CLUB PAR SON NOM.
            //
            // Ce bloc demandait un code à six lettres. Un code suppose qu'on l'ait reçu de
            // quelqu'un — donc qu'on sache déjà que le club existe et comment il s'appelle,
            // c'est-à-dire tout ce qu'une recherche rend inutile. Et il fallait le taper sans se
            // tromper, sur un champ en capitales, pour une erreur qui ne disait que
            // « introuvable ».
            VStack(alignment: .leading, spacing: 6) {
                RUCardHeader(icon: "magnifyingglass", tint: RUColor.rose2, title: "Rejoindre un club")
                TextField("Chercher par son nom", text: $clubQuery)
                    .textFieldStyle(.plain)
                    .font(RUFont.sans(.emphasis))
                    .foregroundColor(RUColor.textPrimary)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

                if clubSearchEnCours {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                } else if !clubQuery.trimmingCharacters(in: .whitespaces).isEmpty, clubResultats.isEmpty {
                    Text("Aucun club ouvert ne porte ce nom.")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                        .padding(.vertical, 8)
                }
                ForEach(clubResultats) { trouve in
                    Button(action: { Task { await joinClub(trouve) } }) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(trouve.name)
                                    .font(RUFont.sans(.label, weight: .medium))
                                    .foregroundColor(RUColor.textPrimary)
                                    .lineLimit(1)
                                // Le nombre de membres n'est pas décoratif : rien n'empêche deux
                                // clubs de porter le même nom, et c'est ce qui les distingue.
                                // LA VILLE AVANT LE COMPTE, pour la même raison en plus fort :
                                // entre deux « Foulées du Canal », c'est elle qui dit laquelle
                                // est la sienne. Un nombre de membres ne l'a jamais dit.
                                Text(ligneDuClubTrouve(trouve))
                                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text("Rejoindre")
                                .font(RUFont.sans(.body, weight: .semibold))
                                .foregroundColor(RUColor.rose2)
                        }
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(isLoading)
                }
            }
        }
        .padding(16)
        .ruCard()
    }

    // MARK: Signed in, in a club

    private var levelInfo: (level: Int, title: String, xpIntoLevel: Int, xpForLevel: Int) {
        // Composés dans `Text("Niveau \(level) · \(title)")` en tant qu'argument : ils n'atteignent
        // jamais un `LocalizedStringKey` par eux-mêmes, d'où `String(localized:)`.
        let titles = [
            String(localized: "Premiers pas"),
            String(localized: "Foulée légère"),
            String(localized: "Rythme trouvé"),
            String(localized: "Foulée d'or"),
            String(localized: "Vitesse de croisière"),
            String(localized: "Endurance de fer"),
            String(localized: "Élite locale")
        ]
        let xp = auth.currentUser?.xpTotal ?? 0
        let xpPerLevel = 250
        let level = xp / xpPerLevel + 1
        let title = titles[min(max(level - 1, 0), titles.count - 1)]
        return (level, title, xp % xpPerLevel, xpPerLevel)
    }

    /// LE SEUL OBJET SOMBRE D'UNE PAGE CLAIRE, ET IL ÉTAIT EN BAS DE CELLE-CI.
    ///
    /// Ce bloc gardait son dégradé violet nuit DANS LES DEUX THÈMES. En sombre, c'est le héros
    /// de la page ; en clair, c'est un pavé noir au pied d'un écran pâle — c'est-à-dire
    /// exactement le « gros cadre » qu'on avait retiré du HAUT de cette page, réapparu au bas.
    ///
    /// On le voit à ce que le code avouait déjà : les textes étaient figés en blanc, avec pour
    /// raison « cette carte reste sombre dans les deux thèmes, donc `text2` passerait
    /// sombre-sur-sombre ». Le symptôme était traité, pas la cause.
    ///
    /// En clair, c'est maintenant une carte comme les autres. Ce qui ne bouge pas, c'est la
    /// PASTILLE du niveau : elle garde son dégradé violet→rose, et reste le point de couleur de
    /// la section. Un point, pas un aplat plein cadre.
    private var levelCard: some View {
        let info = levelInfo
        let clair = RUColor.isLight
        let encre = clair ? RUColor.textPrimary : Color.white
        let encre2 = clair ? RUColor.text3 : Color.white.opacity(0.65)
        return HStack(spacing: 14) {
            Text("\(info.level)").displayStyle(22).foregroundColor(.white)
                .contentTransition(.numericText())
                .frame(width: 52, height: 52)
                .background(LinearGradient(colors: [RUColor.violet, RUColor.rose], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: RUSpacing.radiusLarge, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                // « TON NIVEAU », écrit. Sur une page qui parle du club du début à la fin, un
                // « Niveau 17 » sans sujet se lit comme le niveau DU CLUB — ce qu'il n'est pas :
                // il vient de mon XP à moi.
                // L'XP MONTE SUR LA LIGNE DU SOURCIL, PARCE QUE LE TITRE SE REPLIE.
                //
                // « Niveau 17 · Élite locale » ne tient pas sur une ligne à 23,1 pt dans la
                // largeur qui reste à droite de la pastille. Il passait donc sur deux lignes,
                // et comme le compteur d'XP partageait sa rangée en `lastTextBaseline`, il se
                // retrouvait échoué à droite de « Élite locale » — une forme en escalier, avec
                // la jauge qui démarre sous un bloc de texte en deux morceaux.
                //
                // Les deux lignes du titre ne sont pas le problème : un titre long a le droit
                // de se replier. C'est de lui accrocher un chiffre qui l'était. Le sourcil, lui,
                // tient toujours sur une ligne et a de la place à droite.
                HStack(alignment: .firstTextBaseline) {
                    Text("Ton niveau dans le club")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(encre2)
                    Spacer(minLength: 8)
                    Text("\(info.xpIntoLevel) / \(info.xpForLevel) XP").font(RUFont.mono(10)).foregroundColor(encre2)
                        .contentTransition(.numericText())
                }
                Text("Niveau \(info.level) · \(info.title)")
                    .font(RUFont.sans(.title, weight: .bold)).foregroundColor(encre)
                    .fixedSize(horizontal: false, vertical: true)
                LinearBar(fraction: Double(info.xpIntoLevel) / Double(info.xpForLevel), color: RUColor.violet, gradient: RUColor.violetRoseGradient)
            }
        }
        .animation(.easeOut(duration: 0.4), value: info.level)
        .animation(.easeOut(duration: 0.4), value: info.xpIntoLevel)
        .padding(16)
        .background(clair
                    ? LinearGradient(colors: [RUColor.card, RUColor.card], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color(hex: 0x241046), Color(hex: 0x160B1F)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: RUSpacing.radiusHero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusHero, style: .continuous)
            .stroke(clair ? RUColor.cardBorder : RUColor.violet.opacity(0.3), lineWidth: RUSpacing.hairline))
    }

    /// LA COUVERTURE DU CLUB.
    ///
    /// La dernière chose qui manquait pour qu'un club ressemble à un LIEU plutôt qu'à une fiche :
    /// le canal, la piste, le groupe au départ. Elle ne s'affiche que si quelqu'un en a posé une
    /// — un cadre gris en attente d'image dirait « il manque quelque chose » à des clubs qui ne
    /// manquent de rien.
    ///
    /// 16:6, pas 16:9 : c'est une bande, pas une photo. Plus haute, elle pousserait le nom du
    /// club et ses trois onglets sous la ligne de flottaison, et on ouvrirait l'écran sur une
    /// image au lieu de l'ouvrir sur le club.
    @ViewBuilder private var banniere: some View {
        if let brut = board.club?.coverUrl, !brut.isEmpty, let url = URL(string: brut) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RUColor.card
            }
            .aspectRatio(16.0 / 6.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
            .accessibilityHidden(true)
        }
    }

    /// « Lyon · 18 membres », ou le compte seul quand le club n'a pas dit où il court.
    private func ligneDuClubTrouve(_ trouve: ClubSearchResult) -> String {
        let membres = Pluriel.choisir(trouve.memberCount,
                                      String(localized: "\(trouve.memberCount) membre"),
                                      String(localized: "\(trouve.memberCount) membres"))
        guard let ville = trouve.city, !ville.isEmpty else { return membres }
        return "\(ville) · \(membres)"
    }

    private func daysLeft(until date: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0)
    }

    /// « 312 / 500 km — 62 % ». Le pourcentage est celui que la barre juste au-dessus dessine
    /// déjà : la maquette le met en toutes lettres, et c'est le chiffre qu'on cherche vraiment
    /// (« on en est où »), là où deux nombres bruts obligent à faire la division de tête. Rien
    /// d'inventé — c'est exactement `progressKm / targetKm`, tous deux calculés côté serveur.
    private func challengeProgressText(_ challenge: ClubChallenge) -> String {
        // Pas de `String(localized:)` : deux nombres, une barre, « km ». Rien à traduire, et
        // une clé au catalogue pour ça aurait deux traductions identiques à la française.
        let base = "\(Int(challenge.progressKm)) / \(Int(challenge.targetKm)) km"
        guard challenge.targetKm > 0 else { return base }
        let pct = Int((challenge.progressKm / challenge.targetKm * 100).rounded())
        return "\(base) — \(pct) %"
    }

    /// Any member can set the club's challenge (see "Gestion du club") — this used to always show
    /// a fixed "100 km ce mois-ci" regardless of whether anyone had actually agreed to that goal.
    /// `progressKm` is a real sum computed server-side over every member's logged runs since the
    /// challenge was created, not just this device's local history.
    /// UNE SECTION, PAS UNE CARTE — et surtout pas une carte VIDE.
    ///
    /// « Défi du club / Aucun défi en cours » occupait un rectangle plein de cent points de haut
    /// pour dire qu'il n'y avait rien à dire. Deux de ces blocs se suivaient en tête de l'écran,
    /// et c'est tout ce qu'on voyait d'un club qui démarre : deux grands cadres vides.
    ///
    /// L'invitation à en créer un reste, en une ligne discrète — c'est la même forme que
    /// « Sorties de groupe » juste en dessous, qui n'a jamais eu besoin d'un cadre pour dire
    /// qu'aucune sortie n'est prévue.
    private var challengeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let challenge = board.challenge {
                HStack {
                    RUCardHeader(title: "Défi du club")
                    StatChip(text: String(localized: "J-\(daysLeft(until: challenge.endDate))"), color: RUColor.rose2)
                }
                Text(challenge.title).displayStyle(19).foregroundColor(RUColor.textPrimary)
                LinearBar(fraction: challenge.targetKm > 0 ? min(1, challenge.progressKm / challenge.targetKm) : 0, color: RUColor.rose)
                HStack {
                    Text(challengeProgressText(challenge)).font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    Spacer()
                    Text("ensemble").font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                }
            } else {
                HStack {
                    RUCardHeader(title: "Défi du club")
                    Spacer(minLength: 8)
                    Button(action: { showManagement = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                            Text("Créer").font(RUFont.sans(.small, weight: .semibold))
                        }
                        .foregroundColor(RUColor.rose2)
                        .padding(8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                }
                Text("Aucun défi en cours — un objectif de kilomètres à se partager, avec une date de fin.")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
        .padding(.top, 6)
    }

    private var clubTabs: some View {
        HStack(spacing: 2) {
            // `segment` reçoit un `String` (et non un littéral posé directement dans un `Text`) :
            // sans `String(localized:)` ces libellés ne passeraient jamais par le catalogue.
            segment(String(localized: "Aperçu"), .overview)
            segment(String(localized: "Classement"), .board)
            segment(String(localized: "Activité"), .feed)
        }
        .padding(3)
        .background(RUColor.bg2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    /// Rien n'est lancé : pas un kilomètre cette semaine, pas de défi, pas de sortie prévue.
    ///
    /// Les trois sections du haut de l'Aperçu, prises ensemble. Séparément, chacune a une bonne
    /// raison d'afficher sa phrase d'absence ; empilées, elles font une page qui ne dit rien
    /// trois fois.
    private var clubEnSommeil: Bool {
        (board.weekStats?.totalKm ?? 0) == 0
            && board.challenge == nil
            && (board.events ?? []).isEmpty
    }

    /// À plusieurs, mais rien de lancé. Les deux actions sont celles que portaient les
    /// intertitres de « Défi du club » et « Sorties de groupe » — elles ne sont pas perdues avec
    /// les sections, elles sont réunies là où quelqu'un les cherchera.
    private var carteClubAReveiller: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rien n'est lancé pour l'instant")
                .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
            Text("Un défi à se partager, ou une sortie à proposer : c'est ce qui donne au club une raison de se retrouver cette semaine.")
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                .fixedSize(horizontal: false, vertical: true)
            // PAS DE `minHeight: 44` ICI — voir la note sur le bouton « Partager » plus bas.
            // Le style le garantit déjà ; le réécrire dans le libellé l'EMPILE sous les marges
            // du style et donne un pavé de soixante-douze points.
            HStack(spacing: 10) {
                Button(action: { showManagement = true }) {
                    Text("Créer un défi")
                        .font(RUFont.sans(.label, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                Button(action: { showCreateEvent = true }) {
                    Text("Proposer une sortie")
                        .font(RUFont.sans(.label, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    /// SEULE DANS SON CLUB : LA SEULE CHOSE À FAIRE, ET ELLE EST DITE DEUX FOIS AU MÊME ENDROIT.
    ///
    /// Cette carte vivait dans l'onglet Activité, c'est-à-dire sur le troisième onglet d'un
    /// écran qui s'ouvre sur le premier. Un club d'une personne n'a pourtant qu'un seul sujet —
    /// trouver la deuxième — et l'Aperçu lui répondait par trois sections vides empilées :
    /// « Personne n'a encore couru cette semaine », « Aucun défi en cours », « Aucune sortie
    /// prévue ». Trois fois rien, en trois intertitres de même taille que de vraies sections.
    ///
    /// Elle est donc partagée par les deux onglets plutôt que recopiée : un lien de partage
    /// dupliqué, c'est une des deux copies qui garde l'ancienne URL le jour où elle change.
    @ViewBuilder private var carteClubSeul: some View {
        if let club = board.club {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: Accord.selon(f: String(localized: "Tu es seule dans \(club.name)"),
                                            m: String(localized: "Tu es seul dans \(club.name)")))
                    .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                // LE LIEN A REMPLACÉ LE CODE.
                //
                // Ce bloc affichait un code à six lettres et proposait de le partager, puis
                // il a dit « cherche son nom dans l'onglet Club » — une consigne, et qui
                // désignait un onglet qui n'existe plus. Il n'y a qu'une chose à envoyer
                // maintenant, et c'est le lien juste en dessous.
                Text("Un club prend vie à plusieurs — classement, défis, sorties de groupe. Envoie son lien aux gens avec qui tu cours.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                    .fixedSize(horizontal: false, vertical: true)
                // UN VRAI LIEN, ENFIN. Ce message disait « cherche-le par son nom dans
                // l'onglet Club » : une consigne, pas une invitation. Le lien ouvre
                // maintenant la page publique du club — sa photo, sa ville, ses
                // prochaines séances — et, sur un iPhone où l'app est installée,
                // directement l'app.
                // LE PAVÉ GRIS DE SOIXANTE-DOUZE POINTS, ET D'OÙ IL VENAIT.
                //
                // `SecondaryButtonStyle` garantit DÉJÀ la cible de 44 points — c'est écrit dans
                // son corps : `.padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 44)`.
                // Le libellé en redemandait 44 de son côté, et les deux ne se recouvrent pas :
                // le style ajoute ses 14 points EN HAUT ET EN BAS d'un libellé déjà haut de 44.
                // D'où 72 points de haut pour le mot « Partager » — un aplat gris qui occupait
                // un tiers de la carte et la faisait ressembler à un formulaire.
                //
                // Et `GhostButtonStyle` plutôt que `Secondary`, parce que c'est le style de
                // partage de la maquette : sa propre documentation cite « Partager ce badge » et
                // « Partager ta course ». Fond de carte, libellé en accent — l'action se voit
                // par sa COULEUR au lieu de se voir par sa masse.
                ShareLink(item: String(localized: "Rejoins mon club \(club.name) sur RUNUP : https://runup-nu.vercel.app/club/\(club.id)")) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Partager")
                    }
                    .font(RUFont.sans(.label, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RUSpacing.cardPadding)
            .ruCard()
        }
    }

    /// Contenu de l'onglet Aperçu : « où en est le club en ce moment ». L'ordre suit celui de la
    /// maquette — l'état collectif (niveau, pouls, défi) d'abord, puis ce qui appelle une action
    /// (les sorties), puis qui est là. La ligne d'adhésion (signaler / quitter) descend en bas de
    /// cet onglet : c'est de l'administration, elle n'a jamais eu à être au-dessus du classement.
    private var overviewContent: some View {
        // SERRÉ DANS UN GROUPE, LARGE ENTRE DEUX — et c'était 10 des deux côtés.
        //
        // Chaque section empile son intertitre et son contenu à 10 points, et les sections
        // étaient espacées de 10 + les 6 de leur `padding(.top)`, soit 16. Seize contre dix :
        // l'œil ne distingue pas les deux, donc il ne voit pas des groupes, il voit une liste
        // de lignes également séparées. C'est ce qui donne à la page son air de brouillon.
        //
        // 18 porte l'écart entre sections à 24 contre 10 à l'intérieur. Un rapport de 1 à 2,4
        // suffit à ce que le groupement se lise sans qu'on ait à y penser.
        VStack(alignment: .leading, spacing: 18) {
            // UNE ICÔNE POUR LA PAGE, AUCUNE POUR SES SECTIONS.
            //
            // Quatre couleurs tenaient lieu de titres sur cet écran — rose pour la semaine,
            // rose2 pour le défi, violet pour les sorties, ambre pour le classement — soit
            // quatre teintes pour quatre intertitres de même niveau, qui ne distinguaient rien
            // d'autre qu'elles-mêmes. C'est la règle déjà appliquée à la page d'une course et au
            // profil de quelqu'un ; elle manquait ici, sur l'écran qui en empile le plus.
            //
            // LA PAGE DU CLUB S'OUVRE SUR LE CLUB, PAS SUR MOI.
            //
            // Le premier bloc était ma carte de niveau : le plus saturé de l'écran, un dégradé
            // violet plein cadre — et une statistique PERSONNELLE en tête d'une page
            // collective. On ouvrait « Les Foulées du Canal » et on lisait « Niveau 17 ». Mon
            // niveau n'a pas disparu, il est descendu à sa place : après ce que le club fait.

            // TROIS FOIS RIEN N'EST PAS TROIS SECTIONS.
            //
            // Un club qui démarre ouvrait sur « Personne n'a encore couru cette semaine »,
            // « Aucun défi en cours » et « Aucune sortie prévue » — trois intertitres de la
            // taille d'une vraie section, pour dire trois fois qu'il n'y a rien. C'est tout
            // le premier écran, et c'est la première impression que donne un club.
            //
            // Quand les trois sont vides, elles cèdent la place à UN bloc qui dit quoi faire.
            // Seule, c'est trouver la deuxième personne — la carte qui le dit existait déjà,
            // mais sur l'onglet Activité, qu'on n'ouvre pas quand on vient d'arriver. À
            // plusieurs, ce sont les deux boutons que portaient les intertitres disparus.
            if clubEnSommeil {
                if board.club.map({ $0.memberCount <= 1 }) == true {
                    carteClubSeul
                } else {
                    carteClubAReveiller
                }
            } else {
                weekPulseCard
                challengeCard
                eventsCard
            }
            // CE QU'UN CLASSEMENT NE DIT PAS. Un tableau hebdomadaire dit qui court le plus ;
            // il ne dit ni vers quoi le club court, ni ce qu'il a déjà réussi. Les deux
            // sections ci-dessous ne demandent aucune donnée nouvelle — elles étaient dans les
            // courses suivies et dans les sorties publiées, jamais regardées ensemble.
            coursesDuClub
            seancesTenues
            recordsDuClub
            levelCard
        }
        .task { await chargerLesPepites() }
    }

    // MARK: - Ce que le club prépare

    @ViewBuilder
    private var coursesDuClub: some View {
        if let courses = highlights?.races, !courses.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                RUCardHeader(title: "Ce que le club prépare")
                VStack(spacing: 0) {
                    ForEach(Array(courses.enumerated()), id: \.element.id) { rang, course in
                        if rang > 0 { boardDivider }
                        ligneDeCourseDuClub(course)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func ligneDeCourseDuClub(_ course: ClubRace) -> some View {
        Button(action: { appState.ouvrirLaCourse(course.race) }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if let jours = course.race.joursRestants, jours >= 0 {
                        Text(jours == 0 ? String(localized: "C'est aujourd'hui")
                                        : String(localized: "J-\(jours)"))
                            .font(RUFont.sans(.micro, weight: .bold)).tracking(0.6)
                            .foregroundColor(RUColor.rose2)
                    }
                    Text(course.race.name)
                        .font(RUFont.sans(.label, weight: .semibold))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1)
                    if !course.race.sousTitre.isEmpty {
                        Text(course.race.sousTitre)
                            .font(RUFont.sans(.small))
                            .foregroundColor(RUColor.text3)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                // Les visages, et le compte à côté. « 3 » seul ne dit pas QUI prépare la même
                // course que moi — et c'est exactement la question qu'on se pose en lisant cette
                // liste dans un club.
                HStack(spacing: -8) {
                    ForEach(course.runners) { coureur in
                        AvatarView(urlString: coureur.avatarUrl, base64DataURI: coureur.avatarBase64,
                                   initial: String(coureur.name.prefix(1)), size: 26, seed: coureur.id)
                            .overlay(Circle().stroke(RUColor.bg, lineWidth: 2))
                    }
                }
                if course.members > course.runners.count {
                    Text("+\(course.members - course.runners.count)")
                        .font(RUFont.sans(.small, weight: .bold))
                        .foregroundColor(RUColor.text2)
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Pluriel.choisir(course.members,
            String(localized: "\(course.race.name), \(course.members) membre la prépare"),
            String(localized: "\(course.race.name), \(course.members) membres la préparent")))
    }

    // MARK: - Les séances tenues

    /// « ON ÉTAIT 28 MARDI DERNIER. »
    ///
    /// La phrase dont un crew est fier, et la seule preuve qu'un club VIT : un classement dit
    /// qui court, pas si on se retrouve. Elle n'existait nulle part — une séance hebdomadaire
    /// s'avance d'une semaine et vide ses présences, donc ce qui s'était passé disparaissait
    /// chaque semaine au profit de la suivante.
    ///
    /// La MOYENNE d'abord, le total ensuite : vingt séances à trois personnes et vingt séances à
    /// trente ne sont pas le même club, et c'est la moyenne qui le dit.
    @ViewBuilder
    private var seancesTenues: some View {
        if let histo = highlights?.sessionHistory, histo.total > 0 {
            VStack(alignment: .leading, spacing: 10) {
                RUCardHeader(title: "Les séances tenues")
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(histo.averageAttendees)")
                        .displayStyle(26)
                        .foregroundColor(RUColor.textPrimary)
                    // Pas de `Pluriel` ici : « au départ en moyenne » ne s'accorde pas, et
                    // appeler le choix de pluriel avec deux fois la même phrase donnerait deux
                    // clés identiques au catalogue et un faux air de règle.
                    Text("au départ en moyenne")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    Spacer(minLength: 8)
                    Text(Pluriel.choisir(histo.total,
                                         String(localized: "\(histo.total) séance"),
                                         String(localized: "\(histo.total) séances")))
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                }
                VStack(spacing: 0) {
                    ForEach(Array(histo.recent.enumerated()), id: \.element.id) { rang, seance in
                        if rang > 0 { boardDivider }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.semaineFormatter.string(from: seance.heldAt))
                                    .font(RUFont.sans(.micro, weight: .bold)).tracking(0.6)
                                    .foregroundColor(RUColor.text3)
                                Text(seance.title)
                                    .font(RUFont.sans(.body, weight: .semibold))
                                    .foregroundColor(RUColor.textPrimary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text("\(seance.attendees) au départ")
                                .font(RUFont.sans(.body, weight: .semibold))
                                .foregroundColor(RUColor.text2)
                        }
                        .padding(.vertical, 11)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Les records du club

    @ViewBuilder
    private var recordsDuClub: some View {
        let records = highlights?.records ?? []
        if !records.isEmpty || highlights?.bestWeek != nil {
            VStack(alignment: .leading, spacing: 10) {
                RUCardHeader(title: "Les records du club")
                VStack(spacing: 0) {
                    // LE RECORD COLLECTIF EN TÊTE, et c'est l'ordre juste : les trois suivants
                    // nomment quelqu'un, celui-ci dit ce que le club a fait ENSEMBLE. Sur la page
                    // d'un club, c'est la phrase la plus à sa place.
                    if let semaine = highlights?.bestWeek {
                        ligneDeLaMeilleureSemaine(semaine)
                        if !records.isEmpty { boardDivider }
                    }
                    ForEach(Array(records.enumerated()), id: \.element.id) { rang, record in
                        if rang > 0 { boardDivider }
                        ligneDeRecord(record)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    /// Pas d'avatar, et c'est le propos : personne ne possède cette ligne.
    ///
    /// Mais sa PLACE est gardée. Sans ce vide de 32 points, son intitulé commençait au bord de
    /// l'écran pendant que les trois records nominatifs démarraient derrière leur photo : quatre
    /// lignes d'une même liste avec deux marges gauches différentes. L'absence de visage se lit
    /// alors comme un défaut d'alignement, là où elle doit se lire comme ce qu'elle est —
    /// personne ne possède ce record.
    private func ligneDeLaMeilleureSemaine(_ semaine: ClubBestWeek) -> some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 32, height: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("LA PLUS GROSSE SEMAINE")
                    .font(RUFont.sans(.micro, weight: .bold)).tracking(0.6)
                    .foregroundColor(RUColor.text3)
                // 19 → 21, soit 22,9 pt rendus. C'EST LE CHIFFRE QU'ON VIENT LIRE, et il
                // passait derrière l'intertitre qui le surplombe (20,0 avant, 17,5 depuis).
                // Dans une app de course, la mesure est le contenu ; « Les records du club »
                // n'est que l'étagère sur laquelle elle est posée.
                Text(Distances.km(semaine.km))
                    .displayStyle(21)
                    .foregroundColor(RUColor.textPrimary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Pluriel.choisir(semaine.runners,
                                     String(localized: "\(semaine.runners) coureuse"),
                                     String(localized: "\(semaine.runners) coureuses")))
                    .font(RUFont.sans(.body, weight: .semibold))
                    .foregroundColor(RUColor.text2)
                Text(Self.semaineFormatter.string(from: semaine.startsAt))
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text3)
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    /// « semaine du 6 oct. » — le lundi, puisque c'est là que la semaine du club commence.
    private static let semaineFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f
    }()

    /// Chaque record OUVRE la sortie qui le porte. Un record qu'on ne peut pas aller voir est une
    /// ligne de statistique ; un record qui mène au tracé, aux splits et au profil de celle qui
    /// l'a couru est une histoire du club.
    private func ligneDeRecord(_ record: ClubRecord) -> some View {
        Button(action: { appState.ouvrirLaSortie(record.activityId) }) {
            HStack(spacing: 12) {
                AvatarView(urlString: record.avatarUrl, base64DataURI: record.avatarBase64,
                           initial: String(record.name.prefix(1)), size: 32, seed: record.userId)
                VStack(alignment: .leading, spacing: 2) {
                    Text(libelleDuRecord(record.genre))
                        .font(RUFont.sans(.micro, weight: .bold)).tracking(0.6)
                        .foregroundColor(RUColor.text3)
                    Text(valeurDuRecord(record))
                        .displayStyle(21)
                        .foregroundColor(RUColor.textPrimary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.name)
                        .font(RUFont.sans(.body, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                        .lineLimit(1)
                    Text(record.createdAt.relativeDescription)
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }

    private func libelleDuRecord(_ genre: String) -> String {
        switch genre {
        case "distance": return String(localized: "LA PLUS LONGUE")
        case "allure": return String(localized: "LA PLUS RAPIDE")
        default: return String(localized: "LE PLUS DE DÉNIVELÉ")
        }
    }

    private func valeurDuRecord(_ record: ClubRecord) -> String {
        switch record.genre {
        case "distance":
            return record.distanceKm.map { Distances.km($0) } ?? "—"
        case "allure":
            // « /km » accolé à l'allure : sans l'unité, « 4:12 » se lit comme un temps.
            return record.secPerKm.map { String(localized: "\(TimeFormat.allure(secondesParKm: $0)) /km") } ?? "—"
        default:
            return record.elevationGainM.map { "\($0) m" } ?? "—"
        }
    }

    private func chargerLesPepites() async {
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

    private func boardModeChip(_ label: String, _ value: BoardMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { boardMode = value }
        }) {
            Text(label)
                .font(RUFont.sans(.small, weight: .semibold))
                .foregroundColor(boardMode == value ? RUColor.rose2 : RUColor.text2)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .frame(minHeight: 44)
                // Les deux branches de ce ternaire valaient `card2` : le sélecteur ne changeait
                // donc de REMPLISSAGE jamais, et la pastille active ne se distinguait que par un
                // filet et une nuance de texte — le signal le plus faible de l'app. Tous ses
                // voisins écrivent `card2 : card`.
                .background(boardMode == value ? RUColor.card2 : RUColor.card, in: Capsule())
                .overlay(Capsule().stroke(boardMode == value ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(boardMode == value ? .isSelected : [])
    }

    private func segment(_ label: String, _ value: Tab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { tab = value }
            if value == .feed && feed.isEmpty { Task { await loadFeed() } }
        }) {
            Text(label)
                .font(RUFont.sans(.label, weight: .semibold))
                // Pastille NEUTRE (surface de carte sur rail `bg2`), pas un aplat d'accent —
                // deux raisons. D'abord la règle que la maquette applique partout : l'accent
                // souligne, il ne remplit pas. Ensuite, et c'est décisif ici, `SocialView`
                // affiche déjà juste au-dessus son propre sélecteur « Mon club / Mes amis » en
                // aplat rose : deux barres roses empilées à 8 pt l'une de l'autre ne se
                // hiérarchisent plus du tout. Accent pour le choix de destination principale,
                // neutre pour la navigation interne à l'écran.
                .foregroundColor(tab == value ? RUColor.textPrimary : RUColor.text3)
                // Back to its original compact size, no enforced 44pt minimum — she found the
                // audit's forced-44pt height on this pill too big and asked for it back.
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(tab == value ? RUColor.card : .clear, in: RoundedRectangle(cornerRadius: RUSpacing.radiusChip, style: .continuous))
                .shadow(color: .black.opacity(tab == value && RUColor.isLight ? 0.08 : 0), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }

    /// Mes badges. Le calcul vit dans `ClubBadgeEngine` (RunUp/Services) depuis que le profil
    /// les affiche aussi : deux écrans, une seule dérivation.
    private var badges: [ClubBadge] { ClubBadgeEngine.badges(runs: runs, profile: profile) }

    /// The club's pulse this week — real collective km + how many members actually ran, computed
    /// server-side over this Monday-started week. Gives the club a shared "we" number, not just
    /// individual rankings.
    /// Les kilomètres du club cette semaine, et qui les a courus.
    ///
    /// Le nombre de membres actifs vivait ici, en chiffre, ET trois cartes plus bas en pile
    /// d'avatars sous son propre intertitre « Membres actifs cette semaine ». Deux blocs pour un
    /// seul fait, séparés par le défi et les sorties de groupe — assez loin l'un de l'autre pour
    /// qu'on ne remarque pas que c'est le même. Les visages remplacent le chiffre : ils le
    /// contiennent (on les compte) et disent en plus QUI, ce que « 4 » ne dira jamais.
    private var weekPulseCard: some View {
        let stats = board.weekStats
        let km = String(format: "%.1f", locale: Locale.current, stats?.totalKm ?? 0)
        let active = (board.weekly ?? []).filter { $0.weekKm > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    RUCardHeader(title: "Le club cette semaine", subtitle: "Kilomètres cumulés")
                    // « 0,0 KM » EN GRAND N'EST PAS UNE INFORMATION, C'EST UN REPROCHE.
                    //
                    // Un club qui démarre, ou un lundi matin, ouvrait sur un zéro de vingt-six
                    // points dans un cadre plein. Le chiffre ne s'écrit donc en grand que
                    // lorsqu'il y a quelque chose à écrire ; sinon, une phrase.
                    if stats?.totalKm ?? 0 > 0 {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(km).displayStyle(26).foregroundColor(RUColor.textPrimary)
                            Text("KM").font(RUFont.sans(.small, weight: .bold)).foregroundColor(RUColor.text2)
                        }
                    } else {
                        Text("Personne n'a encore couru cette semaine.")
                            .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    }
                }
                Spacer(minLength: 8)
            }
            if !active.isEmpty {
                HStack(spacing: 10) {
                    HStack(spacing: -8) {
                        ForEach(active.prefix(6)) { member in
                            AvatarView(
                                urlString: member.avatarUrl,
                                base64DataURI: member.avatarBase64,
                                initial: String(member.name.prefix(1)),
                                size: 28,
                                seed: member.isMe ? nil : member.id
                            )
                            .overlay(Circle().stroke(RUColor.card, lineWidth: 2))
                        }
                        if active.count > 6 {
                            Text("+\(active.count - 6)")
                                .font(RUFont.sans(.small, weight: .bold))
                                .foregroundColor(RUColor.text2)
                                .frame(width: 28, height: 28)
                                .background(RUColor.card2, in: Circle())
                                .overlay(Circle().stroke(RUColor.card, lineWidth: 2))
                        }
                    }
                    Text(Pluriel.choisir(active.count,
                                         String(localized: "\(active.count) membre a couru"),
                                         String(localized: "\(active.count) membres ont couru")))
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Pluriel.choisir(active.count,
                                                    String(localized: "\(active.count) membre a couru cette semaine"),
                                                    String(localized: "\(active.count) membres ont couru cette semaine")))
            }
        }
    }

    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEE d MMM · HH:mm"
        return f
    }()

    private static let eventTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "HH:mm"
        return f
    }()

    /// « CE SOIR · 18:00 » plutôt que « MER 13 AOÛT · 18:00 » quand la sortie est aujourd'hui.
    ///
    /// La maquette insiste sur ce point et elle a raison : une sortie de groupe est une chose à
    /// laquelle on décide de se joindre MAINTENANT, et une date complète oblige à comparer
    /// mentalement avec le jour qu'on est. Purement du formatage — la donnée reste `startsAt`.
    private func eventDateLabel(_ date: Date) -> String {
        let time = Self.eventTimeFormatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            return Calendar.current.component(.hour, from: date) >= 17
                ? String(localized: "CE SOIR · \(time)")
                : String(localized: "AUJOURD'HUI · \(time)")
        }
        if Calendar.current.isDateInTomorrow(date) { return String(localized: "DEMAIN · \(time)") }
        return Self.eventDateFormatter.string(from: date).uppercased()
    }

    /// Sorties de groupe — real proposed group runs with RSVP. The one feature that turns a
    /// leaderboard into an actual club: people running TOGETHER.
    /// Une SECTION, plus une carte-dans-carte.
    ///
    /// L'onglet Vue d'ensemble empilait quatre cartes de même largeur et de même chrome — le
    /// niveau, la semaine, le défi, les sorties — et c'est cette répétition qui faisait le « mur
    /// de boîtes » reproché à tout l'écran. Les sorties sont une LISTE : l'intertitre passe sur
    /// la page (le motif de « Mon équipement » sur le Profil), et chaque sortie devient sa propre
    /// petite carte. La page respire ; le défi, désormais seule carte teintée après le héros
    /// violet, redevient le point focal communautaire qu'il doit être.
    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(title: "Sorties de groupe") {
                Button(action: { showCreateEvent = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Proposer").font(RUFont.sans(.small, weight: .semibold))
                    }
                    .foregroundColor(RUColor.rose2)
                    .padding(8)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
            if (board.events ?? []).isEmpty {
                Text("Aucune sortie prévue — propose un créneau, les autres n'ont qu'à dire « J'y serai ».")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    .padding(.horizontal, 2)
            }
            ForEach(board.events ?? []) { event in
                VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(eventDateLabel(event.startsAt))
                                .font(RUFont.sans(.micro, weight: .bold)).tracking(0.6).foregroundColor(RUColor.rose2)
                            // « CHAQUE SEMAINE », écrit. Sans ça, une séance qui revient se lit
                            // comme une sortie de plus, et c'est tout le contraire : c'est LE
                            // rendez-vous du club, celui autour duquel le reste s'organise.
                            if event.repeatsWeekly == true {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 8, weight: .bold))
                                    Text("CHAQUE SEMAINE")
                                }
                                .font(RUFont.sans(.micro, weight: .bold)).tracking(0.4)
                                .foregroundColor(RUColor.text3)
                            }
                        }
                        Text(event.title).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin").font(.system(size: 8))
                                Text(location).font(RUFont.sans(.small))
                            }
                            .foregroundColor(RUColor.text2)
                        }
                    }
                    Spacer()
                    Button(action: { toggleRsvp(event) }) {
                        VStack(spacing: 2) {
                            Text(event.goingByMe ? "J'y serai ✓" : "J'y serai")
                                .font(RUFont.sans(.small, weight: .bold))
                                .foregroundColor(event.goingByMe ? .white : RUColor.textPrimary)
                                .padding(.horizontal, 11).padding(.vertical, 6)
                                .background(event.goingByMe ? RUColor.rose : RUColor.card2, in: Capsule())
                                .overlay(Capsule().stroke(event.goingByMe ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                            Text("\(event.going) au départ")
                                .font(RUFont.sans(.micro)).foregroundColor(RUColor.text2)
                        }
                        // La capsule fait 25 pt de haut. C'est la seule action sociale de la carte
                        // des sorties, et elle est isolée : rien autour pour rattraper une frappe
                        // qui tombe à côté. La zone tapable monte à 44, la pastille ne bouge pas —
                        // le même traitement que les boutons-icônes de l'app.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                }
                groupesDAllure(event)
                }
                .padding(12)
                .ruCard(radius: RUSpacing.radiusCompact)
                .contextMenu {
                    if event.isMine {
                        Button("Annuler cette sortie", role: .destructive) { deleteEvent(event) }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateEvent) {
            CreateEventSheet { title, location, date, chaqueSemaine, groupes in
                let created = try await clubService.createEvent(title: title, location: location, startsAt: date,
                                                                repeatsWeekly: chaqueSemaine, paceGroups: groupes)
                await MainActor.run {
                    var events = board.events ?? []
                    events.append(created)
                    events.sort { $0.startsAt < $1.startsAt }
                    board.events = events
                }
            }
            .runUpSheetStyle()
        }
    }

    /// LES GROUPES D'ALLURE, SANS LESQUELS UNE SORTIE DE CREW NE FONCTIONNE PAS.
    ///
    /// Trente personnes au départ ne courent pas ensemble : elles partent par groupes — « 4:30 »,
    /// « 5:15 », « 6:00 et on discute ». Dire « j'y serai » sans dire à quelle allure laisse
    /// l'organisateur sans la seule information dont il ait besoin : combien de meneurs prévoir.
    ///
    /// Taper un autre groupe que le sien DÉPLACE, ça ne décommande pas : c'est le geste qu'on
    /// fait vraiment, et le contraire aurait fait disparaître sa présence d'un doigt mal posé.
    @ViewBuilder
    private func groupesDAllure(_ event: ClubEvent) -> some View {
        let groupes = event.paceGroups ?? []
        if !groupes.isEmpty {
            // Horizontal : un club peut en proposer huit, et huit pastilles sur une ligne fixe
            // se réduiraient jusqu'à l'illisible.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(groupes, id: \.self) { groupe in
                        let choisi = event.myPaceGroup == groupe
                        let compte = event.paceCounts?[groupe] ?? 0
                        Button(action: { toggleRsvp(event, groupe: groupe) }) {
                            HStack(spacing: 5) {
                                Text(groupe)
                                    .font(RUFont.sans(.small, weight: .bold))
                                if compte > 0 {
                                    Text("\(compte)")
                                        .font(RUFont.sans(.small))
                                        .foregroundColor(choisi ? RUColor.onRose.opacity(0.8) : RUColor.text3)
                                }
                            }
                            .foregroundColor(choisi ? RUColor.onRose : RUColor.text2)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                            .background(choisi ? RUColor.rose : RUColor.card2, in: Capsule())
                            .overlay(Capsule().stroke(choisi ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(String(localized: "Groupe \(groupe)"))
                        .accessibilityValue(Pluriel.choisir(compte,
                                                            String(localized: "\(compte) personne"),
                                                            String(localized: "\(compte) personnes")))
                        .accessibilityAddTraits(choisi ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func toggleRsvp(_ event: ClubEvent, groupe: String? = nil) {
        Haptics.selection()
        Task {
            do {
                let result = try await clubService.toggleEventRsvp(eventId: event.id, paceGroup: groupe)
                await MainActor.run {
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
                }
            } catch ClubServiceError.badResponse(404, _) {
                // The event was already cancelled/expired server-side — leaving it in the local
                // list would just let her tap it again and fail identically every time.
                await MainActor.run { board.events?.removeAll { $0.id == event.id } }
            } catch {
                await MainActor.run { appState.toast(String(localized: "Impossible de répondre — réessaie.")) }
            }
        }
    }

    private func deleteEvent(_ event: ClubEvent) {
        Task {
            do {
                try await clubService.deleteEvent(eventId: event.id)
                await MainActor.run { board.events?.removeAll { $0.id == event.id } }
            } catch ClubServiceError.badResponse(404, _) {
                // Already gone server-side — still fine to drop it locally.
                await MainActor.run { board.events?.removeAll { $0.id == event.id } }
            } catch {
                // A real failure (network, 403 not-the-creator, ...) — keep it in the list rather
                // than silently pretending the cancel worked when it didn't.
                await MainActor.run { appState.toast(String(localized: "Impossible d'annuler la sortie — réessaie.")) }
            }
        }
    }

    /// Split out of what used to be one large `boardContent` body — three near-identical ~25-line
    /// row blocks plus a triple `if`/`.transition()` chain in a single ViewBuilder expression was
    /// enough to blow the type-checker's budget (`unable to type-check this expression in
    /// reasonable time`, a real build failure on-device, not just a style nit). Breaking it into
    /// these smaller pieces is exactly the fix Xcode's own error message suggests, and doubles as
    /// the same `Group { if ... }` fix `HomeView.programWeekCard` already needed elsewhere in this
    /// app: an `if` with no `else` can't take a modifier directly.
    private var boardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Two real races: km of THIS week (Monday reset — a newcomer can win her first week)
            // and the all-time XP board.
            HStack(spacing: 6) {
                boardModeChip(String(localized: "Cette semaine"), .week)
                boardModeChip(String(localized: "Général (XP)"), .general)
            }
            Group {
                if boardMode == .week {
                    weekBoardContent
                } else {
                    generalBoardContent
                }
            }
            .transition(.opacity)

        }
    }

    /// Ranked by raw `weekKm` (the server's own order) in `.km` mode; re-ranked client-side by
    /// `pctOfTarget` in `.pctObjectif` mode — the server always orders by km since that's the one
    /// true race everyone shares, but "closest to YOUR OWN plan" is a different ranking entirely
    /// (a beginner at 110% of her plan legitimately outranks a marathoner at 70% of his, even
    /// though his raw km is much higher). Rows with no `pctOfTarget` (hasn't opened Club since
    /// this shipped, or course libre) sort to the bottom rather than being dropped — still visible,
    /// just falls back to a plain km display for that one row.
    private var rankedWeekly: [WeeklyRow] {
        let rows = board.weekly ?? []
        guard weeklyDisplayMode == .pctObjectif else { return rows }
        return rows.sorted { a, b in
            switch (a.pctOfTarget, b.pctOfTarget) {
            case let (pa?, pb?): return pa > pb
            case (nil, nil): return a.weekKm > b.weekKm
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    private var weekBoardContent: some View {
        Group {
            if (board.weekly ?? []).isEmpty && !isLoading {
                Text("Personne n'a encore couru cette semaine — lance-toi !")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                // La bascule Km / % objectif était posée seule, alignée à droite, sans rien
                // dire de ce qu'elle bascule. La maquette lui donne son titre de section sur la
                // même ligne — c'est ce qui fait qu'on comprend « classement DE LA SEMAINE » et
                // pas « classement tout court, avec un réglage mystérieux ».
                HStack {
                    RUCardHeader(title: "Classement de la semaine")
                    Spacer(minLength: 8)
                    weeklyDisplayModePicker
                }
                .padding(.bottom, 2)
                weekBoardRows
            }
        }
    }

    private var weekBoardRows: some View {
        let rows = rankedWeekly
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                if index > 0 && !entry.isMe && !rows[index - 1].isMe {
                    boardDivider
                }
                weekRow(entry, displayRank: index + 1)
            }
        }
    }

    /// Filet de séparation entre deux lignes de classement (`.lb-row`'s `border-top`).
    ///
    /// Les lignes étaient auparavant des cartes individuelles (fond `card2` + contour + rayon 14),
    /// empilées avec 6 pt d'écart : douze membres donnaient douze cartes à contours, soit un
    /// classement qui ressemblait à une liste de réglages. Un classement est une seule et même
    /// liste ordonnée — un filet entre les lignes le dit, et ça permet d'en afficher nettement
    /// plus par écran. La ligne « toi » garde, elle, son fond teinté : c'est le seul repère qui
    /// doit sauter aux yeux, et il ressort beaucoup mieux maintenant qu'il est le seul fond de la
    /// liste (le filet saute de part et d'autre pour ne pas venir couper ce bloc arrondi).
    private var boardDivider: some View {
        Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
    }

    /// Same pill-in-capsule idiom as `StatsView.rangePicker` — Km vs. "% objectif" for the weekly
    /// board only (the all-time XP/global boards have no personal target to compare against).
    private var weeklyDisplayModePicker: some View {
        HStack(spacing: 3) {
            ForEach(WeeklyDisplayMode.allCases) { mode in
                Button(action: {
                    Haptics.selection()
                    weeklyDisplayMode = mode
                }) {
                    Text(mode == .km ? "Km" : "% objectif")
                        // Était en chasse fixe : deux mots de réglage dans une typographie que
                        // rien d'autre de l'écran n'emploie, à côté d'un titre de section en
                        // sans. La chasse fixe sert les CHIFFRES qui s'alignent en colonne,
                        // pas les étiquettes.
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(weeklyDisplayMode == mode ? .white : RUColor.text2)
                        // Même hauteur que le sélecteur de période des Stats, dont c'est l'idiome.
                        .padding(.horizontal, 9).padding(.vertical, 9)
                        .background(
                            // Même dégradé d'accent que partout ailleurs, via le token partagé
                            // (`--ru-gradient` de la maquette) plutôt qu'un couple recopié à la
                            // main — c'est exactement ce que `RUColor.accentGradient` centralise.
                            weeklyDisplayMode == mode
                                ? AnyShapeStyle(RUColor.accentGradient(from: .top, to: .bottom))
                                : AnyShapeStyle(Color.clear),
                            in: Capsule()
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: weeklyDisplayMode)
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(weeklyDisplayMode == mode ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RUColor.card2, in: Capsule())
    }

    /// LE RANG, ÉCRIT TROIS FOIS ET SANS MÉDAILLE.
    ///
    /// Les trois premières places portaient 🥇🥈🥉 — des émojis en couleurs d'impression au
    /// milieu d'une liste sombre et sobre, et la chose la moins chère à l'œil de tout l'écran.
    /// Un classement n'a pas besoin d'images pour dire qui mène : le chiffre le dit, et l'or de
    /// la première place suffit à la distinguer. Les deuxième et troisième reprennent leur rang,
    /// comme la quatrième et la cinquième — la hiérarchie est dans l'ordre de la liste, pas dans
    /// trois pastilles de couleur.
    ///
    /// Et il était recopié à l'identique dans les TROIS classements (semaine, général, mondial),
    /// donc corrigé une fois ici plutôt que trois fois là-bas.
    private func rang(_ valeur: Int, estMoi: Bool) -> some View {
        Text("\(valeur)")
            .displayStyle(15)
            .foregroundColor(estMoi ? RUColor.rose2 : (valeur == 1 ? RUColor.amber : RUColor.text2))
            .frame(width: 20)
    }

    private func weekRow(_ entry: WeeklyRow, displayRank: Int) -> some View {
        Button(action: { if !entry.isMe { appState.ouvrirLeProfil(entry.id) } }) {
        HStack(spacing: 12) {
            rang(displayRank, estMoi: entry.isMe)
            AvatarView(urlString: entry.avatarUrl, base64DataURI: entry.avatarBase64, initial: String(entry.name.prefix(1)), size: 28, seed: entry.isMe ? nil : entry.id)
            Text(entry.isMe ? String(localized: "\(entry.name) · toi") : entry.name)
                .font(RUFont.sans(.label, weight: entry.isMe ? .semibold : .regular))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if weeklyDisplayMode == .pctObjectif, let pct = entry.pctOfTarget {
                weeklyPctBadge(pct: pct, isMe: entry.isMe)
            } else {
                Text(verbatim: "\(String(format: "%.1f", locale: Locale.current, entry.weekKm)) km")
                    .displayStyle(14).foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.textPrimary)
            }
        }
        // Même retrait horizontal pour TOUTES les lignes (et non un retrait plus grand pour la
        // mienne, comme le fait la maquette avec sa marge négative) : ici les colonnes — rang,
        // avatar, nom — doivent rester alignées d'une ligne à l'autre, sinon la ligne « toi » a
        // l'air décalée par erreur. Le fond teinté suffit largement à la distinguer.
        .padding(.horizontal, 8)
        .padding(.vertical, 11)
        .background(entry.isMe ? RUColor.rose.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(entry.isMe)
    }

    /// A compact progress ring + percentage, replacing the raw-km number in "% objectif" mode —
    /// lime past 100% of plan (she's beaten her own target), rose otherwise. The ring itself is
    /// visually capped at a full circle past 100% (going further doesn't need to overflow the
    /// shape to read as "done and then some" — the number next to it already says 114%).
    private func weeklyPctBadge(pct: Int, isMe: Bool) -> some View {
        let fraction = min(Double(pct) / 100, 1)
        let color = pct >= 100 ? RUColor.lime : (isMe ? RUColor.rose2 : RUColor.textPrimary)
        return HStack(spacing: 6) {
            ZStack {
                Circle().stroke(RUColor.line, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
            Text("\(pct)%").displayStyle(14).foregroundColor(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pct) pour cent de l'objectif de la semaine")
    }

    private var generalBoardContent: some View {
        let rows = board.leaderboard
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                if index > 0 && !entry.isMe && !rows[index - 1].isMe {
                    boardDivider
                }
                generalRow(entry)
            }
        }
    }

    /// TOUTE LA LIGNE OUVRE LA PAGE DU MEMBRE, et c'est un `Button` et non un `onTapGesture`.
    ///
    /// La nuance a déjà coûté un défaut dans ce fichier : une bande qui défile, un geste de tape
    /// posé dessus, et taper pour arrêter l'inertie du défilement déclenchait l'action. Un
    /// `Button` placé dans une vue défilante ne répond pas à la tape qui arrête la décélération ;
    /// un `onTapGesture`, si. Sur un classement qu'on fait défiler, c'est la différence entre
    /// « j'ai arrêté la liste » et « je me retrouve sur le profil de quelqu'un ».
    private func generalRow(_ entry: LeaderboardRow) -> some View {
        Button(action: { if !entry.isMe { appState.ouvrirLeProfil(entry.id) } }) {
        HStack(spacing: 12) {
            rang(entry.rank, estMoi: entry.isMe)
            AvatarView(urlString: entry.avatarUrl, base64DataURI: entry.avatarBase64, initial: String(entry.name.prefix(1)), size: 28, seed: entry.isMe ? nil : entry.id)
            Text(entry.isMe ? String(localized: "\(entry.name) · toi") : entry.name)
                .font(RUFont.sans(.label, weight: entry.isMe ? .semibold : .regular))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text("\(entry.xp)").displayStyle(15).foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.textPrimary)
        }
        // Même chrome que `weekRow` ci-dessus (retrait uniforme, fond teinté pour « toi »).
        .padding(.horizontal, 8)
        .padding(.vertical, 11)
        .background(entry.isMe ? RUColor.rose.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        // Sa propre ligne ne mène nulle part : on est déjà à un onglet de son profil, et un
        // aller-retour vers soi-même n'apprend rien.
        .disabled(entry.isMe)
        .contextMenu {
            if !entry.isMe {
                Button("Signaler \(entry.name)") {
                    reportTarget = ReportTarget(targetType: "user", targetId: entry.id, displayName: entry.name)
                }
                Button("Bloquer \(entry.name)", role: .destructive) {
                    pendingBlock = (entry.id, entry.name)
                }
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

    private var feedContent: some View {
        // `LazyVStack` : le serveur renvoie 50 activités, et un `VStack` les construisait TOUTES
        // à l'ouverture de l'onglet — avatars décodés, deux passes d'ombre par carte, et
        // l'animation de révélation qui tournait sur ~45 lignes hors écran.
        LazyVStack(spacing: 0) {
            composeurDuMur
            if feed.isEmpty && posts.isEmpty && !isLoading {
                // Un fil vide a deux causes très différentes, et un seul message les traitait
                // toutes les deux. Seule dans son club, « sois la première » demande de poster
                // pour un public qui n'existe pas — ce qu'il faut, c'est des membres, et le code
                // d'invitation était rangé deux écrans plus loin, dans Gestion du club. À
                // plusieurs, la phrase d'origine est juste : il n'y a qu'à courir.
                if board.club.map({ $0.memberCount <= 1 }) == true {
                    carteClubSeul
                } else {
                    Text(verbatim: Accord.selon(f: String(localized: "Personne n'a encore rien posté — sois la première !"),
                                                m: String(localized: "Personne n'a encore rien posté — sois le premier !")))
                        .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            }
            // ENTRELACÉS PAR DATE, pas empilés en deux listes. Un mur posé au-dessus des
            // sorties se serait lu comme une annonce épinglée ; mêlés, un message de lundi et
            // une sortie de lundi se répondent, et c'est ce qui fait une conversation de club.
            ForEach(Array(entreesDuClub.enumerated()), id: \.element.id) { index, entree in
                switch entree {
                case .sortie(let item):
                    ActivityFeedRow(
                        item: item,
                        isMine: item.userId == auth.currentUser?.id,
                        revealed: feedRevealed,
                        index: index,
                        onKudos: { Task { await toggleKudos(item) } },
                        onComment: { commentsActivity = item },
                        onReport: {
                            reportTarget = ReportTarget(targetType: "activity", targetId: item.id, displayName: String(localized: "l'activité de \(item.name)"))
                        },
                        onBlock: { pendingBlock = (item.userId, item.name) },
                        onDelete: { pendingDeleteActivity = item },
                        onEdit: { editingActivity = item }
                    )
                case .message(let post):
                    VStack(spacing: 0) {
                        if index > 0 {
                            Rectangle().fill(RUColor.line)
                                .frame(height: RUSpacing.hairline)
                                .padding(.bottom, 16)
                        }
                        blocDeMessage(post)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }

    /// Une entrée de l'onglet Activité : une sortie, ou un message du mur. Deux formes, une seule
    /// liste triée — le même motif que le fil unique, pour la même raison.
    private enum EntreeDuClub: Identifiable {
        case sortie(FeedItem)
        case message(ClubPost)

        var id: String {
            switch self {
            case .sortie(let item): return "s-\(item.id)"
            case .message(let post): return "m-\(post.id)"
            }
        }

        var date: Date {
            switch self {
            case .sortie(let item): return item.createdAt
            case .message(let post): return post.createdAt
            }
        }
    }

    private var entreesDuClub: [EntreeDuClub] {
        // Seulement les messages de premier niveau : une réponse s'affiche sous le sien, pas
        // au milieu du fil où elle n'aurait plus de question.
        let messages = posts.filter { $0.parentId == nil }.map(EntreeDuClub.message)
        return (feed.map(EntreeDuClub.sortie) + messages).sorted { $0.date > $1.date }
    }

    private func reponses(a message: ClubPost) -> [ClubPost] {
        posts.filter { $0.parentId == message.id }.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Écrire sur le mur

    private var composeurDuMur: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reponseA {
                HStack(spacing: 6) {
                    Text("Réponse à \(reponseA.author.name)")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                    Button(action: { self.reponseA = nil }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(RUColor.text3)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Annuler la réponse")
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 10) {
                TextField(reponseA == nil
                          ? String(localized: "Dis quelque chose au club…")
                          : String(localized: "Ta réponse…"),
                          text: $brouillonDuClub, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.textPrimary)
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                // UN ACCENT ÉTEINT N'EST PAS UN ACCENT DÉSACTIVÉ, C'EST UN ACCENT CASSÉ.
                //
                // Le bouton inactif était le rose de l'app à 35 % : un disque bordeaux terne, qui
                // se lit comme une couleur ratée plutôt que comme un bouton en attente. Inactif,
                // il prend la surface neutre des autres boutons-icônes de l'app ; il ne devient
                // rose qu'au moment où il peut vraiment envoyer.
                Button(action: { Task { await publierSurLeMur() } }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(peutPublier ? RUColor.onRose : RUColor.text3)
                        .frame(width: 38, height: 38)
                        .background(peutPublier ? AnyShapeStyle(RUColor.rose) : AnyShapeStyle(RUColor.card2), in: Circle())
                        .overlay(Circle().stroke(peutPublier ? Color.clear : RUColor.line, lineWidth: RUSpacing.hairline))
                }
                .buttonStyle(PressableStyle())
                .disabled(!peutPublier)
                .accessibilityLabel("Publier sur le mur du club")
            }
        }
        .padding(.bottom, 16)
    }

    private var peutPublier: Bool {
        !brouillonDuClub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !envoiDuMessage
    }

    private func blocDeMessage(_ message: ClubPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            enTeteDeMessage(message)
            ForEach(reponses(a: message)) { reponse in
                HStack(alignment: .top, spacing: 8) {
                    Rectangle().fill(RUColor.line).frame(width: RUSpacing.hairline)
                    enTeteDeMessage(reponse)
                }
                .padding(.leading, 10)
            }
            HStack(spacing: 18) {
                Button(action: { Task { await applaudirLeMessage(message) } }) {
                    HStack(spacing: 7) {
                        Image(systemName: message.kudoedByMe ? "hands.clap.fill" : "hands.clap")
                            .font(.system(size: 15, weight: .regular))
                        if message.kudos > 0 {
                            Text("\(message.kudos)").font(RUFont.sans(.body, weight: .semibold))
                        }
                    }
                    .foregroundColor(message.kudoedByMe ? RUColor.rose : RUColor.text2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(message.kudoedByMe ? "Retirer ton applaudissement" : "Applaudir ce message")

                Button(action: {
                    reponseA = message
                    brouillonDuClub = ""
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: "bubble.right").font(.system(size: 15, weight: .regular))
                        let compte = reponses(a: message).count
                        if compte > 0 {
                            Text("\(compte)").font(RUFont.sans(.body, weight: .semibold))
                        }
                    }
                    .foregroundColor(RUColor.text2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(String(localized: "Répondre à \(message.author.name)"))
                Spacer(minLength: 0)
            }
        }
    }

    private func enTeteDeMessage(_ message: ClubPost) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                // Le bloc d'identité entier ouvre la page de la personne — la photo, le nom et
                // l'heure ensemble, comme partout ailleurs.
                Button(action: { if !message.isMine { appState.ouvrirLeProfil(message.author.id) } }) {
                    HStack(spacing: 8) {
                        AvatarView(urlString: message.author.avatarUrl, base64DataURI: message.author.avatarBase64,
                                   initial: String(message.author.name.prefix(1)), size: 32,
                                   seed: message.isMine ? nil : message.author.id)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(message.author.name)
                                .font(RUFont.sans(.label, weight: .bold))
                                .foregroundColor(RUColor.textPrimary)
                            Text(message.createdAt.relativeDescription)
                                .font(RUFont.sans(.small))
                                .foregroundColor(RUColor.text3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                Spacer(minLength: 0)
                Menu {
                    if message.isMine {
                        Button("Supprimer ce message", role: .destructive) {
                            Task { await supprimerLeMessage(message) }
                        }
                    } else {
                        Button("Signaler ce message") {
                            reportTarget = ReportTarget(targetType: "club_post", targetId: message.id,
                                                        displayName: message.author.name)
                        }
                        Button("Bloquer \(message.author.name)", role: .destructive) {
                            pendingBlock = (message.author.id, message.author.name)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RUColor.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Plus d'options")
            }
            Text(message.text)
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func publierSurLeMur() async {
        let texte = brouillonDuClub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texte.isEmpty else { return }
        envoiDuMessage = true
        defer { envoiDuMessage = false }
        do {
            try await clubService.postClubMessage(text: texte, parentId: reponseA?.id)
            brouillonDuClub = ""
            reponseA = nil
            // On RECHARGE plutôt que de fabriquer la ligne localement : le serveur décide de
            // l'identifiant et de la date, et deux appareils afficheraient sinon deux versions
            // du même message.
            posts = (try? await clubService.fetchClubPosts()) ?? posts
        } catch {
            appState.toast(PanneReseau.phrase(pour: error))
        }
    }

    private func applaudirLeMessage(_ message: ClubPost) async {
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

    private func supprimerLeMessage(_ message: ClubPost) async {
        do {
            try await clubService.deleteClubPost(postId: message.id)
            // Les réponses partent avec lui côté serveur (ON DELETE CASCADE) : on fait pareil ici
            // plutôt que de laisser des réponses orphelines jusqu'au prochain chargement.
            posts.removeAll { $0.id == message.id || $0.parentId == message.id }
        } catch {
            appState.toast(PanneReseau.phrase(pour: error))
        }
    }

    // MARK: Networking

    private func loadIfSignedIn() async {
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
            syncBadgesIfNeeded()
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

    private func loadFeed() async {
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
                    icon: "👏", colorHex: 0xFF3B6B,
                    title: String(localized: "Nouveaux encouragements"),
                    text: Pluriel.choisir(gained,
                        String(localized: "Quelqu'un a applaudi ta séance."),
                        String(localized: "\(gained) personnes ont applaudi ta séance."))
                )
            }
            profile.kudosSeenCounts[item.id] = item.kudos
        }
    }

    private func createClub() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await clubService.createClub(name: newClubName.trimmingCharacters(in: .whitespaces))
            // Inside the `do`, after the call succeeded — an attempt that 422'd on the name, or
            // never left the device, is not a club created.
            Analytics.shared.track(.clubCreated)
            newClubName = ""
            board = try await clubService.fetchBoard()
        } catch ClubServiceError.badResponse(422, _) {
            errorMessage = String(localized: "Ce nom n'est pas autorisé — choisis-en un autre.")
        } catch {
            errorMessage = String(localized: "Impossible de créer le club.")
        }
        isLoading = false
    }

    /// Sets the club's active challenge and updates `board` immediately so the card on the main
    /// page reflects it without a full refetch. Throws (rather than setting `errorMessage`, which
    /// lives on the page underneath) so the create-challenge form — its own sheet stacked on top
    /// of "Gestion du club" — can show its own inline error.
    private func createChallenge(title: String, targetKm: Double, endDate: Date) async throws {
        let challenge = try await clubService.createChallenge(title: title, targetKm: targetKm, endDate: endDate)
        board.challenge = challenge
    }

    private func chercherUnClub(_ texte: String) {
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

    private func joinClub(_ club: ClubSearchResult) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await clubService.joinClub(clubId: club.id)
            // Same placement rule as `createClub` — a club that closed between the search and
            // the tap (404) isn't a join. Created vs joined are tracked apart on purpose: a club
            // that fills up and a club that gets created are two different signals, and one
            // without the other says the invitation isn't landing.
            Analytics.shared.track(.clubJoined)
            clubQuery = ""
            clubResultats = []
            board = try await clubService.fetchBoard()
        } catch ClubServiceError.badResponse(404, _) {
            // Le club a été fermé ou supprimé entre la recherche et l'appui. Rare, mais c'est
            // la seule chose que ce code puisse vouloir dire maintenant.
            errorMessage = String(localized: "Ce club n'est plus ouvert.")
        } catch {
            errorMessage = String(localized: "Impossible de rejoindre ce club.")
        }
        isLoading = false
    }

    private func leaveClub() async {
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

    private func toggleKudos(_ item: FeedItem) async {
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
    private func bumpCommentsCount(_ activityId: String) {
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
                    icon: "💬", colorHex: 0xFF3B6B,
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
    private func updateBio(_ bio: String) async throws {
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
    private func syncBadgesIfNeeded() {
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
    private func syncWeeklyTargetIfNeeded() {
        let target = profile.plannedWeeklyKm
        Task { try? await clubService.syncWeeklyTarget(target) }
    }

    private func submitReport(_ target: ReportTarget, reason: String) async {
        do {
            try await clubService.report(targetType: target.targetType, targetId: target.targetId, reason: reason)
            appState.toast(String(localized: "Signalement envoyé — merci"))
        } catch {
            appState.toast(String(localized: "Impossible d'envoyer le signalement, réessaie."))
        }
    }

    private func confirmBlock(_ userId: String) async {
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
}

/// Identifies what a report is about — a club, a user, or one activity — so the reason picker
/// can post to `api/moderation/report` with the right target. Internal (not private): `FriendsView`
/// reuses this same type for its own report confirmationDialog.
struct ReportTarget: Identifiable {
    let id = UUID()
    var targetType: String
    var targetId: String
    var displayName: String
}

/// One badge tile's real state — `key` matches `ClubBadgeCatalog`/the server's `KNOWN_BADGES`, so
/// this same shape works whether the progress/earned state came from local data (mine, in
/// `ClubView`) or from another member's synced `badgeKeys` (`ClubMemberProfileView`). Internal
/// (not private) since both files construct one.
struct ClubBadge: Identifiable {
    // `key` is already unique per badge definition (`ClubBadgeCatalog.all`) — a fresh `UUID()`
    // here meant every rebuild of `badges` (any body re-evaluation: a kudos tap, tab switch, RSVP)
    // handed `ForEach` an entirely new identity for every tile, defeating diffing and triggering
    // spurious re-animations even when nothing about the badges actually changed.
    var id: String { key }
    var key: String
    /// Le nom d'un symbole SF — voir `ClubBadgeCatalog.Definition.symbole`.
    var symbole: String
    var name: String
    var detail: String
    /// nil for binary badges ("Lève-tôt") or whenever there's no local data to compute progress
    /// from (any badge on someone else's profile).
    var progressText: String?
    var earned: Bool
}

/// Was previously just a static, untappable tile — no way to know what a badge required or how
/// close she was to earning a locked one. Tapping now opens this real detail instead. Internal so
/// `ClubMemberProfileView` can reuse it for other members' badges too.
struct BadgeDetailView: View {
    var badge: ClubBadge
    /// Rendue à la demande, et seulement pour un badge gagné : `ImageRenderer` coûte un rendu
    /// complet hors écran, inutile pour une tuile verrouillée qui ne sera pas partagée.
    @State private var shareImage: Image?
    @State private var shareRenderFailed = false

    var body: some View {
        let color = ClubBadgeCatalog.color(for: badge.key)
        VStack(spacing: 14) {
            BadgeHexTile(symbole: badge.symbole, earned: badge.earned, color: color,
                         side: 76, tailleDuSymbole: 32, lockedOpacity: 0.4)
                .padding(.top, 22)

            Text(badge.name).font(RUFont.sans(.title, weight: .bold)).foregroundColor(RUColor.textPrimary)

            // Sans `background:` — le défaut de `StatChip` est déjà neutre, et il l'est
            // délibérément : « rose → bordeaux, ambre → brun, lime → olive », c'est écrit dans
            // le composant. Ce paramètre était l'échappatoire « si l'appelant a une raison » ;
            // il servait ici à réintroduire exactement ce qui avait été retiré, et donnait une
            // capsule olive en plein centre de la feuille de badge. `color` porte déjà le lime,
            // sur le texte, où il se voit.
            StatChip(
                text: badge.earned ? "Débloqué" : "Pas encore débloqué",
                color: badge.earned ? RUColor.lime : RUColor.text3
            )

            Text(badge.detail)
                .font(RUFont.sans(.label)).foregroundColor(RUColor.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            if let progressText = badge.progressText, !badge.earned {
                Text(progressText).font(RUFont.mono(13, weight: .semibold)).foregroundColor(RUColor.rose2)
            }

            // La carte partageable existait déjà (`BadgeShareCardView`), mais n'était rendue que
            // par `BadgeUnlockedView` — l'animation de déblocage, vue une fois. Passé cette
            // fenêtre, un badge gagné n'était plus partageable du tout : la seule image que l'app
            // sait fabriquer d'une réussite devenait inatteignable une seconde après l'avoir
            // obtenue.
            if badge.earned {
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(badge.name, image: shareImage)) {
                        HStack(spacing: 7) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Partager ce badge")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 30)
                } else if shareRenderFailed {
                    // Même récupération que `RecapView` et `BadgeUnlockedView` : `uiImage` peut
                    // revenir nil sous pression mémoire, et sans reprise manuelle le bouton
                    // resterait absent pour toujours.
                    Button("Réessayer") { renderShareCard() }
                        .font(RUFont.sans(.body, weight: .semibold))
                        .foregroundColor(RUColor.rose2)
                        .frame(minHeight: 44)
                } else {
                    ProgressView().tint(RUColor.text3)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(RUColor.pageBackground)
        .task {
            guard badge.earned, shareImage == nil else { return }
            renderShareCard()
        }
    }

    @MainActor private func renderShareCard() {
        shareRenderFailed = false
        let renderer = ImageRenderer(content: BadgeShareCardView(badge: badge))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else {
            shareRenderFailed = true
            return
        }
        shareImage = Image(uiImage: uiImage)
    }
}

extension Date {
    /// Formatter construction (locale lookup included) is the expensive part, and this is called
    /// once per feed row on every redraw — one shared instance instead of a fresh allocation each
    /// call. Safe as a plain static: everything touching it runs on the main actor.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .short
        return formatter
    }()

    /// Shared with `ActivityCommentsSheet` — one relative-time formatter for the feed and its
    /// comment threads instead of two copies.
    var relativeDescription: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: .now)
    }
}
