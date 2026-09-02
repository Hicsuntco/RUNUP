import Foundation

/// La charge d'entraînement : ce que le corps encaisse cette semaine, comparé à ce à quoi il est
/// habitué.
///
/// # Pourquoi c'est une règle et pas un calcul d'écran
///
/// Le rapport aigu sur chronique est un marqueur de blessure, pas une statistique décorative. Une
/// semaine nettement plus lourde que les précédentes est le mécanisme par lequel on se blesse en
/// suivant scrupuleusement un programme, et le seuil de 1,5 est celui que la littérature retient
/// pour le dire. Le calcul vivait dans une propriété de `StatsView`, où il n'était vérifiable
/// qu'en accumulant huit semaines de vraies courses.
enum TrainingLoad {
    /// Au-delà : la semaine pèse nettement plus lourd que l'habitude.
    static let highRatio: Double = 1.5
    /// En dessous : une semaine de récupération, ou un arrêt.
    static let lowRatio: Double = 0.8
    /// Nombre de semaines qui définissent « l'habitude ».
    static let chronicWeeks = 4

    enum Zone: Equatable {
        case low, optimal, high

        /// La CLÉ du catalogue, jamais une chaîne déjà traduite.
        ///
        /// Les libellés partaient dans `StatChip`, qui les passe à `LocalizedStringKey` — donc les
        /// traduit lui-même. Deux d'entre eux arrivaient pourtant déjà traduits par
        /// `String(localized:)` : traduits une première fois, puis cherchés comme clé. En français
        /// le résultat est correct par identité, ailleurs il l'était par chance. Le troisième,
        /// écrit brut, était le seul juste.
        var labelKey: String {
            switch self {
            case .low: return "Charge faible"
            case .optimal: return "Zone optimale"
            case .high: return "Charge élevée"
            }
        }
    }

    /// `nil` quand il n'y a pas encore de quoi comparer — moins de quatre semaines d'historique,
    /// ou quatre semaines à zéro kilomètre. Un rapport calculé sur rien vaut moins que pas de
    /// rapport du tout : il donnerait une alerte, ou un feu vert, sans fondement.
    ///
    /// `weeklyKm` est ordonné de la plus ancienne à la plus récente, la dernière étant la semaine
    /// en cours.
    static func acuteChronicRatio(weeklyKm: [Double]) -> Double? {
        guard weeklyKm.count >= chronicWeeks, let acute = weeklyKm.last else { return nil }
        // La moyenne inclut la semaine en cours, ce qui amortit le rapport : une semaine deux fois
        // plus lourde que les trois précédentes ne sort pas à 2,0 mais à 1,6. C'est le
        // comportement d'origine, conservé tel quel — le déplacer changerait le seuil auquel
        // l'alerte se déclenche, et ce choix-là appartient à l'entraînement, pas au remaniement.
        let window = weeklyKm.suffix(chronicWeeks)
        let average = window.reduce(0, +) / Double(window.count)
        guard average > 0 else { return nil }
        return acute / average
    }

    static func zone(for ratio: Double) -> Zone {
        if ratio > highRatio { return .high }
        if ratio < lowRatio { return .low }
        return .optimal
    }
}
