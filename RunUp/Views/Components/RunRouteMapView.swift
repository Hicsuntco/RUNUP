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

    private var coordinates: [CLLocationCoordinate2D] {
        route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    private var region: MKCoordinateRegion? {
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
        if let region, coordinates.count > 1 {
            Map(initialPosition: .region(region), interactionModes: []) {
                MapPolyline(coordinates: coordinates)
                    .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .allowsHitTesting(false)
        }
    }
}
