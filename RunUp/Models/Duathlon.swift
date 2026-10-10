import Foundation

/// Les quatre formats du duathlon : courir, rouler, courir encore.
///
/// # POURQUOI UN FICHIER À PART, ET PAS UN TRIATHLON SANS NATATION
///
/// Parce que ce n'en est pas un. Retirer la natation d'un triathlon donnerait vélo-course ;
/// un duathlon commence et finit en courant, et c'est cette troisième épreuve qui le définit.
///
/// La seconde course est le sujet entier de la discipline. Elle se court sur des jambes qui
/// viennent de rouler une heure ou cinq, après avoir déjà couru — et l'allure qu'on y tient
/// n'a rien à voir avec celle du même nombre de kilomètres frais. Quelqu'un qui s'entraîne aux
/// trois épreuves séparément arrive au deuxième parc à vélo en forme et finit à pied en
/// marchant. C'est le défaut le plus courant de la discipline, et il se prépare : par des
/// enchaînements, et par rien d'autre.
///
/// D'où une conséquence qui tient tout le plan : un duathlon demande MOINS d'heures qu'un
/// triathlon du même nom, et plus d'enchaînements. Les heures d'effort ci-dessous le disent.
///
/// # UNE QUESTION DE MOINS QU'AU TRIATHLON, ET C'EST VOULU
///
/// Le triathlon pose une question sur la natation (voir `NiveauDeNage`), parce que prescrire
/// « 1500 m en continu » à quelqu'un qui n'a jamais enchaîné deux longueurs met cette personne
/// seule au milieu d'un lac. Le vélo ne fait courir aucun risque de cette nature : on y va
/// moins vite, on y souffre, on s'arrête quand on veut. Et l'app VOIT le vélo — GPS, distance,
/// durée, fréquence cardiaque — là où elle ne voit rien de la natation, donc le plan se corrige
/// tout seul après coup au lieu de devoir tout deviner d'avance.
///
/// Une question qui ne change pas une décision ne vaut pas une étape d'inscription.
///
/// # LES DISTANCES
///
/// Celles des fédérations, et elles ne se discutent pas. Sprint et Standard sont partout les
/// mêmes ; les deux formats longs suivent la nomenclature de World Triathlon et d'USA
/// Triathlon — « moyenne » pour le 10/60/10 que court la plupart des Powerman, « longue » pour
/// le 10/150/30 de Zofingen. Les organisateurs s'en écartent parfois : c'est pour ça que
/// « Mon propre temps » existe à côté des chronos proposés.
enum DuathlonFormat: String, Codable, CaseIterable, Identifiable {
    case sprint, standard, moyenneDistance, longueDistance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sprint: return String(localized: "Sprint")
        case .standard: return String(localized: "Standard")
        case .moyenneDistance: return String(localized: "Moyenne distance")
        case .longueDistance: return String(localized: "Longue distance")
        }
    }

    /// La PREMIÈRE course. Celle qu'on part trop vite, toujours.
    var premiereCourseKm: Double {
        switch self {
        case .sprint: return 5
        case .standard: return 10
        case .moyenneDistance: return 10
        case .longueDistance: return 10
        }
    }

    var veloKm: Double {
        switch self {
        case .sprint: return 20
        case .standard: return 40
        case .moyenneDistance: return 60
        case .longueDistance: return 150
        }
    }

    /// LA SECONDE COURSE, et la seule épreuve qui dise quelque chose sur la préparation.
    ///
    /// Elle est plus courte que la première sur les deux formats courts et aussi longue ou plus
    /// sur les deux longs — ce qui veut dire que la difficulté ne vient pas de sa distance mais
    /// de ce qu'il y a devant.
    var secondeCourseKm: Double {
        switch self {
        case .sprint: return 2.5
        case .standard: return 5
        case .moyenneDistance: return 10
        case .longueDistance: return 30
        }
    }

    var courseTotaleKm: Double { premiereCourseKm + secondeCourseKm }

    /// « 10 km · 40 km · 5 km » — les trois épreuves dans leur ordre, qui ne change jamais.
    var resume: String {
        "\(Self.km(premiereCourseKm)) · \(Self.km(veloKm)) · \(Self.km(secondeCourseKm))"
    }

    /// Des temps de FINISSEUR, pas des objectifs de performance — même esprit qu'au triathlon.
    ///
    /// Vérifiés en simulant deux profils sur les trois épreuves plus les transitions : une
    /// age-grouper solide tombe sur les deux premiers, une première fois sur les deux derniers.
    var chronoPresets: [String] {
        switch self {
        case .sprint: return ["1:05", "1:15", "1:25", "1:40"]
        case .standard: return ["2:10", "2:25", "2:45", "3:10"]
        case .moyenneDistance: return ["3:30", "4:00", "4:30", "5:15"]
        case .longueDistance: return ["8:00", "9:00", "10:30", "12:00"]
        }
    }

    /// Le temps d'effort, en heures — la grandeur qui dimensionne le volume de la semaine,
    /// comme `TriathlonFormat.heuresDeffort` et le kilomètre-effort de l'ultra.
    ///
    /// Le MILIEU de la fourchette des temps de finisseur, pas le meilleur : un plan se
    /// dimensionne sur la journée qu'elle va vraiment vivre.
    var heuresDeffort: Double {
        switch self {
        case .sprint: return 1.3
        case .standard: return 2.6
        case .moyenneDistance: return 4.3
        case .longueDistance: return 10.2
        }
    }

    /// La part de la journée passée À PIED, en fraction du temps d'effort.
    ///
    /// C'est ce qui distingue un duathlon d'un triathlon de durée comparable, et ce que le plan
    /// doit traduire en volume : on court beaucoup plus, en proportion, dans un duathlon — deux
    /// épreuves sur trois. Un plan calqué sur le triathlon sous-entraînerait la course.
    ///
    /// Estimée à 5:30/km à pied et 30 km/h à vélo, transitions comprises dans le total : ce ne
    /// sont pas les allures de tout le monde, mais le RAPPORT entre les deux bouge peu, et
    /// c'est le rapport qui sert ici.
    var partCourue: Double {
        let heuresCourse = courseTotaleKm * 5.5 / 60
        let heuresVelo = veloKm / 30
        return heuresCourse / (heuresCourse + heuresVelo)
    }

    /// « 20 km », « 2,5 km » — le zéro décimal inutile tombe, la virgule suit la langue.
    ///
    /// Interne et non privée : l'écran d'inscription écrit la même phrase avec les mêmes
    /// nombres, et une seconde mise en forme à côté finirait par en diverger — « 2.5 km » d'un
    /// côté, « 2,5 km » de l'autre, sur le même écran.
    static func km(_ valeur: Double) -> String {
        let arrondi = (valeur * 10).rounded() / 10
        return arrondi == arrondi.rounded()
            ? String(format: "%.0f km", locale: Locale.current, arrondi)
            : String(format: "%.1f km", locale: Locale.current, arrondi)
    }
}
