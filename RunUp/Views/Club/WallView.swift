import SwiftUI

/// LE FIL : UN SEUL ENDROIT OÙ TOUT ATTERRIT.
///
/// # CE QU'IL REMPLACE
///
/// Trois fils séparés — le club, les amis, le mur d'une course — demandaient de savoir OÙ
/// regarder avant de savoir QUOI regarder. Celui-ci retourne la question : tout arrive, et les
/// filtres servent à restreindre, pas à trouver.
///
/// # CE QUI AURAIT PU SE PERDRE, ET QUI NE SE PERD PAS
///
/// Le contexte. Un fil mélangé où rien ne dit pourquoi telle personne y figure n'est plus un
/// réseau, c'est un annuaire. Chaque sortie porte donc sa PROVENANCE sous le nom de son autrice —
/// « ton club », « tu la suis », « toi » — calculée par le serveur, la plus spécifique gagnant
/// quand une personne est les trois à la fois.
///
/// Les messages des pages de course arrivent dans un tableau à part et portent le NOM de leur
/// course : une recherche de partenaire qui débarquerait au milieu des sorties sans dire pour
/// quelle course ne voudrait rien dire. Leur carte mène à la page, où se tient la conversation.
struct WallView: View {
    @Environment(AppState.self) private var appState

    @State private var page: WallPage?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var filtre: Filtre = .tout
    @State private var revealed = false

    // Ce que les cartes ouvrent.
    @State private var commentsFor: FeedItem?
    @State private var editing: FeedItem?
    @State private var reportTarget: ReportTarget?
    @State private var reportReason = ""
    @State private var pendingBlock: (id: String, name: String)?

    private var clubService: ClubService { ClubService(auth: appState.auth) }

    /// Les quatre portées, dans l'ordre où l'on s'en sert : tout d'abord, puis ce qu'on vient
    /// chercher précisément.
    private enum Filtre: String, CaseIterable, Identifiable {
        case tout, club, amis, courses
        var id: String { rawValue }
        var libelle: String {
            switch self {
            case .tout: return String(localized: "Tout")
            case .club: return String(localized: "Club")
            case .amis: return String(localized: "Amis")
            case .courses: return String(localized: "Courses")
            }
        }
    }

    /// Une entrée du fil : une sortie, ou un message de course. Deux formes, une seule liste
    /// triée — c'est l'entrelacement par date qui fait qu'il se lit comme un fil et non comme
    /// deux listes cousues.
    private enum Entree: Identifiable {
        case sortie(FeedItem)
        case course(WallRacePost)

        var id: String {
            switch self {
            case .sortie(let item): return "s-\(item.id)"
            case .course(let post): return "c-\(post.id)"
            }
        }

        var date: Date {
            switch self {
            case .sortie(let item): return item.createdAt
            case .course(let post): return post.createdAt
            }
        }
    }

    private var entrees: [Entree] {
        guard let page else { return [] }
        let sorties = page.items.map(Entree.sortie)
        let courses = filtre == .club || filtre == .amis ? [] : page.racePosts.map(Entree.course)
        return (sorties + courses).sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                barreDeFiltres
                    .padding(.bottom, 14)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 50)
                } else if let loadError {
                    Text("Impossible de charger le fil — \(loadError).")
                        .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 40).padding(.horizontal, 24)
                } else if entrees.isEmpty {
                    videHonnete
                } else {
                    ForEach(Array(entrees.enumerated()), id: \.element.id) { index, entree in
                        switch entree {
                        case .sortie(let item):
                            ActivityFeedRow(
                                item: item,
                                isMine: item.source == "moi",
                                revealed: revealed,
                                index: index,
                                onKudos: { Task { await applaudir(item) } },
                                onComment: { commentsFor = item },
                                onReport: {
                                    reportTarget = ReportTarget(targetType: "activity", targetId: item.id,
                                                                displayName: item.name)
                                },
                                onBlock: { pendingBlock = (item.userId, item.name) },
                                onDelete: { Task { await supprimer(item) } },
                                onEdit: { editing = item },
                                sourceLabel: libelleDeProvenance(item.source)
                            )
                        case .course(let post):
                            // Même filet, même rythme qu'une sortie. L'annonce avait gardé sa
                            // carte pour se distinguer ; dans un fil entièrement à plat, c'était
                            // elle qui détonnait — un rectangle rempli tous les quatre posts.
                            // Ce qui la distingue, c'est son en-tête : un drapeau à damier, le
                            // nom de la course sous celui de la personne, et le genre annoncé.
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(RUColor.line)
                                        .frame(height: RUSpacing.hairline)
                                        .padding(.bottom, 16)
                                }
                                carteDeCourse(post)
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, RUSpacing.tabBarBottomInset + RUSpacing.tabBarHeight + 20)
        }
        .background(RUColor.pageBackground)
        .task { if page == nil { await charger() } }
        .refreshable { await charger() }
        .onChange(of: filtre) { _, _ in Task { await charger() } }
        .sheet(item: $commentsFor) { item in
            ActivityCommentsSheet(
                activity: item,
                currentUserId: appState.auth.currentUser?.id,
                clubService: clubService,
                onCommentPosted: { Task { await charger() } },
                onReport: { commentaire in
                    reportTarget = ReportTarget(targetType: "comment", targetId: commentaire.id,
                                                displayName: commentaire.name)
                },
                onBlock: { commentaire in pendingBlock = (commentaire.userId, commentaire.name) }
            )
            .runUpSheetStyle(detents: [.large])
        }
        .sheet(item: $editing) { item in
            EditActivitySheet(item: item, onSaved: { Task { await charger() } })
                .runUpSheetStyle(detents: [.large])
        }
        .alert("Signaler", isPresented: Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        )) {
            TextField("Pourquoi ?", text: $reportReason)
            Button("Envoyer") { signaler() }
            Button("Annuler", role: .cancel) { reportTarget = nil; reportReason = "" }
        } message: {
            Text("Ce signalement sera examiné. Merci de préciser ce qui pose problème.")
        }
        .alert("Bloquer cette personne ?", isPresented: Binding(
            get: { pendingBlock != nil },
            set: { if !$0 { pendingBlock = nil } }
        )) {
            Button("Bloquer", role: .destructive) { bloquer() }
            Button("Annuler", role: .cancel) { pendingBlock = nil }
        } message: {
            Text("Vous ne verrez plus rien l'un de l'autre, nulle part dans l'app.")
        }
    }

    // MARK: - Les filtres

    private var barreDeFiltres: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filtre.allCases) { valeur in
                    let actif = filtre == valeur
                    Button(action: { filtre = valeur }) {
                        Text(valeur.libelle)
                            .font(RUFont.sans(.body, weight: .bold))
                            .foregroundColor(actif ? RUColor.onRose : RUColor.text2)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(actif ? RUColor.rose : RUColor.card2, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func libelleDeProvenance(_ source: String?) -> String? {
        switch source {
        case "club": return String(localized: "ton club")
        case "amis": return String(localized: "tu la suis")
        case "moi": return String(localized: "toi")
        default: return nil
        }
    }

    // MARK: - Une annonce de course dans le fil

    /// Compacte. Elle dit DE QUELLE COURSE il s'agit — sans ça, « je cherche quelqu'un à 4:45 »
    /// arrivant au milieu des sorties ne voudrait rien dire — et elle mène à la page, où se tient
    /// la conversation.
    ///
    /// # ELLE N'EST PAS UN BOUTON, ET C'EST UNE CORRECTION
    ///
    /// Je l'avais écrite comme un seul grand bouton vers la page de la course, avec
    /// l'applaudissement posé dessus par un geste de tape. Un geste de tape À L'INTÉRIEUR d'un
    /// bouton est avalé par le bouton : applaudir aurait ouvert la page. Deux actions sur une même
    /// carte demandent deux cibles distinctes — c'est exactement la répartition du post juste
    /// au-dessus, où le bloc d'identité mène à la personne et l'applaudissement reste une action.
    private func carteDeCourse(_ post: WallRacePost) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: {
                appState.openRacesTabOnNextVisit = true
                appState.go(.club)
            }) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle().fill(RUColor.cyan.opacity(0.16))
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(RUColor.cyan)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.author.name)
                            .font(RUFont.sans(.label, weight: .bold))
                            .foregroundColor(RUColor.textPrimary)
                            .lineLimit(1)
                        Text(post.raceName)
                            .font(RUFont.sans(.small))
                            .foregroundColor(RUColor.text3)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(genreLisible(post.kind))
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(RUColor.cyan)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(Capsule().strokeBorder(RUColor.cyan.opacity(0.4),
                                                        lineWidth: RUSpacing.hairline))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(String(localized: "Voir la page de \(post.raceName)"))

            Text(post.text)
                .font(RUFont.sans(.body))
                .foregroundColor(post.closed ? RUColor.text3 : RUColor.text2)
                .strikethrough(post.closed, color: RUColor.text3)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            // Applaudir SANS quitter le fil. Obliger à ouvrir la page de la course pour répondre
            // « lu, et oui » coûte plus cher que la réponse elle-même, et c'est comme ça qu'un mur
            // reste vide.
            Button(action: { Task { await applaudirLaCourse(post) } }) {
                HStack(spacing: 7) {
                    Image(systemName: post.kudoedByMe ? "hands.clap.fill" : "hands.clap")
                        .font(.system(size: 15, weight: .regular))
                    if post.kudos > 0 {
                        Text("\(post.kudos)")
                            .font(RUFont.sans(.body, weight: .semibold))
                    }
                }
                .foregroundColor(post.kudoedByMe ? RUColor.rose : RUColor.text2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(post.kudoedByMe ? "Retirer ton applaudissement" : "Applaudir ce message")
            .accessibilityValue("\(post.kudos)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func genreLisible(_ genre: String) -> String {
        switch genre {
        case "partner": return String(localized: "Partenaire")
        case "bib_offer": return String(localized: "Je cède")
        case "bib_wanted": return String(localized: "Je cherche")
        default: return String(localized: "Message")
        }
    }

    // MARK: - Le vide

    private var videHonnete: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 26)).foregroundColor(RUColor.text3)
            Text(filtre == .tout
                 ? String(localized: "Rien pour l'instant")
                 : String(localized: "Rien sous ce filtre"))
                .font(RUFont.sans(.emphasis, weight: .bold))
                .foregroundColor(RUColor.textPrimary)
            // Le vide le plus utile dit QUOI FAIRE, et ce n'est pas la même chose selon le filtre.
            Text(messageDuVide)
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }

    private var messageDuVide: String {
        switch filtre {
        case .club: return String(localized: "Personne de ton club n'a encore publié.")
        case .amis: return String(localized: "Suis des coureurs et leurs sorties arriveront ici.")
        case .courses: return String(localized: "Prépare une course et ce qui s'y dit arrivera ici.")
        case .tout: return String(localized: "Rejoins un club, suis des coureurs, prépare une course — tout atterrira ici.")
        }
    }

    // MARK: - Chargement et actions

    private func charger() async {
        loadError = nil
        // En démonstration, le cache est tout — même raison qu'au Club, au Profil et sur la page
        // de quelqu'un : pas de serveur en face d'un simulateur.
        if Demonstration.enCours {
            page = appState.cachedWall
            isLoading = false
            if !revealed { withAnimation(.easeOut(duration: 0.35)) { revealed = true } }
            return
        }
        do {
            page = try await clubService.fetchWall(scope: filtre.rawValue)
            // L'apparition en cascade des cartes ne joue qu'une fois : la rejouer à chaque
            // rechargement ferait clignoter un fil qu'on vient de tirer vers le bas.
            if !revealed {
                withAnimation(.easeOut(duration: 0.35)) { revealed = true }
            }
        } catch {
            loadError = PanneReseau.motif(pour: error)
        }
        isLoading = false
    }

    private func applaudir(_ item: FeedItem) async {
        guard let index = page?.items.firstIndex(where: { $0.id == item.id }) else { return }
        do {
            let maintenant = try await clubService.toggleKudos(activityId: item.id)
            page?.items[index].kudoedByMe = maintenant
            page?.items[index].kudos += maintenant ? 1 : -1
            Haptics.impact(.light)
        } catch {
            appState.toast(String(localized: "Impossible d'applaudir — réessaie."))
        }
    }

    private func applaudirLaCourse(_ post: WallRacePost) async {
        guard let index = page?.racePosts.firstIndex(where: { $0.id == post.id }) else { return }
        do {
            let reponse = try await clubService.toggleRacePostKudos(postId: post.id)
            page?.racePosts[index].kudoedByMe = reponse.kudoed
            page?.racePosts[index].kudos = reponse.kudos
            Haptics.impact(.light)
        } catch {
            appState.toast(String(localized: "Impossible d'applaudir — réessaie."))
        }
    }

    private func supprimer(_ item: FeedItem) async {
        do {
            try await clubService.deleteActivity(activityId: item.id)
            page?.items.removeAll { $0.id == item.id }
        } catch {
            appState.toast(String(localized: "Impossible de supprimer — réessaie."))
        }
    }

    private func signaler() {
        guard let cible = reportTarget else { return }
        let raison = reportReason.trimmingCharacters(in: .whitespacesAndNewlines)
        reportTarget = nil
        reportReason = ""
        guard !raison.isEmpty else { return }
        Task {
            try? await clubService.report(targetType: cible.targetType, targetId: cible.targetId, reason: raison)
            appState.toast(String(localized: "Signalement envoyé"))
        }
    }

    private func bloquer() {
        guard let cible = pendingBlock else { return }
        pendingBlock = nil
        Task {
            do {
                try await clubService.blockUser(userId: cible.id)
                await charger()
            } catch {
                appState.toast(String(localized: "Impossible de bloquer cette personne."))
            }
        }
    }
}
