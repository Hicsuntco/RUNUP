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

    /// LES DONNÉES DU CLUB ET LE RÉSEAU VIVENT À PART — voir `ClubStore`.
    ///
    /// Construit ici et non dans une `.task` : `@State` ne se laisse pas initialiser depuis
    /// l'environnement, mais il se laisse initialiser depuis un paramètre, et `SocialView` a
    /// l'environnement. Le magasin existe donc dès le premier rendu, ce qui évite d'avoir à
    /// répondre à « que se passe-t-il si une vue s'affiche avant que son magasin existe ».
    @State private var magasin: ClubStore

    /// Lue pour savoir si les trois onglets s'empilent — voir `clubTabs`.
    @Environment(\.dynamicTypeSize) private var tailleDuTexte

    /// `@MainActor` EXPLICITE, parce que `ClubStore` l'est et qu'un `init` de structure ne
    /// l'hérite pas forcément. Construire un objet isolé au fil principal depuis un contexte
    /// qui ne l'est pas est une erreur de compilation, pas un avertissement — et il n'y a pas
    /// de compilateur Swift ici pour la voir. Redondante si SwiftUI isole déjà `View`, et sans
    /// coût dans ce cas.
    @MainActor
    init(appState: AppState) {
        _magasin = State(initialValue: ClubStore(appState: appState))
    }

    /// L'APERÇU EST LE BON ONGLET POUR DE VRAIES GENS, ET LE MAUVAIS POUR UNE CAPTURE.
    ///
    /// Il montre les kilomètres du club cette semaine, le défi en cours et les sorties de
    /// groupe prévues — trois choses qu'un club inventé n'a pas, donc trois états vides sous
    /// une accroche qui parle du fil du club. Le fil, lui, est plein. Voir `Demonstration`.
    @State private var tab: Tab = Tab.auDemarrage
    @State private var brouillonDuClub = ""
    @State private var reponseA: ClubPost?
    @State private var envoiDuMessage = false
    // Starts true (not false) so the very first render — before `.task` below has had a chance to
    // run — reads as "checking for your club" rather than immediately flashing the create/join
    // form. `.id(appState.screen)` on the parent means a fresh ClubView (and fresh isLoading=true)
    // is created every time this tab is opened, so this covers every visit, not just the first.
    @State private var showSignIn = false
    @State private var newClubName = ""
    @State private var clubQuery = ""
    @State private var reportTarget: ReportTarget?
    @State private var pendingBlock: (userId: String, name: String)?
    @State private var showManagement = false
    @State private var commentsActivity: FeedItem?
    /// La sortie en cours de modification — la sienne uniquement, le serveur le vérifie de son côté.
    @State private var editingActivity: FeedItem?
    @State private var showLeaveConfirm = false
    @State private var showCreateEvent = false
    /// La sortie de groupe qu'on est en train de modifier. Non nil présente `CreateEventSheet`
    /// Le message du mur qu'on est en train de réécrire.
    @State private var messageEnModification: ClubPost?
    /// My own feed activity pending delete confirmation (appui long → Supprimer).
    @State private var pendingDeleteActivity: FeedItem?
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
        // `@Bindable` LE TEMPS DU CORPS, et pour une seule liaison : la feuille du badge
        // débloqué se présente par `item:`, qui veut un `Binding`. Un objet `@Observable` n'en
        // fournit pas directement — c'est `@Bindable` qui en fabrique un. C'est le motif que
        // donne la documentation d'Apple pour la migration vers Observation.
        @Bindable var magasin = magasin
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                banniere
                header
                // Pleine largeur, SOUS l'en-tête et pas dedans : à côté du nom, elle aurait eu
                // la moitié de la ligne et se serait tronquée au premier mot intéressant.
                if let texte = magasin.board.club?.description, !texte.isEmpty {
                    Text(texte)
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !auth.isSignedIn {
                    signInPrompt
                } else if magasin.isLoading && magasin.board.club == nil {
                    // Without this, the ~few seconds `loadIfSignedIn` takes to fetch her real
                    // club read as "the create/join form flashes, then flips to the leaderboard" —
                    // confusing when she already has a club (looks like it vanished, not loaded).
                    loadingCard
                } else if magasin.board.club == nil {
                    clubSetupCard
                } else {
                    clubTabs
                    Group {
                        switch tab {
                        case .overview: overviewContent
                        case .board:
                            ClubBoardSection(board: magasin.board, isLoading: magasin.isLoading,
                                             reportTarget: $reportTarget,
                                             pendingBlock: $pendingBlock)
                        case .feed: feedContent
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let message = magasin.errorMessage {
                    // Was color-only (rose text, no icon) — reads as regular text rather than an
                    // error, especially on a light theme with a pale accent swatch selected.
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(RUFont.icone(.small))
                        Text(message).font(RUFont.sans(.small))
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
        .task { await magasin.loadIfSignedIn(badges: badges) }
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
        .onChange(of: clubQuery) { _, nouveau in magasin.chercherUnClub(nouveau) }
        .refreshable { await magasin.loadIfSignedIn(badges: badges) }
        .onChange(of: magasin.feed.count) { _, count in
            if count > 0 { feedRevealed = true }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
                .runUpSheetStyle(detents: [.large])
        }
        // ET « PROPOSER UNE SORTIE » NE FAISAIT RIEN SUR UN CLUB EN SOMMEIL.
        //
        // Deux boutons posent `showCreateEvent` : le « + » de la carte des sorties, et celui de
        // la carte qui propose de RÉVEILLER le club. Or ces deux cartes s'excluent —
        // `if clubEnSommeil { carteClubAReveiller } else { eventsCard }` — et la feuille était
        // accrochée à la seconde. Sur un club endormi, c'est-à-dire exactement le cas où cette
        // carte existe, taper « Proposer une sortie » posait l'état et n'ouvrait rien ; et la
        // feuille surgissait plus tard, sans qu'on l'ait demandée, le jour où le club se
        // réveillait et où `eventsCard` revenait à l'écran.
        //
        // LA RÈGLE, ET ELLE VAUT POUR LES DOUZE : une feuille se pose sur une vue qui est à
        // l'écran quand on la demande. Si le bouton et la feuille ne sont pas dans la même
        // branche, la feuille remonte au corps.
        .sheet(isPresented: $showCreateEvent) {
            CreateEventSheet { title, location, date, chaqueSemaine, groupes in
                try await magasin.creerLaSortie(title: title, location: location, startsAt: date,
                                                repeatsWeekly: chaqueSemaine, paceGroups: groupes)
            }
            .runUpSheetStyle()
        }
        // LA FEUILLE D'ÉDITION D'UN MESSAGE DU MUR ÉTAIT ACCROCHÉE À `eventsCard`.
        //
        // C'est-à-dire à l'onglet APERÇU, alors que le bouton qui la déclenche — « Modifier ce
        // message », dans l'en-tête d'un message — est sur l'onglet ACTIVITÉ. Les trois onglets
        // s'excluent (`switch tab`), donc la vue qui portait la feuille n'était pas à l'écran
        // au moment où l'on demandait à l'ouvrir : taper « Modifier ce message » ne faisait
        // RIEN. Et pire que rien — l'état restait posé, et la feuille surgissait sans qu'on
        // l'ait demandée au moment où l'on passait sur l'Aperçu.
        //
        // Trouvé en relevant, pour chaque feuille du fichier, la vue qui la porte et celle qui
        // la déclenche. Sur douze, c'est la seule qui n'était pas chez elle. Elle rejoint ici
        // les deux autres feuilles du mur, sur le corps, qui est à l'écran quel que soit
        // l'onglet.
        .sheet(item: $messageEnModification) { message in
            EditTextPostSheet(titreDeLaFeuille: String(localized: "Modifier le message"),
                              texteInitial: message.text) { texte in
                // Recousu sur place plutôt que rechargé : un message n'a qu'un texte, il ne
                // change ni de place ni de compteur. Recharger le mur entier pour une phrase
                // ferait clignoter la liste sous les doigts de qui vient de la corriger.
                try await magasin.modifierLeMessage(message, texte: texte)
            }
            .runUpSheetStyle()
        }
        .sheet(item: $editingActivity) { activity in
            EditActivitySheet(item: activity, onSaved: { Task { await magasin.loadFeed() } })
                .runUpSheetStyle()
        }
        .sheet(item: $commentsActivity) { activity in
            ActivityCommentsSheet(
                activityId: activity.id,
                currentUserId: auth.currentUser?.id,
                clubService: clubService,
                onCommentPosted: { magasin.bumpCommentsCount(activity.id) },
                onReport: { comment in
                    commentsActivity = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        reportTarget = ReportTarget(targetType: "comment", targetId: comment.id, displayName: String(localized: "le commentaire de \(comment.nomComplet)"))
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
                .runUpSheetStyle(detents: [.large], gereSonBas: true)
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { Task { await magasin.loadIfSignedIn(badges: badges) } }
        }
        // Report reason picker — App Store guideline 1.2. `reportTarget` is set by the context
        // menus on leaderboard rows / feed items / the club itself.
        .confirmationDialog(
            "Signaler",
            isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }),
            presenting: reportTarget
        ) { target in
            Button("Contenu inapproprié") { Task { await magasin.submitReport(target, reason: "Contenu inapproprié") } }
            Button("Harcèlement") { Task { await magasin.submitReport(target, reason: "Harcèlement") } }
            Button("Spam") { Task { await magasin.submitReport(target, reason: "Spam") } }
            Button("Annuler", role: .cancel) {}
        } message: { target in
            Text("Pourquoi signales-tu \(target.displayName) ?")
        }
        // Quitter le club — le bouton vit maintenant dans la feuille de gestion, qui se ferme
        // avant de demander confirmation ; le dialogue doit donc être porté par une vue qui, elle,
        // reste à l'écran. `leaveClub()` garde son propre garde-fou contre le double appel.
        .confirmationDialog("Quitter le club ?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Quitter", role: .destructive) { Task { await magasin.leaveClub() } }
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
                    Task { await magasin.confirmBlock(target.userId) }
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
                    Task { await magasin.confirmDeleteActivity(item) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Elle disparaîtra du fil du club, avec ses applaudissements et commentaires. Tes XP restent acquis.")
        }
        .fullScreenCover(item: $magasin.unlockedBadge) { badge in
            BadgeUnlockedView(badge: badge, onDismiss: { magasin.unlockedBadge = nil })
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
            if let club = magasin.board.club {
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
                        HStack(spacing: 6) {
                            Image(systemName: "person.3.fill")
                                .font(RUFont.icone(.small, weight: .semibold))
                                .foregroundColor(RUColor.rose)
                            EyebrowLabel(text: "Le Club")
                        }
                        HStack(spacing: 6) {
                            Text(club.name).displayStyle(.title).foregroundColor(RUColor.textPrimary).lineLimit(1).minimumScaleFactor(0.6)
                            Image(systemName: "chevron.right").font(RUFont.icone(.body, weight: .semibold)).foregroundColor(RUColor.text3)
                        }
                        // CE QUE LE CLUB EST, ET OÙ IL COURT. Sans ces deux lignes, la page
                        // s'ouvrait sur un nom et un compte de membres — ce qui ne dit ni où
                        // l'on court, ni à quelle heure, ni si on y est le bienvenu quand on
                        // débute, c'est-à-dire tout ce qu'on cherche à savoir d'un club.
                        if let ville = club.city, !ville.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin").font(RUFont.icone(.micro))
                                Text(ville).font(RUFont.sans(.small, weight: .semibold))
                            }
                            .foregroundColor(RUColor.text2)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                            .font(RUFont.icone(.small, weight: .semibold))
                            .foregroundColor(RUColor.rose)
                        EyebrowLabel(text: "Le Club")
                    }
                    Text("Rejoins un club").displayStyle(.title).foregroundColor(RUColor.textPrimary)
                }
            }
            Spacer()
            if let club = magasin.board.club {
                StatChip(text: Pluriel.choisir(club.memberCount,
                                               String(localized: "\(club.memberCount) membre"),
                                               String(localized: "\(club.memberCount) membres")),
                         color: RUColor.text2, background: RUColor.card)
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showManagement) {
            if let club = magasin.board.club {
                ClubManagementView(
                    club: club,
                    members: magasin.board.leaderboard,
                    challenge: magasin.board.challenge,
                    onCreateChallenge: { title, targetKm, endDate in
                        try await magasin.createChallenge(title: title, targetKm: targetKm, endDate: endDate)
                    },
                    onReport: { member in
                        // Dismiss the sheet first, then set the target once its dismiss animation
                        // is out of the way — setting both in the same tick makes SwiftUI try to
                        // dismiss the sheet and present the confirmationDialog simultaneously,
                        // and one of the two silently loses.
                        showManagement = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            reportTarget = ReportTarget(targetType: "user", targetId: member.id, displayName: member.nomComplet)
                        }
                    },
                    onBlock: { member in
                        showManagement = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            pendingBlock = (member.id, member.name)
                        }
                    },
                    onUpdateBio: { bio in try await magasin.updateBio(bio) },
                    onSetOpen: { try await magasin.ouvrirLeClub($0, badges: badges) },
                    onSetClubProfile: { description, ville in
                        try await magasin.reglerLaFiche(description: description, ville: ville,
                                                        badges: badges)
                    },
                    onSetClubCover: { try await magasin.reglerLaCouverture(dataURI: $0, badges: badges) },
                    onSetMemberRole: { memberId, organisateur in
                        try await magasin.reglerLeRole(memberId: memberId,
                                                       organisateur: organisateur, badges: badges)
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
        .padding(18)
        .ruCard()
    }

    // MARK: Signed in, no club yet

    private var clubSetupCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                RUCardHeader(icon: "plus.circle.fill", title: "Créer un club", subtitle: "Tu en seras l'administratrice")
                HStack {
                    TextField("Nom du club", text: $newClubName)
                        .textFieldStyle(.plain)
                        .font(RUFont.sans(.emphasis))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                    Button("Créer") {
                        Task { if await magasin.createClub(nom: newClubName) { newClubName = "" } }
                    }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: newClubName.trimmingCharacters(in: .whitespaces).isEmpty || magasin.isLoading))
                        .disabled(newClubName.trimmingCharacters(in: .whitespaces).isEmpty || magasin.isLoading)
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
                RUCardHeader(icon: "magnifyingglass", title: "Rejoindre un club")
                TextField("Chercher par son nom", text: $clubQuery)
                    .textFieldStyle(.plain)
                    .font(RUFont.sans(.emphasis))
                    .foregroundColor(RUColor.textPrimary)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

                let rienDeTape = clubQuery.trimmingCharacters(in: .whitespaces).isEmpty

                if magasin.clubSearchEnCours {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                } else if !rienDeTape, magasin.clubResultats.isEmpty {
                    RUEmpty(forme: .ligne,
                            message: String(localized: "Aucun club ouvert ne porte ce nom."))
                        .padding(.vertical, 8)
                }

                // RIEN DE TAPÉ : ON PROPOSE, AU LIEU DE NE RIEN MONTRER.
                //
                // Le champ exige deux caractères du NOM. Il suppose donc qu'on sache déjà qu'un
                // club existe et comment il s'appelle — exactement le reproche qui avait fait
                // retirer le code d'invitation à six lettres, deux crans plus loin.
                //
                // Les mêmes lignes que la recherche, pas une autre vue : une suggestion doit
                // ressembler à ce qu'on aurait trouvé en cherchant, sinon ce n'est plus la même
                // porte.
                if rienDeTape, !magasin.clubSuggestions.isEmpty {
                    Text("Ou rejoins-en un ouvert")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                        .padding(.top, 6)
                    ForEach(magasin.clubSuggestions) { suggere in
                        ligneDUnClubARejoindre(suggere)
                    }
                }

                ForEach(magasin.clubResultats) { trouve in
                    ligneDUnClubARejoindre(trouve)
                }
            }
            .task { await magasin.chargerLesClubsSuggeres() }
        }
        .padding(18)
        .ruCard()
    }

    // MARK: Signed in, in a club

    /// La carte du niveau est partie dans `ClubLevelCard`, et son calcul dans `NiveauDuClub`.
    /// Elle était la moins chère à sortir des 1 425 lignes de ce fichier : aucun état à faire
    /// passer, une seule donnée en entrée. Voir « Chantier 35 » dans `PROGRESS.md`.

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
        if let brut = magasin.board.club?.coverUrl, !brut.isEmpty, let url = URL(string: brut) {
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
    /// LA MÊME LIGNE POUR LES DEUX LISTES — celle qu'on a cherchée et celle qu'on propose.
    ///
    /// Deux vues presque identiques auraient dérivé à la première retouche, et l'écart se serait
    /// lu comme une différence de nature entre un club trouvé et un club proposé. Il n'y en a
    /// pas : c'est le même club, et le même appui le rejoint.
    private func ligneDUnClubARejoindre(_ trouve: ClubSearchResult) -> some View {
        Button(action: { Task { if await magasin.joinClub(trouve) { clubQuery = "" } } }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trouve.name)
                        .font(RUFont.sans(.label, weight: .medium))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1)
                    // Le nombre de membres n'est pas décoratif : rien n'empêche deux clubs de
                    // porter le même nom, et c'est ce qui les distingue. LA VILLE AVANT LE
                    // COMPTE, pour la même raison en plus fort : entre deux « Foulées du Canal »,
                    // c'est elle qui dit laquelle est la sienne.
                    Text(ligneDuClubTrouve(trouve))
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("Rejoindre")
                    .font(RUFont.sans(.body, weight: .semibold))
                    .foregroundColor(RUColor.rose2)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(magasin.isLoading)
    }

    /// CE QUE LA LIGNE DIT SOUS LE NOM, et dans quel ordre.
    ///
    /// Une suggestion porte SA RAISON d'être là, avant la ville et le compte : « une liste de
    /// noms sans explication ressemble à un annuaire, et on ne suit pas un annuaire » — c'est la
    /// règle déjà écrite pour les suggestions de personnes, et c'est le même problème.
    ///
    /// Une séance à venir passe devant un mur actif : l'une dit où se présenter samedi, l'autre
    /// seulement que le club n'est pas mort. Un club cherché, lui, n'a aucune raison à donner :
    /// on l'a demandé par son nom.
    private func ligneDuClubTrouve(_ trouve: ClubSearchResult) -> String {
        let membres = Pluriel.choisir(trouve.memberCount,
                                      String(localized: "\(trouve.memberCount) membre"),
                                      String(localized: "\(trouve.memberCount) membres"))
        var morceaux: [String] = []
        if trouve.seancePrevue == true {
            morceaux.append(String(localized: "Une séance prévue"))
        } else if trouve.actifRecemment == true {
            morceaux.append(String(localized: "Actif ces jours-ci"))
        }
        if let ville = trouve.city, !ville.isEmpty { morceaux.append(ville) }
        morceaux.append(membres)
        return morceaux.joined(separator: " · ")
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
            if let challenge = magasin.board.challenge {
                HStack {
                    RUCardHeader(title: "Défi du club")
                    StatChip(text: String(localized: "J-\(daysLeft(until: challenge.endDate))"), color: RUColor.rose2)
                }
                Text(challenge.title).displayStyle(.subtitle).foregroundColor(RUColor.textPrimary)
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
                            Image(systemName: "plus").font(RUFont.icone(.small, weight: .bold))
                            Text("Créer").font(RUFont.sans(.small, weight: .semibold))
                        }
                        .foregroundColor(RUColor.rose2)
                        .padding(8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                }
                RUEmpty(forme: .ligne,
                        message: String(localized: "Aucun défi en cours — un objectif de kilomètres à se partager, avec une date de fin."))
                    .padding(.horizontal, 2)
            }
        }
        .ruCarteSiPleine(magasin.board.challenge != nil)
    }

    private var clubTabs: some View {
        // LES TROIS ONGLETS S'EMPILENT EN GRAND TEXTE, ET C'EST LA CAPTURE QUI L'A IMPOSÉ.
        //
        // Trois segments à un tiers de la largeur chacun ne peuvent pas tenir « Classement » au
        // deuxième cran d'accessibilité. La capture du 8 novembre 2026 montre le résultat, et
        // ce n'est pas une troncature — c'est une COUPURE DE MOT sans trait d'union :
        //
        //   · en français : « Classe / ment » ;
        //   · en espagnol, les trois à la fois : « Resume / n », « Clasific / ación »,
        //     « Activida / d ».
        //
        // Un onglet dont le nom est coupé en deux ne se lit plus comme un nom. Empilés, les trois
        // ont la largeur entière et le problème disparaît sans rien rétrécir : rien ne vaut la
        // peine d'être lu à 60 % de sa taille sur l'écran de quelqu'un qui a demandé du gros
        // texte. Aux tailles ordinaires, rien ne bouge.
        let disposition = tailleDuTexte.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 2))
            : AnyLayout(HStackLayout(spacing: 2))
        return disposition {
            // `segment` reçoit un `String` (et non un littéral posé directement dans un `Text`) :
            // sans `String(localized:)` ces libellés ne passeraient jamais par le catalogue.
            segment(String(localized: "Aperçu"), .overview)
            segment(String(localized: "Classement"), .board)
            segment(String(localized: "Activité"), .feed)
        }
        .padding(4)
        .background(RUColor.bg2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    /// Rien n'est lancé : pas un kilomètre cette semaine, pas de défi, pas de sortie prévue.
    ///
    /// Les trois sections du haut de l'Aperçu, prises ensemble. Séparément, chacune a une bonne
    /// raison d'afficher sa phrase d'absence ; empilées, elles font une page qui ne dit rien
    /// trois fois.
    private var clubEnSommeil: Bool {
        (magasin.board.weekStats?.totalKm ?? 0) == 0
            && magasin.board.challenge == nil
            && (magasin.board.events ?? []).isEmpty
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
        if let club = magasin.board.club {
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
        // étaient espacées de 10. Dix contre dix : l'œil ne distingue pas les deux, donc il ne
        // voit pas des groupes, il voit une liste de lignes également séparées. C'est ce qui
        // donne à la page son air de brouillon.
        //
        // 24 porte le rapport à 1 contre 2,4, ce qui suffit à ce que le groupement se lise sans
        // qu'on ait à y penser. L'écart s'écrit ICI et une seule fois : il était composé de 18
        // de pile plus un `padding(.top, 6)` recopié sur quatre sections — que les deux autres
        // n'avaient pas, si bien que l'écran alternait 18 et 24 sans que ce soit voulu.
        VStack(alignment: .leading, spacing: 24) {
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
                if magasin.board.club.map({ $0.memberCount <= 1 }) == true {
                    carteClubSeul
                } else {
                    carteClubAReveiller
                }
            } else {
                weekPulseCard
                challengeCard
                ClubEventsSection(magasin: magasin, badges: badges,
                                  showCreateEvent: $showCreateEvent)
            }
            // CE QU'UN CLASSEMENT NE DIT PAS. Un tableau hebdomadaire dit qui court le plus ;
            // il ne dit ni vers quoi le club court, ni ce qu'il a déjà réussi. Les deux
            // sections ci-dessous ne demandent aucune donnée nouvelle — elles étaient dans les
            // courses suivies et dans les sorties publiées, jamais regardées ensemble.
            // LES TROIS SECTIONS DE PÉPITES SONT MAINTENANT UNE SOUS-VUE, et la condition
            // qui les garde est RESTÉE ICI. C'est ce qui rend le déplacement neutre.
            //
            // Elles étaient trois enfants directs de cette pile, espacés de 24, et chacune
            // rendait une vue vide quand elle n'avait rien à dire — une pile n'espace pas
            // autour du vide. Les regrouper en fait UN enfant : une pile sans contenu, de
            // hauteur nulle mais bien présente, que celle-ci espacerait de 24 de part et
            // d'autre. Quarante-huit points de blanc sur l'écran d'un club tout neuf.
            //
            // Le `if` sans `else` rend une `EmptyView`, exactement comme les trois sections
            // vides d'avant. Et il est ici et non dans l'enfant, parce qu'un `.task` posé sur
            // une vue qui ne rend rien est une question à laquelle personne ne répond avec
            // certitude — celui du chargement, lui, est sur cette pile-ci, qui existe toujours.
            if magasin.aDesPepites {
                ClubHighlightsSections(highlights: magasin.highlights)
            }
            ClubLevelCard(xpTotal: auth.currentUser?.xpTotal ?? 0)
        }
        .task { await magasin.chargerLesPepites() }
    }



    private func segment(_ label: String, _ value: Tab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { tab = value }
            if value == .feed && magasin.feed.isEmpty { Task { await magasin.loadFeed() } }
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
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(tab == value ? RUColor.card : .clear, in: RoundedRectangle(cornerRadius: RUSpacing.radiusChip, style: .continuous))
                // UN FILET D'ACCENT, PARCE QUE LA PASTILLE SEULE ÉTAIT INVISIBLE. Mesuré :
                // `card` sur le rail `bg2` donne 1,25:1 en clair et 1,04:1 en sombre — du blanc
                // sur du blanc, et du noir sur du noir. La règle WCAG 1.4.11 demande 3:1 pour un
                // élément d'interface qui porte un état.
                //
                // L'état ÉTAIT lisible, mais par le texte seul (18,8:1 contre `text3`). Un
                // sélecteur dont la pastille ne se voit pas est un sélecteur dont on ne comprend
                // pas la forme : on lit trois mots dont un plus clair, pas un onglet choisi.
                //
                // Le filet et non le remplissage : la raison écrite au-dessus tient toujours —
                // deux barres roses empilées ne se hiérarchisent plus. Un filet n'est pas un
                // aplat, c'est la règle du dépôt (« un accent ne se dilue pas, il va au
                // contour »), et c'est déjà ce que fait la pastille du classement juste à côté.
                // Mesuré à 4,97:1 en sombre et 3,03:1 en clair.
                .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusChip, style: .continuous)
                    .stroke(tab == value ? RUColor.rose : .clear, lineWidth: RUSpacing.hairline))
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
        let stats = magasin.board.weekStats
        let km = String(format: "%.1f", locale: Locale.current, stats?.totalKm ?? 0)
        let active = (magasin.board.weekly ?? []).filter { $0.weekKm > 0 }
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
                        // « km » et non « KM » : sur ce même écran, les quatre records écrivent
                        // déjà leur unité en minuscules. Deux casses pour la même unité, à trois
                        // centimètres l'une de l'autre.
                        RUChiffre(valeur: km, unite: "km")
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
        // Les pastilles des membres actifs se cerclent de `RUColor.card` pour se chevaucher
        // proprement : ce liseré n'a de sens que sur une carte. Posé sur le fond lavande, il
        // dessinait des anneaux blancs autour des visages.
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }


    private var feedContent: some View {
        // `LazyVStack` : le serveur renvoie 50 activités, et un `VStack` les construisait TOUTES
        // à l'ouverture de l'onglet — avatars décodés, deux passes d'ombre par carte, et
        // l'animation de révélation qui tournait sur ~45 lignes hors écran.
        LazyVStack(spacing: 0) {
            composeurDuMur
            if magasin.feed.isEmpty && magasin.posts.isEmpty && !magasin.isLoading {
                // Un fil vide a deux causes très différentes, et un seul message les traitait
                // toutes les deux. Seule dans son club, « sois la première » demande de poster
                // pour un public qui n'existe pas — ce qu'il faut, c'est des membres, et le code
                // d'invitation était rangé deux écrans plus loin, dans Gestion du club. À
                // plusieurs, la phrase d'origine est juste : il n'y a qu'à courir.
                if magasin.board.club.map({ $0.memberCount <= 1 }) == true {
                    carteClubSeul
                } else {
                    RUEmpty(message: Accord.selon(
                        f: String(localized: "Personne n'a encore rien posté — sois la première !"),
                        m: String(localized: "Personne n'a encore rien posté — sois le premier !")))
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
                        onKudos: { Task { await magasin.toggleKudos(item) } },
                        onComment: { commentsActivity = item },
                        onReport: {
                            reportTarget = ReportTarget(targetType: "activity", targetId: item.id, displayName: String(localized: "l'activité de \(item.nomComplet)"))
                        },
                        onBlock: { pendingBlock = (item.userId, item.name) },
                        onDelete: { pendingDeleteActivity = item },
                        onEdit: { editingActivity = item }
                    )
                case .message(let post):
                    // Plus de filet : `blocDeMessage` est une carte comme les sorties, et c'est
                    // l'écart entre deux cartes qui les sépare — même valeur qu'`ActivityFeedRow`,
                    // pour que l'onglet garde un seul rythme quel que soit le type d'entrée.
                    blocDeMessage(post)
                        .padding(.bottom, 14)
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
        let messages = magasin.posts.filter { $0.parentId == nil }.map(EntreeDuClub.message)
        return (magasin.feed.map(EntreeDuClub.sortie) + messages).sorted { $0.date > $1.date }
    }

    private func reponses(a message: ClubPost) -> [ClubPost] {
        magasin.posts.filter { $0.parentId == message.id }.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Écrire sur le mur

    private var composeurDuMur: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reponseA {
                HStack(spacing: 6) {
                    Text("Réponse à \(reponseA.author.nomComplet)")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                    Button(action: { self.reponseA = nil }) {
                        Image(systemName: "xmark.circle.fill").font(RUFont.icone(.body)).foregroundColor(RUColor.text3)
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
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                // UN ACCENT ÉTEINT N'EST PAS UN ACCENT DÉSACTIVÉ, C'EST UN ACCENT CASSÉ.
                //
                // Le bouton inactif était le rose de l'app à 35 % : un disque bordeaux terne, qui
                // se lit comme une couleur ratée plutôt que comme un bouton en attente. Inactif,
                // il prend la surface neutre des autres boutons-icônes de l'app ; il ne devient
                // rose qu'au moment où il peut vraiment envoyer.
                Button(action: {
                    // L'ÉTAT D'ENVOI, LE BROUILLON ET LA RÉPONSE EN COURS RESTENT ICI : ce sont
                    // trois choses de l'écran. Le magasin publie et recharge le mur, il rend si
                    // ça a marché, et la vue décide alors de vider ce qui lui appartient.
                    // LE GARDE EST ICI, AVANT LE DRAPEAU, comme il l'était avant le
                    // déménagement : un brouillon vide ne doit pas faire clignoter le bouton en
                    // « envoi en cours » le temps d'un `await` qui ne partira pas.
                    guard peutPublier else { return }
                    envoiDuMessage = true
                    Task {
                        let parti = await magasin.publier(texte: brouillonDuClub,
                                                          enReponseA: reponseA)
                        envoiDuMessage = false
                        if parti {
                            brouillonDuClub = ""
                            reponseA = nil
                        }
                    }
                }) {
                    Image(systemName: "arrow.up")
                        .font(RUFont.icone(.medium, weight: .bold))
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
        .padding(.bottom, 18)
    }

    private var peutPublier: Bool {
        !brouillonDuClub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !envoiDuMessage
    }

    private func blocDeMessage(_ message: ClubPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            enTeteDeMessage(message)
            ForEach(reponses(a: message)) { reponse in
                HStack(alignment: .top, spacing: 8) {
                    RUFilet(.vertical)
                    enTeteDeMessage(reponse)
                }
                .padding(.leading, 10)
            }
            HStack(spacing: 18) {
                Button(action: { Task { await magasin.applaudirLeMessage(message) } }) {
                    HStack(spacing: 8) {
                        Image(systemName: message.kudoedByMe ? "hands.clap.fill" : "hands.clap")
                            .font(RUFont.icone(.medium, weight: .regular))
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
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.right").font(RUFont.icone(.medium, weight: .regular))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        // MÊME CARTE QUE LES SORTIES — voir la note jumelle sur `WallView.carteDeCourse`.
        //
        // Ce message du mur partageait le rythme à plat des sorties ; depuis qu'elles sont des
        // cartes, c'est lui qui détonnerait en restant nu, et l'onglet Activité se lirait comme
        // deux listes cousues plutôt que comme une conversation.
        .padding(14)
        .background(RUColor.card)
        .clipShape(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous)
                .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline)
        )
    }

    private func enTeteDeMessage(_ message: ClubPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Le bloc d'identité entier ouvre la page de la personne — la photo, le nom et
                // l'heure ensemble, comme partout ailleurs.
                Button(action: { if !message.isMine { appState.ouvrirLeProfil(message.author.id) } }) {
                    HStack(spacing: 8) {
                        AvatarView(urlString: message.author.avatarUrl, base64DataURI: message.author.avatarBase64,
                                   initial: String(message.author.name.prefix(1)), size: 32,
                                   seed: message.isMine ? nil : message.author.id)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.author.nomComplet)
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
                        Button("Modifier ce message") { messageEnModification = message }
                        Button("Supprimer ce message", role: .destructive) {
                            Task { await magasin.supprimerLeMessage(message) }
                        }
                    } else {
                        Button("Signaler ce message") {
                            reportTarget = ReportTarget(targetType: "club_post", targetId: message.id,
                                                        displayName: message.author.nomComplet)
                        }
                        Button("Bloquer \(message.author.name)", role: .destructive) {
                            pendingBlock = (message.author.id, message.author.name)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(RUFont.icone(.body, weight: .bold))
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

}
