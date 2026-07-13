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

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.workoutType()
        ]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    func requestAuthorization() async throws {
        guard Self.isHealthDataAvailable else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        isAuthorized = true
    }

    /// Active energy burned today (kcal) — feeds the "Bouger" ring.
    func activeEnergyToday() async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await sumToday(type: type, unit: .kilocalorie())
    }

    /// Apple Exercise minutes today — feeds the "Actif" ring.
    func exerciseMinutesToday() async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else { return 0 }
        return await sumToday(type: type, unit: .minute())
    }

    /// Running/walking distance today (km) — feeds the "Courir" ring.
    func runDistanceKmToday() async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0 }
        return await sumToday(type: type, unit: .meterUnit(with: .kilo))
    }

    /// Most recent resting/average heart rate sample (bpm), used for coach readiness copy.
    func latestHeartRate() async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
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
