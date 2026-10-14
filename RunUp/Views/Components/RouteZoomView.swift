import SwiftUI
import MapKit

/// LE TRACÉ EN GRAND, ET MANIPULABLE.
///
/// Jusqu'ici la carte d'une course n'existait qu'en vignette : en fond de l'écran de fin, et une
/// par ligne dans l'historique. Toutes inertes, et à raison — une carte qui répond au doigt dans
/// une liste capte le geste de défilement (voir `RunRouteMapView.interactive`). Le manque n'était
/// donc pas que ces vignettes soient figées, c'est qu'aucun écran n'ouvrait le tracé en grand.
///
/// Ici il n'y a rien à faire défiler : la carte prend tout, le pincement et le déplacement lui
/// reviennent sans disputer de geste à personne.
///
/// Les chiffres restent affichés par-dessus plutôt que dans une barre à part : regarder un
/// parcours sans savoir lequel — 8 km en 45 minutes, ou 20 en deux heures — ne dit pas
/// grand-chose, et c'est exactement ce qu'on vient chercher en agrandissant.
struct RouteZoomView: View {
    var run: RunRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            RunRouteMapView(route: run.route, lineWidth: 5, interactive: true)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    resume
                    Spacer(minLength: 12)
                    fermer
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                Spacer()
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }

    /// Les trois chiffres que la carte ne dit pas. Posés sur un fond flouté parce qu'ils se
    /// lisent par-dessus une carte, dont la couleur sous le texte n'est pas connue à l'avance.
    private var resume: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(run.titreAffiche)
                .font(RUFont.sans(.label, weight: .semibold))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1)
            // Les trois mêmes valeurs, formatées comme l'écran de fin les formate déjà : deux
            // décimales et la locale courante, pour qu'agrandir la carte ne change pas les
            // chiffres qu'on avait sous les yeux une seconde plus tôt.
            RUMetricRow(spacing: 12) {
                valeur(String(format: "%.2f", locale: Locale.current, run.distanceKm),
                       unite: String(localized: "km"))
                valeur(PaceModel.formatDuration(Double(run.durationSeconds)), unite: "")
                valeur(run.avgPace, unite: String(localized: "/km"))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous)
            .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    private func valeur(_ texte: String, unite: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(texte)
                .font(RUFont.sans(.emphasis, weight: .bold))
                .foregroundColor(RUColor.textPrimary)
            if !unite.isEmpty {
                Text(unite)
                    .font(RUFont.sans(.micro, weight: .medium))
                    .foregroundColor(RUColor.text3)
            }
        }
    }

    /// Une croix, et une VRAIE cible de 44 points : c'est la seule sortie de cet écran, posée
    /// par-dessus une carte qui, elle, consomme tous les autres gestes.
    private var fermer: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(RUColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(String(localized: "Fermer le tracé"))
    }
}
