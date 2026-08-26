import Foundation
import WatchConnectivity
import Observation

/// The watch's half of the phone↔watch bridge. Two flows:
/// - Inbound: the phone pushes today's session (title, target pace, duration) via
///   `updateApplicationContext` — latest-state semantics, survives the phone being unreachable,
///   exactly what "what's my session today?" needs (no queue of stale sessions).
/// - Outbound: a finished run goes up via `transferUserInfo` — queued delivery, so a run ended
///   in airplane mode / far from the phone still arrives once they reconnect. The phone side
///   (`WatchSessionService`) dedupes on `clientId`, so a retried transfer can't double-insert.
///
/// `@MainActor` : les trois propriétés ci-dessous sont lues par l'écran d'accueil de la montre.
/// Elles étaient écrites depuis les callbacks `WCSessionDelegate`, qui arrivent sur une file
/// système — d'où les `nonisolated` en bas et le décodage du contexte AVANT de traverser.
@MainActor
@Observable
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    /// Today's session as last pushed by the phone — nil until the first sync (fresh install,
    /// phone app not opened since the watch app was installed).
    private(set) var sessionTitle: String?
    private(set) var sessionPace: String?
    private(set) var sessionDurationMinutes: Int?
    /// Jamais affiché : la montre ne fait que le transporter, du téléphone vers le téléphone, pour
    /// que la course revienne en sachant quelle séance elle exécutait.
    private(set) var sessionKind: String?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Called once from the app's init so the session activates at launch (the lazy `shared`
    /// would otherwise only spin up on first use).
    func activate() {}

    func sendCompletedRun(startedAt: Date, elapsedSeconds: Double, distanceKm: Double, kcal: Double, avgHeartRate: Int) {
        guard WCSession.isSupported() else { return }
        var payload: [String: Any] = [
            "kind": "completedRun",
            // Idempotency key — same role as the club API's client_id: a re-queued transfer
            // (or a delegate double-fire) must not become two RunRecords on the phone.
            "clientId": UUID().uuidString,
            // The séance this run was actually run against — what the start screen displayed,
            // not whatever the phone's plan says at delivery time (could be days later).
            //
            // Quand il n'y en a pas, la clé est OMISE plutôt que remplie avec « Course libre » :
            // ce libellé finirait tel quel, en français, dans l'historique d'une utilisatrice
            // anglophone. Le téléphone applique son propre repli traduit à la réception.
            "startedAt": startedAt.timeIntervalSince1970,
            "elapsedSeconds": elapsedSeconds,
            "distanceKm": distanceKm,
            "kcal": kcal,
            "avgHeartRate": avgHeartRate,
        ]
        if let sessionTitle { payload["title"] = sessionTitle }
        if let sessionKind { payload["sessionKind"] = sessionKind }
        WCSession.default.transferUserInfo(payload)
    }

    private func apply(_ context: SessionContext) {
        sessionTitle = context.title
        sessionPace = context.pace
        sessionDurationMinutes = context.durationMinutes
        sessionKind = context.kind
    }
}

// `nonisolated` : WatchConnectivity rappelle depuis sa propre file. Le dictionnaire `[String: Any]`
// qu'elle fournit n'est pas `Sendable`, donc il est décodé ici, sur place, et seul le résultat —
// trois valeurs simples dans une structure immuable — franchit la limite vers l'acteur principal.
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // The context the phone pushed while this app wasn't running is available right after
        // activation — read it so a cold launch still shows today's session.
        let context = SessionContext(session.receivedApplicationContext)
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let context = SessionContext(applicationContext)
        Task { @MainActor in self.apply(context) }
    }
}

/// La séance du jour telle que le téléphone la pousse, une fois extraite du `[String: Any]`.
///
/// Déclarée au niveau du fichier, et non imbriquée dans la classe : un type imbriqué dans une
/// classe `@MainActor` en hérite l'isolation, ce qui rendrait son `init` inappelable depuis les
/// callbacks `nonisolated` ci-dessus, qui sont précisément là où il sert.
private struct SessionContext: Sendable {
    var title: String?
    var pace: String?
    var durationMinutes: Int?
    var kind: String?

    init(_ context: [String: Any]) {
        title = context["sessionTitle"] as? String
        pace = context["sessionPace"] as? String
        durationMinutes = context["sessionDurationMinutes"] as? Int
        kind = context["sessionKind"] as? String
    }
}
