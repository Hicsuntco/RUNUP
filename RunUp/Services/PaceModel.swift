import Foundation

/// Real training paces derived from what's already collected at onboarding (target race time,
/// best recent performance, or declared level) — replaces the fixed pace/zone literals every
/// session archetype used to carry regardless of who was training. Deliberately simple (a
/// threshold-pace anchor + fixed percentage offsets per zone, in the spirit of standard
/// recreational-running pace calculators) rather than a full physiological model — this app has
/// no lab test, just a questionnaire, and a plausible estimate beats the same 3 fixed numbers for
/// every runner.
enum PaceModel {
    struct Zones {
        var easy: String       // Z2 — footings, long runs
        var marathon: String   // Z2-3 — allure semi-longue / rythme course longue distance
        var threshold: String  // Z3 — tempo / seuil
        var interval: String   // Z4 — fractionné / VMA
        /// Raw seconds/km behind `easy` — kept alongside the formatted string so
        /// `AdaptivePlanEngine` can compute a realistic long-run duration from a target distance
        /// without re-parsing the "M:SS" text.
        var easySecPerKm: Double
        /// Raw seconds/km behind `threshold` — the same anchor `referenceThresholdPace` computed,
        /// exposed so `StatsView` can project real race-time predictions from it too (via Riegel,
        /// same as here) when there's no run history yet to predict from instead.
        var thresholdSecPerKm: Double
    }

    static func zones(for profile: UserProfile) -> Zones {
        let thresholdSecPerKm = referenceThresholdPace(for: profile)
        return Zones(
            easy: format(thresholdSecPerKm * 1.20),
            marathon: format(thresholdSecPerKm * 1.08),
            threshold: format(thresholdSecPerKm * 1.0),
            interval: format(thresholdSecPerKm * 0.92),
            easySecPerKm: thresholdSecPerKm * 1.20,
            thresholdSecPerKm: thresholdSecPerKm
        )
    }

    /// Projects a known pace at one distance onto any other distance via Riegel's formula —
    /// exposed for `StatsView`'s race-time predictions, reusing the same model that seeds the
    /// plan's own paces instead of a second, disconnected formula.
    static func projectedPace(fromSecPerKm refSecPerKm: Double, fromKm refKm: Double, toKm targetKm: Double) -> Double {
        guard refKm > 0, targetKm > 0 else { return refSecPerKm }
        let refTotalSeconds = refSecPerKm * refKm
        let projectedTotalSeconds = refTotalSeconds * pow(targetKm / refKm, 1.06)
        return projectedTotalSeconds / targetKm
    }

    /// Exposed so `StatsView` can compare a real predicted race time against the user's actual
    /// target — same parsing `referenceThresholdPace` uses internally.
    static func parseChronoSeconds(_ text: String, distance: RaceDistance?) -> Double? {
        parseChrono(text, distance: distance)
    }

    static func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))" : "\(m):\(String(format: "%02d", s))"
    }

    /// A `RunRecord.avgPace` string ("m:ss") → seconds/km — shared by every screen that averages
    /// or compares real per-run paces (`StatsView`, `WeeklyRecapView`) instead of each keeping its
    /// own copy of the same split.
    static func parseSecPerKm(_ pace: String) -> Double? {
        let parts = pace.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// Total elapsed time across possibly many runs, e.g. "1h23" or "45 min" — distinct from
    /// `formatDuration` above, which formats a single pace/split as "m:ss". Shared by `StatsView`'s
    /// and `WeeklyRecapView`'s "temps total" tiles.
    static func formatTotalDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(m) min"
    }

    /// Seconds-per-km at "threshold" — the anchor every other zone is a percentage offset of.
    /// Priority: real race target time > best recent performance (parsed opportunistically) >
    /// declared experience level.
    private static func referenceThresholdPace(for profile: UserProfile) -> Double {
        if profile.goalId == .race,
           let chrono = profile.raceChrono,
           let km = profile.effectiveRaceDistanceKm,
           let totalSeconds = parseChrono(chrono, distance: profile.raceDistance),
           totalSeconds > 0 {
            return thresholdPace(fromPerformanceSeconds: totalSeconds, km: km)
        }
        if let recent = profile.bestRecentPerf, let parsed = parseFreeformPerf(recent) {
            return thresholdPace(fromPerformanceSeconds: parsed.seconds, km: parsed.km)
        }
        switch profile.level {
        case .debutante: return 330      // ≈ 5:30/km reference
        case .intermediaire: return 285  // ≈ 4:45/km
        case .confirmee: return 240      // ≈ 4:00/km
        }
    }

    /// Projects any real performance onto a 10K-equivalent time via Riegel's formula (a standard,
    /// widely-used race-time conversion), then treats that 10K pace as the threshold-pace anchor
    /// — a common approximation in recreational pace calculators.
    private static func thresholdPace(fromPerformanceSeconds seconds: Double, km: Double) -> Double {
        guard km > 0 else { return 285 }
        let projected10k = seconds * pow(10.0 / km, 1.06)
        return projected10k / 10.0
    }

    /// `chronoPresets` use "MM:SS" for 5K/10K but "H:MM" for semi/marathon (the presets
    /// themselves are already in whichever format fits the distance — see `GoalType.swift`). A
    /// custom chrono ("Mon propre temps") is free text, though, and its own placeholder
    /// (`RaceDetailsStepView`'s "Ex. 1:52:00") suggests full H:MM:SS — which used to fail to parse
    /// entirely (the old code only accepted exactly 2 colon-separated parts) and silently fall
    /// back to a generic level-based pace, regardless of the real chrono she'd just typed.
    private static func parseChrono(_ text: String, distance: RaceDistance?) -> Double? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3:
            return Double(parts[0] * 3600 + parts[1] * 60 + parts[2])
        case 2:
            switch distance {
            case .k5, .k10: return Double(parts[0] * 60 + parts[1])
            default: return Double(parts[0] * 3600 + parts[1] * 60)
            }
        default:
            return nil
        }
    }

    /// Best-effort parse of a free-text "best recent performance" — only used when confidently
    /// matched (a plain "Xkm" followed by a time-like token). Anything else falls back to the
    /// level-based default rather than risk deriving real training paces from a misparse.
    private static func parseFreeformPerf(_ text: String) -> (km: Double, seconds: Double)? {
        let lowered = text.lowercased()
        guard let kmRange = lowered.range(of: #"\d+(\.\d+)?\s?km"#, options: .regularExpression),
              let km = Double(lowered[kmRange].filter { $0.isNumber || $0 == "." }), km > 0
        else { return nil }
        guard let timeRange = lowered.range(of: #"\d{1,2}:\d{2}(:\d{2})?"#, options: .regularExpression) else { return nil }
        let timeParts = lowered[timeRange].split(separator: ":").compactMap { Int($0) }
        let seconds: Double
        switch timeParts.count {
        case 2: seconds = Double(timeParts[0] * 60 + timeParts[1]) // "52:00" → mm:ss for a recent-perf sentence
        case 3: seconds = Double(timeParts[0] * 3600 + timeParts[1] * 60 + timeParts[2])
        default: return nil
        }
        return (km, seconds)
    }

    private static func format(_ secondsPerKm: Double) -> String {
        let total = Int(secondsPerKm.rounded())
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
