import Foundation
import SwiftData
import Observation
import WidgetKit
import ActivityKit

/// Central app store + router — mirrors the `store`/`ctx` object threaded through the
/// prototype via React context. Held once at the root and read via `@Environment(AppState.self)`.
///
/// `@MainActor` sur la classe entière, et non plus méthode par méthode. Cet objet n'existe que
/// pour être lu par SwiftUI : chacune de ses propriétés observables est rendue à l'écran, et il
/// possède des objets SwiftData (`profile`, `modelContext`) qui appartiennent au contexte du fil
/// principal. Les annotations éparpillées sur trois méthodes laissaient tout le reste — dont
/// `startRun()`, `endLiveRun()` et `toast()` — accessible depuis n'importe quel fil, ce que le
/// compilateur ne pouvait ni vérifier ni empêcher. C'est la même famille de défaut que
/// `ToastCenter`, `LiveRunViewModel` et `VoiceCoachController`, corrigée de la même façon.
///
/// Conséquence pratique : les rares appelants qui ne sont PAS sur le fil principal (les callbacks
/// `WCSessionDelegate` de `WatchSessionService`, l'observateur `NSCalendarDayChanged`) doivent
/// désormais sauter explicitement sur l'acteur principal — ce qu'ils faisaient déjà, mais par
/// convention plutôt que sous garantie du compilateur.
@MainActor
@Observable
final class AppState {
    let modelContext: ModelContext
    let healthKit = HealthKitService()
    let toastCenter = ToastCenter()
    let auth = AuthService()

    var profile: UserProfile
    var screen: AppScreen = .home
    /// Real activities queued in `ClubActivityOutbox` waiting to reach the server (a spotty
    /// connection at the exact moment a run finished, or the server briefly unreachable) — kept in
    /// sync by `ClubActivityOutbox` itself on every enqueue/success/retry so History can show a
    /// real "still syncing" banner instead of a run's XP/feed entry silently never arriving with
    /// no visible sign anything went wrong.
    var pendingActivityCount: Int = 0
    /// Consumed once by `SocialView.onAppear` then reset — lets `ProfileView`'s "Amis" card land
    /// directly on the Friends segment instead of `SocialView`'s own default ("Mon club"), without
    /// giving `mode` a second, competing source of truth (`@AppStorage`/a `UserProfile` field)
    /// for what's a one-shot navigation intent, not a real persisted preference.
    var openFriendsTabOnNextVisit = false
    /// Même mécanique que ci-dessus pour la carte « Itinéraires » du Profil : une intention de
    /// navigation à usage unique, pas une préférence à persister.
    var openRoutesTabOnNextVisit = false
    /// Phone↔watch bridge — receives runs finished on the wrist, mirrors today's session out.
    /// Optional only because it needs `self` (created at the end of `init`); never nil after.
    @ObservationIgnored private(set) var watchSession: WatchSessionService?
    @ObservationIgnored private var lastPublishedSnapshot: DailyGoalsSnapshot?

    // Sheets
    var sessionDetailPresented = false
    var moveSessionPresented = false
    var programSettingsPresented = false
    var notificationsPresented = false
    /// The same "nouvel objectif" wizard `ChoiceView` presents at the end of a program — hoisted
    /// here so Profil's "Refaire un programme" can open it directly too, without going through
    /// recovery/choice first. Replaces the old "Refaire l'onboarding" action, which re-asked her
    /// name/sexe/date de naissance/blessures — everything, not just the goal — to get a new plan.
    var newGoalWizardPresented = false
    /// Runs waiting for their RPE debrief — a "FAIT" tap (`markTodaySessionDone`) or a run
    /// delivered from the Watch (`WatchSessionService.handleCompletedRun`) appends here rather
    /// than overwriting a single slot. Two runs finishing in quick succession (e.g. the Watch
    /// queuing several while the phone was out of range, then delivering them together on
    /// reconnect) used to silently drop the first one's RPE/streak/XP credit forever — the second
    /// arrival just overwrote the one slot before its sheet was ever shown. `RootTabView` presents
    /// `pendingDebriefs.first` and pops it once that debrief is dismissed, so a second arrival
    /// while one is already showing queues behind it instead of replacing it.
    var pendingDebriefs: [RunRecord] = []

    /// The last board/feed `ClubView` successfully loaded — held here, not in `ClubView`'s own
    /// `@State`, because `RootTabView` keys `currentScreen` on `.id(appState.screen)` and tears
    /// down/recreates the whole view on every tab switch (see that file for why). Without this,
    /// leaving Club and coming back always re-paid the full network round-trip and a blank
    /// loading spinner before showing anything again, even seconds after the last visit — this
    /// lets a re-visit render the last known state immediately while a fresh fetch still runs
    /// underneath to catch up.
    var cachedClubBoard: ClubBoard?
    var cachedClubFeed: [FeedItem]?

    // Live run (ephemeral, survives navigating away from the Live screen)
    var liveRun: LiveRunViewModel?
    var isRunActive: Bool { liveRun != nil }
    /// The most recently completed run, shown on the Recap screen. Transient — not persisted
    /// on `UserProfile` itself, just a navigation hand-off (the `RunRecord` is already inserted
    /// into `modelContext` and lives on independently via the History query). Unrelated to
    /// `pendingDebriefs` above — Recap embeds its own `DebriefSheet` inline for the live-GPS-run
    /// flow, which can't race with the manual/Watch flow the way two Watch deliveries can race
    /// each other.
    var lastRun: RunRecord?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            self.profile = existing
        } else {
            let fresh = UserProfile()
            modelContext.insert(fresh)
            self.profile = fresh
        }
        AdaptivePlanEngine.refreshProgramForCurrentDate(self.profile)
        AdaptivePlanEngine.resetDailyGoalsIfNewDay(self.profile)
        // The scenePhase→active hook in RunUpApp only catches a real background/foreground
        // transition — an app left open and awake (screen never locked, e.g. plugged in
        // overnight) crosses midnight without ever backgrounding, so the week strip/weekNumber
        // stayed frozen on the old day indefinitely until the next real relaunch. This fires the
        // instant the system clock actually rolls over to a new calendar day, foreground or not.
        // `MainActor.assumeIsolated` plutôt qu'un `Task` : `queue: .main` garantit déjà que ce bloc
        // s'exécute sur le fil principal, donc on l'affirme au compilateur au lieu de replanifier
        // le travail un tour de boucle plus tard. Un `Task` ferait basculer le rafraîchissement
        // après le passage à minuit au tour suivant, ce qui n'apporte rien.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshProgramForCurrentDate() }
        }
        ThemeStore.shared.themeID = self.profile.accentThemeID
        ThemeStore.shared.isLightMode = self.profile.isLightMode
        NotificationService.shared.rescheduleDailyReminder(for: self.profile)
        NotificationService.shared.rescheduleInactivityReminder(for: self.profile)
        NotificationService.shared.scheduleWeeklyRecapReminder(for: self.profile)
        // When HealthKit is connected, `syncDailyGoalsFromHealthKit` below publishes once itself
        // with fresh numbers — publishing here too would just be an immediately-stale extra
        // reload against WidgetKit's per-day budget for no visible benefit.
        if !self.profile.connectedSources.contains(.apple) { publishWidgetSnapshot() }
        // Created last: the service holds `unowned self` and activates WCSession immediately, so
        // a queued watch run (finished while the phone app was closed) is delivered right away.
        self.watchSession = WatchSessionService(appState: self)
        Task { await self.syncDailyGoalsFromHealthKit() }
        // Cold launch never fires RootView's `onChange(of: scenePhase)` (there's no PRIOR phase to
        // transition from), so `refreshProgramForCurrentDate()` — the only other call site — never
        // runs on a fresh launch. Without this, same-day adjustment only ever kicked in once she'd
        // backgrounded/foregrounded the app at least once, which for a lot of real days never
        // happens at all.
        Task { await self.checkSameDayAdjustment() }
        // A Live Activity left over from a killed/crashed app is an orphan by definition
        // (`liveRun` doesn't survive relaunch) — end it instead of leaving a frozen "in-progress"
        // run on the Lock Screen for hours.
        Task {
            for activity in Activity<RunActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        // Reflects whatever's still queued from a previous session that got killed before it
        // could retry — without this, `pendingActivityCount` would silently start at its `= 0`
        // default and stay there until the next successful post/retry touched it.
        // Différé d'un tour de boucle plutôt qu'appelé directement : le compte n'est lu que par
        // une vue, donc arriver au tour suivant est invisible, et cela évite de faire une lecture
        // SwiftData de plus sur le chemin critique du lancement à froid.
        Task { self.refreshPendingActivityCount() }
        // Les sorties encore en file appartiennent au compte qui les a produites. À la
        // déconnexion elles deviennent impubliables (leur jeton disparaît) et dangereuses (le
        // compte suivant les publierait sous son nom), donc on les abandonne. Posé ici plutôt
        // que dans `AuthService`, qui n'a pas à connaître l'état de l'app.
        auth.onSignOut = { [weak self] in
            Task { self?.discardPendingClubActivities() }
        }
        Task { self.recoverInterruptedRunIfNeeded() }
    }

    /// Récupère une course que l'app a perdue en étant tuée en plein effort.
    ///
    /// `LiveRunViewModel` écrit un instantané toutes les dix secondes ; `stop()` l'efface. Un
    /// instantané encore présent au lancement signifie donc exactement une chose : une course a
    /// commencé et ne s'est jamais terminée proprement. Avant, elle disparaissait sans laisser la
    /// moindre trace — ni entrée d'historique, ni écriture dans Santé, ni message.
    ///
    /// On propose de l'ENREGISTRER, pas de la reprendre. Reprendre supposerait de décider ce qui
    /// s'est passé entre la mort de l'app et sa réouverture — a-t-elle continué à courir, s'est
    /// elle arrêtée, quand ? — et aucune de ces réponses n'est dans les données. Ce qui a été
    /// mesuré jusqu'à la coupure, en revanche, est réel : c'est ça qu'on lui rend.
    ///
    /// Le chemin est celui, déjà éprouvé, d'une course reçue de la montre : insérer le relevé,
    /// l'empiler dans `pendingDebriefs`, et laisser la feuille de debrief s'ouvrir depuis la
    /// racine. Elle valide son ressenti et la course entre dans le programme comme n'importe
    /// quelle autre.
    private func recoverInterruptedRunIfNeeded() {
        guard let snapshot = LiveRunSnapshotStore.loadRecoverable() else { return }
        // Consommé tout de suite : quoi qu'il advienne ensuite, cette course ne doit pas être
        // reproposée au prochain lancement.
        LiveRunSnapshotStore.clear()

        // Garde-fou contre un doublon : si un relevé couvre déjà ce départ, l'instantané est un
        // reliquat (arrêt normal dont l'effacement n'a pas abouti) et non une course perdue.
        let descriptor = FetchDescriptor<RunRecord>()
        if let existing = try? modelContext.fetch(descriptor),
           existing.contains(where: { abs($0.date.timeIntervalSince(snapshot.startedAt)) < 300 }) {
            return
        }

        let record = AdaptivePlanEngine.buildRunRecord(
            title: snapshot.sessionTitle,
            elapsedSeconds: snapshot.elapsedSeconds,
            distanceKm: snapshot.distanceMeters / 1000,
            kcal: 0,
            avgHeartRate: 0,
            elevationGainM: Int(snapshot.elevationGainMeters.rounded()),
            realSplitSeconds: snapshot.splitSecondsPerKm,
            route: snapshot.route
        )
        record.date = snapshot.startedAt
        record.sessionKind = snapshot.sessionKind
        modelContext.insert(record)
        pendingDebriefs.append(record)

        let distance = String(format: "%.1f", locale: Locale.current, record.distanceKm)
        notify(
            icon: "🛟",
            colorHex: 0x38E0D0,
            title: String(localized: "Course récupérée"),
            text: String(localized: "L'app s'est fermée pendant ta sortie — \(distance) km avaient été enregistrés. Valide ton ressenti pour les garder.")
        )
    }

    /// Re-checks the program week/phase against the real calendar date — call whenever the app
    /// returns to the foreground so a skipped week or program completion is picked up even if the
    /// user didn't open the app on the exact day it happened.
    func refreshProgramForCurrentDate() {
        let previousWeek = profile.weekNumber
        AdaptivePlanEngine.refreshProgramForCurrentDate(profile)
        AdaptivePlanEngine.resetDailyGoalsIfNewDay(profile)
        if profile.weekNumber != previousWeek {
            let title = String(localized: "Nouvelle semaine")
            let text = String(localized: "Semaine \(profile.weekNumber) prête, ajustée d'après ta forme de la semaine passée.")
            notify(icon: "mark", colorHex: 0xFF3B6B, title: title, text: text, coachOnly: true)
            // `notify` above already no-ops the bell entry when this toggle is off (`coachOnly:
            // true`) — mirror that here so the real notification doesn't fire when the in-app one
            // didn't either.
            if profile.coachNotificationsEnabled {
                NotificationService.shared.postImmediateNotification(title: title, body: text)
            }
        }
        NotificationService.shared.rescheduleDailyReminder(for: profile)
        NotificationService.shared.rescheduleInactivityReminder(for: profile)
        NotificationService.shared.scheduleWeeklyRecapReminder(for: profile)
        if !profile.connectedSources.contains(.apple) { publishWidgetSnapshot() }
        Task { await syncDailyGoalsFromHealthKit() }
        Task { await checkSameDayAdjustment() }
    }

    /// Same-day reactive lightening — a short night or yesterday's brutal RPE eases TODAY's
    /// session instead of only ever showing up in next week's plan (see
    /// `AdaptivePlanEngine.applySameDayAdjustmentIfNeeded`). Deliberately its own call, not folded
    /// into `syncDailyGoalsFromHealthKit` below: the RPE half of the check needs no HealthKit
    /// connection at all, and nesting it inside that HealthKit-gated function would have silently
    /// denied it to anyone who's never connected Apple Santé. Sleep is read here (nil if not
    /// connected) so the "already checked today" guard is only ever consumed once, with the real
    /// sleep-aware answer — not consumed early by some other call site checking with `nil` before
    /// a HealthKit-aware one gets a chance to run today.
    private func checkSameDayAdjustment() async {
        let today = Calendar.current.startOfDay(for: .now)
        guard profile.lastSameDayAdjustmentCheckDay != today else { return }
        let sleepHours = profile.connectedSources.contains(.apple) ? await healthKit.lastNightSleepHours() : nil
        guard AdaptivePlanEngine.applySameDayAdjustmentIfNeeded(profile, sleepHours: sleepHours) else { return }
        let reason = profile.todaySession.adjustment ?? String(localized: "récupération")
        // `displayTitle`, pas `title` : `title` reste le libellé français interne (voir
        // `WorkoutSession`) — l'afficher tel quel remettait du français dans une notification
        // par ailleurs traduite.
        let sessionName = profile.todaySession.displayTitle
        notify(icon: "🌙", colorHex: 0x8A6CFF, title: String(localized: "Séance allégée aujourd'hui"), text: "\(sessionName) · \(reason).")
        if profile.coachNotificationsEnabled {
            NotificationService.shared.postImmediateNotification(
                title: String(localized: "Séance allégée aujourd'hui"),
                body: String(localized: "On lève un peu le pied sur « \(sessionName) » — le programme s'ajuste à ta forme du jour.")
            )
        }
        publishWidgetSnapshot()
    }

    /// Mirrors today's goals/streak/theme into the shared App Group container and asks WidgetKit
    /// to redraw the Home Screen widget — call anywhere `dailyGoalsProgress`, `streak`, or the
    /// accent/light-mode theme could have just changed, since the widget's own process has no way
    /// to observe `profile` directly (see `DailyGoalsSnapshot`).
    func publishWidgetSnapshot() {
        let today = AdaptivePlanEngine.currentWeekdayIndex()
        let snapshot = DailyGoalsSnapshot(
            progress: profile.dailyGoalsProgress,
            streak: profile.streak,
            accentThemeID: profile.accentThemeID,
            isLightMode: profile.isLightMode,
            dailyGoalsDone: profile.dailyGoalsDone,
            dailyGoalsTotal: profile.dailyGoalsTotal,
            activeCaloriesRemaining: max(0, Int((profile.activeCaloriesGoal - profile.activeCaloriesToday).rounded())),
            stepsRemaining: max(0, Int((profile.stepsGoal - profile.stepsToday).rounded())),
            weekStrip: profile.weekStrip.map { WidgetWeekDay(letter: $0.letter, isDone: $0.state == .done, isToday: $0.state == .today) },
            isRestDay: profile.weekSessions.first(where: { $0.weekday == today }).map { $0.session == nil } ?? false
        )
        // Only burn a WidgetKit reload (daily budget ~40-70) when something the widget shows
        // actually changed — browsing the color nuancier used to exhaust it and silently freeze
        // the widget for the rest of the day.
        if snapshot != lastPublishedSnapshot {
            lastPublishedSnapshot = snapshot
            DailyGoalsSnapshot.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        }
        // Same trigger points work for the watch: anywhere the plan/session could have changed,
        // this already fires — the service itself skips the send when nothing session-related moved.
        watchSession?.pushTodaySession()
    }

    /// Pulls today's step count and active calories from Apple Santé, if connected — the
    /// "Calories actives" and "Pas" daily goals are HealthKit-sourced, not something logged inside
    /// the app.
    // Isolé sur l'acteur principal (via la classe) : ceci tournait autrefois sur l'exécuteur où
    // la `Task` atterrissait, puis mutait le profil SwiftData et insérait des notifications depuis
    // un fil de fond — plantages intermittents et écritures perdues à chaque synchro. Les `await`
    // HealthKit, eux, continuent de s'exécuter hors du fil principal.
    private func syncDailyGoalsFromHealthKit() async {
        guard profile.connectedSources.contains(.apple) else { return }
        // Idempotent (only the first call registers) — placed here, on the sync path itself, so
        // observation starts whenever Santé is connected: at launch, and right after she connects
        // it in onboarding/Profil. The observer fires on new steps/calories samples — including
        // hourly background deliveries — and re-runs this same sync, which republishes the
        // widget. `[weak self]` because the closure outlives any single call.
        healthKit.startObservingDailyGoals { @Sendable [weak self] in
            guard let self else { return }
            // `Task` créée depuis un contexte NON isolé (HealthKit appelle depuis sa file) : elle
            // n'hérite donc d'aucun acteur, et c'est l'`await` ci-dessous qui saute sur le
            // principal — ce qui est précisément ce qu'on veut ici.
            Task { await self.syncDailyGoalsFromHealthKit() }
        }
        async let steps = healthKit.stepsToday()
        async let calories = healthKit.activeCaloriesToday()
        profile.stepsToday = await steps
        profile.activeCaloriesToday = await calories
        if AdaptivePlanEngine.checkDailyGoalsBonus(profile) {
            postClubActivity(type: "badge", text: String(localized: "a bouclé ses 3 objectifs du jour"), xpEarned: 120, contentKey: "daily_goals")
            notify(icon: "🎉", colorHex: 0xC9FF3B, title: String(localized: "Journée bouclée"), text: String(localized: "Tes 3 objectifs du jour sont faits — +120 XP."))
            NotificationService.shared.postImmediateNotification(title: String(localized: "Journée bouclée 🎉"), body: String(localized: "Tes 3 objectifs du jour sont faits — +120 XP."))
            toast(String(localized: "Journée bouclée · +120 XP 🎉"))
        }
        // The sole publish for this event when HealthKit is connected — `init`/
        // `refreshProgramForCurrentDate` skip their own synchronous publish in that case so this
        // one (with fresh step/calorie numbers) is the only one that fires.
        publishWidgetSnapshot()
    }

    /// Inserts a real bell-icon notification — replaces what used to be a purely decorative UI
    /// (the bell/badge/sheet existed and read from `AppNotification`, but nothing ever created
    /// one). `coachOnly` gates it on the "Notifications du coach" toggle in Profil, for
    /// program-related updates specifically; social/gamification ones (kudos, daily goals) always
    /// post regardless of that toggle.
    func notify(icon: String, colorHex: Int, title: String, text: String, coachOnly: Bool = false) {
        if coachOnly && !profile.coachNotificationsEnabled { return }
        modelContext.insert(AppNotification(icon: icon, colorHex: colorHex, title: title, text: text))
    }

    // `postClubActivity`/`retryPendingClubActivities` live in ClubActivityOutbox.swift — a local
    // outbox now backs the post so a failed network call doesn't silently drop it forever.

    func go(_ screen: AppScreen) {
        self.screen = screen
    }

    func startRun() {
        // Guard here (not per call site) so every entry point — Home's session card, the session
        // detail sheet, the tab bar's resume pill — is protected from silently overwriting an
        // in-progress run's LiveRunViewModel (which would orphan its timer/location task with no
        // RunRecord ever produced for it).
        guard !isRunActive else {
            screen = .live
            return
        }
        let vm = LiveRunViewModel(profile: profile, healthKit: healthKit)
        liveRun = vm
        vm.start()
        // Placed after the guard above, so a tap on an already-running session (the tab bar's
        // resume pill) doesn't count as a second run started. `trackOnce` is what makes the first
        // one the activation metric — an install that never reaches this line is an install that
        // never became a runner, and nothing else in the app could tell us that.
        Analytics.shared.trackOnce(.firstRunStarted)
        Analytics.shared.track(.runStarted, ["session": .string(profile.todaySession.title)])
        screen = .live
    }

    func endLiveRun() -> RunRecord? {
        guard let vm = liveRun else { return nil }
        let record = vm.stop()
        liveRun = nil
        // An accidental start (a pocket tap killed 40 s later, under 100 m moved) is not a run —
        // recording it would put a fabricated-looking "0,05 km" entry in History/Stats forever,
        // and (since the HealthKit write only fires below, after this guard) it won't create a
        // phantom workout in Apple Health either.
        guard record.distanceKm >= 0.1 || record.durationSeconds >= 120 else {
            toast(String(localized: "Course trop courte — rien n'a été enregistré."))
            screen = .home
            return nil
        }
        vm.saveToHealthKit(record)
        modelContext.insert(record)
        lastRun = record
        screen = .recap
        return record
    }

    /// Déplace une séance d'un jour à l'autre de la semaine en cours.
    ///
    /// Écrit directement dans `weekSessions`, qui EST la semaine en cours — il n'y a pas de couche
    /// de surcharge à tenir, et donc rien qui puisse se désynchroniser du plan. Les semaines
    /// suivantes ne sont pas concernées : elles sont régénérées à chaque affichage, un déplacement
    /// y serait silencieusement perdu (voir `SessionMove`).
    ///
    /// Rend `false` quand le déplacement est refusé, pour que l'appelant n'affiche pas une
    /// confirmation d'une chose qui n'a pas eu lieu.
    @discardableResult
    func moveSession(from: Int, to: Int) -> Bool {
        guard let moved = SessionMove.apply(to: profile.weekSessions, from: from, to: to) else { return false }
        profile.weekSessions = moved

        // La bande de la semaine sur l'accueil lit `weekStrip`, pas `weekSessions`, et son état
        // « repos » vient des jours de course du profil — pas des séances réellement posées. Sans
        // ces deux lignes, l'accueil continuerait d'annoncer une séance le jour qu'on vient de
        // libérer et de marquer repos celui où elle vient d'atterrir : deux représentations de la
        // même semaine, dont une seule aurait bougé.
        //
        // `.done` n'est jamais touché : un jour déjà validé ne peut pas être l'un des deux (une
        // séance faite ne se déplace pas), et l'écraser effacerait une séance qui a bien eu lieu.
        let today = AdaptivePlanEngine.currentWeekdayIndex()
        profile.weekStrip = profile.weekStrip.map { day in
            guard day.weekday == from || day.weekday == to, day.state != .done else { return day }
            var updated = day
            let occupied = (moved.first { $0.weekday == day.weekday }?.session?.durationMinutes ?? 0) > 0
            updated.state = !occupied ? .rest : (day.weekday == today ? .today : .upcoming)
            return updated
        }

        Haptics.success()
        toast(String(localized: "Séance déplacée"))
        Analytics.shared.track(.sessionMoved, ["from": .int(from), "to": .int(to)])
        return true
    }

    /// Logs today's planned session as done without going through the GPS Live Run flow — for a
    /// strength day, a treadmill session, or simply forgetting to hit record. Builds a synthetic
    /// `RunRecord` from the session's own planned duration/pace (no real heart-rate reading, so
    /// `avgHeartRate` is 0 — `HistoryView` already knows to hide that line rather than show a
    /// fake number) and opens the same RPE debrief every other run goes through, so streak/XP/
    /// plan-adaptation all work identically either way.
    func markTodaySessionDone() {
        let session = profile.todaySession
        guard session.durationMinutes > 0 else { return }
        let elapsedSeconds = Double(session.durationMinutes * 60)
        // "FAIT" means she ran it without the app tracking it — there's no GPS behind this tap,
        // so there's no real distance or pace to report, only the planned target. The old code
        // derived a distance from elapsedSeconds / plannedPace, which fabricated a precise-looking
        // "5.2 km @ 5:30/km" for a run that could have gone at any real pace at all, for every
        // session with a pace target — not just the paceless HYROX case this comment used to
        // describe. Distance 0 is the honest record; kcal falls back to a time-based estimate.
        let record = AdaptivePlanEngine.buildRunRecord(
            title: session.title,
            elapsedSeconds: elapsedSeconds,
            distanceKm: 0,
            kcal: Double(session.durationMinutes) * 7,
            avgHeartRate: 0
        )
        // Le type de la séance suit la course : c'est ce qui permet au fil du club de refabriquer
        // sa phrase dans la langue de qui la lit (voir `FeedItem.localizedText`). Nil pour un plan
        // enregistré avant `SessionKind`.
        record.sessionKind = session.kind
        // Deliberately NOT inserted into SwiftData here — `DebriefSheet` inserts it on VALIDER.
        // Inserting up front meant dismissing the debrief sheet without validating left a phantom
        // synthetic run in History/Stats for a session that was never actually confirmed done.
        pendingDebriefs.append(record)
    }

    func openSessionDetail() { sessionDetailPresented = true }
    func openMoveSession() { moveSessionPresented = true }
    func openProgramSettings() { programSettingsPresented = true }
    func openNotifications() { notificationsPresented = true }

    func toast(_ message: String) {
        toastCenter.show(message)
    }

    /// Real, deliberate gating for Apple's review prompt — never a fixed schedule or every
    /// launch, only right after a genuinely positive moment (a run that felt easy/good) at a
    /// meaningful progress milestone, and never more than once every 90 days from this app's own
    /// side (on top of whatever StoreKit itself already throttles system-wide).
    func shouldRequestReview(rpe: RPE) -> Bool {
        guard rpe == .facile || rpe == .justeBien else { return false }
        let milestones: Set<Int> = [3, 10, 25, 50, 100]
        guard milestones.contains(profile.completedDebriefsCount) else { return false }
        if let last = profile.lastReviewPromptDate,
           (Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 999) < 90 {
            return false
        }
        return true
    }

    func recordReviewPromptShown() {
        profile.lastReviewPromptDate = .now
    }
}
