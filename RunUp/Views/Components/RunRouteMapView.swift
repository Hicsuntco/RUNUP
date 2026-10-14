import SwiftUI
import MapKit

/// A small, non-interactive map showing a real completed run's GPS trace — replaces the old
/// decorative fixed-shape curve wherever a route needs to look like an actual map instead of a
/// generic squiggle: Recap's hero header, History's mini-thumbnails. Nil route (a manual entry or
/// a no-GPS "Marquer comme faite") renders nothing — callers should fall back to a purely
/// decorative treatment in that case rather than showing an empty map.
struct RunRouteMapView: View {
    var route: [RunRecord.RoutePoint]
    var lineWidth: CGFloat = 4
    var lineColor: Color = RUColor.rose
    /// Est-ce que la carte se manipule — pincer, déplacer, zoomer ?
    ///
    /// `false` PARTOUT SAUF EN PLEIN ÉCRAN, et ce n'est pas de la frilosité. Cette vue sert
    /// surtout de vignette : une par ligne dans l'historique, une en fond de l'écran de fin. Une
    /// carte manipulable à ces endroits-là capte le geste de défilement — le doigt qui veut
    /// remonter la liste déplace la carte sous lui, et la liste ne bouge pas. C'est pour ça que
    /// `allowsHitTesting(false)` était posé ici dès l'origine.
    ///
    /// Le vrai manque n'était donc pas que cette vue soit inerte, c'est qu'aucun écran n'offrait
    /// la carte EN GRAND. Voir `RouteZoomView` : le geste de défilement n'y existe pas, donc le
    /// conflit non plus.
    var interactive: Bool = false

    private var coordinates: [CLLocationCoordinate2D] {
        route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        // 40% padding so the trace doesn't touch the frame's edges, with a floor so a
        // dead-straight or near-stationary route doesn't zoom in absurdly tight.
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.003),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.003)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        // Computed once per body evaluation and reused for both the region scan and the polyline
        // itself — `coordinates` used to be read 3 times per render (twice directly, once inside
        // the old `region` computed property re-deriving it from scratch), each a full `.map`
        // pass over the route. Shown in a scrolling history list, one row per completed run.
        let coords = coordinates
        if let region = region(for: coords), coords.count > 1 {
            Map(initialPosition: .region(region), interactionModes: interactive ? .all : []) {
                MapPolyline(coordinates: coords)
                    .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .allowsHitTesting(interactive)
        }
    }
}
