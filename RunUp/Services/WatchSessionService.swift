import Foundation
import WatchConnectivity

/// The iPhone's half of the phone↔watch bridge (the watch half is
/// `RunUpWatch/WatchConnectivityManager`). Two flows:
/// - Outbound: today's session (title, target pace, duration) via `updateApplicationContext` —
///   latest-state semantics, so the watch always has the current session even if it was
///   unreachable when the plan changed. Pushed from `AppState.publishWidgetSnapshot()`, which
///   already fires on every plan/theme/goal change.
/// - Inbound: a run finished on the wrist arrives via `didReceiveUserInfo` (queued — survives
///   airplane mode, delivered when the devices reconnect). The phone builds the `RunRecord`,
///   inserts it, and opens the same RPE debrief every other run goes through, so streak/XP/
///   plan-adaptation work identically whether the run was tracked from pocket or wrist.
///
/// `@MainActor` : ce service lit et écrit `AppState` (contexte SwiftData, file de débriefs,
/// toasts). Les callbacks `WCSessionDelegate` en bas, eux, arrivent sur une file système — ils
/// sont donc explicitement `nonisolated` et sautent sur l'acteur principal, ce qui est ce que le
/// code faisait déjà mais que rien ne garantissait.
@MainActor
final class WatchSessionService: NSObject {
    private unowned let appState: AppState
    /// Last context actually handed to WCSession — `publishWidgetSnapshot` fires on plenty of
    /// changes that don't touch the session (theme, steps), and re-sending an identical context
    /// would just burn the transfer budget. Nil (not `[:]`) until the first send of this launch:
    /// a rest day's context IS the empty dictionary, and seeding with `[:]` made the "unchanged"
    /// guard skip that first send — the watch kept showing yesterday's séance all rest day.
    private var lastSentContext: [String: String]?

    private static let seenClientIdsKey = "watchRunSeenClientIds"

    init(appState: AppState) {
        self.appState = appState
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Mirrors today's session to the watch. Rest days send an empty context — the watch then
    /// shows its "course libre" framing instead of yesterday's stale séance.
    func pushTodaySession() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let profile = appState.profile
        let today = AdaptivePlanEngine.currentWeekdayIndex()
        let isRestDay = profile.weekSessions.first(where: { $0.weekday == today }).map { $0.session == nil } ?? false

        // Two parallel dictionaries: the [String: String] one exists only because [String: Any]
        // isn't Equatable — it's what makes the "did anything change?" guard possible.
        var context: [String: String] = [:]
        var payload: [String: Any] = [:]
        if !isRestDay {
            let session = profile.todaySession
            context = [
                "sessionTitle": session.title,
                "sessionPace": session.pace,
                "sessionDurationMinutes": String(session.durationMinutes),
            ]
            payload = [
                "sessionTitle": session.title,
                "sessionPace": session.pace,
                "sessionDurationMinutes": session.durationMinutes,
            ]
        }
        guard context != lastSentContext else { return }
        do {
            try WCSession.default.updateApplicationContext(payload)
            lastSentContext = context
        } catch {
            // Not paired / watch app not installed — nothing to do, next call retries.
        }
    }

    // MARK: Inbound completed run

    private func handleCompletedRun(_ payload: CompletedRunPayload) {
        // Idempotency — transferUserInfo can re-deliver (and the watch could retry): the same
        // wrist run must never become two RunRecords.
        var seen = UserDefaults.standard.stringArray(forKey: Self.seenClientIdsKey) ?? []
        guard !seen.contains(payload.clientId) else { return }
        seen.append(payload.clientId)
        if seen.count > 100 { seen.removeFirst(seen.count - 100) }
        UserDefaults.standard.set(seen, forKey: Self.seenClientIdsKey)

        // A tap-started-tap-stopped accident on the wrist (a few seconds, no distance) shouldn't
        // pollute History — same spirit as the Live screen's own minimum.
        guard payload.elapsedSeconds >= 60, payload.distanceKm >= 0.1 else { return }

        let record = AdaptivePlanEngine.buildRunRecord(
            title: payload.title,
            elapsedSeconds: payload.elapsedSeconds,
            distanceKm: payload.distanceKm,
            kcal: payload.kcal,
            avgHeartRate: payload.avgHeartRate
        )
        // Dated when she actually ran, not when the queued transfer finally arrived — a run
        // finished Saturday in airplane mode must not appear as a Sunday run in History.
        if let startedAtEpoch = payload.startedAtEpoch {
            record.date = Date(timeIntervalSince1970: startedAtEpoch)
        }
        // Inserted right away — like a GPS run, it really happened (DebriefSheet sees
        // `modelContext != nil` and won't re-insert). The debrief only adds the RPE on top.
        // Queued rather than assigned to a single slot — two runs delivered together on
        // reconnect (a real case: the Watch queues delivery through airplane mode/out-of-range)
        // must not have the second silently overwrite the first's pending debrief.
        appState.modelContext.insert(record)
        appState.pendingDebriefs.append(record)
        let distance = String(format: "%.1f", locale: Locale.current, record.distanceKm)
        appState.notify(icon: "⌚", colorHex: 0xFF3B6B, title: String(localized: "Course reçue de ta montre"), text: String(localized: "\(record.title) · \(distance) km — valide ton ressenti pour mettre à jour le programme."))
        appState.toast(String(localized: "Course reçue de ta montre ⌚"))
    }
}

// `nonisolated` sur chacun : WatchConnectivity appelle ces méthodes depuis sa propre file, jamais
// depuis le fil principal. Les déclarer telles quelles sur une classe `@MainActor` reviendrait à
// promettre au compilateur quelque chose de faux ; le saut vers l'acteur principal est donc écrit
// explicitement là où il a lieu.
extension WatchSessionService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in self.pushTodaySession() }
    }

    // iOS-only requirements — fire when the user switches to a different paired watch.
    // Re-activating hands the session over to the newly active watch.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // Décodé ICI, sur la file de WatchConnectivity, pour que seul un type `Sendable` traverse.
        guard let payload = CompletedRunPayload(userInfo) else { return }
        Task { @MainActor in self.handleCompletedRun(payload) }
    }
}

/// La charge utile d'une course reçue de la montre, une fois extraite du `[String: Any]`.
///
/// Ce type existe pour une raison précise : `[String: Any]` n'est pas `Sendable`, donc le passer
/// tel quel du callback `WCSessionDelegate` (file système) à l'acteur principal est exactement le
/// franchissement d'isolation que Swift 6 interdit. On lit donc les valeurs là où elles arrivent
/// — elles sont toutes de simples scalaires — et on ne fait traverser qu'une structure immuable
/// et `Sendable`.
///
/// Déclaré au niveau du fichier et non imbriqué dans `WatchSessionService` : un type imbriqué
/// dans une classe `@MainActor` en hérite l'isolation, ce qui rendrait son `init` inappelable
/// depuis le callback `nonisolated` qui en a précisément besoin.
private struct CompletedRunPayload: Sendable {
    var clientId: String
    var title: String
    var elapsedSeconds: Double
    var distanceKm: Double
    var kcal: Double
    var avgHeartRate: Int
    var startedAtEpoch: Double?

    init?(_ userInfo: [String: Any]) {
        guard userInfo["kind"] as? String == "completedRun",
              let clientId = userInfo["clientId"] as? String
        else { return nil }
        self.clientId = clientId
        self.title = userInfo["title"] as? String ?? String(localized: "Course libre")
        self.elapsedSeconds = userInfo["elapsedSeconds"] as? Double ?? 0
        self.distanceKm = userInfo["distanceKm"] as? Double ?? 0
        self.kcal = userInfo["kcal"] as? Double ?? 0
        self.avgHeartRate = userInfo["avgHeartRate"] as? Int ?? 0
        self.startedAtEpoch = userInfo["startedAt"] as? Double
    }
}
