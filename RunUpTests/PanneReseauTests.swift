import XCTest
@testable import RunUp

/// « Vérifie ta connexion » ne doit plus jamais s'afficher sur un téléphone au wifi plein.
///
/// Onze écrans attrapaient les erreurs des trois services par un `catch` nu ou un `try?`, puis
/// affirmaient tous la même panne. Or les trois causes ont des remèdes opposés : se reconnecter,
/// attendre, ou changer d'endroit. Ces tests tiennent la classification — et la tiennent sur
/// `cause(de:)` plutôt que sur les phrases, parce que les phrases sont traduites et que le
/// simulateur de l'intégration continue tourne EN ANGLAIS (voir `FeedLocalizationTests`).
final class PanneReseauTests: XCTestCase {

    private let coupure = URLError(.notConnectedToInternet)

    // MARK: Les trois services disent la même chose de la même panne

    /// Le défaut d'origine : le classificateur ne connaissait qu'une des trois énumérations, donc
    /// une vraie coupure de réseau survenue sur l'authentification ou le coach retombait sur
    /// « RUNUP ne répond pas » — un message qui fait attendre quelqu'un qui n'a qu'à retrouver du
    /// réseau.
    func testUneCoupureDeReseauEstReconnueDansLesTroisServices() {
        XCTAssertEqual(PanneReseau.cause(de: ClubServiceError.network(coupure)), PanneReseau.Cause.reseau)
        XCTAssertEqual(PanneReseau.cause(de: AuthServiceError.network(coupure)), PanneReseau.Cause.reseau)
        XCTAssertEqual(PanneReseau.cause(de: CoachServiceError.network(coupure)), PanneReseau.Cause.reseau)
        // Et une `URLError` nue : tous les appels de l'app ne passent pas par ces trois services.
        XCTAssertEqual(PanneReseau.cause(de: coupure), PanneReseau.Cause.reseau)
    }

    /// 401 et 403 sont les deux seuls codes qui parlent de la session. Les ranger avec le reste
    /// ferait attendre quelqu'un qui n'a qu'à se reconnecter.
    func testSeulsQuatreCentUnEtQuatreCentTroisSontUneSessionExpiree() {
        for code in [401, 403] {
            XCTAssertEqual(PanneReseau.cause(de: ClubServiceError.badResponse(code, "")), PanneReseau.Cause.sessionExpiree, "\(code)")
            XCTAssertEqual(PanneReseau.cause(de: AuthServiceError.badResponse(code, "")), PanneReseau.Cause.sessionExpiree, "\(code)")
            XCTAssertEqual(PanneReseau.cause(de: CoachServiceError.badResponse(code, "")), PanneReseau.Cause.sessionExpiree, "\(code)")
        }
        XCTAssertEqual(PanneReseau.cause(de: ClubServiceError.notSignedIn), PanneReseau.Cause.sessionExpiree)
        XCTAssertEqual(PanneReseau.cause(de: AuthServiceError.notSignedIn), PanneReseau.Cause.sessionExpiree)

        for code in [400, 404, 409, 422, 429, 500, 502, 503] {
            XCTAssertEqual(PanneReseau.cause(de: ClubServiceError.badResponse(code, "")), PanneReseau.Cause.serveur, "\(code)")
            XCTAssertEqual(PanneReseau.cause(de: AuthServiceError.badResponse(code, "")), PanneReseau.Cause.serveur, "\(code)")
        }
    }

    /// Un refus du modèle et une réponse vide arrivent en HTTP 200 : le serveur a répondu. Ce
    /// n'est ni le réseau ni la session, et les deux écrans du coach ont en plus leur propre
    /// phrase pour le refus.
    func testUnRefusDuCoachNEstPasUnePanneDeReseau() {
        XCTAssertEqual(PanneReseau.cause(de: CoachServiceError.refused), PanneReseau.Cause.serveur)
        XCTAssertEqual(PanneReseau.cause(de: CoachServiceError.emptyReply), PanneReseau.Cause.serveur)
    }

    /// Un échec de décodage : le serveur a répondu quelque chose que cette version de l'app ne
    /// sait pas lire. Nommer le réseau enverrait chercher très loin d'où ça se passe.
    func testUneErreurInconnueRetombeSurLeServeurEtJamaisSurLeReseau() {
        struct Inattendue: Error {}
        let decodage = DecodingError.valueNotFound(
            String.self, DecodingError.Context(codingPath: [], debugDescription: "test")
        )
        XCTAssertEqual(PanneReseau.cause(de: Inattendue()), PanneReseau.Cause.serveur)
        XCTAssertEqual(PanneReseau.cause(de: decodage), PanneReseau.Cause.serveur)
    }

    // MARK: L'INVARIANT QUI COMPTE

    /// Aucune panne autre qu'une panne de réseau ne doit produire la phrase du réseau.
    ///
    /// C'est la règle que les onze écrans violaient, et la seule qui se vérifie sans comparer de
    /// texte français : on prend la phrase d'une vraie coupure comme référence, et on exige
    /// qu'aucune autre cause ne la rende.
    func testSeuleUneCoupureProduitLaPhraseDuReseau() {
        let phraseDuReseau = PanneReseau.phrase(pour: coupure)
        let motifDuReseau = PanneReseau.motif(pour: coupure)

        let pannesQuiNeSontPasLeReseau: [Error] = [
            ClubServiceError.notSignedIn,
            ClubServiceError.badResponse(401, ""),
            ClubServiceError.badResponse(500, ""),
            AuthServiceError.notSignedIn,
            AuthServiceError.badResponse(403, ""),
            AuthServiceError.badResponse(502, ""),
            CoachServiceError.refused,
            CoachServiceError.emptyReply,
            CoachServiceError.badResponse(500, "")
        ]
        for panne in pannesQuiNeSontPasLeReseau {
            XCTAssertNotEqual(PanneReseau.phrase(pour: panne), phraseDuReseau,
                              "\(panne) annonce une panne de réseau qui n'existe pas")
            XCTAssertNotEqual(PanneReseau.motif(pour: panne), motifDuReseau,
                              "\(panne) annonce une panne de réseau qui n'existe pas")
        }
    }

    /// Les trois phrases doivent être trois phrases — sinon la distinction ne sert à rien — et
    /// aucune ne doit être vide, ce qui arriverait si une clé manquait au catalogue.
    func testLesTroisPhrasesSontDistinctesEtNonVides() {
        let phrases = [
            PanneReseau.phrase(pour: coupure),
            PanneReseau.phrase(pour: ClubServiceError.badResponse(500, "")),
            PanneReseau.phrase(pour: ClubServiceError.notSignedIn)
        ]
        let motifs = [
            PanneReseau.motif(pour: coupure),
            PanneReseau.motif(pour: ClubServiceError.badResponse(500, "")),
            PanneReseau.motif(pour: ClubServiceError.notSignedIn)
        ]
        XCTAssertEqual(Set(phrases).count, 3, "Deux causes différentes rendent la même phrase")
        XCTAssertEqual(Set(motifs).count, 3, "Deux causes différentes rendent le même motif")
        for texte in phrases + motifs {
            XCTAssertFalse(texte.isEmpty)
        }
    }

    /// Le motif est une subordonnée, pas une phrase : il s'insère derrière un tiret dans « Photo
    /// enregistrée, mais pas encore visible du club — <motif>. » Un point final y produirait deux
    /// points, et une majuscule une phrase qui commence au milieu d'une autre.
    func testLeMotifSInsereDansUnePhraseDejaCommencee() {
        for panne in [ClubServiceError.network(coupure), .badResponse(500, ""), .notSignedIn] {
            let motif = PanneReseau.motif(pour: panne)
            XCTAssertFalse(motif.hasSuffix("."), "« \(motif) » se termine par un point")
            guard let premiere = motif.first else { return XCTFail("motif vide") }
            // `RUNUP` est le nom de l'app : la seule majuscule admise en tête.
            XCTAssertTrue(premiere.isLowercase || motif.hasPrefix("RUNUP"),
                          "« \(motif) » commence par une majuscule")
        }
    }
}
