import Foundation
import Observation

/// Drives the 8-step onboarding wizard. Mirrors the local state hooks in `Onboarding` (onboarding.jsx).
@Observable
final class OnboardingViewModel {
    static let totalSteps = 8

    var showWelcome = true
    var step = 0

    // Step 0
    var name = ""
    // Step 1
    var birthdate: Date?
    // Step 2
    var goal: GoalType?
    // Step 3 — race branch
    var distance: RaceDistance?
    var customDistance = ""
    var chrono: String?
    var isCustomChrono = false
    var raceDate: Date?
    // Step 3 — non-race branches
    var weightNow = ""
    var weightTarget = ""
    var height = ""
    var focusArea: String?
    var bestRecentPerf = ""
    var lastRanRecency: String?
    var injuryArea: String?
    var weeklyTimeBudget: String?
    var preferredTimeOfDay: String?
    // Step 4
    var runningDays: Set<Int> = [1, 2, 4, 6]
    var preferredLongRunDay: Int?

    /// The day the long run actually lands on — falls back to the latest selected running day if
    /// none was explicitly chosen, or if the chosen one got deselected.
    var effectiveLongRunDay: Int? {
        if let day = preferredLongRunDay, runningDays.contains(day) { return day }
        return runningDays.max()
    }
    // Step 5
    var level: ExperienceLevel = .intermediaire
    // Step 6
    var connected: Set<ConnectedSource> = []
    var connecting: ConnectedSource?
    // Step 7
    var buildProgress = 0

    var isRace: Bool { goal == .race }

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
        case 1: return birthdate != nil
        case 2: return goal != nil
        case 3: return isRace ? raceStepValid : deepDiveValid
        case 4: return runningDays.count >= 2
        case 5: return true
        case 6: return true
        default: return true
        }
    }

    private var raceStepValid: Bool {
        guard let distance else { return false }
        if distance == .other && customDistance.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        return hasChrono && raceDate != nil
    }

    private var deepDiveValid: Bool {
        switch goal {
        case .weight: return !weightNow.isEmpty && !weightTarget.isEmpty && !height.isEmpty
        case .progress: return focusArea != nil
        case .restart: return lastRanRecency != nil && injuryArea != nil
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

    func toggleConnect(_ source: ConnectedSource) {
        if connected.contains(source) {
            connected.remove(source)
            return
        }
        connecting = source
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            await MainActor.run {
                connected.insert(source)
                connecting = nil
            }
        }
    }

    func buildResult() -> AdaptivePlanEngine.OnboardingResult {
        AdaptivePlanEngine.OnboardingResult(
            name: name.trimmingCharacters(in: .whitespaces),
            birthdate: birthdate,
            goal: goal ?? .health,
            raceDistance: isRace ? distance : nil,
            raceDistanceCustom: isRace ? customDistance : nil,
            raceChrono: isRace ? chrono : nil,
            raceDate: isRace ? raceDate : nil,
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
            preferredTimeOfDay: preferredTimeOfDay
        )
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
