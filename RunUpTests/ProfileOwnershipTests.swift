import XCTest
@testable import RunUp

/// Verrouille la règle « à qui appartiennent les données de cet appareil ».
///
/// Elle arbitre entre deux fautes opposées et graves. Effacer trop vite détruit l'entraînement de
/// quelqu'un qui s'est trompé de compte ; ne jamais effacer montre le nom, la photo et le programme
/// d'une personne à une autre sur un téléphone qui change de mains. Les trois cas ci-dessous sont
/// la frontière entre les deux, et rien dans le code appelant ne doit pouvoir la déplacer sans
/// casser un test.
final class ProfileOwnershipTests: XCTestCase {

    /// Le cas le plus fréquent, et la promesse de l'app : on s'entraîne d'abord, on crée un compte
    /// ensuite. Rien ne doit être perdu à ce moment-là.
    func testProfileWithNoOwnerIsAdopted() {
        XCTAssertEqual(ProfileOwnership.decide(currentOwner: nil, signingIn: "user-1"), .adopt)
    }

    /// Les profils créés avant l'existence du champ n'ont pas de propriétaire écrit. Les adopter
    /// silencieusement est correct : la personne devant l'écran est celle qui a toujours utilisé
    /// ce téléphone. Les traiter comme un conflit poserait la question de l'effacement à toute la
    /// base installée, au premier lancement suivant la mise à jour.
    func testEmptyOwnerIsTreatedAsNoOwner() {
        XCTAssertEqual(ProfileOwnership.decide(currentOwner: "", signingIn: "user-1"), .adopt)
    }

    func testSameAccountIsAlreadyOwned() {
        XCTAssertEqual(ProfileOwnership.decide(currentOwner: "user-1", signingIn: "user-1"), .alreadyOwned)
    }

    /// Le cas qu'on répare : un autre compte se connecte, et il faut demander.
    func testDifferentAccountIsAConflict() {
        XCTAssertEqual(ProfileOwnership.decide(currentOwner: "user-1", signingIn: "user-2"), .conflict)
    }

    /// La comparaison est exacte, sans normalisation.
    ///
    /// Les identifiants viennent du serveur et ne sont pas saisis à la main : les rapprocher à la
    /// casse près ou en ignorant les espaces n'ajouterait aucune tolérance utile, et ferait passer
    /// pour identiques deux comptes qui ne le sont pas — soit exactement la fuite à éviter.
    func testComparisonIsExact() {
        XCTAssertEqual(ProfileOwnership.decide(currentOwner: "User-1", signingIn: "user-1"), .conflict)
        XCTAssertEqual(ProfileOwnership.decide(currentOwner: "user-1 ", signingIn: "user-1"), .conflict)
    }
}
