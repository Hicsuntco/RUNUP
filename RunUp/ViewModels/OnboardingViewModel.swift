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
    var chrono: String?
    var isCustomChrono = false
    var raceDate: Date?
    // Step 3 — HYROX branch (reuses `chrono`/`raceDate` above for target finish time/event date)
    var hyroxDivision: HyroxDivision?
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
        case 3: return isRace ? raceStepValid : (isHyrox ? hyroxStepValid : deepDiveValid)
        // Injury/cycle fields are always optional — a real, known injury/blessure worth flagging
        // is the exception, not the rule, so requiring an answer here would just add friction for
        // the common case of "nothing to report."
        case 4: return true
        case 5: return runningDays.count >= 2 && runningDaysTouched
        case 6: return levelTouched
        case 7: return true
        default: return true
        }
    }

    private var raceStepValid: Bool {
        guard let distance else { return false }
        if distance == .other && customDistance.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        return hasChrono && raceDate != nil
    }

    private var hyroxStepValid: Bool {
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        return hasChrono && raceDate != nil && hyroxDivision != nil
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
            raceDistance: isRace ? distance : nil,
            raceDistanceCustom: isRace ? customDistance : nil,
            raceChrono: isRace ? chrono : (isHyrox ? chrono : nil),
            raceDate: isRace ? raceDate : (isHyrox ? raceDate : nil),
            hyroxDivision: isHyrox ? hyroxDivision?.rawValue : nil,
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
