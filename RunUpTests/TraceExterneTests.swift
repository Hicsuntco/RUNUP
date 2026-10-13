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

/// CE QUI A ÉTÉ MESURÉ, ET POURQUOI LA MIGRATION DES TRACÉS N'A PAS EU LIEU.
///
/// # LA QUESTION
///
/// `RunRecord.route` est un tableau de points GPS rangé DANS la ligne de la course.
/// `LocationService` ne pose aucun `distanceFilter` et demande `kCLLocationAccuracyBest`, donc il
/// arrive environ un point par seconde : une sortie de 45 minutes en porte ~2 500, un marathon
/// ~10 000. Et douze écrans relisent l'historique ENTIER à chaque affichage — kilométrage des
/// chaussures, records personnels, badges, série : aucun ne peut se contenter d'une fenêtre
/// récente. L'hypothèse était donc que chaque ouverture des stats relisait des millions de
/// coordonnées dont elle n'a aucun usage, et que `@Attribute(.externalStorage)` les sortirait de
/// la ligne.
///
/// # LA MESURE (build 266)
///
/// 150 sorties de 2 500 points — 375 000 coordonnées, un an et demi à quatre sorties par semaine
/// — dans deux magasins sur disque, puis le coût de ce que font vraiment les écrans : relire tout
/// l'historique et n'y lire que des nombres.
///
///     en ligne  0,019 s        externe  0,016 s        rapport 0,88
///
/// **Dix-neuf millisecondes.** Et le stockage externe n'en reprend que trois. Le blob quitte bien
/// la ligne — le test ci-dessous le vérifie sur le disque, fichier par fichier — et ça ne change
/// presque rien : lire `distanceKm` sur 150 lignes ne paie pas les tracés, quoi qu'on ait supposé.
/// L'hypothèse était fausse, pas insuffisante.
///
/// Et la conclusion ne dépend même pas du rapport : **19 ms est le coût TOTAL** de la lecture,
/// tracés compris. Même si les tracés en représentaient la totalité, les retirer de la ligne ne
/// rendrait que 19 ms sur un geste qui en a 16 pour paraître instantané. Il n'y a rien à gagner
/// là, quelle que soit la part qui leur revient.
///
/// # LA DÉCISION
///
/// Pas de migration. Elle demandait de geler le schéma d'aujourd'hui (cinq modèles, 124
/// propriétés), d'en écrire un second et de poser une étape entre les deux — un aller sans retour
/// qu'aucune mise à jour ne répare chez quelqu'un dont la donnée, elle, ne revient pas en
/// arrière. Pour trois millisecondes.
///
/// # CE QUE CE FICHIER GARDE
///
/// Deux choses, et c'est pour ça qu'il n'est pas supprimé avec la question qui l'a fait naître :
///
///   1. `@Attribute(.externalStorage)` FONCTIONNE sur un tableau encodé, et pas seulement sur du
///      `Data` — ce n'était pas écrit nulle part, et c'est utile le jour où un vrai blob (une
///      photo, une vidéo) devra sortir d'une ligne chaude.
///   2. Relire tout l'historique est bon marché, et doit le rester. Le plafond du second test est
///      large exprès : il n'est pas là pour mesurer, il est là pour attraper le jour où lire
///      l'historique coûtera une seconde — et ce jour-là, ce fichier dira tout de suite si les
///      tracés y sont pour quelque chose.
///
/// Les deux maquettes ci-dessus ne touchent à aucun modèle réel : c'est ce qui a permis de
/// répondre sans rien parier.
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

    // MARK: 2. Le blob quitte-t-il la ligne, et est-ce que ça change quelque chose ?

    /// Le poids réel du magasin : le fichier SQLite ET ses journaux. Sans le `-wal`, un magasin
    /// qui n'a pas encore été consolidé paraîtrait vide et la comparaison dirait n'importe quoi.
    private func poidsDuMagasin(_ fichier: URL) throws -> Int {
        let dossier = fichier.deletingLastPathComponent()
        let prefixe = fichier.lastPathComponent
        return try FileManager.default.contentsOfDirectory(atPath: dossier.path)
            .filter { $0.hasPrefix(prefixe) }
            .reduce(0) { total, nom in
                let u = dossier.appendingPathComponent(nom)
                guard (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == false
                else { return total }
                return total + ((try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
    }

    /// Le poids de ce que Core Data a posé À CÔTÉ du magasin, dans son dossier `_EXTERNAL_DATA`.
    private func poidsDesBlobsExternes(_ dossier: URL) -> Int {
        guard let marche = FileManager.default.enumerator(at: dossier,
                                                          includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total = 0
        for cas in marche {
            guard let u = cas as? URL, u.path.contains("_EXTERNAL_DATA") else { continue }
            total += (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        }
        return total
    }

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

    func testLeStockageExterneSortLeBlobDeLaLigneSansChangerLeCoutDeLecture() throws {
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

        // D'ABORD : LE BLOB A-T-IL VRAIMENT QUITTÉ LA LIGNE ?
        //
        // Sans cette vérification, la comparaison de temps qui suit ne vaudrait rien : si
        // SwiftData avait ignoré l'attribut, les deux magasins seraient identiques et le rapport
        // mesuré ne dirait rien d'autre que le bruit de la machine. C'est la différence entre
        // « le gain n'existe pas » et « on n'a rien mesuré », et les deux se ressemblent.
        let blobs = poidsDesBlobsExternes(dossier)
        let poidsEnLigne = try poidsDuMagasin(fichierEnLigne)
        let poidsExterne = try poidsDuMagasin(fichierExterne)
        XCTAssertGreaterThan(
            blobs, 1_000_000,
            "Rien dans `_EXTERNAL_DATA` : SwiftData a ignoré `.externalStorage` sur un tableau encodé, "
            + "donc la comparaison de temps ci-dessous ne mesure rien. Blobs \(blobs) o.")
        XCTAssertLessThan(
            poidsExterne, poidsEnLigne / 2,
            "Le magasin externe n'a pas maigri : \(poidsExterne) o contre \(poidsEnLigne) o en ligne.")

        // ENSUITE : EST-CE QUE ÇA CHANGE QUELQUE CHOSE ? Non — 0,019 s contre 0,016 s au build
        // 266, soit un rapport de 0,88. Le plafond ci-dessous est volontairement LARGE : il ne
        // mesure pas, il garde. Lire tout l'historique sans toucher aux tracés doit rester bon
        // marché, et le jour où ça coûtera une seconde, ce test le dira — avec, juste à côté, la
        // preuve que les tracés n'y sont pour rien.
        let enLigne = try coutDeLecture(BancCourseEnLigne.self, schemaEnLigne, fichierEnLigne) { $0.distanceKm }
        let externe = try coutDeLecture(BancCourseExterne.self, schemaExterne, fichierExterne) { $0.distanceKm }

        XCTAssertLessThan(enLigne, 1.0, String(format:
            "Relire %ld courses × %ld points coûte %.3f s avec les tracés dans la ligne.", courses, points, enLigne))
        XCTAssertLessThan(externe, 1.0, String(format:
            "Relire %ld courses × %ld points coûte %.3f s avec les tracés hors de la ligne.", courses, points, externe))
    }
}
