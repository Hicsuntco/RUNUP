import Foundation
import Observation

/// Drives the Live Run screen: real elapsed time + GPS distance (via `LocationService`), coach
/// voice cues at scripted timestamps, and real GPS-instability detection. Ported from the
/// `startRun`/timer logic in app.jsx, adapted to use real CoreLocation data instead of a
/// simulated tick (see architecture decision to use MapKit for the Live Run screen).
@Observable
final class LiveRunViewModel {
    let location = LocationService()
    private let profile: UserProfile
    private let healthKit: HealthKitService
    private let startedAt = Date()

    private(set) var elapsedSeconds: Double = 0
    private(set) var isPaused = false
    private(set) var heartRate = 150
    private(set) var coachCue: String?

    private var timerTask: Task<Void, Never>?
    private var firedCueTimestamps: Set<Int> = []
    private var coachCueClearTask: Task<Void, Never>?

    private let cues: [(Int, String)]

    var distanceKm: Double { location.distanceMeters / 1000 }
    var isSignalUnstable: Bool { location.isSignalUnstable }
    var intervalIndex: Int { min(6, 1 + Int(distanceKm / 1.2)) }
    var kcal: Double { distanceKm * 65 }

    var paceLabel: String {
        guard distanceKm > 0.05 else { return "--:--" }
        let secPerKm = elapsedSeconds / distanceKm
        return AdaptivePlanEngine.fmt(secPerKm)
    }

    init(profile: UserProfile, healthKit: HealthKitService) {
        self.profile = profile
        self.healthKit = healthKit
        let name = profile.name
        let targetPace = profile.todaySession.pace
        cues = [
            (6, "C'est parti \(name). Échauffement tranquille, reste en Z2."),
            (120, "Fin d'échauffement. Premier 800 : vise \(targetPace), foulée relâchée."),
            (360, "Beau rythme, tu tiens ton allure — FC bien maîtrisée 👊"),
            (720, "Mi-séance, tu gères parfaitement. Garde ta cadence."),
            (1080, "Dernier bloc, c'est le moment — lâche tout dessus 🔥")
        ]
    }

    func start() {
        location.requestAuthorization()
        location.start()
        timerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { self.tick() }
            }
        }
    }

    private func tick() {
        guard !isPaused else { return }
        elapsedSeconds += 1
        heartRate = 156 + Int(sin(elapsedSeconds / 40) * 6) + Int.random(in: -2...3)
        let t = Int(elapsedSeconds)
        for (threshold, message) in cues where t >= threshold && !firedCueTimestamps.contains(threshold) {
            firedCueTimestamps.insert(threshold)
            showCue(message)
        }
    }

    private func showCue(_ message: String) {
        coachCueClearTask?.cancel()
        coachCue = message
        coachCueClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.coachCue = nil }
        }
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused { location.stop() } else { location.start() }
    }

    /// Stops tracking and produces a `RunRecord`. Caller (AppState) inserts it into SwiftData.
    func stop() -> RunRecord {
        timerTask?.cancel()
        location.stop()
        let record = AdaptivePlanEngine.buildRunRecord(
            title: profile.todaySession.title,
            elapsedSeconds: elapsedSeconds,
            distanceKm: distanceKm,
            kcal: kcal,
            avgHeartRate: heartRate
        )
        let endedAt = Date()
        Task { try? await healthKit.saveRun(start: startedAt, end: endedAt, distanceKm: record.distanceKm, kcal: Double(record.kcal)) }
        return record
    }
}
