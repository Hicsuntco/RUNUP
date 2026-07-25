import Foundation

/// A small local outbox for `AppState.postClubActivity`. The server endpoint is already
/// idempotent on `clientId` (`ON CONFLICT (client_id) DO NOTHING` in `api/activities/[action].js`),
/// so retrying is safe by construction — the only real gap was that the client never kept the
/// payload around long enough to retry it. Before this, a failed post (a spotty connection at the
/// exact moment she finishes a run) silently and permanently dropped that run's server-side XP,
/// club feed entry, and challenge progress, while the local streak/XP credit and "+120 XP" toast
/// fired unconditionally regardless of whether the server ever received it.
private struct PendingClubActivity: Codable, Equatable {
    var clientId: UUID
    var type: String
    var text: String
    var xpEarned: Int
    var distanceKm: Double?
}

@MainActor
extension AppState {
    private static let outboxKey = "clubActivityOutbox.v1"

    private var outbox: [PendingClubActivity] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.outboxKey),
                  let items = try? JSONDecoder().decode([PendingClubActivity].self, from: data) else { return [] }
            return items
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: Self.outboxKey)
        }
    }

    /// Posts to the real club feed/leaderboard if signed in — silently does nothing otherwise
    /// (Club participation is optional; this must never block the flow it's called from). Queued
    /// to the local outbox *before* the network attempt, so a kill mid-request still leaves
    /// something to retry rather than a `try?` that discarded the payload the instant it failed.
    func postClubActivity(type: String, text: String, xpEarned: Int, distanceKm: Double? = nil) {
        guard auth.isSignedIn else { return }
        let pending = PendingClubActivity(clientId: UUID(), type: type, text: text, xpEarned: xpEarned, distanceKm: distanceKm)
        outbox.append(pending)
        Task { await attemptPost(pending) }
    }

    /// Call opportunistically — app foreground, Club tab opening — to retry anything still queued
    /// from a prior failed attempt. Safe to call anytime, including with an empty outbox.
    func retryPendingClubActivities() {
        guard auth.isSignedIn else { return }
        for pending in outbox {
            Task { await attemptPost(pending) }
        }
    }

    private func attemptPost(_ pending: PendingClubActivity) async {
        let service = ClubService(auth: auth)
        do {
            try await service.postActivity(clientId: pending.clientId, type: pending.type, text: pending.text, xpEarned: pending.xpEarned, distanceKm: pending.distanceKm)
            outbox.removeAll { $0.clientId == pending.clientId }
        } catch {
            // Left in the outbox — picked up again next time `retryPendingClubActivities()` runs.
        }
    }
}
