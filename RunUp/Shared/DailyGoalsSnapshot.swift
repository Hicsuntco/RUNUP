import Foundation

/// One cell of the week strip, for the widget's compact day-by-day row — mirrors the handful of
/// `DayStatus` fields the widget actually renders (letter + done/today), rather than sharing the
/// app's own `DayStatus` type (which lives in `RunUp/Models/`, not `Shared/`, and carries a full
/// `Date` plus a 4-case state the widget doesn't need to distinguish at this size).
struct WidgetWeekDay: Codable, Equatable {
    var letter: String
    var isDone: Bool
    var isToday: Bool

    init(letter: String, isDone: Bool, isToday: Bool) {
        self.letter = letter
        self.isDone = isDone
        self.isToday = isToday
    }

    /// Décodage tolérant : l'instantané du widget est écrit par l'app et relu par une AUTRE
    /// PROCESSUS, qui n'est pas forcément de la même version — l'extension garde la sienne en
    /// mémoire jusqu'à ce que le système la relance. Une clé ajoutée d'un côté ne doit pas
    /// rendre l'instantané illisible de l'autre : le widget afficherait alors un écran vide
    /// jusqu'à la publication suivante. Voir `ci_scripts/check_decodage.py`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        letter = try c.decodeIfPresent(String.self, forKey: .letter) ?? ""
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        isToday = try c.decodeIfPresent(Bool.self, forKey: .isToday) ?? false
    }

    private enum CodingKeys: String, CodingKey { case letter, isDone, isToday }

    /// Le rang du jour dans la bande, lundi = 0, à partir d'une date.
    ///
    /// # POURQUOI LE WIDGET NE CROIT PLUS `isToday`
    ///
    /// L'en-tête du widget écrit « Mardi » à partir de la date que le système lui donne. La
    /// pastille du jour lisait `isToday`, écrit par l'app au dernier instantané publié. Sur un
    /// vrai téléphone, le titre disait mardi pendant que la pastille cerclée était sur lundi :
    /// deux parties du même widget, deux jours différents, parce que l'une sait l'heure et
    /// l'autre récite ce qu'on lui a dit la veille.
    ///
    /// L'instantané ne garde donc que ce que lui seul sait — les jours bouclés — et le rang du
    /// jour se calcule.
    ///
    /// `Calendar.component(.weekday:)` rend 1 pour dimanche et 7 pour samedi. Ramener lundi à 0
    /// est un décalage de +5 modulo 7, et c'est exactement le genre de calcul qu'on croit juste :
    /// il est éprouvé sur les sept jours dans `RunUpTests`.
    static func rangDuJour(_ date: Date, calendrier: Calendar = Calendar(identifier: .gregorian)) -> Int {
        (calendrier.component(.weekday, from: date) + 5) % 7
    }
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
    /// Les objectifs eux-mêmes, et pas seulement ce qu'il en reste.
    ///
    /// Sans eux, le widget ne pouvait écrire que le reste, et il l'écrivait avec un signe moins :
    /// « -600 ». L'app, sur le même écran d'accueil, écrit « À FAIRE 0 /400 KCAL ». Deux façons
    /// de dire la même chose, dont une se lit comme un défaut. Avec l'objectif, le widget reprend
    /// la forme de l'app.
    ///
    /// Décodés avec une valeur par défaut, comme `isRestDay` : un instantané écrit par une
    /// version précédente ne doit pas faire échouer tout le décodage et renvoyer le widget à ses
    /// données d'exemple.
    var activeCaloriesGoal: Int = 0
    var stepsGoal: Int = 0
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
        case activeCaloriesGoal, stepsGoal
    }

    init(progress: [Double], streak: Int, accentThemeID: String, isLightMode: Bool,
         dailyGoalsDone: Int, dailyGoalsTotal: Int, activeCaloriesRemaining: Int,
         stepsRemaining: Int, weekStrip: [WidgetWeekDay], isRestDay: Bool = false,
         activeCaloriesGoal: Int = 0, stepsGoal: Int = 0) {
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
        self.activeCaloriesGoal = activeCaloriesGoal
        self.stepsGoal = stepsGoal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progress = try c.decodeIfPresent([Double].self, forKey: .progress) ?? []
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        // "rose" est la valeur de AccentTheme.defaultID, recopiee ici : ce fichier est
        // compile dans la cible RunUpWidgets, qui ne voit pas RunUp/DesignSystem.
        accentThemeID = try c.decodeIfPresent(String.self, forKey: .accentThemeID) ?? "rose"
        // `false` ET NON `true`, CONTRAIREMENT AU DÉFAUT DE L'APP, et c'est voulu : un instantané
        // sans cette clé a été écrit par une version de l'app ANTÉRIEURE à la clé, donc par
        // quelqu'un qui a déjà un profil — et un profil déjà enregistré reste en sombre. Mettre
        // `true` ici afficherait un widget clair à côté d'une app sombre, le temps du prochain
        // lancement.
        isLightMode = try c.decodeIfPresent(Bool.self, forKey: .isLightMode) ?? false
        dailyGoalsDone = try c.decodeIfPresent(Int.self, forKey: .dailyGoalsDone) ?? 0
        dailyGoalsTotal = try c.decodeIfPresent(Int.self, forKey: .dailyGoalsTotal) ?? 3
        activeCaloriesRemaining = try c.decodeIfPresent(Int.self, forKey: .activeCaloriesRemaining) ?? 0
        stepsRemaining = try c.decodeIfPresent(Int.self, forKey: .stepsRemaining) ?? 0
        weekStrip = try c.decodeIfPresent([WidgetWeekDay].self, forKey: .weekStrip) ?? []
        isRestDay = try c.decodeIfPresent(Bool.self, forKey: .isRestDay) ?? false
        activeCaloriesGoal = try c.decodeIfPresent(Int.self, forKey: .activeCaloriesGoal) ?? 0
        stepsGoal = try c.decodeIfPresent(Int.self, forKey: .stepsGoal) ?? 0
    }

    /// L'état vide honnête — ce que le widget montre avant que l'app ait jamais publié
    /// (installation neuve), plutôt que des chiffres de démonstration inventés.
    ///
    /// `isLightMode: true` : une installation neuve, c'est exactement le cas où l'app ouvre en
    /// clair. Le widget doit dire la même chose qu'elle.
    static var empty: DailyGoalsSnapshot {
        DailyGoalsSnapshot(progress: [0, 0, 0], streak: 0, accentThemeID: "rose", isLightMode: true,
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
