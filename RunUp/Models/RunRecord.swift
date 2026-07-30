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
        /// Real GPS altitude in meters, only when the fix's vertical accuracy was trustworthy
        /// (see `LocationService`) — Optional (not a 0 default) so it reads as "unknown" rather
        /// than "sea level" when there's no trustworthy reading, and so every run recorded
        /// before this field existed still decodes fine (a non-optional field with no inline
        /// default would fail Codable synthesis against old, key-less JSON).
        var altitude: Double?
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
    /// Which `Shoe` this run was logged in, if any — a plain field (not a `@Relationship`) so
    /// deleting a `Shoe` never cascades onto real run history; `Shoe.totalKm` just stops counting
    /// a run whose shoe no longer exists.
    var shoeID: UUID? = nil
    /// Set once, the moment `DebriefSheet`'s VALIDER actually runs for this record — the real
    /// guard against crediting XP/streak/club-feed twice for the same run (a double-tap, or
    /// reopening the debrief for an already-validated run). `run.modelContext == nil` alone only
    /// ever protected the INSERT, not re-running the reward logic on an already-inserted record.
    var debriefedAt: Date? = nil

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
