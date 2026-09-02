import Foundation

/// La frontière entre ce que RUNUP donne et ce que RUNUP Plus vend.
///
/// # Pourquoi elle existe
///
/// L'app était entièrement verrouillée après sept jours. Le raisonnement se tenait — c'est le
/// modèle de Runna — mais il avait une conséquence que personne n'avait regardée en face : le
/// Club, le fil d'amis, les classements, les défis et les itinéraires partagés se trouvaient
/// derrière le mur. Or une fonctionnalité sociale sans monde ne vaut rien. Personne ne paye pour
/// rejoindre un club vide, donc le club reste vide, donc personne ne paye. Le parrainage
/// souffrait du même mal : il recrutait des gens qui heurtaient le mur une semaine plus tard.
///
/// # Où passe la frontière, et pourquoi là
///
/// **Le suivi est gratuit parce qu'il est devenu gratuit partout.** Nike Run Club le donne, Apple
/// aussi. Faire payer un chronomètre et un tracé GPS, c'est vendre ce que tout le monde offre —
/// et se priver des gens qui remplissent le Club.
///
/// **Le coach est payant parce que personne ne l'a.** Le programme périodisé qui se recalcule sur
/// la forme du jour, le coach qui a lu l'historique, la voix dans les écouteurs pendant l'effort :
/// c'est le produit. C'est ce qui vaut 6,99 € par mois, et rien d'autre ici ne les vaut.
///
/// Ce découpage est celui de Strava — gratuit pour enregistrer et partager, payant pour analyser
/// et planifier — et il tient pour la même raison : le gratuit n'est pas une perte de revenu,
/// c'est ce qui donne au payant quelque chose à quoi se rattacher.
enum PlusFeature: String, CaseIterable, Identifiable, Sendable {
    /// Le programme périodisé et son adaptation après chaque sortie.
    case adaptivePlan
    /// Le coach écrit, qui connaît l'objectif et l'historique.
    case coach
    /// Le coach à la voix pendant la course.
    case voiceCoach
    /// Préparer une date de course : périodisation, affûtage, compte à rebours.
    case raceGoal
    /// Prédictions 5 km, 10 km, semi, marathon.
    case predictions
    /// Charge d'entraînement sur huit semaines.
    case trainingLoad

    // Le bilan de la semaine a failli être vendu, et il est resté gratuit délibérément. C'est le
    // rendez-vous du dimanche soir : la chose qui fait rouvrir l'app quand on n'a pas couru. Le
    // vendre reviendrait à faire payer la raison de revenir, chez des gens qui ne sont pas encore
    // convaincus — et à vider le Club de ceux qui le peuplent.

    var id: String { rawValue }

    /// Le nom de la fonctionnalité tel qu'il apparaît sur le verrou. Court : il est lu par
    /// quelqu'un qui vient de heurter une porte fermée et qui décide en une seconde s'il insiste.
    var title: String {
        switch self {
        case .adaptivePlan: return String(localized: "Ton programme qui s'adapte")
        case .coach: return String(localized: "Ton coach personnel")
        case .voiceCoach: return String(localized: "Le coach dans tes écouteurs")
        case .raceGoal: return String(localized: "Préparer une course")
        case .predictions: return String(localized: "Tes temps prévus")
        case .trainingLoad: return String(localized: "Ta charge d'entraînement")
        }
    }

    /// Ce que la personne gagne, pas ce que la fonctionnalité fait. Un verrou qui décrit une
    /// mécanique ne vend rien ; un verrou qui décrit un bénéfice se lit jusqu'au bout.
    var pitch: String {
        switch self {
        case .adaptivePlan:
            return String(localized: "Un plan périodisé calé sur ton objectif, qui se recalcule après chaque sortie selon ta forme et ton ressenti.")
        case .coach:
            return String(localized: "Il a lu tes dernières séances. Pose-lui une question avant de partir, demande un conseil, fais-toi rassurer après une sortie difficile.")
        case .voiceCoach:
            return String(localized: "Appuie, pose ta question à voix haute, il te répond dans les écouteurs — sans sortir le téléphone.")
        case .raceGoal:
            return String(localized: "Base, spécifique, affûtage : un vrai plan calé sur la date de ta course, de 4 à 20 semaines.")
        case .predictions:
            return String(localized: "Ce que tu vaux aujourd'hui sur 5 km, 10 km, semi et marathon, d'après tes vraies sorties.")
        case .trainingLoad:
            return String(localized: "Huit semaines de charge en un coup d'œil, pour voir venir le surmenage avant qu'il ne te blesse.")
        }
    }
}

/// Ce que l'app déverrouille, et pour qui.
enum Entitlement {
    /// La règle, en une décision.
    ///
    /// `isSubscribed` à `nil` veut dire « on ne sait pas encore » : la vérification StoreKit n'a
    /// pas répondu. On laisse passer. Verrouiller pendant ce temps ferait clignoter un verrou
    /// devant une abonnée à chaque lancement — bref, mais insultant, et c'est la pire chose qu'un
    /// écran de vente puisse faire.
    ///
    /// `canSell` à `false` déverrouille tout, quelle qu'en soit la raison : réseau coupé, panne
    /// StoreKit, produit pas encore approuvé. C'est la règle qui existait déjà pour l'app entière
    /// (`SubscriptionService.grantsAccess`), et elle vaut ici pour la même raison — un écran qui
    /// ne peut rien encaisser n'a pas le droit de bloquer. Le petit risque d'abus est très en
    /// dessous du coût de la panne qu'il évite.
    /// Le dernier état connu de l'abonnement, hors de tout écran.
    ///
    /// `SubscriptionService` est `@MainActor` et vit dans l'environnement SwiftUI : les
    /// notifications locales, la synchronisation avec la montre et tout ce qui tourne sans
    /// interface ne peuvent pas l'interroger. Ils lisaient donc le programme comme si de rien
    /// n'était, et une personne sans abonnement recevait chaque matin le nom exact de la séance
    /// qu'elle ne peut pas ouvrir.
    ///
    /// Écrit dans le groupe d'app, à côté de l'instantané des widgets, pour la même raison : c'est
    /// le seul endroit que les extensions savent lire.
    ///
    /// Volontairement optimiste au démarrage — `nil` vaut « ouvert ». Une valeur absente signifie
    /// qu'aucune vérification n'a encore eu lieu, jamais qu'il n'y a pas d'abonnement, et fermer
    /// par défaut ferait taire les rappels d'une abonnée le temps d'un premier lancement.
    private static let cacheKey = "runup.entitlement.plus-active"
    private static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: DailyGoalsSnapshot.appGroupID) }

    static var hasPlusCached: Bool {
        guard let defaults = sharedDefaults,
              defaults.object(forKey: cacheKey) != nil else { return true }
        return defaults.bool(forKey: cacheKey)
    }

    static func cacheHasPlus(_ active: Bool) {
        sharedDefaults?.set(active, forKey: cacheKey)
    }

    static func unlocks(_ feature: PlusFeature, isSubscribed: Bool?, canSell: Bool) -> Bool {
        _ = feature // Aucune fonctionnalité n'a de régime particulier aujourd'hui — mais la
                    // signature le permet sans avoir à retoucher les appelants le jour où l'une
                    // d'elles passe du gratuit au payant, ou l'inverse.
        if isSubscribed == true { return true }
        if !canSell { return true }
        return isSubscribed ?? true
    }
}
