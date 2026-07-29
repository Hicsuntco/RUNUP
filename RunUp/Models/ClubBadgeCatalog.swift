import Foundation
import SwiftUI

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
        Definition(key: "elevation300", emoji: "🏔", name: "300 m de D+", detail: "Cumule du dénivelé positif sur tes sorties."),
        Definition(key: "firstRun", emoji: "👟", name: "Première course", detail: "Termine ta toute première sortie sur RunUp."),
        Definition(key: "streak7", emoji: "🌟", name: "Série de 7 jours", detail: "Enchaîne 7 jours de séances sans interruption."),
        Definition(key: "streak30", emoji: "👑", name: "Série de 30 jours", detail: "Enchaîne 30 jours de séances sans interruption."),
        Definition(key: "tenRuns", emoji: "🎯", name: "10 courses", detail: "Termine 10 sorties au total."),
        Definition(key: "fiftyRuns", emoji: "💯", name: "50 courses", detail: "Termine 50 sorties au total."),
        Definition(key: "distance50", emoji: "🏁", name: "50 km cumulés", detail: "Cumule 50 km sur l'ensemble de tes sorties."),
        Definition(key: "distance250", emoji: "🌍", name: "250 km cumulés", detail: "Cumule 250 km sur l'ensemble de tes sorties."),
        Definition(key: "distance1000", emoji: "🌌", name: "1000 km cumulés", detail: "Cumule 1000 km sur l'ensemble de tes sorties."),
        Definition(key: "halfMarathonDistance", emoji: "🏅", name: "Demi-marathon", detail: "Parcours 21 km ou plus en une seule sortie."),
        Definition(key: "marathonDistance", emoji: "🎖", name: "Marathon", detail: "Parcours 42 km ou plus en une seule sortie."),
        Definition(key: "nightRun", emoji: "🌙", name: "Course de nuit", detail: "Termine une séance après 21h."),
        Definition(key: "weekendWarrior", emoji: "🏆", name: "Guerrière du week-end", detail: "Cumule 10 sorties un samedi ou un dimanche.")
    ]

    /// A themed color per badge instead of the same neutral tile for all 15+ — fire/série in
    /// ambre, vitesse/nuit en violet, aube en rose2, dénivelé en lime, volume/comptage en cyan,
    /// paliers de distance de course en rose. Every color already exists in `RUColor` — no new
    /// hue introduced, just distinguishing badges from each other at a glance.
    static func color(for key: String) -> Color {
        switch key {
        case "streak3", "streak7", "streak30", "weekendWarrior": return RUColor.amber
        case "interval3", "nightRun": return RUColor.violet
        case "earlyRun": return RUColor.rose2
        case "elevation300": return RUColor.lime
        case "firstRun", "tenRuns", "fiftyRuns", "distance50", "distance250", "distance1000": return RUColor.cyan
        case "halfMarathonDistance", "marathonDistance": return RUColor.rose
        default: return RUColor.rose
        }
    }
}
