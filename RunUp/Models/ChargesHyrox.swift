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
    ///
    /// EN CENTIMÈTRES ET NON EN MÈTRES, pour une raison d'affichage : le règlement écrit « 2.70M »,
    /// et un nombre à virgule doit se formater avec la locale sous peine d'afficher un point à
    /// quelqu'un qui attend une virgule (voir `ci_scripts/check_decimales.py`). 270 cm dit le même
    /// fait, sans machinerie, et se lit mieux pour une hauteur de cible.
    let wallBallCibleCm: Int

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
        /// « DISTANCE 50 METERS [4 X 12.5M] », dans les deux sens. La distance totale et le
        /// nombre d'allers plutôt que la longueur d'un aller : 12,5 est un nombre à virgule, et
        /// 50 m en quatre allers dit exactement la même chose sans en être un.
        static let sledTotalM = 50
        static let sledAllers = 4
        static let burpeeBroadJumpM = 80
        static let farmersCarryM = 200
        static let fentesM = 100
        static let wallBallsReps = 100
    }

    /// Les huit stations, DANS L'ORDRE DE LA COURSE, avec ce qu'elles prescrivent pour cette
    /// division.
    ///
    /// # DEUX STATIONS N'EXISTAIENT NULLE PART DANS CETTE APP
    ///
    /// `burpee`, `sandbag` et `lunge` apparaissaient zéro fois dans tout le dépôt. Six stations sur
    /// huit étaient nommées quelque part, et les deux absentes sont les deux schémas de mouvement
    /// qu'une coureuse n'a aucune autre raison de travailler : un burpee suivi d'un saut horizontal,
    /// et une fente chargée sur cent mètres. Les taire était le manque le plus coûteux de la
    /// préparation.
    ///
    /// L'ORDRE EST CELUI DE L'ÉPREUVE, pas un ordre de lecture. Chaque station suit un kilomètre
    /// de course, et c'est précisément ce que l'épreuve demande de gérer : le carry arrive après
    /// le rameur, les fentes après le carry, et les cent wall balls après tout le reste.
    ///
    /// Fonction pure, et c'est voulu : elle se vérifie sans écran. La fiche détail s'en sert, et
    /// n'a donc pas à savoir dans quel ordre les stations tombent.
    var stations: [(nom: String, prescription: String)] {
        [
            (String(localized: "SkiErg"), String(localized: "\(Format.skiErgM) m")),
            (String(localized: "Sled push"),
             String(localized: "\(Format.sledTotalM) m en \(Format.sledAllers) allers · \(sledPushKg) kg")),
            (String(localized: "Sled pull"),
             String(localized: "\(Format.sledTotalM) m en \(Format.sledAllers) allers · \(sledPullKg) kg")),
            (String(localized: "Burpee broad jumps"),
             String(localized: "\(Format.burpeeBroadJumpM) m · poitrine au sol, les deux pieds ensemble")),
            (String(localized: "Rameur"), String(localized: "\(Format.rameurM) m")),
            (String(localized: "Farmers carry"),
             String(localized: "\(Format.farmersCarryM) m · \(kettlebellKg) kg dans chaque main")),
            (String(localized: "Fentes sandbag"),
             String(localized: "\(Format.fentesM) m · \(sandbagKg) kg · genou arrière au sol")),
            (String(localized: "Wall balls"),
             String(localized: "\(Format.wallBallsReps) reps · \(wallBallKg) kg · cible à \(wallBallCibleCm) cm")),
        ]
    }
}
