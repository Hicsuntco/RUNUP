import Foundation

/// Les durées de RUNUP, écrites une seule fois pour les trois cibles.
///
/// # POURQUOI CE FICHIER EXISTE
///
/// Il y en avait six copies, réparties sur l'app, le widget et la montre, et elles ne disaient
/// pas toutes la même chose. Deux divergences réelles, dont une visible côte à côte :
///
/// 1. **Le widget perdait les heures.** `RunActivityWidget.formatDuration` rendait
///    `"\(s / 60):\(s % 60)"` sans jamais passer aux heures : une sortie longue mise en pause
///    affichait « 95:00 » sur l'écran verrouillé. C'est exactement le défaut que la version de
///    `PaceModel` documente comme corrigé — « a 95-minute long run used to render as "95:00"
///    instead of "1:35:00" everywhere this was (mis)used for that » — sauf que la copie du widget
///    n'avait jamais reçu la correction. Elle était hors de portée de la relecture : un autre
///    dossier, une autre cible.
///
/// 2. **L'allure s'arrondissait ou se tronquait selon l'écran.** Trois copies arrondissaient, une
///    tronquait. Même nombre, une seconde d'écart.
///
/// Ces deux-là sont des défauts, et ils sont réparés. Il en restait une troisième qui n'en était
/// pas un : `parle` écrivait « 3 h 28 » sur l'accueil et dans le fil du club, `compacte` écrivait
/// « 3h28 » dans les statistiques. Les deux formes étaient défendables, et ce fichier les gardait
/// côte à côte en attendant qu'on les voie pour décider.
///
/// C'EST DÉCIDÉ : une seule forme, resserrée — `duree`. « 3h28 » partout, et « 3hr28 » en
/// anglais, parce que « h » seul n'y est pas le symbole de l'heure. Les deux fonctions n'en font
/// plus qu'une, et les cinq appels pointent dessus.
///
/// # CE QUI N'EST PAS ICI
///
/// `RunUp/Shared` est pris en entier par le widget et fichier par fichier par la montre : rien
/// ici ne peut dépendre d'un modèle de l'app. Ce sont donc trois fonctions pures, de nombres vers
/// des chaînes. Tout ce qui demande un profil, une zone ou une course reste dans `PaceModel`, qui
/// délègue ici pour la mise en forme.
enum TimeFormat {

    /// « 4:37 » — une allure au kilomètre, à partir de secondes par kilomètre.
    ///
    /// ARRONDIT, et c'est la seule règle juste des deux : tronquer retire systématiquement jusqu'à
    /// une seconde, donc une coureuse pile sur son allure cible lit toujours un peu mieux que la
    /// cible. C'est aussi la règle que suivent déjà le plan et l'historique.
    ///
    /// Ne passe jamais aux heures — une allure au kilomètre n'y arrive pas. Pour une durée, voir
    /// `horloge`.
    static func allure(secondesParKm: Double) -> String {
        let total = Int(max(0, secondesParKm).rounded())
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    /// « 1:35:00 », ou « 46:12 » quand il n'y a pas d'heure. Un chronomètre.
    ///
    /// Le passage aux heures est le point entier de cette fonction : c'est son absence qui faisait
    /// lire « 95:00 » sur l'écran verrouillé.
    static func horloge(_ secondes: Double) -> String {
        let total = Int(max(0, secondes).rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))"
            : "\(m):\(String(format: "%02d", s))"
    }

    /// Le symbole de l'heure, dans la langue de l'appareil.
    ///
    /// # POURQUOI CE N'EST PAS UNE CLÉ DE CATALOGUE
    ///
    /// Parce que la clé serait « h ». Un caractère, sans contexte, qui voudrait dire tout et
    /// rien dans une liste de seize cents phrases — et qui entrerait en collision avec le
    /// premier « h » qu'on écrirait ailleurs. Le catalogue est fait pour des phrases ; ceci est
    /// un symbole d'unité, et il en existe exactement deux formes.
    ///
    /// La langue est un PARAMÈTRE et non une lecture de `Locale.current` à l'intérieur : c'est
    /// ce qui rend la règle vérifiable. Le simulateur de l'intégration continue tourne en
    /// anglais, donc un test qui lirait la langue courante affirmerait « hr » ici et « h » sur
    /// la machine de quelqu'un d'autre.
    static func symboleHeure(langue: String?) -> String {
        langue == "en" ? "hr" : "h"
    }

    /// « 3h28 », ou « 46 min ». La durée d'une sortie, d'une semaine, d'un bloc.
    ///
    /// Jamais « 0h46 » : ce serait exact et illisible, l'œil compte les zéros avant de lire le
    /// nombre. Les minutes, elles, sont toujours sur deux chiffres dès qu'une heure les précède
    /// — « 3h8 » se lit comme trois heures huit, et il faut une seconde pour comprendre.
    ///
    /// `min` n'est pas traduit, et c'est juste : c'est le symbole de la minute dans les trois
    /// langues de l'app. L'heure, elle, ne l'est pas — d'où `symboleHeure`.
    static func duree(_ secondes: Int) -> String {
        let total = max(0, secondes)
        let h = total / 3600
        let m = (total % 3600) / 60
        guard h > 0 else { return "\(m) min" }
        let symbole = symboleHeure(langue: Locale.current.language.languageCode?.identifier)
        return "\(h)\(symbole)\(String(format: "%02d", m))"
    }

    /// « 24,3 » — des kilomètres par heure, à partir de secondes par kilomètre.
    ///
    /// Le pendant de `allure`, pour les disciplines où l'allure au kilomètre ne se lit pas.
    /// « 2:28/km » est juste à vélo, et illisible : personne ne pense sa sortie comme ça. Une
    /// décimale, parce que l'unité est grande — l'entier seul perdrait les écarts qui comptent.
    ///
    /// Rend « — » plutôt que l'infini quand il n'y a pas encore d'allure : un zéro au
    /// dénominateur est une absence de mesure, pas une vitesse nulle.
    /// « 1:55 » pour une nage — des minutes aux CENT MÈTRES.
    ///
    /// Un dixième de l'allure au kilomètre, et c'est tout : la chaîne qui mesure une sortie rend
    /// des secondes par kilomètre quelle que soit la discipline, parce qu'elle ne sait diviser
    /// qu'une distance par un temps. La conversion se fait donc ici, au moment d'écrire — un seul
    /// endroit, comme l'unité juste à côté.
    static func allureParCentMetres(secondesParKm: Double) -> String {
        allure(secondesParKm: max(0, secondesParKm) / 10)
    }

    static func vitesse(secondesParKm: Double) -> String {
        guard secondesParKm > 0 else { return "—" }
        let kmh = 3600 / secondesParKm
        return String(format: "%.1f", locale: Locale.current, kmh)
    }

    /// « 7,42 » — deux décimales, et le séparateur décimal de la langue de l'appareil.
    ///
    /// Écrit trois fois en `String(format:)` avant d'atterrir ici : deux fois dans la Live
    /// Activity, une dans le widget d'accueil. Trois formatages de la même distance, dans deux
    /// cibles, et rien pour les tenir d'accord — c'est précisément ce que ce fichier existe pour
    /// éviter.
    static func distance(km: Double) -> String {
        String(format: "%.2f", locale: .current, max(0, km))
    }

    /// Ce que la discipline donne à lire, et son unité. Un seul endroit décide — sans quoi
    /// chaque écran choisirait, et deux écrans finiraient par ne pas dire la même chose de la
    /// même sortie.
    static func rythme(_ discipline: Discipline, secondesParKm: Double) -> (valeur: String, unite: String) {
        // L'unité vient de `Discipline`, qui est le seul endroit à l'écrire : l'île dynamique en
        // a besoin aussi, et elle l'avait recopiée — en dur, et sans jamais changer de discipline.
        let valeur: String
        switch discipline.rythme {
        case .allureParKm: valeur = allure(secondesParKm: secondesParKm)
        case .allureParCentMetres: valeur = allureParCentMetres(secondesParKm: secondesParKm)
        case .vitesse: valeur = vitesse(secondesParKm: secondesParKm)
        }
        return (valeur, discipline.rythmeUnite.uppercased())
    }

}
