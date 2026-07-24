import Foundation
import HealthKit
import Observation

/// Drives a real watchOS running workout — `HKWorkoutSession` keeps the app alive with the
/// screen off, and `HKLiveWorkoutBuilder` streams the sensors the iPhone app alone never had:
/// live wrist heart rate, real distance (watchOS fuses GPS + accelerometer itself for an
/// outdoor-run configuration — no manual CoreLocation needed for v1), and measured active
/// calories. Ending the session saves a genuine workout to HealthKit (it counts toward her
/// Apple rings, and the iPhone app's daily goals read those same stores), then hands the run's
/// numbers to `WatchConnectivityManager` for the phone to turn into a `RunRecord` + debrief.
@Observable
final class WatchWorkoutManager: NSObject {
    enum State: Equatable {
        case idle
        case running
        case paused
        case ended
    }

    private(set) var state: State = .idle
    private(set) var elapsedSeconds: Double = 0
    private(set) var distanceMeters: Double = 0
    /// Nil until the first real sample lands — never a fabricated number, same policy as the
    /// iPhone app's live screen.
    private(set) var heartRate: Int?
    /// The session-wide average (from the builder's own statistics), distinct from `heartRate`
    /// (the live most-recent sample) — this is what the phone's RunRecord stores as FC moy.
    private(set) var avgHeartRate: Int?
    private(set) var activeCalories: Double = 0
    /// Set when starting/authorizing fails — the UI shows it instead of silently doing nothing.
    private(set) var errorMessage: String?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startedAt: Date?

    var paceLabel: String {
        let km = distanceMeters / 1000
        guard km > 0.05 else { return "--:--" }
        let secPerKm = elapsedSeconds / km
        let total = Int(secPerKm.rounded())
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    var elapsedLabel: String {
        let total = Int(elapsedSeconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))" : "\(m):\(String(format: "%02d", s))"
    }

    private static let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let dist = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(dist) }
        if let cal = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(cal) }
        return types
    }()

    private static let shareTypes: Set<HKSampleType> = {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let dist = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(dist) }
        if let cal = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(cal) }
        return types
    }()

    func start() {
        errorMessage = nil
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        Task {
            do {
                try await store.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
                let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
                session.delegate = self
                builder.delegate = self

                let start = Date()
                session.startActivity(with: start)
                try await builder.beginCollection(at: start)

                await MainActor.run {
                    self.session = session
                    self.builder = builder
                    self.startedAt = start
                    self.state = .running
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Impossible de démarrer — vérifie l'accès Santé dans Réglages."
                }
            }
        }
    }

    func togglePause() {
        guard let session else { return }
        if state == .running {
            session.pause()
            state = .paused
        } else if state == .paused {
            session.resume()
            state = .running
        }
    }

    func end() {
        guard let session, let builder else { return }
        state = .ended
        session.end()
        Task {
            do {
                try await builder.endCollection(at: Date())
                try await builder.finishWorkout()
            } catch {
                // The workout data is still in the builder's samples even when finishing throws
                // (rare) — the run summary below is what the phone consumes either way.
            }
            await MainActor.run {
                WatchConnectivityManager.shared.sendCompletedRun(
                    startedAt: self.startedAt ?? Date(),
                    elapsedSeconds: self.elapsedSeconds,
                    distanceKm: self.distanceMeters / 1000,
                    kcal: self.activeCalories,
                    avgHeartRate: self.avgHeartRate ?? 0
                )
            }
        }
    }

    func reset() {
        session = nil
        builder = nil
        startedAt = nil
        elapsedSeconds = 0
        distanceMeters = 0
        heartRate = nil
        avgHeartRate = nil
        activeCalories = 0
        state = .idle
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "La séance s'est interrompue — réessaie."
            self.state = .idle
        }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Statistics are read on the builder's own queue — snapshot then hop to main.
        var newHeartRate: Int?
        var newAvgHeartRate: Int?
        var newDistance: Double?
        var newCalories: Double?

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                if let bpm = statistics.mostRecentQuantity()?.doubleValue(for: bpmUnit) {
                    newHeartRate = Int(bpm.rounded())
                }
                if let avg = statistics.averageQuantity()?.doubleValue(for: bpmUnit) {
                    newAvgHeartRate = Int(avg.rounded())
                }
            case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
                newDistance = statistics.sumQuantity()?.doubleValue(for: .meter())
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                newCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())
            default:
                break
            }
        }

        let elapsed = workoutBuilder.elapsedTime
        Task { @MainActor in
            self.elapsedSeconds = elapsed
            if let newHeartRate { self.heartRate = newHeartRate }
            if let newAvgHeartRate { self.avgHeartRate = newAvgHeartRate }
            if let newDistance { self.distanceMeters = newDistance }
            if let newCalories { self.activeCalories = newCalories }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        let elapsed = workoutBuilder.elapsedTime
        Task { @MainActor in self.elapsedSeconds = elapsed }
    }
}
