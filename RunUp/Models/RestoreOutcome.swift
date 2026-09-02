import Foundation

/// Ce qu'il faut dire après « Restaurer mes achats ».
///
/// Trois issues, et les confondre coûte cher. L'ancienne version n'en connaissait qu'une : elle
/// avalait l'échec de synchronisation puis regardait s'il existait un abonnement. Une panne de
/// réseau ressortait donc sous la forme « Aucun abonnement actif trouvé » — un message faux,
/// adressé à quelqu'un qui paye, au moment précis où il essaie de récupérer ce qu'il a payé.
///
/// Une règle à part plutôt qu'un `if` dans la vue : c'est la seule façon de la vérifier sans
/// acheter réellement un abonnement, et l'écart entre « je n'ai pas pu regarder » et « j'ai
/// regardé, il n'y a rien » est exactement le genre de nuance qu'on reperd au premier remaniement.
enum RestoreOutcome: Equatable {
    /// L'abonnement est retrouvé et actif.
    case restored
    /// La vérification a bien eu lieu, et il n'y a rien à restaurer sur ce compte Apple.
    case nothingFound
    /// On n'a pas pu vérifier. Ne dit RIEN sur l'existence d'un abonnement.
    case couldNotCheck

    static func decide(syncFailed: Bool, isSubscribed: Bool?) -> RestoreOutcome {
        // L'abonnement d'abord : si le droit est là, peu importe que la synchronisation ait
        // échoué — elle sert à aller CHERCHER ce qu'on a déjà trouvé.
        if isSubscribed == true { return .restored }
        if syncFailed { return .couldNotCheck }
        // `nil` veut dire que la vérification n'a pas abouti non plus, malgré une synchronisation
        // réussie. C'est encore un « je ne sais pas », pas un « il n'y a rien ».
        return isSubscribed == false ? .nothingFound : .couldNotCheck
    }

    var message: String {
        switch self {
        case .restored: return String(localized: "Ton abonnement est restauré.")
        case .nothingFound: return String(localized: "Aucun abonnement actif sur ce compte Apple.")
        case .couldNotCheck: return String(localized: "Impossible de vérifier — réessaie quand tu auras du réseau.")
        }
    }
}
