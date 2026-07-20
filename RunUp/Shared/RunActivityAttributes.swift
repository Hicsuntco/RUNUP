import ActivityKit
import Foundation

/// Live Activity attributes for an in-progress run — Lock Screen + Dynamic Island. Lives in
/// `Shared/` because both targets need the *identical* type: the app (`LiveRunViewModel`, which
/// calls `Activity<RunActivityAttributes>.request`) and `RunUpWidgets` (which defines the actual
/// `ActivityConfiguration<RunActivityAttributes>` UI) — `Activity<Attributes>` is generic over
/// this, so there's no other way for the two sides to agree on what's even being displayed.
struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceKm: Double
        var elapsedSeconds: Double
        var paceLabel: String
        var isPaused: Bool
    }

    /// Fixed for the run's whole lifetime, set once at `Activity.request(attributes:)` — unlike
    /// `ContentState`, this never updates mid-run.
    var sessionTitle: String
}
