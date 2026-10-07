import Foundation

/// Ce qu'on a fait : courir, ou rouler.
///
/// # POURQUOI CE TYPE EXISTE, ET POURQUOI IL EST DANGEREUX DE L'OUBLIER
///
/// Jusqu'ici l'app n'avait qu'une discipline, donc aucun endroit n'avait à le dire. Treize
/// agrégations somment `distanceKm` sur tous les relevés, les records personnels cherchent la
/// plus longue et la plus rapide, la série compte les jours, les chaussures accumulent leur
/// kilométrage, et le moteur de plan coche la séance du jour. Aucune de ces treize ne pose de
/// question : elles ont toujours eu raison, parce qu'il n'y avait rien d'autre à compter.
///
/// La première sortie vélo les rend toutes fausses **en silence**. Quarante kilomètres entrent
/// dans la distance courue du mois, la meilleure allure devient une vitesse de vélo que personne
/// ne battra jamais à pied, les chaussures vieillissent sans avoir touché le sol, et la séance de
/// course du jour se coche toute seule. Rien ne casse, rien ne s'affiche en rouge : les chiffres
/// deviennent simplement faux, et on ne s'en aperçoit que des semaines plus tard, quand plus
/// personne ne sait ce qui était vrai.
///
/// D'où la règle, tenue par `ci_scripts/check_disciplines.py` : **une somme sur des relevés
/// passe par `Array<RunRecord>.only(_:)`, jamais sur le tableau nu.** Le filtre devient
/// impossible à oublier parce qu'il est impossible à sauter.
///
/// # CE QUI N'EST PAS ICI
///
/// La natation. Elle n'a pas de GPS en bassin — il lui faut la détection de longueurs de
/// HealthKit et un écran de course entièrement différent. L'ajouter à cette énumération sans ça
/// donnerait une discipline qui ne sait rien mesurer.
enum Discipline: String, Codable, Equatable, CaseIterable {
    case run = "run"
    case bike = "bike"

    /// La discipline des relevés écrits avant que ce champ n'existe. Ils sont tous des courses,
    /// par construction : l'app ne savait rien faire d'autre.
    static let legacy: Discipline = .run

    var title: String {
        switch self {
        case .run: return String(localized: "Course")
        case .bike: return String(localized: "Vélo")
        }
    }

    var sfSymbol: String {
        switch self {
        case .run: return "figure.run"
        case .bike: return "bicycle"
        }
    }

    /// Course : des minutes par kilomètre. Vélo : des kilomètres par heure.
    ///
    /// Ce n'est pas une préférence d'affichage, c'est la grandeur que la discipline rend
    /// lisible. « 2:30/km » à vélo est juste et illisible ; « 24 km/h » à pied l'est tout autant.
    var usesPacePerKm: Bool { self == .run }

    /// Les chaussures de course ne s'usent pas à vélo.
    var wearsShoes: Bool { self == .run }

    /// Une sortie vélo ne coche pas la séance de course du jour. Le plan est un plan de COURSE —
    /// tant qu'il n'y a pas de plan triathlon, rouler ne remplit aucune de ses cases.
    var completesRunningPlan: Bool { self == .run }

    /// Les deux disciplines comptent pour la série et les anneaux du jour : elles mesurent
    /// l'ASSIDUITÉ, pas le kilométrage de course. Quelqu'un qui roule une heure n'a pas rien fait.
    var countsTowardStreak: Bool { true }
}

extension Array where Element == RunRecord {
    /// LE SEUL PASSAGE pour agréger des relevés.
    ///
    /// Écrire `runs.reduce(0) { $0 + $1.distanceKm }` était juste tant qu'il n'y avait qu'une
    /// discipline, et devient faux sans prévenir le jour où il y en a deux. Passer par ici force
    /// à répondre à la question « de quoi parle ce total ? » — et `check_disciplines.py` refuse
    /// les sommes qui ne sont pas passées par là.
    func only(_ discipline: Discipline) -> [RunRecord] {
        filter { $0.discipline == discipline }
    }

    /// Quand le total porte bien sur TOUT, disciplines confondues — l'assiduité, la série, le
    /// nombre de jours actifs. Explicite exprès : « toutes » doit être une décision écrite, pas
    /// l'absence de décision.
    var allDisciplines: [RunRecord] { self }
}
