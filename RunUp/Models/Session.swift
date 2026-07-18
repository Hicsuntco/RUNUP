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

    /// True only for the archetypes actually structured as reps + recovery (see
    /// `AdaptivePlanEngine.archetypes`) — a footing/tempo/sortie longue is one continuous effort,
    /// not a set of intervals. Shared by `SessionDetailSheet` (step breakdown) and the Live Run
    /// screen (interval-progress badge) so both agree on what counts as an interval session.
    var isIntervalSession: Bool {
        let t = title.lowercased()
        return t.contains("fractionné") || t.contains("rappel d'allure")
    }
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
    /// The real calendar date this cell represents — lets the strip show an actual date number
    /// (like "12", today circled) instead of just a bare weekday letter. Defaults to `.now` when
    /// decoding a `weekStrip` persisted before this field existed, so existing profiles don't
    /// crash on launch.
    var date: Date = .now

    static let letters = ["L", "M", "M", "J", "V", "S", "D"]

    private enum CodingKeys: String, CodingKey { case weekday, letter, state, date }

    init(weekday: Int, letter: String, state: State, date: Date = .now) {
        self.weekday = weekday
        self.letter = letter
        self.state = state
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekday = try c.decode(Int.self, forKey: .weekday)
        letter = try c.decode(String.self, forKey: .letter)
        state = try c.decode(State.self, forKey: .state)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? .now
    }
}
