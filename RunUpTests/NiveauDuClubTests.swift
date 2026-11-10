import XCTest
@testable import RunUp

/// Verrouille le palier de niveau du Club.
///
/// Ce calcul vivait dans `ClubView`, propriété privée au milieu de 1 425 lignes : il n'était
/// vérifiable qu'en ouvrant l'écran avec un compte au bon nombre de points, c'est-à-dire jamais.
/// Il porte pourtant trois décisions — le palier de 250, les sept titres, et ce qui arrive quand
/// on dépasse le dernier — dont la dernière n'était écrite nulle part.
final class NiveauDuClubTests: XCTestCase {

    // MARK: - Les bords du palier

    /// Zéro point n'est pas le niveau zéro : il n'y en a pas.
    func testOnCommenceAuNiveauUn() {
        let p = NiveauDuClub.palier(xp: 0)
        XCTAssertEqual(p.niveau, 1)
        XCTAssertEqual(p.xpDansLeNiveau, 0)
        XCTAssertEqual(p.titre, NiveauDuClub.titres[0])
    }

    /// Le dernier point AVANT le palier, et le premier APRÈS. C'est l'endroit où un `>=` mal
    /// placé décale tout le monde d'un niveau sans que rien ne plante.
    func testLePalierBasculeAuBonPoint() {
        let avant = NiveauDuClub.palier(xp: NiveauDuClub.xpParNiveau - 1)
        XCTAssertEqual(avant.niveau, 1)
        XCTAssertEqual(avant.xpDansLeNiveau, NiveauDuClub.xpParNiveau - 1)

        let apres = NiveauDuClub.palier(xp: NiveauDuClub.xpParNiveau)
        XCTAssertEqual(apres.niveau, 2)
        XCTAssertEqual(apres.xpDansLeNiveau, 0)
    }

    /// Le palier annoncé est le même pour tout le monde : la jauge se dessine en divisant par
    /// lui, et une valeur qui varierait ferait des jauges incomparables d'un écran à l'autre.
    func testLePalierAnnonceEstToujoursLeMeme() {
        for xp in [0, 1, 249, 250, 999, 100_000] {
            XCTAssertEqual(NiveauDuClub.palier(xp: xp).xpParNiveau, NiveauDuClub.xpParNiveau,
                           "xp \(xp)")
        }
    }

    /// Les points dans le niveau restent toujours affichables dans une jauge : entre zéro inclus
    /// et le palier exclu. Hors de là, `LinearBar` recevrait une fraction supérieure à un.
    func testLesPointsDansLeNiveauRestentDansLaJauge() {
        for xp in stride(from: 0, through: 3000, by: 7) {
            let p = NiveauDuClub.palier(xp: xp)
            XCTAssertTrue((0..<NiveauDuClub.xpParNiveau).contains(p.xpDansLeNiveau), "xp \(xp)")
        }
    }

    // MARK: - Les titres

    /// Chaque palier des sept premiers niveaux a son propre titre, dans l'ordre.
    func testLesSeptPremiersNiveauxOntChacunLeurTitre() {
        for (index, titre) in NiveauDuClub.titres.enumerated() {
            let xp = index * NiveauDuClub.xpParNiveau
            let p = NiveauDuClub.palier(xp: xp)
            XCTAssertEqual(p.niveau, index + 1, "xp \(xp)")
            XCTAssertEqual(p.titre, titre, "niveau \(index + 1)")
        }
    }

    /// AU-DELÀ DU DERNIER TITRE, ON NE S'ARRÊTE PAS DE MONTER.
    ///
    /// Les titres s'épuisent à sept, les niveaux non. Le comportement existait — un
    /// `min(max(…))` dans la vue — mais n'était écrit nulle part, et c'est exactement le bord
    /// qu'un remaniement transforme en plantage d'index ou en « Premiers pas » retrouvé au
    /// niveau 12.
    func testPasseLeDernierTitreLeNiveauContinueDeMonter() {
        let dernier = NiveauDuClub.titres.count
        for niveau in [dernier, dernier + 1, dernier + 5, 40] {
            let p = NiveauDuClub.palier(xp: (niveau - 1) * NiveauDuClub.xpParNiveau)
            XCTAssertEqual(p.niveau, niveau)
            XCTAssertEqual(p.titre, NiveauDuClub.titres.last, "niveau \(niveau)")
        }
    }

    func testIlYASeptTitresEtAucunNEstVide() {
        XCTAssertEqual(NiveauDuClub.titres.count, 7)
        for titre in NiveauDuClub.titres {
            XCTAssertFalse(titre.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        XCTAssertEqual(Set(NiveauDuClub.titres).count, 7, "deux titres identiques")
    }

    // MARK: - Ce qui ne devrait pas arriver

    /// UN XP NÉGATIF N'EXISTE PAS CÔTÉ SERVEUR, et il arriverait ici sans rien casser si une
    /// colonne devenait nulle ou signée. Il rend le niveau 1 : il n'y a pas de niveau 0, et une
    /// jauge négative ne se dessine pas.
    func testUnXpNegatifNeDescendPasSousLePremierNiveau() {
        for xp in [-1, -250, -100_000] {
            let p = NiveauDuClub.palier(xp: xp)
            XCTAssertEqual(p.niveau, 1, "xp \(xp)")
            XCTAssertEqual(p.xpDansLeNiveau, 0, "xp \(xp)")
        }
    }

    /// Le niveau ne recule jamais quand l'XP monte.
    func testLeNiveauEstCroissant() {
        var precedent = 0
        for xp in stride(from: 0, through: 5000, by: 13) {
            let niveau = NiveauDuClub.palier(xp: xp).niveau
            XCTAssertGreaterThanOrEqual(niveau, precedent, "xp \(xp)")
            precedent = niveau
        }
    }
}
