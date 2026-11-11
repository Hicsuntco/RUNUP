import Foundation

/// POURQUOI CETTE SÉANCE, AUJOURD'HUI — une phrase, tirée de ce que le moteur a décidé.
///
/// # CE QUI EXISTAIT, ET CE QUI MANQUAIT
///
/// L'app disait déjà pourquoi une séance avait été ALLÉGÉE : `adjustment` porte « Allégée · nuit
/// courte », `adaptationNote` porte « adapté à ta cheville sensible · impact réduit ». La carte
/// d'accueil les affiche en une ligne sous le titre, et son commentaire dit la bonne chose :
/// « voici la séance, voici pourquoi elle est ce qu'elle est ».
///
/// Mais ces lignes n'existent que les jours où le moteur corrige. Les autres jours — la grande
/// majorité — l'app affiche une séance et se tait sur la raison. Or le moteur en a une : il sait
/// dans quel bloc on est, qu'une semaine sur quatre est allégée, combien de semaines restent, et
/// à quelle distance est la course.
///
/// # LA CONDITION, ET POURQUOI ELLE EST DURE
///
/// `PHASE2.md` pose la condition en toutes lettres : « à condition que la phrase vienne du moteur
/// et pas d'un catalogue de phrases. Sinon c'est un texte générique, donc un défaut. »
///
/// Une phrase par bloc serait exactement ce catalogue. Ce qui l'en sépare : **chaque phrase porte
/// un nombre de CE plan** — le numéro de semaine, le total, les jours avant la course. Deux
/// coureuses dans le même bloc ne lisent pas la même phrase, parce qu'elles ne sont pas à la même
/// semaine. Une phrase sans nombre a été écartée à chaque fois ; là où le moteur n'a rien de
/// chiffré à dire, cette fonction rend `nil` et l'écran se tait.
///
/// # CE QU'ELLE NE FAIT PAS
///
/// Elle ne parle JAMAIS par-dessus une correction. Si le moteur a allégé la séance, c'est ça, la
/// raison du jour : `adjustment` a la priorité, et cette fonction rend `nil`. Deux explications
/// empilées sur la même carte, c'est une de trop.
///
/// Elle ne dit rien non plus un jour de repos : la carte affiche « REPOS » et porte déjà sa
/// propre ligne.
enum PourquoiCetteSeance {

    /// Ce que le moteur sait, et rien d'autre. Aucun type de SwiftUI, aucune base de données :
    /// c'est ce qui rend la décision éprouvable sans ouvrir l'app.
    struct Contexte {
        var bloc: AdaptivePlanEngine.TrainingBlock
        var semaine: Int
        var semainesEnTout: Int?
        /// Jours avant la course, quand il y en a une. Négatif ou nul : la course est passée.
        var joursAvantLaCourse: Int?
        /// La séance a déjà été corrigée par le moteur — fatigue, blessure, semaine chargée.
        var dejaExplique: Bool
        var estUnJourDeRepos: Bool
    }

    /// La phrase, ou `nil` quand il n'y a rien de vrai et de chiffré à dire.
    static func phrase(_ c: Contexte) -> String? {
        // UNE CORRECTION EXPLIQUE DÉJÀ LA JOURNÉE. Elle est plus précise que n'importe quelle
        // phrase de bloc — « nuit courte » bat « bloc spécifique » — et deux explications
        // empilées sur la même carte, c'est une de trop.
        if c.dejaExplique || c.estUnJourDeRepos { return nil }

        switch c.bloc {
        case .deload:
            // La règle est dans `trainingBlock` : `week % 4 == 0` à l'intérieur du bloc de
            // construction. La phrase dit la règle, avec le numéro réel de la semaine.
            return String(localized: "Semaine \(c.semaine) : une semaine sur quatre est allégée, pour que les trois suivantes tiennent.")

        case .affutage:
            // L'affûtage ne se comprend que par rapport à une date. Sans elle, on se tait.
            guard let jours = c.joursAvantLaCourse, jours > 0 else { return nil }
            return String(localized: "Affûtage, J-\(jours) : le volume baisse, l'intensité reste. C'est la fatigue qu'on enlève, pas la forme.")

        case .specifique:
            guard let total = c.semainesEnTout, total > 0 else { return nil }
            return String(localized: "Semaine \(c.semaine) sur \(total), bloc spécifique : les séances ressemblent de plus en plus à ta course.")

        case .base:
            guard let total = c.semainesEnTout, total > 0 else { return nil }
            return String(localized: "Semaine \(c.semaine) sur \(total), bloc de base : on construit le volume avant de le spécialiser.")
        }
    }
}
