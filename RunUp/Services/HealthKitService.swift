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

    /// Steps recorded today — used as-is (not literally isolated from step-during-a-run time) for
    /// the "Pas" daily goal; a reasonable proxy since a single run is a small fraction of most
    /// days' total steps, and RunRecord doesn't store precise start/end timestamps to subtract by.
    func stepsToday() async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return await sumToday(type: type, unit: .count())
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
        return await sumToday(type: type, unit: .kilocalorie())
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

    /// Saves a completed run as an HKWorkout.
    func saveRun(start: Date, end: Date, distanceKm: Double, kcal: Double) async throws {
        let workout = HKWorkout(
            activityType: .running,
            start: start,
            end: end,
            duration: end.timeIntervalSince(start),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
            totalDistance: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm),
            metadata: nil
        )
        try await store.save(workout)
    }

    private func sumToday(type: HKQuantityType, unit: HKUnit) async -> Double {
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }
}
