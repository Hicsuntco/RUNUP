import XCTest
@testable import RunUp

/// Les comptes de la maison, côté app.
///
/// # CE QUE CES TESTS GARDENT
///
/// Que le droit vienne du SERVEUR et de nulle part ailleurs. Hukaia a fait l'inverse, et l'a
/// écrit dans son propre code : l'exemption s'y lisait dans `localStorage`, et une ligne dans la
/// console suffisait à tout déverrouiller, à vie. Ici l'app ne sait pas fabriquer ce booléen —
/// elle le reçoit, et le seul risque est qu'elle cesse de l'écouter.
final class AdminTests: XCTestCase {

    /// Un compte de la maison ouvre tout, même sans abonnement et même quand la vente marche.
    func testUnCompteDeLaMaisonOuvreTout() {
        for feature in PlusFeature.allCases {
            XCTAssertTrue(
                Entitlement.unlocks(feature, isSubscribed: false, canSell: true, estAdmin: true),
                "\(feature) reste verrouillée pour un compte de la maison")
        }
    }

    /// Et sans ce drapeau, rien ne change : un non-abonné face à une vente qui marche reste
    /// dehors. C'est ce qui rend l'ajout sûr — il n'ouvre que ce qu'on lui demande d'ouvrir.
    func testSansLeDrapeauLaRegleEstInchangee() {
        for feature in PlusFeature.allCases {
            XCTAssertFalse(
                Entitlement.unlocks(feature, isSubscribed: false, canSell: true, estAdmin: false),
                "\(feature) s'est ouverte toute seule")
            // Les deux règles qui existaient avant tiennent toujours.
            XCTAssertTrue(Entitlement.unlocks(feature, isSubscribed: true, canSell: true))
            XCTAssertTrue(Entitlement.unlocks(feature, isSubscribed: false, canSell: false))
        }
    }

    /// LE DÉFAUT EST « PAS ADMIN », ET IL L'EST PAR CONSTRUCTION.
    ///
    /// `estAdmin` a une valeur par défaut à `false`, donc les appelants qui ne la passent pas —
    /// c'est-à-dire tous ceux qui existaient avant — gardent exactement leur comportement. Un
    /// droit dont le défaut serait « ouvert » s'accorderait tout seul le jour où quelqu'un
    /// oublie un argument.
    func testLeDefautEstPasAdmin() {
        XCTAssertFalse(Entitlement.unlocks(.raceGoal, isSubscribed: false, canSell: true))
    }

    /// UN SERVEUR QUI NE CONNAÎT PAS CES CHAMPS NE DÉCONNECTE PERSONNE.
    ///
    /// La fenêtre entre le déploiement de l'app et celui du serveur n'est jamais nulle. Un
    /// `decode` strict sur `isAdmin` ferait échouer le décodage de TOUT le compte pendant cette
    /// fenêtre — donc déconnecterait tout le monde, pour un champ dont personne n'a besoin.
    func testUnCompteSansLesChampsAdminSeDecodeQuandMeme() throws {
        let ancien = """
        {"id":"u1","name":"Charlotte","xpTotal":4180,"referralCode":"ABC123"}
        """
        let compte = try JSONDecoder().decode(AuthenticatedUser.self, from: Data(ancien.utf8))
        XCTAssertEqual(compte.id, "u1")
        XCTAssertFalse(compte.isAdmin, "un champ absent a été lu comme vrai")
        XCTAssertFalse(compte.adminListConfigured)
        XCTAssertNil(compte.email)
    }

    /// Et quand le serveur les envoie, ils sont lus.
    func testLesChampsAdminSontLusQuandIlsArrivent() throws {
        let neuf = """
        {"id":"u1","name":"Charlotte","xpTotal":4180,"email":"a@b.com",
         "isAdmin":true,"adminListConfigured":true}
        """
        let compte = try JSONDecoder().decode(AuthenticatedUser.self, from: Data(neuf.utf8))
        XCTAssertTrue(compte.isAdmin)
        XCTAssertTrue(compte.adminListConfigured)
        XCTAssertEqual(compte.email, "a@b.com")
    }

    /// « Pas dans la liste » et « pas de liste » sont DEUX états, et la fiche les distingue.
    ///
    /// Les deux donnent `isAdmin == false` et se ressemblent à l'écran. L'un se corrige en
    /// ajoutant une adresse, l'autre en créant la variable — et sans la distinction on essaie le
    /// premier pendant une heure.
    func testLesDeuxPannesQuiSeRessemblentSontDistinguables() throws {
        let sansListe = """
        {"id":"u1","name":"C","xpTotal":0,"isAdmin":false,"adminListConfigured":false}
        """
        let pasDedans = """
        {"id":"u1","name":"C","xpTotal":0,"isAdmin":false,"adminListConfigured":true}
        """
        let a = try JSONDecoder().decode(AuthenticatedUser.self, from: Data(sansListe.utf8))
        let b = try JSONDecoder().decode(AuthenticatedUser.self, from: Data(pasDedans.utf8))
        XCTAssertEqual(a.isAdmin, b.isAdmin)
        XCTAssertNotEqual(a.adminListConfigured, b.adminListConfigured)
    }
}
