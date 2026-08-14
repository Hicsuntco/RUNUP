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
    private var endedAt = Date()

    /// La séance en cours, FIGÉE au démarrage de la course.
    ///
    /// Le modèle relisait `profile.todaySession` à dix endroits — dont la construction du
    /// `RunRecord` à l'arrêt et la machine à segments qui tourne à chaque seconde. Or
    /// l'observateur `.NSCalendarDayChanged` régénère cette séance en plein milieu d'une course
    /// à cheval sur minuit, et le passage dimanche → lundi régénère la semaine entière. Une
    /// course partie à 23h50 se terminait donc sous le nom de la séance du LENDEMAIN — voire
    /// « Repos » si le lendemain est un jour off — et un fractionné pouvait basculer en retour au
    /// calme si la nouvelle séance déclarait moins de répétitions.
    ///
    /// Une copie de valeur suffit : `WorkoutSession` est une `struct`, donc ce qui est capturé ici
    /// ne peut plus être modifié sous les pieds de la course.
    private var session: WorkoutSession = AdaptivePlanEngine.restSession
    /// Wall-clock pause bookkeeping: elapsed = now - startedAt - accumulated pauses. The old
    /// `elapsedSeconds += 1` per `Task.sleep(1s)` iteration systematically undercounted (sleep is
    /// "at least 1s", plus scheduling gaps) — minutes of drift over a long run, corrupting pace
    /// and splits.
    private var accumulatedPauseSeconds: Double = 0
    private var pauseBeganAt: Date?
    private var lastActivityPush = Date.distantPast
    private var lastSnapshotWrite = Date.distantPast
    private static let snapshotIntervalSeconds: Double = 10

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
    /// Auto-pause relies entirely on `CLLocation.speed`, which stays ~0 with no real GPS
    /// displacement (treadmill, indoor track, a bad urban-canyon fix) — without this, she'd have
    /// to manually tap play every ~10s for the whole run since the auto-resume condition can
    /// never fire. Tracks consecutive auto-pause cycles that gained no real distance; after a
    /// few in a row this session's auto-pause turns itself off (her persisted setting is
    /// untouched) so the run stops livelocking.
    private var autoPauseCyclesWithNoDistance = 0
    private var autoPauseCycleStartDistanceKm: Double = 0
    private var runtimeAutoPauseDisabled = false

    /// Real-time pace-zone alerts: a rolling window (real distance covered over the last
    /// `paceWindowSeconds`) compared against the session's target pace — reacts to her CURRENT
    /// effort, unlike the whole-run average `paceLabel` shows, which barely moves late in a run.
    private var paceWindowStartDistanceKm: Double = 0
    private var paceWindowStartElapsed: Double = 0
    private var lastPaceAlertAtElapsed: Double = -.infinity
    private static let paceWindowSeconds: Double = 30
    private static let paceAlertMinElapsedSeconds: Double = 180
    private static let paceAlertCooldownSeconds: Double = 90
    /// A real coaching tolerance, not a hair-trigger — normal stride-to-stride pace noise
    /// shouldn't nag her every 30 seconds.
    private static let paceAlertToleranceSecPerKm: Double = 20
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

    /// Real guided execution for a structured session ("5 × 500 m") — warmup → each rep (ends the
    /// moment real GPS distance covers `repKm` since the rep began, not a guessed flat 1.2 km
    /// chunk the old approximation used) → a fixed recovery jog → the next rep → cooldown after
    /// the last one. Nil for a continuous session (footing/tempo/sortie longue — nothing to
    /// segment) or when the title doesn't parse into a real structure.
    enum IntervalSegment: Equatable {
        case warmup
        case rep(Int)
        case recovery(Int)
        case cooldown
    }
    private(set) var currentSegment: IntervalSegment?
    private var segmentStartDistanceKm: Double = 0
    private var segmentStartElapsed: Double = 0
    /// A real archetype always states its own warmup as "10-15′" (see
    /// `SessionDetailSheet.steps`) — 8 min lands inside that range without eating too far into
    /// the actual work reps on a shorter session.
    private static let warmupSeconds: Double = 8 * 60
    /// A coaching default (typical easy-jog recovery between track reps), not a measurement —
    /// same spirit as the app's other pace-zone heuristics (`PaceModel`).
    private static let recoverySeconds: Double = 90

    /// Chip text for the Live overlay — nil when there's no real structure to narrate, in which
    /// case the UI shows nothing rather than a guess.
    var segmentLabel: String? {
        guard let currentSegment, let reps = session.intervalStructure?.reps else { return nil }
        switch currentSegment {
        case .warmup: return "ÉCHAUFFEMENT"
        case .rep(let n): return "RÉP. \(n)/\(reps)"
        case .recovery: return "RÉCUPÉRATION"
        case .cooldown: return "RETOUR AU CALME"
        }
    }
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
        let targetPace = session.pace
        // Cues match what the session actually is — the old fixed set said "Premier 800 : vise X"
        // on continuous footings (no 800s exist there) and claimed "FC bien maîtrisée" with no
        // real heart-rate reading behind it, the exact kind of fabricated claim the rest of the
        // app already scrubbed out.
        if session.isIntervalSession {
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
        // La séance est capturée ICI, une fois pour toutes : c'est le seul instant où
        // `profile.todaySession` désigne à coup sûr la séance que la coureuse a sous les yeux.
        // Tout ce qui la relirait plus tard lirait potentiellement celle du lendemain.
        session = profile.todaySession
        // A real structure takes over segment-by-segment guidance from the flat scripted `cues`
        // above (see `tick()`) — only when the title actually parses into reps, so a session
        // still gets narrated even if it happens not to.
        if session.intervalStructure != nil {
            currentSegment = .warmup
        }
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
        persistSnapshotIfDue()
        let t = Int(elapsedSeconds)
        // Only for a continuous session (currentSegment stays nil the whole run) — a real
        // structure is narrated by `advanceIntervalSegmentIfNeeded()` below instead, with cues
        // tied to the ACTUAL rep boundaries rather than fixed timestamps that drift the moment
        // she runs faster or slower than the archetype assumed.
        if currentSegment == nil {
            for (threshold, message) in cues where t >= threshold && !firedCueTimestamps.contains(threshold) {
                firedCueTimestamps.insert(threshold)
                showCue(message)
            }
        } else {
            advanceIntervalSegmentIfNeeded()
        }
        checkPaceAlert()
        if profile.autoPauseEnabled && !runtimeAutoPauseDisabled {
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

    /// Checks the CURRENT segment's real completion condition (distance for a rep, elapsed time
    /// for warmup/recovery) and transitions the moment it's met — driven by actual GPS/time
    /// progress, not a fixed schedule, so it stays accurate whether she runs the rep faster or
    /// slower than the archetype's target pace assumed.
    private func advanceIntervalSegmentIfNeeded() {
        guard let structure = session.intervalStructure, let segment = currentSegment else { return }
        switch segment {
        case .warmup:
            if elapsedSeconds - segmentStartElapsed >= Self.warmupSeconds {
                beginSegment(.rep(1), reps: structure.reps)
            }
        case .rep(let n):
            if distanceKm - segmentStartDistanceKm >= structure.repKm {
                beginSegment(n < structure.reps ? .recovery(n) : .cooldown, reps: structure.reps)
            }
        case .recovery(let n):
            if elapsedSeconds - segmentStartElapsed >= Self.recoverySeconds {
                beginSegment(.rep(n + 1), reps: structure.reps)
            }
        case .cooldown:
            break
        }
    }

    private func beginSegment(_ segment: IntervalSegment, reps: Int) {
        currentSegment = segment
        segmentStartDistanceKm = distanceKm
        segmentStartElapsed = elapsedSeconds
        Haptics.impact(.medium)
        let targetPace = session.pace
        switch segment {
        case .warmup:
            break
        case .rep(let n):
            showCue(n == 1
                ? "Échauffement terminé. Première répétition : vise \(targetPace)/km, foulée relâchée."
                : "Répétition \(n)/\(reps) — vise \(targetPace)/km.")
        case .recovery:
            showCue("Récupération — souffle, foulée relâchée.")
        case .cooldown:
            showCue("Dernière répétition faite, bien joué 🔥 Retour au calme.")
        }
    }

    /// Warmup/recovery/cooldown are deliberately off the target pace — only an actual rep (or a
    /// continuous session, which has no segments at all) is the effort worth nudging her on.
    private var isInTargetEffortSegment: Bool {
        guard let currentSegment else { return true }
        if case .rep = currentSegment { return true }
        return false
    }

    /// Compares real recent pace (distance actually covered in the last `paceWindowSeconds`)
    /// against the session's target and speaks a nudge when she's meaningfully off it — the
    /// audio equivalent of glancing at the pace number, for when she isn't looking at the screen.
    private func checkPaceAlert() {
        defer {
            if elapsedSeconds - paceWindowStartElapsed >= Self.paceWindowSeconds {
                paceWindowStartDistanceKm = distanceKm
                paceWindowStartElapsed = elapsedSeconds
            }
        }
        guard profile.paceAlertsEnabled,
              elapsedSeconds >= Self.paceAlertMinElapsedSeconds,
              isInTargetEffortSegment,
              elapsedSeconds - paceWindowStartElapsed >= Self.paceWindowSeconds,
              elapsedSeconds - lastPaceAlertAtElapsed >= Self.paceAlertCooldownSeconds,
              let targetSecPerKm = PaceModel.parseSecPerKm(session.pace)
        else { return }
        let windowDistanceKm = distanceKm - paceWindowStartDistanceKm
        guard windowDistanceKm > 0.05 else { return }
        let recentSecPerKm = (elapsedSeconds - paceWindowStartElapsed) / windowDistanceKm
        let delta = recentSecPerKm - targetSecPerKm
        guard abs(delta) > Self.paceAlertToleranceSecPerKm else { return }
        lastPaceAlertAtElapsed = elapsedSeconds
        voiceCoach?.announce(delta > 0 ? "Accélère un peu, tu es sous ton allure cible." : "Ralentis légèrement, tu vas plus vite que ton allure cible.")
    }

    /// A genuine stop held for `autoPauseDelaySeconds` (red light, water fountain) — pauses the
    /// same way a manual tap would (chrono/distance freeze) but keeps GPS running so `tick()` can
    /// notice her moving again and resume on its own, matching what Strava/Garmin call
    /// "auto pause".
    private func autoPause() {
        if distanceKm - autoPauseCycleStartDistanceKm < 0.01 {
            autoPauseCyclesWithNoDistance += 1
        } else {
            autoPauseCyclesWithNoDistance = 1
        }
        autoPauseCycleStartDistanceKm = distanceKm

        isAutoPaused = true
        isPaused = true
        pauseBeganAt = Date()
        location.pauseAccumulation()
        Haptics.impact(.light)
        if autoPauseCyclesWithNoDistance >= 3 {
            runtimeAutoPauseDisabled = true
            showCue("Pause auto désactivée pour cette course — le GPS ne détecte pas ton déplacement. Utilise le bouton pause toi-même.")
        } else {
            showCue("Pause automatique — reprends dès que tu es prête, ou continue à marcher pour repartir.")
        }
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
        let target = session.pace
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
        let attributes = RunActivityAttributes(sessionTitle: session.title, plannedDurationMinutes: session.durationMinutes)
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

    /// Stops tracking and produces a `RunRecord`. Caller (AppState) inserts it into SwiftData and
    /// only then calls `saveToHealthKit`, once its own "too short to count" guard has passed — the
    /// HealthKit write used to fire unconditionally from here, so a discarded pocket-tap run still
    /// landed a permanent phantom workout in Apple Health even though the app's own History
    /// correctly refused to keep it and told her nothing was recorded.
    func stop() -> RunRecord {
        endLiveActivity()
        timerTask?.cancel()
        heartRatePollTask?.cancel()
        voiceCoach?.stop()
        location.stop()
        let record = AdaptivePlanEngine.buildRunRecord(
            title: session.title,
            elapsedSeconds: elapsedSeconds,
            distanceKm: distanceKm,
            kcal: kcal,
            // 0, same as a manually-logged run — HistoryView already knows to hide the FC line
            // rather than show a fake number when there's no real reading behind it.
            avgHeartRate: heartRate ?? 0,
            elevationGainM: Int(location.elevationGainMeters.rounded()),
            realSplitSeconds: splitSecondsPerKm,
            route: zip(location.route, location.routeAltitudes).map { coord, altitude in
                RunRecord.RoutePoint(lat: coord.latitude, lng: coord.longitude, altitude: altitude)
            }
        )
        endedAt = Date()
        // La course a une fin explicite : l'instantané n'a plus rien à récupérer, et le laisser
        // ferait proposer cette même course au prochain lancement.
        LiveRunSnapshotStore.clear()
        return record
    }

    /// Écrit l'état courant sur disque, au plus une fois toutes les dix secondes.
    ///
    /// C'est le compromis qui compte ici : à dix secondes, une app tuée ne perd au pire que dix
    /// secondes de course et quelques dizaines de mètres — négligeable au regard d'une sortie
    /// entière — tandis qu'écrire à chaque seconde ferait une centaine d'écritures disque par
    /// sortie courte, sur un chemin déjà tenu pour son coût en batterie.
    private func persistSnapshotIfDue() {
        guard Date().timeIntervalSince(lastSnapshotWrite) >= Self.snapshotIntervalSeconds else { return }
        lastSnapshotWrite = Date()
        LiveRunSnapshotStore.save(
            LiveRunSnapshot(
                startedAt: startedAt,
                updatedAt: Date(),
                accumulatedPauseSeconds: accumulatedPauseSeconds,
                elapsedSeconds: elapsedSeconds,
                distanceMeters: location.distanceMeters,
                elevationGainMeters: location.elevationGainMeters,
                splitSecondsPerKm: splitSecondsPerKm,
                sessionTitle: session.title,
                route: zip(location.route, location.routeAltitudes).map { coord, altitude in
                    RunRecord.RoutePoint(lat: coord.latitude, lng: coord.longitude, altitude: altitude)
                }
            )
        )
    }

    /// Writes the run to Apple Health — call only once the caller has actually decided to keep the
    /// run (see `stop()`'s doc comment). `startedAt`/`endedAt` are moving-time bounds (pauses
    /// excluded via `duration`) — start/end alone would tell Santé a 30-min run with a 15-min
    /// coffee pause was a 45-min workout.
    func saveToHealthKit(_ record: RunRecord) {
        Task { try? await healthKit.saveRun(start: startedAt, end: endedAt, duration: Double(record.durationSeconds), distanceKm: record.distanceKm, kcal: Double(record.kcal)) }
    }
}
