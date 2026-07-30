import Foundation
import SwiftData

/// A pair of running shoes, tracked for wear like Strava/Garmin's gear feature — the single most
/// concrete "thing to look at and manage" a runner has, no GPS matching or social graph needed.
/// `RunRecord.shoeID` (a plain field, not a `@Relationship`, same lightweight pattern as
/// `stravaActivityId`) links a run to the pair it was actually run in; total wear is always
/// derived from real linked runs rather than an incremented counter, so it can never drift out of
/// sync the way a stored running total could.
@Model
final class Shoe {
    var id: UUID
    var name: String
    var createdAt: Date
    /// Km already on the shoe before she started tracking it in the app — lets a pair bought
    /// months ago start at its real wear instead of pretending it's brand new.
    var startDistanceKm: Double
    /// Non-nil once retired — kept in history (and still shown, read-only) rather than deleted, so
    /// past runs logged against it don't silently lose their shoe attribution.
    var retiredAt: Date?
    /// Typical road-shoe lifespan is 600-800km before cushioning/support genuinely degrades —
    /// 700 is a reasonable default; editable per pair since a racing flat and a max-cushion
    /// trainer don't wear the same way.
    var alertThresholdKm: Double

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        startDistanceKm: Double = 0,
        retiredAt: Date? = nil,
        alertThresholdKm: Double = 700
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.startDistanceKm = startDistanceKm
        self.retiredAt = retiredAt
        self.alertThresholdKm = alertThresholdKm
    }

    /// Always recomputed from `runs`, never stored — same reasoning as `AdaptivePlanEngine
    /// .recomputeStreak`: a running total that's incremented by hand goes stale the moment a run
    /// gets deleted or reassigned, while deriving it fresh is honest by construction.
    func totalKm(runs: [RunRecord]) -> Double {
        startDistanceKm + runs.filter { $0.shoeID == id }.reduce(0) { $0 + $1.distanceKm }
    }
}
