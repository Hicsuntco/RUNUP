import XCTest
@testable import RunUp

/// Verrouille la frontière entre le gratuit et le payant.
///
/// Deux erreurs sont possibles ici et elles n'ont pas le même coût. Verrouiller à tort ferme
/// l'app à quelqu'un qui a payé — c'est une demande de remboursement et un avis à une étoile.
/// Déverrouiller à tort donne l'app gratuitement. La règle penche délibérément du second côté à
/// chaque fois qu'elle ne sait pas, et ces tests sont là pour que ce penchant reste un choix et
/// ne devienne pas un accident.
final class EntitlementTests: XCTestCase {

    // MARK: - L'abonnée

    func testSubscriberUnlocksEverything() {
        for feature in PlusFeature.allCases {
            XCTAssertTrue(Entitlement.unlocks(feature, isSubscribed: true, canSell: true),
                          "\(feature.rawValue) doit être ouvert à une abonnée.")
        }
    }

    /// Et même si la boutique est tombée : son abonnement ne dépend pas de la disponibilité des
    /// produits à vendre.
    func testSubscriberUnlocksEvenWhenTheStoreIsDown() {
        for feature in PlusFeature.allCases {
            XCTAssertTrue(Entitlement.unlocks(feature, isSubscribed: true, canSell: false))
        }
    }

    // MARK: - La non-abonnée

    func testNonSubscriberIsLockedOutOfPlusFeatures() {
        for feature in PlusFeature.allCases {
            XCTAssertFalse(Entitlement.unlocks(feature, isSubscribed: false, canSell: true),
                           "\(feature.rawValue) ne doit pas être ouvert sans abonnement.")
        }
    }

    // MARK: - Les deux cas où l'on ouvre par défaut

    /// La vérification StoreKit n'a pas encore répondu. Verrouiller ferait clignoter un verrou
    /// devant une abonnée à chaque lancement.
    func testUnknownSubscriptionStateUnlocks() {
        for feature in PlusFeature.allCases {
            XCTAssertTrue(Entitlement.unlocks(feature, isSubscribed: nil, canSell: true),
                          "Tant qu'on ne sait pas, on laisse passer.")
        }
    }

    /// Rien à vendre — réseau coupé, panne StoreKit, produit pas encore approuvé. Un écran qui ne
    /// peut rien encaisser n'a pas le droit de bloquer.
    func testNothingToSellUnlocksEvenForANonSubscriber() {
        for feature in PlusFeature.allCases {
            XCTAssertTrue(Entitlement.unlocks(feature, isSubscribed: false, canSell: false),
                          "Sans produit vendable, le verrou n'aurait aucune sortie.")
        }
    }

    func testNothingToSellAndUnknownStateUnlocks() {
        XCTAssertTrue(Entitlement.unlocks(.coach, isSubscribed: nil, canSell: false))
    }

    // MARK: - Ce que la frontière contient

    /// Le cœur de la décision : ce qui se vend, ce sont le programme et le coach. Si quelqu'un
    /// ajoute un jour le suivi GPS, le Club ou l'historique à cette liste, il rouvre exactement le
    /// problème d'amorçage que ce découpage existe pour résoudre — et ce test le dira.
    func testPlusSellsCoachingNotTracking() {
        XCTAssertEqual(Set(PlusFeature.allCases.map(\.rawValue)),
                       ["adaptivePlan", "coach", "voiceCoach", "raceGoal",
                        "predictions", "trainingLoad"],
                       """
                       La frontière a bougé. Le suivi, l'historique, les anneaux du jour, le \
                       bilan de la semaine, le Club, les amis, les classements et les itinéraires \
                       sont gratuits POUR TOUJOURS : ce sont eux qui peuplent l'app et qui la \
                       font rouvrir, et une app vide ne se vend pas.
                       """)
    }

    /// Chaque verrou doit pouvoir se présenter. Un verrou sans texte est un cul-de-sac.
    func testEveryFeatureCanExplainItself() {
        for feature in PlusFeature.allCases {
            XCTAssertFalse(feature.title.isEmpty, "\(feature.rawValue) n'a pas de titre.")
            XCTAssertFalse(feature.pitch.isEmpty, "\(feature.rawValue) n'a pas d'argument.")
        }
    }
}
