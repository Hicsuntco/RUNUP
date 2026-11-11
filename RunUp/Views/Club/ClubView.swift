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
        _mur = State(initialValue: MurDuClub())
    }

    /// L'APERÇU EST LE BON ONGLET POUR DE VRAIES GENS, ET LE MAUVAIS POUR UNE CAPTURE.
    ///
    /// Il montre les kilomètres du club cette semaine, le défi en cours et les sorties de
    /// groupe prévues — trois choses qu'un club inventé n'a pas, donc trois états vides sous
    /// une accroche qui parle du fil du club. Le fil, lui, est plein. Voir `Demonstration`.
    @State private var tab: Tab = Tab.auDemarrage
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

    /// LE MUR A SON PROPRE OBJET D'ÉTAT, et c'est ce qui l'a rendu découpable.
    ///
    /// Huit `@State` vivaient ici à plat : le brouillon, l'envoi en cours, la réponse en cours,
    /// les quatre feuilles du mur et le drapeau de révélation du fil. Les passer un par un à une
    /// vue sortie du fichier aurait fait huit liaisons à ne pas confondre. Voir `MurDuClub`.
    ///
    /// Construit dans l'`init` comme le magasin, et pour la raison écrite au-dessus de celui-ci :
    /// `MurDuClub` est `@MainActor`, et le construire depuis un contexte qui ne l'est pas est une
    /// ERREUR DE COMPILATION. L'`init` l'est explicitement ; une valeur par défaut posée ici
    /// dépendrait de ce que le compilateur déduit, et il n'y en a pas sous la main pour vérifier.
    @State private var mur: MurDuClub
    /// La sortie en cours de modification — la sienne uniquement, le serveur le vérifie de son côté.
    @State private var showLeaveConfirm = false
    @State private var showCreateEvent = false
    /// La sortie de groupe qu'on est en train de modifier. Non nil présente `CreateEventSheet`
    /// Le message du mur qu'on est en train de réécrire.
    /// My own feed activity pending delete confirmation (appui long → Supprimer).
    /// Drives the feed rows' staggered entrance — flipped once the first feed load lands, after
    /// which each row's own per-index delay takes over (same pattern as `RecapView`'s splits).

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
        // Même raison pour le mur : les trois feuilles qu'il ouvre se présentent par `item:`.
        @Bindable var mur = mur
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
                    ClubSetupCard(magasin: magasin,
                                  newClubName: $newClubName,
                                  clubQuery: $clubQuery)
                } else {
                    clubTabs
                    Group {
                        switch tab {
                        case .overview: overviewContent
                        case .board:
                            ClubBoardSection(board: magasin.board, isLoading: magasin.isLoading,
                                             reportTarget: $reportTarget,
                                             pendingBlock: $pendingBlock)
                        case .feed:
                            ClubWallView(magasin: magasin, mur: mur,
                                         reportTarget: $reportTarget,
                                         pendingBlock: $pendingBlock)
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
            if count > 0 { mur.filDevoile = true }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
                .runUpSheetStyle(detents: [.large])
        }
        // ET « PROPOSER UNE SORTIE » NE FAISAIT RIEN SUR UN CLUB EN SOMMEIL.
        //
        // Deux boutons posent `showCreateEvent` : le « + » de la carte des sorties, et celui de
        // la carte qui propose de RÉVEILLER le club. Or ces deux cartes s'excluent —
        // `if clubEnSommeil { ClubWakeCard(…) } else { eventsCard }` — et la feuille était
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
        .sheet(item: $mur.messageEnModification) { message in
            EditTextPostSheet(titreDeLaFeuille: String(localized: "Modifier le message"),
                              texteInitial: message.text) { texte in
                // Recousu sur place plutôt que rechargé : un message n'a qu'un texte, il ne
                // change ni de place ni de compteur. Recharger le mur entier pour une phrase
                // ferait clignoter la liste sous les doigts de qui vient de la corriger.
                try await magasin.modifierLeMessage(message, texte: texte)
            }
            .runUpSheetStyle()
        }
        .sheet(item: $mur.editingActivity) { activity in
            EditActivitySheet(item: activity, onSaved: { Task { await magasin.loadFeed() } })
                .runUpSheetStyle()
        }
        .sheet(item: $mur.commentsActivity) { activity in
            ActivityCommentsSheet(
                activityId: activity.id,
                currentUserId: auth.currentUser?.id,
                clubService: clubService,
                onCommentPosted: { magasin.bumpCommentsCount(activity.id) },
                onReport: { comment in
                    mur.commentsActivity = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        reportTarget = ReportTarget(targetType: "comment", targetId: comment.id, displayName: String(localized: "le commentaire de \(comment.nomComplet)"))
                    }
                },
                onBlock: { comment in
                    mur.commentsActivity = nil
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
            isPresented: Binding(get: { mur.pendingDeleteActivity != nil }, set: { if !$0 { mur.pendingDeleteActivity = nil } })
        ) {
            // The item is captured SYNCHRONOUSLY here: dismissing the alert nils
            // `pendingDeleteActivity` before an async Task body would get to read it, which made
            // the whole action a silent no-op.
            Button("Supprimer", role: .destructive) {
                if let item = mur.pendingDeleteActivity {
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
                if magasin.seuleDansSonClub {
                    ClubAloneCard(magasin: magasin)
                } else {
                    ClubWakeCard(showCreateEvent: $showCreateEvent,
                                 showManagement: $showManagement)
                }
            } else {
                ClubWeekPulseCard(magasin: magasin)
                ClubChallengeCard(magasin: magasin, showManagement: $showManagement)
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
}
