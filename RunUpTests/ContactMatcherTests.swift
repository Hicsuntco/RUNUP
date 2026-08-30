import XCTest
@testable import RunUp

/// Verrouille l'empreinte d'une adresse e-mail.
///
/// Ces valeurs ne sont pas décoratives : ce sont celles que Postgres produit de son côté, avec
/// `encode(digest(lower(btrim(email)), 'sha256'), 'hex')` sur la colonne générée
/// `users.email_sha256`. Deux normalisations qui divergeraient — une majuscule laissée, un espace
/// gardé — ne lèveraient aucune erreur : la recherche dans les contacts ne trouverait simplement
/// jamais personne, et rien n'indiquerait pourquoi. C'est la panne la plus coûteuse à diagnostiquer
/// de tout ce montage, et la seule qu'un test peut rendre impossible.
final class ContactMatcherTests: XCTestCase {

    /// Minuscules et espaces de bord retirés, exactement comme `lower(btrim(...))`.
    func testHashMatchesThePostgresNormalisation() {
        XCTAssertEqual(
            ContactMatcher.hash(email: "  Charlotte@Example.COM "),
            "0136c661f132c126599053dc8f78ddd5fb558d26119c2edceebe01a013001db8"
        )
        XCTAssertEqual(
            ContactMatcher.hash(email: "test@runup.app"),
            "5df724cf48b4b3e91d02723c5d1b4a5beaa05facedcfe37bc47d56b26b07256f"
        )
    }

    /// La casse et les espaces ne doivent jamais produire deux empreintes différentes.
    func testCaseAndWhitespaceDoNotChangeTheFingerprint() {
        let reference = ContactMatcher.hash(email: "test@runup.app")
        XCTAssertEqual(ContactMatcher.hash(email: "TEST@RUNUP.APP"), reference)
        XCTAssertEqual(ContactMatcher.hash(email: "\n test@Runup.app  "), reference)
    }

    /// Ce qui n'est pas une adresse ne part pas.
    ///
    /// Un carnet d'adresses contient des champs « e-mail » remplis avec autre chose — un pseudo,
    /// une note, une chaîne vide. Les hacher ne trouverait rien et ferait sortir du téléphone des
    /// empreintes de données qui n'ont rien à y faire.
    func testNonAddressesAreRejected() {
        XCTAssertNil(ContactMatcher.hash(email: ""))
        XCTAssertNil(ContactMatcher.hash(email: "   "))
        XCTAssertNil(ContactMatcher.hash(email: "Charlotte"))
    }

    /// L'empreinte fait bien 64 caractères hexadécimaux — le format que le serveur exige et
    /// refuse d'interpréter autrement, pour qu'une adresse en clair ne puisse jamais passer.
    func testFingerprintIsLowercaseHexOfTheRightLength() {
        let hash = ContactMatcher.hash(email: "test@runup.app")
        XCTAssertEqual(hash?.count, 64)
        XCTAssertEqual(hash, hash?.lowercased())
        XCTAssertTrue(hash?.allSatisfy { $0.isHexDigit } == true)
    }
}
