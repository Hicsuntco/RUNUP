import Foundation

/// Ce qui remplace le kilomètre quand on prépare un ultra.
///
/// # LE PROBLÈME, EN UNE LIGNE
///
/// Tout le moteur de plan raisonne en KILOMÈTRES à allure de route. `longRunDuration(km)` multiplie
/// une distance par une allure plate, et le bloc spécifique vise `min(raceKm × 0,8, 30)`.
///
/// Appliqué à un 80 km avec 4 000 m de dénivelé, ça donne une sortie longue de 30 km annoncée à
/// trois heures — alors qu'en montagne ces trente kilomètres-là en prennent cinq. Le plan
/// prescrirait donc des séances dont il ignore la durée réelle, et la seule mesure qui compte en
/// ultra — le TEMPS passé debout — n'apparaîtrait nulle part.
///
/// # LE KILOMÈTRE-EFFORT
///
/// La convention des coureurs de trail : **cent mètres de dénivelé coûtent un kilomètre de plat**.
/// Un 80 km avec 4 000 m de D+ vaut donc 80 + 40 = 120 kilomètres-effort.
///
/// Ce n'est pas une loi de la physique, c'est une règle de terrain — mais c'est CELLE QUE LES
/// COUREURS EMPLOIENT, donc celle avec laquelle un plan peut dialoguer. Une formule plus savante
/// (Naismith, Minetti) serait plus juste en laboratoire et illisible sur un plan de la semaine.
///
/// Avec elle, une seule multiplication redonne au moteur ce qu'il sait déjà faire : du temps.
///
/// # ET POURQUOI LA RAMPE N'A PAS EU À CHANGER
///
/// `AdaptivePlanEngine.rampedLongRunKm` ne sait pas ce qu'elle rampe : elle prend un départ, une
/// cible, et ne dépasse jamais +10 % par semaine. Elle vaut donc pour des kilomètres, des minutes
/// ou des mètres de dénivelé sans qu'on y touche. Tout ce qui manquait était la QUANTITÉ à lui
/// donner — ce fichier la calcule, et le garde-fou anti-blessure continue de s'appliquer tel quel,
/// dans la nouvelle unité.
enum UltraTrail {

    /// Cent mètres de D+ valent un kilomètre de plat.
    static let metresParKilometreEffort: Double = 100

    /// La distance à plat qui coûterait le même effort.
    static func kilometresEffort(km: Double, denivelePositifM: Double) -> Double {
        max(0, km) + max(0, denivelePositifM) / metresParKilometreEffort
    }

    /// Le temps passé debout, en secondes, pour une sortie donnée.
    ///
    /// L'allure est celle du footing — en ultra on ne court pas plus vite que ça, et on marche les
    /// montées raides, ce que le kilomètre-effort compte déjà.
    static func tempsDeffortSecondes(km: Double, denivelePositifM: Double,
                                     allureFacileSecParKm: Double) -> Double {
        kilometresEffort(km: km, denivelePositifM: denivelePositifM) * max(0, allureFacileSecParKm)
    }

    // MARK: La sortie longue, en TEMPS

    /// Les trois blocs, et ce qu'ils visent.
    ///
    /// EN TEMPS ET PLAFONNÉ, parce que c'est ainsi que s'écrit un plan d'ultra. On ne court pas
    /// cent kilomètres à l'entraînement : la plus longue sortie d'une préparation de 100 km tourne
    /// autour de cinq à six heures. Ce qui construit le reste est la répétition et l'enchaînement,
    /// pas une sortie héroïque de plus.
    ///
    /// Chacun porte SA fraction, SON plancher et SON plafond — et pas un plancher commun, qui
    /// était la première version et qui était fausse. Avec un plancher unique, une course courte
    /// voyait sa fraction d'affûtage passer sous le seuil et remonter à la même valeur que le bloc
    /// de base : l'affûtage prescrivait alors la même sortie longue que le bloc qu'il est censé
    /// alléger. Trois jeux de bornes, ordonnés, rendent cette inversion impossible — et
    /// `UltraTrailTests` l'exige pour toute course plausible.
    enum Bloc {
        case base, specifique, affutage

        /// La part du temps d'effort de la COURSE que vise la sortie longue.
        ///
        /// On ne s'approche jamais de la durée de l'épreuve : ce qui construit un ultra est la
        /// répétition et l'enchaînement, pas une sortie héroïque de plus.
        var fraction: Double {
            switch self {
            case .base: return 0.30
            case .specifique: return 0.55
            case .affutage: return 0.20
            }
        }

        /// En dessous, ce n'est plus la sortie longue de ce bloc-là.
        var plancherSecondes: Double {
            switch self {
            case .base: return 75 * 60
            case .specifique: return 90 * 60
            case .affutage: return 45 * 60
            }
        }

        /// Au-delà, le plan prescrirait une séance que personne ne fait. Sans plafond, un 170 km
        /// avec 10 000 m de D+ donnerait une « sortie longue » de quinze heures.
        var plafondSecondes: Double {
            switch self {
            case .base: return 3 * 3600
            case .specifique: return 6 * 3600
            case .affutage: return 2 * 3600
            }
        }
    }

    /// Le temps d'effort visé par la sortie longue, selon le bloc.
    static func cibleSortieLongueSecondes(tempsDeffortCourseSecondes: Double,
                                          bloc: Bloc) -> Double {
        let brut = max(0, tempsDeffortCourseSecondes) * bloc.fraction
        return min(max(brut, bloc.plancherSecondes), bloc.plafondSecondes)
    }

    // MARK: Le dénivelé de la séance

    /// Le D+ que la sortie longue doit contenir, en mètres.
    ///
    /// Proportionnel à la DENSITÉ de dénivelé de la course, pas à son total : un 80 km avec
    /// 4 000 m (50 m/km) et un 80 km avec 800 m (10 m/km) ne demandent pas la même préparation,
    /// et c'est le mètre par kilomètre qui le dit. La sortie longue reproduit cette densité sur sa
    /// propre distance.
    ///
    /// Plafonné à 2 000 m : au-delà, on ne trouve plus le terrain, et le plan prescrirait une
    /// séance que personne ne peut faire — ce qui est la façon la plus sûre de faire abandonner
    /// un plan.
    static func deniveleSortieLongueM(densiteCourseMParKm: Double, kmDeLaSortie: Double) -> Double {
        min(max(0, densiteCourseMParKm) * max(0, kmDeLaSortie), 2000)
    }

    /// Mètres de D+ par kilomètre. Zéro quand la course n'en déclare pas — une course plate est
    /// une réponse, pas une absence de réponse.
    static func densite(km: Double, denivelePositifM: Double) -> Double {
        guard km > 0 else { return 0 }
        return max(0, denivelePositifM) / km
    }

    // MARK: L'enchaînement du week-end

    /// La seconde sortie d'un week-end enchaîné, en secondes.
    ///
    /// # POURQUOI CE N'EST PAS UNE SORTIE LONGUE DE PLUS
    ///
    /// Le « back-to-back » est la séance signature de l'ultra, et sa raison d'être est précise :
    /// partir le dimanche sur des jambes déjà entamées reproduit la deuxième moitié de l'épreuve,
    /// que personne ne peut reproduire autrement sans courir huit heures d'affilée.
    ///
    /// Soixante pour cent de la veille : assez long pour que la fatigue soit le sujet, assez court
    /// pour que la semaine suivante existe encore. Deux sorties égales deux jours de suite est la
    /// façon classique de se blesser en préparant un ultra.
    static let fractionDuSecondJour: Double = 0.60

    static func secondJourSecondes(premierJourSecondes: Double) -> Double {
        max(0, premierJourSecondes) * fractionDuSecondJour
    }

    /// À partir de quelle durée de course l'enchaînement a du sens.
    ///
    /// Sous les quatre heures d'effort, l'épreuve ne demande pas d'apprendre à repartir sur des
    /// jambes mortes : un marathon de montagne se prépare avec des sorties longues ordinaires.
    /// Prescrire un enchaînement à quelqu'un qui n'en a pas besoin, c'est lui coûter un week-end
    /// entier pour rien.
    static let seuilDenchainementSecondes: Double = 4 * 3600

    static func demandeUnEnchainement(tempsDeffortCourseSecondes: Double) -> Bool {
        tempsDeffortCourseSecondes >= seuilDenchainementSecondes
    }
}
