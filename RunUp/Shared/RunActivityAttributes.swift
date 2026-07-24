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
        /// Reference date such that `now - timerReference == elapsed` — lets the widget render a
        /// self-ticking `Text(timerInterval:)` chrono (per-second, zero pushes) instead of the
        /// static label that only moved on each 5s update. Nil while paused/ended, where the
        /// frozen `elapsedSeconds` label is the honest display.
        var timerReference: Date?
        /// True on the final update — the Lock Screen card lingers a moment after the run, and
        /// without this it showed a pause icon as if the run were still going.
        var isEnded: Bool = false
    }

    /// Fixed for the run's whole lifetime, set once at `Activity.request(attributes:)` — unlike
    /// `ContentState`, this never updates mid-run.
    var sessionTitle: String
}
