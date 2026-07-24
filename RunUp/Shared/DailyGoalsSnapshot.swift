import Foundation

/// One cell of the week strip, for the widget's compact day-by-day row — mirrors the handful of
/// `DayStatus` fields the widget actually renders (letter + done/today), rather than sharing the
/// app's own `DayStatus` type (which lives in `RunUp/Models/`, not `Shared/`, and carries a full
/// `Date` plus a 4-case state the widget doesn't need to distinguish at this size).
struct WidgetWeekDay: Codable, Equatable {
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
// Equatable so `AppState.publishWidgetSnapshot` can skip identical re-publishes — WidgetKit's
// daily reload budget is ~40-70; browsing the color nuancier alone used to burn through it and
// silently freeze the widget for the rest of the day.
struct DailyGoalsSnapshot: Codable, Equatable {
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
    /// Rest day: the widget hides the séance goal bar and shows "Repos" instead of an empty
    /// "À faire" contradicting its own "X/2" denominator. Decoded with a default so a snapshot
    /// written by an older app build doesn't fail the whole decode (which would silently flip
    /// the widget to placeholder data).
    var isRestDay: Bool = false

    private enum CodingKeys: String, CodingKey {
        case progress, streak, accentThemeID, isLightMode, dailyGoalsDone, dailyGoalsTotal
        case activeCaloriesRemaining, stepsRemaining, weekStrip, isRestDay
    }

    init(progress: [Double], streak: Int, accentThemeID: String, isLightMode: Bool,
         dailyGoalsDone: Int, dailyGoalsTotal: Int, activeCaloriesRemaining: Int,
         stepsRemaining: Int, weekStrip: [WidgetWeekDay], isRestDay: Bool = false) {
        self.progress = progress
        self.streak = streak
        self.accentThemeID = accentThemeID
        self.isLightMode = isLightMode
        self.dailyGoalsDone = dailyGoalsDone
        self.dailyGoalsTotal = dailyGoalsTotal
        self.activeCaloriesRemaining = activeCaloriesRemaining
        self.stepsRemaining = stepsRemaining
        self.weekStrip = weekStrip
        self.isRestDay = isRestDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progress = try c.decode([Double].self, forKey: .progress)
        streak = try c.decode(Int.self, forKey: .streak)
        accentThemeID = try c.decode(String.self, forKey: .accentThemeID)
        isLightMode = try c.decode(Bool.self, forKey: .isLightMode)
        dailyGoalsDone = try c.decode(Int.self, forKey: .dailyGoalsDone)
        dailyGoalsTotal = try c.decode(Int.self, forKey: .dailyGoalsTotal)
        activeCaloriesRemaining = try c.decode(Int.self, forKey: .activeCaloriesRemaining)
        stepsRemaining = try c.decode(Int.self, forKey: .stepsRemaining)
        weekStrip = try c.decode([WidgetWeekDay].self, forKey: .weekStrip)
        isRestDay = try c.decodeIfPresent(Bool.self, forKey: .isRestDay) ?? false
    }

    /// The honest empty state — what the widget shows before the app has ever published
    /// (fresh install) instead of fabricated demo numbers.
    static var empty: DailyGoalsSnapshot {
        DailyGoalsSnapshot(progress: [0, 0, 0], streak: 0, accentThemeID: "rose", isLightMode: false,
                           dailyGoalsDone: 0, dailyGoalsTotal: 3, activeCaloriesRemaining: 0,
                           stepsRemaining: 0, weekStrip: [])
    }

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
