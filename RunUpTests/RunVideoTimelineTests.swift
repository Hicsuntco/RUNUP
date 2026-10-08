import XCTest
@testable import RunUp

/// Le déroulé d'une vidéo de course : ce que montre l'image 173.
///
/// Ces tests ne sont pas de la couverture. Une vidéo se POSTE : c'est la surface où un tracé mal
/// rogné publie une adresse, et où un compteur faux est lu par des gens qui n'ont pas l'app. Le
/// rendu demande un appareil et un encodeur ; l'arithmétique, non — et c'est elle qui se trompe.
final class RunVideoTimelineTests: XCTestCase {

    // MARK: Fixtures

    /// Un tracé rectiligne vers l'est, à Paris, avec un point tous les `pas` mètres.
    ///
    /// Même forme que `RouteSharingPrivacyTests` : une ligne droite est le pire cas pour le
    /// rognage, puisque chaque mètre parcouru est un mètre gagné en éloignement du départ.
    private func ligneDroite(points: Int, pas: Double, altitudes: ((Int) -> Double?)? = nil)
        -> [RunRecord.RoutePoint] {
        let lat = 48.8566
        let lng = 2.3522
        let metresParDegre = 111_320.0 * cos(lat * .pi / 180)
        return (0..<points).map { i in
            RunRecord.RoutePoint(lat: lat,
                                 lng: lng + (Double(i) * pas) / metresParDegre,
                                 altitude: altitudes?(i))
        }
    }

    private func sortie(points: Int, pas: Double, km: Double, secondes: Int,
                        splits: [String] = [], denivele: Int = 0,
                        altitudes: ((Int) -> Double?)? = nil) -> RunRecord {
        RunRecord(title: "Test", distanceKm: km, durationSeconds: secondes,
                  avgPace: "5:00", avgHeartRate: 150, kcal: 500,
                  elevationGainM: denivele, splits: splits,
                  route: ligneDroite(points: points, pas: pas, altitudes: altitudes))
    }

    /// Dix kilomètres en cinquante minutes, un point tous les dix mètres.
    private func dixKilometres(splits: [String] = [], denivele: Int = 0,
                               altitudes: ((Int) -> Double?)? = nil) -> RunRecord {
        sortie(points: 1001, pas: 10, km: 10, secondes: 3000,
               splits: splits, denivele: denivele, altitudes: altitudes)
    }

    private let splitsReguliers = ["5:00", "5:00", "5:00", "5:00", "5:00",
                                   "5:00", "5:00", "5:00", "5:00", "5:00"]
    /// Un cinquième kilomètre deux fois plus lent : la côte.
    private let splitsAvecCote = ["4:20", "4:20", "4:20", "4:20", "8:00",
                                  "4:20", "4:20", "4:20", "4:20", "4:20"]

    // MARK: LA RÈGLE QUI COMPTE : CE QUI SORT DU TÉLÉPHONE

    /// LE TEST LE PLUS IMPORTANT DE CE FICHIER.
    ///
    /// Une vidéo se poste, donc le tracé qu'elle dessine quitte le téléphone — et un tracé GPS
    /// brut commence et finit devant chez soi. La vidéo doit passer par la MÊME porte que le
    /// partage, et jamais par une seconde écriture de la règle.
    func testLeTraceDessineNeContientJamaisLesExtremitesReelles() {
        let run = dixKilometres(splits: splitsReguliers)
        guard let rendu = RunVideoTimeline.pour(run, images: 60) else {
            return XCTFail("un dix kilomètres doit donner une vidéo")
        }
        let brut: [RunRecord.RoutePoint] = run.route
        guard let premierDessine = rendu.route.first, let dernierDessine = rendu.route.last,
              let vraiDepart = brut.first, let vraieArrivee = brut.last
        else { return XCTFail("tracé vide") }

        let perduAuDepart = RouteGeometry.distanceMeters(vraiDepart, premierDessine)
        let perduALArrivee = RouteGeometry.distanceMeters(vraieArrivee, dernierDessine)
        XCTAssertGreaterThanOrEqual(perduAuDepart, RouteGeometry.sharingTrimMeters,
                                    "le trait commence à \(Int(perduAuDepart)) m du départ réel")
        XCTAssertGreaterThanOrEqual(perduALArrivee, RouteGeometry.sharingTrimMeters,
                                    "le trait finit à \(Int(perduALArrivee)) m de l'arrivée réelle")
    }

    /// Les trois refus, et ils sont délibérés : mieux vaut pas de bouton qu'une vidéo d'un trait
    /// de trois points — ou qu'une vidéo d'un tracé qui n'a pas survécu au rognage.
    func testLesSortiesQuiNeDoiventPasDonnerDeVideo() {
        // Pas de tracé du tout : une sortie saisie à la main, un tapis de course.
        let sansTrace = RunRecord(title: "Tapis", distanceKm: 8, durationSeconds: 2400,
                                  avgPace: "5:00", avgHeartRate: 150, kcal: 400)
        XCTAssertNil(RunVideoTimeline.pour(sansTrace))

        // Neuf cents mètres : il ne reste rien après avoir retiré 300 m aux deux bouts.
        let tropCourte = sortie(points: 91, pas: 10, km: 0.9, secondes: 300)
        XCTAssertNil(RunVideoTimeline.pour(tropCourte), "900 m ne survivent pas au rognage")

        // Une durée nulle : rien à dérouler.
        let sansDuree = sortie(points: 1001, pas: 10, km: 10, secondes: 0)
        XCTAssertNil(RunVideoTimeline.pour(sansDuree))
    }

    // MARK: Le temps

    /// La courbe du temps doit être EXACTE aux deux bouts, quels que soient les splits. C'est le
    /// défaut qu'une simulation a trouvé : sur un dix kilomètres pile, les dix splits couvrent
    /// toute la distance, et sans recalage le chronomètre finissait à 47:00 pour une sortie de
    /// 50:00 — la dernière image sautait de trois minutes.
    func testLeTempsEstExactAuxDeuxBouts() {
        let jeux: [[String]] = [[], splitsReguliers, splitsAvecCote,
                                ["5:01", "5:01", "5:01", "5:01", "5:01",
                                 "5:01", "5:01", "5:01", "5:01", "5:01"]]
        for splits in jeux {
            let secondes: [Double] = splits.compactMap(PaceModel.parseSecPerKm)
            let debut = RunVideoTimeline.secondes(aMetres: 0, splits: secondes,
                                                  metresTotaux: 10000, secondesTotales: 3000)
            let fin = RunVideoTimeline.secondes(aMetres: 10000, splits: secondes,
                                                metresTotaux: 10000, secondesTotales: 3000)
            XCTAssertEqual(debut, 0, accuracy: 0.001, "\(splits.count) split(s)")
            XCTAssertEqual(fin, 3000, accuracy: 0.001, "\(splits.count) split(s)")
        }
    }

    /// Sans aucun split, on ne sait rien de l'allure : la répartition uniforme est la seule
    /// honnête, et elle ne prétend rien entre les deux bouts.
    func testSansSplitLeTempsEstUniforme() {
        let moitie = RunVideoTimeline.secondes(aMetres: 5000, splits: [],
                                               metresTotaux: 10000, secondesTotales: 3000)
        XCTAssertEqual(moitie, 1500, accuracy: 0.001)
    }

    /// CE QUI SÉPARE UNE VIDÉO DE SA COURSE D'UNE ANIMATION. Les points du tracé ne portent pas
    /// d'horodatage, mais les splits portent le temps réel de chaque kilomètre : le trait doit
    /// donc traîner là où elle a traîné.
    func testUnKilometreLentRalentitLeTrait() {
        let images = 360
        let secondes: [Double] = splitsAvecCote.compactMap(PaceModel.parseSecPerKm)
        let run = dixKilometres(splits: splitsAvecCote)
        guard let rendu = RunVideoTimeline.pour(run, images: images) else {
            return XCTFail("un dix kilomètres doit donner une vidéo")
        }
        XCTAssertEqual(secondes.count, 10)

        let dansLaCote = rendu.instants.filter { $0.metres >= 4000 && $0.metres < 5000 }.count
        let siUniforme = images / 10
        XCTAssertGreaterThan(dansLaCote, siUniforme + images / 20,
                             "le km lent ne reçoit que \(dansLaCote) images sur \(images)")
    }

    // MARK: Les invariants du déroulé

    /// Aucun compteur ne recule, et le trait ne se raccourcit jamais. Un compteur qui recule est
    /// le défaut qu'on remarque immédiatement et qu'on ne pardonne pas à une vidéo qu'on a postée.
    func testRienNeReculeJamais() {
        for splits in [[], splitsReguliers, splitsAvecCote] {
            let run = dixKilometres(splits: splits, denivele: 180) { i in 35 + Double(i % 50) }
            guard let rendu = RunVideoTimeline.pour(run, images: 120) else {
                return XCTFail("\(splits.count) split(s) : pas de vidéo")
            }
            for (avant, apres) in zip(rendu.instants, rendu.instants.dropFirst()) {
                XCTAssertGreaterThanOrEqual(apres.pointsDessines, avant.pointsDessines)
                XCTAssertGreaterThanOrEqual(apres.metres, avant.metres - 0.001)
                XCTAssertGreaterThanOrEqual(apres.secondes, avant.secondes - 0.001)
            }
        }
    }

    /// Une première image vide se lit comme une vidéo qui n'a pas démarré.
    func testLaPremiereImageDessineQuelqueChose() {
        let run = dixKilometres(splits: splitsReguliers)
        guard let rendu = RunVideoTimeline.pour(run, images: 90) else {
            return XCTFail("pas de vidéo")
        }
        guard let premiere = rendu.instants.first else { return XCTFail("déroulé vide") }
        XCTAssertGreaterThanOrEqual(premiere.pointsDessines, 1)
        XCTAssertEqual(premiere.secondes, 0, accuracy: 0.001)
    }

    /// LA DERNIÈRE IMAGE EST CELLE QU'ON REGARDE. Le rognage arrête le trait trois cents mètres
    /// avant l'arrivée : laisser les compteurs s'arrêter là afficherait « 9,7 km » au bout d'un
    /// dix kilomètres, sur l'image précisément faite pour être vue.
    func testLaDerniereImagePorteLesChiffresDeLaCourse() {
        let run = dixKilometres(splits: splitsAvecCote, denivele: 240) { i in 35 + Double(i % 40) }
        guard let rendu = RunVideoTimeline.pour(run, images: 120) else {
            return XCTFail("pas de vidéo")
        }
        guard let derniere = rendu.instants.last else { return XCTFail("déroulé vide") }
        XCTAssertEqual(derniere.metres, 10000, accuracy: 0.001)
        XCTAssertEqual(derniere.secondes, 3000, accuracy: 0.001)
        XCTAssertEqual(derniere.pointsDessines, rendu.route.count)
        XCTAssertEqual(derniere.denivelePositifM ?? -1, 240, accuracy: 0.001)
    }

    // MARK: Les distances et le dénivelé

    func testLesDistancesCumuleesPartentDeZeroEtMontent() {
        let route = ligneDroite(points: 101, pas: 10)
        let cumul: [Double] = RunVideoTimeline.distancesCumulees(route)
        XCTAssertEqual(cumul.count, route.count)
        XCTAssertEqual(cumul[0], 0, accuracy: 0.001)
        for (avant, apres) in zip(cumul, cumul.dropFirst()) {
            XCTAssertGreaterThan(apres, avant)
        }
        // Mille mètres annoncés, à la tolérance de la haversine sur une ligne de latitude.
        // Le pas est calculé avec 111 320 m par degré de longitude ; la haversine en compte
        // 111 195 — mille mètres nominaux en font 998,9 de vrais. La tolérance couvre cet écart
        // sans couvrir une erreur de projection.
        XCTAssertEqual(cumul[cumul.count - 1], 1000, accuracy: 3)
    }

    /// Le dénivelé intermédiaire suit le MÊME calcul que partout — `ElevationGain`, sa bande
    /// morte et son lissage — et se tait quand il n'y a pas de quoi le dire. Un chiffre tiré de
    /// trois points serait un autre chiffre faux, pas une approximation.
    func testLeDeniveleSeTaitQuandIlNYAPasDeQuoiLeDire() {
        // Moins de dix altitudes connues sur tout le tracé.
        let presqueSansAltitude = ligneDroite(points: 101, pas: 10) { i in i < 5 ? 35 : nil }
        XCTAssertNil(RunVideoTimeline.denivelesCumules(presqueSansAltitude, intervalleSecondes: 3))

        // Une vraie montée : le dénivelé doit monter, et ne jamais redescendre.
        let montee = ligneDroite(points: 201, pas: 10) { i in 35 + Double(i) * 0.5 }
        guard let cumul = RunVideoTimeline.denivelesCumules(montee, intervalleSecondes: 3) else {
            return XCTFail("200 altitudes connues doivent suffire")
        }
        XCTAssertEqual(cumul.count, montee.count)
        for (avant, apres) in zip(cumul, cumul.dropFirst()) {
            XCTAssertGreaterThanOrEqual(apres, avant)
        }
        XCTAssertGreaterThan(cumul[cumul.count - 1], 50, "une montée de 100 m doit se voir")
    }
}
