import XCTest
@testable import RunUp

/// Verrouille une ligne d'historique qui se contredisait dans sa propre largeur :
/// « Repos · 7,4 km · 45:18 ».
///
/// Courir un jour de repos est parfaitement normal — c'est même ce que fait la plupart des gens
/// qui suivent un plan. Le relevé prenait pourtant son titre de la séance PRÉVUE, et la séance
/// prévue ce jour-là s'appelle « Repos ».
///
/// La règle existait déjà, à un seul endroit sur quatre : `markTodaySessionDone` écrivait
/// `durationMinutes > 0 ? title : « Séance libre »`. La course au GPS, la montre et la
/// récupération d'une app tuée ne l'avaient pas — et c'est la course au GPS qui produit
/// l'écrasante majorité des relevés. Encore la même vérité écrite une fois sur quatre.
final class RestDayRunTitleTests: XCTestCase {

    private func course(titre: String, kind: SessionKind?) -> RunRecord {
        AdaptivePlanEngine.buildRunRecord(
            title: titre,
            elapsedSeconds: 2718,
            distanceKm: 7.4,
            kcal: 0,
            avgHeartRate: 0,
            sessionKind: kind
        )
    }

    func testUneCourseUnJourDeReposNeSAppellePasRepos() {
        let record = course(titre: "Repos", kind: .rest)
        XCTAssertNotEqual(record.title, "Repos")
        XCTAssertEqual(record.title, String(localized: "Séance libre"))
    }

    /// Le titre est refusé par le TYPE, pas par son texte : la même séance sur un téléphone
    /// anglais arrive ici intitulée « Rest day », et doit être traitée pareil.
    func testLeRefusNeDependPasDeLaLangueDuTitre() {
        XCTAssertEqual(course(titre: "Rest day", kind: .rest).title, String(localized: "Séance libre"))
        XCTAssertEqual(course(titre: "Descanso", kind: .rest).title, String(localized: "Séance libre"))
    }

    func testUneVraieSeanceGardeSonTitre() {
        XCTAssertEqual(course(titre: "Footing tranquille", kind: .easyFooting).title, "Footing tranquille")
        XCTAssertEqual(course(titre: "Sortie longue", kind: .longRun).title, "Sortie longue")
    }

    /// Une course importée ou saisie à la main n'a pas de type de séance. Elle n'a aucune raison
    /// d'être renommée.
    func testSansTypeDeSeanceLeTitreEstIntact() {
        XCTAssertEqual(course(titre: "Course importée", kind: nil).title, "Course importée")
    }

    /// Le type suit bien le relevé : c'est lui que lit le fil du club pour refabriquer sa phrase
    /// dans la langue du lecteur, et c'est lui que la réparation des anciennes courses utilise
    /// comme critère. Il était posé à la main après coup par chaque appelant — une deuxième ligne
    /// à ne pas oublier, pour la même information.
    func testLeTypeDeSeanceEstPoseParLeConstructeur() {
        XCTAssertEqual(course(titre: "Footing tranquille", kind: .easyFooting).sessionKind, .easyFooting)
        XCTAssertEqual(course(titre: "Repos", kind: .rest).sessionKind, .rest)
        XCTAssertNil(course(titre: "Course importée", kind: nil).sessionKind)
    }

    /// Et la séance de repos de référence porte bien le type sur lequel tout ça repose : si elle
    /// le perdait, la règle ci-dessus cesserait silencieusement de s'appliquer.
    func testLaSeanceDeReposPorteBienSonType() {
        XCTAssertEqual(AdaptivePlanEngine.restSession.kind, .rest)
        XCTAssertEqual(AdaptivePlanEngine.restSession.durationMinutes, 0)
    }
}
