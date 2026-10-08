import Foundation

/// Ce qui décide d'un ultra et qui n'est pas de l'entraînement.
///
/// # POURQUOI CE FICHIER EXISTE
///
/// Les quatre blocs du plan répondent à « que courir cette semaine ». Ils ne répondent à aucune
/// des trois questions qui font abandonner sur un ultra, et ces trois-là ne sont pas des questions
/// d'entraînement :
///
/// — **le ravitaillement**, parce qu'un ultra se perd au ventre bien plus souvent qu'aux jambes ;
/// — **le matériel**, parce qu'un sac non conforme est un refus au départ, et une veste oubliée
///   une nuit de froid ;
/// — **la nuit**, parce que personne ne découvre à trois heures du matin, en course, ce qu'il
///   aurait dû essayer à l'entraînement.
///
/// # CE QU'IL NE FAIT PAS
///
/// Il ne prescrit rien d'individuel. Les fourchettes sont celles de la pratique courante en
/// endurance — et une fourchette est honnête là où un nombre unique serait faux : la tolérance
/// digestive, la sudation et la chaleur du jour changent tout, d'une personne à l'autre et d'une
/// course à l'autre. Chaque écran qui s'en sert le dit, et dit aussi la seule consigne qui vaille :
/// ÇA SE TESTE À L'ENTRAÎNEMENT, sur les sorties longues, pas le jour J.
///
/// Il ne remplace pas non plus le règlement de la course. Chaque organisation publie SA liste de
/// matériel obligatoire et la contrôle au départ ; celle d'ici est le socle commun des grands
/// trails, pas la liste de personne. Les écrans le disent aussi.
enum UltraRaceDay {

    // MARK: Le ravitaillement

    /// Glucides par heure, en grammes.
    ///
    /// La fourchette de la pratique courante sur les efforts longs. Le bas est ce qu'un estomac
    /// non entraîné encaisse ; le haut demande de l'avoir habitué, ce qui s'obtient en mangeant
    /// sur les sorties longues et nulle part ailleurs.
    static let glucidesParHeureMin = 60
    static let glucidesParHeureMax = 90

    /// Boisson par heure, en millilitres. Au-delà, on dilue sans hydrater ; en dessous, on
    /// s'épaissit. La chaleur pousse vers le haut de la fourchette, le froid vers le bas.
    static let eauParHeureMinML = 400
    static let eauParHeureMaxML = 600

    /// Sodium par heure, en milligrammes. C'est la plus large des trois fourchettes, et c'est
    /// normal : la perte en sel varie d'un facteur trois d'une personne à l'autre.
    static let sodiumParHeureMinMG = 300
    static let sodiumParHeureMaxMG = 800

    /// L'intervalle entre deux prises, en minutes. Trente, parce que « manger régulièrement » ne
    /// se fait pas : une consigne sans horloge ne tient pas quand on est fatiguée.
    static let minutesEntreDeuxPrises = 30

    static func heures(_ tempsDeffortSecondes: Double) -> Double {
        max(0, tempsDeffortSecondes) / 3600
    }

    /// Le total de glucides de la course, en grammes — le nombre qui fait comprendre qu'un ultra
    /// se prépare aussi en faisant les courses.
    static func glucidesTotaux(tempsDeffortSecondes: Double) -> (bas: Int, haut: Int) {
        let h = heures(tempsDeffortSecondes)
        return (Int((h * Double(glucidesParHeureMin)).rounded()),
                Int((h * Double(glucidesParHeureMax)).rounded()))
    }

    /// Le nombre de prises sur l'ensemble de la course, à une toutes les trente minutes.
    static func nombreDePrises(tempsDeffortSecondes: Double) -> Int {
        max(1, Int((heures(tempsDeffortSecondes) * 60 / Double(minutesEntreDeuxPrises)).rounded()))
    }

    /// Les litres à prévoir au total, arrondis au demi-litre près.
    static func litresTotaux(tempsDeffortSecondes: Double) -> (bas: Double, haut: Double) {
        let h = heures(tempsDeffortSecondes)
        func arrondi(_ ml: Int) -> Double { (h * Double(ml) / 1000 * 2).rounded() / 2 }
        return (arrondi(eauParHeureMinML), arrondi(eauParHeureMaxML))
    }

    // MARK: La nuit

    /// La nuit est-elle au programme ?
    ///
    /// On ne connaît pas l'heure de départ — aucune app ne la connaît avant que le dossard
    /// n'existe — donc on raisonne sur la DURÉE. Au-delà de dix heures d'effort, aucun départ en
    /// matinée ne finit avant la nuit : elle est certaine. Entre six et dix, elle dépend de
    /// l'heure de départ, donc elle est possible — et une frontale qu'on n'a pas sortie est
    /// exactement le matériel qui manque.
    enum Nuit {
        case aucune, possible, certaine
    }

    static let seuilNuitPossibleSecondes: Double = 6 * 3600
    static let seuilNuitCertaineSecondes: Double = 10 * 3600

    static func nuit(tempsDeffortSecondes: Double) -> Nuit {
        if tempsDeffortSecondes >= seuilNuitCertaineSecondes { return .certaine }
        if tempsDeffortSecondes >= seuilNuitPossibleSecondes { return .possible }
        return .aucune
    }

    /// Deux frontales dès que la nuit est possible, et ce n'est pas une précaution de confort :
    /// la plupart des grands trails l'exigent au contrôle du sac, et une frontale qui s'éteint en
    /// descente technique arrête la course.
    static func frontales(tempsDeffortSecondes: Double) -> Int {
        nuit(tempsDeffortSecondes: tempsDeffortSecondes) == Nuit.aucune ? 0 : 2
    }
}
