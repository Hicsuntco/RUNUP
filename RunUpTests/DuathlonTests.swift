import XCTest
@testable import RunUp

/// Ce que les quatre formats de duathlon doivent vérifier, et qui ne se voit pas en relisant
/// une liste de nombres.
///
/// Aucune assertion ne porte sur un MOT : les titres passent par le catalogue, et le simulateur
/// de l'intégration continue tourne en anglais. Ce qui se teste ici, ce sont les distances, les
/// rapports entre elles, et la cohérence des chronos avec les heures d'effort — autant de choses
/// qui ne changent pas de langue.
final class DuathlonTests: XCTestCase {

    /// « 1:05 » → 1,083 heure. Les chronos sont écrits comme on les lit.
    private func heures(_ chrono: String) -> Double {
        let bouts = chrono.split(separator: ":").compactMap { Double($0) }
        XCTAssertEqual(bouts.count, 2, "chrono mal formé : \(chrono)")
        return bouts.count == 2 ? bouts[0] + bouts[1] / 60 : 0
    }

    // MARK: - Les distances des fédérations

    func testLesDistancesSontCellesDesFederations() {
        let attendu: [DuathlonFormat: (Double, Double, Double)] = [
            .sprint: (5, 20, 2.5),
            .standard: (10, 40, 5),
            .moyenneDistance: (10, 60, 10),
            .longueDistance: (10, 150, 30),
        ]
        for (format, (course1, velo, course2)) in attendu {
            XCTAssertEqual(format.premiereCourseKm, course1, accuracy: 0.0001, "\(format.rawValue)")
            XCTAssertEqual(format.veloKm, velo, accuracy: 0.0001, "\(format.rawValue)")
            XCTAssertEqual(format.secondeCourseKm, course2, accuracy: 0.0001, "\(format.rawValue)")
        }
        XCTAssertEqual(attendu.count, DuathlonFormat.allCases.count,
                       "Un format a été ajouté sans que ce test le connaisse.")
    }

    func testLaCourseTotaleEstLaSommeDesDeux() {
        for format in DuathlonFormat.allCases {
            XCTAssertEqual(format.courseTotaleKm,
                           format.premiereCourseKm + format.secondeCourseKm, accuracy: 0.0001)
        }
    }

    /// LE PREMIER PARCOURS N'EST JAMAIS LE PLUS COURT NULLE PART, et la seconde course n'est
    /// jamais absente. Un duathlon dont la seconde course tomberait à zéro serait un
    /// enchaînement course-vélo, c'est-à-dire autre chose.
    func testLesTroisEpreuvesExistentToujours() {
        for format in DuathlonFormat.allCases {
            XCTAssertGreaterThan(format.premiereCourseKm, 0, "\(format.rawValue)")
            XCTAssertGreaterThan(format.veloKm, 0, "\(format.rawValue)")
            XCTAssertGreaterThan(format.secondeCourseKm, 0, "\(format.rawValue)")
        }
    }

    // MARK: - Le résumé

    /// Trois épreuves, donc deux séparateurs — et l'ordre ne change jamais : on court, on roule,
    /// on court. Le test ne regarde pas les MOTS : « km » et la virgule décimale suivent la
    /// langue de l'appareil.
    func testLeResumePorteLesTroisEpreuvesDansLOrdre() {
        for format in DuathlonFormat.allCases {
            let resume = format.resume
            XCTAssertEqual(resume.filter { $0 == "·" }.count, 2, resume)
            let morceaux = resume.components(separatedBy: "·")
            XCTAssertTrue(morceaux[0].contains("\(Int(format.premiereCourseKm))"), resume)
            XCTAssertTrue(morceaux[1].contains("\(Int(format.veloKm))"), resume)
        }
    }

    // MARK: - Les chronos et les heures d'effort

    func testLesChronosSontQuatreEtCroissants() {
        for format in DuathlonFormat.allCases {
            let bornes = format.chronoPresets.map(heures)
            XCTAssertEqual(bornes.count, 4, "\(format.rawValue)")
            XCTAssertEqual(bornes, bornes.sorted(), "\(format.rawValue) : chronos non croissants")
        }
    }

    /// `heuresDeffort` dimensionne le volume de la semaine. Si elle dérivait des chronos qu'on
    /// propose à côté, le plan préparerait une autre course que celle qui est affichée.
    func testLesHeuresDEffortCollentAuMilieuDesChronos() {
        for format in DuathlonFormat.allCases {
            let bornes = format.chronoPresets.map(heures)
            let milieu = ((bornes.first ?? 0) + (bornes.last ?? 0)) / 2
            let ecart = abs(milieu - format.heuresDeffort) / format.heuresDeffort
            XCTAssertLessThan(ecart, 0.12,
                              "\(format.rawValue) : \(format.heuresDeffort) h contre \(milieu) h de milieu")
        }
    }

    func testPlusLeFormatEstLongPlusIlDemandeDHeures() {
        let ordre: [DuathlonFormat] = [.sprint, .standard, .moyenneDistance, .longueDistance]
        let heures = ordre.map(\.heuresDeffort)
        XCTAssertEqual(heures, heures.sorted(), "\(heures)")
    }

    // MARK: - Ce qui fait un duathlon

    /// LA PART COURUE DÉCROÎT QUAND LE VÉLO GROSSIT, et reste toujours majoritaire ou presque.
    /// C'est la grandeur dont le plan se sert pour ne pas sous-entraîner la course.
    func testLaPartCourueDecroitAvecLaTailleDuVelo() {
        let ordre: [DuathlonFormat] = [.sprint, .standard, .moyenneDistance, .longueDistance]
        let parts = ordre.map(\.partCourue)
        XCTAssertEqual(parts, parts.sorted(by: >), "\(parts)")
        for (format, part) in zip(ordre, parts) {
            XCTAssertGreaterThan(part, 0.40, "\(format.rawValue) : \(part)")
            XCTAssertLessThan(part, 0.60, "\(format.rawValue) : \(part)")
        }
    }

    /// L'INVARIANT QUI JUSTIFIE UN PLAN SÉPARÉ.
    ///
    /// À durée comparable, un duathlon se court bien plus qu'un triathlon : deux épreuves à pied
    /// sur trois, et pas de natation pour prendre du temps sans faire courir. Un plan de
    /// duathlon calqué sur celui du triathlon sous-entraînerait la course — et c'est exactement
    /// le défaut qui fait finir le second parcours en marchant.
    func testUnDuathlonSeCourtBienPlusQuUnTriathlon() {
        // Le triathlon olympique, calculé ici avec les mêmes allures de référence : 5:30/km à
        // pied, 30 km/h à vélo, 3,0 km/h à la nage.
        let tri = TriathlonFormat.olympique
        let triCourse = tri.courseKm * 5.5 / 60
        let triVelo = tri.veloKm / 30
        let triNage = Double(tri.nageMetres) / 1000 / 3.0
        let triPart = triCourse / (triCourse + triVelo + triNage)

        XCTAssertGreaterThan(DuathlonFormat.standard.partCourue, triPart * 1.4,
                             "duathlon \(DuathlonFormat.standard.partCourue) contre triathlon \(triPart)")
    }

    /// Un duathlon demande moins d'heures que le triathlon du même rang : pas de natation, et
    /// un vélo plus court. Si cette règle sautait, le volume hebdomadaire serait calé trop haut.
    func testUnDuathlonDemandeMoinsDHeuresQueLeTriathlonDuMemeRang() {
        let paires: [(DuathlonFormat, TriathlonFormat)] = [
            (.sprint, .sprint), (.standard, .olympique), (.longueDistance, .longueDistance),
        ]
        for (duathlon, triathlon) in paires {
            XCTAssertLessThan(duathlon.heuresDeffort, triathlon.heuresDeffort,
                              "\(duathlon.rawValue) contre \(triathlon.rawValue)")
        }
    }

    // MARK: - L'énumération elle-même

    func testLesTitresSontDistinctsEtNonVides() {
        let titres = DuathlonFormat.allCases.map(\.title)
        XCTAssertEqual(Set(titres).count, titres.count, "\(titres)")
        for titre in titres { XCTAssertFalse(titre.isEmpty) }
    }

    /// `rawValue` est écrit en base dans `UserProfile` : le renommer silencieusement rendrait
    /// illisible le format choisi par toutes celles qui ont déjà un plan en cours.
    func testLesIdentifiantsStockesNeChangentPas() {
        XCTAssertEqual(DuathlonFormat.allCases.map(\.rawValue),
                       ["sprint", "standard", "moyenneDistance", "longueDistance"])
    }
}
