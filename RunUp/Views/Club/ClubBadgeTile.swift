import SwiftUI

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
    /// LA MÊME AVANCÉE, EN NOMBRE — 0 à 1.
    ///
    /// `progressText` rend « 2/3 jours », ce qui se lit mais ne se compare pas : pour désigner
    /// LE badge dont on est le plus proche, il faut pouvoir les classer. Et une chaîne traduite
    /// ne se range pas — « 18,3/21 km » et « 2/3 jours » n'ont ni la même unité ni le même
    /// séparateur décimal selon la langue.
    ///
    /// En dernier et avec un défaut : les deux autres constructeurs de cette structure
    /// (`PublicProfileView`, qui n'a pas l'historique de la personne) continuent de compiler
    /// sans y toucher.
    var fraction: Double?
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
                .padding(.top, 24)

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
                Text(progressText).font(RUFont.mono(.body, weight: .semibold)).foregroundColor(RUColor.rose2)
            }

            // La carte partageable existait déjà (`BadgeShareCardView`), mais n'était rendue que
            // par `BadgeUnlockedView` — l'animation de déblocage, vue une fois. Passé cette
            // fenêtre, un badge gagné n'était plus partageable du tout : la seule image que l'app
            // sait fabriquer d'une réussite devenait inatteignable une seconde après l'avoir
            // obtenue.
            if badge.earned {
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(badge.name, image: shareImage)) {
                        HStack(spacing: 8) {
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
