import Foundation

/// Ce qu'il faut dire après un achat d'abonnement.
///
/// # LE DÉFAUT QUI A FAIT NAÎTRE CE TYPE
///
/// La décision vivait dans `SubscriptionService.purchase(_:)`, en une ligne :
///
/// ```swift
/// await transaction.finish()
/// await refreshEntitlement()
/// return isSubscribed == true ? .subscribed : .failed
/// ```
///
/// Cette ligne annonce un ÉCHEC après une transaction VÉRIFIÉE et terminée — c'est-à-dire après
/// qu'Apple a signé l'achat et prélevé l'argent. Le paywall en tirait les trois pires
/// conséquences possibles d'un seul coup : l'avertissement « L'achat n'a pas abouti. » affiché à
/// quelqu'un qui vient de payer, un `purchaseFailed` enregistré dans les statistiques — donc un
/// taux d'échec faux, qui pousserait à corriger du code qui marche — et l'écran laissé ouvert
/// avec son bouton d'achat toujours actif, ce qui invite à retaper. C'est exactement le
/// raisonnement que le cas `.subscribed` du paywall tient déjà pour expliquer pourquoi il ferme.
///
/// Le droit d'accès N'ARRIVE PAS avec la fin de l'achat. `Transaction.currentEntitlements` le
/// publie quelques centaines de millisecondes plus tard, parfois plus. Le même piège était déjà
/// connu, documenté et contourné trente lignes plus bas, dans `applyRedemption(sheetFailed:)` :
/// « Poser la question une seule fois, tout de suite, répondrait “rien” à quelqu'un qui vient
/// d'entrer un code parfaitement valide. » Le code promo attendait ; l'achat, non.
///
/// # POURQUOI UN TYPE À PART, HORS DE STOREKIT
///
/// Comme `Entitlement`, `OfferCodeOutcome` et `RestoreOutcome` : c'est la seule façon de vérifier
/// la règle sans acheter réellement un abonnement. Un `.failed` rendu après une transaction
/// vérifiée ne se voit ni au compilateur, ni aux tests, ni au simulateur — il se voit le jour où
/// quelqu'un paye et que le réseau traîne, c'est-à-dire chez l'utilisatrice.
enum PurchaseOutcome: Equatable {
    /// Apple a signé l'achat ET le droit d'accès est là. Le cas ordinaire.
    case subscribed
    /// Apple a signé l'achat, le droit d'accès n'est pas encore publié.
    ///
    /// Ce n'est pas un échec, et ce n'est pas une incertitude : on TIENT la transaction vérifiée,
    /// qui est la preuve d'achat elle-même. Il ne manque que sa propagation dans
    /// `currentEntitlements`, que `Transaction.updates` finira de livrer. Le seul écart avec
    /// `.subscribed` est donc le message — et le fait que les statistiques puissent compter
    /// combien de fois l'attente n'a pas suffi.
    case purchasedAwaitingUnlock
    /// La personne a lu le prix et a dit non. À ne jamais ranger avec un échec : une annulation
    /// se corrige sur l'offre, un échec se corrige dans le code.
    case cancelled
    /// « Demander à acheter » : un parent doit approuver. La transaction arrivera plus tard par
    /// `Transaction.updates`.
    case pending
    /// L'achat n'a pas eu lieu, ou on ne peut pas s'y fier.
    case failed

    /// Ce que StoreKit a répondu, réduit à ce dont la décision a besoin.
    ///
    /// Un type à nous plutôt que `Product.PurchaseResult` : celui d'Apple transporte une
    /// transaction signée, ne se construit pas dans un test, et porte un cas `@unknown default`
    /// qu'on ne peut pas fabriquer. La traduction se fait en un `switch` de six lignes dans
    /// `SubscriptionService`, et la règle, elle, se teste.
    enum StoreKitResult: Equatable {
        /// `.success` avec une transaction `.verified`. Apple a signé : l'argent est engagé.
        case verified
        /// `.success` avec une transaction `.unverified`. La signature n'a pas été validée : on
        /// ne peut rien en conclure, ni dans un sens ni dans l'autre.
        case unverified
        case cancelled
        case pending
        /// Un cas ajouté par une version future de StoreKit (`@unknown default`).
        case unknown
        /// `product.purchase()` a levé.
        case threw
    }

    static func decide(result: StoreKitResult, isSubscribed: Bool?) -> PurchaseOutcome {
        switch result {
        // La transaction est signée par Apple. Le droit suivra ; son absence à cet instant ne
        // dit rien de l'achat, seulement de l'heure qu'il est.
        case .verified:
            return isSubscribed == true ? .subscribed : .purchasedAwaitingUnlock

        // StoreKit est formel sur ces deux-là, et il parle de CET achat : un abonnement déjà
        // actif par ailleurs ne transforme pas un refus en succès. C'est la différence avec les
        // cas ambigus ci-dessous, et c'est pour ça qu'ils ne lisent pas `isSubscribed`.
        case .cancelled:
            return .cancelled
        case .pending:
            return .pending

        // Les trois cas où l'on ne sait pas. Le droit tranche, comme dans `RestoreOutcome` et
        // `OfferCodeOutcome` : s'il est là, annoncer un échec serait faux. Et il est digne de foi
        // même ici — `refreshEntitlement()` ne compte que des transactions `.verified` portant
        // l'un de nos identifiants de produit, non révoquées et non expirées.
        case .unverified, .unknown, .threw:
            return isSubscribed == true ? .subscribed : .failed
        }
    }

    /// `nil` veut dire : ne rien annoncer.
    ///
    /// Seule l'annulation se tait. Le reste parle, y compris l'attente : un écran qui ferme sans
    /// un mot après un paiement laisse croire qu'il ne s'est rien passé.
    var message: String? {
        switch self {
        case .subscribed:
            return String(localized: "Bienvenue dans RUNUP Plus")
        case .purchasedAwaitingUnlock:
            return String(localized: "Paiement validé. Ton accès s'ouvre dans un instant.")
        case .pending:
            return String(localized: "Achat en attente d'approbation.")
        case .failed:
            return String(localized: "L'achat n'a pas abouti.")
        case .cancelled:
            return nil
        }
    }

    /// L'écran d'achat doit-il se refermer ?
    ///
    /// Oui dès qu'Apple a encaissé. Sans ça, Face ID validé et message passé, il reste à l'écran
    /// le héros « 7 jours offerts », les formules cochables et un bouton d'achat toujours actif :
    /// rien ne dit que ça a marché, et le geste naturel est de retaper.
    var ferme: Bool {
        switch self {
        case .subscribed, .purchasedAwaitingUnlock: return true
        case .cancelled, .pending, .failed: return false
        }
    }
}
