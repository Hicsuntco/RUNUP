import XCTest
import SwiftData
@testable import RunUp

// MARK: - Les maquettes

// AU NIVEAU DU FICHIER, et pas imbriquées dans la classe de tests : la macro `@Model` produit
// une extension et des accesseurs, et la faire porter sur un type imbriqué ferait dépendre la
// compilation d'un détail de la macro. Ce fichier est là pour mesurer, pas pour parier.
//
// Les quatre maquettes ne diffèrent que par le rangement du tracé, et ne portent que les champs
// que les écrans lisent vraiment. Aucune ne touche à un modèle réel : c'est ce qui permet de
// répondre sans rien engager.

/// `RunRecord` tel qu'il est aujourd'hui : le tableau de points rangé DANS la ligne.
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

/// La même avec `.externalStorage` sur le tableau — LA FORME QUI NE MARCHE PAS. Voir
/// `testLeStockageExterneEstSansEffetSurUnTableauEncode`.
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

/// Le tracé encodé à la main en `Data`, rangé dans la ligne. Le témoin de la paire ci-dessous.
@Model
final class BancCourseBlobEnLigne {
    var date: Date
    var distanceKm: Double
    var durationSeconds: Int
    var traceEncodee: Data = Data()

    init(date: Date, distanceKm: Double, durationSeconds: Int, traceEncodee: Data) {
        self.date = date
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.traceEncodee = traceEncodee
    }
}

/// Le même `Data`, hors de la ligne. UNE SEULE DIFFÉRENCE avec le témoin — l'attribut — et
/// exactement les mêmes octets de part et d'autre, pour que la mesure ne puisse rien dire
/// d'autre que ce qu'on lui demande.
@Model
final class BancCourseBlobExterne {
    var date: Date
    var distanceKm: Double
    var durationSeconds: Int
    @Attribute(.externalStorage) var traceEncodee: Data = Data()

    init(date: Date, distanceKm: Double, durationSeconds: Int, traceEncodee: Data) {
        self.date = date
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.traceEncodee = traceEncodee
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
/// récente. L'hypothèse était que chaque ouverture des stats relisait des millions de coordonnées
/// dont elle n'a aucun usage.
///
/// # LA PREMIÈRE RÉPONSE, ET LE PIÈGE QU'ELLE CACHAIT (builds 266-267)
///
/// `@Attribute(.externalStorage)` posé sur `[RoutePoint]` compile, le schéma se matérialise, les
/// tracés se relisent au point près — et **ne sort rien de la ligne du tout**. Zéro octet dans
/// `_EXTERNAL_DATA`, et les deux magasins pèsent le même nombre d'octets, 23 506 944 de part et
/// d'autre. L'attribut est ignoré en silence sur un attribut qui n'est pas du `Data`.
///
/// Le build 266 avait donc mesuré DEUX MAGASINS IDENTIQUES, et son « rapport de 0,88 » n'était
/// que le bruit de la machine. La conclusion tombait juste, la mesure ne valait rien, et les deux
/// se ressemblaient assez pour qu'on s'en contente. C'est la vérification sur le disque ajoutée
/// au build 267 — `_EXTERNAL_DATA`, et le poids réel des fichiers — qui a fait la différence
/// entre « le gain n'existe pas » et « on n'a rien mesuré ».
///
/// # LA VRAIE MESURE
///
/// Faite sur la paire qui, elle, fonctionne : le même tracé encodé en `Data`, dans la ligne puis
/// hors de la ligne, aux mêmes octets près. 150 sorties de 2 500 points — 375 000 coordonnées,
/// un an et demi à quatre sorties par semaine — puis le coût de ce que font vraiment les écrans :
/// relire tout l'historique et n'y lire que des nombres.
///
/// Et le chiffre qui décide est le coût TOTAL, tracés compris : **19 ms** pour relire ces 150
/// lignes depuis un magasin de 23 Mo. Même si les tracés en représentaient la totalité, les
/// sortir de la ligne ne rendrait que 19 ms sur un geste qui en a 16 pour paraître instantané.
///
/// # LA DÉCISION
///
/// Pas de migration. Elle demandait de geler le schéma d'aujourd'hui (cinq modèles, 124
/// propriétés), d'en écrire un second et de poser une étape entre les deux — un aller sans retour
/// qu'aucune mise à jour ne répare chez quelqu'un dont la donnée, elle, ne revient pas en
/// arrière. Et pour l'obtenir il aurait d'abord fallu changer `route` en `Data`, puisque
/// l'attribut ne mord pas sur un tableau. Tout ça pour un gain qui ne peut pas dépasser 19 ms.
///
/// # CE QUE CE FICHIER GARDE
///
///   1. LE PIÈGE : `.externalStorage` est sans effet sur un attribut encodé. Ce n'est écrit nulle
///      part, ça ne prévient pas, et la donnée se relit parfaitement — donc rien ne le signale.
///      Le test le fixe, et échouera le jour où Apple le corrigera : on le saura au lieu de le
///      supposer.
///   2. Que relire tout l'historique est bon marché, et doit le rester. Le plafond du dernier
///      test est large exprès : il n'est pas là pour mesurer, il est là pour attraper le jour où
///      lire l'historique coûtera une seconde — et ce jour-là, ce fichier dira tout de suite si
///      les tracés y sont pour quelque chose.
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

    // MARK: Ce que le disque dit

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
    /// Zéro veut dire que rien n'est sorti de la ligne, quoi que l'attribut ait annoncé.
    private func poidsDesBlobsExternes(_ dossier: URL) -> Int {
        guard let marche = FileManager.default.enumerator(
            at: dossier, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
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

    // MARK: 1. Le tracé se relit, et c'est tout ce que ça prouve

    func testUnTraceSeRelitAuPointPresMalgreLAttribut() throws {
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
                contexte.insert(BancCourseExterne(
                    date: Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400),
                    distanceKm: 8 + Double(i), durationSeconds: 2_700, route: t))
            }
            try contexte.save()
        }

        let relu = ModelContext(try magasin(schema, fichier))
        let courses = try relu.fetch(FetchDescriptor<BancCourseExterne>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(courses.count, 12, "Les lignes elles-mêmes ne se relisent pas.")
        for (i, course) in courses.enumerated() {
            XCTAssertEqual(course.route.count, 2_000, "Tracé \(i) tronqué.")
            XCTAssertEqual(course.route.first, originaux[i].first, "Tracé \(i) : premier point.")
            XCTAssertEqual(course.route.last, originaux[i].last, "Tracé \(i) : dernier point.")
            // `XCTAssertTrue` et non `XCTAssertEqual` sur les tableaux entiers : l'égalité est la
            // même, mais un échec d'`XCTAssertEqual` imprimerait les 4 000 points des deux côtés,
            // et c'est l'annotation de la tâche qui porte le message — la seule qu'on puisse lire.
            XCTAssertTrue(course.route == originaux[i],
                          "Tracé \(i) altéré, hors premier et dernier point.")
        }
        // ET C'EST TOUT CE QUE ÇA PROUVE. Ce test passait déjà au build 266, où l'attribut ne
        // sortait rien de la ligne : une donnée qui se relit parfaitement ne dit rien de l'endroit
        // où elle est rangée. C'est précisément ce qui a failli faire conclure sur une mesure vide.
    }

    // MARK: 2. Le piège : l'attribut ne mord pas sur un tableau encodé

    func testLeStockageExterneEstSansEffetSurUnTableauEncode() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }
        let courses = 40, points = 2_500

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

        // LE CONSTAT, FIXÉ POUR QU'IL NE SE REDÉCOUVRE PAS. Si ce test se met à échouer, c'est
        // une BONNE nouvelle : Apple aura corrigé le comportement, et sortir un tableau encodé
        // d'une ligne redeviendra possible sans passer par du `Data`. À relire alors en entier.
        XCTAssertEqual(poidsDesBlobsExternes(dossier), 0,
                       "`.externalStorage` sort maintenant un tableau encodé de la ligne — "
                       + "relire l'en-tête de ce fichier, le piège qu'il décrit n'existe plus.")
        XCTAssertEqual(try poidsDuMagasin(fichierExterne), try poidsDuMagasin(fichierEnLigne),
                       "Les deux magasins ne pèsent plus la même chose : l'attribut a commencé à agir.")
    }

    // MARK: 3. La vraie mesure, sur la paire qui fonctionne

    func testRelireLHistoriqueResteBonMarcheDansLesDeuxRangements() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        // 150 sorties de 2 500 points : l'historique d'un an et demi à quatre sorties par semaine,
        // à la cadence réelle d'un point par seconde. Une taille que son téléphone atteindra.
        let courses = 150, points = 2_500

        let schemaEnLigne = Schema([BancCourseBlobEnLigne.self])
        let fichierEnLigne = dossier.appendingPathComponent("blob-enligne.store")
        let schemaExterne = Schema([BancCourseBlobExterne.self])
        let fichierExterne = dossier.appendingPathComponent("blob-externe.store")

        let encodeur = JSONEncoder()
        do {
            let a = ModelContext(try magasin(schemaEnLigne, fichierEnLigne))
            let b = ModelContext(try magasin(schemaExterne, fichierExterne))
            for i in 0..<courses {
                // LES MÊMES OCTETS DES DEUX CÔTÉS. Deux encodages distincts, même d'un même
                // tableau, laisseraient planer un doute sur ce que la mesure compare.
                let octets = try encodeur.encode(trace(points: points, graine: i))
                let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400)
                a.insert(BancCourseBlobEnLigne(date: date, distanceKm: 8 + Double(i % 20),
                                               durationSeconds: 2_700, traceEncodee: octets))
                b.insert(BancCourseBlobExterne(date: date, distanceKm: 8 + Double(i % 20),
                                               durationSeconds: 2_700, traceEncodee: octets))
            }
            try a.save()
            try b.save()
        }

        // D'ABORD : LE BLOB A-T-IL VRAIMENT QUITTÉ LA LIGNE ? Sans ça, la comparaison de temps
        // qui suit ne mesurerait rien — c'est l'erreur du build 266, et elle ne se voit pas.
        let blobs = poidsDesBlobsExternes(dossier)
        let poidsEnLigne = try poidsDuMagasin(fichierEnLigne)
        let poidsExterne = try poidsDuMagasin(fichierExterne)
        XCTAssertGreaterThan(blobs, 1_000_000,
                             "Rien dans `_EXTERNAL_DATA` : même sur du `Data`, l'attribut n'agit pas. "
                             + "La mesure qui suit ne comparerait que deux magasins identiques. Blobs \(blobs) o.")
        XCTAssertLessThan(poidsExterne, poidsEnLigne / 2,
                          "Le magasin externe n'a pas maigri : \(poidsExterne) o contre \(poidsEnLigne) o.")

        // ENSUITE : EST-CE QUE ÇA CHANGE QUELQUE CHOSE ? Le plafond est volontairement LARGE. Il
        // ne mesure pas, il garde : relire tout l'historique sans toucher aux tracés doit rester
        // bon marché, et le jour où ça coûtera une seconde, ce test le dira — avec, juste à côté,
        // de quoi savoir si les tracés y sont pour quelque chose.
        let enLigne = try coutDeLecture(BancCourseBlobEnLigne.self, schemaEnLigne, fichierEnLigne) { $0.distanceKm }
        let externe = try coutDeLecture(BancCourseBlobExterne.self, schemaExterne, fichierExterne) { $0.distanceKm }

        XCTAssertLessThan(enLigne, 1.0, String(format:
            "Relire %ld courses × %ld points coûte %.3f s avec le tracé dans la ligne.", courses, points, enLigne))
        XCTAssertLessThan(externe, 1.0, String(format:
            "Relire %ld courses × %ld points coûte %.3f s avec le tracé hors de la ligne.", courses, points, externe))
    }
}
