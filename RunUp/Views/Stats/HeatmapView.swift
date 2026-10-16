import SwiftUI
import SwiftData
import MapKit

/// "Mes routes" — every GPS-tracked run overlaid on one map, Strava-heatmap-style but purely
/// personal: no shared segments, no comparison with anyone else, just where she's already run and
/// where she hasn't. Built from `RunRecord.route` already stored for the share-card trace and
/// History's mini-maps — no new data collection needed.
struct HeatmapView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]

    /// Les tracés prêts à dessiner, et le cadrage qui les contient — CALCULÉS UNE FOIS.
    ///
    /// # CE QUE COÛTAIT LA VERSION PRÉCÉDENTE, À CHAQUE PASSE DE `body`
    ///
    /// Trois parcours complets de toutes les positions enregistrées :
    ///
    ///   · `runsWithRoute` lisait `run.route` de chaque course pour en compter les points ;
    ///   · `allCoords` aplatissait TOUS les tracés en un seul tableau — cent cinquante courses à
    ///     deux mille cinq cents points font 375 000 `CLLocationCoordinate2D`, soit six mégaoctets
    ///     alloués — uniquement pour calculer le rectangle englobant ;
    ///   · le `ForEach` reconvertissait ensuite chaque tracé, un par un.
    ///
    /// Et `run.route` n'est pas un tableau en mémoire : c'est un attribut encodé par SwiftData,
    /// donc chaque lecture le DÉCODE. Une passe de `body` — un défilement, une rotation, un
    /// changement de thème, n'importe quelle observation qui s'invalide — repayait les trois.
    ///
    /// Le cadrage, lui, ne sert qu'une fois : `Map(initialPosition:)` ne le lit qu'au premier
    /// affichage. Il était recalculé à chaque fois pour être jeté.
    @State private var parcours: [Parcours] = []
    @State private var cadrage: MKCoordinateRegion?

    /// Le calcul a-t-il eu lieu ? Sans ce drapeau, `parcours` est vide à la première passe de
    /// `body` — avant que `.task` n'ait tourné — et l'écran affichait une demi-seconde
    /// « Aucun parcours GPS enregistré pour l'instant » en gros au milieu, à quelqu'un qui en a
    /// cent cinquante. C'est le prix d'un calcul différé, et il se paie avec un état « pas encore
    /// répondu » distinct de « la réponse est zéro ».
    @State private var prepare = false

    /// Un tracé, déjà converti en coordonnées de carte.
    private struct Parcours: Identifiable {
        let id: PersistentIdentifier
        let points: [CLLocationCoordinate2D]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackTitleHeaderView(eyebrow: prepare
                                ? Pluriel.choisir(parcours.count,
                                                  String(localized: "\(parcours.count) parcours tracké"),
                                                  String(localized: "\(parcours.count) parcours trackés"))
                                : String(localized: "Mes parcours"),
                                title: "Mes routes") {
                appState.go(.stats)
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if !prepare {
                // Rien, pas un message : le calcul dure le temps d'une image, et une phrase qui
                // paraît pour disparaître est pire qu'un instant de vide.
                Spacer()
            } else if parcours.isEmpty {
                Spacer()
                Text("Aucun parcours GPS enregistré pour l'instant — la carte se remplit après ta première course trackée.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            } else if let cadrage {
                Map(initialPosition: .region(cadrage)) {
                    ForEach(parcours) { trace in
                        MapPolyline(coordinates: trace.points)
                            // Low opacity so streets run many times layer up into a visibly
                            // denser trace than a street run only once — the actual "heatmap"
                            // effect, built entirely from stacking real routes.
                            .stroke(RUColor.rose.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(RUColor.pageBackground)
        // `id: runs.count` : une course ajoutée ou supprimée refait le calcul, le reste ne le
        // refait pas. Un `onAppear` seul raterait la course enregistrée pendant que cet écran est
        // ouvert — un `body` à chaque passe la voyait, pour le prix décrit plus haut.
        .task(id: runs.count) {
            preparer()
            prepare = true
        }
    }

    /// L'UNIQUE parcours des positions : il construit les tracés et le rectangle englobant
    /// ensemble, au lieu d'aplatir tout une seconde fois pour ne garder que quatre nombres.
    private func preparer() {
        var minLat = Double.infinity, maxLat = -Double.infinity
        var minLng = Double.infinity, maxLng = -Double.infinity
        var traces: [Parcours] = []

        for run in runs {
            let route = run.route
            guard route.count > 1 else { continue }
            var points: [CLLocationCoordinate2D] = []
            points.reserveCapacity(route.count)
            for point in route {
                minLat = min(minLat, point.lat); maxLat = max(maxLat, point.lat)
                minLng = min(minLng, point.lng); maxLng = max(maxLng, point.lng)
                points.append(CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng))
            }
            traces.append(Parcours(id: run.persistentModelID, points: points))
        }

        parcours = traces
        guard !traces.isEmpty, minLat.isFinite, minLng.isFinite else {
            cadrage = nil
            return
        }
        cadrage = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
                                   longitudeDelta: max((maxLng - minLng) * 1.3, 0.01))
        )
    }
}
