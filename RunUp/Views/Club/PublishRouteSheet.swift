import SwiftUI
import CoreLocation

/// Publier une sortie déjà courue comme itinéraire, pour quelqu'un qui débarque dans la ville.
///
/// L'écran a deux rôles, et le second compte autant que le premier : recueillir un nom, et **dire
/// exactement ce qui part**. Publier un tracé GPS est le seul geste de cette app qui expose la
/// position réelle de quelqu'un ; le faire accepter sans l'expliquer serait obtenir un
/// consentement qui n'en est pas un. D'où l'aperçu du tracé ROGNÉ — celui qui partira, pas celui
/// qui a été couru — et la phrase qui nomme les 300 mètres retirés de chaque côté.
struct PublishRouteSheet: View {
    var run: RunRecord
    /// Appelé après une publication réussie, pour que l'écran appelant puisse le signaler.
    var onPublished: (String?) -> Void = { _ in }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var locality: String?
    @State private var countryCode: String?
    @State private var isPublishing = false
    @State private var errorMessage: String?

    /// Le tracé tel qu'il sera publié. Calculé une fois, et c'est LUI qui est dessiné : montrer le
    /// tracé complet avec une promesse de rognage demanderait de croire l'app sur parole.
    private var payload: (points: [RunRecord.RoutePoint], preview: [RunRecord.RoutePoint])? {
        RouteGeometry.shareablePayload(run.route)
    }

    private var canPublish: Bool {
        payload != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty && !isPublishing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let payload {
                    trimmedPreview(payload.points)
                    privacyNote
                } else {
                    tooShortNote
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nom de l'itinéraire")
                        .font(RUFont.sans(11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(RUColor.text3)
                    TextField(placeholderName, text: $name)
                        .font(RUFont.sans(15))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(12)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Ce qu'il faut savoir (optionnel)")
                        .font(RUFont.sans(11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(RUColor.text3)
                    TextField("Plat, le long du fleuve. Ça grimpe au km 3.", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .font(RUFont.sans(15))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(12)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(RUFont.sans(13))
                        .foregroundColor(RUColor.rose)
                }

                Button(isPublishing ? String(localized: "PUBLICATION…") : String(localized: "PUBLIER L'ITINÉRAIRE")) {
                    publish()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canPublish)
                .opacity(canPublish ? 1 : 0.5)

                Button("Annuler") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
        }
        .background(RUColor.bg)
        .task { await resolveLocality() }
        .onAppear { if name.isEmpty { name = placeholderName } }
    }

    // MARK: - Morceaux

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Partager cet itinéraire")
                .font(RUFont.bebas(28))
                .foregroundColor(RUColor.textPrimary)
            Text("Quelqu'un qui arrive dans le coin verra ton parcours et pourra le suivre.")
                .font(RUFont.sans(14))
                .foregroundColor(RUColor.text2)
        }
    }

    private func trimmedPreview(_ points: [RunRecord.RoutePoint]) -> some View {
        RouteThumbnail(route: points, lineWidth: 3)
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
            .accessibilityLabel(Text("Aperçu du tracé qui sera publié"))
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundColor(RUColor.rose)
            // Le chiffre est repris de la constante, pas recopié : si le rognage change un jour,
            // cette phrase ne peut pas devenir un mensonge.
            Text("Les \(Int(RouteGeometry.sharingTrimMeters)) premiers et derniers mètres sont retirés avant l'envoi : personne ne verra d'où tu es partie ni où tu es rentrée. C'est le tracé ci-dessus qui sera publié, pas celui que tu as couru.")
                .font(RUFont.sans(12.5))
                .foregroundColor(RUColor.text2)
        }
        .padding(12)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tooShortNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(RUColor.rose)
            Text("Cette sortie est trop courte pour être partagée : une fois les extrémités retirées, il ne resterait pas assez de tracé pour être utile.")
                .font(RUFont.sans(12.5))
                .foregroundColor(RUColor.text2)
        }
        .padding(12)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// « Boucle de 8 km » — un nom déjà rempli, que l'utilisatrice n'a qu'à corriger. Un champ vide
    /// est ce qui fait abandonner une publication.
    private var placeholderName: String {
        let km = Int(run.distanceKm.rounded())
        if let locality { return String(localized: "\(km) km à \(locality)") }
        return String(localized: "Parcours de \(km) km")
    }

    // MARK: - Actions

    /// Le géocodage inverse se fait ICI, sur l'appareil, et seul le nom de la ville part au
    /// serveur. Ça évite un fournisseur de géocodage côté serveur, sa clé d'API et son coût par
    /// requête — et ça n'envoie pas une coordonnée de plus que nécessaire.
    private func resolveLocality() async {
        guard let first = payload?.points.first else { return }
        let location = CLLocation(latitude: first.lat, longitude: first.lng)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return }
        locality = placemark.locality ?? placemark.administrativeArea
        countryCode = placemark.isoCountryCode
        if name.isEmpty || name == String(localized: "Parcours de \(Int(run.distanceKm.rounded())) km") {
            name = placeholderName
        }
    }

    private func publish() {
        guard canPublish else { return }
        isPublishing = true
        errorMessage = nil
        let service = ClubService(auth: appState.auth)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let id = try await service.publishRoute(
                    name: trimmedName,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    route: run.route,
                    distanceKm: run.distanceKm,
                    elevationGainM: run.elevationGainM,
                    durationSeconds: run.durationSeconds,
                    locality: locality,
                    countryCode: countryCode
                )
                isPublishing = false
                appState.toast(String(localized: "Itinéraire publié 🗺️"))
                onPublished(id)
                dismiss()
            } catch {
                isPublishing = false
                errorMessage = String(localized: "La publication a échoué — vérifie ta connexion et réessaie.")
            }
        }
    }
}
