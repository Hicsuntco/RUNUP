import Foundation
import Observation

/// Drives the 9-step onboarding wizard. Mirrors the local state hooks in `Onboarding` (onboarding.jsx),
/// plus a step 4 (injury/cycle) split out of what used to be a combined step 3.
@Observable
final class OnboardingViewModel {
    static let totalSteps = 9

    var showWelcome = true
    var step = 0

    init() {
        loadDraft()
    }

    // Step 0
    var name = ""
    // Step 1
    var birthdate: Date?
    var sex: String?
    // Step 2
    var goal: GoalType?
    // Step 3 — race branch
    var distance: RaceDistance?
    var customDistance = ""
    /// Le D+ de la course, saisi en mètres. Une chaîne et non un `Int` : c'est un champ de
    /// texte, et l'état d'un champ de texte à moitié rempli n'est pas un nombre.
    var raceElevationGain = ""
    var chrono: String?
    var isCustomChrono = false
    var raceDate: Date?
    // Step 3 — HYROX branch (reuses `chrono`/`raceDate` above for target finish time/event date)
    var hyroxDivision: HyroxDivision?
    // Step 3 — branche triathlon. Réutilise `chrono` (le temps visé) et `raceDate` (la date de
    // l'épreuve) comme HYROX : les deux veulent dire exactement la même chose ici.
    var triathlonFormat: TriathlonFormat?
    /// Ce qu'elle nage en continu AUJOURD'HUI. Sans valeur par défaut, volontairement : c'est la
    /// seule question de l'inscription dont une réponse supposée peut faire du mal, et « 1500 m
    /// et plus » pré-cochée serait une réponse supposée. Voir `NiveauDeNage`.
    var nageNiveau: NiveauDeNage?
    // Step 3 — non-race branches
    var weightNow = ""
    var weightTarget = ""
    var height = ""
    var focusArea: String?
    var bestRecentPerf = ""
    var lastRanRecency: String?
    var weeklyTimeBudget: String?
    var preferredTimeOfDay: String?
    // Step 4 — shared across every branch (race included): injury is asked regardless of goal,
    // cycle tracking only ever offered when `sex == "female"`.
    var injuryArea: String?
    var cycleTrackingEnabled = false
    var lastPeriodStartDate: Date?
    var averageCycleLengthDays = 28
    // Step 5
    var runningDays: Set<Int> = [1, 2, 4, 6]
    var preferredLongRunDay: Int?
    /// Set the moment she taps any day toggle — `runningDays` starts pre-filled with a plausible
    /// default so the screen isn't empty, but a plan built from that default without her ever
    /// touching it would be guessing at her real rhythm, not asking. Gates `canProceed(fromStep:
    /// 5)` alongside the existing 2-day minimum.
    var runningDaysTouched = false

    /// The day the long run actually lands on — falls back to the latest selected running day if
    /// none was explicitly chosen, or if the chosen one got deselected.
    var effectiveLongRunDay: Int? {
        if let day = preferredLongRunDay, runningDays.contains(day) { return day }
        return runningDays.max()
    }
    // Step 6
    var level: ExperienceLevel = .intermediaire
    /// Same reasoning as `runningDaysTouched` — `level` defaults to `.intermediaire` so a card is
    /// always shown as selected, but the plan's whole starting difficulty comes from this one
    /// answer and shouldn't ship on a default she never confirmed.
    var levelTouched = false
    // Step 7
    var connected: Set<ConnectedSource> = []
    var connecting: ConnectedSource?
    // Step 8
    var buildProgress = 0

    var isRace: Bool { goal == .race }
    var isHyrox: Bool { goal == .hyrox }
    var isUltra: Bool { goal == .ultraTrail }
    var isTriathlon: Bool { goal == .triathlon }

    /// Le nombre de jours que l'objectif choisi exige. Deux tant qu'aucun objectif n'est encore
    /// choisi : l'étape des jours vient après celle de l'objectif, donc ce repli n'est atteint
    /// que par un brouillon incomplet.
    var joursMinimum: Int { goal?.joursMinimumParSemaine ?? 2 }
    /// L'étape « ta course » sert aux deux : un ultra-trail EST une course, avec une question
    /// de plus. Lui faire un écran séparé aurait dupliqué la distance, le chrono et la date
    /// pour un seul champ de différence.
    var isCourseOuUltra: Bool { isRace || isUltra }
    /// Le D+ saisi, quand c'en est un. Zéro et le vide sont la même réponse ici : « je ne sais
    /// pas », auquel cas le plan retombe sur une course plate.
    var raceElevationGainM: Int? {
        let brut = Int(raceElevationGain.trimmingCharacters(in: .whitespaces))
        return (brut ?? 0) > 0 ? brut : nil
    }

    var age: Int? {
        guard let birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: .now).year
    }

    var daysUntilRace: Int? {
        guard let raceDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: raceDate).day ?? 0
        return max(1, days)
    }

    func canProceed(fromStep step: Int) -> Bool {
        switch step {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return birthdate != nil && sex != nil
        case 2: return goal != nil
        case 3:
            if isCourseOuUltra { return raceStepValid }
            if isHyrox { return hyroxStepValid }
            if isTriathlon { return triathlonStepValid }
            return deepDiveValid
        // Injury/cycle fields are always optional — a real, known injury/blessure worth flagging
        // is the exception, not the rule, so requiring an answer here would just add friction for
        // the common case of "nothing to report."
        case 4: return true
        // Le minimum vient de l'OBJECTIF, pas d'un littéral : un triathlon en exige trois,
        // parce qu'une semaine à deux jours ne peut pas contenir trois disciplines. Voir
        // `GoalType.joursMinimumParSemaine`.
        case 5: return runningDays.count >= joursMinimum && runningDaysTouched
        case 6: return levelTouched
        case 7: return true
        default: return true
        }
    }

    private var raceStepValid: Bool {
        guard let distance else { return false }
        if distance == .other && customDistance.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        // Le dénivelé est EXIGÉ pour un ultra, et seulement pour lui. Sans ce nombre, le plan ne
        // peut pas calculer un temps d'effort, donc il retomberait sur des kilomètres plats —
        // c'est-à-dire sur le défaut que tout l'objectif existe pour corriger. Mieux vaut une
        // question de plus qu'un plan faux.
        if isUltra && raceElevationGainM == nil { return false }
        return hasChrono && raceDate != nil
    }

    private var hyroxStepValid: Bool {
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        return hasChrono && raceDate != nil && hyroxDivision != nil
    }

    /// Le format ET le niveau de natation sont exigés, et le niveau n'a pas de valeur par
    /// défaut — c'est ce qui le rend obligatoire. Le chrono et la date, comme pour HYROX.
    ///
    /// Exiger le niveau de natation est le pendant d'exiger le dénivelé pour un ultra (voir
    /// `raceStepValid`) : sans ce nombre, le plan ne peut pas dimensionner la seule discipline
    /// qu'il ne saura jamais mesurer. Mieux vaut une question de plus qu'un plan faux — et ici,
    /// qu'un plan qui envoie quelqu'un nager 1500 m sans l'avoir demandé.
    private var triathlonStepValid: Bool {
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        return hasChrono && raceDate != nil && triathlonFormat != nil && nageNiveau != nil
    }

    private var deepDiveValid: Bool {
        switch goal {
        case .weight: return !weightNow.isEmpty && !weightTarget.isEmpty && !height.isEmpty
        case .progress: return focusArea != nil
        case .restart: return lastRanRecency != nil
        case .health: return weeklyTimeBudget != nil && preferredTimeOfDay != nil
        default: return true
        }
    }

    /// Choisir un format pré-remplit le chrono, comme `selectDistance` le fait pour une course.
    /// Le deuxième preset et non le premier : le premier est une belle performance, le deuxième
    /// est le temps que fait la plupart des gens qui finissent.
    func selectTriathlonFormat(_ f: TriathlonFormat) {
        triathlonFormat = f
        chrono = f.chronoPresets[safe: 1]
        isCustomChrono = false
    }

    func selectDistance(_ d: RaceDistance) {
        distance = d
        if d != .other {
            chrono = d.chronoPresets[safe: 1]
            isCustomChrono = false
        } else {
            chrono = nil
        }
    }


    func buildResult() -> AdaptivePlanEngine.OnboardingResult {
        AdaptivePlanEngine.OnboardingResult(
            name: name.trimmingCharacters(in: .whitespaces),
            birthdate: birthdate,
            sex: sex,
            goal: goal ?? .health,
            raceDistance: isCourseOuUltra ? distance : nil,
            raceDistanceCustom: isCourseOuUltra ? customDistance : nil,
            raceElevationGainM: isUltra ? raceElevationGainM : nil,
            // Les trois objectifs à date partagent ces deux champs : la course et l'ultra par
            // `isCourseOuUltra`, HYROX et le triathlon chacun pour soi. `periodiseVersUneDate`
            // dit la même chose en une propriété, et c'est elle qu'il faudra lire le jour où un
            // quatrième arrive — cette chaîne de ternaires a déjà atteint sa limite.
            raceChrono: (goal?.periodiseVersUneDate ?? false) ? chrono : nil,
            raceDate: (goal?.periodiseVersUneDate ?? false) ? raceDate : nil,
            hyroxDivision: isHyrox ? hyroxDivision?.rawValue : nil,
            triathlonFormat: isTriathlon ? triathlonFormat?.rawValue : nil,
            nageNiveau: isTriathlon ? nageNiveau?.rawValue : nil,
            runningDays: Array(runningDays),
            preferredLongRunDay: effectiveLongRunDay,
            level: level,
            connectedSources: Array(connected),
            weightNowKg: Double(weightNow),
            weightTargetKg: Double(weightTarget),
            heightCm: Double(height),
            focusArea: focusArea,
            bestRecentPerf: bestRecentPerf.isEmpty ? nil : bestRecentPerf,
            lastRanRecency: lastRanRecency,
            injuryArea: injuryArea,
            weeklyTimeBudget: weeklyTimeBudget,
            preferredTimeOfDay: preferredTimeOfDay,
            cycleTrackingEnabled: sex == "female" && cycleTrackingEnabled,
            lastPeriodStartDate: cycleTrackingEnabled ? lastPeriodStartDate : nil,
            averageCycleLengthDays: averageCycleLengthDays
        )
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
