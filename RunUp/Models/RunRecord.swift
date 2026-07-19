import Foundation
import SwiftData

/// One completed run — a growing collection, queried newest-first. Mirrors `history` in app.jsx.
@Model
final class RunRecord {
    /// A GPS fix from the real route — plain lat/lng rather than `CLLocationCoordinate2D` (not
    /// natively `Codable`), so SwiftData can store it like any other value-type array (same
    /// pattern as `splits: [String]`). Feeds the share-card route trace; empty for runs with no
    /// GPS behind them (manually logged, or the no-GPS "Marquer comme faite" path).
    struct RoutePoint: Codable, Equatable {
        var lat: Double
        var lng: Double
    }

    var date: Date
    var title: String
    var distanceKm: Double
    var durationSeconds: Int
    var avgPace: String
    var avgHeartRate: Int
    var kcal: Int
    var elevationGainM: Int
    var splits: [String]
    var route: [RoutePoint] = []
    /// Non-nil only for a run imported from Strava (see `StravaService.importActivities`) — lets
    /// re-importing skip activities already pulled in, instead of duplicating History on every
    /// sync.
    var stravaActivityId: Int? = nil

    init(
        date: Date = .now,
        title: String,
        distanceKm: Double,
        durationSeconds: Int,
        avgPace: String,
        avgHeartRate: Int,
        kcal: Int,
        elevationGainM: Int = 0,
        splits: [String] = [],
        route: [RoutePoint] = [],
        stravaActivityId: Int? = nil
    ) {
        self.date = date
        self.title = title
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.avgPace = avgPace
        self.avgHeartRate = avgHeartRate
        self.kcal = kcal
        self.elevationGainM = elevationGainM
        self.splits = splits
        self.route = route
        self.stravaActivityId = stravaActivityId
    }
}
