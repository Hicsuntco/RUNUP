import Foundation

/// Le jour J d'un triathlon : où passe le temps, où l'on mange, et ce qui se perd en transition.
///
/// # CE QUE LE PLAN NE DIT PAS
///
/// Les douze semaines construisent trois disciplines. Elles ne disent rien de la JOURNÉE, et un
/// triathlon se perd au ventre et en transition bien plus souvent qu'aux jambes. Trois faits
/// décident de presque tout, et aucune séance ne les enseigne.
///
/// # ON NE MANGE PAS DANS L'EAU
///
/// C'est le fait structurel du format, et c'est celui qui surprend. La natation ne permet aucun
/// ravitaillement : rien à boire, rien à avaler, et la combinaison comprime l'estomac. La
/// nutrition de la journée commence donc à la sortie de l'eau, alors qu'une partie de l'effort
/// est déjà faite.
///
/// # LE VÉLO EST LE SEUL ENDROIT OÙ L'ESTOMAC DIT OUI
///
/// Il représente environ la moitié du temps total — plus que les deux autres réunies sur un
/// format long — et c'est le seul moment où l'on est assise, stable, respiration régulière. À
/// pied, après trois heures de selle, l'estomac refuse presque tout.
///
/// Conséquence : TOUT CE QUI SERA NÉCESSAIRE POUR LA COURSE DOIT ÊTRE PRIS SUR LE VÉLO. Pas
/// « idéalement », pas « si possible ». C'est la règle, et elle explique pourquoi quelqu'un qui
/// a bien nagé et bien roulé peut s'arrêter de courir au dixième kilomètre.
///
/// # LES CONSTANTES VIENNENT D'`UltraRaceDay`, ET CE N'EST PAS UN RACCOURCI
///
/// Soixante à quatre-vingt-dix grammes de glucides par heure, quatre à six cents millilitres
/// d'eau : la physiologie de l'endurance ne change pas parce qu'on change de sport. Les recopier
/// ici aurait créé deux vérités pour une seule question, et c'est précisément ce que `Calories`
/// existe pour empêcher ailleurs dans ce dépôt.
///
/// Ce qui est propre au triathlon n'est pas la quantité, c'est la RÉPARTITION : la même somme
/// horaire, concentrée sur une fenêtre qui exclut la natation et se referme dès le début de la
/// course.
enum TriathlonRaceDay {

    /// Le temps passé sur chaque épreuve, en minutes.
    struct Repartition: Equatable {
        var nage: Int
        var velo: Int
        var course: Int
        var transitions: Int

        var total: Int { nage + velo + course + transitions }
    }

    /// Les parts de la journée, mesurées plutôt que supposées.
    ///
    /// Obtenues en simulant deux profils réalistes — une age-grouper solide et une première fois
    /// — sur les trois épreuves de chaque format, puis en moyennant leurs parts. C'est la même
    /// simulation qui a servi à fixer les temps de finisseur de `TriathlonFormat.chronoPresets`,
    /// donc les deux sont cohérents par construction.
    ///
    /// Les parts VARIENT avec le format, et il faut qu'elles varient : la natation pèse un
    /// cinquième d'un sprint et un huitième d'une longue distance, parce que c'est la seule
    /// épreuve dont la part diminue quand l'épreuve s'allonge. Et les transitions pèsent sept
    /// pour cent d'un sprint — une minute perdue là s'y voit, et c'est pour ça que les sprints se
    /// gagnent en transition.
    static func parts(_ format: TriathlonFormat) -> (nage: Double, velo: Double, course: Double) {
        switch format {
        case .sprint: return (0.195, 0.448, 0.288)
        case .olympique: return (0.202, 0.464, 0.298)
        case .half: return (0.128, 0.522, 0.314)
        case .longueDistance: return (0.130, 0.531, 0.320)
        }
    }

    /// La journée découpée, à partir du temps visé.
    ///
    /// Les transitions sont le RESTE et non une quatrième part : ainsi la somme des quatre vaut
    /// exactement le temps visé, quels que soient les arrondis. Un découpage dont les morceaux ne
    /// recomposent pas le tout est un découpage qu'on relit trois fois sans comprendre.
    static func repartition(format: TriathlonFormat, minutesVisees: Int) -> Repartition {
        let p = parts(format)
        let total = max(0, minutesVisees)
        let nage = Int((Double(total) * p.nage).rounded())
        let velo = Int((Double(total) * p.velo).rounded())
        let course = Int((Double(total) * p.course).rounded())
        return Repartition(nage: nage, velo: velo, course: course,
                           transitions: max(0, total - nage - velo - course))
    }

    /// Les glucides à prendre SUR LE VÉLO, en grammes.
    ///
    /// La fenêtre de ravitaillement n'est pas la journée : c'est le vélo, plus la course dans la
    /// mesure où l'estomac l'accepte encore. On compte donc la totalité du vélo et la MOITIÉ de
    /// la course — pas par prudence rhétorique, mais parce que ce qui n'est pas pris sur la selle
    /// ne sera pas pris du tout.
    static func glucidesSurLeVelo(_ r: Repartition) -> (min: Int, max: Int) {
        let heures = Double(r.velo) / 60
        return (Int((heures * Double(UltraRaceDay.glucidesParHeureMin)).rounded()),
                Int((heures * Double(UltraRaceDay.glucidesParHeureMax)).rounded()))
    }

    /// L'eau à embarquer sur le vélo, en millilitres — arrondie aux cent millilitres, parce
    /// qu'un bidon ne se remplit pas au millilitre près.
    static func eauSurLeVelo(_ r: Repartition) -> (min: Int, max: Int) {
        let heures = Double(r.velo) / 60
        func cent(_ v: Double) -> Int { Int((v / 100).rounded()) * 100 }
        return (cent(heures * Double(UltraRaceDay.eauParHeureMinML)),
                cent(heures * Double(UltraRaceDay.eauParHeureMaxML)))
    }

    /// Les transitions valent-elles une séance ?
    ///
    /// Deux minutes gagnées en transition, c'est deux minutes gagnées sur le chrono — sans un
    /// battement de cœur de plus. Sur un sprint, les transitions pèsent sept pour cent de la
    /// journée : deux minutes y valent plus que tout ce qu'un bloc de seuil peut rapporter en
    /// quatre semaines. Sur une longue distance elles pèsent moins de deux pour cent, et le
    /// temps est ailleurs.
    ///
    /// Le seuil est à CINQ pour cent, et pas à trois comme dans la première version.
    ///
    /// À trois, l'olympique (3,6 %) et le half (3,6 %) tombaient du même côté que le sprint à
    /// égalité parfaite — un seuil qui ne distingue rien ne mérite pas d'exister. Les parts
    /// mesurées sont 6,9 % / 3,6 % / 3,6 % / 1,9 %, donc la seule frontière réelle sépare le
    /// sprint du reste. C'est aussi ce que tout le monde sait du format : un sprint se gagne en
    /// transition, un Ironman se gagne ailleurs.
    static func transitionsDecisives(_ format: TriathlonFormat) -> Bool {
        let p = parts(format)
        return (1 - p.nage - p.velo - p.course) > 0.05
    }

    /// LA COMBINAISON EST UNE RÈGLE DE COURSE, PAS UN CHOIX DE CONFORT.
    ///
    /// Elle est obligatoire en dessous d'une température d'eau et INTERDITE au-dessus d'une
    /// autre, et les deux seuils dépendent de la fédération, du format et de l'année. Cette app
    /// n'a aucun règlement vérifié à affirmer comme un fait, et un seuil faux ici n'est pas une
    /// approximation : c'est quelqu'un qui arrive au départ avec une combinaison qu'on va lui
    /// refuser, ou sans celle qu'on va lui réclamer.
    ///
    /// On dit donc que la règle existe, qu'elle se lit au briefing, et que l'eau froide se
    /// répète à l'entraînement. Aucun chiffre. C'est le même parti que les charges HYROX, pour
    /// la même raison — voir `AdaptivePlanEngine.hyroxArchetypes`.
    static let combinaisonEstUneRegleDeCourse = true
}
