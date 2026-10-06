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
/// Ces deux-là sont des défauts, et ils sont réparés. Il reste une troisième divergence qui n'en
/// est PAS une, et c'est pourquoi `parle` et `compacte` coexistent ci-dessous : la même durée
/// s'écrit « 3 h 28 » sur l'accueil et dans le fil du club, « 3h28 » dans les statistiques. Les
/// deux formes sont défendables et aucune n'est un accident. Les unifier ici changerait des
/// pixels sur des écrans que personne n'a regardés en le décidant — alors les deux restent,
/// nommées, au même endroit, et le choix se fait maintenant en voyant les deux.
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

    /// « 3 h 28 », ou « 46 min ». La durée telle qu'on la DIT, pas un chronomètre.
    ///
    /// Jamais « 0 h 46 » : ce serait exact et illisible, l'œil compte les zéros avant de lire le
    /// nombre.
    static func parle(_ secondes: Int) -> String {
        let total = max(0, secondes)
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h) h \(String(format: "%02d", m))" : "\(m) min"
    }

    /// La même chose, resserrée : « 3h28 ». Pour une tuile de statistique, où la largeur est
    /// comptée. Voir l'en-tête : la coexistence des deux est un choix en attente, pas un oubli.
    static func compacte(_ secondes: Int) -> String {
        let total = max(0, secondes)
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(m) min"
    }
}
