import Foundation
import SwiftUI

/// Shared badge definitions (key/symbole/name/detail) — keys must match `KNOWN_BADGES` in
/// `api/clubs/[action].js`. `ClubView` combines these with progress computed locally from real
/// `RunRecord`/streak data no other client can see (for "my" badges); `ClubMemberProfileView`
/// combines them with just the earned/locked flag the server already knows via
/// `LeaderboardRow.badgeKeys` (for any other member) — real achievements visible on every
/// profile, not just your own device, since `ClubView` syncs newly-earned keys up via
/// `ClubService.syncBadges`.
enum ClubBadgeCatalog {
    struct Definition: Identifiable {
        var key: String
        /// UN SYMBOLE DESSINÉ, PAS UN ÉMOJI.
        ///
        /// Les seize badges portaient 🔥⚡🌅🏔👟🌟👑🎯💯🏁🌍🌌🏅🎖🌙🏆 — des images en couleurs
        /// d'impression, posées dans des hexagones teintés sur un écran sombre et sobre. C'était
        /// le dernier endroit de l'app où le rendu ne venait pas d'elle : un émoji est dessiné
        /// par le système, dans SON style, qui change d'une version d'iOS à l'autre et ne
        /// s'accorde à aucune charte.
        ///
        /// Un symbole SF prend la COULEUR DU BADGE (voir `color(for:)`), la graisse du reste de
        /// l'app, et grandit avec le texte. C'est ce qui sépare une récompense d'un autocollant.
        var symbole: String
        var name: String
        var detail: String
        var id: String { key }
    }

    static let all: [Definition] = [
        Definition(key: "streak3", symbole: "flame.fill", name: String(localized: "Série de 3 jours"), detail: String(localized: "Enchaîne des séances sans jour d'interruption.")),
        Definition(key: "interval3", symbole: "bolt.fill", name: String(localized: "Fractionné pro"), detail: String(localized: "Réalise des séances de fractionné ou de VMA.")),
        Definition(key: "earlyRun", symbole: "sunrise.fill", name: String(localized: "Lève-tôt"), detail: String(localized: "Termine une séance avant 7h du matin.")),
        Definition(key: "elevation300", symbole: "mountain.2.fill", name: String(localized: "300 m de D+"), detail: String(localized: "Cumule du dénivelé positif sur tes sorties.")),
        Definition(key: "firstRun", symbole: "shoeprints.fill", name: String(localized: "Première course"), detail: String(localized: "Termine ta toute première sortie sur RunUp.")),
        Definition(key: "streak7", symbole: "sparkles", name: String(localized: "Série de 7 jours"), detail: String(localized: "Enchaîne 7 jours de séances sans interruption.")),
        Definition(key: "streak30", symbole: "crown.fill", name: String(localized: "Série de 30 jours"), detail: String(localized: "Enchaîne 30 jours de séances sans interruption.")),
        Definition(key: "tenRuns", symbole: "target", name: String(localized: "10 courses"), detail: String(localized: "Termine 10 sorties au total.")),
        Definition(key: "fiftyRuns", symbole: "flame.circle.fill", name: String(localized: "50 courses"), detail: String(localized: "Termine 50 sorties au total.")),
        Definition(key: "distance50", symbole: "flag.checkered", name: String(localized: "50 km cumulés"), detail: String(localized: "Cumule 50 km sur l'ensemble de tes sorties.")),
        Definition(key: "distance250", symbole: "globe.europe.africa.fill", name: String(localized: "250 km cumulés"), detail: String(localized: "Cumule 250 km sur l'ensemble de tes sorties.")),
        Definition(key: "distance1000", symbole: "moon.stars.fill", name: String(localized: "1000 km cumulés"), detail: String(localized: "Cumule 1000 km sur l'ensemble de tes sorties.")),
        Definition(key: "halfMarathonDistance", symbole: "medal.fill", name: String(localized: "Demi-marathon"), detail: String(localized: "Parcours 21 km ou plus en une seule sortie.")),
        Definition(key: "marathonDistance", symbole: "trophy.fill", name: String(localized: "Marathon"), detail: String(localized: "Parcours 42 km ou plus en une seule sortie.")),
        Definition(key: "nightRun", symbole: "moon.fill", name: String(localized: "Course de nuit"), detail: String(localized: "Termine une séance après 21h.")),
        Definition(key: "weekendWarrior", symbole: "calendar.badge.checkmark", name: String(localized: "Guerrière du week-end"), detail: String(localized: "Cumule 10 sorties un samedi ou un dimanche."))
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
