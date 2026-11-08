import XCTest
@testable import RunUp

/// La fausse conversation du coach tombe-t-elle toujours AUJOURD'HUI ?
///
/// # CE QUE CE FICHIER PROTÈGE
///
/// `3-coach` est une des six captures livrées à Apple. Le message du coach y est planté cinq
/// heures en arrière — assez pour qu'il ait l'air d'une vraie conversation du matin. Sans borne,
/// une chaîne qui tourne à 03 h 00 le pose à 22 h 00 la VEILLE, et la capture affiche un
/// séparateur « HIER » au-dessus de la conversation. L'image livrée ne dit alors plus ce qu'on
/// veut qu'elle dise : un coach qui a répondu ce matin.
///
/// Le défaut est passé une fois. Deux exécutions comparées, à 01 h 18 et 04 h 37, s'accordaient ;
/// une troisième à 07 h 00 ne s'accordait plus. « Deux exécutions qui s'accordent ne font pas une
/// reproductibilité » — l'en-tête de `ci_scripts/comparer.py`.
///
/// # POURQUOI CE N'EST PAS LA CHAÎNE QUI LE VÉRIFIE
///
/// Parce qu'elle ne le peut pas. Le cas qui casse n'existe qu'entre minuit et 05 h 00, et une
/// exécution d'intégration continue tombe à l'heure où quelqu'un pousse. Attendre qu'elle tombe
/// la nuit pour savoir si la borne tient, c'est confier la vérification au hasard. Ici, les
/// vingt-quatre heures sont éprouvées en une seconde.
final class CaptureSeedHeureTests: XCTestCase {

    private let calendrier = Calendar.current

    private func a(_ heure: Int, _ minute: Int = 0) -> Date {
        // Une date FIXE : un test ancré sur l'heure courante finirait par ne plus éprouver le
        // cas qu'il vise, et par échouer tout seul un jour de changement d'heure.
        var morceaux = DateComponents()
        morceaux.year = 2026; morceaux.month = 11; morceaux.day = 8
        morceaux.hour = heure; morceaux.minute = minute
        return calendrier.date(from: morceaux)!
    }

    /// LE CAS QUI JUSTIFIE TOUT CE FICHIER.
    func testAvantCinqHeuresLaPoseResteAujourdHui() {
        for heure in 0..<5 {
            let maintenant = a(heure, 30)
            let pose = CaptureSeed.poseDeLaConversation(maintenant)
            XCTAssertEqual(calendrier.startOfDay(for: pose),
                           calendrier.startOfDay(for: maintenant),
                           "à \(heure) h 30, le message tombe un autre jour")
            XCTAssertLessThanOrEqual(pose, maintenant, "le message est dans le futur")
        }
    }

    /// Et à toute heure, pas seulement sur les cinq qui cassent.
    func testLesVingtQuatreHeuresTombentAujourdHui() {
        for heure in 0..<24 {
            let maintenant = a(heure, 17)
            let pose = CaptureSeed.poseDeLaConversation(maintenant)
            XCTAssertEqual(calendrier.startOfDay(for: pose),
                           calendrier.startOfDay(for: maintenant),
                           "à \(heure) h 17, le message tombe un autre jour")
        }
    }

    /// Passé 05 h 00, la borne ne doit RIEN faire : le message garde ses cinq heures d'écart,
    /// qui sont ce qui le fait ressembler à une vraie conversation plutôt qu'à l'instant présent.
    func testApresCinqHeuresLeReculDeCinqHeuresEstIntact() {
        for heure in 5..<24 {
            let maintenant = a(heure, 30)
            let pose = CaptureSeed.poseDeLaConversation(maintenant)
            XCTAssertEqual(pose.timeIntervalSince(maintenant), -3600.0 * 5, accuracy: 1.0,
                           "à \(heure) h 30, le recul de cinq heures a été raboté")
        }
    }

    /// À minuit pile, la pose EST minuit — pas une seconde avant.
    func testAMinuitLaPoseEstLeDebutDuJour() {
        let minuit = a(0, 0)
        XCTAssertEqual(CaptureSeed.poseDeLaConversation(minuit), calendrier.startOfDay(for: minuit))
    }

    /// Le message du coach arrive APRÈS la question : la réponse est posée 40 secondes plus tard
    /// (voir `conversation`), et une borne qui écraserait la pose sans toucher à ce décalage
    /// inverserait la conversation. Ici on vérifie seulement que la pose laisse la place.
    func testLaPoseLaisseLaPlaceALaReponse() {
        for heure in 0..<24 {
            let maintenant = a(heure, 0)
            let pose = CaptureSeed.poseDeLaConversation(maintenant)
            XCTAssertEqual(calendrier.startOfDay(for: pose.addingTimeInterval(40)),
                           calendrier.startOfDay(for: maintenant),
                           "à \(heure) h, la réponse du coach tombe un autre jour que la question")
        }
    }
}
