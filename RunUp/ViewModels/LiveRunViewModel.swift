import Foundation
import Observation
import ActivityKit

/// Drives the Live Run screen: real elapsed time + GPS distance (via `LocationService`), coach
/// voice cues at scripted timestamps, and real GPS-instability detection. Ported from the
/// `startRun`/timer logic in app.jsx, adapted to use real CoreLocation data instead of a
/// simulated tick (see architecture decision to use MapKit for the Live Run screen).
///
/// `@MainActor` : ce modèle possède l'état que l'écran de course lit à chaque image, et il écrit
/// des objets SwiftData (le `RunRecord` produit par `stop()`). Ses trois tâches de fond — le
/// chrono à la seconde, le relevé de fréquence cardiaque, l'effacement des messages du coach —
/// capturaient `self` dans du code concurrent sans qu'aucune isolation ne le garantisse.
@MainActor
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
    /// Seuils, armement et compte des secondes immobiles : voir `AutoPause`, où la règle vit
    /// seule et sous test.
    private var autoPauseState = AutoPause.State()
    /// Le cas qui reste après tout ce que `AutoPause` règle : le tapis de course et la piste
    /// couverte, où l'appareil ne se déplace pas du tout. La vitesse y est réellement nulle et
    /// l'éloignement aussi, donc les deux preuves de reprise disent « toujours à l'arrêt », et
    /// elle devrait taper « reprendre » toutes les dix secondes pendant une heure. Au bout de
    /// trois cycles de pause sans le moindre mètre gagné, la pause automatique se coupe pour
    /// cette course seulement — son réglage enregistré n'est pas touché.
    ///
    /// Ce garde-fou était inatteignable avant : `autoPause()` n'est appelée que depuis la branche
    /// NON pausée de `tick()`, donc une pause dont on ne pouvait plus sortir ne comptait jamais
    /// de deuxième cycle. La reprise par éloignement est ce qui le rend enfin accessible.
    private var autoPauseCyclesWithNoDistance = 0
    private var autoPauseCycleStartDistanceKm: Double = 0
    private var runtimeAutoPauseDisabled = false

    /// L'allure récente — la fenêtre glissante de `PaceWindow`, où vit la règle. Elle alimente
    /// désormais DEUX choses au lieu d'une : la consigne vocale, comme avant, et le chiffre
    /// affiché sous ALLURE, qui montrait jusqu'ici la moyenne de toute la course et pouvait donc
    /// rester immobile pendant que le coach disait « accélère ».
    private var paceWindow = PaceWindow.State()
    private var lastPaceAlertAtElapsed: Double = -.infinity
    private static let paceAlertMinElapsedSeconds: Double = 180
    private static let paceAlertCooldownSeconds: Double = 90
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

    /// Ce que l'écran doit dire de la localisation. Il n'affichait qu'un seul cas — « signal
    /// instable » — et se taisait dans les deux qui comptent : pendant l'accrochage, où une
    /// distance figée à 0,00 est normale, et quand l'autorisation est refusée, où elle ne se
    /// débloquera jamais toute seule. Les deux se ressemblaient trait pour trait à l'écran, et
    /// ressemblaient toutes deux à une app cassée.
    enum GPSState { case denied, searching, unstable, ok }
    var gpsState: GPSState {
        switch location.authorizationStatus {
        case .denied, .restricted: return .denied
        default: break
        }
        if !location.hasFix { return .searching }
        return location.isSignalUnstable ? .unstable : .ok
    }

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
        // Les quatre libellés étaient des littéraux français nus. Les clés existent pourtant dans
        // le catalogue depuis toujours : c'est `String(localized:)` qui manquait, et rien ne le
        // signalait — la pastille était en 12 pt dans un coin. Elle est maintenant le surtitre du
        // bloc de consigne, au centre de l'écran de course, et un « ÉCHAUFFEMENT » sur un
        // téléphone anglais s'y verrait tout de suite.
        switch currentSegment {
        case .warmup: return String(localized: "ÉCHAUFFEMENT")
        case .rep(let n): return String(localized: "RÉP. \(n)/\(reps)")
        case .recovery: return String(localized: "RÉCUPÉRATION")
        case .cooldown: return String(localized: "RETOUR AU CALME")
        }
    }
    /// L'allure cible du jour est-elle la consigne de CET instant ?
    ///
    /// Non pendant l'échauffement, la récupération et le retour au calme — et l'écran de course
    /// l'ignorait : il affichait « ÉCHAUFFEMENT » en surtitre et, juste en dessous, l'allure des
    /// répétitions en gros et en accent, c'est-à-dire la consigne de courir son échauffement à
    /// l'allure de son travail. La donnée existait déjà ici, à l'usage de l'alerte vocale, qui
    /// se tait sur ces segments pour exactement cette raison.
    var isTargetEffortNow: Bool { isInTargetEffortSegment }

    /// Où elle en est DANS le segment en cours, de 0 à 1 — `nil` quand la question n'a pas de
    /// réponse.
    ///
    /// L'écran annonçait « RÉP. 3/5 » et rien d'autre : la coureuse savait quelle répétition elle
    /// courait, jamais s'il lui restait cinquante mètres ou quatre cents. C'est pourtant la seule
    /// information que la machine à segments possède déjà et ne disait pas — elle connaît la
    /// condition exacte de fin de chaque segment, puisque c'est elle qui la surveille à chaque
    /// seconde dans `advanceIntervalSegmentIfNeeded()`.
    ///
    /// Le retour au calme vaut `nil` : il n'a pas de longueur prévue, il s'arrête quand elle
    /// arrête. Une barre qui se remplirait vers une fin inventée vaudrait moins que rien.
    var segmentProgress: Double? {
        guard let currentSegment, let structure = session.intervalStructure else { return nil }
        switch currentSegment {
        case .warmup:
            return Self.fraction(elapsedSeconds - segmentStartElapsed, of: Self.warmupSeconds)
        case .rep:
            return Self.fraction(distanceKm - segmentStartDistanceKm, of: structure.repKm)
        case .recovery:
            return Self.fraction(elapsedSeconds - segmentStartElapsed, of: Self.recoverySeconds)
        case .cooldown:
            return nil
        }
    }

    /// Ce qu'il reste du segment, dans l'unité dont il dépend vraiment : des mètres pour une
    /// répétition (qui se termine sur la distance), un temps pour l'échauffement et la
    /// récupération (qui se terminent sur le chrono). Afficher un temps restant sur une
    /// répétition serait une prédiction, pas une mesure.
    var segmentRemainingLabel: String? {
        guard let currentSegment, let structure = session.intervalStructure else { return nil }
        switch currentSegment {
        case .warmup:
            return Self.remainingTime(Self.warmupSeconds - (elapsedSeconds - segmentStartElapsed))
        case .rep:
            let metres = (structure.repKm - (distanceKm - segmentStartDistanceKm)) * 1000
            return String(localized: "\(max(0, Int(metres.rounded()))) m")
        case .recovery:
            return Self.remainingTime(Self.recoverySeconds - (elapsedSeconds - segmentStartElapsed))
        case .cooldown:
            return nil
        }
    }

    private static func fraction(_ done: Double, of total: Double) -> Double? {
        guard total > 0 else { return nil }
        return min(max(done / total, 0), 1)
    }

    private static func remainingTime(_ seconds: Double) -> String {
        PaceModel.formatDuration(max(0, seconds.rounded()))
    }

    // Voir `Calories` : la constante était écrite ici, dans `AddRunSheet` et dans `AppState`,
    // chacune avec un commentaire demandant aux deux autres de rester d'accord.
    var kcal: Double { Calories.estimate(distanceKm: distanceKm) }

    /// La moyenne de toute la sortie. Elle garde sa place là où elle veut dire quelque chose —
    /// le `RunRecord`, le récap, la Live Activity — mais plus sur l'écran de course.
    var paceLabel: String {
        guard distanceKm > 0.05 else { return "--:--" }
        let secPerKm = elapsedSeconds / distanceKm
        return PaceModel.paceText(secPerKm)
    }

    /// Ce que l'écran de course affiche sous ALLURE : l'allure des trente dernières secondes.
    ///
    /// Avant les dix premières secondes, la fenêtre ne dit rien et la moyenne de la course EST
    /// l'allure récente — on la montre donc, sans mentir. Après, les deux divergent et c'est la
    /// récente qui compte : c'est celle qu'elle peut corriger.
    var recentPaceLabel: String {
        guard let secPerKm = PaceWindow.secPerKm(paceWindow, minimumSeconds: PaceWindow.displayMinimumSeconds) else {
            return paceLabel
        }
        return PaceModel.paceText(secPerKm)
    }

    /// L'allure récente face à la cible du jour.
    ///
    /// `unknown` pendant l'échauffement, la récupération et le retour au calme : ces segments
    /// sont VOULUS hors allure cible (voir `isInTargetEffortSegment`), et faire passer le chiffre
    /// à l'ambre pendant un footing de récupération serait reprocher à la coureuse d'avoir suivi
    /// la consigne.
    var paceStanding: PaceWindow.Standing {
        guard isInTargetEffortSegment else { return .unknown }
        return PaceWindow.standing(
            secPerKm: PaceWindow.secPerKm(paceWindow, minimumSeconds: PaceWindow.displayMinimumSeconds),
            target: PaceModel.parseSecPerKm(session.pace)
        )
    }

    init(profile: UserProfile, healthKit: HealthKitService) {
        self.profile = profile
        self.healthKit = healthKit
        let name = profile.name
        // Une constante locale, PAS `self.session` : dans un initialiseur, lire une propriété de
        // `self` avant que toutes les propriétés stockées ne soient posées est interdit — et `cues`
        // ne l'est pas encore. La séance est affectée à `self.session` en fin d'`init`.
        let todaySession = profile.todaySession
        let targetPace = todaySession.pace
        // Cues match what the session actually is — the old fixed set said "Premier 800 : vise X"
        // on continuous footings (no 800s exist there) and claimed "FC bien maîtrisée" with no
        // real heart-rate reading behind it, the exact kind of fabricated claim the rest of the
        // app already scrubbed out.
        if todaySession.isIntervalSession {
            cues = [
                (6, String(localized: "C'est parti \(name). Échauffement tranquille, reste en Z2.")),
                (120, String(localized: "Fin d'échauffement. Première répétition : vise \(targetPace), foulée relâchée.")),
                (360, String(localized: "Tiens ton allure sur chaque répétition, récupère bien entre les blocs 👊")),
                (720, String(localized: "Mi-séance, tu gères. Garde ta cadence sur les prochaines répétitions.")),
                (1080, String(localized: "Dernier bloc, c'est le moment — lâche tout dessus 🔥"))
            ]
        } else {
            cues = [
                (6, String(localized: "C'est parti \(name). Départ tranquille, laisse le corps se mettre en route.")),
                (120, String(localized: "Trouve ton rythme de croisière : vise \(targetPace), foulée relâchée.")),
                (360, String(localized: "Beau rythme, reste régulière — c'est la constance qui paie 👊")),
                (720, String(localized: "Mi-séance, tu gères parfaitement. Garde ta cadence.")),
                (1080, String(localized: "Dernière partie — finis proprement, sans t'arracher 🔥"))
            ]
        }
        // Les consignes vocales ci-dessus viennent d'être construites à partir de cette séance :
        // la figer ici garantit qu'elles décrivent bien la course qui va démarrer, même si le
        // modèle est créé un instant avant `start()`.
        self.session = todaySession
    }

    func start() {
        startedAt = Date()
        paceWindow = PaceWindow.State()
        lastPaceAlertAtElapsed = -.infinity
        autoPauseState = AutoPause.State()
        autoPauseCyclesWithNoDistance = 0
        autoPauseCycleStartDistanceKm = 0
        runtimeAutoPauseDisabled = false
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
        // Les deux tâches héritent de l'isolation `@MainActor` : `tick()` et `pollHeartRate()`
        // s'exécutent donc sur le fil principal sans `MainActor.run` explicite. `weak self` est
        // relu à chaque tour plutôt que capturé fort pour la durée du sommeil, pour que le modèle
        // puisse être libéré dès que l'écran disparaît.
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
        heartRatePollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollHeartRate()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func tick() {
        guard !isPaused else {
            // A manual pause (isAutoPaused == false) only ever ends on an explicit tap — this
            // only watches for movement resuming while WE'RE the one who paused it.
            // Deux preuves indépendantes qu'elle est repartie, et une seule suffit : une vitesse
            // franche, ou un vrai éloignement du point d'arrêt. La seconde existe parce que la
            // première manque à l'appel exactement là où on en a besoin — à l'arrêt, sous un
            // immeuble, `CLLocation.speed` devient indisponible. Avec la vitesse seule, une pause
            // automatique prise dans ces conditions ne se levait plus jamais toute seule.
            if isAutoPaused, movementResumed {
                resumeFromAutoPause()
            }
            return
        }
        elapsedSeconds = max(0, Date().timeIntervalSince(startedAt) - accumulatedPauseSeconds)
        // Un échantillon par seconde de course. Les pauses ne sont pas échantillonnées — ce
        // `guard` plus haut rend la main — donc la fenêtre décrit bien trente secondes COURUES,
        // et une pause de cinq minutes au feu rouge ne vient pas y écraser l'allure.
        PaceWindow.record(&paceWindow, elapsed: elapsedSeconds, km: distanceKm)
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
        if AutoPause.tick(&autoPauseState,
                          speed: location.currentSpeedMetersPerSecond,
                          enabled: profile.autoPauseEnabled && !runtimeAutoPauseDisabled) {
            autoPause()
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

    /// Dit à voix haute ce que le chiffre à l'écran vient de montrer : l'allure récente s'est
    /// écartée de la cible — l'équivalent sonore du coup d'œil, pour les moments où elle ne
    /// regarde pas l'écran.
    ///
    /// La règle et la tolérance sont celles de `paceStanding` — la voix ne peut plus contredire
    /// l'écran sur le SENS de l'écart. Elle exige en revanche une fenêtre plus longue
    /// (`alertMinimumSeconds` contre `displayMinimumSeconds`) et garde son délai de
    /// quatre-vingt-dix secondes : un chiffre qu'on peut ignorer d'un coup d'œil coûte moins cher
    /// qu'une voix dans les oreilles. L'écran peut donc dire ACCÉLÈRE sans que le coach parle ;
    /// jamais l'inverse.
    private func checkPaceAlert() {
        guard profile.paceAlertsEnabled,
              elapsedSeconds >= Self.paceAlertMinElapsedSeconds,
              isInTargetEffortSegment,
              elapsedSeconds - lastPaceAlertAtElapsed >= Self.paceAlertCooldownSeconds
        else { return }
        let standing = PaceWindow.standing(
            secPerKm: PaceWindow.secPerKm(paceWindow, minimumSeconds: PaceWindow.alertMinimumSeconds),
            target: PaceModel.parseSecPerKm(session.pace)
        )
        switch standing {
        case .unknown, .onTarget:
            return
        case .tooSlow:
            lastPaceAlertAtElapsed = elapsedSeconds
            voiceCoach?.announce("Accélère un peu, tu es sous ton allure cible.")
        case .tooFast:
            lastPaceAlertAtElapsed = elapsedSeconds
            voiceCoach?.announce("Ralentis légèrement, tu vas plus vite que ton allure cible.")
        }
    }

    /// A genuine stop held for `AutoPause.delaySeconds` (red light, water fountain) — pauses the
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
            showCue(String(localized: "Pause auto désactivée pour cette course — le GPS ne détecte pas ton déplacement. Utilise le bouton pause toi-même."))
        } else {
            showCue("Pause automatique — reprends dès que tu es prête, ou continue à marcher pour repartir.")
        }
        updateLiveActivity()
    }

    /// Vraie reprise du mouvement, par l'une ou l'autre des deux mesures — voir `AutoPause`.
    private var movementResumed: Bool {
        AutoPause.shouldResume(speed: location.currentSpeedMetersPerSecond,
                               metersSincePause: location.metersSincePause)
    }

    private func resumeFromAutoPause() {
        isPaused = false
        isAutoPaused = false
        autoPauseState.stationarySeconds = 0
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
            self.heartRate = Int(bpm.rounded())
        }
    }

    /// Real, current run stats handed to `VoiceCoachController` at the moment a voice question is
    /// sent — not the profile-level context `CoachService.systemPrompt` already builds, since
    /// that has no idea a run is even in progress.
    private func liveVoiceContext() -> String {
        let target = session.pace
        return "Distance parcourue jusqu'ici : \(String(format: "%.2f", locale: Locale.current, distanceKm)) km. Allure actuelle : \(paceLabel) /km (allure cible du jour : \(target) /km). Temps écoulé : \(PaceModel.formatDuration(elapsedSeconds))."
    }

    private func showCue(_ message: String) {
        coachCueClearTask?.cancel()
        coachCue = message
        coachCueClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.coachCue = nil
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
            autoPauseState.stationarySeconds = 0
            // resume(), never start() — start() zeroes route/distance, which is exactly what used
            // to wipe a paused run back to 0,00 km at the traffic light.
            location.resume()
        }
        updateLiveActivity()
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RunActivityAttributes(sessionTitle: session.displayTitle, plannedDurationMinutes: session.durationMinutes)
        let state = RunActivityAttributes.ContentState(distanceKm: 0, elapsedSeconds: 0, paceLabel: "--:--", isPaused: false, timerReference: Date())
        liveActivity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: .now + 60), pushType: nil)
    }

    private func updateLiveActivity() {
        guard let liveActivity else { return }
        let state = RunActivityAttributes.ContentState(
            distanceKm: distanceKm,
            elapsedSeconds: elapsedSeconds,
            // L'allure RÉCENTE, la même que l'écran de course — pas la moyenne de la sortie.
            //
            // L'écran verrouillé se regarde en courant, exactement comme l'écran de l'app : y
            // montrer un autre chiffre que celui de l'app rejouerait, une surface plus loin, le
            // défaut qu'on vient de réparer. Le dernier état, lui, garde la moyenne — voir
            // `endLiveActivity` : une course finie se résume par son allure moyenne, et à cet
            // instant il n'y a plus de « récent ».
            paceLabel: recentPaceLabel,
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
            title: session.displayTitle,
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
            },
            // Le type de séance suit la course dans son relevé : `title` est du texte affiché,
            // donc traduit, et tout ce qui voudrait en déduire quelque chose (le badge fractionné
            // du club) doit lire ce champ-ci. Passé au constructeur, qui s'en sert aussi pour
            // refuser d'intituler une course « Repos ».
            sessionKind: session.kind
        )
        // DATÉE À SON DÉPART, PAS À SON ARRIVÉE. `buildRunRecord` laisse `date` à `.now`,
        // c'est-à-dire l'instant de ce `stop()`. Les trois autres façons de créer un relevé
        // rétrodatent déjà — la montre, la récupération d'app tuée, l'import Santé — et la course
        // GPS, le chemin principal de l'app, était la seule à ne pas le faire.
        //
        // Ce que ça cassait : une sortie partie dimanche 23 h 50 et arrêtée lundi 00 h 20 cochait
        // le LUNDI et laissait la séance du dimanche à faire pour toujours. Le moteur de plan
        // porte un long commentaire expliquant qu'il corrige ce cas — il le corrigeait sur une
        // date qui était déjà fausse. Même chose pour la série, le bilan hebdomadaire et les
        // badges « sortie matinale » / « sortie nocturne », tous calculés sur une heure de fin.
        record.date = startedAt
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
                sessionTitle: session.displayTitle,
                sessionKind: session.kind,
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
        Task { try? await healthKit.saveRun(record.discipline, start: startedAt, end: endedAt, duration: Double(record.durationSeconds), distanceKm: record.distanceKm, kcal: Double(record.kcal)) }
    }
}
