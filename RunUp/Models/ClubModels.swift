import Foundation

/// Club/social is mock data in v1 (no backend) — plain in-memory structs rather than SwiftData,
/// since nothing here needs to persist or be queried across launches. See README § 11.

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    var rank: Int
    var name: String
    var xp: Int
    var medal: String?
    var isMe: Bool = false
}

struct ActivityFeedItem: Identifiable {
    let id = UUID()
    var name: String
    var initial: String
    var colorHex: UInt32
    var time: String
    var text: String
    var kudos: Int
}

struct ClubBadge: Identifiable {
    let id = UUID()
    var emoji: String
    var name: String
    var earned: Bool
}

enum ClubMockData {
    static let feed: [ActivityFeedItem] = [
        ActivityFeedItem(name: "Sarah K.", initial: "S", colorHex: 0xFF0F5B, time: "il y a 20 min", text: "a couru 8.2 km · Sortie longue", kudos: 6),
        ActivityFeedItem(name: "Thomas R.", initial: "T", colorHex: 0x7C5CFF, time: "il y a 2 h", text: "a débloqué le badge 🏔 Dénivelé", kudos: 14),
        ActivityFeedItem(name: "Marc D.", initial: "M", colorHex: 0x38E0D0, time: "ce matin", text: "a couru 5.0 km · Récup active", kudos: 3),
        ActivityFeedItem(name: "Sarah K.", initial: "S", colorHex: 0xFF0F5B, time: "hier", text: "a rejoint le défi 100 km en juillet", kudos: 9)
    ]

    static func leaderboard(myName: String, myXp: Int) -> [LeaderboardEntry] {
        [
            LeaderboardEntry(rank: 1, name: "Thomas R.", xp: 2480, medal: "🥇"),
            LeaderboardEntry(rank: 2, name: "\(myName) · toi", xp: 2000 + myXp, medal: "🥈", isMe: true),
            LeaderboardEntry(rank: 3, name: "Sarah K.", xp: 2180, medal: "🥉"),
            LeaderboardEntry(rank: 4, name: "Marc D.", xp: 1950, medal: nil)
        ]
    }

    static func badges(streak: Int) -> [ClubBadge] {
        [
            ClubBadge(emoji: "🔥", name: "Série \(streak)j", earned: true),
            ClubBadge(emoji: "⚡", name: "VMA pro", earned: true),
            ClubBadge(emoji: "🌅", name: "Lève-tôt", earned: true),
            ClubBadge(emoji: "🏔", name: "Dénivelé", earned: false)
        ]
    }
}
