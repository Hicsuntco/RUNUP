import XCTest
@testable import RunUp

/// Verrouille la règle qui rend le fil du club lisible dans les trois langues.
///
/// Le serveur renvoie une phrase déjà rédigée — « a couru 8,2 km · Sortie longue » — composée sur
/// l'appareil de celle qui a posté, DANS SA LANGUE. Une app vendue en français, anglais et
/// espagnol servait donc un fil français à ses lectrices anglophones, jusque dans le titre de
/// séance. `FeedItem.localizedText` refabrique cette phrase chez la lectrice à partir de
/// `contentKey`.
///
/// Ces tests n'affirment aucune chaîne en dur : ils comparent au `String(localized:)` calculé ici
/// même, donc ils disent la même chose quelle que soit la langue dans laquelle ils tournent. Ce
/// qu'ils verrouillent, c'est le CHOIX — recomposer quand on le peut, retomber sur le texte du
/// serveur quand on ne le peut pas — et surtout le fait qu'on ne retombe jamais silencieusement
/// sur une phrase figée alors qu'on avait de quoi faire mieux.
final class FeedLocalizationTests: XCTestCase {

    // MARK: - Fixture

    /// Une ligne de fil telle que `api/activities/feed` la renvoie. Passer par le vrai décodeur
    /// plutôt que par un initialiseur mémoire teste au passage la tolérance de `FeedItem` aux
    /// clés absentes — celle qui évite qu'un serveur pas encore déployé vide le fil entier.
    private func feedItem(text: String,
                          contentKey: String? = nil,
                          distanceKm: Double? = nil) throws -> FeedItem {
        var row: [String: Any] = [
            "id": "11111111-1111-1111-1111-111111111111",
            "userId": "22222222-2222-2222-2222-222222222222",
            "name": "Charlotte",
            "text": text,
            "createdAt": "2026-08-26T10:00:00Z",
            "kudos": 0,
            "kudoedByMe": false,
            "commentsCount": 0,
        ]
        if let contentKey { row["contentKey"] = contentKey }
        if let distanceKm { row["distanceKm"] = distanceKm }
        let data = try JSONSerialization.data(withJSONObject: row)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FeedItem.self, from: data)
    }

    // MARK: - Ce qui peut être recomposé l'est

    func testRunWithDistanceIsRebuiltFromTheContentKey() throws {
        let item = try feedItem(text: "a couru 8,2 km · Sortie longue",
                                contentKey: SessionKind.longRun.rawValue,
                                distanceKm: 8.2)
        let expectedTitle = String(localized: String.LocalizationValue(SessionKind.longRun.titleKey))
        let distance = String(format: "%.1f", locale: Locale.current, 8.2)

        XCTAssertEqual(item.localizedText,
                       String(localized: "a couru \(distance) km · \(expectedTitle)"))
        // La distance est reformatée avec la locale de la lectrice : une Anglaise doit lire
        // « 8.2 », pas le « 8,2 » figé par la Française qui a posté.
        XCTAssertTrue(item.localizedText.contains(distance))
    }

    /// Une séance sans GPS (HYROX, renfo, « marquer comme faite ») : pas de distance à annoncer.
    /// La phrase change de forme, elle ne se contente pas d'omettre un chiffre — « a couru 0,0 km »
    /// ferait passer une absence de mesure pour une mesure.
    func testSessionWithoutDistanceUsesTheOtherSentence() throws {
        let item = try feedItem(text: "a fait sa séance · Renforcement",
                                contentKey: SessionKind.hyroxTechnique.rawValue)
        let expectedTitle = String(localized: String.LocalizationValue(SessionKind.hyroxTechnique.titleKey))
        XCTAssertEqual(item.localizedText, String(localized: "a fait sa séance · \(expectedTitle)"))
    }

    /// Le seuil est celui de `DebriefSheet` : sous 50 m, il n'y a pas de distance réelle.
    func testNegligibleDistanceIsTreatedAsNoDistance() throws {
        let item = try feedItem(text: "peu importe",
                                contentKey: SessionKind.easyFooting.rawValue,
                                distanceKm: 0.02)
        let expectedTitle = String(localized: String.LocalizationValue(SessionKind.easyFooting.titleKey))
        XCTAssertEqual(item.localizedText, String(localized: "a fait sa séance · \(expectedTitle)"))
    }

    func testDailyGoalsBadgeIsRebuilt() throws {
        let item = try feedItem(text: "a bouclé ses 3 objectifs du jour", contentKey: "daily_goals")
        XCTAssertEqual(item.localizedText, String(localized: "a bouclé ses 3 objectifs du jour"))
    }

    /// Tous les types de séance doivent produire un titre traduit, pas la clé brute. Un
    /// `session.<kind>.title` absent du catalogue ressortirait tel quel dans le fil — visible
    /// nulle part ailleurs, puisque cet écran n'existe que pour les autres.
    func testEverySessionKindHasATranslatedTitle() throws {
        for kind in SessionKind.allCases {
            let title = String(localized: String.LocalizationValue(kind.titleKey))
            XCTAssertNotEqual(title, kind.titleKey,
                              "session.\(kind.rawValue).title manque au catalogue de traduction")
        }
    }

    // MARK: - Ce qui ne peut pas l'être retombe sur le serveur

    /// Une activité postée avant l'existence de `content_key`. Elle reste en français pour tout le
    /// monde — c'est la limite acceptée, et la phrase de son autrice vaut infiniment mieux qu'une
    /// carte vide.
    func testActivityWithoutContentKeyKeepsTheServerSentence() throws {
        let item = try feedItem(text: "a couru 8,2 km · Sortie longue", distanceKm: 8.2)
        XCTAssertEqual(item.localizedText, "a couru 8,2 km · Sortie longue")
    }

    /// Une clé qu'une version plus récente de l'app aurait introduite, lue par une plus ancienne.
    /// Le repli doit être le texte du serveur, jamais une phrase à trous ni la clé elle-même.
    func testUnknownContentKeyFallsBackInsteadOfShowingTheKey() throws {
        let item = try feedItem(text: "a couru 5,0 km · Une séance inconnue",
                                contentKey: "une_seance_du_futur",
                                distanceKm: 5)
        XCTAssertEqual(item.localizedText, "a couru 5,0 km · Une séance inconnue")
    }
}
