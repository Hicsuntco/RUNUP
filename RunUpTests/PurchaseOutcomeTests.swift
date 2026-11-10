import XCTest
@testable import RunUp

/// Verrouille ce qu'on répond après un achat d'abonnement.
///
/// Le cas qui a motivé ces tests est le plus coûteux que cette app puisse produire : une
/// transaction signée par Apple, l'argent prélevé, et à l'écran « L'achat n'a pas abouti. »
///
/// Il n'avait rien d'improbable. `purchase(_:)` posait la question du droit d'accès UNE FOIS,
/// immédiatement après `transaction.finish()`, alors que `Transaction.currentEntitlements` le
/// publie quelques centaines de millisecondes plus tard. Le même piège était déjà connu et
/// contourné trente lignes plus bas pour les codes promo ; l'achat, lui, répondait « échec ».
///
/// Et il ne se voyait d'aucune autre façon : ni au compilateur, ni dans un simulateur, où
/// l'entitlement arrive instantanément. Il se voyait chez l'utilisatrice, sur un réseau lent,
/// une fois sur combien — personne ne le saura, puisque la statistique elle-même l'enregistrait
/// comme un échec.
final class PurchaseOutcomeTests: XCTestCase {

    // MARK: - Le cas d'origine

    /// LE TEST QUI COMPTE. Transaction vérifiée, droit pas encore publié : jamais un échec.
    func testAVerifiedTransactionIsNeverAFailure() {
        XCTAssertEqual(PurchaseOutcome.decide(result: .verified, isSubscribed: nil),
                       .purchasedAwaitingUnlock)
        XCTAssertEqual(PurchaseOutcome.decide(result: .verified, isSubscribed: false),
                       .purchasedAwaitingUnlock)
    }

    /// Et le message qui accompagne cette issue ne doit pas être celui de l'échec — c'était là
    /// tout le défaut, pas dans le nom du cas.
    func testTheAwaitingUnlockMessageIsNotTheFailureMessage() {
        XCTAssertNotNil(PurchaseOutcome.purchasedAwaitingUnlock.message)
        XCTAssertNotEqual(PurchaseOutcome.purchasedAwaitingUnlock.message,
                          PurchaseOutcome.failed.message,
                          "Un achat encaissé par Apple annonce la même chose qu'un achat raté.")
    }

    /// Le cas ordinaire : signé, et le droit est là.
    func testAVerifiedTransactionWithTheEntitlementIsSubscribed() {
        XCTAssertEqual(PurchaseOutcome.decide(result: .verified, isSubscribed: true), .subscribed)
    }

    // MARK: - Ce que StoreKit affirme, et ce dont il doute

    /// Une annulation reste une annulation, même chez quelqu'un qui EST abonné par ailleurs.
    ///
    /// La règle « le droit d'abord » de `RestoreOutcome` et `OfferCodeOutcome` ne s'applique pas
    /// ici : là-bas on CHERCHE un droit, et le trouver clôt la question. Ici StoreKit parle d'un
    /// achat précis, et il est formel. Confondre les deux ferait compter une annulation comme une
    /// vente — c'est-à-dire fausserait la seule mesure qui dise si le prix est le problème.
    func testACancellationStaysACancellationForASubscriber() {
        XCTAssertEqual(PurchaseOutcome.decide(result: .cancelled, isSubscribed: true), .cancelled)
        XCTAssertEqual(PurchaseOutcome.decide(result: .cancelled, isSubscribed: false), .cancelled)
        XCTAssertEqual(PurchaseOutcome.decide(result: .cancelled, isSubscribed: nil), .cancelled)
    }

    /// « Demander à acheter » de même : l'approbation d'un parent viendra plus tard, ou jamais.
    func testPendingStaysPending() {
        for droit: Bool? in [true, false, nil] {
            XCTAssertEqual(PurchaseOutcome.decide(result: .pending, isSubscribed: droit), .pending)
        }
    }

    /// Les trois cas ambigus, sans droit : un échec, et c'est honnête.
    func testTheAmbiguousResultsWithoutAnEntitlementAreFailures() {
        for resultat: PurchaseOutcome.StoreKitResult in [.unverified, .unknown, .threw] {
            XCTAssertEqual(PurchaseOutcome.decide(result: resultat, isSubscribed: false), .failed)
            XCTAssertEqual(PurchaseOutcome.decide(result: resultat, isSubscribed: nil), .failed)
        }
    }

    /// Les mêmes, AVEC le droit : ne jamais annoncer un échec à qui a l'abonnement.
    ///
    /// Le droit est digne de foi même dans ces cas-là : `refreshEntitlement()` ne compte que des
    /// transactions `.verified`, portant un de nos identifiants de produit, ni révoquées ni
    /// expirées. Une signature non validée pendant l'achat ne retire rien à celle-là.
    func testTheEntitlementWinsOverAnAmbiguousResult() {
        for resultat: PurchaseOutcome.StoreKitResult in [.unverified, .unknown, .threw] {
            XCTAssertEqual(PurchaseOutcome.decide(result: resultat, isSubscribed: true), .subscribed)
        }
    }

    // MARK: - Ce que l'écran en fait

    /// `nil` veut dire « ne rien annoncer », et une seule issue y a droit.
    ///
    /// Un écran d'achat qui se referme sans un mot laisse croire qu'il n'a rien fait, et fait
    /// retaper — ce qui, sur cet écran-là, veut dire tenter un second paiement.
    func testOnlyACancellationStaysSilent() {
        XCTAssertNil(PurchaseOutcome.cancelled.message)
        for issue: PurchaseOutcome in [.subscribed, .purchasedAwaitingUnlock, .pending, .failed] {
            XCTAssertNotNil(issue.message, "\(issue) ne dit rien à l'écran.")
            XCTAssertFalse(issue.message?.isEmpty ?? true)
        }
    }

    /// Quatre issues qui parlent, quatre phrases distinctes.
    ///
    /// Le test ne cherche AUCUN mot : chercher « abouti » ou « bienvenue » reviendrait à tester
    /// le catalogue de traduction en croyant tester une règle, et ça casse à la première langue
    /// ajoutée — `String(localized:)` traduit. Ce qui compte est structurel : deux issues qui
    /// disent la même chose sont deux issues qu'on aurait pu ne pas séparer, et c'est justement
    /// leur séparation qui corrige le défaut d'origine.
    func testTheOutcomesThatSpeakDoNotSayTheSameThing() {
        let phrases = Set([PurchaseOutcome.subscribed, .purchasedAwaitingUnlock, .pending, .failed]
            .compactMap(\.message))
        XCTAssertEqual(phrases.count, 4,
                       "Deux issues distinctes affichent le même message : la nuance se perd à l'écran.")
    }

    /// L'écran se referme dès qu'Apple a encaissé, et seulement dans ce cas.
    ///
    /// Laisser le paywall ouvert après un paiement, c'est laisser un bouton d'achat actif devant
    /// quelqu'un qui vient de payer. Le refermer après un échec serait l'inverse : on retire
    /// l'écran à quelqu'un qui doit pouvoir réessayer.
    func testThePaywallClosesExactlyWhenApplePaid() {
        XCTAssertTrue(PurchaseOutcome.subscribed.ferme)
        XCTAssertTrue(PurchaseOutcome.purchasedAwaitingUnlock.ferme)
        XCTAssertFalse(PurchaseOutcome.failed.ferme)
        XCTAssertFalse(PurchaseOutcome.pending.ferme)
        XCTAssertFalse(PurchaseOutcome.cancelled.ferme)
    }
}
