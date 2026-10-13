import XCTest
import SwiftData
@testable import RunUp

/// LE FILET DOIT TENIR — et il n'y a qu'une occasion de le vérifier, celle où il sert.
///
/// Une sauvegarde ne se relit jamais le jour où on l'écrit. Elle se relit six mois plus tard, par
/// une autre version de l'app, après que le magasin SwiftData a refusé de s'ouvrir. Tout ce qui
/// peut aller mal à ce moment-là est hors de portée d'un essai à la main ; ces tests sont la
/// seule chose qui s'en approche.
///
/// `ci_scripts/check_sauvegarde.py` tient l'autre moitié : qu'aucune propriété enregistrée ne
/// sorte du filet sans que quelqu'un l'ait écrit.
final class SauvegardeTests: XCTestCase {

    // MARK: Un profil rempli, pour avoir quelque chose à perdre

    private func profilRempli() -> UserProfile {
        let p = UserProfile(name: "Charlotte")
        p.onboarded = true
        p.goalId = .race
        p.level = .confirmee
        p.sex = "female"
        p.birthdate = Date(timeIntervalSince1970: 500_000_000)
        p.goalDisplay = "10 km · 47:30"
        p.raceDistance = .k10
        p.raceChrono = "47:30"
        p.raceDate = Date(timeIntervalSince1970: 1_800_000_000)
        p.volumeActuel = "troisOuQuatre"
        p.plusLongueSortie = "dixAquinze"
        p.allureFooting = "cinqTrente"
        p.tempsSemaineMin = 45
        p.tempsWeekEndMin = 90
        p.terrains = ["route", "piste"]
        p.autresSports = ["velo"]
        p.streak = 37
        p.xp = 4210
        p.weekNumber = 5
        p.weekTier = 3
        p.recentRPESeverities = [1, 2, 1, 3]
        p.seenBadgeKeys = ["premiere_course", "dix_sorties"]
        p.completedDebriefsCount = 42
        p.runningDays = [1, 3, 5, 6]
        p.preferredLongRunDay = 6
        p.accentThemeID = "menthe"
        p.distanceUnit = "km"
        p.avatarImageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        p.weekSessions = [
            PlannedDay(weekday: 1, session: WorkoutSession(
                title: "Fractionné", subtitle: "8 × 400 m", durationMinutes: 50,
                pace: "4:20", zone: "Z4", kind: .lightIntervals), completed: true),
            PlannedDay(weekday: 3),
        ]
        p.todaySession = WorkoutSession(
            title: "Footing", subtitle: "Zone 2", durationMinutes: 40,
            pace: "5:30", zone: "Z2", kind: .easyFooting)
        return p
    }

    private func courses(chaussure: UUID) -> [RunRecord] {
        [
            RunRecord(date: Date(timeIntervalSince1970: 1_700_000_000), title: "Footing",
                      distanceKm: 8.2, durationSeconds: 2_700, avgPace: "5:29",
                      avgHeartRate: 148, kcal: 540, elevationGainM: 62,
                      splits: ["5:20", "5:35"],
                      route: [.init(lat: 48.85, lng: 2.35, altitude: 35),
                              .init(lat: 48.86, lng: 2.36)],
                      sessionKind: .easyFooting),
            RunRecord(date: Date(timeIntervalSince1970: 1_700_300_000), title: "Sortie longue",
                      distanceKm: 18.4, durationSeconds: 6_300, avgPace: "5:42",
                      avgHeartRate: 142, kcal: 1_180, elevationGainM: 210,
                      sessionKind: .longRun),
        ].map { course in
            course.shoeID = chaussure
            return course
        }
    }

    /// Un magasin en mémoire, avec le vrai schéma de l'app — pas une maquette : la restauration
    /// insère de vrais `@Model`, et c'est SwiftData qui dit si elle sait les écrire.
    private func magasinVide() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: PersistenceController.schema,
                                               isStoredInMemoryOnly: true)
        return try ModelContainer(for: PersistenceController.schema,
                                  migrationPlan: RunUpMigrationPlan.self,
                                  configurations: [configuration])
    }

    private func allerRetour(_ s: Sauvegarde) throws -> Sauvegarde {
        let data = try SauvegardeService.encodeur().encode(s)
        return try SauvegardeService.decodeur().decode(Sauvegarde.self, from: data)
    }

    // MARK: L'aller-retour complet

    func testLeProfilSurvitALAllerRetour() throws {
        let origine = profilRempli()
        let sauvegarde = try allerRetour(SauvegardeService.construire(
            profil: origine, courses: [], messages: [], chaussures: []))

        let neuf = UserProfile()
        SauvegardeService.appliquer(try XCTUnwrap(sauvegarde.profil), sur: neuf)

        XCTAssertEqual(neuf.name, "Charlotte")
        XCTAssertEqual(neuf.goalId, .race)
        XCTAssertEqual(neuf.level, .confirmee)
        XCTAssertEqual(neuf.sex, "female")
        XCTAssertEqual(neuf.birthdate, origine.birthdate)
        XCTAssertEqual(neuf.goalDisplay, "10 km · 47:30")
        XCTAssertEqual(neuf.raceDistance, .k10)
        XCTAssertEqual(neuf.raceDate, origine.raceDate)
        XCTAssertEqual(neuf.volumeActuel, "troisOuQuatre")
        XCTAssertEqual(neuf.tempsSemaineMin, 45)
        XCTAssertEqual(neuf.tempsWeekEndMin, 90)
        XCTAssertEqual(neuf.terrains, ["route", "piste"])
        XCTAssertEqual(neuf.autresSports, ["velo"])
        XCTAssertEqual(neuf.streak, 37)
        XCTAssertEqual(neuf.xp, 4_210)
        XCTAssertEqual(neuf.weekTier, 3)
        XCTAssertEqual(neuf.recentRPESeverities, [1, 2, 1, 3])
        XCTAssertEqual(neuf.seenBadgeKeys, ["premiere_course", "dix_sorties"])
        XCTAssertEqual(neuf.completedDebriefsCount, 42)
        XCTAssertEqual(neuf.runningDays, [1, 3, 5, 6])
        XCTAssertEqual(neuf.preferredLongRunDay, 6)
        XCTAssertEqual(neuf.accentThemeID, "menthe")
        XCTAssertEqual(neuf.avatarImageData, origine.avatarImageData)
        XCTAssertTrue(neuf.onboarded)
        // Le programme en cours, et pas seulement les réponses : c'est lui qu'elle voit à
        // l'ouverture, et le régénérer donnerait une autre semaine que celle qu'elle suivait.
        XCTAssertEqual(neuf.weekSessions.count, 2)
        XCTAssertEqual(neuf.weekSessions.first?.session?.kind, .lightIntervals)
        XCTAssertEqual(neuf.weekSessions.first?.completed, true)
        XCTAssertEqual(neuf.todaySession.kind, .easyFooting)
        XCTAssertEqual(neuf.todaySession.durationMinutes, 40)
    }

    func testUneCourseSurvitEntiereALAllerRetour() throws {
        let paire = UUID()
        let origine = courses(chaussure: paire)
        let sauvegarde = try allerRetour(SauvegardeService.construire(
            profil: profilRempli(), courses: origine, messages: [], chaussures: []))

        XCTAssertEqual(sauvegarde.courses.count, 2)
        let relue = try XCTUnwrap(sauvegarde.courses.first).enRunRecord()
        XCTAssertEqual(relue.date, origine[0].date)
        XCTAssertEqual(relue.title, "Footing")
        XCTAssertEqual(relue.distanceKm, 8.2)
        XCTAssertEqual(relue.durationSeconds, 2_700)
        XCTAssertEqual(relue.avgPace, "5:29")
        XCTAssertEqual(relue.avgHeartRate, 148)
        XCTAssertEqual(relue.kcal, 540)
        XCTAssertEqual(relue.elevationGainM, 62)
        XCTAssertEqual(relue.splits, ["5:20", "5:35"])
        XCTAssertEqual(relue.sessionKind, .easyFooting)
        XCTAssertEqual(relue.shoeID, paire)
        // LE TRACÉ. C'est la donnée que la migration qui vient va déplacer, donc celle dont la
        // sauvegarde doit prouver qu'elle sait la rendre.
        XCTAssertEqual(relue.route.count, 2)
        XCTAssertEqual(relue.route.first?.lat, 48.85)
        XCTAssertEqual(relue.route.first?.altitude, 35)
        XCTAssertNil(relue.route.last?.altitude)
    }

    func testLesChaussuresGardentLeurIdentifiant() throws {
        let paire = Shoe(name: "Pegasus 41", startDistanceKm: 120, alertThresholdKm: 650)
        let mesCourses = courses(chaussure: paire.id)
        let sauvegarde = try allerRetour(SauvegardeService.construire(
            profil: profilRempli(), courses: mesCourses, messages: [], chaussures: [paire]))

        let relue = try XCTUnwrap(sauvegarde.chaussures.first).enShoe()
        let coursesRelues = sauvegarde.courses.map { $0.enRunRecord() }
        XCTAssertEqual(relue.id, paire.id)
        XCTAssertEqual(relue.name, "Pegasus 41")
        XCTAssertEqual(relue.alertThresholdKm, 650)
        // Le lien course → paire passe par l'UUID. En tirer un neuf à la restauration remettrait
        // tous les kilométrages à zéro sans rien afficher d'anormal.
        XCTAssertEqual(relue.totalKm(runs: coursesRelues), 120 + 8.2 + 18.4, accuracy: 0.001)
    }

    func testLaConversationSurvitALAllerRetour() throws {
        let messages = [
            ChatMessage(role: .user, text: "J'ai mal au genou",
                        timestamp: Date(timeIntervalSince1970: 1_700_000_100)),
            ChatMessage(role: .coach, text: "On allège la semaine",
                        timestamp: Date(timeIntervalSince1970: 1_700_000_200)),
            ChatMessage(role: .system, text: "Semaine allégée",
                        timestamp: Date(timeIntervalSince1970: 1_700_000_300)),
        ]
        let sauvegarde = try allerRetour(SauvegardeService.construire(
            profil: profilRempli(), courses: [], messages: messages, chaussures: []))

        XCTAssertEqual(sauvegarde.messages.count, 3)
        let relus = sauvegarde.messages.map { $0.enChatMessage() }
        XCTAssertEqual(relus.map(\.role), [.user, .coach, .system])
        XCTAssertEqual(relus[0].text, "J'ai mal au genou")
        XCTAssertEqual(relus[2].timestamp, messages[2].timestamp)
    }

    // MARK: Le refus de fusionner

    func testLaRestaurationNExigeQuUneBaseVide() {
        XCTAssertTrue(SauvegardeService.peutRestaurer(onboarded: false, nombreDeCourses: 0))
        // Déjà inscrite : il y a des réponses d'inscription à écraser.
        XCTAssertFalse(SauvegardeService.peutRestaurer(onboarded: true, nombreDeCourses: 0))
        // Pas inscrite mais des courses : un import Santé a déjà tourné.
        XCTAssertFalse(SauvegardeService.peutRestaurer(onboarded: false, nombreDeCourses: 3))
        XCTAssertFalse(SauvegardeService.peutRestaurer(onboarded: true, nombreDeCourses: 212))
    }

    func testRestaurerSurUneBaseNonVideLeve() throws {
        let profil = profilRempli()   // onboarded == true
        let contexte = ModelContext(try magasinVide())
        var sauvegarde = Sauvegarde()
        sauvegarde.courses = [Sauvegarde.Course()]

        XCTAssertThrowsError(try SauvegardeService.restaurer(
            sauvegarde, dans: contexte, profil: profil, nombreDeCourses: 0)) { erreur in
            XCTAssertEqual(erreur as? SauvegardeService.Echec, .baseNonVide)
        }
    }

    // MARK: La tolérance — un défaut local ne coûte pas le fichier

    private func decoder(_ json: String) throws -> Sauvegarde {
        try SauvegardeService.decodeur().decode(Sauvegarde.self, from: Data(json.utf8))
    }

    func testUnFichierVideSeLitQuandMeme() throws {
        let s = try decoder("{}")
        XCTAssertEqual(s.version, Sauvegarde.versionDuFormat)
        XCTAssertNil(s.profil)
        XCTAssertTrue(s.courses.isEmpty)
    }

    func testUneCourseAbimeeNeCoutePasLesAutres() throws {
        // La deuxième entrée n'est même pas un objet. Un `[Course]` ordinaire ferait échouer
        // TOUT le décodage : les cinq cents courses du fichier perdues à cause d'une.
        let s = try decoder("""
        {"courses": [
          {"title": "Footing", "distanceKm": 8.2},
          "ceci n'est pas une course",
          {"title": "Sortie longue", "distanceKm": 18.4}
        ]}
        """)
        XCTAssertEqual(s.courses.count, 2)
        XCTAssertEqual(s.courses.map(\.title), ["Footing", "Sortie longue"])
    }

    func testUnTableauEntierementAbimeNeBloquePas() throws {
        // La garde anti-boucle de `Indulgent`. Si rien ne faisait avancer le curseur, l'app
        // tournerait sans fin sur le même élément : une sauvegarde abîmée figerait l'écran au
        // lieu de se lire à moitié. Un test qui dépasserait son temps imparti le dirait.
        let s = try decoder("""
        {"courses": [1, 2, true, null, [], "x"], "messages": [[[1]]]}
        """)
        XCTAssertTrue(s.courses.isEmpty)
        XCTAssertTrue(s.messages.isEmpty)
    }

    func testUneValeurInconnueNeFaitPasEchouerLeReste() throws {
        // Le cas réel : une sauvegarde écrite par une version PLUS RÉCENTE, relue par la version
        // qu'on vient de réinstaller. `objectif_de_2027` et `seance_de_demain` ne lui disent rien.
        let s = try decoder("""
        {"profil": {"name": "Charlotte", "goalId": "objectif_de_2027", "streak": 37},
         "courses": [{"title": "Footing", "sessionKind": "seance_de_demain", "distanceKm": 8.2}]}
        """)
        let profil = try XCTUnwrap(s.profil)
        XCTAssertEqual(profil.name, "Charlotte")
        XCTAssertEqual(profil.streak, 37)

        let neuf = UserProfile()
        SauvegardeService.appliquer(profil, sur: neuf)
        XCTAssertEqual(neuf.name, "Charlotte")
        XCTAssertEqual(neuf.streak, 37)
        // L'objectif illisible laisse celui de l'initialiseur au lieu d'emporter le fichier.
        XCTAssertEqual(neuf.goalId, UserProfile().goalId)

        let course = try XCTUnwrap(s.courses.first).enRunRecord()
        XCTAssertEqual(course.distanceKm, 8.2)
        XCTAssertNil(course.sessionKind)
        // Le titre enregistré reste le repli d'affichage — voir `RunRecord.titreAffiche`.
        XCTAssertEqual(course.titreAffiche, "Footing")
    }

    func testUnChampDUnMauvaisTypeNEmportePasSesVoisins() throws {
        let s = try decoder("""
        {"profil": {"name": "Charlotte", "streak": "beaucoup", "xp": 4210}}
        """)
        let profil = try XCTUnwrap(s.profil)
        XCTAssertEqual(profil.name, "Charlotte")
        XCTAssertNil(profil.streak)
        XCTAssertEqual(profil.xp, 4_210)
    }

    func testUnChampAbsentNEcrasePasLaValeurEnPlace() throws {
        // UNE SAUVEGARDE PLUS ANCIENNE QUE L'APP. Elle ne connaît ni le thème ni les terrains ;
        // écrire `nil` par-dessus viderait des réglages que personne n'a touchés.
        let s = try decoder("""
        {"profil": {"name": "Charlotte"}}
        """)
        let neuf = UserProfile()
        let themeDOrigine = neuf.accentThemeID
        let uniteDOrigine = neuf.distanceUnit
        SauvegardeService.appliquer(try XCTUnwrap(s.profil), sur: neuf)
        XCTAssertEqual(neuf.name, "Charlotte")
        XCTAssertEqual(neuf.accentThemeID, themeDOrigine)
        XCTAssertEqual(neuf.distanceUnit, uniteDOrigine)
        XCTAssertFalse(neuf.onboarded)
    }

    func testUnTraceAbimeNeCoutePasLaCourse() throws {
        let s = try decoder("""
        {"courses": [{"title": "Footing", "distanceKm": 8.2,
          "route": [{"lat": 48.85, "lng": 2.35}, "cassé", {"lat": 48.86, "lng": 2.36}]}]}
        """)
        let course = try XCTUnwrap(s.courses.first).enRunRecord()
        XCTAssertEqual(course.distanceKm, 8.2)
        XCTAssertEqual(course.route.count, 2)
    }

    func testUnFichierQuiNEstPasUnObjetEstRefuse() {
        // Un tableau nu, un nombre, une chaîne : ce n'est pas une sauvegarde. Refuser permet de
        // dire « ce fichier n'est pas une sauvegarde RUNUP » ; tolérer rendrait une sauvegarde
        // vide, qui se serait présentée comme restaurée en n'ayant rien restauré.
        XCTAssertThrowsError(try decoder("[1, 2, 3]"))
        XCTAssertThrowsError(try decoder("42"))
    }

    func testUnTableauEcritDeTraversNEffacePasCeQuiEstEnPlace() throws {
        // `weekStrip` n'est même pas un tableau ici. Le lire comme un tableau VIDE effacerait la
        // bande de la semaine du profil en place — une perte provoquée par le geste censé réparer.
        let s = try decoder("""
        {"profil": {"name": "Charlotte", "weekStrip": {"lundi": "done"}}}
        """)
        let profil = try XCTUnwrap(s.profil)
        XCTAssertNil(profil.weekStrip)

        let neuf = UserProfile()
        let bandeDOrigine = neuf.weekStrip
        SauvegardeService.appliquer(profil, sur: neuf)
        XCTAssertEqual(neuf.name, "Charlotte")
        XCTAssertEqual(neuf.weekStrip, bandeDOrigine)
    }

    func testUnProfilQuiNEstPasUnObjetNeCoutePasLesCourses() throws {
        let s = try decoder("""
        {"profil": "abîmé", "courses": [{"title": "Footing", "distanceKm": 8.2}]}
        """)
        XCTAssertNil(s.profil)
        XCTAssertEqual(s.courses.count, 1)
    }

    // MARK: Le fichier lui-même

    func testLeFichierSEcritEtSeRelitDepuisLeDisque() throws {
        // Pas une simulation : un vrai fichier sur un vrai disque, écrit puis relu, parce que
        // c'est le seul trajet que la sauvegarde empruntera jamais.
        let dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }

        let paire = Shoe(name: "Pegasus 41", startDistanceKm: 120)
        let origine = SauvegardeService.construire(
            profil: profilRempli(), courses: courses(chaussure: paire.id),
            messages: [ChatMessage(role: .user, text: "Salut")], chaussures: [paire],
            versionApp: "3.1", le: Date(timeIntervalSince1970: 1_760_000_000))

        let url = try XCTUnwrap(SauvegardeService.ecrire(origine, dans: dossier))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let relue = try XCTUnwrap(SauvegardeService.lire(url))

        XCTAssertEqual(relue.versionApp, "3.1")
        XCTAssertEqual(relue.creeLe, origine.creeLe)
        XCTAssertEqual(relue.courses.count, 2)
        XCTAssertEqual(relue.messages.count, 1)
        XCTAssertEqual(relue.chaussures.count, 1)
        XCTAssertEqual(relue.profil?.name, "Charlotte")
        XCTAssertEqual(relue.profil?.avatarImageData, origine.profil?.avatarImageData)
    }

    func testLeNomDuFichierPorteSaDate() {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "UTC")!
        let jour = Date(timeIntervalSince1970: 1_760_000_000)   // 2025-10-09
        XCTAssertEqual(SauvegardeService.nomDeFichier(le: jour, calendrier: calendrier),
                       "RUNUP-sauvegarde-2025-10-09.json")
    }

    func testUnFichierQuiNEstPasUneSauvegardeNeRendRien() throws {
        let dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let url = dossier.appendingPathComponent("photo.json")
        try Data("pas du JSON du tout".utf8).write(to: url)

        XCTAssertNil(SauvegardeService.lire(url))
        XCTAssertNil(SauvegardeService.lire(dossier.appendingPathComponent("absent.json")))
    }

    // MARK: La restauration complète, dans un vrai magasin

    func testUneRestaurationCompleteDansUnMagasinVide() throws {
        let contexte = ModelContext(try magasinVide())

        let paire = Shoe(name: "Pegasus 41", startDistanceKm: 120)
        let fichier = try allerRetour(SauvegardeService.construire(
            profil: profilRempli(), courses: courses(chaussure: paire.id),
            messages: [ChatMessage(role: .user, text: "Salut")], chaussures: [paire]))

        let vierge = UserProfile()
        contexte.insert(vierge)
        let compte = try SauvegardeService.restaurer(
            fichier, dans: contexte, profil: vierge, nombreDeCourses: 0)

        XCTAssertEqual(compte.courses, 2)
        XCTAssertEqual(compte.messages, 1)
        XCTAssertEqual(compte.chaussures, 1)
        XCTAssertEqual(try contexte.fetchCount(FetchDescriptor<RunRecord>()), 2)
        XCTAssertEqual(try contexte.fetchCount(FetchDescriptor<ChatMessage>()), 1)
        XCTAssertEqual(try contexte.fetchCount(FetchDescriptor<Shoe>()), 1)
        XCTAssertEqual(vierge.name, "Charlotte")
        XCTAssertEqual(vierge.streak, 37)
        XCTAssertTrue(vierge.onboarded)

        // Et le kilométrage de la paire se retrouve, parce que les identifiants ont été gardés.
        let relues = try contexte.fetch(FetchDescriptor<RunRecord>())
        let relue = try XCTUnwrap(try contexte.fetch(FetchDescriptor<Shoe>()).first)
        XCTAssertEqual(relue.totalKm(runs: relues), 120 + 8.2 + 18.4, accuracy: 0.001)
    }
}
