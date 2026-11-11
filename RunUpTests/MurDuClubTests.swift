import XCTest
@testable import RunUp

/// Les trois règles du mur du Club.
///
/// # POURQUOI CE FICHIER EXISTE
///
/// Elles vivaient en propriétés privées d'une vue de 1 400 lignes : vérifiables seulement en
/// ouvrant l'écran du Club avec les bonnes données — un message, sa réponse, une sortie du même
/// jour — c'est-à-dire jamais. Elles sont pures, donc elles n'avaient aucune raison d'être là.
///
/// Chacune porte une décision qui n'était écrite nulle part, et dont la disparition ne casse
/// rien : le fil se remplit simplement de répliques orphelines, ou se met à se lire à l'envers.
final class MurDuClubTests: XCTestCase {

    // MARK: Fabriquer des données qui décodent vraiment

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Décodé plutôt que construit à la main : `ClubPost` vient du serveur, et une fixture écrite
    /// avec un `init` mémberwise cesserait de ressembler à ce que l'app reçoit vraiment.
    private func message(_ id: String, parent: String? = nil, le jour: Int) throws -> ClubPost {
        let parentJSON = parent.map { "\"\($0)\"" } ?? "null"
        let json = """
        { "id": "\(id)", "parentId": \(parentJSON), "text": "coucou",
          "createdAt": "2026-11-\(String(format: "%02d", jour))T08:00:00Z",
          "kudos": 0, "kudoedByMe": false, "isMine": false,
          "author": { "id": "1", "name": "Inès", "isPrivate": false } }
        """
        return try decoder().decode(ClubPost.self, from: Data(json.utf8))
    }

    private func sortie(_ id: String, le jour: Int) throws -> FeedItem {
        let json = """
        { "id": "\(id)", "userId": "1", "name": "Inès", "text": "a couru 10 km",
          "createdAt": "2026-11-\(String(format: "%02d", jour))T08:00:00Z",
          "isPersonalRecord": false, "kudos": 0, "kudoedByMe": false,
          "commentsCount": 0, "kudosNames": [] }
        """
        return try decoder().decode(FeedItem.self, from: Data(json.utf8))
    }

    // MARK: 1. On ne publie pas du vide, et pas deux fois

    @MainActor
    func testUnBrouillonVideNePeutPasPartir() {
        let mur = MurDuClub()
        XCTAssertFalse(mur.peutPublier)
    }

    /// LE CAS QUI SE PERD EN SIMPLIFIANT. `isEmpty` seul laisse passer trois retours à la ligne,
    /// et le club reçoit un message vide que personne ne peut supprimer d'un geste évident.
    @MainActor
    func testUnBrouillonQuiNEstQueDesEspacesEtDesRetoursNePeutPasPartir() {
        let mur = MurDuClub()
        for vide in [" ", "   ", "\n", " \n \n ", "\t"] {
            mur.brouillon = vide
            XCTAssertFalse(mur.peutPublier, "« \(vide.debugDescription) » est passé pour un message")
        }
    }

    @MainActor
    func testUnBrouillonEcritPeutPartir() {
        let mur = MurDuClub()
        mur.brouillon = "On se voit dimanche ?"
        XCTAssertTrue(mur.peutPublier)
    }

    /// Pendant l'aller-retour, le bouton s'éteint : deux appuis ne doivent pas publier deux fois.
    @MainActor
    func testOnNePublieToujoursPasPendantQueLEnvoiEstEnCours() {
        let mur = MurDuClub()
        mur.brouillon = "On se voit dimanche ?"
        mur.envoiEnCours = true
        XCTAssertFalse(mur.peutPublier)
    }

    // MARK: 2. Les entrées du fil

    /// LA DÉCISION LA MOINS VISIBLE DES DEUX, et celle qu'un remaniement fait disparaître sans
    /// rien casser : une réponse n'entre PAS dans le fil, elle s'affiche sous son message. Sans
    /// ce filtre, le fil se remplit de répliques qui n'ont plus de question au-dessus d'elles.
    func testUneReponseNEntrePasDansLeFil() throws {
        let entrees = MurDuClub.entrees(
            sorties: [],
            messages: [try message("m1", le: 10), try message("r1", parent: "m1", le: 11)])
        XCTAssertEqual(entrees.map(\.id), ["m-m1"])
    }

    /// ENTRELACÉS PAR DATE, PAS EMPILÉS EN DEUX LISTES. Un mur posé au-dessus des sorties se lit
    /// comme une annonce épinglée ; mêlés, un message de lundi et une sortie de lundi se répondent.
    func testLesSortiesEtLesMessagesSEntrelacentParDate() throws {
        let entrees = MurDuClub.entrees(
            sorties: [try sortie("s1", le: 12), try sortie("s2", le: 9)],
            messages: [try message("m1", le: 11), try message("m2", le: 8)])
        XCTAssertEqual(entrees.map(\.id), ["s-s1", "m-m1", "s-s2", "m-m2"],
                       "le fil n'est plus trié par date, ou les deux listes se sont re-empilées")
    }

    func testLeFilVaDuPlusRecentAuPlusAncien() throws {
        let entrees = MurDuClub.entrees(sorties: [], messages: [
            try message("vieux", le: 1), try message("neuf", le: 28), try message("milieu", le: 14),
        ])
        XCTAssertEqual(entrees.map(\.id), ["m-neuf", "m-milieu", "m-vieux"])
    }

    func testUnFilSansRienEstVide() {
        XCTAssertTrue(MurDuClub.entrees(sorties: [], messages: []).isEmpty)
    }

    // MARK: 3. Les réponses

    func testSeulesLesReponsesDeCeMessageRemontent() throws {
        let messages = [try message("m1", le: 10), try message("m2", le: 10),
                        try message("r1", parent: "m1", le: 11),
                        try message("r2", parent: "m2", le: 11)]
        XCTAssertEqual(MurDuClub.reponses(a: try message("m1", le: 10), dans: messages).map(\.id),
                       ["r1"])
    }

    /// L'ORDRE EST L'INVERSE DE CELUI DU FIL, ET C'EST VOULU.
    ///
    /// Un fil se lit du plus récent au plus ancien parce qu'on vient voir les nouvelles ; une
    /// conversation se lit dans l'ordre où elle s'est tenue. Deux tris opposés sur le même écran
    /// est exactement le genre d'écart qu'on « corrige » en croyant bien faire.
    func testLesReponsesVontDuPlusAncienAuPlusRecent() throws {
        let messages = [try message("m1", le: 1),
                        try message("tard", parent: "m1", le: 20),
                        try message("tot", parent: "m1", le: 2),
                        try message("milieu", parent: "m1", le: 10)]
        XCTAssertEqual(MurDuClub.reponses(a: try message("m1", le: 1), dans: messages).map(\.id),
                       ["tot", "milieu", "tard"])
    }

    func testUnMessageSansReponseNEnARien() throws {
        XCTAssertTrue(MurDuClub.reponses(a: try message("m1", le: 10),
                                         dans: [try message("m1", le: 10)]).isEmpty)
    }
}
