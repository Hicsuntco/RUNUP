import Foundation

/// One cell of the week strip, for the widget's compact day-by-day row — mirrors the handful of
/// `DayStatus` fields the widget actually renders (letter + done/today), rather than sharing the
/// app's own `DayStatus` type (which lives in `RunUp/Models/`, not `Shared/`, and carries a full
/// `Date` plus a 4-case state the widget doesn't need to distinguish at this size).
struct WidgetWeekDay: Codable {
    var letter: String
    var isDone: Bool
    var isToday: Bool
}

/// The tiny slice of `UserProfile` the Home Screen widget needs, mirrored into an App Group
/// container — the widget extension runs in its own process with no access to the main app's
/// SwiftData store, so it can only ever read what the app last chose to publish here. The app
/// writes a fresh snapshot (`AppState.publishWidgetSnapshot`) every time daily goals could have
/// changed, then asks WidgetKit to reload; the widget only ever reads via `load()`, never writes.
/// Deliberately just `progress`/`streak`/theme id — not the full `UserProfile` — so a change to
/// that model never has to think about what an entirely separate process/target does with it.
struct DailyGoalsSnapshot: Codable {
    /// [Séance du jour, Calories actives, Pas], each 0...1 — same order/meaning as
    /// `UserProfile.dailyGoalsProgress`.
    var progress: [Double]
    var streak: Int
    var accentThemeID: String
    var isLightMode: Bool
    /// `UserProfile.dailyGoalsDone`/`.dailyGoalsTotal` — the widget's own "X/3 bouclés" eyebrow,
    /// so it doesn't have to re-derive completion count from `progress` (which alone can't tell
    /// "1 done at 100%" apart from "all 3 half-done" without the same `>= 1` threshold logic
    /// `UserProfile` already applies once).
    var dailyGoalsDone: Int
    var dailyGoalsTotal: Int
    /// Raw remaining amounts (not just the 0...1 fractions in `progress`) so the widget can phrase
    /// a real sentence ("Encore 110 kcal actives et 2400 pas") instead of just showing the ring.
    var activeCaloriesRemaining: Int
    var stepsRemaining: Int
    /// Monday...Sunday, mirrors `UserProfile.weekStrip` — the medium widget's compact
    /// done/today/upcoming row underneath the ring.
    var weekStrip: [WidgetWeekDay]

    static let appGroupID = "group.com.hicsuntco.runup"
    private static let defaultsKey = "runup.widget.daily-goals-snapshot"
    // `UserDefaults(suiteName:)` re-resolves the App Group container each time it's instantiated —
    // not free — and this is written on every launch/foreground/goal change and read on every
    // widget timeline reload, so a fresh instance (and fresh encoder/decoder) per call adds up.
    private static let defaults = UserDefaults(suiteName: appGroupID)
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func save(_ snapshot: DailyGoalsSnapshot) {
        guard let defaults, let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static func load() -> DailyGoalsSnapshot? {
        guard let defaults, let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? decoder.decode(DailyGoalsSnapshot.self, from: data)
    }
}
