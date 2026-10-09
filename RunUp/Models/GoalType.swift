import Foundation

/// Les objectifs de l'inscription, dans l'ordre où l'étape 2 les affiche.
///
/// Six à l'origine, puis HYROX, puis l'ultra-trail, puis le triathlon — et le commentaire a
/// annoncé « six » pendant deux ajouts, en renvoyant à une section du README qui n'existe plus.
/// Il ne compte donc plus : la liste qui fait foi est celle de `GoalStepView`, qui lit `allCases`
/// filtré par `estProposable`, et l'ordre de déclaration ci-dessous EST l'ordre à l'écran.
enum GoalType: String, Codable, CaseIterable, Identifiable {
    case race, progress, restart, weight, health, hyrox, ultraTrail, triathlon

    var id: String { rawValue }

    /// `String(localized:)` et non un littéral nu : ces libellés sont composés au niveau du
    /// MODÈLE, donc rendus comme de simples `String` que SwiftUI ne localise pas tout seul —
    /// contrairement à un `Text("…")` écrit dans une vue. Ils apparaissent sur l'onboarding, le
    /// profil, l'écran objectif et le plan : c'est le libellé le plus vu de l'app.
    var title: String {
        switch self {
        case .race: return String(localized: "Préparer une course")
        case .progress: return String(localized: "Progresser")
        case .restart: return String(localized: "(Re)commencer")
        case .weight: return String(localized: "Perdre du poids")
        case .health: return String(localized: "Rester en forme")
        case .hyrox: return String(localized: "Préparer un HYROX")
        case .ultraTrail: return String(localized: "Préparer un ultra-trail")
        case .triathlon: return String(localized: "Préparer un triathlon")
        }
    }

    var subtitle: String {
        switch self {
        case .race: return String(localized: "Un dossard en vue — on construit le plan pour le jour J")
        case .progress: return String(localized: "Courir plus vite ou plus longtemps, sans course précise")
        case .restart: return String(localized: "Reprendre en douceur, sans se blesser")
        case .weight: return String(localized: "Un programme qui allie course et rééquilibrage alimentaire")
        case .health: return String(localized: "Une routine régulière qui tient dans ta semaine")
        case .hyrox: return String(localized: "8 × 1 km de course + stations fonctionnelles — un vrai plan hybride")
        case .ultraTrail: return String(localized: "Dénivelé, descente technique et sorties enchaînées — un plan qui compte en heures")
        case .triathlon: return String(localized: "Nager, rouler, courir — et surtout enchaîner les trois")
        }
    }

    var emoji: String {
        switch self {
        case .race: return "🏁"
        case .progress: return "📈"
        case .restart: return "🌱"
        case .weight: return "🔥"
        case .health: return "⚡"
        case .hyrox: return "🏋️"
        case .ultraTrail: return "⛰️"
        case .triathlon: return "🏊"
        }
    }

    /// Cet objectif est-il proposable à l'inscription ?
    ///
    /// LE ROBINET D'UN OBJECTIF LIVRÉ EN PLUSIEURS MORCEAUX. L'ultra-trail est arrivé en cinq
    /// temps — le modèle d'effort, l'objectif et ses questions, les onze séances, les garde-fous,
    /// le jour J. Entre le deuxième et le quatrième, le choisir aurait donné un plan de ROUTE
    /// dimensionné en kilomètres plats : exactement le défaut que tout ce travail existe pour
    /// corriger, servi sous le nom qui promet le contraire. Mieux vaut un objectif absent qu'un
    /// objectif qui ment, donc il était retenu ici.
    ///
    /// LE TRIATHLON EST OUVERT, ET VOICI CE QUI DEVAIT ÊTRE VRAI AVANT.
    ///
    /// Il est arrivé en six temps, et il est resté retenu ici pendant cinq d'entre eux : la
    /// natation comme discipline, l'import depuis la montre, la saisie à la main, l'objectif et
    /// ses quatre formats, les séances. Le choisir avant la cinquième aurait donné un plan de
    /// COURSE portant le nom « triathlon » — aucune natation, aucun vélo, aucune transition, et
    /// trois quarts de la préparation absents sans qu'une seule ligne ne le signale.
    ///
    /// Il s'ouvre maintenant parce que les deux surfaces qui le proposent savent demander son
    /// format ET le niveau de natation : l'inscription et l'assistant de nouvel objectif. La
    /// seconde était le piège — elle lit cette propriété exactement comme la première, donc
    /// ouvrir l'objectif l'y faisait apparaître sans ses deux questions. Un test le réclamait,
    /// et c'est en le faisant échouer qu'on a su qu'il fallait reprendre l'assistant.
    ///
    /// Le robinet reste. C'est par lui que passera le prochain objectif construit par morceaux,
    /// et une liste qui se filtre dit à qui la lit qu'un objectif peut exister dans le modèle
    /// sans être encore offert.
    var estProposable: Bool {
        switch self {
        case .race, .progress, .restart, .weight, .health, .hyrox, .ultraTrail, .triathlon:
            return true
        }
    }

    /// Cet objectif se périodise-t-il vers une DATE ?
    ///
    /// # CE QUE CETTE PROPRIÉTÉ RÉPARE
    ///
    /// La liste était écrite en dur au milieu de `ProgramShape.compute` : `goal == .race ||
    /// goal == .hyrox`. L'ultra-trail n'y figurait pas, donc son plan tombait dans la branche
    /// « programme ouvert » : zéro semaine de base, zéro de spécifique, zéro d'affûtage, et un
    /// cycle base/décharge qui tourne indéfiniment.
    ///
    /// Autrement dit : les onze séances d'ultra existaient, le moteur savait les produire, et il
    /// n'en servait jamais que deux blocs sur quatre — parce que personne ne lui avait dit que cet
    /// objectif avait une ligne d'arrivée. Pas de bloc spécifique, donc aucune sortie longue
    /// spécifique, aucun enchaînement du week-end, aucune sortie de nuit, aucun affûtage. Un plan
    /// d'ultra sans affûtage, c'est une course qu'on aborde fatiguée.
    ///
    /// La liste vit désormais sur le type, pour que l'oubli ne puisse plus se répéter en silence :
    /// ajouter un objectif à date force à répondre ici.
    var periodiseVersUneDate: Bool {
        switch self {
        // Le triathlon a une date, et il en a plus besoin que les autres : l'affûtage d'une
        // épreuve à trois disciplines ne consiste pas à réduire un volume mais trois, et
        // l'enchaînement vélo→course est la dernière chose à relâcher.
        case .race, .hyrox, .ultraTrail, .triathlon: return true
        case .progress, .restart, .weight, .health: return false
        }
    }

    /// LE NOMBRE MINIMAL DE JOURS PAR SEMAINE QUE CET OBJECTIF EXIGE.
    ///
    /// Deux pour tout ce qui se court : c'est peu, et c'est assumé — quelqu'un qui ne peut donner
    /// que deux séances mérite un plan plutôt qu'un refus.
    ///
    /// TROIS POUR LE TRIATHLON, et ce n'est pas une préférence. Une semaine à deux jours ne peut
    /// pas contenir trois disciplines : il en manquerait forcément une, et ce serait la natation
    /// — celle qui arrive en dernier dans l'ordre de priorité des séances, et celle dont
    /// l'absence ne se verrait nulle part puisque l'app ne la mesure pas. Un plan de triathlon
    /// sans natation porterait le nom du format et n'en préparerait que deux tiers.
    ///
    /// Ce nombre vivait en littéral dans QUATRE endroits — l'inscription, l'écran des jours,
    /// l'assistant de nouvel objectif et les réglages du programme. Il ne pouvait donc pas
    /// dépendre de l'objectif, et la question ne s'était jamais posée. Elle se pose ici.
    var joursMinimumParSemaine: Int {
        switch self {
        case .race, .progress, .restart, .weight, .health, .hyrox, .ultraTrail: return 2
        case .triathlon: return 3
        }
    }

    /// Recovery length (days) once a 9-week program built for this goal ends. See README § 14.
    var recoveryDays: Int {
        switch self {
        case .race: return 6
        case .weight: return 3
        case .progress: return 4
        case .restart: return 5
        case .health: return 3
        case .hyrox: return 6
        // Sept jours : c'est l'épreuve qui laisse les traces les plus longues de la liste.
        // Un ultra ne se récupère pas en quatre jours, et proposer de repartir trop tôt est
        // le meilleur moyen de transformer une belle course en blessure.
        case .ultraTrail: return 7
        // Six jours, comme une course sur route — mais pour une raison différente : ce n'est pas
        // la distance qui laisse des traces, c'est d'avoir tenu trois disciplines dans la même
        // journée. Un format long tire plus que ça ; c'est le plan de la préparation suivante
        // qui s'en charge, pas ce compteur-là.
        case .triathlon: return 6
        }
    }
}

/// HYROX division — Open uses lighter prescribed loads than Pro. Deliberately no kg figures
/// anywhere in the app for either division (see `AdaptivePlanEngine.hyroxArchetypes`) — this app
/// has no verified current-season rulebook weights to assert as fact, and a wrong "real" number
/// would be exactly the kind of fake precision this codebase has been fixing everywhere else.
enum HyroxDivision: String, Codable, CaseIterable, Identifiable {
    case open, pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: return "Open"
        case .pro: return "Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .open: return String(localized: "Charges standard — le format le plus couru")
        case .pro: return String(localized: "Charges renforcées — pour un niveau confirmé")
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case debutante, intermediaire, confirmee

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debutante: return String(localized: "Débutante")
        case .intermediaire: return String(localized: "Intermédiaire")
        case .confirmee: return String(localized: "Confirmée")
        }
    }

    var subtitle: String {
        switch self {
        case .debutante: return String(localized: "Je cours depuis moins de 6 mois")
        case .intermediaire: return String(localized: "Je cours 2-3 fois par semaine")
        case .confirmee: return String(localized: "Je m'entraîne sérieusement depuis des années")
        }
    }
}

enum RaceDistance: String, Codable, CaseIterable, Identifiable {
    case k5, k10, semi, marathon, other
    // Les quatre formats d'ultra. Séparés des distances de route et JAMAIS mélangés à l'écran :
    // proposer « 5 km » à quelqu'un qui prépare un 100 miles, ou « 100 km » à quelqu'un qui
    // prépare son premier 10, c'est faire relire toute la grille pour rien.
    case ultra50, ultra80, ultra100, ultra100M

    var id: String { rawValue }

    var label: String {
        switch self {
        case .k5: return "5 km"
        case .k10: return "10 km"
        case .semi: return String(localized: "Semi")
        case .marathon: return String(localized: "Marathon")
        case .other: return String(localized: "Autre distance")
        case .ultra50: return "50 km"
        case .ultra80: return "80 km"
        case .ultra100: return "100 km"
        case .ultra100M: return "100 miles"
        }
    }

    /// Les distances à proposer pour un objectif donné.
    ///
    /// `allCases` ne convient plus depuis qu'il y a des formats d'ultra : la grille montrerait
    /// « 5 km » à quelqu'un qui prépare un 100 miles. Deux listes, chacune complète pour son
    /// monde, et « Autre distance » dans les deux — c'est par là que passent l'Ekiden, le trail
    /// de 22 km et le 110 km qui n'est dans aucune liste.
    static func choix(pour objectif: GoalType?) -> [RaceDistance] {
        objectif == .ultraTrail
            ? [.ultra50, .ultra80, .ultra100, .ultra100M, .other]
            : [.k5, .k10, .semi, .marathon, .other]
    }

    var chronoPresets: [String] {
        switch self {
        case .k5: return ["20:00", "22:30", "25:00", "28:00"]
        case .k10: return ["42:00", "47:30", "52:00", "58:00"]
        case .semi: return ["1:40", "1:50", "2:00", "2:15"]
        case .marathon: return ["3:30", "3:50", "4:15", "4:45"]
        case .other: return []
        // Des temps de FINISSEUR, pas des objectifs de performance : en ultra, la question
        // n'est pas « combien » mais « est-ce que j'arrive au bout ». Les fourchettes sont
        // celles d'un parcours de montagne ordinaire pour chaque format.
        case .ultra50: return ["6:00", "7:30", "9:00", "11:00"]
        case .ultra80: return ["10:00", "12:00", "15:00", "18:00"]
        case .ultra100: return ["13:00", "16:00", "20:00", "24:00"]
        case .ultra100M: return ["24:00", "30:00", "36:00", "44:00"]
        }
    }

    /// nil for `.other` — a bare enum case has no way to hold the number from a free-text custom
    /// distance ("Trail 22 km"). That number still exists on `UserProfile.raceDistanceCustom`
    /// though, so anything scaling pace/periodization to the real race distance should read
    /// `UserProfile.effectiveRaceDistanceKm` instead of this property directly — it falls back to
    /// parsing the custom text rather than silently discarding a real, just-not-preset distance.
    var km: Double? {
        switch self {
        case .k5: return 5
        case .k10: return 10
        case .semi: return 21.0975
        case .marathon: return 42.195
        case .ultra50: return 50
        case .ultra80: return 80
        case .ultra100: return 100
        // 100 miles. La valeur exacte, pas 160 : c'est elle qui alimente le temps d'effort, et
        // un kilomètre d'écart sur un format pareil vaut dix minutes debout.
        case .ultra100M: return 160.934
        case .other: return nil
        }
    }
}

enum ConnectedSource: String, Codable, CaseIterable, Identifiable {
    case apple, strava, garmin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return String(localized: "Apple Santé")
        case .strava: return "Strava"
        case .garmin: return "Garmin Connect"
        }
    }

    var subtitle: String {
        switch self {
        case .apple: return String(localized: "FC, sommeil, course")
        case .strava: return String(localized: "Historique & segments")
        case .garmin: return String(localized: "Montre & données avancées")
        }
    }

    /// Apple Health (HealthKit) and Strava (real OAuth, see `StravaService`) both have a real
    /// integration; Garmin is still a UI stub.
    var isNativelySupported: Bool { self == .apple || self == .strava }
}

enum ProgramPhase: String, Codable {
    case active, recovery, choice, freerun
}

enum RPE: Int, Codable, CaseIterable, Identifiable {
    case tropDur, dur, justeBien, facile

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .tropDur: return "😮‍💨"
        case .dur: return "😤"
        case .justeBien: return "🙂"
        case .facile: return "😎"
        }
    }

    var label: String {
        switch self {
        case .tropDur: return String(localized: "Trop dur")
        case .dur: return String(localized: "Dur")
        case .justeBien: return String(localized: "Juste bien")
        case .facile: return String(localized: "Facile")
        }
    }
}
