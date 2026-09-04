import Foundation

/// Les cinq chiffres qu'une course produit, et qui peuvent donc s'afficher sur la montre.
///
/// C'est une liste FERMÉE, et volontairement courte : elle ne contient que ce que
/// `WatchWorkoutManager` mesure réellement. Y ajouter « dénivelé » ou « cadence » demanderait
/// d'abord de les mesurer — proposer un réglage pour un chiffre qui n'existe pas produirait un
/// écran avec un tiret permanent à la place.
enum RunMetric: String, Codable, CaseIterable, Sendable {
    case time, distance, pace, heartRate, calories

    /// L'unité, sous le chiffre. Ce sont des CLÉS du catalogue, pas des libellés : elles passent
    /// par `LocalizedStringKey` à l'affichage.
    var unitKey: String {
        switch self {
        case .time: return "Temps"
        case .distance: return "km"
        case .pace: return "/km"
        case .heartRate: return "bpm"
        case .calories: return "kcal"
        }
    }

    /// Le nom entier, pour la liste de réglages — « /km » ne se choisit pas dans un menu.
    var nameKey: String {
        switch self {
        case .time: return "Temps"
        case .distance: return "Distance"
        case .pace: return "Allure"
        case .heartRate: return "Cardio"
        case .calories: return "Calories"
        }
    }
}

/// Ce que la coureuse veut voir pendant sa course, et à quelle place.
///
/// # Pourquoi le réglage vit sur le téléphone
///
/// La montre n'a pas de clavier, et personne ne configure son affichage en courant. Le réglage se
/// prend donc dans l'app, et voyage par le canal qui pousse déjà la séance du jour
/// (`updateApplicationContext`) — dont la sémantique « dernier état connu » est exactement celle
/// d'un réglage : pas de file de valeurs périmées à rejouer, juste la dernière qui compte.
///
/// # Ce qui ne se règle pas
///
/// La barre de progression suit la DURÉE de la séance, quel que soit le héros choisi. C'est le
/// seul objectif qu'une séance porte réellement — elles sont définies en minutes, jamais en
/// kilomètres. Une barre qui suivrait la distance avancerait vers un but qui n'existe pas.
struct WatchRunLayout: Codable, Equatable, Sendable {
    /// Le grand chiffre, celui qu'on lit le bras qui balance.
    var hero: RunMetric
    /// Les trois petits, sous lui. Exactement trois : deux laissent un vide, quatre redonnent
    /// l'écran encombré qu'on vient de quitter.
    var secondary: [RunMetric]

    static let secondaryCount = 3

    /// Le défaut, et le repli de tout ce qui ne se décode pas : le temps en héros, puis distance,
    /// allure, cardio. C'est la disposition choisie sur maquette.
    static let standard = WatchRunLayout(hero: .time, secondary: [.distance, .pace, .heartRate])

    /// L'ordre dans lequel on complète une sélection incomplète. Fixe, pour qu'un même réglage
    /// tronqué donne toujours le même écran.
    private static let fillOrder: [RunMetric] = [.distance, .pace, .heartRate, .calories, .time]

    /// Ramène n'importe quelle sélection à une disposition affichable.
    ///
    /// Trois choses ne doivent pas être représentables, et aucune n'est théorique : le héros qui
    /// se répète en bas (on lirait deux fois le même chiffre), un doublon dans les trois petits,
    /// et un compte différent de trois. La dernière arrive dès qu'on décode un réglage écrit par
    /// une version plus ancienne ou plus récente de l'app.
    static func sanitized(hero: RunMetric, secondary: [RunMetric]) -> WatchRunLayout {
        var kept: [RunMetric] = []
        for metric in secondary where metric != hero && !kept.contains(metric) {
            kept.append(metric)
            if kept.count == secondaryCount { break }
        }
        for metric in fillOrder where kept.count < secondaryCount {
            if metric != hero && !kept.contains(metric) { kept.append(metric) }
        }
        return WatchRunLayout(hero: hero, secondary: kept)
    }

    // MARK: Le format de transport

    /// « time|distance,pace,heartRate ».
    ///
    /// Une chaîne, et non du JSON, parce que le contexte poussé à la montre est un
    /// `[String: String]` : y glisser un blob encodé demanderait de le désencoder des deux côtés
    /// pour trois valeurs énumérées. Ce format-ci se lit dans un journal de débogage.
    var wireValue: String {
        hero.rawValue + "|" + secondary.map(\.rawValue).joined(separator: ",")
    }

    /// Rend `nil` quand la chaîne n'est pas exploitable — l'appelant retombe alors sur `standard`
    /// plutôt que d'afficher un écran à moitié construit.
    init?(wireValue: String) {
        let halves = wireValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard halves.count == 2, let hero = RunMetric(rawValue: String(halves[0])) else { return nil }
        let secondary = halves[1]
            .split(separator: ",", omittingEmptySubsequences: true)
            .compactMap { RunMetric(rawValue: String($0)) }
        self = Self.sanitized(hero: hero, secondary: secondary)
    }

    init(hero: RunMetric, secondary: [RunMetric]) {
        self.hero = hero
        self.secondary = secondary
    }
}
