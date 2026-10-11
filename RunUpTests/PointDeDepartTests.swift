import XCTest
import SwiftData
@testable import RunUp

/// Le plan part de la personne, plus de la course visée.
///
/// # LES TROIS CHOSES QUE LE MOTEUR INVENTAIT
///
/// 1. LA PREMIÈRE SORTIE LONGUE venait de la distance de la course : `baseTarget * 0.6`, soit
///    8,4 km en semaine 1 d'un plan marathon — qu'on coure trois kilomètres ou vingt-cinq.
/// 2. LE PALIER DE DÉPART venait du niveau coché, un mot sur soi, et de rien d'autre.
/// 3. TOUTES LES ALLURES venaient du temps visé, c'est-à-dire d'une ambition.
///
/// Aucun de ces trois défauts ne cassait quoi que ce soit : le plan s'affichait, les chiffres
/// étaient cohérents, les semaines bien formées. C'est pour ça qu'ils ont tenu si longtemps, et
/// c'est pour ça qu'il faut des tests qui regardent les NOMBRES plutôt que la forme.
@MainActor
final class PointDeDepartTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func profil(plusLongueSortie: PlusLongueSortie? = nil,
                        allureFooting: AllureFooting? = nil,
                        perfRecente: String? = nil,
                        chrono: String? = nil,
                        niveau: ExperienceLevel = .intermediaire) -> UserProfile {
        let p = UserProfile(name: "Test")
        p.goalId = .race
        p.level = niveau
        p.raceDistance = .marathon
        p.raceChrono = chrono
        p.plusLongueSortie = plusLongueSortie?.rawValue
        p.allureFooting = allureFooting?.rawValue
        p.bestRecentPerf = perfRecente
        p.runningDays = [0, 2, 4, 6]
        p.preferredLongRunDay = 6
        let start = Date()
        p.programStartDate = start
        p.raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 16, to: start)
        container.mainContext.insert(p)
        return p
    }

    /// La durée de la sortie longue de la semaine 1 — le seul endroit où la distance de départ
    /// se laisse observer depuis l'extérieur du moteur.
    private func sortieLongueSemaine1(_ p: UserProfile) throws -> Int {
        let semaine = AdaptivePlanEngine.generateWeekSessions(weekNumber: 1, tier: 2, profile: p)
        let longue = semaine.compactMap { $0.session }.first { $0.family == .longRun }
        return try XCTUnwrap(longue, "aucune sortie longue en semaine 1").durationMinutes
    }

    // MARK: 1. La sortie longue part d'elle

    /// DEUX PERSONNES, LE MÊME MARATHON, DEUX PREMIÈRES SORTIES LONGUES.
    ///
    /// C'est tout le sujet en une assertion : avant, ces deux-là recevaient la même.
    func testLaPremiereSortieLongueSuitCeQuElleCourtDeja() throws {
        let petite = try sortieLongueSemaine1(profil(plusLongueSortie: .moinsDe3))
        let grande = try sortieLongueSemaine1(profil(plusLongueSortie: .de15a25))
        XCTAssertLessThan(petite, grande, "petite \(petite) min, grande \(grande) min")
    }

    /// Et elle est MONOTONE : chaque tranche part d'au moins aussi loin que la précédente.
    /// Une seule inversion suffirait à ce que répondre honnêtement « je cours plus » donne un
    /// plan plus court.
    func testPlusOnCourtDejaPlusLaPremiereSortieLongueEstLongue() throws {
        var precedente = 0
        for tranche in PlusLongueSortie.allCases {
            let duree = try sortieLongueSemaine1(profil(plusLongueSortie: tranche))
            XCTAssertGreaterThanOrEqual(duree, precedente, "\(tranche) casse la monotonie")
            precedente = duree
        }
    }

    /// UN PROFIL QUI N'A PAS RÉPONDU GARDE EXACTEMENT SON PLAN D'AVANT.
    ///
    /// Les gens déjà inscrits n'ont jamais vu cette question. Leur prêter une réponse —
    /// « aucune », le plus prudent — raccourcirait brutalement la sortie longue de tout le monde
    /// à la mise à jour, et personne ne comprendrait pourquoi.
    func testUnProfilSansReponseGardeLAncienCalcul() throws {
        // `baseTarget` d'un marathon vaut 14 km, donc l'ancien départ valait 8,4 km : entre la
        // tranche « 5 à 10 » et la tranche « 10 à 15 ».
        let sansReponse = try sortieLongueSemaine1(profil())
        let cinq = try sortieLongueSemaine1(profil(plusLongueSortie: .de5a10))
        let dix = try sortieLongueSemaine1(profil(plusLongueSortie: .de10a15))
        XCTAssertGreaterThan(sansReponse, cinq)
        XCTAssertLessThan(sansReponse, dix)
    }

    // MARK: 2. Les allures viennent de ce qu'elle fait, pas de ce qu'elle vise

    private func seuil(_ p: UserProfile) -> Double { PaceModel.zones(for: p).thresholdSecPerKm }

    /// UNE PERF RÉELLE BAT LE TEMPS VISÉ.
    ///
    /// Quelqu'un qui vise 3 h 30 au marathon et dont la meilleure perf récente est un 10 km en
    /// 1 h recevait un plan calé sur 3 h 30 — footings trop rapides, seuil hors de portée. Le
    /// plan ne l'emmenait pas vers son objectif : il supposait qu'elle y était déjà.
    func testUnePerfReelleLEmporteSurLeTempsVise() {
        let ambitieuse = profil(perfRecente: "10 km en 60 min", chrono: "3:30")
        let sansPerf = profil(chrono: "3:30")
        XCTAssertGreaterThan(seuil(ambitieuse), seuil(sansPerf),
                             "la perf réelle doit donner une allure PLUS LENTE que l'ambition")
    }

    /// L'allure déclarée bat le temps visé, et cède devant une perf réelle.
    func testLallureDeclareeSeGlisseEntreLaPerfEtLeTempsVise() {
        let perfEtAllure = profil(allureFooting: .plusDe7, perfRecente: "10 km en 40 min")
        let allureSeule = profil(allureFooting: .plusDe7, chrono: "3:30")
        XCTAssertLessThan(seuil(perfEtAllure), seuil(allureSeule),
                          "la perf réelle doit primer sur l'allure déclarée")

        let viseSeul = profil(chrono: "3:30")
        XCTAssertGreaterThan(seuil(allureSeule), seuil(viseSeul),
                             "l'allure déclarée doit primer sur le temps visé")
    }

    /// « Je ne sais pas » ne vaut aucune allure — c'est une vraie réponse, pas un nombre.
    func testJeNeSaisPasNeFabriquePasDAllure() {
        let ignorante = profil(allureFooting: .jeNeSaisPas, chrono: "3:30")
        let muette = profil(chrono: "3:30")
        XCTAssertEqual(seuil(ignorante), seuil(muette))
    }

    /// Plus l'allure déclarée est rapide, plus le seuil l'est. Une inversion ici retournerait
    /// tout le plan.
    func testLesAlluresDeclareesSontOrdonnees() {
        let ordonnees = AllureFooting.allCases.filter { $0.secondesParKm != nil }
        var precedent = Double.greatestFiniteMagnitude
        for allure in ordonnees {
            let valeur = seuil(profil(allureFooting: allure))
            XCTAssertLessThan(valeur, precedent, "\(allure) casse l'ordre")
            precedent = valeur
        }
    }

    // MARK: 3. Le volume actuel plafonne le palier de départ

    /// Les tranches disent des nombres cohérents entre elles — c'est sur eux que le moteur
    /// travaille, le libellé n'est que leur habillage.
    func testLesTranchesSontOrdonnees() {
        var sorties = -1
        for v in VolumeActuel.allCases {
            XCTAssertGreaterThan(v.sortiesParSemaine, sorties, "\(v) casse l'ordre")
            sorties = v.sortiesParSemaine
        }
        var km = -1.0
        for s in PlusLongueSortie.allCases where s != .aucune {
            XCTAssertGreaterThanOrEqual(s.km, km, "\(s) casse l'ordre")
            km = s.km
        }
    }

    /// LE NIVEAU DÉCLARÉ NE SUFFIT PLUS À LUI SEUL.
    ///
    /// « Confirmée » décrit ce qu'on sait faire ; la semaine 1, elle, ne dépend que de ce que
    /// les jambes ont fait le mois dernier. Le palier se lit à travers la charge de la semaine,
    /// la seule façon de l'observer depuis l'extérieur.
    func testQuiNeCourtPlusNeDemarrePasAuPalierDUneConfirmee() {
        let resultat: (String?) -> Int = { volume in
            let p = UserProfile(name: "Test")
            self.container.mainContext.insert(p)
            AdaptivePlanEngine.applyOnboarding(
                AdaptivePlanEngine.OnboardingResult(
                    name: "Test", birthdate: nil, sex: nil, goal: .health,
                    raceDistance: nil, raceDistanceCustom: nil, raceElevationGainM: nil,
                    raceChrono: nil, raceDate: nil, hyroxDivision: nil, triathlonFormat: nil,
                    nageNiveau: nil, duathlonFormat: nil,
                    volumeActuel: volume, plusLongueSortie: nil, allureFooting: nil,
                    runningDays: [0, 2, 4, 6], preferredLongRunDay: 6, level: .confirmee,
                    connectedSources: [], weightNowKg: nil, weightTargetKg: nil, heightCm: nil,
                    focusArea: nil, bestRecentPerf: nil, lastRanRecency: nil, injuryArea: nil,
                    weeklyTimeBudget: nil, preferredTimeOfDay: nil,
                    cycleTrackingEnabled: false, lastPeriodStartDate: nil, averageCycleLengthDays: 28),
                to: p)
            return p.weekTier
        }
        XCTAssertEqual(resultat(VolumeActuel.aucune.rawValue), 1)
        XCTAssertEqual(resultat(VolumeActuel.uneOuDeux.rawValue), 2)
        XCTAssertEqual(resultat(VolumeActuel.cinqEtPlus.rawValue), 3)
        // Sans réponse, le comportement d'avant : le niveau décide seul.
        XCTAssertEqual(resultat(nil), 3)
    }
}

/// La lecture d'une « meilleure perf récente » écrite à la main.
///
/// # CE QUE CES TESTS ONT TROUVÉ
///
/// L'exemple que le champ affiche lui-même — « Ex. 10 km en 52 min » — ne passait pas son
/// propre analyseur : celui-ci exigeait un temps à deux points, donc « 52 min » était rejeté en
/// silence. Quelqu'un qui recopiait l'exemple mot pour mot n'obtenait rien.
///
/// Ça restait discret tant que ce champ n'était qu'un repli sur un objectif sur neuf. Depuis
/// qu'il est la première source de TOUTES les allures du plan, une lecture qui rate est un plan
/// entier recalé sur une constante de niveau — sans un mot nulle part.
///
/// Les cas sont écrits dans les trois langues de l'app, parce que c'est dans les trois qu'on
/// tape cette phrase, et que deux des trois défauts trouvés ici étaient précisément des défauts
/// de langue : la virgule décimale française et les miles anglais.
final class PerfRecenteTests: XCTestCase {

    private func lu(_ texte: String, file: StaticString = #filePath, line: UInt = #line)
    throws -> (km: Double, seconds: Double) {
        try XCTUnwrap(PaceModel.parseFreeformPerf(texte), "« \(texte) » n'a pas été lu",
                      file: file, line: line)
    }

    /// L'EXEMPLE DU CHAMP, DANS LES TROIS LANGUES. C'est le cas qui échouait.
    func testLexempleAfficheParLeChampEstLu() throws {
        for texte in ["10 km en 52 min", "10 km in 52 min", "10 km en 52 min"] {
            let r = try lu(texte)
            XCTAssertEqual(r.km, 10, accuracy: 0.01, texte)
            XCTAssertEqual(r.seconds, 3120, accuracy: 1, texte)
        }
    }

    /// LE PIÈGE DE L'ORDRE : « 10 km en 52 min » contient deux nombres, et le premier est la
    /// distance. Chercher les minutes dans la phrase entière rendrait dix minutes.
    func testLaDistanceNEstPasRelueCommeUnTemps() throws {
        XCTAssertEqual(try lu("10 km en 52 min").seconds, 3120, accuracy: 1)
        XCTAssertEqual(try lu("5 km en 25 min").seconds, 1500, accuracy: 1)
    }

    /// LA VIRGULE DÉCIMALE FRANÇAISE. « 10,5 » devenait « 105 » : un dix-kilomètres se lisait
    /// comme un cent-cinq, et toutes les allures du plan en découlaient.
    func testLaVirguleDecimaleEstUneVirgule() throws {
        XCTAssertEqual(try lu("10,5 km en 55 min").km, 10.5, accuracy: 0.01)
        XCTAssertEqual(try lu("10.5 km in 55 min").km, 10.5, accuracy: 0.01)
    }

    /// LES MILES. L'app est en anglais aussi, et personne aux États-Unis n'écrit en kilomètres.
    func testLesMilesSontConvertis() throws {
        XCTAssertEqual(try lu("6 miles in 48 min").km, 9.656, accuracy: 0.01)
        XCTAssertEqual(try lu("6 mi in 48 min").km, 9.656, accuracy: 0.01)
    }

    /// « min » NE DOIT JAMAIS ÊTRE LU COMME « mi ». La frontière de mot tient, et ce test est là
    /// pour qu'elle continue de tenir : sans elle, « 52 min » vaudrait 52 miles, soit 84 km.
    func testMinNestPasMi() throws {
        XCTAssertEqual(try lu("10 km en 52 min").km, 10, accuracy: 0.01)
        XCTAssertNil(PaceModel.parseFreeformPerf("52 min"), "pas de distance, donc rien à lire")
    }

    /// Les écritures du temps qui coexistent dans la vraie vie.
    func testLesFormesDuTempsQuOnEcritVraiment() throws {
        XCTAssertEqual(try lu("5 km en 22:30").seconds, 1350, accuracy: 1)
        XCTAssertEqual(try lu("21,1 km en 1h52").seconds, 6720, accuracy: 1)
        XCTAssertEqual(try lu("21.1 km in 1:52:00").seconds, 6720, accuracy: 1)
        XCTAssertEqual(try lu("10 km en 1 heure").seconds, 3600, accuracy: 1)
        XCTAssertEqual(try lu("10 km in 1 hr 05").seconds, 3900, accuracy: 1)
        XCTAssertEqual(try lu("10km 52min").seconds, 3120, accuracy: 1)
        XCTAssertEqual(try lu("10 km en 52 minutes").seconds, 3120, accuracy: 1)
    }

    /// MIEUX VAUT NE PAS LIRE QUE MAL LIRE. C'est de ce nombre que descendent les quatre zones
    /// du plan : une lecture hasardeuse coûte plus cher qu'un repli sur le niveau déclaré.
    func testCeQuOnNeSaitPasLireNEstPasDevine() {
        for texte in ["", "pas mal", "10 km", "un semi en 1h52", "52:00"] {
            XCTAssertNil(PaceModel.parseFreeformPerf(texte), "« \(texte) » n'aurait pas dû être lu")
        }
    }
}
