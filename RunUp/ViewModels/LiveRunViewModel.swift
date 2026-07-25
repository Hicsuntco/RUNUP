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
    /// Set in `start()`, not at init — the view model can exist briefly before the run begins,
    /// and this date anchors both the wall-clock elapsed math and the HealthKit workout.
    private var startedAt = Date()
    /// Wall-clock pause bookkeeping: elapsed = now - startedAt - accumulated pauses. The old
    /// `elapsedSeconds += 1` per `Task.sleep(1s)` iteration systematically undercounted (sleep is
    /// "at least 1s", plus scheduling gaps) — minutes of drift over a long run, corrupting pace
    /// and splits.
    private var accumulatedPauseSeconds: Double = 0
    private var pauseBeganAt: Date?
    private var lastActivityPush = Date.distantPast

    private(set) var elapsedSeconds: Double = 0
    private(set) var isPaused = false
    /// True only when the CURRENT pause was system-detected (see `tick()`), not tapped manually —
    /// distinguishes "resume automatically the moment she starts moving again" from a deliberate
    /// manual pause, which should only ever end on an explicit tap.
    private(set) var isAutoPaused = false
    /// Consecutive ticks (seconds) below `autoPauseSpeedThreshold` while actively running — reset
    /// the moment speed picks back up, or on any resume.
    private var stationarySeconds: Double = 0
    /// ~2.2 km/h — well under even a very slow walking pace, so normal jog-walk intervals or a
    /// red light glance don't trigger it; only a genuine stop (red light, water fountain, tying a
    /// shoelace) does, and only after it's held for `autoPauseDelaySeconds`.
    private static let autoPauseSpeedThreshold: Double = 0.6
    private static let autoPauseDelaySeconds: Double = 10
    /// Deliberately higher than the pause threshold (hysteresis) — resuming right at the same
    /// speed that triggered the pause would flicker pause/resume on every small fluctuation.
    private static let autoResumeSpeedThreshold: Double = 1.3
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
    /// The session's real rep count, parsed from its own title ("5 × 500 m" → 5) — nil when the
    /// title doesn't declare one, in which case the live counter chip is hidden entirely rather
    /// than shown over a denominator that was previously a hardcoded 6 regardless of the session.
    var intervalRepCount: Int? {
        guard let range = profile.todaySession.title.range(of: #"\d+\s*×"#, options: .regularExpression) else { return nil }
        return Int(profile.todaySession.title[range].filter(\.isNumber))
    }
    var intervalIndex: Int { min(intervalRepCount ?? 6, 1 + Int(distanceKm / 1.2)) }
    // Same 62 kcal/km estimate as `markTodaySessionDone` — two different constants for the same
    // approximation meant a GPS run and a manual run disagreed on identical distances.
    var kcal: Double { distanceKm * 62 }

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
        // Cues match what the session actually is — the old fixed set said "Premier 800 : vise X"
        // on continuous footings (no 800s exist there) and claimed "FC bien maîtrisée" with no
        // real heart-rate reading behind it, the exact kind of fabricated claim the rest of the
        // app already scrubbed out.
        if profile.todaySession.isIntervalSession {
            cues = [
                (6, "C'est parti \(name). Échauffement tranquille, reste en Z2."),
                (120, "Fin d'échauffement. Première répétition : vise \(targetPace), foulée relâchée."),
                (360, "Tiens ton allure sur chaque répétition, récupère bien entre les blocs 👊"),
                (720, "Mi-séance, tu gères. Garde ta cadence sur les prochaines répétitions."),
                (1080, "Dernier bloc, c'est le moment — lâche tout dessus 🔥")
            ]
        } else {
            cues = [
                (6, "C'est parti \(name). Départ tranquille, laisse le corps se mettre en route."),
                (120, "Trouve ton rythme de croisière : vise \(targetPace), foulée relâchée."),
                (360, "Beau rythme, reste régulière — c'est la constance qui paie 👊"),
                (720, "Mi-séance, tu gères parfaitement. Garde ta cadence."),
                (1080, "Dernière partie — finis proprement, sans t'arracher 🔥")
            ]
        }
    }

    func start() {
        startedAt = Date()
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
        guard !isPaused else {
            // A manual pause (isAutoPaused == false) only ever ends on an explicit tap — this
            // only watches for movement resuming while WE'RE the one who paused it.
            if isAutoPaused, location.currentSpeedMetersPerSecond > Self.autoResumeSpeedThreshold {
                resumeFromAutoPause()
            }
            return
        }
        elapsedSeconds = max(0, Date().timeIntervalSince(startedAt) - accumulatedPauseSeconds)
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
        if profile.autoPauseEnabled {
            if location.currentSpeedMetersPerSecond < Self.autoPauseSpeedThreshold {
                stationarySeconds += 1
                if stationarySeconds >= Self.autoPauseDelaySeconds {
                    autoPause()
                }
            } else {
                stationarySeconds = 0
            }
        }
        // Every 5s, not every tick — ActivityKit updates are meant to be occasional, not a
        // per-second stream (the chrono ticks itself via `timerReference`; these pushes only
        // refresh distance/pace).
        if Date().timeIntervalSince(lastActivityPush) >= 5 {
            lastActivityPush = Date()
            updateLiveActivity()
        }
    }

    /// A genuine stop held for `autoPauseDelaySeconds` (red light, water fountain) — pauses the
    /// same way a manual tap would (chrono/distance freeze) but keeps GPS running so `tick()` can
    /// notice her moving again and resume on its own, matching what Strava/Garmin call
    /// "auto pause".
    private func autoPause() {
        isAutoPaused = true
        isPaused = true
        pauseBeganAt = Date()
        location.pauseAccumulation()
        Haptics.impact(.light)
        showCue("Pause automatique — reprends dès que tu es prête, ou continue à marcher pour repartir.")
        updateLiveActivity()
    }

    private func resumeFromAutoPause() {
        isPaused = false
        isAutoPaused = false
        stationarySeconds = 0
        if let pauseBeganAt {
            accumulatedPauseSeconds += Date().timeIntervalSince(pauseBeganAt)
            self.pauseBeganAt = nil
        }
        location.resume()
        Haptics.impact(.light)
        updateLiveActivity()
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
        return "Distance parcourue jusqu'ici : \(String(format: "%.2f", locale: Locale(identifier: "fr_FR"), distanceKm)) km. Allure actuelle : \(paceLabel) /km (allure cible du jour : \(target) /km). Temps écoulé : \(PaceModel.formatDuration(elapsedSeconds))."
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
        if isPaused {
            // A deliberate tap — isAutoPaused stays false, so this only ever un-pauses on another
            // explicit tap, never on movement alone.
            pauseBeganAt = Date()
            location.stop()
        } else {
            if let pauseBeganAt {
                accumulatedPauseSeconds += Date().timeIntervalSince(pauseBeganAt)
                self.pauseBeganAt = nil
            }
            // Covers resuming a manual pause AND tapping resume while auto-paused — either way
            // this is now a real, un-paused run.
            isAutoPaused = false
            stationarySeconds = 0
            // resume(), never start() — start() zeroes route/distance, which is exactly what used
            // to wipe a paused run back to 0,00 km at the traffic light.
            location.resume()
        }
        updateLiveActivity()
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RunActivityAttributes(sessionTitle: profile.todaySession.title)
        let state = RunActivityAttributes.ContentState(distanceKm: 0, elapsedSeconds: 0, paceLabel: "--:--", isPaused: false, timerReference: Date())
        liveActivity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: .now + 60), pushType: nil)
    }

    private func updateLiveActivity() {
        guard let liveActivity else { return }
        let state = RunActivityAttributes.ContentState(
            distanceKm: distanceKm,
            elapsedSeconds: elapsedSeconds,
            paceLabel: paceLabel,
            isPaused: isPaused,
            timerReference: isPaused ? nil : Date(timeIntervalSinceNow: -elapsedSeconds)
        )
        // staleDate dims the card if updates stop arriving (app killed mid-run) instead of
        // leaving a frozen "in-progress" run on the Lock Screen for hours.
        Task { await liveActivity.update(ActivityContent(state: state, staleDate: .now + 60)) }
    }

    /// Ends the Live Activity with the run's final tally kept briefly on the Lock Screen (30s,
    /// explicitly — `.default` actually leaves it for up to 4 hours), marked `isEnded` so the
    /// widget shows a checkmark, not a pause icon implying the run is still going. Call from
    /// `stop()`, before `location`/timers are torn down so the final values still read true.
    private func endLiveActivity() {
        guard let liveActivity else { return }
        let finalState = RunActivityAttributes.ContentState(distanceKm: distanceKm, elapsedSeconds: elapsedSeconds, paceLabel: paceLabel, isPaused: false, timerReference: nil, isEnded: true)
        Task { await liveActivity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 30)) }
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
        // duration = real moving time (pauses excluded) — start/end alone would tell Santé a
        // 30-min run with a 15-min coffee pause was a 45-min workout.
        Task { try? await healthKit.saveRun(start: startedAt, end: endedAt, duration: elapsedSeconds, distanceKm: record.distanceKm, kcal: Double(record.kcal)) }
        return record
    }
}
