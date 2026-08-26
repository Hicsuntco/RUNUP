import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Profile tab — a real social hub (identity, real stats, a live preview into Amis and Running
/// Club) rather than a settings page with her name pinned to the top of it. Every setting that
/// used to live directly on this screen (data sources, appearance, notifications, daily goals)
/// moved to `SettingsView`, reached one tap away via the gear icon — nothing here competes with
/// the stats/social content for space anymore, same "one tap away, not gone" cost `MoreSettingsView`
/// already paid for the settings reached even less often than these.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]
    private var profile: UserProfile { appState.profile }
    private var auth: AuthService { appState.auth }
    private var clubService: ClubService { ClubService(auth: auth) }

    @State private var showSettings = false
    @State private var showSignIn = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isSavingAvatar = false

    @State private var isLoadingSocial = true
    @State private var board: ClubBoard?
    @State private var friendsList: FriendsList?
    /// Le fil lui-même, plus seulement son décompte : la carte Amis en montre désormais les deux
    /// premières lignes. « 3 nouvelles activités aujourd'hui » demande d'aller voir pour savoir
    /// de quoi il s'agit ; deux lignes réelles répondent avant qu'on ait à taper.
    @State private var friendsFeed: [FeedItem] = []

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private static let raceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                statRow

                // Local, donc affiché avant toute considération de compte : ces deux blocs sont
                // les seuls de la page à ne rien attendre du réseau, et c'est précisément ce que
                // regardait un écran vide au premier lancement.
                if !runs.isEmpty {
                    WeekVolumeStrip(runs: runs)
                }

                if !firstStepsDone {
                    firstStepsCard
                }

                if !auth.isSignedIn {
                    signInPrompt
                } else if isLoadingSocial {
                    loadingSocialCard
                } else {
                    amisCard
                    clubCard
                    itinerairesCard
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(RUColor.bg)
        .task { await loadSocialSummary() }
        .refreshable { await loadSocialSummary() }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { Task { await loadSocialSummary() } }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 11) {
                avatarButton
                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.name).displayStyle(18).foregroundColor(RUColor.textPrimary)
                    if let objectifText {
                        // `.profil-obj-pill` de la maquette : l'objectif était une simple ligne de
                        // texte gris de plus, indistincte du reste ; dans une capsule bordée il
                        // devient une étiquette d'identité, au même titre que le nom.
                        HStack(spacing: 4) {
                            Image(systemName: "target").font(.system(size: 9)).foregroundColor(RUColor.text3)
                            Text(objectifText)
                                .font(RUFont.sans(10, weight: .semibold))
                                .foregroundColor(RUColor.text2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(RUColor.card, in: Capsule())
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                }
            }
            Spacer(minLength: 8)
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundColor(RUColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(RUColor.card, in: Circle())
                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Réglages")
        }
    }

    /// Only when a program/course-libre goal is actually current — recovery and choice phases
    /// have no active goal, and showing the last program's objective there reads as if it were
    /// still being pursued (same reasoning `HomeView.weekEyebrow` already applies).
    private var objectifText: String? {
        guard profile.programPhase == .active || profile.programPhase == .freerun else { return nil }
        if let raceDate {
            return "\(profile.goalDisplay) · \(Self.raceDateFormatter.string(from: raceDate))"
        }
        return profile.goalDisplay.isEmpty ? nil : profile.goalDisplay
    }

    private var raceDate: Date? { profile.raceDate }

    private var avatarButton: some View {
        PhotosPicker(selection: $avatarPickerItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(imageData: profile.avatarImageData, initial: String(profile.name.prefix(1)), size: 52)
                    .opacity(isSavingAvatar ? 0.5 : 1)
                    // `.profil-avatar-ring` : un liseré dégradé, détaché de la photo par un
                    // interstice, autour de MA photo uniquement. C'est le seul avatar « moi » de
                    // l'app — partout ailleurs `AvatarView(seed:)` donne à chaque personne sa
                    // propre couleur, ici c'est l'anneau qui joue ce rôle de marqueur d'identité.
                    // `strokeBorder` (et non `stroke`) pour que le trait soit tracé À L'INTÉRIEUR
                    // du cercle : le diamètre visible reste exactement celui du cadre, sans
                    // déborder d'un demi-trait sur la mise en page ni sur le crayon d'édition.
                    .padding(3)
                    .overlay(Circle().strokeBorder(RUColor.accentGradient(), lineWidth: 2))
                if isSavingAvatar {
                    ProgressView().tint(RUColor.textPrimary)
                } else {
                    // A small pencil badge is what actually tells her the avatar is
                    // tappable — a plain circle with no affordance reads as decoration.
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .background(RUColor.rose, in: Circle())
                        .offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(isSavingAvatar)
        .accessibilityLabel("Changer la photo de profil")
        .onChange(of: avatarPickerItem) { _, newItem in
            Task { await setAvatar(from: newItem) }
        }
        .contextMenu {
            if profile.avatarImageData != nil {
                Button("Supprimer la photo", role: .destructive) {
                    Task { await removeAvatar() }
                }
            }
        }
    }

    /// Resizes to a real thumbnail (240pt max side) before storing — the picker hands back full
    /// camera-resolution photos (several MB), and this is stored locally in SwiftData AND,
    /// base64-encoded, in the club backend's `users.avatar_data` column for every other member's
    /// leaderboard/feed row — keeping it small keeps both cheap.
    private func setAvatar(from item: PhotosPickerItem?) async {
        isSavingAvatar = true
        defer { isSavingAvatar = false }
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data)
        else { return }
        let resized = uiImage.resized(maxDimension: 240)
        guard let jpeg = resized.jpegData(compressionQuality: 0.6) else { return }
        await MainActor.run { profile.avatarImageData = jpeg }
        // Only club members can ever see this, so only sync it when there's actually an account —
        // it stays a purely local photo otherwise, same as every other profile field.
        guard auth.isSignedIn else { return }
        let dataURI = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        do {
            try await auth.updateAvatar(dataURI: dataURI)
        } catch {
            // The local photo is already saved (see above) — only the club-visible copy failed to
            // sync, worth telling her since it silently used to just never reach other members.
            appState.toast(String(localized: "Photo enregistrée, mais pas encore visible du club — vérifie ta connexion."))
        }
    }

    private func removeAvatar() async {
        await MainActor.run {
            profile.avatarImageData = nil
            avatarPickerItem = nil
        }
        guard auth.isSignedIn else { return }
        do {
            try await auth.updateAvatar(dataURI: nil)
        } catch {
            // Mirrors setAvatar's error handling above — the local photo is already cleared, but
            // the server (and every other club member's leaderboard/feed/comments view) still
            // shows the old one until this actually lands, and without this she'd have no signal
            // that the removal didn't take.
            appState.toast(String(localized: "Photo supprimée localement, mais toujours visible du club — vérifie ta connexion."))
        }
    }

    // MARK: - Real stats row

    private var totalKm: Double { runs.reduce(0) { $0 + $1.distanceKm } }

    /// Number of real, permanent badges earned — `profile.seenBadgeKeys` (see `ClubView`) already
    /// tracks exactly this set (every earned key gets appended there the moment `ClubView` next
    /// computes it, and a badge never un-earns), so this reads it directly instead of re-deriving
    /// earned/locked state from `runs`/`profile.streak` a second time in a different file.
    private var badgeCount: Int { profile.seenBadgeKeys.count }

    /// `.profil-stat-row` de la maquette : trois chiffres posés à même la page, alignés sur leur
    /// ligne de base, PAS une carte à trois colonnes séparées par des filets.
    ///
    /// C'est un vrai changement de hiérarchie, pas un détail : cet écran a trois blocs (identité,
    /// chiffres, social) et la version en carte donnait aux chiffres le même poids visuel qu'aux
    /// deux cartes Amis / Running Club en dessous — trois cartes empilées, aucune priorité. En
    /// ligne nue, les chiffres deviennent le prolongement de l'en-tête (« qui je suis, où j'en
    /// suis ») et les seules vraies cartes de la page sont les deux destinations tapables.
    private var statRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            // `statCell` reçoit un `String` : sans `String(localized:)` ces libellés n'atteindraient
            // jamais le catalogue.
            statCell(value: String(format: "%.0f", totalKm), label: String(localized: "km"))
            statCell(
                value: "\(profile.streak)",
                label: String(localized: "sem. de suite"),
                valueColor: profile.streak > 0 ? RUColor.rose : RUColor.textPrimary,
                icon: profile.streak > 0 ? "flame.fill" : nil
            )
            statCell(value: "\(badgeCount)", label: badgeCount > 1 ? String(localized: "badges") : String(localized: "badge"))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    private func statCell(value: String, label: String, valueColor: Color = RUColor.textPrimary, icon: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // La flamme est groupée avec le chiffre dans un HStack imbriqué, centré, plutôt que
            // posée directement dans la rangée alignée sur la ligne de base : une image n'a pas de
            // ligne de base typographique, et l'aligner comme du texte la fait flotter. Le HStack
            // imbriqué, lui, expose la ligne de base de son propre Text — la rangée extérieure
            // s'aligne donc bien sur le chiffre.
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11)).foregroundColor(valueColor)
                }
                Text(value).displayStyle(19).foregroundColor(valueColor)
            }
            Text(label).font(RUFont.sans(9.5, weight: .semibold)).foregroundColor(RUColor.text3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Social preview cards

    private var loadingSocialCard: some View {
        VStack(spacing: 10) {
            ProgressView().tint(RUColor.rose)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .ruCard()
    }

    private var signInPrompt: some View {
        VStack(spacing: 12) {
            AppMarkView(size: 40)
            Text("Ton profil prend vie à plusieurs").font(RUFont.sans(14, weight: .semibold)).foregroundColor(RUColor.textPrimary)
            // Cet écran est le SEUL accès au club et aux amis depuis que Profil est le 5e onglet :
            // déconnectée, il n'existe plus aucun autre chemin vers eux. Il doit donc dire ce
            // qu'il y a derrière, pas seulement qu'il faut se connecter — une porte, pas un mur.
            // (Rien n'est perdu au passage : rejoindre un club, suivre quelqu'un ou applaudir une
            // séance demande de toute façon un compte.)
            Text("Ton classement de club, le fil de tes amis et les sorties de groupe t'attendent ici.")
                .font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).multilineTextAlignment(.center)
            Button("SE CONNECTER") { showSignIn = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .ruCard()
    }

    /// Fond de `.social-card` : la carte standard, LAVÉE d'une pointe de sa couleur (7 %) et
    /// bordée de cette même couleur (22 %). C'est volontairement une teinte, pas un aplat — la
    /// règle que suit la maquette d'un bout à l'autre est « accent, pas remplissage » : deux
    /// grosses cartes en aplat rose/violet feraient hurler une page qui, autrement, est neutre.
    /// Ce qui change vraiment, c'est que les deux destinations cessent d'être deux cartes grises
    /// identiques et deviennent deux endroits distincts et reconnaissables.
    private func socialCard<Content: View>(tint: Color, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous)
        return content()
            .padding(15)
            // Mélange OPAQUE dans `card` (`RUColor.tint`), pas un `tint.opacity(0.07)` translucide
            // posé par-dessus : c'est la règle du fichier de tokens, et ici elle compte vraiment —
            // en thème sombre `card` est lui-même une translucidité blanche, empiler deux couches
            // translucides y donnerait une carte plus claire que toutes les autres de la page.
            .background(shape.fill(RUColor.tint(tint, RUColor.socialTintAmount, over: RUColor.card)))
            // Le contour, lui, reste translucide : `RUColor.line` est une couleur à alpha (noir
            // 14% / blanc 8%) et `tint(_:over:)` rend une couleur opaque — mélanger dedans
            // donnerait un trait quasi noir en thème clair au lieu d'un filet.
            .overlay(shape.stroke(tint.opacity(0.3), lineWidth: RUSpacing.hairline))
            // Même ombre que `ruCard()`, et surtout pas plus. Cette carte portait encore
            // l'ancienne (radius 16, y 5, 16 %), rescapée parce qu'elle est posée à la main ici
            // plutôt que par le modificateur partagé : les deux seules cartes teintées de la page
            // flottaient donc quatre fois plus haut que toutes les cartes neutres de l'app. La
            // maquette fait l'inverse — une teinte se distingue par sa couleur, jamais par plus
            // d'élévation.
            .shadow(color: .black.opacity(RUColor.isLight ? 0.04 : 0), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(RUColor.isLight ? 0.08 : 0), radius: 4, x: 0, y: 3)
    }

    /// `.social-card-arrow` — un chevron nu se perd dans une carte teintée ; dans une pastille
    /// ronde de la couleur de la page, il redevient le bouton « ça s'ouvre » qu'il est censé être.
    private var cardArrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(RUColor.text2)
            .frame(width: 26, height: 26)
            .background(RUColor.bg, in: Circle())
    }

    /// Filet de `.social-card-teaser` : sépare l'en-tête de la carte (qui/quoi) de son aperçu de
    /// contenu (qui court, quand). Sans lui les deux lignes se lisaient comme un seul pavé.
    private var teaserDivider: some View {
        Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
    }

    private var amisCard: some View {
        Button(action: {
            appState.openFriendsTabOnNextVisit = true
            appState.go(.club)
        }) {
            socialCard(tint: RUColor.violet) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(RUColor.violet.opacity(0.16))
                            Image(systemName: "person.2.fill").font(.system(size: 16)).foregroundColor(RUColor.violet)
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Amis").font(RUFont.sans(15, weight: .bold)).foregroundColor(RUColor.textPrimary)
                            if let friendsList {
                                Text("\(friendsList.followers.count) abonnés · \(friendsList.following.count) abonnements")
                                    .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
                            }
                        }
                        Spacer(minLength: 0)
                        // Les demandes en attente étaient signalées sur le segment « Mes amis »
                        // du sélecteur de `SocialView`, qui vient de disparaître. Sans ce
                        // report, un compte privé pouvait garder des demandes sans réponse
                        // indéfiniment — c'est justement la raison d'être de ce compteur, et il
                        // est mieux ici : sur l'écran ouvert par l'onglet, pas sur une barre
                        // qu'il fallait déjà avoir atteinte.
                        if let friendsList, !friendsList.incomingRequests.isEmpty {
                            Text("\(friendsList.incomingRequests.count)")
                                .font(RUFont.sans(10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RUColor.rose, in: Capsule())
                                .accessibilityLabel(friendsList.incomingRequests.count > 1
                                    ? String(localized: "\(friendsList.incomingRequests.count) demandes en attente")
                                    : String(localized: "\(friendsList.incomingRequests.count) demande en attente"))
                        }
                        cardArrow
                    }

                    teaserDivider

                    // Trois cas, du plus riche au plus pauvre : ce que les amis ont couru, sinon
                    // qui sont les amis, sinon l'invitation à en trouver.
                    if !friendsFeed.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            ForEach(friendsFeed.prefix(2)) { item in
                                feedPreviewRow(item)
                            }
                        }
                    } else if let friendsList, !friendsList.following.isEmpty {
                        HStack(spacing: 8) {
                            HStack(spacing: -7) {
                                ForEach(friendsList.following.prefix(3)) { user in
                                    AvatarView(urlString: user.avatarUrl, base64DataURI: user.avatarBase64, initial: String(user.name.prefix(1)), size: 22, seed: user.id)
                                        .overlay(Circle().stroke(RUColor.bg, lineWidth: 2))
                                }
                            }
                            Text("Rien de nouveau aujourd'hui")
                                .font(RUFont.sans(10.5, weight: .semibold)).foregroundColor(RUColor.text2)
                        }
                    } else {
                        Text("Trouve des coureurs à suivre").font(RUFont.sans(10.5, weight: .semibold)).foregroundColor(RUColor.text2)
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    /// La troisième porte de l'onglet social. Elle répond à une question que les deux autres ne
    /// posent pas : non pas « avec qui je cours », mais « où je cours », quand on est quelque part
    /// qu'on ne connaît pas.
    private var itinerairesCard: some View {
        Button(action: {
            appState.openRoutesTabOnNextVisit = true
            appState.go(.club)
        }) {
            // Cyan, et non violet comme Amis : les trois destinations de la page portaient deux
            // teintes pour trois cartes, si bien qu'Amis et Itinéraires — les deux qui n'ont rien
            // à voir l'une avec l'autre — se lisaient comme une paire. Trois teintes, trois
            // endroits. Le cyan est déjà un jeton sémantique de l'app, pas une couleur inventée
            // ici, et il suit le thème clair/sombre comme les deux autres.
            socialCard(tint: RUColor.cyan) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(RUColor.cyan.opacity(0.18))
                        Image(systemName: "map.fill").font(.system(size: 15)).foregroundColor(RUColor.cyan)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Itinéraires").font(RUFont.sans(15, weight: .bold)).foregroundColor(RUColor.textPrimary)
                        Text("Trouve où courir, ici ou en voyage")
                            .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
                    }
                    Spacer(minLength: 0)
                    cardArrow
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var clubCard: some View {
        Button(action: { appState.go(.club) }) {
            socialCard(tint: RUColor.rose) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 12) {
                        ZStack {
                            // Seul vrai aplat de la page, et il fait 40 pt : la pastille du club
                            // porte le dégradé de marque avec un trophée blanc, là où Amis porte
                            // une simple teinte violette. C'est ce qui distingue les deux cartes
                            // au premier coup d'œil sans colorer la moitié de l'écran.
                            Circle().fill(RUColor.accentGradient())
                            Image(systemName: "trophy.fill").font(.system(size: 15)).foregroundColor(.white)
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Running Club").font(RUFont.sans(15, weight: .bold)).foregroundColor(RUColor.textPrimary)
                            if let club = board?.club {
                                Text(club.memberCount > 1
                                     ? String(localized: "\(club.name) · \(club.memberCount) membres")
                                     : String(localized: "\(club.name) · \(club.memberCount) membre"))
                                    .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
                            } else {
                                Text("Tu n'en as pas encore rejoint").font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
                            }
                        }
                        Spacer(minLength: 0)
                        cardArrow
                    }

                    teaserDivider

                    // Le podium seulement à partir de deux membres : un « 1ᵉʳ » solitaire dans un
                    // club d'une personne se moque de celle qui le lit.
                    if topThree.count >= 2 {
                        clubPodium
                    }

                    if let event = board?.events?.first {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 11)).foregroundColor(RUColor.rose)
                            Text(event.title).font(RUFont.sans(10.5, weight: .bold)).foregroundColor(RUColor.rose).lineLimit(1)
                            Text(event.going > 1
                                 ? String(localized: "— \(event.going) confirmés")
                                 : String(localized: "— \(event.going) confirmé")).font(RUFont.sans(10.5)).foregroundColor(RUColor.text2)
                        }
                    } else if board?.club == nil {
                        // La maquette propose ici un aperçu de « 2 clubs près de toi » à
                        // rejoindre. Non repris : un club de cette app se rejoint UNIQUEMENT par
                        // code d'invitation (`ClubService.joinClub`) — il n'existe ni annuaire
                        // public, ni géolocalisation de clubs, ni notion de club « proche » dans
                        // le schéma. La carte dit donc ce qui est réellement faisable.
                        Text("Rejoins un club avec un code d'invitation, ou crée le tien")
                            .font(RUFont.sans(10.5, weight: .semibold)).foregroundColor(RUColor.text2)
                    } else {
                        Text("Aucune sortie prévue pour l'instant")
                            .font(RUFont.sans(10.5, weight: .semibold)).foregroundColor(RUColor.text3)
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Feed preview

    /// Une ligne du fil des amis, réduite à ce qui se lit sans réfléchir : qui, combien, quand.
    private func feedPreviewRow(_ item: FeedItem) -> some View {
        HStack(spacing: 8) {
            AvatarView(
                urlString: item.avatarUrl,
                base64DataURI: item.avatarBase64,
                initial: String(item.name.prefix(1)),
                size: 22,
                seed: item.userId
            )
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(item.name)
                        .font(RUFont.sans(10.5, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1)
                    if item.isPersonalRecord {
                        // Un record personnel est la seule chose du fil qui mérite qu'on lève les
                        // yeux — c'est aussi ce qui fait applaudir, donc ce qui fait revenir.
                        Text("RECORD")
                            .font(RUFont.sans(7.5, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(RUColor.amber)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .overlay(Capsule().stroke(RUColor.amber.opacity(0.45), lineWidth: RUSpacing.hairline))
                    }
                }
                Text(feedMeta(item))
                    .font(RUFont.mono(9.5))
                    .foregroundColor(RUColor.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if item.kudos > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "hands.clap.fill").font(.system(size: 8))
                    Text("\(item.kudos)").font(RUFont.mono(9))
                }
                .foregroundColor(RUColor.text3)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// « 8,2 km · 5:12 /km · il y a 2 h » — chaque colonne seulement si elle a été mesurée, comme
    /// `ActivityFeedRow` : une séance de renfo n'a pas de distance, et un « 0 km » ferait passer
    /// une absence de mesure pour une mesure.
    private func feedMeta(_ item: FeedItem) -> String {
        var parts: [String] = []
        if let km = item.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        }
        if let pace = item.avgPace, !pace.isEmpty {
            parts.append("\(pace) /km")
        }
        parts.append(Self.relativeFormatter.localizedString(for: item.createdAt, relativeTo: .now))
        return parts.joined(separator: " · ")
    }

    // MARK: - Club podium

    private var topThree: [LeaderboardRow] { Array((board?.leaderboard ?? []).prefix(3)) }

    /// Le classement du club, réduit à trois tuiles. La carte disait « 14 membres » — un nombre
    /// qui ne donne envie de rien. Trois noms, trois scores et sa propre place dedans, si.
    private var clubPodium: some View {
        HStack(spacing: 6) {
            ForEach(topThree) { row in
                podiumCell(row)
            }
        }
    }

    private func podiumCell(_ row: LeaderboardRow) -> some View {
        let shape = RoundedRectangle(cornerRadius: RUSpacing.radiusCompact - 2, style: .continuous)
        return VStack(spacing: 3) {
            AvatarView(
                urlString: row.avatarUrl,
                base64DataURI: row.avatarBase64,
                initial: String(row.name.prefix(1)),
                size: 20,
                // `seed: nil` pour soi — le dégradé de marque, comme partout ailleurs dans l'app
                // où « moi » apparaît à côté des autres.
                seed: row.isMe ? nil : row.id
            )
            Text(rankLabel(row.rank))
                .font(RUFont.sans(8, weight: .bold))
                .foregroundColor(RUColor.text3)
            Text("\(row.xp)")
                .displayStyle(15)
                .foregroundColor(RUColor.textPrimary)
            Text(row.isMe ? String(localized: "Toi") : row.name)
                .font(RUFont.sans(8.5))
                .foregroundColor(RUColor.text2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .background(shape.fill(row.isMe ? RUColor.tint(RUColor.rose, 0.14, over: RUColor.card2) : RUColor.card2))
        .overlay(shape.stroke(row.isMe ? RUColor.rose.opacity(0.35) : RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        .accessibilityElement(children: .combine)
    }

    private func rankLabel(_ rank: Int) -> String {
        rank == 1 ? String(localized: "1ᵉʳ") : "\(rank)ᵉ"
    }

    // MARK: - Premiers pas

    private var stepGoalDone: Bool { !profile.goalDisplay.isEmpty }
    private var stepRunDone: Bool { !runs.isEmpty }
    private var stepSocialDone: Bool {
        board?.club != nil || !(friendsList?.following.isEmpty ?? true)
    }
    private var doneStepCount: Int { [stepGoalDone, stepRunDone, stepSocialDone].filter { $0 }.count }
    /// La carte disparaît d'elle-même une fois les trois franchis — elle n'a pas de réglage, pas
    /// de croix à fermer, et ne revient jamais.
    private var firstStepsDone: Bool { doneStepCount == 3 }

    /// Ce qui remplace le vide d'un compte neuf.
    ///
    /// Au premier lancement cet écran affichait trois zéros et deux cartes qui annonçaient elles
    /// aussi zéro — soit, sur la moitié haute, cinq façons de dire « il n'y a rien », puis 60 %
    /// de page vide. Or il y a bien quelque chose à faire, et c'est même la seule chose qui
    /// compte à ce moment-là. Un parcours en trois pas, dont le premier est déjà validé par
    /// l'onboarding : commencer à 1/3 plutôt qu'à 0/3 n'est pas cosmétique, c'est la différence
    /// entre une liste de corvées et quelque chose de déjà entamé.
    private var firstStepsCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    EyebrowLabel(text: "Premiers pas")
                    Text("Trois choses et c'est parti")
                        .font(RUFont.sans(13.5, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                }
                Spacer(minLength: 8)
                Text("\(doneStepCount)/3")
                    .font(RUFont.mono(11, weight: .medium))
                    .foregroundColor(RUColor.text2)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(RUColor.bg2)
                    Capsule()
                        .fill(RUColor.accentGradient(from: .leading, to: .trailing))
                        .frame(width: max(0, geo.size.width * CGFloat(doneStepCount) / 3))
                }
            }
            .frame(height: 3)

            VStack(spacing: 0) {
                stepRow(
                    index: 1,
                    done: stepGoalDone,
                    title: String(localized: "Ton objectif est fixé"),
                    detail: objectifText ?? String(localized: "Choisis ce que tu prépares"),
                    action: { appState.go(.home) }
                )
                stepRow(
                    index: 2,
                    done: stepRunDone,
                    title: String(localized: "Enregistre ta première sortie"),
                    detail: String(localized: "Même 2 km — c'est ce qui démarre tout"),
                    cta: String(localized: "COURIR"),
                    action: { appState.startRun() }
                )
                stepRow(
                    index: 3,
                    done: stepSocialDone,
                    title: String(localized: "Rejoins un club, suis un coureur"),
                    detail: String(localized: "Courir seul est le meilleur moyen d'arrêter"),
                    cta: String(localized: "VOIR"),
                    isLast: true,
                    action: {
                        // Déconnectée, la porte n'est pas le club : c'est le compte. L'envoyer sur
                        // un onglet qui lui redemandera de se connecter serait un aller-retour.
                        if auth.isSignedIn {
                            appState.openFriendsTabOnNextVisit = true
                            appState.go(.club)
                        } else {
                            showSignIn = true
                        }
                    }
                )
            }
        }
        .padding(15)
        .ruCard()
    }

    private func stepRow(
        index: Int,
        done: Bool,
        title: String,
        detail: String,
        cta: String? = nil,
        isLast: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(done ? RUColor.rose : Color.clear)
                        Circle().strokeBorder(done ? Color.clear : RUColor.text4, lineWidth: 1.5)
                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(RUColor.onRose)
                        } else {
                            Text("\(index)")
                                .font(RUFont.sans(9, weight: .bold))
                                .foregroundColor(RUColor.text3)
                        }
                    }
                    .frame(width: 20, height: 20)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(RUFont.sans(11, weight: .bold))
                            .foregroundColor(done ? RUColor.text2 : RUColor.textPrimary)
                            // Une étape franchie reste lisible mais cesse d'appeler : c'est la
                            // suivante qui doit attirer l'œil.
                            .strikethrough(done, color: RUColor.text3)
                        Text(detail)
                            .font(RUFont.sans(9))
                            .foregroundColor(RUColor.text3)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if let cta, !done {
                        HStack(spacing: 3) {
                            Text(cta).font(RUFont.sans(9, weight: .bold))
                            Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(RUColor.rose)
                    }
                }
                .padding(.vertical, 9)

                if !isLast {
                    Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(done)
    }

    // MARK: - Data loading

    private func loadSocialSummary() async {
        guard auth.isSignedIn else { isLoadingSocial = false; return }
        isLoadingSocial = true
        // Independent requests, fired concurrently — same reasoning as `ClubView.loadIfSignedIn`:
        // none of these three depends on another's result, so the wait is the slowest single
        // request instead of the sum of all three.
        async let boardAttempt = try? await clubService.fetchBoard()
        async let friendsListAttempt = try? await clubService.fetchFriendsList()
        async let friendsFeedAttempt = try? await clubService.fetchFriendsFeed()
        let (boardResult, friendsListResult, friendsFeedResult) = await (boardAttempt, friendsListAttempt, friendsFeedAttempt)

        board = boardResult
        friendsList = friendsListResult
        friendsFeed = friendsFeedResult ?? []
        isLoadingSocial = false
    }
}
