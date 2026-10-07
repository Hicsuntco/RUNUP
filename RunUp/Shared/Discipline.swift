import Foundation

/// Ce qu'on a fait : courir sur route, rouler, ou courir en trail.
///
/// # OÙ VIT CE FICHIER, ET POURQUOI
///
/// Dans `Shared`, et pas dans `Models`, parce que `TimeFormat` le référence — et `TimeFormat`
/// est compilé par les trois cibles : l'app, le widget et la montre. Laissé dans `Models`, que
/// ces deux-là ne compilent pas, il faisait échouer leur construction sur un type introuvable.
/// Ce fichier ne dépend donc de rien d'autre que Foundation ; le filtre sur les tableaux de
/// relevés, lui, parle de `RunRecord` et reste dans `Models`.
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
///
/// Et un plan triathlon. Il n'y en a pas : le plan de RUNUP est un plan de course, et ce sont
/// trois disciplines de relevé, pas un programme multisport.
///
/// # POURQUOI CHAQUE DRAPEAU EST UN `switch` EXHAUSTIF
///
/// Ils étaient écrits `self == .run`. C'est juste tant qu'il n'y a que la course et le vélo, et
/// ça devient faux SANS QUE RIEN NE COMPILE EN ROUGE à la troisième discipline : le trail serait
/// arrivé avec `wearsShoes` à faux, `completesRunningPlan` à faux et `usesPacePerKm` à faux —
/// une discipline à pied qui n'use pas de chaussures, ne coche aucune séance et s'affiche en
/// km/h. Aucune erreur de compilation, aucune alerte, juste un mode qui ne marche pas.
///
/// Un `switch` sans `default` déplace la décision au seul endroit où elle est prise correctement :
/// le compilateur. Ajouter la natation fera échouer la construction sur chacun de ces drapeaux,
/// l'un après l'autre, jusqu'à ce que quelqu'un ait répondu pour chacun. La règle est tenue par
/// `ci_scripts/check_disciplines.py`, qui refuse un drapeau de `Discipline` écrit avec `==`.
enum Discipline: String, Codable, Equatable, CaseIterable {
    case run = "run"
    case bike = "bike"
    case trail = "trail"

    /// La discipline des relevés écrits avant que ce champ n'existe. Ils sont tous des courses,
    /// par construction : l'app ne savait rien faire d'autre.
    static let legacy: Discipline = .run

    var title: String {
        switch self {
        case .run: return String(localized: "Course")
        case .bike: return String(localized: "Vélo")
        case .trail: return String(localized: "Trail")
        }
    }

    /// Le libellé court du bouton de départ, en capitales. Séparé de `title` parce que ce n'est
    /// pas le même texte : « RUN » là où `title` dit « Course », parce que c'est le mot qui est
    /// sur ce bouton depuis le premier jour et que le changer n'apporterait rien.
    var tabLabel: String {
        switch self {
        case .run: return String(localized: "RUN")
        case .bike: return String(localized: "VÉLO")
        case .trail: return String(localized: "TRAIL")
        }
    }

    /// « Passer au vélo », « Passer au trail », « Passer à la course ».
    ///
    /// La phrase entière est une clé, pas un gabarit à trous : l'article change avec le mot, et
    /// « Passer à {Vélo} » donnerait « Passer à Vélo » en français comme dans les deux langues
    /// traduites. C'est le nom d'une action d'accessibilité, donc une phrase qu'on entend.
    var switchToLabel: String {
        switch self {
        case .run: return String(localized: "Passer à la course")
        case .bike: return String(localized: "Passer au vélo")
        case .trail: return String(localized: "Passer au trail")
        }
    }

    /// La suivante dans le cycle de l'appui long.
    ///
    /// Calculée sur `allCases`, donc l'ordre du cycle est l'ordre de déclaration et une discipline
    /// de plus s'y insère sans qu'on touche à ce calcul. Le `?? self` ne peut pas arriver — une
    /// valeur est toujours dans `allCases` — mais il évite d'écrire un `!` pour le prouver.
    var next: Discipline {
        let toutes = Self.allCases
        guard let rang = toutes.firstIndex(of: self) else { return self }
        return toutes[(rang + 1) % toutes.count]
    }

    var sfSymbol: String {
        switch self {
        case .run: return "figure.run"
        case .bike: return "bicycle"
        // `figure.hiking` plutôt qu'un second `figure.run` : c'est la seule icône du jeu système
        // qui dise le terrain, et le terrain est précisément ce qui distingue le trail.
        case .trail: return "figure.hiking"
        }
    }

    /// Course : des minutes par kilomètre. Vélo : des kilomètres par heure.
    ///
    /// Ce n'est pas une préférence d'affichage, c'est la grandeur que la discipline rend
    /// lisible. « 2:30/km » à vélo est juste et illisible ; « 24 km/h » à pied l'est tout autant.
    ///
    /// Le trail se lit en minutes par kilomètre comme la route : l'allure y est erratique, mais
    /// c'est bien une allure, et la convertir en km/h ne la rendrait pas plus lisible.
    var usesPacePerKm: Bool {
        switch self {
        case .run, .trail: return true
        case .bike: return false
        }
    }

    /// Les chaussures de course ne s'usent pas à vélo. Elles s'usent en trail — plus vite, même.
    var wearsShoes: Bool {
        switch self {
        case .run, .trail: return true
        case .bike: return false
        }
    }

    /// Une sortie vélo ne coche pas la séance de course du jour. Le plan est un plan de COURSE —
    /// tant qu'il n'y a pas de plan triathlon, rouler ne remplit aucune de ses cases.
    ///
    /// Le trail, lui, la coche : c'est de la course à pied. Une sortie trail d'une heure n'est pas
    /// un à-côté du plan, c'est la séance du jour, faite ailleurs.
    var completesRunningPlan: Bool {
        switch self {
        case .run, .trail: return true
        case .bike: return false
        }
    }

    /// Est-ce que l'allure CIBLE du plan a un sens, et la voix a-t-elle le droit de la réclamer ?
    ///
    /// C'est la question que `completesRunningPlan` ne pose pas, et il a fallu le trail pour que
    /// la différence apparaisse. Les deux ont toujours été confondues parce qu'elles n'avaient
    /// jamais divergé : courir remplit la case du jour ET se mesure à l'allure, rouler ne fait
    /// ni l'un ni l'autre. Un seul booléen suffisait.
    ///
    /// Le trail les sépare. Il remplit la case du jour — et 5:10/km n'y veut rien dire : la même
    /// foulée donne 4:20 sur le plat et 9:30 dans une montée à 15 %. Garder un seul booléen aurait
    /// donné, au choix, une sortie trail qui ne compte pas dans le plan, ou une voix qui annonce
    /// « tu es trop lente » pendant toute l'ascension — en ayant tort, et sur la portion la plus
    /// dure de la sortie.
    ///
    /// L'allure reste AFFICHÉE en trail (voir `usesPacePerKm`) : c'est une mesure, et une mesure
    /// se regarde. Ce qui se tait, c'est la cible et le jugement porté dessus.
    var followsPaceTargets: Bool {
        switch self {
        case .run: return true
        case .bike, .trail: return false
        }
    }

    /// Toutes les disciplines comptent pour la série et les anneaux du jour : elles mesurent
    /// l'ASSIDUITÉ, pas le kilométrage de course. Quelqu'un qui roule une heure n'a pas rien fait.
    var countsTowardStreak: Bool {
        switch self {
        case .run, .bike, .trail: return true
        }
    }
}
