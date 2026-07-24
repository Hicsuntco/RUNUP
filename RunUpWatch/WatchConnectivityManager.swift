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
@Observable
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    /// Today's session as last pushed by the phone — nil until the first sync (fresh install,
    /// phone app not opened since the watch app was installed).
    private(set) var sessionTitle: String?
    private(set) var sessionPace: String?
    private(set) var sessionDurationMinutes: Int?

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
        let payload: [String: Any] = [
            "kind": "completedRun",
            // Idempotency key — same role as the club API's client_id: a re-queued transfer
            // (or a delegate double-fire) must not become two RunRecords on the phone.
            "clientId": UUID().uuidString,
            // The séance this run was actually run against — what the start screen displayed,
            // not whatever the phone's plan says at delivery time (could be days later).
            "title": sessionTitle ?? "Course libre",
            "startedAt": startedAt.timeIntervalSince1970,
            "elapsedSeconds": elapsedSeconds,
            "distanceKm": distanceKm,
            "kcal": kcal,
            "avgHeartRate": avgHeartRate,
        ]
        WCSession.default.transferUserInfo(payload)
    }

    private func readSessionContext(_ context: [String: Any]) {
        Task { @MainActor in
            self.sessionTitle = context["sessionTitle"] as? String
            self.sessionPace = context["sessionPace"] as? String
            self.sessionDurationMinutes = context["sessionDurationMinutes"] as? Int
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // The context the phone pushed while this app wasn't running is available right after
        // activation — read it so a cold launch still shows today's session.
        readSessionContext(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        readSessionContext(applicationContext)
    }
}
