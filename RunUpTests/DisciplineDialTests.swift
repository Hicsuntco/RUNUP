import XCTest
import CoreGraphics
@testable import RunUp

/// La géométrie du cadran de disciplines : un déplacement de doigt entre, une discipline sort.
///
/// C'est la seule partie du cadran qu'on peut prouver sans appareil — et c'est celle qui décide.
/// Le dessin, lui, ne se juge qu'à l'œil sur un vrai téléphone.
final class DisciplineDialTests: XCTestCase {

    /// Un déplacement de doigt dans une direction donnée, en degrés (zéro à droite, quatre-vingt-dix
    /// en haut), et à une distance donnée du bouton.
    private func doigt(_ degres: Double, a distance: CGFloat = 90) -> CGSize {
        let radians = degres * .pi / 180
        // L'ordonnée est NÉGATIVE vers le haut, comme celle que SwiftUI rapporte.
        return CGSize(width: distance * cos(radians), height: -distance * sin(radians))
    }

    // MARK: - Les trois directions

    func testVersLeHautCEstLeVelo() {
        XCTAssertEqual(DisciplineDial.option(pour: doigt(90)), .bike)
    }

    func testVersLaGaucheCEstLaCourse() {
        XCTAssertEqual(DisciplineDial.option(pour: doigt(145)), .run)
        XCTAssertEqual(DisciplineDial.option(pour: doigt(180)), .run,
                       "plein gauche reste la course : il n'y a rien au-delà")
    }

    func testVersLaDroiteCEstLeTrail() {
        XCTAssertEqual(DisciplineDial.option(pour: doigt(35)), .trail)
        XCTAssertEqual(DisciplineDial.option(pour: doigt(0)), .trail,
                       "plein droite reste le trail")
    }

    /// AUCUN TROU. Toute direction du demi-cercle supérieur vise quelque chose : une direction où
    /// le doigt part franchement et où il ne se passe rien est la pire réponse possible à un geste
    /// franc, et c'est ce qu'une tolérance angulaire aurait produit.
    func testToutLeDemiCercleSuperieurViseQuelqueChose() {
        for degres in stride(from: 0.0, through: 180.0, by: 1.0) {
            XCTAssertNotNil(DisciplineDial.option(pour: doigt(degres)),
                            "\(degres)° ne vise rien")
        }
    }

    /// Et les trois sont atteignables : un cadran dont un rond ne serait jamais choisi serait un
    /// cadran à deux ronds avec un décor.
    func testLesTroisDisciplinesSontAtteignables() {
        var vues = Set<Discipline>()
        for degres in stride(from: 0.0, through: 180.0, by: 1.0) {
            if let option = DisciplineDial.option(pour: doigt(degres)) { vues.insert(option) }
        }
        XCTAssertEqual(vues, Set(Discipline.allCases))
    }

    // MARK: - Les trois façons de ne rien choisir

    func testUnDoigtQuiNaPasBougeNeChoisitRien() {
        XCTAssertNil(DisciplineDial.option(pour: .zero))
        XCTAssertNil(DisciplineDial.option(pour: doigt(90, a: DisciplineDial.zoneMorte - 1)))
    }

    func testJusteAuDeLaDeLaZoneMorteOnChoisitDeja() {
        XCTAssertNotNil(DisciplineDial.option(pour: doigt(90, a: DisciplineDial.zoneMorte + 1)))
    }

    /// Tirer vers le bas annule. Le cadran s'ouvre vers le haut, donc c'est le mouvement opposé
    /// au choix — il n'a pas besoin d'être expliqué pour être compris.
    func testVersLeBasOnAnnule() {
        XCTAssertNil(DisciplineDial.option(pour: doigt(-90)))
        for degres in stride(from: -179.0, through: -1.0, by: 1.0) {
            XCTAssertNil(DisciplineDial.option(pour: doigt(degres)), "\(degres)° devrait annuler")
        }
    }

    func testTropLoinOnNeVisePlusRien() {
        XCTAssertNil(DisciplineDial.option(pour: doigt(90, a: DisciplineDial.porteeMaximale + 1)))
        XCTAssertNotNil(DisciplineDial.option(pour: doigt(90, a: DisciplineDial.porteeMaximale - 1)))
    }

    // MARK: - Où les ronds sont dessinés

    /// Le dessin et le geste doivent parler du même cadran : un rond posé à un endroit et visé à
    /// un autre serait un cadran qui ment. On vérifie donc que la direction de chaque rond est
    /// bien celle qui le choisit.
    func testChaqueRondEstViseParSaPropreDirection() {
        for discipline in Discipline.allCases {
            let centre = DisciplineDial.position(discipline)
            let versLeRond = CGSize(width: centre.x, height: centre.y)
            XCTAssertEqual(DisciplineDial.option(pour: versLeRond), discipline,
                           "glisser vers le rond \(discipline) doit choisir \(discipline)")
        }
    }

    func testLesRondsSontSurLArcEtAuDessusDuBouton() {
        for discipline in Discipline.allCases {
            let p = DisciplineDial.position(discipline)
            XCTAssertEqual(hypot(p.x, p.y), DisciplineDial.rayon, accuracy: 0.001)
            XCTAssertLessThan(p.y, 0, "\(discipline) doit être AU-DESSUS du bouton")
        }
    }

    /// Course à gauche, vélo au centre, trail à droite — l'ordre de lecture, et celui de
    /// `Discipline.allCases`. Fixe, donc le geste s'apprend et finit par se faire sans regarder.
    func testLOrdreDesRondsEstCeluiDeLaLecture() {
        let course = DisciplineDial.position(.run)
        let velo = DisciplineDial.position(.bike)
        let trail = DisciplineDial.position(.trail)
        XCTAssertLessThan(course.x, velo.x)
        XCTAssertLessThan(velo.x, trail.x)
        XCTAssertEqual(velo.x, 0, accuracy: 0.001, "le vélo est droit au-dessus du bouton")
    }
}
