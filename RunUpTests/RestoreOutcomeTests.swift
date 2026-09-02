import XCTest
@testable import RunUp

/// Verrouille ce qu'on répond à « Restaurer mes achats ».
///
/// Le cas qui a motivé ces tests n'est pas théorique : la synchronisation avec l'App Store échoue
/// quand le réseau manque, et aussi quand on referme la demande de mot de passe Apple. L'échec
/// était avalé, puis l'app regardait s'il existait un abonnement — et n'en trouvant pas, elle
/// annonçait « Aucun abonnement actif trouvé ».
///
/// Ce message est faux, il s'adresse à quelqu'un qui paye, et il tombe pendant qu'il essaie de
/// récupérer ce qu'il a payé — typiquement sur un téléphone neuf, donc sur un réseau qu'on ne
/// maîtrise pas. Toute la valeur de cette règle tient dans un écart : « je n'ai pas pu regarder »
/// n'est pas « j'ai regardé, il n'y a rien ».
final class RestoreOutcomeTests: XCTestCase {

    func testAnActiveSubscriptionIsRestored() {
        XCTAssertEqual(RestoreOutcome.decide(syncFailed: false, isSubscribed: true), .restored)
    }

    /// Même si la synchronisation a échoué : elle sert à aller CHERCHER un droit qu'on a déjà
    /// trouvé. Échouer à chercher ce qu'on tient déjà ne change rien.
    func testAnActiveSubscriptionWinsOverAFailedSync() {
        XCTAssertEqual(RestoreOutcome.decide(syncFailed: true, isSubscribed: true), .restored)
    }

    /// Le vrai « il n'y a rien » : on a pu vérifier, et le compte Apple ne porte pas d'abonnement.
    func testAVerifiedEmptyAccountSaysSo() {
        XCTAssertEqual(RestoreOutcome.decide(syncFailed: false, isSubscribed: false), .nothingFound)
    }

    /// Le bug d'origine. Sans réseau, la réponse ne doit surtout pas être « tu n'as rien ».
    func testAFailedSyncNeverClaimsThereIsNothing() {
        XCTAssertEqual(RestoreOutcome.decide(syncFailed: true, isSubscribed: false), .couldNotCheck)
        XCTAssertEqual(RestoreOutcome.decide(syncFailed: true, isSubscribed: nil), .couldNotCheck)
    }

    /// `nil` est un troisième état, pas un `false` déguisé : la vérification n'a pas abouti, même
    /// si la synchronisation, elle, s'est bien passée.
    func testAnUnknownStateIsNotAnEmptyAccount() {
        XCTAssertEqual(RestoreOutcome.decide(syncFailed: false, isSubscribed: nil), .couldNotCheck)
    }

    /// Chaque issue doit avoir quelque chose à dire — un bouton qui ne répond rien fait retaper.
    func testEveryOutcomeSpeaks() {
        for outcome: RestoreOutcome in [.restored, .nothingFound, .couldNotCheck] {
            XCTAssertFalse(outcome.message.isEmpty)
        }
    }

    /// Trois états, trois messages différents.
    ///
    /// La première version de ce test cherchait le mot « Aucun » dans le message rendu. Elle
    /// échouait dès que le simulateur tournait en anglais : `String(localized:)` traduit, et
    /// « No active subscription » ne contient évidemment pas « Aucun ». Le défaut était dans le
    /// test, pas dans le code — chercher des MOTS revient à tester le catalogue de traduction en
    /// croyant tester une règle, et ça casse à la première langue ajoutée.
    ///
    /// Ce qui compte vraiment est structurel et ne dépend d'aucune langue : deux états qui
    /// disent la même chose sont deux états qu'on aurait pu ne pas séparer, et c'est justement
    /// leur séparation qui corrige le bug d'origine. L'interdiction d'annoncer une absence non
    /// constatée, elle, est vérifiée au niveau de la DÉCISION par
    /// `testAFailedSyncNeverClaimsThereIsNothing` — au bon endroit, avant toute traduction.
    func testTheThreeOutcomesDoNotSayTheSameThing() {
        let messages = Set([RestoreOutcome.restored, .nothingFound, .couldNotCheck].map(\.message))
        XCTAssertEqual(messages.count, 3,
                       "Deux issues distinctes affichent le même message : la nuance se perd à l'écran.")
    }
}
