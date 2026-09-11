import XCTest
@testable import RunUp

/// Le sous-titre RÉELLEMENT affiché.
///
/// Rien ne le testait, et c'est ce qui a permis à toutes les adaptations du moteur de disparaître
/// sans bruit : les tests existants vérifient les durées, les zones et `adjustment`, jamais le
/// texte rendu. Une séance allégée l'était bel et bien — la phrase qui l'expliquait ne s'affichait
/// simplement plus.
final class SessionSubtitleTests: XCTestCase {
    private func seance(kind: SessionKind?, note: String?) -> WorkoutSession {
        var s = WorkoutSession(title: "Footing tranquille", subtitle: "sous-titre enregistré",
                               durationMinutes: 30, pace: "5:30", zone: "Z2", adjustment: nil,
                               kind: kind)
        s.adaptationNote = note
        return s
    }

    /// Le cas qui était cassé : une séance adaptée doit DIRE ce qui a été adapté.
    func testLaNoteDAdaptationEstAffichee() {
        let rendu = seance(kind: .easyFooting, note: "allégé (phase menstruelle)").displaySubtitle
        XCTAssertTrue(rendu.contains("·"), "la note est jointe au sous-titre de base")
        XCTAssertTrue(rendu.count > seance(kind: .easyFooting, note: nil).displaySubtitle.count,
                      "elle ajoute quelque chose, elle ne remplace pas")
    }

    /// Sans adaptation, rien ne change — pas de séparateur orphelin en fin de ligne.
    func testSansNoteLeSousTitreEstInchange() {
        let rendu = seance(kind: .easyFooting, note: nil).displaySubtitle
        XCTAssertFalse(rendu.hasSuffix("·"))
        XCTAssertFalse(rendu.hasSuffix(" "))
        XCTAssertFalse(rendu.isEmpty)
    }

    /// Une séance enregistrée AVANT `kind` n'a que son sous-titre stocké. Elle ne doit pas
    /// devenir muette, et sa note doit quand même s'afficher.
    func testSeanceAncienneGardeSonSousTitre() {
        XCTAssertEqual(seance(kind: nil, note: nil).displaySubtitle, "sous-titre enregistré")
        XCTAssertTrue(seance(kind: nil, note: "impact réduit").displaySubtitle
            .hasPrefix("sous-titre enregistré ·"))
    }

    /// `subtitle` et `adaptationNote` ont deux rôles distincts : le premier décrit la séance, le
    /// second son adaptation. Les remettre dans le même champ est exactement ce qui a fait perdre
    /// le second.
    func testLesDeuxChampsRestentSepares() {
        let s = seance(kind: .easyFooting, note: "impact réduit")
        XCTAssertEqual(s.subtitle, "sous-titre enregistré", "le champ stocké n'est pas réécrit")
        XCTAssertEqual(s.adaptationNote, "impact réduit")
    }
}
