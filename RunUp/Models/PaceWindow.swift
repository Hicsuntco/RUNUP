import Foundation

/// L'allure récente, séparée de l'écran qui l'affiche et de la voix qui la commente.
///
/// Il y en avait deux, et elles ne disaient pas la même chose. L'écran de course montrait la
/// moyenne de toute la sortie — un chiffre qui, passé la vingtième minute, ne bouge plus de
/// quelques secondes même quand elle change franchement de rythme. La voix du coach, elle,
/// comparait une fenêtre de trente secondes à l'allure cible. Résultat : le coach disait
/// « accélère un peu » pendant que le seul chiffre affiché sous l'étiquette ALLURE restait
/// rigoureusement immobile. Sur l'unique écran qu'on regarde en courant, essoufflée, c'est la
/// contradiction la plus coûteuse qu'on puisse poser.
///
/// Une seule source désormais, et trois principes :
///
/// 1. **La fenêtre glisse, elle ne se vide pas.** L'alerte utilisait une fenêtre qui repartait
///    de zéro toutes les trente secondes : juste après la remise à zéro, la distance parcourue
///    valait quelques mètres et l'allure calculée dessus n'importe quoi — inoffensif pour une
///    alerte qui n'écoutait qu'en fin de fenêtre, mais inaffichable. Ici les échantillons sont
///    gardés et les plus vieux tombent un par un : la fenêtre fait toujours trente secondes et
///    l'allure est lisible à chaque seconde.
///
/// 2. **Une fenêtre trop courte ne donne pas d'allure.** Deux secondes et dix mètres donnent un
///    nombre, pas une allure. Sous `displayMinimumSeconds`, on ne montre rien — c'est le même
///    refus que `heartRate` à `nil` plutôt qu'un « 0 bpm ».
///
/// 3. **L'écran et la voix lisent la même règle.** `standing(secPerKm:target:)` est la seule
///    comparaison à la cible, avec la seule tolérance. Le chiffre ne peut plus passer à l'ambre
///    sans que la consigne vocale soit d'accord, ni l'inverse.
enum PaceWindow {
    /// Trente secondes : assez long pour que le bruit de foulée à foulée s'efface, assez court
    /// pour qu'un changement de rythme se voie avant d'être fini.
    static let spanSeconds: Double = 30
    /// Ce qu'il faut de fenêtre pour afficher un chiffre. Dix secondes de course, à n'importe
    /// quelle allure humaine, font déjà plus de vingt mètres.
    static let displayMinimumSeconds: Double = 10
    /// Ce qu'il faut de fenêtre pour parler. Plus exigeant que l'affichage : un chiffre qu'on
    /// peut ignorer d'un coup d'œil coûte moins cher qu'une voix dans les oreilles.
    ///
    /// Volontairement un peu sous `spanSeconds` : les échantillons arrivent à la seconde et la
    /// fenêtre n'atteint donc jamais trente secondes pile.
    static let alertMinimumSeconds: Double = 25
    /// Une vraie tolérance d'entraîneur, pas un détecteur de bruit : la dérive normale d'une
    /// foulée ne doit pas la faire changer de couleur toutes les trente secondes.
    static let toleranceSecPerKm: Double = 20
    /// Vingt mètres. En dessous, la fenêtre décrit un arrêt, un accrochage GPS ou un tapis de
    /// course — pas une allure.
    static let minimumDistanceKm: Double = 0.02

    struct Sample: Equatable {
        var elapsed: Double
        var km: Double
    }

    struct State: Equatable {
        fileprivate(set) var samples: [Sample] = []
    }

    /// Un tour d'horloge. `elapsed` est le temps de course (hors pauses), `km` la distance GPS.
    static func record(_ state: inout State, elapsed: Double, km: Double) {
        state.samples.append(Sample(elapsed: elapsed, km: km))
        // On garde le plus vieil échantillon ENCORE utile : celui juste avant le début de la
        // fenêtre. Tant que le suivant est lui aussi assez vieux, le premier ne sert plus.
        while state.samples.count > 2, elapsed - state.samples[1].elapsed >= spanSeconds {
            state.samples.removeFirst()
        }
    }

    /// Les secondes par kilomètre sur la fenêtre, ou `nil` quand elle ne permet pas de le dire.
    static func secPerKm(_ state: State, minimumSeconds: Double) -> Double? {
        guard let first = state.samples.first, let last = state.samples.last else { return nil }
        let seconds = last.elapsed - first.elapsed
        let km = last.km - first.km
        guard seconds >= minimumSeconds, km >= minimumDistanceKm else { return nil }
        return seconds / km
    }

    /// Où elle en est par rapport à la consigne du jour.
    enum Standing: Equatable {
        /// Pas de cible, ou pas encore d'allure : il n'y a rien à comparer.
        case unknown
        case onTarget
        /// Plus lente que la cible de plus que la tolérance.
        case tooSlow
        case tooFast
    }

    static func standing(secPerKm: Double?, target: Double?) -> Standing {
        guard let secPerKm, let target else { return .unknown }
        let delta = secPerKm - target
        if delta > toleranceSecPerKm { return .tooSlow }
        if delta < -toleranceSecPerKm { return .tooFast }
        return .onTarget
    }
}
