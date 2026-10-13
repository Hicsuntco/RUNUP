import XCTest
import SwiftData
@testable import RunUp

// MARK: - Les maquettes

// AU NIVEAU DU FICHIER, et pas imbriquées dans la classe de tests : la macro `@Model` produit
// une extension et des accesseurs, et la faire porter sur un type imbriqué ferait dépendre la
// compilation d'un détail de la macro. Ce fichier est là pour mesurer, pas pour parier.

/// `RunRecord` tel qu'il est aujourd'hui, réduit à ce qui compte pour la mesure : les quelques
/// champs que les écrans lisent vraiment, et le tracé rangé dans la ligne.
@Model
final class BancCourseEnLigne {
    var date: Date
    var distanceKm: Double
    var durationSeconds: Int
    var route: [RunRecord.RoutePoint] = []

    init(date: Date, distanceKm: Double, durationSeconds: Int, route: [RunRecord.RoutePoint]) {
        self.date = date
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.route = route
    }
}

/// La même, avec le tracé sorti de la ligne. UNE SEULE DIFFÉRENCE entre les deux maquettes,
/// pour que la mesure ne puisse rien dire d'autre que ce qu'on lui demande.
@Model
final class BancCourseExterne {
    var date: Date
    var distanceKm: Double
    var durationSeconds: Int
    @Attribute(.externalStorage) var route: [RunRecord.RoutePoint] = []

    init(date: Date, distanceKm: Double, durationSeconds: Int, route: [RunRecord.RoutePoint]) {
        self.date = date
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.route = route
    }
}

// MARK: - Le banc

/// LE BANC D'ESSAI QUI DÉCIDE SI LA MIGRATION DES TRACÉS VAUT SON PRIX.
///
/// # LA QUESTION
///
/// `RunRecord.route` est un tableau de points GPS rangé DANS la ligne de la course. `LocationService`
/// ne pose aucun `distanceFilter` et demande `kCLLocationAccuracyBest`, donc il arrive environ un
/// point par seconde : une sortie de 45 minutes en porte ~2 500, un marathon ~10 000. Et douze
/// écrans lisent l'historique ENTIER à chaque affichage — kilométrage des chaussures, records
/// personnels, badges, série : aucun ne peut se contenter d'une fenêtre récente.
///
/// Chaque ouverture des stats relit donc des millions de coordonnées dont elle n'a aucun usage.
/// `@Attribute(.externalStorage)` est censé sortir ce blob de la ligne et le laisser sur le disque
/// jusqu'à ce qu'on le demande vraiment.
///
/// # POURQUOI CE FICHIER NE TOUCHE PAS AU VRAI MODÈLE
///
/// Déplacer le stockage d'une propriété d'un `@Model` est un aller SANS RETOUR : il faut geler le
/// schéma d'aujourd'hui, en écrire un second, et poser une étape de migration entre les deux (la
/// marche à suivre est en tête de `RunUpSchemaV1`). Une migration qui échoue chez quelqu'un ne se
/// répare par aucune mise à jour — la donnée, elle, ne revient pas en arrière.
///
/// Payer ça sans savoir si le gain existe serait un pari. Les deux `@Model` ci-dessous sont donc
/// des MAQUETTES, visibles de ce seul fichier de tests, qui reproduisent la forme de `RunRecord`
/// avec et sans stockage externe. Elles répondent aux deux seules questions qui décident de la
/// suite :
///
///   1. SwiftData sait-il faire ça sur un tableau encodé — ou seulement sur du `Data` ? C'est le
///      cas « SwiftData ne sait pas faire ça », et il doit échouer ICI, dans un dossier temporaire,
///      et pas sur son téléphone.
///   2. Le gain en lecture est-il réel, et assez grand pour valoir le gel du schéma ?
///
/// La règle de décision est écrite dans `testLeGainEnLectureJustifieLaMigration` : le stockage
/// externe doit diviser au moins par deux le coût de lecture de l'historique. En dessous, la
/// migration ne vaut pas son risque, et ce test le dira en échouant avec les deux mesures.
final class TraceExterneTests: XCTestCase {

    // MARK: Des tracés qui ressemblent aux vrais

    /// Un tracé plausible : des coordonnées qui avancent, et une altitude parfois absente — c'est
    /// le cas réel (voir `RoutePoint.altitude`, nil quand la précision verticale n'est pas fiable).
    /// Des valeurs toutes identiques se compresseraient autrement qu'un vrai parcours.
    private func trace(points: Int, graine: Int) -> [RunRecord.RoutePoint] {
        var sortie: [RunRecord.RoutePoint] = []
        sortie.reserveCapacity(points)
        var lat = 48.85 + Double(graine) * 0.001
        var lng = 2.35 + Double(graine) * 0.001
        for i in 0..<points {
            lat += Double((i * 7 + graine) % 13) * 0.000_01
            lng += Double((i * 11 + graine) % 17) * 0.000_01
            sortie.append(.init(lat: lat, lng: lng,
                                altitude: i % 5 == 0 ? nil : 30 + Double(i % 80)))
        }
        return sortie
    }

    /// Un dossier à soi, supprimé à la fin. Un magasin EN MÉMOIRE ne mesurerait rien : c'est
    /// justement la lecture du disque qu'on soupèse, et le stockage externe n'existe que là.
    private func dossierTemporaire() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("trace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func magasin(_ schema: Schema, _ url: URL) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
    }

    // MARK: 1. SwiftData sait-il faire ça ?

    func testUnTraceExterneSeRelitAuPointPres() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent("externe.store")
        let schema = Schema([BancCourseExterne.self])

        let originaux = (0..<12).map { trace(points: 2_000, graine: $0) }

        // Écrit, enregistré, PUIS le conteneur est relâché : relire depuis le même conteneur ne
        // prouverait rien, le cache de lignes rendrait les objets sans toucher au disque.
        do {
            let contexte = ModelContext(try magasin(schema, fichier))
            for (i, t) in originaux.enumerated() {
                contexte.insert(BancCourseExterne(date: Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400),
                                              distanceKm: 8 + Double(i), durationSeconds: 2_700, route: t))
            }
            try contexte.save()
        }

        let relu = ModelContext(try magasin(schema, fichier))
        let courses = try relu.fetch(FetchDescriptor<BancCourseExterne>(
            sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(courses.count, 12, "Les lignes elles-mêmes ne se relisent pas.")
        for (i, course) in courses.enumerated() {
            XCTAssertEqual(course.route.count, 2_000, "Tracé \(i) tronqué.")
            XCTAssertEqual(course.route.first, originaux[i].first, "Tracé \(i) : premier point.")
            XCTAssertEqual(course.route.last, originaux[i].last, "Tracé \(i) : dernier point.")
            // `XCTAssertTrue` et non `XCTAssertEqual` sur les tableaux entiers : l'égalité est la
            // même, mais un échec d'`XCTAssertEqual` imprimerait les 4 000 points des deux côtés,
            // et c'est l'annotation de la tâche qui porte le message — la seule qu'on puisse lire.
            XCTAssertTrue(course.route == originaux[i],
                          "Tracé \(i) altéré par le stockage externe, hors premier et dernier point.")
        }
    }

    // MARK: 2. Le gain existe-t-il ?

    /// Le coût de ce que font vraiment les écrans : relire tout l'historique et n'y lire QUE des
    /// nombres — kilomètres, durées, dates. Jamais le tracé.
    ///
    /// Un conteneur neuf à chaque mesure, et la plus BASSE des trois : une machine de CI est
    /// partagée, donc une mesure isolée ne vaut rien, alors que le minimum de plusieurs passages
    /// approche le coût réel sans que le bruit ne puisse le faire baisser.
    private func coutDeLecture<T: PersistentModel>(
        _ type: T.Type, _ schema: Schema, _ fichier: URL, _ somme: (T) -> Double
    ) throws -> TimeInterval {
        var meilleur = TimeInterval.greatestFiniteMagnitude
        for _ in 0..<3 {
            let contexte = ModelContext(try magasin(schema, fichier))
            let depart = Date()
            let lignes = try contexte.fetch(FetchDescriptor<T>())
            let total = lignes.reduce(0) { $0 + somme($1) }
            meilleur = min(meilleur, Date().timeIntervalSince(depart))
            XCTAssertGreaterThan(total, 0, "La mesure n'a rien lu — elle ne mesure rien.")
        }
        return meilleur
    }

    func testLeGainEnLectureJustifieLaMigration() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        // 150 sorties de 2 500 points : l'historique d'un an et demi à quatre sorties par semaine,
        // à la cadence réelle d'un point par seconde. Une taille que son téléphone atteindra.
        let courses = 150, points = 2_500

        let schemaEnLigne = Schema([BancCourseEnLigne.self])
        let fichierEnLigne = dossier.appendingPathComponent("enligne.store")
        let schemaExterne = Schema([BancCourseExterne.self])
        let fichierExterne = dossier.appendingPathComponent("externe.store")

        do {
            let a = ModelContext(try magasin(schemaEnLigne, fichierEnLigne))
            let b = ModelContext(try magasin(schemaExterne, fichierExterne))
            for i in 0..<courses {
                let t = trace(points: points, graine: i)
                let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400)
                a.insert(BancCourseEnLigne(date: date, distanceKm: 8 + Double(i % 20),
                                       durationSeconds: 2_700, route: t))
                b.insert(BancCourseExterne(date: date, distanceKm: 8 + Double(i % 20),
                                       durationSeconds: 2_700, route: t))
            }
            try a.save()
            try b.save()
        }

        let enLigne = try coutDeLecture(BancCourseEnLigne.self, schemaEnLigne, fichierEnLigne) { $0.distanceKm }
        let externe = try coutDeLecture(BancCourseExterne.self, schemaExterne, fichierExterne) { $0.distanceKm }
        // Une mesure nulle rendrait un rapport NaN, et `XCTAssertLessThan(NaN, 0.5)` échoue en
        // accusant le stockage externe de ce qui serait un défaut de la mesure.
        XCTAssertGreaterThan(enLigne, 0, "La mesure de référence est nulle : rien n'a été mesuré.")
        let rapport = externe / enLigne

        // LA RÈGLE DE DÉCISION, et l'échec est ici une RÉPONSE, pas une panne : si le stockage
        // externe ne divise pas au moins par deux le coût de lecture, la migration — gel du
        // schéma, étape de migration, aller sans retour sur les données de tout le monde — ne
        // vaut pas son risque, et il faut chercher le gain ailleurs (une fenêtre sur
        // l'historique, un total de kilométrage entretenu, un `propertiesToFetch`).
        //
        // Les deux mesures sont dans le message parce que c'est la seule façon de les lire : les
        // journaux de tâche ne sont pas téléchargeables, les échecs de test le sont.
        XCTAssertLessThan(
            rapport, 0.5,
            String(format: """
            Le stockage externe ne gagne pas assez pour justifier la migration. \
            %ld courses × %ld points : en ligne %.3f s, externe %.3f s, rapport %.2f. \
            Attendu : moins de 0,50.
            """, courses, points, enLigne, externe, rapport)
        )
    }
}
