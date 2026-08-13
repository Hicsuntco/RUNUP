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
    /// Optionnel *et* décodé avec un défaut : une file écrite par une version précédente de l'app
    /// ne contient pas cette clé, et `JSONDecoder` fait échouer le tableau ENTIER sur une seule
    /// entrée illisible (voir le `try?` du getter, qui retomberait alors sur `[]`). Autrement dit,
    /// un champ non optionnel ici jetterait silencieusement les sorties en attente de quelqu'un
    /// qui met l'app à jour avec le réseau coupé — exactement la perte que cette file existe pour
    /// empêcher.
    var metrics: ActivityMetrics?

    init(clientId: UUID, type: String, text: String, xpEarned: Int, metrics: ActivityMetrics?) {
        self.clientId = clientId
        self.type = type
        self.text = text
        self.xpEarned = xpEarned
        self.metrics = metrics
    }

    private enum CodingKeys: String, CodingKey {
        case clientId, type, text, xpEarned, metrics
        /// Le champ tel qu'il était écrit avant que les métriques soient regroupées. Une sortie
        /// encore en file au moment de la mise à jour porte cette clé et pas `metrics`.
        case legacyDistanceKm = "distanceKm"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clientId = try c.decode(UUID.self, forKey: .clientId)
        type = try c.decode(String.self, forKey: .type)
        text = try c.decode(String.self, forKey: .text)
        xpEarned = try c.decode(Int.self, forKey: .xpEarned)
        if let stored = try c.decodeIfPresent(ActivityMetrics.self, forKey: .metrics) {
            metrics = stored
        } else if let legacy = try c.decodeIfPresent(Double.self, forKey: .legacyDistanceKm) {
            // On ne relit QUE la distance : c'est la seule chose que l'ancienne entrée savait, et
            // elle porte la progression du défi de club. Les autres métriques restent absentes,
            // ce qui est exact — elles n'ont jamais été enregistrées pour cette sortie-là.
            metrics = ActivityMetrics(distanceKm: legacy)
        } else {
            metrics = nil
        }
    }

    /// Écrit explicitement, parce que `legacyDistanceKm` n'a pas de propriété stockée en face :
    /// Swift ne peut donc pas synthétiser `encode(to:)` à partir de ces `CodingKeys`. Cette clé
    /// est en LECTURE SEULE par construction — on relit les entrées de l'ancien format, on n'en
    /// écrit plus jamais.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(clientId, forKey: .clientId)
        try c.encode(type, forKey: .type)
        try c.encode(text, forKey: .text)
        try c.encode(xpEarned, forKey: .xpEarned)
        try c.encodeIfPresent(metrics, forKey: .metrics)
    }
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
    func postClubActivity(type: String, text: String, xpEarned: Int, metrics: ActivityMetrics = .none) {
        guard auth.isSignedIn else { return }
        let pending = PendingClubActivity(clientId: UUID(), type: type, text: text, xpEarned: xpEarned, metrics: metrics)
        outbox.append(pending)
        pendingActivityCount = outbox.count
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

    /// Syncs the observable count from the real outbox — called on every enqueue/success above,
    /// and once at app launch (`AppState.init`) to reflect whatever a killed previous session left
    /// behind. `outbox` itself stays a plain `UserDefaults`-backed computed property (not
    /// `@Observable`-tracked, since it lives in this extension rather than the class body), so
    /// nothing updates the History banner without this explicit nudge.
    func refreshPendingActivityCount() {
        pendingActivityCount = outbox.count
    }

    private func attemptPost(_ pending: PendingClubActivity) async {
        let service = ClubService(auth: auth)
        do {
            try await service.postActivity(clientId: pending.clientId, type: pending.type, text: pending.text, xpEarned: pending.xpEarned, metrics: pending.metrics ?? .none)
            outbox.removeAll { $0.clientId == pending.clientId }
            pendingActivityCount = outbox.count
        } catch {
            // Left in the outbox — picked up again next time `retryPendingClubActivities()` runs.
        }
    }
}
