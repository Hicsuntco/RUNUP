import XCTest
@testable import RunUp

/// Verrouille les allures d'entraînement sur la table publiée de Jack Daniels.
///
/// # CE QUE CES CAS REMPLACENT
///
/// Les quatre allures du plan étaient des coefficients fixes — footing × 1,20, marathon × 1,08,
/// seuil × 1,00, VMA × 0,87 — et le commentaire qui les portait avouait leur origine : « in the
/// spirit of standard recreational running pace calculators ». Aucune source.
///
/// Il y avait pourtant un test, et il était vert : `testIntervalPaceIsAGenuineVO2maxStimulus`
/// exigeait un écart seuil→VMA de 11 à 20 %, sur la foi d'un commentaire affirmant que « real
/// vVO2max sits ~12-18% faster ». Mesuré sur la table de Daniels, l'écart vaut **7,8 à 8,0 %**.
/// Le test ne vérifiait pas une règle : il verrouillait un chiffre inventé, et le verrouillait
/// d'autant mieux qu'il était vert. C'est le pire genre de test, et le remède n'est pas d'en
/// écrire un de plus mais de l'adosser à quelque chose qui ne vient pas de nous.
///
/// # D'OÙ VIENNENT LES NOMBRES CI-DESSOUS
///
/// De la table de Daniels, pour les VDOT 30 à 60 de cinq en cinq — allures en min/km, temps de
/// course en h:mm:ss. Le premier cas vérifie que les deux équations d'*Oxygen Power* retrouvent le
/// VDOT de chaque ligne depuis le temps de 10 km de cette même ligne : si c'est vrai, la table
/// recopiée est bien celle de Daniels et non la paraphrase d'un site. Les cas suivants vérifient
/// l'inversion, allure par allure.
///
/// Ce qui est vérifié n'est donc pas « le code fait ce que le code fait », mais « le code rend la
/// table d'un entraîneur nommé, publiée, et qu'on ne contrôle pas ».
final class VdotTests: XCTestCase {

    /// Une ligne de la table de Daniels. Allures et temps en secondes.
    private struct Ligne {
        let vdot: Double
        let footingLent: Double, footingRapide: Double
        let marathon: Double, seuil: Double, intervalle: Double
        let k5: Double, k10: Double, semi: Double, mar: Double
    }

    private static func s(_ txt: String) -> Double {
        let p = txt.split(separator: ":").compactMap { Double($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : p[0] * 3600 + p[1] * 60 + p[2]
    }

    /// La table, recopiée telle quelle. Sept lignes, dix colonnes.
    private static let table: [Ligne] = [
        Ligne(vdot: 30, footingLent: s("8:23"), footingRapide: s("7:39"), marathon: s("6:52"),
              seuil: s("6:24"), intervalle: s("5:54"),
              k5: s("30:41"), k10: s("1:03:49"), semi: s("2:21:17"), mar: s("4:49:49")),
        Ligne(vdot: 35, footingLent: s("7:28"), footingRapide: s("6:47"), marathon: s("6:04"),
              seuil: s("5:40"), intervalle: s("5:13"),
              k5: s("26:59"), k10: s("56:02"), semi: s("2:04:13"), mar: s("4:16:06")),
        Ligne(vdot: 40, footingLent: s("6:44"), footingRapide: s("6:07"), marathon: s("5:27"),
              seuil: s("5:06"), intervalle: s("4:41"),
              k5: s("24:06"), k10: s("50:01"), semi: s("1:50:54"), mar: s("3:49:37")),
        Ligne(vdot: 45, footingLent: s("6:08"), footingRapide: s("5:34"), marathon: s("4:56"),
              seuil: s("4:38"), intervalle: s("4:16"),
              k5: s("21:49"), k10: s("45:13"), semi: s("1:40:14"), mar: s("3:28:16")),
        Ligne(vdot: 50, footingLent: s("5:38"), footingRapide: s("5:07"), marathon: s("4:31"),
              seuil: s("4:15"), intervalle: s("3:55"),
              k5: s("19:56"), k10: s("41:20"), semi: s("1:31:31"), mar: s("3:10:40")),
        Ligne(vdot: 55, footingLent: s("5:13"), footingRapide: s("4:44"), marathon: s("4:10"),
              seuil: s("3:56"), intervalle: s("3:37"),
              k5: s("18:22"), k10: s("38:06"), semi: s("1:24:16"), mar: s("2:55:55")),
        Ligne(vdot: 60, footingLent: s("4:52"), footingRapide: s("4:25"), marathon: s("3:52"),
              seuil: s("3:40"), intervalle: s("3:23"),
              k5: s("17:03"), k10: s("35:22"), semi: s("1:18:09"), mar: s("2:43:22")),
    ]

    // MARK: - 1. La table recopiée est-elle bien celle de Daniels ?

    /// Les deux équations retrouvent le VDOT de chaque ligne depuis son propre temps de 10 km.
    ///
    /// LE CAS LE PLUS IMPORTANT DU FICHIER, et il ne teste pas notre code pour lui-même : il teste
    /// que la table recopiée depuis le web est cohérente avec les équations publiées d'*Oxygen
    /// Power*. Si elle ne l'était pas, tous les cas suivants vérifieraient une invention.
    func testLaTableEstCoherenteAvecLesEquationsPubliees() throws {
        for l in Self.table {
            let calcule = Vdot.depuisPerformance(km: 10, secondes: l.k10)
            XCTAssertEqual(try XCTUnwrap(calcule), l.vdot, accuracy: 0.05,
                           "le 10 km de la ligne VDOT \(Int(l.vdot)) ne redonne pas son VDOT")
        }
    }

    /// Et depuis N'IMPORTE QUELLE distance de la ligne — c'est ce qui permet de se passer de
    /// Riegel pour ancrer les zones.
    ///
    /// Riegel projette une performance d'une distance sur une autre avec un exposant ajusté sur
    /// des records du monde. Ici, les quatre distances d'une même ligne rendent le même VDOT à
    /// cinq centièmes près, sans aucune projection : la durée entre dans les équations.
    func testToutesLesDistancesDUneLigneRendentLeMemeVdot() throws {
        for l in Self.table {
            for (km, secondes) in [(5.0, l.k5), (10.0, l.k10), (21.0975, l.semi), (42.195, l.mar)] {
                let calcule = Vdot.depuisPerformance(km: km, secondes: secondes)
                XCTAssertEqual(try XCTUnwrap(calcule), l.vdot, accuracy: 0.05,
                               "VDOT \(Int(l.vdot)) : le \(km) km rend autre chose")
            }
        }
    }

    // MARK: - 2. L'inversion rend-elle la table ?

    /// Les deux bords de la plage facile, à la seconde près.
    func testLesDeuxBordsDuFootingRendentLaTable() {
        for l in Self.table {
            XCTAssertEqual(Vdot.allure(vdot: l.vdot, fraction: Vdot.Fraction.footingLent),
                           l.footingLent, accuracy: 1.0, "footing lent, VDOT \(Int(l.vdot))")
            XCTAssertEqual(Vdot.allure(vdot: l.vdot, fraction: Vdot.Fraction.footingRapide),
                           l.footingRapide, accuracy: 1.0, "footing rapide, VDOT \(Int(l.vdot))")
        }
    }

    func testLeSeuilRendLaTable() {
        for l in Self.table {
            XCTAssertEqual(Vdot.allure(vdot: l.vdot, fraction: Vdot.Fraction.seuil),
                           l.seuil, accuracy: 1.0, "seuil, VDOT \(Int(l.vdot))")
        }
    }

    func testLintervalleRendLaTable() {
        for l in Self.table {
            XCTAssertEqual(Vdot.allure(vdot: l.vdot, fraction: Vdot.Fraction.intervalle),
                           l.intervalle, accuracy: 1.0, "intervalle, VDOT \(Int(l.vdot))")
        }
    }

    /// L'allure marathon passe par la DURÉE DE COURSE, pas par une fraction fixe.
    ///
    /// Et c'est pour ça qu'elle tombe juste. La fraction qu'implique l'allure marathon de la table
    /// dérive de 80,5 % à 82,5 % le long des sept lignes : la figer à sa moyenne se tromperait
    /// jusqu'à trois secondes au kilomètre, alors que la calculer comme une course de 42,195 km
    /// reste sous la seconde partout.
    func testLeMarathonPasseParLaDureeDeCourse() {
        for l in Self.table {
            XCTAssertEqual(Vdot.allureDeCourse(vdot: l.vdot, km: 42.195),
                           l.marathon, accuracy: 1.0, "marathon, VDOT \(Int(l.vdot))")
        }
    }

    /// La prédiction de temps de course rend les quatre colonnes de temps de la table.
    func testLesTempsDeCoursePreditsRendentLaTable() {
        for l in Self.table {
            for (km, attendu) in [(5.0, l.k5), (10.0, l.k10), (21.0975, l.semi), (42.195, l.mar)] {
                let predit = Vdot.allureDeCourse(vdot: l.vdot, km: km) * km
                // Une seconde par kilomètre de tolérance : sur un marathon, ça fait quarante-deux
                // secondes sur quatre heures. Serrer plus testerait l'arrondi de la table.
                XCTAssertEqual(predit, attendu, accuracy: km,
                               "VDOT \(Int(l.vdot)) : \(km) km prédit \(Int(predit)) s au lieu de \(Int(attendu))")
            }
        }
    }

    // MARK: - 3. Ce que les coefficients fixes ne pouvaient pas faire

    /// LE DÉFAUT D'ORIGINE, chiffré : aucun coefficient fixe ne couvre la plage.
    ///
    /// Le rapport footing/seuil de Daniels n'est pas une constante — il s'écarte de plus de deux
    /// points entre un VDOT de 30 et un VDOT de 60. Un coefficient unique, quel qu'il soit, se
    /// trompe donc à une extrémité au moins. Ce cas existe pour que personne ne « simplifie »
    /// `Vdot` en revenant à une multiplication.
    func testAucunCoefficientFixeNePeutCouvrirLaPlage() throws {
        let rapports = Self.table.map { l in
            ((l.footingLent + l.footingRapide) / 2) / l.seuil
        }
        let plusSerre = try XCTUnwrap(rapports.min())
        let plusLarge = try XCTUnwrap(rapports.max())
        XCTAssertGreaterThan(plusLarge - plusSerre, 0.01,
                             "si ce rapport était constant, un coefficient fixe suffirait — "
                             + "ce cas n'aurait plus de raison d'être, et `Vdot` non plus")
        XCTAssertEqual(plusSerre, 1.2526, accuracy: 0.002)
        XCTAssertEqual(plusLarge, 1.2659, accuracy: 0.002)
    }

    /// L'écart seuil→VMA vaut 7,8 à 8,0 %, pas les 12 à 18 % qu'affirmait le code.
    ///
    /// C'est le chiffre exact que l'ancien test interdisait. Il est ici avec sa source : l'allure
    /// d'intervalle de Daniels est à peine plus rapide que l'allure du 5 km — la table le montre
    /// ligne par ligne — et non à l'allure du mile.
    func testLecartSeuilVersVmaEstCeluiDeLaTable() {
        for l in Self.table {
            let ecart = (l.seuil - l.intervalle) / l.seuil
            XCTAssertEqual(ecart, 0.079, accuracy: 0.004,
                           "VDOT \(Int(l.vdot)) : écart seuil→VMA de \(Int(ecart * 1000))‰")
        }
    }

    /// L'allure d'intervalle est l'allure du 5 km, à quatre points près — ce qui est la DÉFINITION
    /// que Daniels en donne, et ce que × 0,87 ne pouvait pas respecter.
    func testLintervalleEstPresqueLallureDu5km() {
        for l in Self.table {
            XCTAssertEqual(l.intervalle / (l.k5 / 5), 1.0, accuracy: 0.045,
                           "VDOT \(Int(l.vdot))")
        }
    }

    // MARK: - 4. Les refus

    /// L'ULTRA EST REFUSÉ, et c'est la garde la plus importante du fichier.
    ///
    /// Cent kilomètres en vingt heures donnent un VDOT de 14 si on laisse passer : on finit un
    /// ultra en marchant les montées, ce qui ne dit rien de la vitesse de personne. Le modèle de
    /// Daniels couvre du 1 500 m au marathon, et au-delà il faut rendre « je ne sais pas » plutôt
    /// qu'un nombre qui ancrerait les quatre allures d'un plan entier.
    func testLesDistancesHorsPlageSontRefusees() {
        XCTAssertNil(Vdot.depuisPerformance(km: 100, secondes: 20 * 3600))
        XCTAssertNil(Vdot.depuisPerformance(km: 160.9, secondes: 30 * 3600))
        XCTAssertNil(Vdot.depuisPerformance(km: 50, secondes: 7 * 3600))
        XCTAssertNil(Vdot.depuisPerformance(km: 0.4, secondes: 60))
        XCTAssertNil(Vdot.depuisPerformance(km: 10, secondes: 0))
        XCTAssertNil(Vdot.depuisPerformance(km: 0, secondes: 1800))
    }

    /// Le marathon passe, l'ultra non : la frontière est là où Daniels la met.
    func testLaFrontiereEstLeMarathon() {
        XCTAssertNotNil(Vdot.depuisPerformance(km: 42.195, secondes: 4 * 3600))
        XCTAssertNil(Vdot.depuisPerformance(km: 45, secondes: 4 * 3600 + 20 * 60))
    }

    /// Une saisie absurde est bornée, pas propagée.
    ///
    /// « 5 km en 8 min » est plus rapide que tout record ; « 5 km en 2 h » est une promenade. Les
    /// deux doivent rendre un VDOT dans la plage, parce que le champ est du texte libre et qu'une
    /// faute de frappe ne doit pas donner une allure de plan à deux chiffres.
    func testLesSaisiesAbsurdesSontBornees() throws {
        let tropVite = try XCTUnwrap(Vdot.depuisPerformance(km: 5, secondes: 8 * 60))
        let tropLent = try XCTUnwrap(Vdot.depuisPerformance(km: 5, secondes: 2 * 3600))
        XCTAssertEqual(tropVite, Vdot.vdotMax, accuracy: 0.001)
        XCTAssertEqual(tropLent, Vdot.vdotMin, accuracy: 0.001)
        for v in [tropVite, tropLent] {
            let footing = Vdot.allure(vdot: v, fraction: Vdot.Fraction.footing)
            XCTAssertTrue((150...900).contains(footing), "footing hors de l'humain : \(footing)")
        }
    }

    /// LE BORNAGE N'EST PAS POUR TOUT LE MONDE, ET C'EST POUR ÇA QU'IL Y A DEUX FONCTIONS.
    ///
    /// Le premier jet n'en avait qu'une, bornée, avec un plancher inventé à 25. Quelqu'un qui
    /// court son 10 km en 1 h 40 — une vraie personne — a un VDOT de 17,2 : ramené à 25, son plan
    /// lui prescrivait des footings PLUS RAPIDES que son allure de course, et sa prédiction de
    /// marathon tombait en dessous de son propre 10 km au kilomètre.
    ///
    /// Le plancher est donc descendu à la frontière marche/course, et le bornage est séparé : un
    /// plan le veut — mieux un plan borné qu'aucun plan —, une prédiction non.
    func testLeBornageEstSepareDeLaLecture() throws {
        // Une vraie personne lente : les deux lectures doivent s'accorder, donc pas de bornage.
        let lent = try XCTUnwrap(Vdot.depuisPerformanceBrut(km: 10, secondes: 100 * 60))
        XCTAssertEqual(lent, try XCTUnwrap(Vdot.depuisPerformance(km: 10, secondes: 100 * 60)),
                       accuracy: 0.001, "un 10 km en 1 h 40 est dans la plage, il ne doit rien subir")
        XCTAssertGreaterThan(lent, Vdot.vdotMin)

        // Et son footing doit rester plus LENT que son allure de course. C'était le défaut.
        let footing = Vdot.allure(vdot: lent, fraction: Vdot.Fraction.footing)
        XCTAssertGreaterThan(footing, 600,
                             "footing à \(Int(footing)) s/km pour quelqu'un qui court à 600")

        // Une saisie fautive, elle, s'écarte : le brut la laisse voir, le borné la rattrape.
        let faute = try XCTUnwrap(Vdot.depuisPerformanceBrut(km: 5, secondes: 2 * 3600))
        XCTAssertLessThan(faute, Vdot.vdotMin)
        XCTAssertEqual(try XCTUnwrap(Vdot.depuisPerformance(km: 5, secondes: 2 * 3600)),
                       Vdot.vdotMin, accuracy: 0.001)
    }

    /// LES DEUX BORNES SE NOMMENT, et le premier jet avait tort des deux côtés.
    ///
    /// Le plafond de 85 rabotait une performance humaine réelle : le record du monde du marathon
    /// au moment où ces lignes sont écrites — 1 h 59 min 30 s — vaut 86,45. Le plancher de 25
    /// écartait une vraie coureuse lente. Ce cas fixe les deux contre ce qu'ils doivent séparer :
    /// dedans, un record et une marche-course ; dehors, une faute de frappe.
    func testLesBornesSeparentUnRecordDUneFauteDeFrappe() throws {
        // Le record du monde du marathon, 1 h 59 min 30 s : DEDANS, et à peine.
        let record = try XCTUnwrap(Vdot.depuisPerformanceBrut(km: 42.195, secondes: 7170))
        XCTAssertGreaterThan(record, 85, "le record vaut \(record)")
        XCTAssertLessThan(record, Vdot.vdotMax, "le plafond rabote un record du monde")

        // La frontière marche/course, un 10 km à 12:00/km : DEDANS aussi.
        let marcheCourse = try XCTUnwrap(Vdot.depuisPerformanceBrut(km: 10, secondes: 7200))
        XCTAssertGreaterThanOrEqual(marcheCourse, Vdot.vdotMin,
                                    "la frontière marche/course vaut \(marcheCourse)")

        // Et les fautes de frappe, très loin dehors — assez pour que la valeur exacte des bornes
        // n'ait aucune importance, ce qui est le seul argument qui les rende défendables.
        for (km, secondes) in [(5.0, 8.0 * 60), (42.195, 3600.0)] {
            let trop = try XCTUnwrap(Vdot.depuisPerformanceBrut(km: km, secondes: secondes))
            XCTAssertGreaterThan(trop, Vdot.vdotMax * 1.5, "\(km) km en \(Int(secondes)) s")
        }
        for (km, secondes) in [(5.0, 2.0 * 3600), (10.0, 3.0 * 3600)] {
            let trop = try XCTUnwrap(Vdot.depuisPerformanceBrut(km: km, secondes: secondes))
            XCTAssertLessThan(trop, Vdot.vdotMin * 0.6, "\(km) km en \(Int(secondes)) s")
        }
    }

    // MARK: - 5. La forme des fonctions

    /// L'ordre des quatre allures, à tous les niveaux de la plage.
    ///
    /// Une inversion de deux zones ne se verrait nulle part ailleurs : le plan afficherait une
    /// séance de seuil plus lente qu'un footing, et rien ne planterait.
    func testLesAlluresVontToujoursDuPlusLentAuPlusRapide() {
        for vdot in stride(from: Vdot.vdotMin, through: Vdot.vdotMax, by: 2.5) {
            let footing = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.footing)
            let marathon = Vdot.allureDeCourse(vdot: vdot, km: 42.195)
            let seuil = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.seuil)
            let vma = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.intervalle)
            XCTAssertGreaterThan(footing, marathon, "VDOT \(vdot)")
            XCTAssertGreaterThan(marathon, seuil, "VDOT \(vdot)")
            XCTAssertGreaterThan(seuil, vma, "VDOT \(vdot)")
        }
    }

    /// La dichotomie d'`allureDeCourse` suppose la monotonie. Elle est vérifiée, pas affirmée.
    func testUnePlusLongueDistanceEstToujoursPlusLente() {
        for vdot in [30.0, 45.0, 60.0, 80.0] {
            var precedente = 0.0
            for km in [1.5, 3.0, 5.0, 10.0, 21.0975, 30.0, 42.195] {
                let allure = Vdot.allureDeCourse(vdot: vdot, km: km)
                XCTAssertGreaterThan(allure, precedente,
                                     "VDOT \(vdot) : le \(km) km n'est pas plus lent que la distance d'avant")
                precedente = allure
            }
        }
    }

    /// Un VDOT plus haut, des allures plus rapides — partout.
    func testUnVdotPlusHautDonneDesAlluresPlusRapides() {
        for fraction in [Vdot.Fraction.footingLent, Vdot.Fraction.footing,
                         Vdot.Fraction.seuil, Vdot.Fraction.intervalle] {
            var precedente = Double.greatestFiniteMagnitude
            for vdot in stride(from: Vdot.vdotMin, through: Vdot.vdotMax, by: 5) {
                let allure = Vdot.allure(vdot: vdot, fraction: fraction)
                XCTAssertLessThan(allure, precedente, "fraction \(fraction), VDOT \(vdot)")
                precedente = allure
            }
        }
    }

    /// L'aller-retour : une allure facile déclarée redonne le VDOT dont elle vient.
    ///
    /// C'est le chemin du questionnaire pour qui ne donne aucun chrono, et l'ancien code s'y
    /// trompait du côté opposé à celui où il se trompait sur les chronos : il déduisait d'une
    /// allure de footing un seuil 14 s/km trop LENT, en même temps qu'il déduisait d'un chrono un
    /// footing 25 s/km trop RAPIDE. Deux erreurs de signe contraire, et rien qui les rapproche.
    func testLallerRetourAllureVdotEstSansPerte() throws {
        for vdot in stride(from: 30.0, through: 70.0, by: 5) {
            let allure = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.footing)
            let retour = try XCTUnwrap(Vdot.depuisAllure(secondesParKm: allure,
                                                         fraction: Vdot.Fraction.footing))
            XCTAssertEqual(retour, vdot, accuracy: 0.01, "aller-retour à VDOT \(vdot)")
        }
    }

    /// Le milieu de la plage facile reste DANS la plage, et près du milieu des deux allures.
    func testLeFootingResteDansLaPlageFacile() {
        for l in Self.table {
            let footing = Vdot.allure(vdot: l.vdot, fraction: Vdot.Fraction.footing)
            XCTAssertGreaterThan(footing, l.footingRapide, "VDOT \(Int(l.vdot))")
            XCTAssertLessThan(footing, l.footingLent, "VDOT \(Int(l.vdot))")
            XCTAssertEqual(footing, (l.footingLent + l.footingRapide) / 2, accuracy: 1.5,
                           "VDOT \(Int(l.vdot))")
        }
    }
}
