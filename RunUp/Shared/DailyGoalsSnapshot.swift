import Foundation

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

    static let appGroupID = "group.com.hicsuntco.runup"
    private static let defaultsKey = "runup.widget.daily-goals-snapshot"

    static func save(_ snapshot: DailyGoalsSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static func load() -> DailyGoalsSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: defaultsKey)
        else { return nil }
        return try? JSONDecoder().decode(DailyGoalsSnapshot.self, from: data)
    }
}
