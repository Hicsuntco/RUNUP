import Foundation

/// A single planned workout — today's hero session, or a day in the full plan. Embedded value
/// type (Codable), not its own SwiftData entity: it only ever exists nested inside `UserProfile`
/// or generated on the fly for the Plan screen's week list.
struct WorkoutSession: Codable, Equatable {
    var title: String
    var subtitle: String
    var durationMinutes: Int
    var pace: String
    var zone: String
    /// e.g. "+1 palier" when the coach bumped difficulty — nil when unchanged.
    var adjustment: String?

    static let reprise = WorkoutSession(
        title: "Footing de reprise",
        subtitle: "on repart en douceur sur de nouvelles bases",
        durationMinutes: 30, pace: "5:30", zone: "Z2", adjustment: nil
    )
}

/// One day in the current week's real training plan (as opposed to `DayStatus`, which only
/// tracks the home strip's done/today/rest badge). `session == nil` means a rest day. Generated
/// fresh for the whole week at once by `AdaptivePlanEngine.generateWeekSessions`, so every day is
/// already planned before the week starts — adaptation only regenerates this at a week boundary,
/// never after an individual run.
struct PlannedDay: Codable, Equatable, Identifiable {
    var id: Int { weekday }
    /// 0 = Monday ... 6 = Sunday.
    var weekday: Int
    var session: WorkoutSession?
    var completed: Bool = false
}

/// One day in the 7-cell week strip on Home.
struct DayStatus: Codable, Equatable, Identifiable {
    enum State: String, Codable {
        case done, today, upcoming, rest
    }

    var id: Int { weekday }
    /// 0 = Monday ... 6 = Sunday.
    var weekday: Int
    var letter: String
    var state: State

    static let letters = ["L", "M", "M", "J", "V", "S", "D"]
}
