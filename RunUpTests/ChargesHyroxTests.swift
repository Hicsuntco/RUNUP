import XCTest
@testable import RunUp

/// Les charges du règlement HYROX, épinglées.
///
/// # UN TEST QUI RECOPIE UN TABLEAU, ET POURQUOI IL EN VAUT LA PEINE
///
/// Ces cas ne déduisent rien : ils redisent le tableau de la section 4.1 du règlement Single de la
/// saison 26/27, transcrit depuis le PDF officiel. C'est exactement leur intérêt. Ce sont des
/// charges qu'une coureuse va pousser, tirer et soulever cent fois, et une faute de frappe dans
/// l'énumération — 120 au lieu de 102, 2 × 16 devenu 16 — ne casserait rien, ne se verrait pas à
/// l'écran, et ferait préparer la mauvaise épreuve.
///
/// Les nombres sont donc écrits deux fois, à deux endroits qu'on ne modifie pas d'un même geste.
/// Le jour où le règlement change, il faudra changer les deux — et c'est voulu : ça force à
/// rouvrir la source plutôt qu'à corriger un test qui gêne.
///
/// Source : HYROX Single Rulebook, saison 26/27, section 4.1 « HYROX DIVISIONS ».
final class ChargesHyroxTests: XCTestCase {

    func testLesChargesFemmesSontCellesDuReglement() throws {
        let c = try XCTUnwrap(HyroxDivision.femmes.charges)
        XCTAssertEqual(c.sledPushKg, 102)
        XCTAssertEqual(c.sledPullKg, 78)
        XCTAssertEqual(c.kettlebellKg, 16)
        XCTAssertEqual(c.sandbagKg, 10)
        XCTAssertEqual(c.wallBallKg, 4)
        XCTAssertEqual(c.wallBallCibleM, 2.70)
    }

    func testLesChargesHommesProSontCellesDuReglement() throws {
        let c = try XCTUnwrap(HyroxDivision.hommesPro.charges)
        XCTAssertEqual(c.sledPushKg, 202)
        XCTAssertEqual(c.sledPullKg, 153)
        XCTAssertEqual(c.kettlebellKg, 32)
        XCTAssertEqual(c.sandbagKg, 30)
        XCTAssertEqual(c.wallBallKg, 9)
        XCTAssertEqual(c.wallBallCibleM, 3.00)
    }

    /// HOMMES ET FEMMES PRO PARTAGENT LA COLONNE DES POIDS, ET PAS LA HAUTEUR DE CIBLE.
    ///
    /// Les deux découpages du règlement ne se superposent pas, et ils sont à deux pages d'écart.
    /// Les poids groupent « WOMEN PRO / MEN » ; la hauteur groupe « WOMEN / WOMEN PRO » à 2,70 m
    /// et « MEN / MEN PRO » à 3,00 m. Déduire l'un de l'autre — ce que la première version de ce
    /// fichier faisait — faisait s'entraîner trente centimètres trop bas, cent fois de suite.
    func testHommesEtFemmesProPartagentLesPoidsMaisPasLaCible() throws {
        let hommes = try XCTUnwrap(HyroxDivision.hommes.charges)
        let femmesPro = try XCTUnwrap(HyroxDivision.femmesPro.charges)
        XCTAssertEqual(hommes.sledPushKg, femmesPro.sledPushKg)
        XCTAssertEqual(hommes.sledPullKg, femmesPro.sledPullKg)
        XCTAssertEqual(hommes.kettlebellKg, femmesPro.kettlebellKg)
        XCTAssertEqual(hommes.sandbagKg, femmesPro.sandbagKg)
        XCTAssertEqual(hommes.wallBallKg, femmesPro.wallBallKg)
        XCTAssertNotEqual(hommes.wallBallCibleM, femmesPro.wallBallCibleM,
                          "la hauteur de cible ne suit pas la colonne des poids")

        XCTAssertEqual(hommes.sledPushKg, 152)
        XCTAssertEqual(hommes.sledPullKg, 103)
        XCTAssertEqual(hommes.kettlebellKg, 24)
        XCTAssertEqual(hommes.sandbagKg, 20)
        XCTAssertEqual(hommes.wallBallKg, 6)
    }

    /// Les deux hauteurs de cible, telles que le règlement les donne.
    func testLesHauteursDeCibleSontCellesDuReglement() throws {
        XCTAssertEqual(try XCTUnwrap(HyroxDivision.femmes.charges).wallBallCibleM, 2.70)
        XCTAssertEqual(try XCTUnwrap(HyroxDivision.femmesPro.charges).wallBallCibleM, 2.70)
        XCTAssertEqual(try XCTUnwrap(HyroxDivision.hommes.charges).wallBallCibleM, 3.00)
        XCTAssertEqual(try XCTUnwrap(HyroxDivision.hommesPro.charges).wallBallCibleM, 3.00)
    }

    /// Les charges montent dans l'ordre des divisions, sur chacune des cinq stations chargées.
    ///
    /// Une transposition de deux colonnes ne se verrait sur aucun nombre pris isolément, et ferait
    /// prescrire 202 kg à quelqu'un qui en pousse 102.
    func testLesChargesMontentAvecLaDivision() throws {
        let f = try XCTUnwrap(HyroxDivision.femmes.charges)
        let m = try XCTUnwrap(HyroxDivision.hommes.charges)
        let p = try XCTUnwrap(HyroxDivision.hommesPro.charges)
        XCTAssertLessThan(f.sledPushKg, m.sledPushKg)
        XCTAssertLessThan(m.sledPushKg, p.sledPushKg)
        XCTAssertLessThan(f.sledPullKg, m.sledPullKg)
        XCTAssertLessThan(m.sledPullKg, p.sledPullKg)
        XCTAssertLessThan(f.kettlebellKg, m.kettlebellKg)
        XCTAssertLessThan(m.kettlebellKg, p.kettlebellKg)
        XCTAssertLessThan(f.sandbagKg, m.sandbagKg)
        XCTAssertLessThan(m.sandbagKg, p.sandbagKg)
        XCTAssertLessThan(f.wallBallKg, m.wallBallKg)
        XCTAssertLessThan(m.wallBallKg, p.wallBallKg)
    }

    /// Le sled est le plus lourd en poussée qu'en traction, dans les trois colonnes.
    func testLeSledEstPlusLourdEnPousseeQuEnTraction() throws {
        for division in HyroxDivision.proposees {
            let c = try XCTUnwrap(division.charges, division.rawValue)
            XCTAssertGreaterThan(c.sledPushKg, c.sledPullKg, division.rawValue)
        }
    }

    // MARK: Les divisions héritées

    /// « OPEN » NE DIT PAS SI ELLE POUSSE 102 OU 152 KG, donc on ne l'invente pas.
    ///
    /// Un profil enregistré avant les quatre divisions porte `open` ou `pro`. Lui attribuer une
    /// colonne au hasard ferait prescrire une charge fausse à quelqu'un qui s'entraîne dessus —
    /// `nil` dit « on ne sait pas », et le plan se tait sur les kilos jusqu'à ce qu'elle rechoisisse.
    func testUneDivisionHeriteeNaPasDeCharges() {
        XCTAssertNil(HyroxDivision.open.charges)
        XCTAssertNil(HyroxDivision.pro.charges)
    }

    /// Elles se relisent toujours : un profil déjà enregistré ne devient pas illisible.
    func testLesValeursHeriteesSeDecodentEncore() {
        XCTAssertEqual(HyroxDivision(rawValue: "open"), .open)
        XCTAssertEqual(HyroxDivision(rawValue: "pro"), .pro)
    }

    /// Mais elles ne sont plus proposées : on ne fait pas choisir une division sans charges.
    func testLesDivisionsProposeesSontLesQuatreDuReglement() {
        XCTAssertEqual(HyroxDivision.proposees, [.femmes, .femmesPro, .hommes, .hommesPro])
        XCTAssertFalse(HyroxDivision.proposees.contains(.open))
        XCTAssertFalse(HyroxDivision.proposees.contains(.pro))
        // Et chacune des proposées porte bien des charges, sans quoi la carte n'aurait rien à dire.
        XCTAssertTrue(HyroxDivision.proposees.allSatisfy { $0.charges != nil })
    }

    /// `estPro` remplace un `== .pro` qui ne pouvait pas survivre au passage à quatre divisions.
    func testEstProReconnaitLesDeuxDivisionsPro() {
        XCTAssertTrue(HyroxDivision.femmesPro.estPro)
        XCTAssertTrue(HyroxDivision.hommesPro.estPro)
        XCTAssertFalse(HyroxDivision.femmes.estPro)
        XCTAssertFalse(HyroxDivision.hommes.estPro)
        // La valeur héritée `pro` reste Pro : c'est la seule chose qu'elle disait de sûr.
        XCTAssertTrue(HyroxDivision.pro.estPro)
        XCTAssertFalse(HyroxDivision.open.estPro)
    }

    // MARK: Le format, identique dans les quatre divisions

    /// Le règlement est explicite : « everyone must run 1 km between each for a total distance of
    /// 8 km ». Huit segments d'un kilomètre, dans toutes les divisions.
    func testLeFormatEstLeMemePourTousEtFaitHuitKilometres() {
        XCTAssertEqual(ChargesHyrox.Format.segmentsDeCourse, 8)
        XCTAssertEqual(ChargesHyrox.Format.courseParSegmentM, 1000)
        XCTAssertEqual(
            ChargesHyrox.Format.segmentsDeCourse * ChargesHyrox.Format.courseParSegmentM, 8000
        )
        // Le sled fait quatre allers de 12,5 m, et non deux de 25 : c'est le règlement qui le dit,
        // contre un résumé de moteur de recherche qui disait l'inverse.
        XCTAssertEqual(ChargesHyrox.Format.sledPushAllers, 4)
        XCTAssertEqual(ChargesHyrox.Format.sledPushM, 12.5)
        XCTAssertEqual(ChargesHyrox.Format.wallBallsReps, 100)
        XCTAssertEqual(ChargesHyrox.Format.burpeeBroadJumpM, 80)
        XCTAssertEqual(ChargesHyrox.Format.farmersCarryM, 200)
        XCTAssertEqual(ChargesHyrox.Format.fentesM, 100)
    }

    /// La saison est affichée avec les charges : un nombre daté n'est pas de la fausse précision,
    /// un nombre sans date en serait.
    func testLaSaisonEstNommee() {
        XCTAssertFalse(ChargesHyrox.saison.isEmpty)
        XCTAssertTrue(HyroxDivision.femmes.subtitle.contains("102"),
                      "la carte annonce la charge, pas une phrase sur le niveau")
    }
}
