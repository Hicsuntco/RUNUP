import SwiftUI
import MapKit

/// Un itinéraire en grand : son tracé complet, ce que son autrice en dit, et les deux gestes qui
/// comptent — le garder pour plus tard, ou l'ouvrir dans Plans pour s'y rendre.
///
/// Le tracé complet n'est chargé qu'ici. La liste de découverte n'a que des aperçus d'une vingtaine
/// de points : afficher cinquante tracés complets sur une carte coûterait plusieurs mégaoctets pour
/// dessiner des gribouillis de quelques millimètres.
struct RouteDetailSheet: View {
    var route: SharedRoute
    /// Remonte l'itinéraire modifié (enregistré ou non) pour que la liste appelante se mette à
    /// jour sans refaire une requête.
    var onChanged: (SharedRoute) -> Void = { _ in }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var detailed: SharedRoute?
    @State private var isSaving = false
    @State private var reportPresented = false
    @State private var reportReason = ""

    private var current: SharedRoute { detailed ?? route }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photo
                map
                title
                stats
                if let notes = current.notes, !notes.isEmpty { notesCard(notes) }
                actions
                reportButton
            }
            .padding(20)
        }
        .background(RUColor.pageBackground)
        .task { await loadFullTrace() }
        .alert("Signaler cet itinéraire", isPresented: $reportPresented) {
            TextField("Pourquoi ?", text: $reportReason)
            Button("Envoyer") { report() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ce signalement sera examiné. Merci de préciser ce qui pose problème.")
        }
    }

    // MARK: - Morceaux

    @ViewBuilder
    private var photo: some View {
        if let photoUrl = current.photoUrl, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RUColor.card2
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityLabel(Text("Photo du parcours"))
        }
    }

    private var map: some View {
        let coordinates = current.drawableCoordinates
        return Map(initialPosition: .region(regionFitting(coordinates))) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(RUColor.rose, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityLabel(Text("Tracé de l'itinéraire"))
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(current.name)
                .font(RUFont.display(26))
                .foregroundColor(RUColor.textPrimary)
            if let author = current.authorName {
                Text(String(localized: "Partagé par \(author)"))
                    .font(RUFont.sans(12.5))
                    .foregroundColor(RUColor.text3)
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            if let km = current.distanceKm {
                statTile(String(format: "%.1f", locale: Locale.current, km), String(localized: "KM"))
            }
            if let elevation = current.elevationGainM, elevation > 0 {
                statTile("\(elevation)", String(localized: "D+"))
            }
            // Le temps de la personne qui a publié, pas un objectif : le libellé le dit, sinon la
            // carte d'entraide devient un classement déguisé.
            if let seconds = current.durationSeconds, seconds > 0 {
                statTile(PaceModel.formatDuration(Double(seconds)), String(localized: "SON TEMPS"))
            }
            statTile("\(current.savesCount)", String(localized: "GARDÉ"))
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(RUFont.display(22)).foregroundColor(RUColor.textPrimary)
            Text(label).font(RUFont.sans(9.5, weight: .semibold)).tracking(1).foregroundColor(RUColor.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func notesCard(_ notes: String) -> some View {
        Text(notes)
            .font(RUFont.sans(14))
            .foregroundColor(RUColor.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(current.saved ? String(localized: "RETIRER DE MES ITINÉRAIRES")
                                 : String(localized: "GARDER CET ITINÉRAIRE")) {
                toggleSaved()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaving)
            .opacity(isSaving ? 0.5 : 1)

            // Le départ affiché est celui du tracé rogné, donc à ~300 m de chez son autrice. C'est
            // exactement ce qu'il faut ouvrir dans Plans : le point où l'itinéraire commence pour
            // qui le découvre, pas le pas de porte de quelqu'un.
            Button {
                let placemark = MKPlacemark(coordinate: current.startCoordinate)
                let item = MKMapItem(placemark: placemark)
                item.name = current.name
                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    Text("M'Y RENDRE")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var reportButton: some View {
        Button("Signaler cet itinéraire") { reportPresented = true }
            .font(RUFont.sans(12))
            .foregroundColor(RUColor.text3)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    // MARK: - Actions

    /// Ajuste la carte au parcours, avec 30 % de marge pour que le tracé ne colle pas aux bords.
    private func regionFitting(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(center: current.startCoordinate,
                                      span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        }
        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.3, 0.005),
                                   longitudeDelta: max((maxLng - minLng) * 1.3, 0.005))
        )
    }

    private func loadFullTrace() async {
        guard current.points == nil else { return }
        if let full = try? await ClubService(auth: appState.auth).fetchRoute(id: route.id) {
            detailed = full
        }
    }

    private func toggleSaved() {
        isSaving = true
        let target = !current.saved
        Task {
            do {
                let count = try await ClubService(auth: appState.auth)
                    .setRouteSaved(routeId: current.id, saved: target)
                var updated = current
                updated.saved = target
                updated.savesCount = count
                detailed = updated
                onChanged(updated)
                Haptics.impact(.light)
            } catch {
                appState.toast(String(localized: "Impossible de mettre à jour — réessaie."))
            }
            isSaving = false
        }
    }

    private func report() {
        let reason = reportReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return }
        reportReason = ""
        Task {
            try? await ClubService(auth: appState.auth)
                .report(targetType: "route", targetId: current.id, reason: reason)
            appState.toast(String(localized: "Signalement envoyé"))
        }
    }
}
