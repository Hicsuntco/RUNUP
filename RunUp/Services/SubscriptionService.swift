import Foundation
import StoreKit
import Observation

/// L'abonnement RUNUP Plus, côté app.
///
/// # Pourquoi l'essai n'est pas un compte à rebours maison
///
/// Le modèle retenu est celui de Runna : sept jours d'essai, puis l'app est verrouillée. La façon
/// naïve de le faire est de stocker une date de premier lancement et de compter. Elle a trois
/// défauts qu'aucun code ne rattrape : la date est reculée en changeant l'heure du téléphone, elle
/// se réinitialise à la réinstallation, et elle ne suit pas l'utilisatrice d'un appareil à l'autre.
///
/// L'essai est donc une **offre d'introduction** déclarée sur l'abonnement dans App Store Connect.
/// L'utilisatrice s'abonne dès le départ, Apple ne prélève rien pendant sept jours, et elle peut
/// résilier depuis les Réglages. L'app n'a plus qu'une question à poser — « cet abonnement est-il
/// actif ? » — à laquelle StoreKit répond avec une transaction signée par Apple, valable sur tous
/// ses appareils et impossible à contrefaire depuis le téléphone.
///
/// # Ce que cette classe ne fait pas
///
/// Elle vérifie l'abonnement SUR L'APPAREIL. C'est solide contre la falsification ordinaire — la
/// signature est vérifiée par StoreKit — mais un appareil débridé reste un appareil débridé. Le
/// coach est le seul point où ça coûte de l'argent à chaque appel : la vérification côté serveur
/// de `api/coach` est la suite logique, et elle est notée dans `IOS_SETUP.md`.
@MainActor
@Observable
final class SubscriptionService {
    /// Les identifiants à créer à l'identique dans App Store Connect. Le groupe d'abonnement doit
    /// contenir les deux : sans quoi passer du mensuel à l'annuel serait un second abonnement au
    /// lieu d'un changement de formule, et l'utilisatrice paierait deux fois.
    enum ProductID {
        static let monthly = "com.hicsuntco.runup.plus.monthly"
        static let yearly = "com.hicsuntco.runup.plus.yearly"
        static let all: [String] = [yearly, monthly]
    }

    /// Les formules à afficher, l'annuel d'abord — c'est celui qui est mis en avant.
    private(set) var products: [Product] = []
    /// `nil` tant que la première vérification n'a pas eu lieu. La distinction compte : afficher
    /// le paywall à quelqu'un qui EST abonné, le temps d'une requête réseau, est la pire
    /// expérience que cet écran puisse produire.
    private(set) var isSubscribed: Bool?
    private(set) var loadFailed = false
    /// L'App Store a répondu que ces identifiants n'existent pas.
    ///
    /// C'est un état de LANCEMENT, pas une panne : tant que les produits ne sont pas créés dans
    /// App Store Connect, il n'y a rien à vendre — et enfermer quelqu'un dehors d'une app qu'on
    /// ne peut pas lui vendre est la pire des deux erreurs possibles. L'app reste donc ouverte
    /// tant que c'est le cas, et le verrou se referme tout seul le jour où les produits existent.
    ///
    /// Le distinguo tient parce que StoreKit distingue les deux cas : `Product.products(for:)`
    /// renvoie un tableau VIDE pour des identifiants inconnus, et LÈVE une erreur quand elle ne
    /// peut pas joindre l'App Store. Couper le réseau ne donne donc pas l'app gratuitement — ça
    /// donne `loadFailed`, qui ne déverrouille rien.
    private(set) var productsUnavailable = false
    private(set) var isPurchasing = false

    init() {
        // Démarré avant tout achat, et jamais annulé tant que l'app vit : c'est par là qu'arrivent
        // les renouvellements, les remboursements, les achats faits sur un autre appareil et les
        // transactions qu'Apple rejoue après une interruption au milieu d'un paiement.
        // Pas de `Task` retenue ni de `deinit` pour l'annuler : la classe est `@MainActor`, donc
        // `deinit` — qui ne l'est pas — ne peut pas lire une de ses propriétés. La boucle se
        // termine d'elle-même par le `guard let self` ci-dessous dès que l'objet disparaît, ce qui
        // est le seul mécanisme dont on ait besoin : ce service vit aussi longtemps que l'app.
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
    }

    func start() async {
        // Les produits AVANT le droit d'accès : c'est le chargement des produits qui dit s'il y a
        // quelque chose à vendre, et l'aiguillage lit les deux ensemble.
        await loadProducts()
        await refreshEntitlement()
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: ProductID.all)
            // Ordre imposé, pas celui d'Apple : l'annuel en premier parce que c'est la formule
            // mise en avant, et `Product.products(for:)` ne garantit aucun ordre.
            products = ProductID.all.compactMap { id in fetched.first { $0.id == id } }
            loadFailed = false
            productsUnavailable = products.isEmpty
        } catch {
            loadFailed = true
            productsUnavailable = false
        }
    }

    /// Y a-t-il quelque chose à vendre ?
    ///
    /// Non veut dire : réseau coupé, panne StoreKit, ou produit pas encore approuvé. Dans ce cas
    /// tout se déverrouille — un écran qui ne peut rien encaisser n'a pas le droit de bloquer.
    ///
    /// La première version distinguait « produits inexistants » (on laisse entrer) de « échec de
    /// chargement » (on verrouille), pour qu'on ne puisse pas s'offrir l'app en coupant le
    /// réseau. C'était le bon raisonnement sur le mauvais critère : la conséquence réelle a été
    /// un verrou affichant « Les formules n'ont pas pu être chargées » au-dessus d'un bouton qui
    /// ne mène nulle part. Le petit risque d'abus que la règle laisse est très en dessous du coût
    /// de la panne qu'elle évite.
    var canSell: Bool { !products.isEmpty }

    /// La seule question que les écrans posent : cette fonctionnalité-là est-elle ouverte ?
    ///
    /// La décision vit dans `Entitlement`, sous test, plutôt qu'ici où elle serait mêlée à
    /// StoreKit et invérifiable autrement qu'en achetant vraiment un abonnement.
    func unlocks(_ feature: PlusFeature) -> Bool {
        Entitlement.unlocks(feature, isSubscribed: isSubscribed, canSell: canSell)
    }

    /// L'état d'abonnement, relu depuis les droits courants plutôt que mémorisé.
    ///
    /// `currentEntitlements` ne renvoie que ce qui est actif MAINTENANT : un abonnement résilié,
    /// expiré ou remboursé en disparaît de lui-même. Stocker un booléen au moment de l'achat
    /// laisserait l'accès ouvert après un remboursement.
    func refreshEntitlement() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            if let revoked = transaction.revocationDate, revoked <= .now { continue }
            if let expiry = transaction.expirationDate, expiry <= .now { continue }
            active = true
        }
        isSubscribed = active
    }

    enum PurchaseOutcome { case subscribed, cancelled, pending, failed }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                await transaction.finish()
                await refreshEntitlement()
                return isSubscribed == true ? .subscribed : .failed
            case .userCancelled:
                return .cancelled
            // « En attente » n'est pas un échec : c'est le cas Ask to Buy, où un parent doit
            // approuver. La transaction arrivera plus tard par `Transaction.updates`.
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Obligatoire pour la validation App Store (guideline 3.1.1) : une utilisatrice qui change de
    /// téléphone doit pouvoir retrouver son abonnement sans repayer.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }
}
