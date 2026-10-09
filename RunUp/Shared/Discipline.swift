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
/// # LA NATATION EST ICI, ET ELLE NE SE DÉMARRE PAS
///
/// Elle était absente, avec cette raison : « pas de GPS en bassin, il lui faut la détection de
/// longueurs de HealthKit et un écran de course entièrement différent ». La raison était juste et
/// la conclusion était trop large. Une discipline n'a pas besoin de se DÉMARRER pour exister :
/// elle a besoin d'être comptée au bon endroit.
///
/// Ce qu'un téléphone ne peut pas faire, il ne le fera pas : on ne suit pas un bassin depuis une
/// poche, et l'app ne le prétend nulle part — `seDemarreDepuisLeTelephone` est faux pour la nage,
/// et le cadran du bouton RUN ne la propose donc jamais.
///
/// Elle se compte à part : pas un kilomètre dans la distance courue, pas une usure de chaussure,
/// pas une case du plan de course cochée — et une allure en minutes aux CENT MÈTRES, qui est la
/// seule unité dans laquelle un nageur se lit.
///
/// # ET AUJOURD'HUI, RIEN NE PRODUIT ENCORE DE NAGE
///
/// À dire plutôt qu'à laisser découvrir : cette discipline existe, et aucun chemin de l'app
/// n'écrit encore de relevé qui la porte. L'import depuis Apple Santé ne demande que des courses
/// (`predicateForWorkouts(with: .running)`), et il n'y a pas de saisie manuelle.
///
/// C'est voulu, et c'est le même ordre que pour l'ultra-trail : la mesure d'abord, la manière de
/// la produire ensuite, l'objectif en dernier — et l'objectif triathlon reste non proposable
/// jusqu'à ce que les deux précédents soient vrais. Un objectif qui promet trois disciplines dont
/// une ne sait rien enregistrer serait exactement le genre de promesse qu'on ne tient pas.
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
    case swim = "swim"

    /// La discipline des relevés écrits avant que ce champ n'existe. Ils sont tous des courses,
    /// par construction : l'app ne savait rien faire d'autre.
    static let legacy: Discipline = .run

    var title: String {
        switch self {
        case .run: return String(localized: "Course")
        case .bike: return String(localized: "Vélo")
        case .trail: return String(localized: "Trail")
        case .swim: return String(localized: "Natation")
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
        // Jamais sur le bouton — la nage ne se démarre pas d'ici. Le libellé existe pour les
        // écrans qui nomment une discipline sans la démarrer : l'historique, les statistiques.
        case .swim: return String(localized: "NAGE")
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
        case .swim: return String(localized: "Passer à la natation")
        }
    }

    var sfSymbol: String {
        switch self {
        case .run: return "figure.run"
        case .bike: return "bicycle"
        // `figure.hiking` plutôt qu'un second `figure.run` : c'est la seule icône du jeu système
        // qui dise le terrain, et le terrain est précisément ce qui distingue le trail.
        case .trail: return "figure.hiking"
        case .swim: return "figure.pool.swim"
        }
    }

    /// La grandeur dans laquelle cette discipline se lit.
    ///
    /// # UN BOOLÉEN NE SAIT PAS DIRE TROIS CHOSES
    ///
    /// C'était `usesPacePerKm: Bool`, et c'était suffisant pour deux mondes : une allure en
    /// minutes par kilomètre à pied, une vitesse en kilomètres-heure à vélo. La natation en
    /// ajoute un troisième, et ce n'est ni l'un ni l'autre — un nageur se lit en minutes aux CENT
    /// MÈTRES, jamais au kilomètre. « 32:00/km » est juste et illisible ; « 1:55/100 m » est ce
    /// qui est écrit sur tous les murs de bassin du monde.
    ///
    /// Gardé en booléen, il aurait fallu choisir entre deux mensonges : vrai, et l'unité affichée
    /// devenait « /km » sur un chiffre qui est aux cent mètres ; faux, et la nage s'affichait en
    /// kilomètres-heure. Une énumération pose la question une fois, et le compilateur la repose à
    /// chaque discipline nouvelle.
    enum Rythme {
        case allureParKm
        case allureParCentMetres
        case vitesse
    }

    var rythme: Rythme {
        switch self {
        // Le trail se lit en minutes par kilomètre comme la route : l'allure y est erratique,
        // mais c'est bien une allure, et la convertir en km/h ne la rendrait pas plus lisible.
        case .run, .trail: return .allureParKm
        case .bike: return .vitesse
        case .swim: return .allureParCentMetres
        }
    }

    /// Se lit en `m:ss` — une allure — plutôt qu'en nombre décimal, qui est une vitesse.
    ///
    /// Remplace `usesPacePerKm`, dont le nom était devenu faux : la nage est bien une allure, et
    /// elle n'est pas au kilomètre. Les trois écrans qui s'en servent ne demandaient jamais autre
    /// chose que « est-ce que j'affiche des minutes-secondes ou un décimal ».
    var seLitEnAllure: Bool { rythme != .vitesse }

    /// Le nom de la mesure de rythme : « Allure » à pied et en bassin, « Vitesse » à vélo.
    ///
    /// Ici et pas dans l'écran de course, parce que la Live Activity en a besoin aussi — et elle
    /// vit dans une extension, un processus séparé qui ne peut rien lire de l'app. Elle affichait
    /// « Allure » sur une sortie vélo, sous un chiffre qui était des kilomètres-heure.
    ///
    /// Deux propriétés et non une capitalisation à la volée : `uppercased()` dépend de la langue,
    /// et les deux casses sont deux clés distinctes du catalogue depuis toujours. Elles sont
    /// voisines ici, donc la décision reste à un seul endroit même si le rendu en a deux.
    var rythmeLabel: String {
        seLitEnAllure ? String(localized: "Allure") : String(localized: "Vitesse")
    }

    var rythmeLabelMajuscules: String {
        seLitEnAllure ? String(localized: "ALLURE") : String(localized: "VITESSE")
    }

    /// L'unité du rythme. Pas traduite — « km », « m » et « h » sont les mêmes symboles partout.
    ///
    /// En minuscules ici, parce que c'est la forme la plus employée ; `TimeFormat.rythme` la met
    /// en capitales pour l'écran de course. `uppercased()` dépend bien de la langue, mais ces
    /// chaînes ne contiennent aucune lettre que le turc traite à part — c'est le `i` qui pose
    /// problème, et il n'y en a pas.
    ///
    /// L'île dynamique écrivait « /km » en dur, sous un chiffre devenu des kilomètres-heure dès
    /// qu'on roule. Deuxième endroit à le faire, après le libellé juste au-dessus.
    var rythmeUnite: String {
        switch rythme {
        case .allureParKm: return "/km"
        case .allureParCentMetres: return "/100 m"
        case .vitesse: return "km/h"
        }
    }

    /// Les chaussures de course ne s'usent pas à vélo. Elles s'usent en trail — plus vite, même.
    var wearsShoes: Bool {
        switch self {
        case .run, .trail: return true
        // Et surtout pas en bassin : le chlore n'use pas une semelle, et une paire qui vieillirait
        // de deux kilomètres à chaque longueur serait à remplacer en un mois.
        case .bike, .swim: return false
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
        case .bike, .swim: return false
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
    /// L'allure reste AFFICHÉE en trail (voir `rythme`) : c'est une mesure, et une mesure
    /// se regarde. Ce qui se tait, c'est la cible et le jugement porté dessus.
    var followsPaceTargets: Bool {
        switch self {
        case .run: return true
        // En bassin, l'allure cible existe — c'est même la discipline où elle est la plus
        // précise — mais elle se tient au chronomètre du mur, pas à une voix dans une oreille.
        case .bike, .trail, .swim: return false
        }
    }

    /// Toutes les disciplines comptent pour la série et les anneaux du jour : elles mesurent
    /// l'ASSIDUITÉ, pas le kilométrage de course. Quelqu'un qui roule une heure n'a pas rien fait.
    var countsTowardStreak: Bool {
        switch self {
        case .run, .bike, .trail, .swim: return true
        }
    }

    /// Cette discipline peut-elle être LANCÉE depuis le téléphone ?
    ///
    /// # CE QU'UN TÉLÉPHONE DANS UNE POCHE PEUT FAIRE, ET CE QU'IL NE PEUT PAS
    ///
    /// Courir, rouler, faire du trail : le GPS suffit, et le téléphone reste sur soi. Nager :
    /// non. Il n'y a pas de GPS sous l'eau, le téléphone n'entre pas dans le bassin, et une
    /// longueur ne se compte qu'au poignet. Prétendre le contraire donnerait un mode qui démarre,
    /// n'enregistre rien, et rend une sortie vide.
    ///
    /// Une nage entre donc par Apple Santé — qui la reçoit de la montre ou de n'importe quelle
    /// app — ou à la main. Ce n'est pas un pis-aller : c'est exactement ce que fait toute app de
    /// triathlon qui n'a pas sa propre montre.
    ///
    /// LE CADRAN LIT CE DRAPEAU. Sans lui, ajouter la natation à l'énumération aurait posé un
    /// quatrième rond sous le bouton RUN, et ce rond aurait démarré une course qui ne mesure
    /// rien. Voir `DisciplineDial`.
    var seDemarreDepuisLeTelephone: Bool {
        switch self {
        case .run, .bike, .trail: return true
        case .swim: return false
        }
    }

    /// Les disciplines que le cadran propose, dans l'ordre de lecture.
    ///
    /// `allCases` filtré, et jamais une seconde liste écrite à la main : une discipline ajoutée
    /// demain entre ici toute seule si elle se démarre, et reste dehors sinon.
    static var demarrables: [Discipline] {
        allCases.filter(\.seDemarreDepuisLeTelephone)
    }
}
