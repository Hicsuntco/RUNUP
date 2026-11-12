import Foundation

/// Les charges prescrites par le règlement HYROX, par division.
///
/// # POURQUOI CE FICHIER EXISTE MAINTENANT, ET PAS AVANT
///
/// L'app ne nommait aucun kilo, et c'était la bonne décision — l'ancien commentaire de
/// `HyroxDivision` disait pourquoi : « this app has no verified current-season rulebook weights to
/// assert as fact, and a wrong "real" number would be exactly the kind of fake precision this
/// codebase has been fixing everywhere else ».
///
/// La prémisse a changé. Le règlement officiel de la saison en cours a été lu, et les charges
/// ci-dessous viennent de son tableau — pas d'une mémoire, pas d'un résumé de moteur de recherche.
/// Une recherche web donnait d'ailleurs le sled en « 2 × 25 m » ; le règlement dit 4 × 12,5 m.
///
/// LA SECONDE MOITIÉ DE CETTE DÉCISION RESTE VRAIE : les charges changent de saison en saison. Elles
/// sont donc DATÉES — la saison s'affiche avec elles — et elles vivent à un seul endroit, pour
/// qu'une mise à jour soit une édition et pas une chasse. Un nombre sourcé et daté n'est pas de la
/// fausse précision ; un nombre sans date en serait.
///
/// Source : HYROX Single Rulebook, saison 26/27, section 4.1 « HYROX DIVISIONS ».
/// https://hyrox.com/wp-content/uploads/2025/07/25_26_HYROX_RulebookSingles_EN.pdf
struct ChargesHyrox: Equatable, Sendable {
    /// La saison du règlement d'où viennent ces charges.
    ///
    /// Affichée partout où un kilo est annoncé. Une coureuse qui prépare une épreuve sous un
    /// règlement plus récent doit pouvoir voir d'un coup d'œil que ces nombres ont une date, et
    /// aller vérifier.
    static let saison = "26/27"

    /// Sled push, 4 × 12,5 m. Kilos SLED COMPRIS, comme le règlement les donne
    /// (« 102KG INCL. SLED »).
    let sledPushKg: Int
    /// Sled pull, 4 × 12,5 m. Kilos sled compris.
    let sledPullKg: Int
    /// Farmers carry, 200 m. Une kettlebell de ce poids dans CHAQUE main.
    let kettlebellKg: Int
    /// Sandbag lunges, 100 m.
    let sandbagKg: Int
    /// Wall balls, 100 répétitions.
    let wallBallKg: Int
    /// La hauteur de la cible des wall balls, en mètres.
    ///
    /// # ELLE NE SUIT PAS LE MÊME DÉCOUPAGE QUE LES CHARGES
    ///
    /// C'est le piège de ce tableau, et il est à deux pages d'écart dans le règlement. Les poids
    /// groupent « WOMEN », puis « WOMEN PRO / MEN », puis « MEN PRO ». La hauteur groupe
    /// autrement : « WOMEN / WOMEN PRO 2.70M » et « MEN / MEN PRO 3.00M ».
    ///
    /// Hommes et Femmes Pro portent donc exactement les mêmes kilos et ne lancent PAS à la même
    /// hauteur. Déduire l'une de l'autre — ce que la première version de ce fichier faisait, en
    /// leur donnant une seule valeur partagée — faisait s'entraîner trente centimètres trop haut
    /// ou trop bas, cent fois de suite.
    let wallBallCibleM: Double

    /// Les distances et répétitions, identiques dans les quatre divisions.
    ///
    /// Le règlement est explicite : « The running distance remains the same across all divisions:
    /// everyone must run 1 km between each for a total distance of 8 km. » Les deux ergomètres,
    /// le burpee broad jump, le carry, les fentes et les wall balls ne changent pas non plus de
    /// volume — seule la charge bouge.
    enum Format {
        static let courseParSegmentM = 1000
        static let segmentsDeCourse = 8
        static let skiErgM = 1000
        static let rameurM = 1000
        static let sledPushM = 12.5
        static let sledPushAllers = 4
        static let sledPullM = 12.5
        static let sledPullAllers = 4
        static let burpeeBroadJumpM = 80
        static let farmersCarryM = 200
        static let fentesM = 100
        static let wallBallsReps = 100
    }
}
