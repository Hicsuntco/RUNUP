import Foundation
import Observation
import HealthKit

/// Apple Santé integration — the only natively-supported data source in v1 (see README:
/// "Utilise HealthKit pour la connexion Apple Santé en priorité ... Strava/Garmin peuvent
/// rester des stubs"). Reads feed the readiness score and rings; writes record completed runs.
@Observable
final class HealthKitService {
    private let store = HKHealthStore()

    private(set) var isAuthorized = false

    static var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    private static let writeTypes: Set<HKSampleType> = [HKObjectType.workoutType()]

    func requestAuthorization() async throws {
        guard Self.isHealthDataAvailable else { return }
        try await store.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
        isAuthorized = true
    }

    /// Long-lived observer queries — kept so `startObservingDailyGoals` is idempotent (called on
    /// every foreground sync; only the first call actually registers anything).
    @ObservationIgnored private var observerQueries: [HKObserverQuery] = []

    /// Watches steps + active calories and fires `onChange` whenever Santé records new samples —
    /// including in the BACKGROUND (hourly batches, via `enableBackgroundDelivery` + the
    /// healthkit.background-delivery entitlement). This is what keeps the Home Screen widget's
    /// "PAS -2 400" honest while she walks all day without opening the app: each delivery wakes
    /// the app briefly, the sync re-reads today's totals and republishes the widget snapshot.
    ///
    /// `@Sendable` sur `onChange` : HealthKit appelle cette fermeture depuis sa propre file, pas
    /// depuis le fil principal. Sans l'annotation, l'appelant (`AppState`, isolé `@MainActor`)
    /// fournissait une fermeture isolée sur l'acteur principal que HealthKit invoquait quand même
    /// en arrière-plan — exactement le genre de saut d'isolation silencieux que Swift 6 refuse.
    func startObservingDailyGoals(onChange: @escaping @Sendable () -> Void) {
        guard Self.isHealthDataAvailable, observerQueries.isEmpty else { return }
        let identifiers: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned]
        for identifier in identifiers {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
                if error == nil { onChange() }
                // Always called, even on error — HealthKit throttles observers that don't
                // acknowledge deliveries.
                completionHandler()
            }
            store.execute(query)
            observerQueries.append(query)
            // Hourly is the floor iOS actually honors for these high-frequency types — matches
            // the widget's own reload budget anyway.
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    /// Steps recorded today — used as-is (not literally isolated from step-during-a-run time) for
    /// the "Pas" daily goal; a reasonable proxy since a single run is a small fraction of most
    /// days' total steps, and RunRecord doesn't store precise start/end timestamps to subtract by.
    func stepsToday() async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return await sum(type: type, unit: .count(), on: .now)
    }

    /// Active calories burned today — feeds the "Calories actives" daily goal. Deliberately not
    /// "minutes actives"/Exercise Time (`appleExerciseTime`): that quantity type is effectively
    /// Apple-Watch-only in practice (third-party sources rarely write to it), while active energy
    /// is a standard quantity type most fitness ecosystems do write to — including RunUp's own
    /// `saveRun` below, so even a runner with no watch at all gets a real, non-zero number on any
    /// day she logs a run, and a Garmin (or any other) watch's own Health-sync app contributes the
    /// rest for the days it's worn.
    func activeCaloriesToday() async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await sum(type: type, unit: .kilocalorie(), on: .now)
    }

    /// Same two reads as above, but for any past calendar day — Santé keeps this data
    /// indefinitely, RunUp just never asked for a day other than today until now. Powers the
    /// "Ta journée" day browser (`RingsView`) so a past day's ring isn't limited to what's in
    /// History (which only ever had actual runs, never the steps/calories side).
    func steps(on date: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return await sum(type: type, unit: .count(), on: date)
    }

    func activeCalories(on date: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await sum(type: type, unit: .kilocalorie(), on: date)
    }

    /// Most recent heart-rate sample within the last `maxAge` seconds — used to poll a genuinely
    /// live-ish reading during a run (see `LiveRunViewModel`). Filtered to `maxAge` rather than
    /// "the last sample ever" so a stale reading from hours/days ago (no Watch worn right now)
    /// correctly returns `nil` instead of being displayed as if it were current.
    func latestHeartRate(maxAge: TimeInterval = 90) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-maxAge), end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let bpm = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    /// Total time actually asleep last night, in hours — the window runs from 6pm yesterday to
    /// noon today, wide enough to catch any real bedtime (including a late one) without pulling
    /// in the PREVIOUS night too. Feeds `AdaptivePlanEngine.applySameDayAdjustmentIfNeeded`: sleep
    /// permission was already requested (see `readTypes`) for this from the start, but nothing
    /// ever actually read it until now. Nil — not 0 — when Santé has no sleep data for that window
    /// (no Watch/sleep tracking used, or she never actually slept with her phone/Watch nearby that
    /// night), since 0 would read as "she didn't sleep at all" rather than "no data".
    func lastNightSleepHours() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        guard let end = cal.date(bySettingHour: 12, minute: 0, second: 0, of: .now),
              let todaySixPM = cal.date(bySettingHour: 18, minute: 0, second: 0, of: .now),
              let start = cal.date(byAdding: .day, value: -1, to: todaySixPM)
        else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            store.execute(query)
        }
    }

    /// Saves a completed run as an HKWorkout.
    /// `duration` is the real moving time (pauses excluded) — passed separately from start/end
    /// because `end - start` includes every pause, and Santé would otherwise show a 30-min run
    /// with a 15-min coffee stop as a 45-min workout.
    func saveRun(start: Date, end: Date, duration: TimeInterval, distanceKm: Double, kcal: Double) async throws {
        let workout = HKWorkout(
            activityType: .running,
            start: start,
            end: end,
            duration: duration,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
            totalDistance: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm),
            metadata: nil
        )
        try await store.save(workout)
    }

    /// `end` is `.now` for today (only counts what's actually happened so far — not a future
    /// window) and the real end of day for any earlier date.
    private func sum(type: HKQuantityType, unit: HKUnit, on date: Date) async -> Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.isDateInToday(date) ? Date.now : (cal.date(byAdding: .day, value: 1, to: start) ?? start)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }
}
