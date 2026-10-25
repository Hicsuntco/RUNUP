import SwiftUI

/// LA PAGE DE QUELQU'UN.
///
/// Ouverte depuis n'importe quel nom de l'app — le fil, le classement, une page de course, une
/// liste d'abonnés. Elle est posée à la racine (`ContentRouterView`) et déclenchée par
/// `appState.ouvrirLeProfil(id)` : aucun écran n'a à savoir comment on présente un profil, donc
/// aucun ne peut oublier de le faire.
///
/// # TROIS ÉTATS, ET LA DIFFÉRENCE ENTRE LES DEUX DERNIERS EST TOUT L'OBJET DE L'ÉCRAN
///
///   · chargement, puis échec s'il y a lieu — avec le MOTIF, jamais « vérifie ta connexion » ;
///   · COMPTE PRIVÉ que je ne suis pas : l'en-tête seul, et une phrase qui dit pourquoi le reste
///     n'est pas là. Pas une liste vide, qui ferait croire que la personne ne court pas ;
///   · sinon : ses dernières sorties, avec les mêmes cartes que le fil.
///
/// Le bouton d'abonnement est la raison d'être de la page pour un compte privé : c'est le seul
/// endroit d'où l'on peut demander à suivre quelqu'un qu'on vient de croiser.
struct PublicProfileView: View {
    var userId: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var page: PublicProfilePage?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var enCours = false
    @State private var selectedBadge: ClubBadge?
    @State private var signalementPresente = false
    @State private var motif = ""

    private var clubService: ClubService { ClubService(auth: appState.auth) }
    private var profil: PublicProfile? { page?.profile }

    private static let inscritDepuis: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            barre
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 14) {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
                    } else if let loadError {
                        Text("Impossible d'ouvrir ce profil — \(loadError).")
                            .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 50).padding(.horizontal, 24)
                    } else if let profil {
                        entete(profil)
                        chiffres(profil)
                        boutons(profil)
                        badges(profil)
                        sorties(profil)
                    }
                }
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.bottom, 30)
            }
        }
        .background(RUColor.pageBackground)
        .task { if page == nil { await charger() } }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge).runUpSheetStyle(detents: [.height(300)])
        }
        .alert("Signaler", isPresented: $signalementPresente) {
            TextField("Pourquoi ?", text: $motif)
            Button("Envoyer") { signaler() }
            Button("Annuler", role: .cancel) { motif = "" }
        } message: {
            Text("Ce signalement sera examiné. Merci de préciser ce qui pose problème.")
        }
    }

    private var barre: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    Text("Retour").font(RUFont.sans(.label, weight: .semibold))
                }
                .foregroundColor(RUColor.text2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            Spacer(minLength: 0)

            if let profil, !profil.isMe {
                Menu {
                    Button("Signaler cette personne") {
                        motif = ""
                        signalementPresente = true
                    }
                    Button("Bloquer", role: .destructive) { Task { await bloquer() } }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(RUColor.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Plus d'options")
            }
        }
    }

    // MARK: - L'en-tête

    private func entete(_ profil: PublicProfile) -> some View {
        VStack(spacing: 8) {
            AvatarView(urlString: profil.avatarUrl, base64DataURI: profil.avatarBase64,
                       initial: String(profil.name.prefix(1)), size: 84,
                       seed: profil.isMe ? nil : profil.id)
                .padding(.top, 8)

            Text(profil.nomComplet)
                .font(RUFont.display(23))
                .foregroundColor(RUColor.textPrimary)
                .multilineTextAlignment(.center)

            if let username = profil.username, !username.isEmpty {
                Text("@\(username)")
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.text3)
            }

            if let bio = profil.bio, !bio.isEmpty {
                Text(bio)
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.text2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
            }

            Text("Inscrit en \(Self.inscritDepuis.string(from: profil.joinedAt))")
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.text3)

            // « Vous vous suivez » plutôt que deux boutons qui disent la même chose à l'envers.
            if profil.followsMe, !profil.isMe {
                Text(profil.jeLaSuis ? String(localized: "Vous vous suivez")
                                     : String(localized: "Te suit"))
                    .font(RUFont.sans(.small, weight: .bold))
                    .foregroundColor(RUColor.violet)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(RUColor.violet.opacity(0.14), in: Capsule())
            }
        }
    }

    private func chiffres(_ profil: PublicProfile) -> some View {
        RUMetricRow(spacing: 20) {
            MetricColumn(value: Distances.km(profil.totalKm), label: String(localized: "Au total"))
            MetricColumn(value: "\(profil.runs)", label: String(localized: "Sorties"))
            MetricColumn(value: "\(profil.followers)", label: String(localized: "Abonnés"), valueColor: RUColor.rose2)
            MetricColumn(value: "\(profil.following)", label: String(localized: "Abonnements"))
        }
        .padding(.top, 4)
    }

    // MARK: - Suivre

    @ViewBuilder
    private func boutons(_ profil: PublicProfile) -> some View {
        if !profil.isMe {
            Button(action: { Task { await basculerLAbonnement(profil) } }) {
                Text(libelleDuBouton(profil))
            }
            // Les deux branches d'un ternaire doivent avoir le même type, et les deux styles
            // n'en sont pas un seul : `AnyButtonStyleBox` les y ramène (voir PlusLockCard).
            .buttonStyle(profil.jeLaSuis || profil.demandeEnvoyee
                         ? AnyButtonStyleBox(SecondaryButtonStyle())
                         : AnyButtonStyleBox(PrimaryButtonStyle(isDisabled: enCours)))
            .disabled(enCours)
            .padding(.top, 4)
        }
    }

    private func libelleDuBouton(_ profil: PublicProfile) -> String {
        if profil.jeLaSuis { return String(localized: "ABONNÉ") }
        if profil.demandeEnvoyee { return String(localized: "DEMANDE ENVOYÉE") }
        // Un compte privé ne se suit pas d'un coup : on DEMANDE. Le dire sur le bouton évite la
        // surprise d'un écran qui ne change pas après l'appui.
        return profil.isPrivate ? String(localized: "DEMANDER À SUIVRE") : String(localized: "SUIVRE")
    }

    // MARK: - Badges

    private func badges(_ profil: PublicProfile) -> some View {
        // Gagnés seulement : une grille de badges VERROUILLÉS sur la page de quelqu'un d'autre
        // raconterait ce qu'il n'a pas fait. Sur ma propre page, c'est un objectif ; sur la
        // sienne, c'est un bulletin.
        let gagnes = ClubBadgeCatalog.all
            .filter { profil.badgeKeys.contains($0.key) }
            .map { ClubBadge(key: $0.key, emoji: $0.emoji, name: $0.name, detail: $0.detail,
                             progressText: nil, earned: true) }
        return Group {
            if !gagnes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    RUCardHeader(icon: "rosette", tint: RUColor.lime, title: "Badges")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(gagnes) { badge in
                                Button(action: { selectedBadge = badge }) {
                                    VStack(spacing: 5) {
                                        // SA COULEUR, PAS UNE COULEUR. Les cinq tuiles sortaient
                                        // toutes en vert : j'avais passé une teinte fixe là où
                                        // le reste de l'app lit celle du badge. Une série d'hexagones
                                        // identiques ne dit plus lequel est lequel, et ne ressemble
                                        // plus à la bande du Profil ni à celle du Club.
                                        BadgeHexTile(emoji: badge.emoji, earned: true,
                                                     color: ClubBadgeCatalog.color(for: badge.key),
                                                     side: 58)
                                        // Et son nom. Un hexagone nu avec « 🌅 » dessus ne dit pas
                                        // ce qui a été gagné — c'est précisément ce qu'on vient
                                        // regarder sur la page de quelqu'un.
                                        Text(badge.name)
                                            .font(RUFont.sans(.micro, weight: .semibold))
                                            .foregroundColor(RUColor.textPrimary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                            .frame(width: 66)
                                    }
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Ses sorties

    @ViewBuilder
    private func sorties(_ profil: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "figure.run", tint: RUColor.rose2, title: "Ses sorties")

            if !profil.canSeeRuns {
                // LE CŒUR DE L'ÉCRAN POUR UN COMPTE PRIVÉ. Une liste vide ferait croire que la
                // personne ne court pas ; cette phrase dit pourquoi il n'y a rien, et le bouton
                // au-dessus dit quoi faire.
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20)).foregroundColor(RUColor.text3)
                    Text("Ce compte est privé")
                        .font(RUFont.sans(.emphasis, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                    Text("Demande à le suivre pour voir ses sorties.")
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .ruCard()
            } else if (page?.items ?? []).isEmpty {
                Text("Rien de publié pour l'instant.")
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                ForEach(Array((page?.items ?? []).enumerated()), id: \.element.id) { index, item in
                    ActivityFeedRow(
                        item: item,
                        isMine: profil.isMe,
                        revealed: true,
                        index: index,
                        onKudos: { Task { await applaudir(item) } },
                        onComment: {},
                        onReport: {
                            motif = ""
                            signalementPresente = true
                        },
                        onBlock: { Task { await bloquer() } },
                        onDelete: {},
                        onEdit: {}
                    )
                }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Actions

    private func charger() async {
        loadError = nil
        // EN DÉMONSTRATION, LE CACHE EST TOUT — même raison qu'au Club et au Profil : il n'y a
        // pas de serveur en face d'un simulateur, et la session de démonstration n'est pas un
        // vrai jeton. Sans ça, la capture ne montrerait qu'une ligne d'erreur.
        if Demonstration.enCours {
            page = appState.cachedPublicProfile
            isLoading = false
            return
        }
        do {
            page = try await clubService.fetchProfile(userId: userId)
        } catch ClubServiceError.badResponse(404, _) {
            // 404 couvre « n'existe pas » ET « l'un de vous a bloqué l'autre ». Les distinguer
            // ici retirerait au blocage son seul effet utile.
            loadError = String(localized: "ce profil n'est pas accessible")
        } catch {
            loadError = PanneReseau.motif(pour: error)
        }
        isLoading = false
    }

    private func basculerLAbonnement(_ profil: PublicProfile) async {
        enCours = true
        do {
            if profil.jeLaSuis || profil.demandeEnvoyee {
                try await clubService.unfollowUser(userId: profil.id)
            } else {
                _ = try await clubService.followUser(userId: profil.id)
            }
            Haptics.impact(.light)
            await charger()
        } catch {
            appState.toast(String(localized: "Impossible de mettre à jour — réessaie."))
        }
        enCours = false
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

    private func signaler() {
        let raison = motif.trimmingCharacters(in: .whitespacesAndNewlines)
        motif = ""
        guard !raison.isEmpty else { return }
        Task {
            try? await clubService.report(targetType: "user", targetId: userId, reason: raison)
            appState.toast(String(localized: "Signalement envoyé"))
        }
    }

    private func bloquer() async {
        do {
            try await clubService.blockUser(userId: userId)
            appState.toast(String(localized: "\(profil?.name ?? "") ne verra plus rien de toi."))
            dismiss()
        } catch {
            appState.toast(String(localized: "Impossible de bloquer cette personne."))
        }
    }
}
