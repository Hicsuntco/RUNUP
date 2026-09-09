import Foundation

/// Ce qu'il s'est passé quand la feuille de code promo s'est refermée.
///
/// La feuille est celle d'Apple : c'est elle qui reçoit le code, le vérifie et affiche ses propres
/// erreurs — « code invalide », « déjà utilisé », « pas éligible ». L'app n'a donc pas à commenter
/// la saisie, et elle ne le peut pas : le résultat qu'Apple lui rend dit seulement si l'écran a pu
/// s'ouvrir, pas si un code a été utilisé. La seule chose que l'app sache vraiment, c'est si
/// l'abonnement est actif juste après. Cette énumération ne dit rien de plus que ça.
enum OfferCodeOutcome: Equatable {
    /// Le droit est là après la fermeture de la feuille.
    case unlocked
    /// La feuille s'est ouverte et refermée sans que rien change. C'est le cas ORDINAIRE — on
    /// ouvre l'écran, on regarde, on referme — et il ne mérite aucun message.
    case nothingApplied
    /// L'écran n'a pas pu s'ouvrir. Rien à voir avec le code : StoreKit indisponible, ou un
    /// simulateur, où cette feuille n'existe pas.
    case sheetFailed

    static func decide(sheetFailed: Bool, isSubscribed: Bool?) -> OfferCodeOutcome {
        // Le droit d'abord, exactement comme pour la restauration : s'il est là, l'échec de la
        // feuille ne veut plus rien dire — on a obtenu ce qu'on venait chercher.
        if isSubscribed == true { return .unlocked }
        return sheetFailed ? .sheetFailed : .nothingApplied
    }

    /// `nil` veut dire : ne rien annoncer.
    ///
    /// Un « aucun code n'a été utilisé » après chaque fermeture de feuille serait un reproche
    /// adressé à quelqu'un qui a simplement regardé — et il serait affiché neuf fois sur dix.
    var message: String? {
        switch self {
        case .unlocked: return String(localized: "Bienvenue dans RUNUP Plus 🎉")
        case .nothingApplied: return nil
        case .sheetFailed: return String(localized: "L'écran des codes n'a pas pu s'ouvrir.")
        }
    }
}
