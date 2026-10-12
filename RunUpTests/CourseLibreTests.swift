import XCTest
import SwiftData
@testable import RunUp

/// La séance du jour en course libre.
///
/// # CE QU'IL Y AVAIT AVANT : RIEN
///
/// Trois séances dormaient dans le moteur, une seule était jamais lue, l'index prévu pour les
/// faire tourner n'a jamais été incrémenté, et la carte d'accueil n'en montrait aucune : elle
/// disait « On sort courir ? », tous les jours, indéfiniment.
///
/// # CE QUE CES TESTS TIENNENT
///
/// L'ORDRE DES RÈGLES EST LA RÈGLE DE SÉCURITÉ. Tout ce qui protège passe avant tout ce qui
/// progresse : une sortie longue attendue depuis huit jours ne doit pas s'imposer au lendemain
/// d'un fractionné. Une inversion ne casserait rien, n'échouerait nulle part, et enverrait
/// quelqu'un enchaîner deux séances dures — la façon la plus courante de se blesser quand
/// personne ne tient le compte à votre place.
///
/// Les assertions portent sur l'INTENTION et sur les nombres, jamais sur une phrase : le
/// simulateur d'intégration continue tourne en anglais.
@MainActor
final class CourseLibreTests: XCTestCase {

    private var container: ModelContainer!
    /// UN CALENDRIER EN UTC, ET PAS CELUI DU SYSTÈME. Les bornes de ces tests sont des JOURS :
    /// « hier », « quatre jours d'affilée », « lundi ». Sur un simulateur réglé à l'ouest de
    /// Greenwich, le fuseau décale le début de journée et une course « d'il y a un jour »
    /// devient une course d'il y a deux — ou un lundi devient un dimanche, et le plafond du
    /// week-end s'invite dans une assertion de durée.
    private let calendrier: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return c
    }()
    /// Un LUNDI, pour que le jour de référence tombe en semaine.
    private let aujourdhui = Date(timeIntervalSince1970: 1_800_259_200) // 2027-01-18, lundi, 08:00 UTC

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func profil(forme: [Int] = []) -> UserProfile {
        let p = UserProfile(name: "Test")
        p.goalId = .health
        p.programPhase = .freerun
        p.level = .intermediaire
        p.recentRPESeverities = forme
        container.mainContext.insert(p)
        return p
    }

    /// Une course il y a `ilYA` jours, de `minutes` minutes, du type donné.
    private func course(ilYA: Int, minutes: Int = 35, kind: SessionKind? = nil) -> RunRecord {
        let date = calendrier.date(byAdding: .day, value: -ilYA, to: aujourdhui) ?? aujourdhui
        return RunRecord(date: date, title: "x", distanceKm: Double(minutes) / 6,
                         durationSeconds: minutes * 60, avgPace: "6:00",
                         avgHeartRate: 140, kcal: 300, sessionKind: kind)
    }

    private func reperes(_ courses: [RunRecord]) -> CourseLibre.Reperes {
        CourseLibre.Reperes(courses: courses.sorted { $0.date > $1.date },
                            aujourdhui: calendrier.startOfDay(for: aujourdhui),
                            calendrier: calendrier)
    }

    private func intention(_ courses: [RunRecord], forme: Int = 80) -> CourseLibre.Intention {
        CourseLibre.intentionDuJour(reperes: reperes(courses), forme: forme).0
    }

    // MARK: Ce qui protège

    func testSansHistoriqueOnRepartCourtEtFacile() {
        XCTAssertEqual(intention([]), .recuperation)
    }

    func testApresDeuxSemainesSansCourirCestUneReprise() {
        XCTAssertEqual(intention([course(ilYA: 20)]), .recuperation)
        // Treize jours, ce n'est pas encore une reprise.
        XCTAssertNotEqual(intention([course(ilYA: 13)]), .recuperation)
    }

    /// DEUX SÉANCES DURES DE SUITE : la règle qui justifie tout le reste.
    func testLeLendemainDuneSeanceDureOnRecupere() {
        XCTAssertEqual(intention([course(ilYA: 1, kind: .vo2maxIntervals)]), .recuperation)
        XCTAssertEqual(intention([course(ilYA: 1, kind: .tempoRun)]), .recuperation)
    }

    func testLeLendemainDuneSortieLongueOnResteFacile() {
        XCTAssertEqual(intention([course(ilYA: 1, minutes: 90, kind: .longRun)]), .recuperation)
    }

    /// L'ORDRE DES RÈGLES. La sortie longue est attendue depuis dix jours ET hier était dur :
    /// c'est la récupération qui gagne. Une inversion ici est exactement le défaut que ce
    /// fichier existe pour empêcher.
    func testLaRecuperationPasseAvantLaSortieLongueAttendue() {
        let historique = [course(ilYA: 1, kind: .vo2maxIntervals), course(ilYA: 12, minutes: 90, kind: .longRun)]
        XCTAssertEqual(intention(historique), .recuperation)
    }

    func testQuatreJoursDaffileeAppellentUnRepos() {
        let quatre = (1...4).map { course(ilYA: $0) }
        XCTAssertEqual(intention(quatre), .repos)
    }

    /// Trois jours d'affilée ne suffisent pas — sauf si la forme baisse déjà.
    func testTroisJoursDaffileeNeSuffisentQueSiLaFormeBaisse() {
        let trois = (1...3).map { course(ilYA: $0) }
        XCTAssertEqual(intention(trois, forme: 60), .repos)
        XCTAssertNotEqual(intention(trois, forme: 85), .repos)
    }

    /// LA FORME DÉCIDE. En dessous de 55, rien de dur ni de long, quoi que dise le calendrier.
    func testUneFormeBasseInterditLeDurEtLeLong() {
        let vieilleLongue = [course(ilYA: 10, minutes: 90, kind: .longRun)]
        XCTAssertEqual(intention(vieilleLongue, forme: 50), .endurance)
        XCTAssertEqual(intention(vieilleLongue, forme: 70), .longue)
    }

    // MARK: Ce qui progresse

    func testApresUneSemaineSansSortieLongueCestLeJour() {
        XCTAssertEqual(intention([course(ilYA: 7, minutes: 90, kind: .longRun), course(ilYA: 3)]), .longue)
    }

    func testApresTroisJoursSansVitesseOnEnRemet() {
        // La sortie longue est récente, donc elle ne réclame rien ; la dernière séance rapide
        // remonte à cinq jours, donc elle, si.
        let historique = [course(ilYA: 2, minutes: 90, kind: .longRun),
                          course(ilYA: 5, kind: .tempoRun)]
        XCTAssertEqual(intention(historique), .qualite)
    }

    func testAvoirCouruHierDonneUnFootingFacile() {
        XCTAssertEqual(intention([course(ilYA: 1), course(ilYA: 3, minutes: 90, kind: .longRun),
                                  course(ilYA: 2, kind: .tempoRun)]), .endurance)
    }

    // MARK: Les durées

    /// LA PROGRESSION EST ICI : la sortie longue repart de la plus longue réellement courue et
    /// la gagne de 10 %. C'est la même règle que le plan structuré s'applique à lui-même.
    func testLaSortieLongueGagneDixPourCent() {
        let r = reperes([course(ilYA: 8, minutes: 60, kind: .longRun), course(ilYA: 3, minutes: 40)])
        XCTAssertEqual(CourseLibre.minutes(.longue, reperes: r), 65) // 60 × 1,10 = 66 → 65
    }

    /// Et jamais plus d'un quart d'heure d'un coup : le pourcentage seul laisserait quelqu'un
    /// qui vient de faire trois heures en prendre dix-huit de plus.
    func testLaSortieLongueNeGagneJamaisPlusDunQuartDheure() {
        let r = reperes([course(ilYA: 8, minutes: 180, kind: .longRun)])
        XCTAssertEqual(CourseLibre.minutes(.longue, reperes: r), 195)
    }

    /// Une séance de qualité est plus COURTE qu'un footing. Une heure de fractionné n'est pas
    /// une progression.
    func testUneSeanceDeQualiteResteCourte() {
        let r = reperes([course(ilYA: 3, minutes: 90), course(ilYA: 5, minutes: 95)])
        XCTAssertLessThanOrEqual(CourseLibre.minutes(.qualite, reperes: r), 45)
    }

    func testToutesLesDureesSontDesMultiplesDeCinq() {
        let r = reperes([course(ilYA: 2, minutes: 37), course(ilYA: 4, minutes: 43)])
        for intention in [CourseLibre.Intention.recuperation, .endurance, .tonique, .qualite, .longue] {
            let m = CourseLibre.minutes(intention, reperes: r)
            XCTAssertEqual(m % 5, 0, "\(intention) : \(m) min")
            XCTAssertGreaterThanOrEqual(m, 20, "\(intention) : \(m) min")
        }
        XCTAssertEqual(CourseLibre.minutes(.repos, reperes: r), 0)
    }

    /// LA MÉDIANE ET PAS LA MOYENNE : une seule sortie de deux heures dans le mois ne doit pas
    /// faire proposer des footings que personne ne fait d'habitude.
    func testUneSortieExceptionnelleNeTirePasLesFootings() {
        let r = reperes([course(ilYA: 2, minutes: 30), course(ilYA: 4, minutes: 30),
                         course(ilYA: 6, minutes: 30), course(ilYA: 8, minutes: 120)])
        XCTAssertEqual(CourseLibre.minutes(.endurance, reperes: r), 30)
    }

    // MARK: La carte change tous les jours, et pas dans la journée

    /// DEUX JOURS DE SUITE À INTENTION ÉGALE NE MONTRENT PAS LA MÊME SÉANCE. C'est la demande
    /// d'origine : une carte identique chaque matin cesse d'être lue au bout de trois jours.
    func testAIntentionEgaleLaSeanceChangeDunJourALautre() {
        let variantes = CourseLibre.variantes(.endurance)
        XCTAssertGreaterThan(variantes.count, 1, "une seule variante : la carte ne peut pas changer")
        XCTAssertEqual(Set(variantes).count, variantes.count, "deux variantes identiques")

        let p = profil()
        let demain = calendrier.date(byAdding: .day, value: 1, to: aujourdhui)!
        // Une course hier ET une aujourd'hui : vue d'aujourd'hui, la dernière remonte à un jour
        // (celle du jour est écartée) ; vue de demain, elle remonte aussi à un jour. Même
        // intention les deux jours — c'est la seule façon d'observer la rotation seule.
        let courses = [course(ilYA: 1), course(ilYA: 0)]
        let a = CourseLibre.duJour(profil: p, courses: courses, jour: aujourdhui, calendrier: calendrier)
        let b = CourseLibre.duJour(profil: p, courses: courses, jour: demain, calendrier: calendrier)
        XCTAssertEqual(a.seance.family, b.seance.family, "les deux jours doivent avoir la même intention")
        XCTAssertNotEqual(a.seance.kind, b.seance.kind)
    }

    /// ET ELLE NE CHANGE PAS DANS LA JOURNÉE. Une carte qui se réécrit quand on rouvre l'accueil
    /// ne se croit plus — c'est pour ça que la variante vient du jour et non d'un tirage.
    func testLaSeanceNeChangePasQuandOnRouvreLaccueil() {
        let p = profil()
        let courses = [course(ilYA: 2)]
        let a = CourseLibre.duJour(profil: p, courses: courses, jour: aujourdhui, calendrier: calendrier)
        let plusTard = calendrier.date(byAdding: .hour, value: 9, to: aujourdhui)!
        let b = CourseLibre.duJour(profil: p, courses: courses, jour: plusTard, calendrier: calendrier)
        XCTAssertEqual(a, b)
    }

    // MARK: Les liens avec le reste de l'app

    /// Une course faite AUJOURD'HUI ne se répond pas à elle-même : la question posée est « que
    /// faire maintenant », pas « qu'as-tu fait ce matin ».
    func testLaCourseDuJourNentrePasDansLeCalcul() {
        let p = profil()
        let sansAujourdhui = CourseLibre.duJour(profil: p, courses: [course(ilYA: 2)],
                                                jour: aujourdhui, calendrier: calendrier)
        let avecAujourdhui = CourseLibre.duJour(profil: p,
                                                courses: [course(ilYA: 2), course(ilYA: 0, kind: .tempoRun)],
                                                jour: aujourdhui, calendrier: calendrier)
        XCTAssertEqual(sansAujourdhui, avecAujourdhui)
    }

    /// Le temps déclaré à l'inscription plafonne aussi la course libre — la même règle que le
    /// plan structuré, et il serait absurde qu'elle ne vaille que pour lui.
    func testLeTempsDeclarePlafonneAussiLaCourseLibre() {
        let p = profil()
        p.tempsSemaineMin = 30
        p.tempsWeekEndMin = 30
        let longue = [course(ilYA: 8, minutes: 90, kind: .longRun), course(ilYA: 3, minutes: 60)]
        let s = CourseLibre.duJour(profil: p, courses: longue, jour: aujourdhui, calendrier: calendrier)
        XCTAssertLessThanOrEqual(s.seance.durationMinutes, 30, "\(s.seance.durationMinutes) min")
    }

    /// Un repos n'a ni durée, ni allure, ni zone à annoncer.
    func testUnReposNaAucunChiffre() {
        let p = profil()
        let quatre = (1...4).map { course(ilYA: $0) }
        let s = CourseLibre.duJour(profil: p, courses: quatre, jour: aujourdhui, calendrier: calendrier)
        XCTAssertEqual(s.seance.durationMinutes, 0)
        XCTAssertEqual(s.seance.kind, .rest)
    }

    /// Chaque intention a au moins une séance pour l'incarner — une liste vide planterait sur
    /// un modulo par zéro.
    func testChaqueIntentionAUneSeance() {
        for intention in [CourseLibre.Intention.repos, .recuperation, .endurance, .tonique, .qualite, .longue] {
            XCTAssertFalse(CourseLibre.variantes(intention).isEmpty, "\(intention)")
        }
    }

    /// 0 = lundi … 6 = dimanche, comme partout ailleurs. Un décalage d'un jour appliquerait le
    /// plafond du dimanche au vendredi.
    func testLindexDuJourCommenceLundi() {
        // 2027-01-18 est un lundi.
        XCTAssertEqual(CourseLibre.indexDuJour(aujourdhui, calendrier), 0)
        let dimanche = calendrier.date(byAdding: .day, value: 6, to: aujourdhui)!
        XCTAssertEqual(CourseLibre.indexDuJour(dimanche, calendrier), 6)
    }
}

/// La boucle se referme : ce qu'on propose aujourd'hui se relit demain.
///
/// # LE DÉFAUT QUE CE FICHIER EMPÊCHE
///
/// Une suggestion n'a de valeur que si la course qui en sort est RELUE pour ce qu'elle était.
/// Course libre posait une séance une fois pour toutes en entrant dans le mode, donc chaque
/// sortie enregistrée portait le même type, pour toujours — et le lendemain, le moteur relisant
/// cet historique n'aurait jamais vu passer une seule séance dure. « Hier c'était dur,
/// aujourd'hui on récupère » ne se serait jamais déclenché, en silence : la suggestion aurait
/// tourné sur ses variantes sans jamais répondre à ce qui avait été fait.
@MainActor
final class CourseLibreBoucleTests: XCTestCase {

    private let calendrier: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return c
    }()
    private let aujourdhui = Date(timeIntervalSince1970: 1_800_259_200)

    private func hier(_ kind: SessionKind, minutes: Int = 40) -> RunRecord {
        let date = calendrier.date(byAdding: .day, value: -1, to: aujourdhui) ?? aujourdhui
        return RunRecord(date: date, title: "x", distanceKm: 7, durationSeconds: minutes * 60,
                         avgPace: "6:00", avgHeartRate: 150, kcal: 400, sessionKind: kind)
    }

    /// UNE SÉANCE DE QUALITÉ PROPOSÉE EST RELUE COMME DURE.
    func testCeQuOnProposeEnQualiteEstReluCommeDur() {
        for kind in CourseLibre.variantes(.qualite) {
            XCTAssertTrue(CourseLibre.Reperes.estDure(hier(kind)), "\(kind) n'est pas relue comme dure")
        }
    }

    /// UNE SORTIE LONGUE PROPOSÉE EST RELUE COMME LONGUE, même courue plus court que prévu :
    /// c'est son TYPE qui la désigne, pas sa durée.
    func testCeQuOnProposeEnLongueEstReluCommeLong() {
        for kind in CourseLibre.variantes(.longue) {
            XCTAssertTrue(CourseLibre.Reperes.estLongue(hier(kind, minutes: 30), typiqueMinutes: 40),
                          "\(kind) n'est pas relue comme longue")
        }
    }

    /// ET L'INVERSE : un footing ne doit pas être pris pour une séance dure, sinon le moteur
    /// proposerait une récupération après chaque sortie et plus rien ne progresserait.
    func testUnFootingNestPasPrisPourUneSeanceDure() {
        let faciles = CourseLibre.variantes(.endurance)
            + CourseLibre.variantes(.recuperation)
            + CourseLibre.variantes(.tonique)
        for kind in faciles {
            XCTAssertFalse(CourseLibre.Reperes.estDure(hier(kind)), "\(kind) est prise pour une séance dure")
        }
    }

    /// LE BOUT DE LA CHAÎNE, en une assertion : une séance de qualité proposée et courue hier
    /// fait proposer une récupération aujourd'hui.
    func testUneQualiteCourueHierFaitProposerUneRecuperationAujourdhui() throws {
        let container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let p = UserProfile(name: "Test")
        p.programPhase = .freerun
        container.mainContext.insert(p)

        for kind in CourseLibre.variantes(.qualite) {
            let s = CourseLibre.duJour(profil: p, courses: [hier(kind)],
                                       jour: aujourdhui, calendrier: calendrier)
            XCTAssertEqual(s.seance.family, .recovery, "après \(kind) : \(s.seance.kind.map(\.rawValue) ?? "—")")
        }
    }
}
