import Foundation

/// La journée d'un duathlon, découpée.
///
/// # CE QUE CE FICHIER NE REPREND PAS DU TRIATHLON
///
/// `TriathlonRaceDay` porte un `transitionsDecisives` : sur un sprint, les transitions pèsent
/// sept pour cent de la journée, et deux minutes gagnées là valent plus qu'un bloc de seuil.
/// La question se pose parce qu'un triathlon commence par sortir de l'eau en combinaison.
///
/// Un duathlon n'a pas ça. Ses deux transitions sont courtes — on descend du vélo, on pose le
/// casque, on part — et elles pèsent entre 1,6 et 3,6 % selon le format, c'est-à-dire TOUJOURS
/// en dessous du seuil de cinq pour cent que le triathlon a fini par retenir. Recopier la règle
/// donnerait une question dont la réponse est « non » quatre fois sur quatre, et le fichier du
/// triathlon dit lui-même qu'un seuil qui ne distingue rien ne mérite pas d'exister.
///
/// Ce qui décide d'un duathlon est ailleurs, et c'est la première course. Voir
/// `DuathlonRaceDay.lePiegeEstLaPremiereCourse`.
enum DuathlonRaceDay {

    struct Repartition: Equatable {
        var premiereCourse: Int
        var velo: Int
        var secondeCourse: Int
        var transitions: Int

        var total: Int { premiereCourse + velo + secondeCourse + transitions }
        var courseTotale: Int { premiereCourse + secondeCourse }
    }

    /// Les parts de la journée, par format.
    ///
    /// Dérivées — 5:30 au kilomètre à pied, 30 km/h à vélo, plus des transitions de trois à huit
    /// minutes selon la taille de l'épreuve — puis normalisées. Ce ne sont pas des mesures de
    /// terrain, et ce n'est pas un problème : ce qui compte ici est le RAPPORT entre les trois
    /// épreuves, et il bouge peu d'une coureuse à l'autre. Les allures absolues, elles, viennent
    /// du chrono qu'elle a visé.
    ///
    /// Ce que ces nombres disent, et qu'on ne voit pas en lisant « 10 km · 40 km · 5 km » : sur
    /// un standard, le vélo prend près de la moitié de la journée et la seconde course à peine
    /// un sixième. Sur une longue distance, c'est l'inverse qui frappe — trente kilomètres à
    /// pied après cent cinquante à vélo, soit près d'un tiers du temps total.
    static func parts(_ format: DuathlonFormat) -> (premiere: Double, velo: Double, seconde: Double) {
        switch format {
        case .sprint: return (0.326, 0.475, 0.163)
        case .standard: return (0.330, 0.480, 0.165)
        case .moyenneDistance: return (0.234, 0.511, 0.234)
        case .longueDistance: return (0.104, 0.568, 0.312)
        }
    }

    /// La journée découpée, à partir du temps visé.
    ///
    /// Les transitions sont le RESTE et non une quatrième part, comme au triathlon : la somme
    /// des quatre vaut alors exactement le temps visé quels que soient les arrondis. Un
    /// découpage dont les morceaux ne recomposent pas le tout se relit trois fois.
    static func repartition(format: DuathlonFormat, minutesVisees: Int) -> Repartition {
        let p = parts(format)
        let total = max(0, minutesVisees)
        let premiere = Int((Double(total) * p.premiere).rounded())
        var velo = Int((Double(total) * p.velo).rounded())
        let seconde = Int((Double(total) * p.seconde).rounded())

        // TROIS ARRONDIS PEUVENT DÉPASSER LEUR TOTAL, et ça casse la promesse du découpage.
        //
        // Sur une longue distance à cinq minutes — absurde, mais un champ libre finit toujours
        // par contenir n'importe quoi — les trois parts s'arrondissent à 1, 3 et 2 : six
        // minutes pour une journée qui en compte cinq, et des transitions ramenées à zéro par
        // le `max`. La somme ne vaut alors plus le temps visé, c'est-à-dire exactement ce que
        // le calcul du reste existait pour garantir.
        //
        // L'excédent est retiré au VÉLO parce que c'est toujours la plus longue des trois : la
        // minute en question y est invisible, alors qu'elle doublerait une seconde course de
        // deux minutes.
        let excedent = max(0, premiere + velo + seconde - total)
        velo = max(0, velo - excedent)

        return Repartition(premiereCourse: premiere, velo: velo, secondeCourse: seconde,
                           transitions: max(0, total - premiere - velo - seconde))
    }

    /// LE VÉLO EST LA SEULE FENÊTRE POUR MANGER, et plus encore qu'au triathlon.
    ///
    /// Un triathlon commence par quarante minutes de natation où l'on ne peut rien prendre,
    /// puis offre un long vélo. Un duathlon encadre son vélo de DEUX courses : rien avant, et
    /// après, un estomac déjà secoué par la première. Ce qui n'est pas pris sur la selle ne
    /// sera pas pris du tout.
    ///
    /// On compte donc la totalité du vélo et la moitié de la seconde course — même règle qu'au
    /// triathlon, et les mêmes grammes par heure, qui vivent dans `UltraRaceDay` pour que les
    /// trois épreuves ne puissent pas en avoir trois versions.
    static func glucidesSurLeVelo(_ r: Repartition) -> (min: Int, max: Int) {
        let heures = (Double(r.velo) + Double(r.secondeCourse) / 2) / 60
        return (Int((heures * Double(UltraRaceDay.glucidesParHeureMin)).rounded()),
                Int((heures * Double(UltraRaceDay.glucidesParHeureMax)).rounded()))
    }

    /// L'eau à embarquer, arrondie aux cent millilitres — un bidon ne se remplit pas au
    /// millilitre près.
    static func eauSurLeVelo(_ r: Repartition) -> (min: Int, max: Int) {
        let heures = Double(r.velo) / 60
        func cent(_ v: Double) -> Int { Int((v / 100).rounded()) * 100 }
        return (cent(heures * Double(UltraRaceDay.eauParHeureMinML)),
                cent(heures * Double(UltraRaceDay.eauParHeureMaxML)))
    }

    /// LA SECONDE COURSE EST-ELLE AU MOINS AUSSI LONGUE QUE LA PREMIÈRE ?
    ///
    /// Vrai pour la moyenne et la longue distance, faux pour les deux formats courts. C'est la
    /// seule chose qui change vraiment la façon d'aborder la journée : sur un standard, la
    /// seconde course est un sprint de cinq kilomètres qu'on peut arracher ; sur une longue,
    /// c'est trente kilomètres, et tout ce qu'on a pris d'avance avant compte contre soi.
    static func secondeCourseAuMoinsAussiLongue(_ format: DuathlonFormat) -> Bool {
        format.secondeCourseKm >= format.premiereCourseKm
    }

    /// LE PIÈGE EST LA PREMIÈRE COURSE, et il n'a pas de chiffre.
    ///
    /// Tout le monde part trop vite : on est frais, on est en groupe, et cinq ou dix kilomètres
    /// ne font pas peur quand on les court d'habitude seuls. La facture arrive deux heures plus
    /// tard, sur la seconde course, et elle ne se renégocie pas.
    ///
    /// Aucun nombre ici, et c'est délibéré. « Pars vingt secondes au kilomètre plus lentement »
    /// serait une fausse précision : l'écart juste dépend du format, du niveau et du jour, et
    /// personne ne l'a mesuré pour cette app. Même parti que les charges HYROX et que la
    /// température de l'eau au triathlon — on dit la règle, on ne fabrique pas le chiffre.
    static let lePiegeEstLaPremiereCourse = true
}
