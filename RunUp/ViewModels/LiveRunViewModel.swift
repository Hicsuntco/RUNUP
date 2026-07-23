import Foundation
import Observation
import ActivityKit

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
    /// Nil until a real, recent (last 90s) HealthKit sample comes in — no Watch/HR strap paired
    /// or streaming means this genuinely has no live reading, which is different from "0 bpm" and
    /// shouldn't be displayed as a number at all. Was previously a fabricated sine-wave formula
    /// dressed up as a live measurement; polled for real via `pollHeartRate()` instead.
    private(set) var heartRate: Int?
    private(set) var coachCue: String?

    private var timerTask: Task<Void, Never>?
    private var heartRatePollTask: Task<Void, Never>?
    private var firedCueTimestamps: Set<Int> = []
    private var coachCueClearTask: Task<Void, Never>?

    /// Real elapsed time for each completed km, recorded the instant real GPS distance crosses a
    /// whole-km boundary — replaces the formula-shaped fake splits `buildRunRecord` used to
    /// generate (`secPerKm - 8 + i*3`, the same curve every single run regardless of how the
    /// runner actually paced it).
    private(set) var splitSecondsPerKm: [Double] = []
    private var lastSplitKm = 0
    private var lastSplitElapsedSeconds: Double = 0

    private let cues: [(Int, String)]

    /// Real hands-free voice coaching (tap the mic, ask a question out loud, hear a real spoken
    /// reply) — nil until `start()` sets it, since its live-context closure needs a fully
    /// initialized `self` to capture (weakly), which the `init` body constructing `self` can't
    /// safely provide yet.
    private(set) var voiceCoach: VoiceCoachController?

    /// Nil whenever Live Activities are off system-wide (Settings toggle) or `request` throws —
    /// every call site below just no-ops on a live run tracked with no on-screen indicator at all,
    /// the same as before this existed.
    private var liveActivity: Activity<RunActivityAttributes>?

    var distanceKm: Double { location.distanceMeters / 1000 }
    var isSignalUnstable: Bool { location.isSignalUnstable }
    /// Only meaningful for the archetypes actually structured as reps (see
    /// `WorkoutSession.isIntervalSession`) — a continuous footing/tempo/sortie longue has no
    /// "interval" to be on. Still an approximation (flat 1.2km chunks, not real lap detection —
    /// no per-km split tracking exists), but no longer shown on session types it doesn't apply to.
    var isIntervalSession: Bool { profile.todaySession.isIntervalSession }
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
        if voiceCoach == nil {
            voiceCoach = VoiceCoachController(profile: profile) { [weak self] in
                self?.liveVoiceContext() ?? ""
            }
        }
        startLiveActivity()
        timerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { self.tick() }
            }
        }
        heartRatePollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pollHeartRate()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func tick() {
        guard !isPaused else { return }
        elapsedSeconds += 1
        let currentKm = Int(distanceKm)
        if currentKm > lastSplitKm {
            splitSecondsPerKm.append(elapsedSeconds - lastSplitElapsedSeconds)
            lastSplitElapsedSeconds = elapsedSeconds
            lastSplitKm = currentKm
            // The runner isn't looking at the screen mid-run — a buzz at each completed km is how
            // Nike Run Club/Strava mark the boundary, and it's the one live moment worth physical
            // feedback (the voice cues cover the rest).
            Haptics.impact(.medium)
        }
        let t = Int(elapsedSeconds)
        for (threshold, message) in cues where t >= threshold && !firedCueTimestamps.contains(threshold) {
            firedCueTimestamps.insert(threshold)
            showCue(message)
        }
        // Every 5s, not every tick — ActivityKit updates are meant to be occasional, not a
        // per-second stream, and the Lock Screen/Dynamic Island don't need second-level precision.
        if t % 5 == 0 { updateLiveActivity() }
    }

    /// Polls HealthKit for a genuinely recent heart-rate sample every 5s — separate from `tick()`
    /// (which runs every second) since there's no reason to hit HealthKit that often, and a real
    /// sample doesn't update that fast anyway. Stays `nil` (not a fabricated number) whenever
    /// nothing recent is available — no paired Watch/HR strap streaming into HealthKit, most
    /// simulators, or HealthKit access never granted.
    private func pollHeartRate() async {
        guard !isPaused else { return }
        if let bpm = await healthKit.latestHeartRate() {
            await MainActor.run { self.heartRate = Int(bpm.rounded()) }
        }
    }

    /// Real, current run stats handed to `VoiceCoachController` at the moment a voice question is
    /// sent — not the profile-level context `CoachService.systemPrompt` already builds, since
    /// that has no idea a run is even in progress.
    private func liveVoiceContext() -> String {
        let target = profile.todaySession.pace
        return "Distance parcourue jusqu'ici : \(String(format: "%.2f", distanceKm)) km. Allure actuelle : \(paceLabel) /km (allure cible du jour : \(target) /km). Temps écoulé : \(PaceModel.formatDuration(elapsedSeconds))."
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
        updateLiveActivity()
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RunActivityAttributes(sessionTitle: profile.todaySession.title)
        let state = RunActivityAttributes.ContentState(distanceKm: 0, elapsedSeconds: 0, paceLabel: "--:--", isPaused: false)
        liveActivity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil)
    }

    private func updateLiveActivity() {
        guard let liveActivity else { return }
        let state = RunActivityAttributes.ContentState(distanceKm: distanceKm, elapsedSeconds: elapsedSeconds, paceLabel: paceLabel, isPaused: isPaused)
        Task { await liveActivity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// Ends the Live Activity with the run's final tally still showing for a few seconds
    /// (`.default` dismissal) rather than yanking it off the Lock Screen the instant she stops —
    /// call from `stop()`, before `location`/timers are torn down so `distanceKm`/`elapsedSeconds`
    /// still read the real final values.
    private func endLiveActivity() {
        guard let liveActivity else { return }
        let finalState = RunActivityAttributes.ContentState(distanceKm: distanceKm, elapsedSeconds: elapsedSeconds, paceLabel: paceLabel, isPaused: true)
        Task { await liveActivity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .default) }
        self.liveActivity = nil
    }

    /// Stops tracking and produces a `RunRecord`. Caller (AppState) inserts it into SwiftData.
    func stop() -> RunRecord {
        endLiveActivity()
        timerTask?.cancel()
        heartRatePollTask?.cancel()
        voiceCoach?.stop()
        location.stop()
        let record = AdaptivePlanEngine.buildRunRecord(
            title: profile.todaySession.title,
            elapsedSeconds: elapsedSeconds,
            distanceKm: distanceKm,
            kcal: kcal,
            // 0, same as a manually-logged run — HistoryView already knows to hide the FC line
            // rather than show a fake number when there's no real reading behind it.
            avgHeartRate: heartRate ?? 0,
            elevationGainM: Int(location.elevationGainMeters.rounded()),
            realSplitSeconds: splitSecondsPerKm,
            route: location.route.map { RunRecord.RoutePoint(lat: $0.latitude, lng: $0.longitude) }
        )
        let endedAt = Date()
        Task { try? await healthKit.saveRun(start: startedAt, end: endedAt, distanceKm: record.distanceKm, kcal: Double(record.kcal)) }
        return record
    }
}
