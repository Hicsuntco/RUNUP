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
                    tempsSemaineMin: nil, tempsWeekEndMin: nil,
                    volumeActuel: volume, plusLongueSortie: nil, allureFooting: nil,
                    runningDays: [0, 2, 4, 6], preferredLongRunDay: 6, level: .confirmee,
                    connectedSources: [], weightNowKg: nil, weightTargetKg: nil, heightCm: nil,
                    focusArea: nil, bestRecentPerf: nil, lastRanRecency: nil, injuryArea: nil, injuryWhen: nil, terrains: [], autresSports: [],
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

/// Le plan ne prescrit jamais plus de temps qu'elle n'en a dit avoir.
///
/// # LA QUESTION EXISTAIT, ET LE PLAN NE LA LISAIT PAS
///
/// « Temps que tu veux y consacrer / semaine » était posée à l'objectif « Rester en forme »
/// depuis le début. Sa réponse n'allait nulle part : `weeklyTimeBudget` n'était lu que par
/// `CoachService`, pour écrire une phrase dans le contexte envoyé au modèle. Le générateur de
/// séances ne l'a jamais ouverte — « moins d'1 h par semaine » et « plus de 3 h » donnaient
/// exactement le même plan, à la minute près.
@MainActor
final class TempsDisponibleTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func profil(semaine: Int? = nil, weekEnd: Int? = nil) -> UserProfile {
        let p = UserProfile(name: "Test")
        p.goalId = .race
        p.level = .confirmee
        p.raceDistance = .marathon
        p.tempsSemaineMin = semaine
        p.tempsWeekEndMin = weekEnd
        p.plusLongueSortie = PlusLongueSortie.de15a25.rawValue
        p.runningDays = [0, 2, 4, 6]
        p.preferredLongRunDay = 6
        let start = Date()
        p.programStartDate = start
        p.raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 16, to: start)
        container.mainContext.insert(p)
        return p
    }

    private func durees(_ p: UserProfile) -> [(jour: Int, minutes: Int)] {
        AdaptivePlanEngine.generateWeekSessions(weekNumber: 2, tier: 3, profile: p)
            .compactMap { jour in jour.session.map { (jour.weekday, $0.durationMinutes) } }
    }

    /// AUCUNE SÉANCE NE DÉPASSE LE TEMPS DONNÉ — c'est la phrase affichée sous la question, et
    /// c'est elle que ce test tient.
    func testAucuneSeanceNeDepasseLeTempsDonne() {
        let p = profil(semaine: 30, weekEnd: 45)
        for (jour, minutes) in durees(p) {
            let plafond = TempsDisponible.estWeekEnd(jour) ? 45 : 30
            XCTAssertLessThanOrEqual(minutes, plafond, "jour \(jour) : \(minutes) min")
        }
    }

    /// Les deux plafonds sont bien DEUX : un mardi et un dimanche ne se ressemblent pas, et
    /// c'est tout l'intérêt de poser la question deux fois.
    func testLeWeekEndEtLaSemaineOntChacunLeurPlafond() {
        let p = profil(semaine: 30, weekEnd: 180)
        let semaine = durees(p).filter { !TempsDisponible.estWeekEnd($0.jour) }
        let weekEnd = durees(p).filter { TempsDisponible.estWeekEnd($0.jour) }
        XCTAssertFalse(semaine.isEmpty)
        XCTAssertFalse(weekEnd.isEmpty)
        XCTAssertTrue(semaine.allSatisfy { $0.minutes <= 30 }, "\(semaine)")
        XCTAssertTrue(weekEnd.contains { $0.minutes > 30 },
                      "le week-end doit pouvoir dépasser le plafond de la semaine — \(weekEnd)")
    }

    /// LE PLAFOND MORD APRÈS LE TIER, pas avant. L'appliquer sur la durée de base laisserait le
    /// palier repasser au-dessus, et une coureuse à qui on a promis 30 minutes en verrait 38.
    func testLePlafondMordApresLePalier() {
        for tier in 1...5 {
            let p = profil(semaine: 30, weekEnd: 45)
            let semaine = AdaptivePlanEngine.generateWeekSessions(weekNumber: 2, tier: tier, profile: p)
                .compactMap { jour in jour.session.map { (jour.weekday, $0.durationMinutes) } }
            for (jour, minutes) in semaine where !TempsDisponible.estWeekEnd(jour) {
                XCTAssertLessThanOrEqual(minutes, 30, "palier \(tier), jour \(jour)")
            }
        }
    }

    /// UNE SÉANCE RACCOURCIE NE S'ANNONCE PAS « Niveau 3 ». L'étiquette promettrait une charge
    /// que la durée dément — c'est le même raisonnement que pour l'allègement du coach.
    func testUneSeanceRaccourcieNeSannoncePasPlusChargee() {
        let p = profil(semaine: 30, weekEnd: 45)
        let semaine = AdaptivePlanEngine.generateWeekSessions(weekNumber: 2, tier: 4, profile: p)
        for jour in semaine {
            guard let s = jour.session else { continue }
            let plafond = TempsDisponible.estWeekEnd(jour.weekday) ? 45 : 30
            if s.durationMinutes >= plafond {
                XCTAssertNil(s.adjustment, "jour \(jour.weekday) : « \(s.adjustment ?? "")» sur une séance plafonnée")
            }
        }
    }

    /// UN PROFIL QUI N'A PAS RÉPONDU GARDE SON PLAN. Les gens déjà inscrits n'ont jamais vu
    /// cette question ; leur imposer un plafond les verrait perdre du temps de course du jour
    /// au lendemain, sans une explication nulle part.
    func testSansReponseAucunPlafond() {
        let avec = durees(profil(semaine: 30, weekEnd: 45)).map { $0.minutes }.reduce(0, +)
        let sans = durees(profil()).map { $0.minutes }.reduce(0, +)
        XCTAssertGreaterThan(sans, avec)
    }

    /// Le samedi et le dimanche sont le week-end, le reste ne l'est pas. Un décalage d'un jour
    /// appliquerait le plafond du dimanche au vendredi.
    func testLesJoursDuWeekEnd() {
        XCTAssertEqual((0...6).filter { TempsDisponible.estWeekEnd($0) }, [5, 6])
    }

    /// Les propositions sont ordonnées, et le week-end va au moins aussi loin que la semaine —
    /// c'est là que tombe la sortie longue.
    func testLesPropositionsSontOrdonnees() {
        XCTAssertEqual(TempsDisponible.enSemaine, TempsDisponible.enSemaine.sorted())
        XCTAssertEqual(TempsDisponible.leWeekEnd, TempsDisponible.leWeekEnd.sorted())
        XCTAssertGreaterThanOrEqual(TempsDisponible.leWeekEnd.max() ?? 0,
                                    TempsDisponible.enSemaine.max() ?? 0)
    }
}

/// La blessure, le terrain, les autres sports — les trois réponses qui n'étaient pas posées.
@MainActor
final class ContexteDeVieTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func profil(zone: String? = nil, quand: AncienneteBlessure? = nil,
                        terrains: [Terrain] = [], sports: [AutreSport] = [],
                        objectif: GoalType = .race) -> UserProfile {
        let p = UserProfile(name: "Test")
        p.goalId = objectif
        p.level = .intermediaire
        p.raceDistance = objectif == .ultraTrail ? .ultra50 : .marathon
        p.raceElevationGainM = objectif == .ultraTrail ? 2500 : nil
        p.injuryArea = zone
        p.injuryWhen = quand?.rawValue
        p.terrains = terrains.map(\.rawValue)
        p.autresSports = sports.map(\.rawValue)
        p.runningDays = [0, 1, 2, 3, 4, 5, 6]
        p.preferredLongRunDay = 6
        let start = Date()
        p.programStartDate = start
        p.raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 16, to: start)
        container.mainContext.insert(p)
        return p
    }

    private func seances(_ p: UserProfile, semaine: Int = 2) -> [WorkoutSession] {
        AdaptivePlanEngine.generateWeekSessions(weekNumber: semaine, tier: 2, profile: p)
            .compactMap(\.session)
    }

    // MARK: La blessure a une date

    /// UNE ENTORSE D'IL Y A TROIS ANS N'ALLÈGE PLUS LE PLAN POUR TOUJOURS.
    ///
    /// L'inscription demandait OÙ, jamais QUAND, et la conséquence était permanente : toute
    /// séance de vitesse raccourcie de 30 %, chaque semaine, indéfiniment.
    func testUneVieilleBlessureNAllegePlusLePlan() {
        let recente = seances(profil(zone: "knee", quand: .enCours))
            .filter { $0.family == .intervals || $0.family == .tempo }
        let ancienne = seances(profil(zone: "knee", quand: .plusDUnAn))
            .filter { $0.family == .intervals || $0.family == .tempo }
        XCTAssertFalse(recente.isEmpty)
        XCTAssertFalse(ancienne.isEmpty)
        XCTAssertLessThan(recente.map(\.durationMinutes).reduce(0, +),
                          ancienne.map(\.durationMinutes).reduce(0, +))
    }

    /// Les quatre tranches se partagent en deux, et la frontière est à trois mois.
    func testTroisMoisEstLaFrontiere() {
        XCTAssertTrue(AncienneteBlessure.enCours.demandeUneAdaptation)
        XCTAssertTrue(AncienneteBlessure.moinsDe3Mois.demandeUneAdaptation)
        XCTAssertFalse(AncienneteBlessure.de3a12Mois.demandeUneAdaptation)
        XCTAssertFalse(AncienneteBlessure.plusDUnAn.demandeUneAdaptation)
    }

    /// SANS RÉPONSE, L'ALLÈGEMENT RESTE. C'est le seul endroit de cette série où « pas de
    /// réponse » penche du côté prudent plutôt que du côté « comme avant » — parce qu'ici les
    /// deux sont la même chose, et retirer une protection sur un silence serait le mauvais
    /// arbitrage.
    func testSansDateLallegementReste() {
        let sansDate = seances(profil(zone: "knee"))
            .filter { $0.family == .intervals || $0.family == .tempo }
            .map(\.durationMinutes).reduce(0, +)
        let ancienne = seances(profil(zone: "knee", quand: .plusDUnAn))
            .filter { $0.family == .intervals || $0.family == .tempo }
            .map(\.durationMinutes).reduce(0, +)
        XCTAssertLessThan(sansDate, ancienne)
    }

    // MARK: Le terrain

    /// PAS DE CÔTE PRÈS DE CHEZ ELLE, PAS DE SÉANCE DE CÔTES.
    ///
    /// Prescrire une séance infaisable ne rend pas le plan exigeant : il rend la semaine
    /// incomplète, et c'est la coureuse qui croit avoir échoué.
    func testSansReliefLesSeancesDeReliefSontRemplacees() {
        let plate = seances(profil(terrains: [.plat, .piste], objectif: .ultraTrail), semaine: 3)
        XCTAssertFalse(plate.isEmpty)
        XCTAssertFalse(plate.contains { $0.kind?.demandeDuRelief == true },
                       "\(plate.compactMap { $0.kind?.rawValue })")
    }

    /// Et la semaine garde le même nombre de séances : un remplacement, pas une suppression.
    func testLeRemplacementNeViedePasLaSemaine() {
        let avec = seances(profil(terrains: [.trail], objectif: .ultraTrail), semaine: 3).count
        let sans = seances(profil(terrains: [.plat], objectif: .ultraTrail), semaine: 3).count
        XCTAssertEqual(avec, sans)
    }

    /// Le remplacement DIT pourquoi — ce n'est pas une substitution silencieuse.
    func testLeRemplacementPorteSaRaison() {
        let plate = seances(profil(terrains: [.plat], objectif: .ultraTrail), semaine: 3)
        XCTAssertTrue(plate.contains { $0.adaptationNote != nil }, "aucune séance ne dit pourquoi")
    }

    /// UNE LISTE VIDE NE FILTRE RIEN. Un plan d'ultra sans ses côtes est un plan amputé, et il
    /// vaut mieux l'amputer sur une réponse que sur un silence.
    func testSansReponseLeReliefReste() {
        let muette = seances(profil(objectif: .ultraTrail), semaine: 3)
        let vallonnee = seances(profil(terrains: [.vallonne], objectif: .ultraTrail), semaine: 3)
        XCTAssertEqual(muette.compactMap { $0.kind }, vallonnee.compactMap { $0.kind })
    }

    /// Le tapis n'offre pas de relief, et c'est un arbitrage : sa pente permet les côtes mais
    /// jamais les descentes, et c'est la descente qui détruit les quadriceps le jour J.
    func testLeTapisNoffrePasDeRelief() {
        XCTAssertFalse(Terrain.tapis.offreDuRelief)
        XCTAssertTrue(Terrain.vallonne.offreDuRelief)
        XCTAssertTrue(Terrain.trail.offreDuRelief)
    }

    // MARK: Les autres sports

    /// DEUX SPORTS PORTEURS, UNE SEULE SÉANCE DE QUALITÉ.
    func testDeuxSportsPorteursReduisentLeBudgetQualite() {
        let dure: (UserProfile) -> Int = { p in
            self.seances(p).filter { $0.family == .intervals || $0.family == .tempo }.count
        }
        XCTAssertEqual(dure(profil(sports: [.muscu, .sportsCo])), 1)
        XCTAssertEqual(dure(profil(sports: [.muscu])), 2)
        XCTAssertEqual(dure(profil()), 2)
    }

    /// LE VÉLO ET LA NATATION NE COMPTENT PAS — c'est l'impact qui pèse sur les jambes, pas la
    /// dépense. La même règle que le moteur applique déjà à ses propres séances.
    func testLeVeloEtLaNatationNeMangentPasLeBudget() {
        let dure = seances(profil(sports: [.velo, .natation, .yoga]))
            .filter { $0.family == .intervals || $0.family == .tempo }.count
        XCTAssertEqual(dure, 2)
        for sport in [AutreSport.velo, .natation, .yoga] {
            XCTAssertFalse(sport.peseSurLesJambes, "\(sport)")
        }
        for sport in [AutreSport.muscu, .sportsCo] {
            XCTAssertTrue(sport.peseSurLesJambes, "\(sport)")
        }
    }
}
