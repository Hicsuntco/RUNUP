import Foundation

// ─── CE QUE LE PLAN INVENTAIT, ET QU'IL DEMANDE DÉSORMAIS ──────────────────────────────────
//
// Trois nombres décidaient de tout un programme sans que personne ne les ait jamais donnés.
//
// LA PREMIÈRE SORTIE LONGUE était calculée depuis la DISTANCE DE LA COURSE : un plan marathon
// posait 8,4 km en semaine 1 — `max(5, min(raceKm * 0.55, 14) * 0.6)` — que la personne coure
// trois kilomètres ou vingt-cinq. Le moteur a pourtant une règle anti-blessure, les +10 % par
// semaine de `rampedLongRunKm` ; elle partait simplement d'un point de départ deviné. Une règle
// de progression rigoureuse appliquée à un point de départ faux donne une progression fausse.
//
// TOUTES LES ALLURES du plan descendent d'un seul nombre. Pour une course il était tiré du TEMPS
// VISÉ, c'est-à-dire d'une ambition et non d'une capacité ; pour les huit autres objectifs,
// d'une des trois constantes du niveau déclaré. « Ta meilleure perf récente » existait déjà,
// mais seulement sur l'objectif « Progresser », et marquée facultative.
//
// LE VOLUME ACTUEL ne servait qu'à l'objectif « (Re)commencer », par la question « ta dernière
// sortie remonte à ». Quelqu'un qui court une fois par mois et quelqu'un qui court quatre fois
// par semaine partaient du même palier dès lors qu'ils cochaient le même niveau.
//
// Les réponses sont des TRANCHES et non des champs libres : on demande ici un ordre de grandeur,
// que tout le monde connaît sur soi, et pas un relevé. Chaque tranche porte la valeur que le
// moteur utilise — c'est elle qui compte, le libellé n'est que son habillage.

/// Combien de fois elle court par semaine, EN CE MOMENT.
enum VolumeActuel: String, Codable, CaseIterable, Identifiable {
    case aucune, uneOuDeux, troisOuQuatre, cinqEtPlus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aucune: return String(localized: "Je ne cours pas en ce moment")
        case .uneOuDeux: return String(localized: "1 à 2 fois par semaine")
        case .troisOuQuatre: return String(localized: "3 à 4 fois par semaine")
        case .cinqEtPlus: return String(localized: "5 fois ou plus")
        }
    }

    /// Le nombre que le moteur utilise — le BAS de la tranche, pas son milieu.
    ///
    /// Une semaine de plan bâtie sur un volume surestimé se paie en blessure ; bâtie sur un
    /// volume sous-estimé, elle se paie en une semaine un peu facile, que le ressenti corrigera
    /// dès le dimanche suivant. Les deux erreurs ne coûtent pas la même chose.
    var sortiesParSemaine: Int {
        switch self {
        case .aucune: return 0
        case .uneOuDeux: return 1
        case .troisOuQuatre: return 3
        case .cinqEtPlus: return 5
        }
    }
}

/// La plus longue sortie des quatre dernières semaines — le point d'où part la progression.
///
/// Quatre semaines, et pas « jamais » : une sortie longue d'il y a deux ans ne dit rien de ce que
/// les jambes savent faire aujourd'hui, et c'est précisément la confusion qui produit les
/// reprises trop ambitieuses.
enum PlusLongueSortie: String, Codable, CaseIterable, Identifiable {
    case aucune, moinsDe3, de3a5, de5a10, de10a15, de15a25, plusDe25

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aucune: return String(localized: "Aucune")
        case .moinsDe3: return String(localized: "Moins de 3 km")
        case .de3a5: return String(localized: "3 à 5 km")
        case .de5a10: return String(localized: "5 à 10 km")
        case .de10a15: return String(localized: "10 à 15 km")
        case .de15a25: return String(localized: "15 à 25 km")
        case .plusDe25: return String(localized: "Plus de 25 km")
        }
    }

    /// Le bas de la tranche, pour la même raison que `sortiesParSemaine` — sauf pour « aucune »,
    /// qui vaut deux kilomètres et non zéro : un plan ne peut pas partir de rien, et deux
    /// kilomètres est la distance qu'on tient en alternant course et marche.
    var km: Double {
        switch self {
        case .aucune: return 2
        case .moinsDe3: return 2
        case .de3a5: return 3
        case .de5a10: return 5
        case .de10a15: return 10
        case .de15a25: return 15
        case .plusDe25: return 25
        }
    }
}

/// L'allure d'un footing tranquille, telle qu'elle la connaît.
///
/// LE REPLI, ET PAS LA SOURCE PRINCIPALE. Une performance récente réelle — « 10 km en 52 min » —
/// vaut toujours mieux : elle porte une distance ET un temps, donc elle se projette. Cette
/// question existe pour les gens qui n'ont pas de chrono à donner, et qui sont la majorité ;
/// sans elle, leur plan entier retombe sur une des trois constantes du niveau déclaré.
///
/// `jeNeSaisPas` est un vrai choix, et le premier de la liste : inventer un chiffre pour pouvoir
/// passer l'écran serait pire que de ne pas répondre, puisque le plan le prendrait au mot.
enum AllureFooting: String, Codable, CaseIterable, Identifiable {
    case jeNeSaisPas, plusDe7, de6a7, de5a6, moinsDe5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jeNeSaisPas: return String(localized: "Je ne sais pas")
        case .plusDe7: return String(localized: "Plus de 7 min/km")
        case .de6a7: return String(localized: "6 à 7 min/km")
        case .de5a6: return String(localized: "5 à 6 min/km")
        case .moinsDe5: return String(localized: "Moins de 5 min/km")
        }
    }

    /// Le milieu de la tranche, en secondes par kilomètre — ici le bas serait le MAUVAIS choix.
    ///
    /// Les deux autres questions parlent de charge, où sous-estimer est prudent. Celle-ci parle
    /// d'allure : sous-estimer donne des footings trop lents, que personne ne tient, et des
    /// séances de qualité qui n'en sont plus. Le milieu de la tranche est la réponse honnête.
    var secondesParKm: Double? {
        switch self {
        case .jeNeSaisPas: return nil
        case .plusDe7: return 450    // 7:30
        case .de6a7: return 390      // 6:30
        case .de5a6: return 330      // 5:30
        case .moinsDe5: return 270   // 4:30
        }
    }
}

/// Le temps qu'elle a POUR UNE SÉANCE — en semaine, et le week-end.
///
/// # LA QUESTION EXISTAIT, ET LE PLAN NE LA LISAIT PAS
///
/// « Temps que tu veux y consacrer / semaine » était posée à l'objectif « Rester en forme », et
/// sa réponse n'allait nulle part : `weeklyTimeBudget` n'était lu que par `CoachService`, pour
/// écrire une phrase dans le contexte envoyé au modèle. Le générateur de séances ne l'a jamais
/// ouverte. Quelqu'un qui répondait « moins d'1 h par semaine » recevait exactement le même plan
/// que quelqu'un qui répondait « plus de 3 h ».
///
/// Un total hebdomadaire était de toute façon la mauvaise unité : ce qui empêche de faire une
/// séance, c'est le temps d'UN jour. Une heure et demie le dimanche et quarante minutes le
/// mardi, ce n'est pas la même semaine que deux heures réparties n'importe comment.
///
/// Deux questions, donc, et deux seulement : le jour de semaine et le week-end. Un plafond par
/// jour serait plus juste et serait invivable à remplir.
enum TempsDisponible {
    /// 0 = lundi … 6 = dimanche, comme partout ailleurs dans l'app.
    static func estWeekEnd(_ jour: Int) -> Bool { jour >= 5 }

    /// Les propositions, en minutes. Le week-end va plus loin parce que c'est là que tombe la
    /// sortie longue, et plus bas nulle part : trente minutes restent trente minutes.
    static let enSemaine = [30, 45, 60, 90]
    static let leWeekEnd = [45, 60, 90, 120, 180]

    /// « 45 min », « 1h30 » — par le formateur de durée de l'app, pas par une chaîne à traduire.
    static func libelle(_ minutes: Int) -> String { TimeFormat.duree(minutes * 60) }

    /// Le plafond qui s'applique à une séance tombant ce jour-là, ou `nil` quand rien n'a été
    /// répondu — auquel cas le plan garde exactement la durée qu'il aurait eue.
    static func plafond(jour: Int, semaine: Int?, weekEnd: Int?) -> Int? {
        estWeekEnd(jour) ? weekEnd : semaine
    }
}

/// Depuis quand la blessure — et est-ce qu'elle gêne ENCORE.
///
/// # UNE ENTORSE D'IL Y A TROIS ANS ALLÉGEAIT LE PLAN POUR TOUJOURS
///
/// L'inscription demandait OÙ, jamais QUAND. Et `adjustForWellbeing` en tirait une conséquence
/// permanente : toute séance de vitesse raccourcie de 30 %, passée en Z2-3, avec la mention
/// « impact réduit » — chaque semaine, indéfiniment. Quelqu'un qui avait coché « genou » en
/// pensant à une vieille histoire recevait un plan bridé pour toujours, sans jamais comprendre
/// pourquoi ses séances de qualité n'en étaient pas.
///
/// Le champ n'est posé que si une zone a été cochée : on ne demande pas « depuis quand » à
/// quelqu'un qui vient de répondre « aucune ».
enum AncienneteBlessure: String, Codable, CaseIterable, Identifiable {
    case enCours, moinsDe3Mois, de3a12Mois, plusDUnAn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .enCours: return String(localized: "Ça me gêne en ce moment")
        case .moinsDe3Mois: return String(localized: "Il y a moins de 3 mois")
        case .de3a12Mois: return String(localized: "Il y a 3 à 12 mois")
        case .plusDUnAn: return String(localized: "Il y a plus d'un an")
        }
    }

    /// Le plan doit-il s'alléger ?
    ///
    /// Oui tant que c'est en cours ou récent — trois mois est la borne au-delà de laquelle un
    /// tissu banal a cicatrisé et où continuer de brider coûte plus que ça ne protège. Au-delà,
    /// la zone reste connue du coach, qui saura en parler ; elle ne décide plus du programme.
    var demandeUneAdaptation: Bool {
        switch self {
        case .enCours, .moinsDe3Mois: return true
        case .de3a12Mois, .plusDUnAn: return false
        }
    }
}

/// Le terrain dont elle dispose vraiment.
///
/// Le plan prescrivait « Côtes longues » et « Descente technique » sans jamais demander s'il y
/// avait une côte à moins de vingt kilomètres. Prescrire une séance infaisable ne rend pas le
/// plan exigeant : il rend la semaine incomplète, et c'est la coureuse qui croit avoir échoué.
enum Terrain: String, Codable, CaseIterable, Identifiable {
    case plat, vallonne, piste, trail, tapis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plat: return String(localized: "Plat / route")
        case .vallonne: return String(localized: "Vallonné")
        case .piste: return String(localized: "Piste d'athlé")
        case .trail: return String(localized: "Trail / sentiers")
        case .tapis: return String(localized: "Tapis de course")
        }
    }

    /// Ce terrain offre-t-il du dénivelé ?
    ///
    /// Le tapis n'en fait PAS partie, et c'est un arbitrage : sa pente permet les côtes mais
    /// jamais les descentes, et une séance de descente est précisément celle qui détruit les
    /// quadriceps le jour J. Promettre le relief sur un tapis tiendrait à moitié, ce qui est la
    /// pire des trois réponses possibles.
    var offreDuRelief: Bool {
        switch self {
        case .vallonne, .trail: return true
        case .plat, .piste, .tapis: return false
        }
    }
}

/// Ce qu'elle fait d'autre, et qui mange la même récupération.
///
/// Rien n'était demandé. Trois séances de renforcement par semaine ne laissent pas les mêmes
/// jambes qu'un plan de course seul, et le programme en posait deux de qualité dans tous les
/// cas.
enum AutreSport: String, Codable, CaseIterable, Identifiable {
    case muscu, velo, natation, sportsCo, yoga

    var id: String { rawValue }

    var title: String {
        switch self {
        case .muscu: return String(localized: "Muscu / renfo")
        case .velo: return String(localized: "Vélo")
        case .natation: return String(localized: "Natation")
        case .sportsCo: return String(localized: "Sports co")
        case .yoga: return String(localized: "Yoga / mobilité")
        }
    }

    /// Pèse-t-il sur les jambes comme une séance de qualité en course ?
    ///
    /// La même question que `SessionKind.disciplines` pose déjà au plafond hebdomadaire du
    /// moteur, et la même réponse : ce qui compte est l'IMPACT, pas la dépense. Le vélo et la
    /// natation fatiguent sans marteler, et c'est exactement ce qui fait d'eux de la
    /// récupération active plutôt qu'une charge de plus.
    var peseSurLesJambes: Bool {
        switch self {
        case .muscu, .sportsCo: return true
        case .velo, .natation, .yoga: return false
        }
    }
}
