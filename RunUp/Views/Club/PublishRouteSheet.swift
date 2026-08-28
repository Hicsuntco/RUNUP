import SwiftUI
import CoreLocation
import PhotosUI

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
    @State private var photoItem: PhotosPickerItem?
    /// L'aperçu affiché ici, et le JPEG encodé prêt à partir. Les deux, parce que redimensionner
    /// à l'envoi ferait attendre au moment où l'on appuie sur « publier ».
    @State private var photoPreview: UIImage?
    @State private var photoDataURI: String?

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
                    photoSection
                } else {
                    tooShortNote
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nom de l'itinéraire")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(RUColor.text3)
                    TextField(placeholderName, text: $name)
                        .font(RUFont.sans(.emphasis))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(12)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous)
                            .stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Ce qu'il faut savoir (optionnel)")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(RUColor.text3)
                    TextField("Plat, le long du fleuve. Ça grimpe au km 3.", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .font(RUFont.sans(.emphasis))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(12)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous)
                            .stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(RUFont.sans(.label))
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
        .background(RUColor.pageBackground)
        .task { await resolveLocality() }
        .onAppear { if name.isEmpty { name = placeholderName } }
    }

    // MARK: - Morceaux

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Partager cet itinéraire")
                .font(RUFont.display(28))
                .foregroundColor(RUColor.textPrimary)
            Text("Quelqu'un qui arrive dans le coin verra ton parcours et pourra le suivre.")
                .font(RUFont.sans(.emphasis))
                .foregroundColor(RUColor.text2)
        }
    }

    private func trimmedPreview(_ points: [RunRecord.RoutePoint]) -> some View {
        RouteThumbnail(route: points, lineWidth: 3)
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous)
                .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
            .accessibilityLabel(Text("Aperçu du tracé qui sera publié"))
    }

    /// La photo est ce qui donne envie d'y aller ; le tracé dit seulement où c'est. Optionnelle,
    /// et présentée comme telle : la rendre obligatoire ferait abandonner la moitié des
    /// publications sur une sortie faite de nuit ou sous la pluie.
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Une photo du coin (optionnel)")
                .font(RUFont.sans(.small, weight: .semibold))
                .tracking(1)
                .foregroundColor(RUColor.text3)

            if let photoPreview {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: photoPreview)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                    Button {
                        self.photoPreview = nil
                        self.photoDataURI = nil
                        self.photoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .black.opacity(0.45))
                            .padding(8)
                    }
                    .accessibilityLabel(Text("Retirer la photo"))
                }
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                        Text("AJOUTER UNE PHOTO")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .onChange(of: photoItem) { _, item in Task { await loadPhoto(item) } }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundColor(RUColor.rose)
            // Le chiffre est repris de la constante, pas recopié : si le rognage change un jour,
            // cette phrase ne peut pas devenir un mensonge.
            Text("Les \(Int(RouteGeometry.sharingTrimMeters)) premiers et derniers mètres sont retirés avant l'envoi : personne ne verra d'où tu es partie ni où tu es rentrée. C'est le tracé ci-dessus qui sera publié, pas celui que tu as couru.")
                .font(RUFont.sans(.label))
                .foregroundColor(RUColor.text2)
        }
        .padding(12)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
    }

    private var tooShortNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(RUColor.rose)
            Text("Cette sortie est trop courte pour être partagée : une fois les extrémités retirées, il ne resterait pas assez de tracé pour être utile.")
                .font(RUFont.sans(.label))
                .foregroundColor(RUColor.text2)
        }
        .padding(12)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
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

    /// Redimensionnée et encodée dès la sélection : 1080 px sur le côté long, qualité 0,6, ce qui
    /// tient sous les 500 ko que `api/activities/routePhoto` accepte tout en restant net en plein
    /// écran. Même chaîne que la photo de profil, à l'échelle près.
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let resized = image.resized(maxDimension: 1080)
        guard let jpeg = resized.jpegData(compressionQuality: 0.6) else { return }
        photoPreview = resized
        photoDataURI = "data:image/jpeg;base64," + jpeg.base64EncodedString()
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
                // La photo part APRÈS, et son échec ne remet pas la publication en cause : un
                // itinéraire sans photo reste utile, une publication perdue ne l'est pas.
                if let id, let photoDataURI {
                    _ = try? await service.setRoutePhoto(routeId: id, dataURI: photoDataURI)
                }
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
