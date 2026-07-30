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

    private var runsWithRoute: [RunRecord] { runs.filter { $0.route.count > 1 } }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.3, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackTitleHeaderView(eyebrow: "\(runsWithRoute.count) parcours trackés", title: "Mes routes") {
                appState.go(.stats)
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if runsWithRoute.isEmpty {
                Spacer()
                Text("Aucun parcours GPS enregistré pour l'instant — la carte se remplit après ta première course trackée.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            } else {
                let allCoords = runsWithRoute.flatMap { run in
                    run.route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                }
                if let region = region(for: allCoords) {
                    Map(initialPosition: .region(region)) {
                        ForEach(runsWithRoute) { run in
                            MapPolyline(coordinates: run.route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) })
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
        }
        .background(RUColor.bg)
    }
}
