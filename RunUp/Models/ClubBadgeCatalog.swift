import Foundation

/// Shared badge definitions (key/emoji/name/detail) — keys must match `KNOWN_BADGES` in
/// `api/clubs/[action].js`. `ClubView` combines these with progress computed locally from real
/// `RunRecord`/streak data no other client can see (for "my" badges); `ClubMemberProfileView`
/// combines them with just the earned/locked flag the server already knows via
/// `LeaderboardRow.badgeKeys` (for any other member) — real achievements visible on every
/// profile, not just your own device, since `ClubView` syncs newly-earned keys up via
/// `ClubService.syncBadges`.
enum ClubBadgeCatalog {
    struct Definition: Identifiable {
        var key: String
        var emoji: String
        var name: String
        var detail: String
        var id: String { key }
    }

    static let all: [Definition] = [
        Definition(key: "streak3", emoji: "🔥", name: "Série de 3 jours", detail: "Enchaîne des séances sans jour d'interruption."),
        Definition(key: "interval3", emoji: "⚡", name: "Fractionné pro", detail: "Réalise des séances de fractionné ou de VMA."),
        Definition(key: "earlyRun", emoji: "🌅", name: "Lève-tôt", detail: "Termine une séance avant 7h du matin."),
        Definition(key: "elevation300", emoji: "🏔", name: "300 m de D+", detail: "Cumule du dénivelé positif sur tes sorties.")
    ]
}
