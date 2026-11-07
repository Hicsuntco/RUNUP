import XCTest
import CoreLocation
@testable import RunUp

/// Verrouille l'algorithme qui décide la DISTANCE DE CHAQUE COURSE.
///
/// `LocationService.consomme` porte trois règles que son fichier explique longuement et que rien
/// ne vérifiait — elles étaient inatteignables depuis l'extérieur du fichier :
///
///   · le **plancher de bruit** refuse un déplacement plus petit que la précision annoncée. Il
///     est né d'un défaut mesuré : à un point par seconde sur vingt-cinq minutes, le tremblement
///     d'un fix immobile ajoutait un vrai **+2 km à une course de 4 km**. Une règle qui corrige
///     une erreur de cinquante pour cent sans aucun test est une règle qu'on perdra ;
///   · le **saut à plus de 12 m/s** (≈ 1:23 au kilomètre) coupe le segment après une perte de
///     signal, au lieu de compter la ligne droite d'un tunnel ;
///   · le **seuil de confiance à 65 mètres** écarte un fix dont on ne sait rien.
///
/// Les trois se trompent en SILENCE : la course s'enregistre, l'app n'a pas l'air cassée, et le
/// chiffre est faux. C'est la mesure sur laquelle une coureuse juge tout le reste.
@MainActor
final class LocationServiceTests: XCTestCase {

    /// Un point de référence à Paris, et un cap vers l'est pour que la latitude ne bouge pas :
    /// un degré de longitude y vaut environ 73 km, ce qui rend les calculs lisibles.
    private let depart = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)

    /// Un fix à `metres` mètres à l'est du départ, `secondes` après le début.
    private func fix(metres: Double, secondes: Double, precision: CLLocationAccuracy = 5,
                     precisionVerticale: CLLocationAccuracy = 5, altitude: Double = 35,
                     vitesse: CLLocationSpeed = 3) -> CLLocation {
        let parDegre = 111_320.0 * cos(depart.latitude * .pi / 180)
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: depart.latitude,
                                               longitude: depart.longitude + metres / parDegre),
            altitude: altitude,
            horizontalAccuracy: precision,
            verticalAccuracy: precisionVerticale,
            course: 90,
            speed: vitesse,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000 + secondes)
        )
    }

    // MARK: - Le plancher de bruit

    /// LE TREMBLEMENT D'UN FIX IMMOBILE NE PRODUIT PAS DE DISTANCE.
    ///
    /// Soixante points qui vont et viennent de six mètres, sous un plancher de huit : c'est le
    /// défaut qui ajoutait +2 km à une course de 4 km, en vingt-cinq minutes de signal dégradé.
    func testLeTremblementDUnFixImmobileNeProduitAucuneDistance() {
        let service = LocationService()
        for i in 0..<60 {
            service.consomme([fix(metres: i.isMultiple(of: 2) ? 0 : 6, secondes: Double(i))])
        }
        XCTAssertEqual(service.distanceMeters, 0, accuracy: 0.001,
                       "le bruit a été compté comme de la distance")
    }

    /// Et un déplacement RÉEL, au-dessus du plancher, compte entièrement.
    func testUnDeplacementAuDessusDuPlancherCompteEntierement() {
        let service = LocationService()
        for i in 0..<10 {
            service.consomme([fix(metres: Double(i) * 20, secondes: Double(i) * 5)])
        }
        XCTAssertEqual(service.distanceMeters, 180, accuracy: 2)
    }

    /// LE PLANCHER SUIT LA PRÉCISION ANNONCÉE, ET IL COÛTE LA QUEUE DU TRAJET — PAS LE TRAJET.
    ///
    /// # MON PREMIER TEST ICI AFFIRMAIT ZÉRO, ET IL AVAIT TORT
    ///
    /// J'avais écrit que dix pas de vingt mètres à vingt-cinq mètres de précision ne comptent
    /// rien, puisque chaque pas est sous le plancher. C'est faux, et le test juste au-dessus le
    /// disait déjà : le plancher NE MET PAS À JOUR `lastLocation`, donc les pas écartés
    /// s'additionnent jusqu'à franchir le seuil. Deux pas de vingt font quarante, quarante
    /// dépasse vingt-cinq, et quarante sont comptés.
    ///
    /// J'avais donc écrit deux tests qui se contredisaient, et c'est la construction qui m'a dit
    /// lequel des deux mentait.
    ///
    /// # CE QUE LE PLANCHER COÛTE VRAIMENT
    ///
    /// Sur un trajet en ligne droite, un signal flou mesure la même chose qu'un signal net, à
    /// UNE FENÊTRE DE COMPARAISON PRÈS : les derniers mètres, ceux qui n'ont pas eu le temps
    /// d'atteindre le seuil avant la fin, sont perdus. 180 mètres parcourus donnent 180 à cinq
    /// mètres de précision et 160 à vingt-cinq.
    ///
    /// Ce n'est pas le trajet qu'il écarte, ce sont les détours : un fix qui part et revient dans
    /// le rayon de sa propre imprécision n'ajoute rien, et c'est exactement ce qu'on lui demande.
    func testLePlancherSuitLaPrecisionAnnonceeEtCouteLaQueueDuTrajet() {
        let flou = LocationService()
        let net = LocationService()
        for i in 0..<10 {
            flou.consomme([fix(metres: Double(i) * 20, secondes: Double(i) * 5, precision: 25)])
            net.consomme([fix(metres: Double(i) * 20, secondes: Double(i) * 5, precision: 5)])
        }
        XCTAssertEqual(net.distanceMeters, 180, accuracy: 2, "le signal net doit tout mesurer")
        XCTAssertEqual(flou.distanceMeters, 160, accuracy: 3,
                       "le signal flou perd une fenêtre de comparaison, pas le trajet")
        XCTAssertLessThan(flou.distanceMeters, net.distanceMeters)
    }

    /// Un déplacement lent mais réel finit par compter : il se mesure contre le dernier fix
    /// RETENU, pas contre le précédent écarté, donc il ne perd pas quelques mètres à chaque pas.
    func testUnDeplacementLentFinitParCompterEnEntier() {
        let service = LocationService()
        // Trois mètres par seconde de MESURE, sous le plancher de huit à chaque pas isolé.
        for i in 0..<10 {
            service.consomme([fix(metres: Double(i) * 3, secondes: Double(i))])
        }
        // 27 mètres parcourus : les pas sous le plancher s'accumulent contre le dernier retenu,
        // donc on compte 9 m, 9 m, 9 m — pas zéro, et pas 27 d'un coup.
        XCTAssertEqual(service.distanceMeters, 27, accuracy: 3)
    }

    // MARK: - Le saut après une perte de signal

    /// UN TUNNEL NE PRODUIT PAS UNE LIGNE DROITE DE DEUX KILOMÈTRES.
    ///
    /// Le fix retrouvé après une coupure arrive comme un bond unique dont la vitesse implicite
    /// n'est atteinte par aucun coureur. Il n'est ni compté, ni retenu comme référence : le point
    /// suivant se compare au dernier bon fix, pas au mauvais.
    func testUnSautPlusRapideQueDouzeMetresParSecondeNEstPasCompte() {
        let service = LocationService()
        service.consomme([fix(metres: 0, secondes: 0)])
        service.consomme([fix(metres: 100, secondes: 10)])     // 10 m/s, plausible
        service.consomme([fix(metres: 2100, secondes: 20)])    // 200 m/s, le tunnel
        XCTAssertEqual(service.distanceMeters, 100, accuracy: 2,
                       "la ligne droite du tunnel a été comptée")
    }

    /// Et le point d'APRÈS le saut se compare au dernier bon fix, donc il ne rattrape pas le
    /// tunnel par la fenêtre.
    func testLePointSuivantUnSautSeCompareAuDernierBonFix() {
        let service = LocationService()
        service.consomme([fix(metres: 0, secondes: 0)])
        service.consomme([fix(metres: 2000, secondes: 10)])   // écarté
        service.consomme([fix(metres: 50, secondes: 20)])     // 50 m depuis le point 0, en 20 s
        XCTAssertEqual(service.distanceMeters, 50, accuracy: 2)
    }

    // MARK: - Le seuil de confiance

    func testUnFixSansPrecisionConnueEstIgnore() {
        let service = LocationService()
        service.consomme([fix(metres: 0, secondes: 0)])
        service.consomme([fix(metres: 100, secondes: 10, precision: -1)])
        service.consomme([fix(metres: 200, secondes: 20, precision: 80)])
        XCTAssertEqual(service.distanceMeters, 0, accuracy: 0.001)
        XCTAssertEqual(service.route.count, 1, "un fix douteux est entré dans le tracé")
    }

    /// `hasFix` ne vaut vrai qu'une fois un point exploitable arrivé : sans lui, l'écran ne peut
    /// pas distinguer « l'app cherche » de « l'app est cassée ».
    func testHasFixNEstVraiQuApresUnPointExploitable() {
        let service = LocationService()
        XCTAssertFalse(service.hasFix)
        service.consomme([fix(metres: 0, secondes: 0, precision: -1)])
        XCTAssertFalse(service.hasFix, "un fix sans précision a été pris pour un signal")
        service.consomme([fix(metres: 0, secondes: 1)])
        XCTAssertTrue(service.hasFix)
    }

    // MARK: - La vitesse inconnue n'est pas un arrêt

    /// `CLLocation.speed` vaut une valeur NÉGATIVE quand l'appareil ne la connaît pas — le cas
    /// des premiers points de chaque course. La rendre à 0 ferait croire à la pause automatique
    /// que la coureuse est arrêtée.
    func testUneVitesseInconnueResteInconnueEtNonZero() {
        let service = LocationService()
        service.consomme([fix(metres: 0, secondes: 0, vitesse: -1)])
        XCTAssertNil(service.currentSpeedMetersPerSecond,
                     "« je ne sais pas » a été rendu en « 0 m/s », donc en « elle est à l'arrêt »")
        service.consomme([fix(metres: 20, secondes: 5, vitesse: 4)])
        XCTAssertEqual(service.currentSpeedMetersPerSecond ?? -1, 4, accuracy: 0.001)
    }

    // MARK: - La pause

    /// PENDANT UNE PAUSE, RIEN NE S'ACCUMULE — mais on continue de mesurer l'éloignement.
    ///
    /// C'est ce qui permet de repartir sans dépendre d'une vitesse que l'appareil ne sait pas
    /// toujours donner : à l'arrêt, sous un immeuble, `speed` devient justement indisponible.
    func testPendantUnePauseRienNeSAccumuleMaisLEloignementSeMesure() {
        let service = LocationService()
        service.consomme([fix(metres: 0, secondes: 0)])
        service.consomme([fix(metres: 100, secondes: 20)])
        let avant = service.distanceMeters
        service.pauseAccumulation()
        service.consomme([fix(metres: 120, secondes: 30)])
        service.consomme([fix(metres: 160, secondes: 40)])
        XCTAssertEqual(service.distanceMeters, avant, accuracy: 0.001,
                       "la pause a laissé passer de la distance")
        XCTAssertEqual(service.metersSincePause, 40, accuracy: 3,
                       "l'éloignement depuis le point d'arrêt n'est pas mesuré")
    }

    /// Et la REPRISE ne jette pas un pont par-dessus la pause : si elle a marché deux cents
    /// mètres pendant l'arrêt, ces mètres ne sont pas de la course.
    func testLaRepriseNeJettePasDePontParDessusLaPause() {
        let service = LocationService()
        service.consomme([fix(metres: 0, secondes: 0)])
        service.consomme([fix(metres: 100, secondes: 20)])
        service.pauseAccumulation()
        service.consomme([fix(metres: 300, secondes: 60)])   // elle a marché pendant la pause
        service.resume()
        service.consomme([fix(metres: 320, secondes: 70)])
        service.consomme([fix(metres: 420, secondes: 90)])
        XCTAssertEqual(service.distanceMeters, 200, accuracy: 3,
                       "les deux cents mètres de la pause sont entrés dans la course")
    }

    // MARK: - Le tracé et ses altitudes

    /// Les deux tableaux restent de la même longueur, index par index : le profil d'élévation les
    /// lit en parallèle, et un décalage y placerait une montée au mauvais kilomètre.
    func testLeTraceEtSesAltitudesRestentAlignes() {
        let service = LocationService()
        for i in 0..<12 {
            service.consomme([fix(metres: Double(i) * 20, secondes: Double(i) * 5,
                                  precisionVerticale: i.isMultiple(of: 3) ? 40 : 4,
                                  altitude: 35 + Double(i))])
        }
        XCTAssertEqual(service.route.count, service.routeAltitudes.count)
        XCTAssertGreaterThan(service.route.count, 8)
        // Une altitude dont la précision verticale dépasse le seuil vaut `nil`, pas une valeur
        // inventée — sinon le profil dessinerait une montée qu'on n'a pas mesurée.
        XCTAssertTrue(service.routeAltitudes.contains(where: { $0 == nil }))
    }

    /// Un lot de plusieurs fixes — ce que la livraison en arrière-plan envoie — compte TOUS ses
    /// points et pas seulement le dernier, sinon chaque virage se coupe en ligne droite.
    func testUnLotCompteTousSesPointsEtPasSeulementLeDernier() {
        let parPoint = LocationService()
        let parLot = LocationService()
        let points = (0..<10).map { fix(metres: Double($0) * 20, secondes: Double($0) * 5) }
        for p in points { parPoint.consomme([p]) }
        parLot.consomme(points)
        XCTAssertEqual(parLot.distanceMeters, parPoint.distanceMeters, accuracy: 0.001)
        XCTAssertEqual(parLot.route.count, parPoint.route.count)
    }
}
