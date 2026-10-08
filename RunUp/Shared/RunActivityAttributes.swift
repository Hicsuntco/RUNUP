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
    /// `WorkoutSession.durationMinutes` at the moment the run started — real planned data (unlike
    /// distance, which no `WorkoutSession` actually tracks), so the Lock Screen's progress bar
    /// shows genuine "how far into the session" rather than a fabricated distance target. 0 for a
    /// rest-day/free-run session with no real plan behind it; the widget hides the bar then.
    var plannedDurationMinutes: Int = 0

    /// La discipline de la sortie, par sa `rawValue`.
    ///
    /// DANS LES ATTRIBUTS ET NON DANS L'ÉTAT : elle est fixée au départ et ne change plus — on ne
    /// passe pas du vélo à la course au milieu d'une sortie. C'est exactement ce que cette moitié
    /// du type est faite pour porter.
    ///
    /// OPTIONNELLE, et c'est ce qui compte. La synthèse de `Codable` n'utilise PAS les valeurs par
    /// défaut quand une clé manque : un champ non optionnel ferait échouer le décodage d'une
    /// activité démarrée par la version précédente, donc une mise à jour de l'app pendant une
    /// sortie figerait l'écran verrouillé. Un `String?` se décode par `decodeIfPresent` et rend
    /// `nil`. Même raisonnement, et même forme, que `RunRecord.disciplineRaw`.
    var disciplineRaw: String? = nil

    var discipline: Discipline {
        disciplineRaw.flatMap(Discipline.init(rawValue:)) ?? .legacy
    }
}
