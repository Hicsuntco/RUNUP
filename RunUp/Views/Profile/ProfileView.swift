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
    @State private var selectedBadge: ClubBadge?
    @State private var showSignIn = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isSavingAvatar = false

    @State private var isLoadingSocial = true
    @State private var board: ClubBoard?
    @State private var friendsList: FriendsList?
    @State private var todaysFriendActivityCount = 0

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

                if runs.isEmpty { firstDayCard } else { statRow }

                if !auth.isSignedIn {
                    signInPrompt
                } else if isLoadingSocial {
                    loadingSocialCard
                } else {
                    // Les trois blocs de la page portent chacun un intertitre depuis que les
                    // badges et l'équipement sont apparus dessous : sans celui-ci, les cartes
                    // sociales étaient la seule section anonyme de l'écran.
                    VStack(alignment: .leading, spacing: 10) {
                        RUCardHeader(title: String(localized: "Communauté"))
                        VStack(spacing: 12) {
                            amisCard
                            clubCard
                            itinerairesCard
                        }
                    }
                }

                badgeSection

            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(RUColor.pageBackground)
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
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge).runUpSheetStyle(detents: [.height(300)])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 11) {
                avatarButton
                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.name).displayStyle(18).foregroundColor(RUColor.textPrimary)
                    // `.profil-obj-pill` de la maquette : l'objectif était une simple ligne de
                    // texte gris de plus, indistincte du reste ; dans une capsule bordée il
                    // devient une étiquette d'identité, au même titre que le nom.
                    //
                    // Elle est désormais le chemin vers l'objectif. Il vivait sous l'intertitre
                    // « Mon équipement », à côté des chaussures — une course à préparer n'est pas
                    // de l'équipement — et il était donc écrit deux fois sur le même écran, dont
                    // une au mauvais endroit. La pastille l'affichait déjà : autant qu'elle y
                    // mène. Elle s'affiche même sans objectif, sinon il n'y aurait plus aucune
                    // porte d'entrée pour en choisir un.
                    Button(action: { appState.go(.race) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "target").font(.system(size: 9)).foregroundColor(RUColor.text3)
                            Text(objectifText ?? String(localized: "Choisir une course à préparer"))
                                .font(RUFont.sans(.small, weight: .semibold))
                                .foregroundColor(RUColor.text2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold)).foregroundColor(RUColor.text3)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(RUColor.card, in: Capsule())
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                        // La pastille fait 26 pt : en faire une destination sans agrandir sa zone
                        // tapable aurait été remplacer une ligne facile à viser par une cible qui
                        // ne l'est pas.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityElement(children: .combine)
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
            // `streak` compte des JOURS — un incrément par jour calendaire, une chaîne rompue
            // au-delà de trois jours d'écart (`AdaptivePlanEngine.applyDebrief`). Le Profil était
            // le seul écran à l'afficher en semaines : les badges disent « Série de 3 jours »,
            // l'accueil « Série, N jours », le débrief « jour N », les Stats « N jours ». Une
            // série de douze jours s'affichait ici « 12 sem. de suite » — douze semaines.
            statCell(
                value: "\(profile.streak)",
                label: profile.streak > 1 ? String(localized: "jours de suite") : String(localized: "jour de suite"),
                valueColor: profile.streak > 0 ? RUColor.rose : RUColor.textPrimary,
                icon: profile.streak > 0 ? "flame.fill" : nil
            )
            statCell(value: "\(badgeCount)", label: badgeCount > 1 ? String(localized: "badges") : String(localized: "badge"))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    /// Taille du chiffre, écrite une fois : `displayStyle` ne s'applique pas à un `Text` composé,
    /// donc sa police et son interlettrage sont reproduits ci-dessous et doivent rester d'accord
    /// avec lui.
    private static let statValueSize: CGFloat = 19

    private func statCell(value: String, label: String, valueColor: Color = RUColor.textPrimary, icon: String? = nil) -> some View {
        // La flamme est une PIÈCE JOINTE dans le `Text`, pas une vue posée à côté de lui.
        //
        // La version précédente les groupait dans un `HStack` imbriqué, en pariant que celui-ci
        // exposerait la ligne de base de son propre `Text` à la rangée extérieure. Il ne le fait
        // pas : sans alignement déclaré, ce `HStack` est CENTRÉ, et une image de 11 pt centrée
        // contre un chiffre de 19 pt déborde au-dessus de sa hampe. La ligne de base que le
        // conteneur annonce se décale d'autant, et le « 1 » de la série tombe plus bas que le
        // « 5 » des kilomètres et le « 1 » des badges — le défaut visible sur l'écran Profil.
        //
        // Une image inline dans un `Text` n'a pas ce problème, et pas seulement en pratique :
        // elle est posée SUR la ligne de base du texte par construction. Il n'y a donc plus
        // d'alignement à obtenir, plus de conteneur intermédiaire, et rien qui puisse se
        // redécaler au prochain changement de taille.
        let number: Text = {
            guard let icon else { return Text(value) }
            // La police du segment l'emporte sur celle appliquée à la composition : la flamme
            // garde ses 11 pt sous un chiffre de 19.
            return Text(Image(systemName: icon)).font(.system(size: 11)) + Text(" ") + Text(value)
        }()

        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            number
                .font(RUFont.display(Self.statValueSize))
                .tracking(-Self.statValueSize * 0.03)
                .foregroundColor(valueColor)
            Text(label).font(RUFont.sans(.micro, weight: .semibold)).foregroundColor(RUColor.text3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Jour 1

    /// Ce que voit une utilisatrice qui vient de finir les huit étapes d'inscription.
    ///
    /// Elle voyait « 0 km · 0 jour de suite · 0 badge ». Trois zéros comme résumé d'une personne,
    /// juste après le moment le plus coûteux du parcours — c'est le point où l'app se fait
    /// désinstaller, pas au troisième jour. Et ces trois zéros sont exacts : le problème n'est pas
    /// qu'ils mentent, c'est qu'ils répondent à une question que personne ne pose le premier jour.
    ///
    /// La rangée de chiffres revient dès la première course enregistrée, et elle a alors quelque
    /// chose à dire. En attendant, l'écran montre ce que le programme VA faire — des données tout
    /// aussi réelles, elles existent depuis la fin de l'inscription.
    private var firstDayCard: some View {
        let shape = AdaptivePlanEngine.ProgramShape.compute(
            goal: profile.goalId, raceDate: profile.raceDate,
            from: profile.programStartDate ?? .now)
        return VStack(alignment: .leading, spacing: 12) {
            RUCardHeader(icon: "flag.checkered", tint: RUColor.rose,
                         title: String(localized: "Ton programme est prêt"),
                         subtitle: objectifText ?? String(localized: "Ta première séance t'attend"))
            HStack(spacing: 10) {
                if let total = shape.totalWeeks {
                    firstDayFact(icon: "calendar", value: "\(total)",
                                 label: total > 1 ? String(localized: "semaines") : String(localized: "semaine"))
                    firstDayFact(icon: "square.stack.3d.up.fill", value: "3",
                                 label: String(localized: "phases"))
                } else {
                    firstDayFact(icon: "infinity", value: "∞",
                                 label: String(localized: "sans date de fin"))
                }
                if let days = profile.daysUntilRace {
                    firstDayFact(icon: "target", value: String(localized: "J-\(days)"),
                                 label: String(localized: "avant course"))
                }
            }
            Text("Tes kilomètres, ta série et tes badges apparaîtront ici dès ta première sortie.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ruHeroCard()
    }

    private func firstDayFact(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(RUColor.rose)
            Text(value).displayStyle(19).foregroundColor(RUColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(LocalizedStringKey(label))
                .font(RUFont.sans(.micro, weight: .semibold)).foregroundColor(RUColor.text3)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("Ton profil prend vie à plusieurs").font(RUFont.sans(.emphasis, weight: .semibold)).foregroundColor(RUColor.textPrimary)
            // Cet écran est le SEUL accès au club et aux amis depuis que Profil est le 5e onglet :
            // déconnectée, il n'existe plus aucun autre chemin vers eux. Il doit donc dire ce
            // qu'il y a derrière, pas seulement qu'il faut se connecter — une porte, pas un mur.
            // (Rien n'est perdu au passage : rejoindre un club, suivre quelqu'un ou applaudir une
            // séance demande de toute façon un compte.)
            Text("Ton classement de club, le fil de tes amis et les sorties de groupe t'attendent ici.")
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).multilineTextAlignment(.center)
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
            .background(shape.fill(RUColor.tint(tint, 0.07, over: RUColor.card)))
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
            // Les trois cartes sociales sont des boutons entiers — Club, Amis, Itinéraires. Sans
            // forme de contact, seuls leurs textes et leurs pastilles répondaient : sur une carte
            // de cette taille, la majorité de la surface visée ne faisait rien. Posé ici, dans
            // l'enveloppe partagée, plutôt que trois fois sur les appelants.
            .contentShape(shape)
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
                            Text("Amis").font(RUFont.sans(.emphasis, weight: .bold)).foregroundColor(RUColor.textPrimary)
                            if let friendsList {
                                Text("\(friendsList.followers.count) abonnés · \(friendsList.following.count) abonnements")
                                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
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
                                .font(RUFont.sans(.small, weight: .bold))
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

                    if let friendsList, !friendsList.following.isEmpty {
                        HStack(spacing: 8) {
                            HStack(spacing: -7) {
                                ForEach(friendsList.following.prefix(3)) { user in
                                    AvatarView(urlString: user.avatarUrl, base64DataURI: user.avatarBase64, initial: String(user.name.prefix(1)), size: 22, seed: user.id)
                                        .overlay(Circle().stroke(RUColor.bg, lineWidth: 2))
                                }
                            }
                            Text(todaysFriendActivityCount > 0
                                 ? (todaysFriendActivityCount > 1
                                    ? String(localized: "\(todaysFriendActivityCount) nouvelles activités aujourd'hui")
                                    : String(localized: "\(todaysFriendActivityCount) nouvelle activité aujourd'hui"))
                                 : "Rien de nouveau aujourd'hui")
                                .font(RUFont.sans(.small, weight: .semibold)).foregroundColor(RUColor.text2)
                        }
                    } else {
                        Text("Trouve des coureurs à suivre").font(RUFont.sans(.small, weight: .semibold)).foregroundColor(RUColor.text2)
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
            socialCard(tint: RUColor.violet) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(RUColor.violet.opacity(0.18))
                        Image(systemName: "map.fill").font(.system(size: 15)).foregroundColor(RUColor.violet)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Itinéraires").font(RUFont.sans(.emphasis, weight: .bold)).foregroundColor(RUColor.textPrimary)
                        Text("Trouve où courir, ici ou en voyage")
                            .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
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
                            Text("Running Club").font(RUFont.sans(.emphasis, weight: .bold)).foregroundColor(RUColor.textPrimary)
                            if let club = board?.club {
                                Text(club.memberCount > 1
                                     ? String(localized: "\(club.name) · \(club.memberCount) membres")
                                     : String(localized: "\(club.name) · \(club.memberCount) membre"))
                                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                            } else {
                                Text("Tu n'en as pas encore rejoint").font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                            }
                        }
                        Spacer(minLength: 0)
                        cardArrow
                    }

                    teaserDivider

                    if let event = board?.events?.first {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 11)).foregroundColor(RUColor.rose)
                            Text(event.title).font(RUFont.sans(.small, weight: .bold)).foregroundColor(RUColor.rose).lineLimit(1).minimumScaleFactor(0.8)
                            Text(event.going > 1
                                 ? String(localized: "— \(event.going) confirmés")
                                 : String(localized: "— \(event.going) confirmé")).font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                        }
                    } else if board?.club == nil {
                        // La maquette propose ici un aperçu de « 2 clubs près de toi » à
                        // rejoindre. Non repris : un club de cette app se rejoint UNIQUEMENT par
                        // code d'invitation (`ClubService.joinClub`) — il n'existe ni annuaire
                        // public, ni géolocalisation de clubs, ni notion de club « proche » dans
                        // le schéma. La carte dit donc ce qui est réellement faisable.
                        Text("Rejoins un club avec un code d'invitation, ou crée le tien")
                            .font(RUFont.sans(.small, weight: .semibold)).foregroundColor(RUColor.text2)
                    } else {
                        Text("Aucune sortie prévue pour l'instant")
                            .font(RUFont.sans(.small, weight: .semibold)).foregroundColor(RUColor.text3)
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Badges

    /// Les badges du catalogue, gagnés et verrouillés, calculés par `ClubBadgeEngine` — la même
    /// dérivation que l'écran Club, pas une seconde copie.
    private var badges: [ClubBadge] { ClubBadgeEngine.badges(runs: runs, profile: profile) }
    private var earnedBadges: [ClubBadge] { badges.filter(\.earned) }

    /// Les badges vivaient uniquement dans l'écran Club, alors que le profil affichait déjà leur
    /// NOMBRE en haut de page — un chiffre sans rien derrière, et « 0 badge » ne disait pas ce
    /// qu'il y avait à gagner.
    ///
    /// La bande montre les gagnés d'abord, puis les autres en verrouillé : quand il n'y en a
    /// aucun — le cas au premier lancement — l'écran montre quand même ce qui est atteignable au
    /// lieu d'une rangée vide.
    ///
    /// Chaque tuile ouvre SON détail, et non plus l'onglet Club.
    ///
    /// Deux raisons. La première est un défaut de manipulation : toute la bande portait un seul
    /// `onTapGesture`, et cette bande défile horizontalement. Taper pour arrêter une inertie de
    /// défilement — le geste que tout le monde fait — déclenchait donc un changement d'onglet.
    /// La seconde est qu'envoyer vers le Club demandait de retrouver le même badge dans une autre
    /// bande, sur un autre écran, pour lire ce qu'il fallait faire pour le gagner. `BadgeDetailView`
    /// existe déjà et rend exactement cette réponse : elle s'ouvre ici.
    ///
    /// Le commentaire d'origine refusait un `Button` par tuile pour ne pas donner vingt arrêts
    /// VoiceOver identiques. L'objection tenait tant qu'ils menaient tous au même endroit ; vingt
    /// destinations distinctes méritent vingt arrêts, chacun nommé.
    private var badgeSection: some View {
        let ordered = earnedBadges + badges.filter { !$0.earned }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RUCardHeader(title: earnedBadges.isEmpty
                             ? String(localized: "Badges à débloquer")
                             : String(localized: "Badges · \(earnedBadges.count) sur \(badges.count)"))
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ordered) { badge in
                        let color = ClubBadgeCatalog.color(for: badge.key)
                        Button(action: { selectedBadge = badge }) {
                            VStack(spacing: 6) {
                                HexagonBadgeShape()
                                    .fill(badge.earned ? color.opacity(0.22) : RUColor.card2)
                                    .overlay(HexagonBadgeShape().stroke(badge.earned ? color.opacity(0.7) : RUColor.line, lineWidth: RUSpacing.hairline))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(Text(badge.emoji).font(.system(size: 26)))
                                    .opacity(badge.earned ? 1 : 0.35)
                                    .shadow(color: badge.earned ? color.opacity(0.35) : .clear, radius: 8, x: 0, y: 3)
                                Text(badge.name)
                                    .font(RUFont.sans(.micro, weight: .semibold))
                                    .foregroundColor(badge.earned ? RUColor.textPrimary : RUColor.text2)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 66)
                            // Un hexagone plein ne se laisse frapper que sur son tracé : sans ça,
                            // ses coins coupés sont des zones mortes. Même remarque que dans
                            // `ClubView.badgeStrip`.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(badge.earned
                                            ? String(localized: "\(badge.name), débloqué")
                                            : String(localized: "\(badge.name), à débloquer"))
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }
        }
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
        todaysFriendActivityCount = (friendsFeedResult ?? []).filter { Calendar.current.isDateInToday($0.createdAt) }.count
        isLoadingSocial = false
    }
}
