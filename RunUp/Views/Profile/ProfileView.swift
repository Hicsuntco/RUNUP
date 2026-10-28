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
    /// La plus proche des courses qu'elle prépare — `mine` les rend déjà triées par date. Sert la
    /// ligne de la tuile « Courses », qui sans elle promettrait une recherche au lieu de montrer
    /// un compte à rebours.
    @State private var nextRace: RaceEvent?

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
                } else if auth.sessionRejected {
                    // AVANT le chargement : tant que le jeton est refusé, les cartes sociales ne
                    // rendront rien et tourneraient indéfiniment.
                    sessionExpiredPrompt
                } else if isLoadingSocial {
                    loadingSocialCard
                } else {
                    // Les trois blocs de la page portent chacun un intertitre depuis que les
                    // badges et l'équipement sont apparus dessous : sans celui-ci, les cartes
                    // sociales étaient la seule section anonyme de l'écran.
                    VStack(alignment: .leading, spacing: 10) {
                        RUCardHeader(title: "Communauté")
                        // LE FIL PASSE DEVANT LA GRILLE, ET PLEINE LARGEUR.
                        //
                        // Ce n'est pas une cinquième destination : c'est celle qu'on ouvre tous
                        // les jours, là où les quatre autres répondent à une question précise.
                        // En faire une tuile parmi quatre l'aurait mise à égalité avec
                        // « Itinéraires », qu'on ouvre trois fois par an.
                        //
                        // Elle ouvre `AppScreen.fil` — l'ÉCRAN, pas un mode de `SocialView`
                        // comme autrefois. Le fil a gagné son en-tête et son état déconnectée
                        // en devenant un écran, et il les garde en perdant son onglet.
                        carteDuFil
                        grilleCommunaute
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
                .runUpSheetStyle(detents: [.large])
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
                .runUpSheetStyle(detents: [.large])
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge).runUpSheetStyle(detents: [.height(300)])
        }
    }

    // MARK: - Header

    /// Mon statut, quand le club me l'a rendu. La bio est une colonne de `users`, mais aucun
    /// point d'entrée ne la rend pour moi seule : elle n'arrive que par le classement du club.
    /// Sans club, pas de bio — et la ligne disparaît plutôt que de laisser un vide.
    private var maBio: String? {
        guard let bio = board?.leaderboard.first(where: \.isMe)?.bio, !bio.isEmpty else { return nil }
        return bio
    }

    /// # LA PHOTO SE VOYAIT À PEINE, ET C'ÉTAIT LE PROBLÈME
    ///
    /// Elle tenait dans 52 points, au bout d'une ligne, à côté d'un nom en 18 : la taille d'une
    /// vignette de liste. Sur la page de quelqu'un d'autre — `PublicProfileView` — la même photo
    /// fait 100 points et ouvre l'écran. Donc l'app montrait les autres mieux qu'elle ne la
    /// montrait, elle, sur son propre profil.
    ///
    /// Elle passe à 88 points, et le nom gagne son pseudo et son statut en dessous : c'est la
    /// même forme que la page publique, ce qui n'est pas une coquetterie — les deux écrans
    /// décrivent le même objet, l'un se modifie et l'autre se regarde.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                avatarButton
                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.name).displayStyle(.title).foregroundColor(RUColor.textPrimary)
                    if let pseudo = auth.currentUser?.username, !pseudo.isEmpty {
                        Text(verbatim: "@\(pseudo)")
                            .font(RUFont.sans(.body))
                            .foregroundColor(RUColor.text3)
                    }
                    if let maBio {
                        Text(maBio)
                            .font(RUFont.sans(.body))
                            .foregroundColor(RUColor.text2)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
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

            pastilleDObjectif
        }
    }

    /// Sortie de la colonne du nom quand la photo est passée à 88 points : à côté d'un disque de
    /// cette taille, « 10 km · 47:30 · 6 décembre 2026 » n'avait plus la largeur de s'écrire et
    /// se rabattait sur son facteur de réduction. Sur sa propre ligne, elle a tout l'écran.
    private var pastilleDObjectif: some View {
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
        // SANS OBJECTIF, LA PASTILLE MÈNE À L'ASSISTANT, PAS À L'ÉCRAN D'OBJECTIF.
        // Elle annonce « Choisir une course à préparer » et envoyait sur `RaceGoalView`,
        // qui est en LECTURE SEULE : « Date à définir », des tuiles vides, et aucun
        // bouton pour choisir quoi que ce soit. Le libellé promettait une action que
        // l'écran d'arrivée n'a pas. L'assistant, lui, fait exactement ce qui est écrit.
        Button(action: {
            if objectifText == nil { appState.newGoalWizardPresented = true } else { appState.go(.race) }
        }) {
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
                // `useGradient: false` : À 88 POINTS, L'APLAT DE DÉGRADÉ N'EST PLUS UN AVATAR, C'EST UN
                // BLOC DE COULEUR. À 52 il passait ; agrandi, il redevenait le plus gros objet rose
                // de l'app juste après qu'on en ait retiré partout ailleurs. La branche pâle —
                // teinte à 16 % et initiale colorée — est celle que la maquette a adoptée en v4,
                // et elle a la forme d'une photo au lieu d'en tenir la place.
                AvatarView(imageData: profile.avatarImageData, initial: String(profile.name.prefix(1)),
                           size: 88, useGradient: false)
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
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .background(RUColor.rose, in: Circle())
                        // Le cercle de fond du symbole déborde du disque de la photo : un liseré
                        // de la couleur de la page le détache, sinon le crayon se lit comme une
                        // entaille dans l'anneau.
                        .overlay(Circle().strokeBorder(RUColor.bg, lineWidth: 2))
                        .offset(x: 1, y: 1)
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
            appState.toast(String(localized: "Photo enregistrée, mais pas encore visible du club — \(PanneReseau.motif(pour: error))."))
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
            appState.toast(String(localized: "Photo supprimée localement, mais toujours visible du club — \(PanneReseau.motif(pour: error))."))
        }
    }

    // MARK: - Real stats row

    private var totalKm: Double { runs.onFoot.reduce(0) { $0 + $1.distanceKm } }

    /// Le nombre de badges gagnés, DÉRIVÉ comme la bande de badges juste en dessous.
    ///
    /// # « 0 BADGE » AU-DESSUS DE « BADGES · 6 SUR 16 »
    ///
    /// Il lisait `profile.seenBadgeKeys`, avec pour raison que cet ensemble « contient déjà
    /// exactement ceux-là ». Il ne les contient qu'APRÈS que `ClubView` ait fait sa passe de
    /// comparaison : c'est lui, et lui seul, qui y range les clés gagnées. Qui n'a jamais ouvert
    /// l'onglet Club a donc un ensemble vide — et lisait « 0 badge » en haut de son profil,
    /// quelques centimètres au-dessus d'une bande qui en affichait six, sur le même écran.
    ///
    /// La capture de diagnostic du Profil l'a montré du premier coup : le profil de démonstration
    /// n'ouvre pas le Club, donc il était dans ce cas-là exactement.
    ///
    /// `earnedBadges` est la dérivation que cet écran fait DÉJÀ pour sa propre bande. Les deux
    /// chiffres de la page ne peuvent plus diverger, puisqu'ils n'en font plus qu'un.
    private var badgeCount: Int { earnedBadges.count }

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
                label: Pluriel.choisir(profile.streak,
                                       String(localized: "jour de suite"),
                                       String(localized: "jours de suite")),
                valueColor: profile.streak > 0 ? RUColor.rose : RUColor.textPrimary,
                icon: profile.streak > 0 ? "flame.fill" : nil
            )
            statCell(value: "\(badgeCount)",
                     label: Pluriel.choisir(badgeCount,
                                            String(localized: "badge"),
                                            String(localized: "badges")))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    /// Taille du chiffre, écrite une fois : `displayStyle` ne s'applique pas à un `Text` composé,
    /// donc sa police et son interlettrage sont reproduits ci-dessous et doivent rester d'accord
    /// avec lui.
    private static let statValueSize: RUDisplaySize = .subtitle

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
                .tracking(-Self.statValueSize.rawValue * 0.03)
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
                                 label: Pluriel.choisir(total,
                                                        String(localized: "semaine"),
                                                        String(localized: "semaines")))
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
            Text(value).displayStyle(.subtitle).foregroundColor(RUColor.textPrimary)
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

    /// SE RECONNECTER SANS SE DÉCONNECTER.
    ///
    /// Le bouton « SE CONNECTER » de `signInPrompt` ne s'affiche que si `!isSignedIn`. Or une
    /// session expirée laisse `isSignedIn` à vrai — l'app a toujours un jeton, c'est le serveur
    /// qui n'en veut plus. Le bouton était donc invisible exactement quand il servait, et le seul
    /// chemin restant était « Se déconnecter » dans Plus de réglages.
    ///
    /// Ce qui coûtait cher : la déconnexion vide la file des sorties en attente
    /// (`discardPendingClubActivities`). Récupérer sa session revenait donc à abandonner ses
    /// publications non envoyées. Ici, `SignInView` pose un jeton frais par `authenticate()`, qui
    /// ne passe jamais par `signOut()` — la file est intacte, et `retryPendingClubActivities`
    /// la reprend à la prochaine ouverture du Club.
    private var sessionExpiredPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "person.badge.clock", tint: RUColor.amberText, title: "Session expirée")
            Text("Ta session de trente jours est arrivée au bout. Tes données sont intactes — reconnecte-toi pour retrouver ton club, tes amis et publier les sorties en attente.")
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)
            Button("ME RECONNECTER") { showSignIn = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 2)
        }
        .padding(RUSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - La grille de Communauté

    private var carteDuFil: some View {
        Button(action: { appState.go(.fil) }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(RUColor.accentGradient())
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 15)).foregroundColor(.white)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Le fil").font(RUFont.sans(.label, weight: .bold)).foregroundColor(RUColor.textPrimary)
                    Text("Ton club, tes abonnements et tes courses, au même endroit")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RUColor.text3)
                    .frame(width: 26, height: 26)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ruCard(radius: RUSpacing.radiusCompact)
            .contentShape(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }


    private func tuileSociale(icone: String,
                              teinte: Color,
                              degrade: Bool = false,
                              titre: String,
                              ligne: String,
                              pastille: String? = nil,
                              etiquettePastille: String? = nil,
                              action: @escaping () -> Void) -> some View {
        let forme = RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous)
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 6) {
                    ZStack {
                        // Le dégradé de marque est réservé au Club : c'est ce qui le distingue
                        // des trois autres sans colorer la moitié de la page. Les autres portent
                        // leur teinte diluée dans le disque, à pleine intensité sur le symbole —
                        // le seul endroit de la tuile où la couleur est vraiment celle qu'on pose.
                        if degrade {
                            Circle().fill(RUColor.accentGradient())
                        } else {
                            Circle().fill(teinte.opacity(0.16))
                        }
                        Image(systemName: icone)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(degrade ? .white : teinte)
                    }
                    .frame(width: 38, height: 38)

                    Spacer(minLength: 0)

                    // Les demandes en attente. La seule chose de cette grille qu'on ne doit pas
                    // pouvoir manquer : un compte privé peut garder des demandes sans réponse
                    // indéfiniment, et c'est la raison d'être de ce compteur.
                    if let pastille {
                        Text(pastille)
                            .font(RUFont.sans(.small, weight: .bold))
                            .foregroundColor(RUColor.onRose)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(RUColor.rose, in: Capsule())
                            .accessibilityLabel(etiquettePastille ?? pastille)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(titre)
                        .font(RUFont.sans(.emphasis, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(ligne)
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        // Sans ça, une ligne de deux lignes est tronquée au lieu de pousser la
                        // tuile — et les quatre tuiles n'ont pas toutes la même longueur de texte.
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            // UNE HAUTEUR PLANCHER, ET DE QUOI REMPLIR LA RANGÉE.
            //
            // Plancher et non fixe : à 200 % de taille de texte, une tuile fixe tronquerait son
            // titre. Mais `minHeight` seul ne suffisait pas — et c'est la capture de diagnostic
            // qui l'a montré, pas le raisonnement. La grille donne bien à chaque rangée la
            // hauteur de sa plus haute tuile ; la plus courte, elle, gardait sa taille propre et
            // se retrouvait CENTRÉE dans la rangée. En français, « Amis » flottait 24 points
            // sous « Running Club », dont la ligne passe sur deux lignes ; en espagnol les deux
            // rangées étaient décalées, « Rutas » débordant sur deux lignes à son tour.
            //
            // `maxHeight: .infinity` fait prendre à la tuile toute la hauteur qu'on lui propose,
            // donc celle de la rangée, et son contenu reste en haut à gauche.
            .frame(minHeight: 116, maxHeight: .infinity, alignment: .topLeading)
            .ruCard(radius: RUSpacing.radiusCompact)
            // Toute la tuile répond, pas seulement son texte : sans forme de contact, la moitié
            // de la surface visée ne fait rien.
            .contentShape(forme)
        }
        .buttonStyle(PressableStyle())
        // Les quatre éléments d'une tuile décrivent UNE destination : quatre arrêts VoiceOver
        // pour une tuile, c'est quatre fois le même contexte relu.
        .accessibilityElement(children: .combine)
    }

    /// QUATRE CARTES PLEINE LARGEUR SONT DEVENUES QUATRE TUILES.
    ///
    /// Ce qu'elles avaient de laid n'était pas leur dessin, c'était leur rythme. Deux d'entre
    /// elles — Amis, Club — portaient un en-tête, un filet, puis un aperçu ; les deux autres —
    /// Courses, Itinéraires — une seule ligne. Posées l'une sous l'autre, les deux premières
    /// faisaient deux fois la hauteur des suivantes, qui avaient donc l'air inachevées. Sept
    /// cents points de hauteur pour quatre liens, et les badges — ce que la page a de plus
    /// coloré — rejetés sous la ligne de flottaison.
    ///
    /// La grille les met à égalité : même hauteur, même structure, deux par rangée, et l'écran
    /// y gagne quatre cent cinquante points. On voit maintenant les badges sans faire défiler.
    ///
    /// CE QUI A ÉTÉ PERDU, ET CE QUI NE L'A PAS ÉTÉ. L'aperçu sous le filet n'a pas disparu :
    /// il EST la ligne de la tuile. Chaque tuile dit la chose la plus utile qu'elle sache —
    /// la prochaine sortie du club plutôt que son nombre de membres, les sorties d'amis du jour
    /// plutôt que le total des abonnements, la course la plus proche plutôt que la promesse
    /// qu'on pourrait en chercher une. C'est un ordre de priorité, pas une amputation : les deux
    /// lignes empilées disaient rarement deux choses différentes.
    private var grilleCommunaute: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            tuileSociale(
                icone: "person.2.fill", teinte: RUColor.violet,
                titre: String(localized: "Amis"), ligne: ligneDesAmis,
                pastille: pastilleDesDemandes, etiquettePastille: etiquetteDesDemandes,
                action: {
                    appState.openFriendsTabOnNextVisit = true
                    appState.go(.club)
                })

            tuileSociale(
                // Deux tuiles sur quatre en aplat plein et deux en teinte pâle : la grille
                // disait une hiérarchie qui n'existe pas. Les quatre destinations se valent.
                icone: "trophy.fill", teinte: RUColor.rose,
                titre: String(localized: "Running Club"), ligne: ligneDuClub,
                action: { appState.go(.club) })

            tuileSociale(
                icone: "flag.checkered", teinte: RUColor.cyan,
                titre: String(localized: "Courses"), ligne: ligneDesCourses,
                action: {
                    appState.openRacesTabOnNextVisit = true
                    appState.go(.club)
                })

            tuileSociale(
                icone: "map.fill", teinte: RUColor.amber,
                titre: String(localized: "Itinéraires"), ligne: String(localized: "Où courir, ici ou en voyage"),
                action: {
                    appState.openRoutesTabOnNextVisit = true
                    appState.go(.club)
                })
        }
    }

    // MARK: Ce que chaque tuile sait dire

    /// Ce qui s'est passé aujourd'hui d'abord : c'est la seule ligne qui donne une raison
    /// d'ouvrir l'écran MAINTENANT. Le nombre d'abonnements ne change pas d'un jour à l'autre.
    private var ligneDesAmis: String {
        if todaysFriendActivityCount > 0 {
            return Pluriel.choisir(todaysFriendActivityCount,
                                   String(localized: "\(todaysFriendActivityCount) sortie aujourd'hui"),
                                   String(localized: "\(todaysFriendActivityCount) sorties aujourd'hui"))
        }
        if let friendsList, !friendsList.following.isEmpty {
            return Pluriel.choisir(friendsList.following.count,
                                   String(localized: "\(friendsList.following.count) abonnement"),
                                   String(localized: "\(friendsList.following.count) abonnements"))
        }
        return String(localized: "Trouve des coureurs à suivre")
    }

    private var pastilleDesDemandes: String? {
        guard let friendsList, !friendsList.incomingRequests.isEmpty else { return nil }
        return "\(friendsList.incomingRequests.count)"
    }

    private var etiquetteDesDemandes: String? {
        guard let friendsList, !friendsList.incomingRequests.isEmpty else { return nil }
        return Pluriel.choisir(friendsList.incomingRequests.count,
                               String(localized: "\(friendsList.incomingRequests.count) demande en attente"),
                               String(localized: "\(friendsList.incomingRequests.count) demandes en attente"))
    }

    /// La prochaine sortie prime sur le nom du club : le nom est écrit sur l'écran d'arrivée, la
    /// sortie a une date et peut se manquer.
    private var ligneDuClub: String {
        if let event = board?.events?.first { return event.title }
        if let club = board?.club {
            return Pluriel.choisir(club.memberCount,
                                   String(localized: "\(club.name) · \(club.memberCount) membre"),
                                   String(localized: "\(club.name) · \(club.memberCount) membres"))
        }
        // La phrase disait « avec un code d'invitation » — un code qui n'existe plus : on
        // rejoint un club en le cherchant par son nom depuis que les codes ont été retirés.
        return String(localized: "Rejoins-en un, ou crée le tien")
    }

    /// « Marathon de Paris · J-162 ». La course la plus proche, celle que le serveur rend en
    /// tête de `mine` — pas un compte de courses suivies, qui ne dirait rien à faire.
    private var ligneDesCourses: String {
        guard let nextRace else { return String(localized: "Trouve celle que tu prépares") }
        guard let jours = nextRace.joursRestants, jours > 0 else { return nextRace.name }
        return String(localized: "\(nextRace.name) · J-\(jours)")
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
                                BadgeHexTile(symbole: badge.symbole, earned: badge.earned, color: color)
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

        // EN DÉMONSTRATION, LE CACHE EST TOUT — même raison qu'au Club (`ClubView.loadIfSignedIn`).
        //
        // Il n'y a pas de serveur en face d'un simulateur, et la session de démonstration n'est
        // pas un vrai jeton : les quatre requêtes ci-dessous prendraient un 401, donc
        // `markSessionRejected()`, donc toute la section Communauté remplacée par « Session
        // expirée » — dans la capture, en bonne place. `CaptureSeed` a déjà tout posé.
        if Demonstration.enCours {
            board = appState.cachedClubBoard
            friendsList = appState.cachedFriendsList
            nextRace = appState.cachedNextRace
            todaysFriendActivityCount = (appState.cachedClubFeed ?? [])
                .filter { Calendar.current.isDateInToday($0.createdAt) }.count
            isLoadingSocial = false
            return
        }

        isLoadingSocial = true
        // Independent requests, fired concurrently — same reasoning as `ClubView.loadIfSignedIn`:
        // none of these three depends on another's result, so the wait is the slowest single
        // request instead of the sum of all three.
        async let boardAttempt = try? await clubService.fetchBoard()
        async let friendsListAttempt = try? await clubService.fetchFriendsList()
        async let friendsFeedAttempt = try? await clubService.fetchFriendsFeed()
        // La quatrième part en même temps que les trois autres : l'attente reste celle de la plus
        // lente, pas la somme. C'est ce qui permet à la tuile « Courses » de montrer un vrai
        // compte à rebours sans rien coûter à l'ouverture de la page.
        async let racesAttempt = try? await clubService.myRaces()
        let (boardResult, friendsListResult, friendsFeedResult, racesResult) =
            await (boardAttempt, friendsListAttempt, friendsFeedAttempt, racesAttempt)

        board = boardResult
        friendsList = friendsListResult
        nextRace = (racesResult ?? []).first
        todaysFriendActivityCount = (friendsFeedResult ?? []).filter { Calendar.current.isDateInToday($0.createdAt) }.count
        isLoadingSocial = false
    }
}
