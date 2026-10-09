import Foundation

/// Les quatre formats du triathlon, et la question de natation qui décide du reste.
///
/// # POURQUOI CE FICHIER EXISTE À PART
///
/// Un triathlon n'est pas une course avec deux disciplines en plus. C'est trois épreuves dont
/// la plus courte est celle que l'app ne sait pas mesurer, et dont l'ordre ne change jamais :
/// on nage, puis on roule, puis on court — fatiguée de la précédente à chaque fois. Un plan qui
/// traiterait les trois comme trois entraînements séparés produirait quelqu'un capable de faire
/// chaque épreuve, et incapable de les enchaîner.
///
/// Les distances sont fixées par les fédérations et ne se discutent pas. Elles vivent ici, en un
/// seul endroit, parce que tout le reste en découle : le temps d'effort estimé, le volume de
/// chaque discipline dans la semaine, la place de l'enchaînement vélo→course, et le contenu du
/// jour J.
///
/// # LES NOMS
///
/// Les libellés sont ceux des fédérations — Sprint, Olympique, Half, Longue distance. Les noms
/// commerciaux que tout le monde emploie (« 70.3 », « Ironman ») sont des marques déposées, et
/// les écrire dans une app qui n'a aucun lien avec leur propriétaire serait au mieux ambigu. Les
/// trois distances sont affichées sous chaque format : quelqu'un qui cherche son 70.3 reconnaît
/// « 1900 m · 90 km · 21,1 km » sans hésiter une seconde.
enum TriathlonFormat: String, Codable, CaseIterable, Identifiable {
    case sprint, olympique, half, longueDistance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sprint: return String(localized: "Sprint")
        case .olympique: return String(localized: "Olympique")
        case .half: return "Half"
        case .longueDistance: return String(localized: "Longue distance")
        }
    }

    /// La natation en MÈTRES, le reste en kilomètres — c'est ainsi que les trois épreuves se
    /// disent, et c'est aussi la règle que `Discipline.uniteDeSaisie` applique partout ailleurs
    /// dans l'app. Personne n'annonce « 1,9 km de natation ».
    var nageMetres: Int {
        switch self {
        case .sprint: return 750
        case .olympique: return 1500
        case .half: return 1900
        case .longueDistance: return 3800
        }
    }

    var veloKm: Double {
        switch self {
        case .sprint: return 20
        case .olympique: return 40
        case .half: return 90
        case .longueDistance: return 180
        }
    }

    /// Les distances exactes, pas arrondies : un half finit sur un semi (21,0975 km) et une
    /// longue distance sur un marathon (42,195 km). L'arrondi coûterait cent mètres de course à
    /// pied en fin de journée, c'est-à-dire une minute debout là où elle compte le plus.
    var courseKm: Double {
        switch self {
        case .sprint: return 5
        case .olympique: return 10
        case .half: return 21.0975
        case .longueDistance: return 42.195
        }
    }

    /// « 1500 m · 40 km · 10 km ». C'est ce qui identifie un format sans employer de marque.
    var resume: String {
        "\(nageMetres) m · \(Self.km(veloKm)) · \(Self.km(courseKm))"
    }

    /// Des temps de FINISSEUR, pas des objectifs de performance — même esprit que les formats
    /// d'ultra de `RaceDistance`. Les fourchettes ont été vérifiées en simulant deux profils
    /// réalistes (une age-grouper solide et une première fois) sur les trois épreuves plus les
    /// transitions : les deux tombent dans la fourchette de chaque format.
    ///
    /// Quelqu'un de plus lent que ça sort des quatre propositions sur les trois formats courts,
    /// et c'est exactement à ça que sert « Mon propre temps » à côté.
    var chronoPresets: [String] {
        switch self {
        case .sprint: return ["1:10", "1:20", "1:30", "1:45"]
        case .olympique: return ["2:15", "2:35", "3:00", "3:30"]
        case .half: return ["5:00", "5:30", "6:15", "7:00"]
        case .longueDistance: return ["10:00", "11:30", "13:00", "15:00"]
        }
    }

    /// Le temps d'effort que ce format représente, en heures — la grandeur qui décide du volume
    /// d'entraînement, comme le kilomètre-effort le fait pour l'ultra (voir `UltraTrail`).
    ///
    /// Le milieu de la fourchette des temps de finisseur, et non le meilleur : un plan se
    /// dimensionne sur la journée qu'elle va vraiment vivre.
    var heuresDeffort: Double {
        switch self {
        case .sprint: return 1.5
        case .olympique: return 3
        case .half: return 6
        case .longueDistance: return 12.5
        }
    }

    /// « 20 km », « 21,1 km » — le zéro décimal inutile tombe, et la virgule suit la langue de
    /// l'appareil. Un « 21.1 km » dans une app en français est le genre de détail qui fait
    /// douter du reste.
    private static func km(_ valeur: Double) -> String {
        let arrondi = (valeur * 10).rounded() / 10
        return arrondi == arrondi.rounded()
            ? String(format: "%.0f km", locale: Locale.current, arrondi)
            : String(format: "%.1f km", locale: Locale.current, arrondi)
    }
}

/// CE QU'ELLE SAIT NAGER AUJOURD'HUI, ET PAS CE QU'ELLE VISE.
///
/// # LA SEULE QUESTION QUI PEUT FAIRE DU MAL
///
/// Les autres questions de l'inscription dimensionnent un plan : se tromper donne un programme
/// trop facile ou trop dur, et il s'ajuste. Celle-ci est différente. Prescrire « 1500 m en
/// continu » à quelqu'un qui n'a jamais enchaîné plus de deux longueurs, ce n'est pas un plan
/// trop dur — c'est quelqu'un seule au milieu d'un bassin, ou pire, d'un lac.
///
/// La natation est aussi la seule des trois disciplines où l'app ne voit RIEN : pas de GPS sous
/// l'eau, pas de cadence, pas d'allure en direct, aucune façon de s'apercevoir que la séance
/// s'est mal passée. Le plan ne peut donc pas se corriger tout seul comme il le fait pour la
/// course. Il n'a qu'une occasion de poser la question, et c'est maintenant.
///
/// # POURQUOI « JE NE NAGE PAS ENCORE » EST UNE RÉPONSE ET PAS UN REFUS
///
/// Parce que c'est vrai pour beaucoup de gens qui s'inscrivent à leur premier triathlon, et
/// parce qu'une app qui ferme la porte à cette réponse obtient simplement une réponse fausse à
/// la place. Le plan construit alors un volume de natation faux, et personne ne saura pourquoi.
enum NiveauDeNage: String, Codable, CaseIterable, Identifiable {
    case pasEncore, moins200, jusqua800, plus1500

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pasEncore: return String(localized: "Je ne nage pas encore")
        case .moins200: return String(localized: "Moins de 200 m d'affilée")
        case .jusqua800: return String(localized: "400 à 800 m")
        case .plus1500: return String(localized: "1500 m et plus")
        }
    }

    var subtitle: String {
        switch self {
        case .pasEncore: return String(localized: "On commencera par apprendre à durer dans l'eau")
        case .moins200: return String(localized: "Quelques longueurs, avec des pauses")
        case .jusqua800: return String(localized: "Je tiens une vraie série sans m'arrêter")
        case .plus1500: return String(localized: "La distance olympique ne me fait pas peur")
        }
    }

    /// Ce qu'elle tient en continu, en mètres. `nil` pour « je ne nage pas encore » : ce n'est
    /// pas zéro, c'est l'absence de repère — et un zéro se glisserait dans un calcul de volume
    /// comme s'il en était un.
    var metresEnContinu: Int? {
        switch self {
        case .pasEncore: return nil
        case .moins200: return 150
        case .jusqua800: return 600
        case .plus1500: return 1500
        }
    }

    /// L'écart entre ce format et ce qu'elle nage aujourd'hui est-il de ceux qu'il faut DIRE ?
    ///
    /// Un facteur trois. En dessous, c'est une progression ordinaire sur une préparation. Au-delà,
    /// ce n'est plus de l'entraînement, c'est un apprentissage — et il demande un bassin, un
    /// maître-nageur et des mois, pas une case de plus dans un plan hebdomadaire.
    ///
    /// Le but n'est PAS d'interdire le format. C'est son objectif, et c'est sa décision. Le but
    /// est qu'elle le choisisse en connaissant le nombre.
    func ecartNotable(pour format: TriathlonFormat) -> Bool {
        guard let metres = metresEnContinu else { return true }
        return format.nageMetres > metres * 3
    }
}
