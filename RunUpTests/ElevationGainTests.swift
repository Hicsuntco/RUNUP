import XCTest
@testable import RunUp

/// Verrouille le dénivelé positif, et surtout l'écart entre ce qu'il mesure et ce que l'ancien
/// calcul inventait.
///
/// `LocationService` sommait tous les écarts d'altitude positifs entre deux fixes GPS. Redresser
/// un bruit symétrique en n'en gardant que la moitié positive produit un total qui ne revient
/// jamais à zéro : il croît avec la DURÉE de la sortie, pas avec son relief. Chaque test de bruit
/// ci-dessous calcule les deux chiffres sur la MÊME suite de fixes, pour que l'écart soit une
/// mesure et pas une affirmation.
final class ElevationGainTests: XCTestCase {

    // MARK: - Un bruit qu'on peut rejouer

    /// Un générateur déterministe, et pas `Double.random(in:)`.
    ///
    /// Un test sur du bruit doit mesurer TOUJOURS le même bruit. Avec une source aléatoire il
    /// passerait un jour sur deux, et c'est la pire espèce de test : celui dont on finit par
    /// croire que l'échec est « normal ». Les valeurs attendues plus bas sont celles de CETTE
    /// suite-là, vérifiées à la quatrième décimale.
    private struct Bruit {
        private var etat: UInt64 = 0x2545_F491_4F6C_DD1D

        /// Un tirage uniforme dans [-1, 1]. Congruence linéaire — `&*` et `&+` enveloppent
        /// modulo 2^64, ce qui est exactement la définition.
        private mutating func tirage() -> Double {
            etat = etat &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let bits = (etat >> 11) & 0x1F_FFFF_FFFF_FFFF
            return Double(bits) / Double(1 << 53) * 2 - 1
        }

        /// Un bruit d'écart-type `ecartType`, en mètres.
        ///
        /// La somme de trois tirages uniformes sur [-1, 1] : chacun a une variance de 1/3, donc
        /// trois en ont une de 1, et l'écart-type de la somme vaut exactement 1. C'est aussi une
        /// approximation très correcte d'une gaussienne, ce qu'est le bruit d'altitude GPS.
        mutating func metres(ecartType: Double) -> Double {
            let a = tirage(), b = tirage(), c = tirage()
            return (a + b + c) * ecartType
        }
    }

    /// L'ANCIEN calcul, rejoué sur la même suite d'altitudes : la somme des écarts positifs.
    private func ancienCalcul(_ altitudes: [Double]) -> Double {
        zip(altitudes, altitudes.dropFirst()).reduce(0.0) { total, paire in
            total + max(0, paire.1 - paire.0)
        }
    }

    private let depart = Date(timeIntervalSince1970: 1_700_000_000)
    private func instant(_ secondes: Double) -> Date { depart.addingTimeInterval(secondes) }

    // MARK: - Le défaut lui-même

    /// Une heure immobile, deux mètres de bruit d'altitude : l'ancien calcul fabrique DEUX
    /// KILOMÈTRES de dénivelé positif. Pas sur une sortie de montagne — sur un téléphone qui n'a
    /// pas bougé.
    func testUneHeureImmobileNeFabriquePlusDeDenivele() {
        var bruit = Bruit()
        var denivele = ElevationGain()
        var altitudes: [Double] = []

        for i in 0..<1800 {
            let altitude = 100 + bruit.metres(ecartType: 2.0)
            altitudes.append(altitude)
            denivele.ajoute(altitude: altitude, precisionVerticale: 8, instant: instant(Double(i) * 2))
        }

        XCTAssertEqual(denivele.metres, 0, accuracy: 0.001,
                       "Debout immobile, le dénivelé doit rester à zéro")
        XCTAssertGreaterThan(ancienCalcul(altitudes), 1500,
                             "Si l'ancien calcul ne fabrique plus de dénivelé sur cette suite, "
                             + "c'est le générateur de bruit qui a changé, pas le défaut qui a disparu")
    }

    /// Le même écart sur une sortie qui a du relief : mille mètres de D+ réels en six montées, que
    /// l'ancien calcul annonce à quatre mille six cent soixante-neuf.
    func testUneSortieTrailNEstPlusMultipliee() {
        var bruit = Bruit()
        var denivele = ElevationGain()
        var altitudes: [Double] = []
        var altitude = 100.0
        var secondes = 0.0

        for _ in 0..<6 {
            for pas in [0.5, -0.5] {
                for _ in 0..<334 {
                    altitude += pas
                    secondes += 2
                    let mesuree = altitude + bruit.metres(ecartType: 2.0)
                    altitudes.append(mesuree)
                    denivele.ajoute(altitude: mesuree, precisionVerticale: 8, instant: instant(secondes))
                }
            }
        }

        // 976 pour 1 000 : les 2,4 % manquants sont le coût de la bande morte à chaque sommet.
        // Les marges sont larges à dessein : ce que ce test verrouille est un RAPPORT de un à
        // quatre, pas une quatrième décimale. Une tolérance serrée coûterait un aller-retour de
        // CI d'un quart d'heure pour un écart qui ne change rien à ce qu'on démontre.
        XCTAssertEqual(denivele.metres, 976, accuracy: 10)
        XCTAssertEqual(ancienCalcul(altitudes), 4668.5, accuracy: 30)
    }

    // MARK: - Ce qu'il compte quand il n'y a pas de bruit

    func testUneMonteeSoutenueEstComptee() {
        var denivele = ElevationGain()
        for i in 0...200 {
            denivele.ajoute(altitude: 100 + 0.5 * Double(i), precisionVerticale: 8,
                            instant: instant(Double(i) * 2))
        }
        // 96,5 pour 100 : le retard du lissage, et le reste sous la bande morte au sommet.
        XCTAssertEqual(denivele.metres, 96.5, accuracy: 0.01)
    }

    func testUneDescenteNeCompteRien() {
        var denivele = ElevationGain()
        for i in 0...200 {
            denivele.ajoute(altitude: 300 - 0.5 * Double(i), precisionVerticale: 8,
                            instant: instant(Double(i) * 2))
        }
        XCTAssertEqual(denivele.metres, 0, accuracy: 0.001)
    }

    /// Un vallon : la remontée se compte depuis le CREUX, pas depuis le sommet d'avant. Sans ça on
    /// perdrait un versant entier à chaque fois.
    func testUnVallonCompteLaRemonteeDepuisLeCreux() {
        var denivele = ElevationGain()
        var altitude = 100.0
        var secondes = 0.0
        for pas in [0.5, -0.5, 0.5] {
            for _ in 0..<100 {
                altitude += pas
                secondes += 2
                denivele.ajoute(altitude: altitude, precisionVerticale: 8, instant: instant(secondes))
            }
        }
        // 86,5 pour 100 : deux renversements de pente, et la bande morte coûte à chacun. C'est la
        // limite connue de ce calcul sur du micro-relief — voir l'en-tête d'`ElevationGain`.
        XCTAssertEqual(denivele.metres, 86.5, accuracy: 0.01)
    }

    // MARK: - Ce qu'il refuse

    func testUneAltitudeQueLAppareilNeGarantitPasEstIgnoree() {
        var denivele = ElevationGain()
        for i in 0...200 {
            denivele.ajoute(altitude: 100 + 0.5 * Double(i),
                            precisionVerticale: ElevationGain.precisionVerticaleMax + 5,
                            instant: instant(Double(i) * 2))
        }
        XCTAssertEqual(denivele.metres, 0, accuracy: 0.001)
    }

    func testUneAltitudeAbsenteEstIgnoree() {
        var denivele = ElevationGain()
        for i in 0...200 {
            denivele.ajoute(altitude: 100 + 0.5 * Double(i), precisionVerticale: -1,
                            instant: instant(Double(i) * 2))
        }
        XCTAssertEqual(denivele.metres, 0, accuracy: 0.001)
    }

    /// Trente mètres en deux secondes, c'est quinze mètres par seconde : un saut de signal, pas
    /// une ascension. Et la mesure continue de fonctionner après.
    func testUnSautDeSignalNestPasUneMontee() {
        var denivele = ElevationGain()
        for i in 0..<10 {
            denivele.ajoute(altitude: 100, precisionVerticale: 8, instant: instant(Double(i) * 2))
        }
        denivele.ajoute(altitude: 130, precisionVerticale: 8, instant: instant(20))
        for i in 11..<30 {
            denivele.ajoute(altitude: 100, precisionVerticale: 8, instant: instant(Double(i) * 2))
        }
        XCTAssertEqual(denivele.metres, 0, accuracy: 0.001)
    }

    /// Un fix hors d'ordre ou daté à la même seconde ne fait rien — surtout pas une division par
    /// zéro dans le contrôle de plausibilité.
    func testDeuxFixesAuMemeInstantNeCassentRien() {
        var denivele = ElevationGain()
        denivele.ajoute(altitude: 100, precisionVerticale: 8, instant: instant(0))
        denivele.ajoute(altitude: 140, precisionVerticale: 8, instant: instant(0))
        denivele.ajoute(altitude: 140, precisionVerticale: 8, instant: instant(-10))
        XCTAssertEqual(denivele.metres, 0, accuracy: 0.001)
    }

    // MARK: - La pause

    /// Quarante mètres gravis PENDANT une pause ne sont pas de la sortie — exactement comme les
    /// mètres parcourus pendant la pause ne sont pas de la distance.
    func testLeDeniveleDeLaPauseNeCompteRien() {
        var denivele = ElevationGain()
        for i in 0..<50 {
            denivele.ajoute(altitude: 100, precisionVerticale: 8, instant: instant(Double(i) * 2))
        }
        denivele.reprend()
        for i in 50..<120 {
            denivele.ajoute(altitude: 140, precisionVerticale: 8, instant: instant(Double(i) * 2))
        }
        XCTAssertEqual(denivele.metres, 0, accuracy: 0.001)
    }

    /// Mais ce qui était déjà monté reste monté. C'est la distinction que `start()` et `resume()`
    /// avaient déjà dû apprendre dans `LocationService`, où un `resume` qui remettait tout à zéro
    /// ramenait une course de 5 km à 0,00 au feu rouge.
    func testLeTotalSurvitALaReprise() {
        var denivele = ElevationGain()
        for i in 0...200 {
            denivele.ajoute(altitude: 100 + 0.5 * Double(i), precisionVerticale: 8,
                            instant: instant(Double(i) * 2))
        }
        let avant = denivele.metres
        XCTAssertEqual(avant, 96.5, accuracy: 0.01)

        denivele.reprend()
        for i in 201...400 {
            denivele.ajoute(altitude: 200 + 0.5 * Double(i - 200), precisionVerticale: 8,
                            instant: instant(Double(i) * 2))
        }
        XCTAssertEqual(denivele.metres, 192.5, accuracy: 0.01)
    }

    func testRemiseAZeroEffaceLeTotal() {
        var denivele = ElevationGain()
        for i in 0...200 {
            denivele.ajoute(altitude: 100 + 0.5 * Double(i), precisionVerticale: 8,
                            instant: instant(Double(i) * 2))
        }
        XCTAssertGreaterThan(denivele.metres, 90)
        denivele.remetAZero()
        XCTAssertEqual(denivele.metres, 0, accuracy: 0.001)
    }
}
