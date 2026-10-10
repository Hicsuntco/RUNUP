import XCTest
@testable import RunUp

/// Les pastilles de l'écran « TON PLAN » citent les réponses de l'inscription.
///
/// # CE QUE CES TESTS TIENNENT
///
/// Les pastilles sont une PREUVE qu'on a écouté. Une preuve fausse est pire que pas de preuve :
/// une rangée qui annonce « -0 kg », « Objectif  » ou « On surveille : aucune » dit le contraire
/// de ce que l'écran existe pour dire. Et rien ne casserait — l'écran s'afficherait, la pastille
/// serait juste vide ou absurde.
///
/// # LES ASSERTIONS NE LISENT AUCUN LITTÉRAL FRANÇAIS
///
/// Le simulateur de l'intégration continue tourne en ANGLAIS. Un test qui attend
/// « 4 jours / semaine » y échouerait pour la seule raison que la phrase est traduite. Les
/// assertions portent donc sur ce qui ne se traduit pas — les nombres, les chronos, « 10 km » —
/// ou comparent à la MÊME chaîne résolue que l'app affiche (`OnboardingChoices.libelle`), jamais
/// à une copie écrite à la main.
final class PlanRecapTests: XCTestCase {

    /// L'inscription REPREND un brouillon depuis `UserDefaults` à la construction — c'est ce qui
    /// permet de reprendre où l'on s'était arrêtée après un appel ou une mise à jour. Dans un
    /// test, ce même mécanisme ferait d'un brouillon laissé par ailleurs une réponse que le test
    /// croit ne pas avoir donnée. On le vide d'abord.
    override func setUp() {
        super.setUp()
        OnboardingViewModel().clearDraft()
    }

    /// Une inscription minimale, à compléter par chaque test. Le rythme est déjà posé par le
    /// modèle (`runningDays` démarre à quatre jours), donc toute rangée en porte au moins une.
    private func inscription(_ goal: GoalType) -> OnboardingViewModel {
        let vm = OnboardingViewModel()
        vm.goal = goal
        vm.name = "Charlotte"
        return vm
    }

    // MARK: Les objectifs à date

    /// Une course : sa distance, son chrono, son jour J, son rythme.
    func testUneCourseCiteSaDistanceSonChronoEtSonJourJ() {
        let jourJ = Date(timeIntervalSince1970: 1_800_000_000)
        let vm = inscription(.race)
        vm.distance = .k10
        vm.chrono = "47:30"
        vm.raceDate = jourJ
        vm.runningDays = [1, 2, 4, 6]

        let pastilles = PlanRecap.pastilles(vm)
        XCTAssertEqual(pastilles.count, 4, "\(pastilles)")
        XCTAssertEqual(pastilles[0], "10 km")
        XCTAssertTrue(pastilles[1].contains("47:30"), pastilles[1])
        // Le jour J porte un jour et un mois. Le mois est traduit, donc illisible depuis un test
        // qui tourne en anglais ; le NUMÉRO du jour ne l'est pas — et il est lu avec le même
        // calendrier que celui qui l'a écrit, faute de quoi le test tomberait sur un simulateur
        // réglé sur un fuseau qui change la date.
        let numeroDuJour = Calendar.current.component(.day, from: jourJ)
        XCTAssertTrue(pastilles[2].contains("\(numeroDuJour)"), pastilles[2])
        XCTAssertTrue(pastilles[3].contains("4"), pastilles[3])
    }

    /// LE DÉNIVELÉ EST LA RAISON D'ÊTRE DE L'OBJECTIF ULTRA, donc il se voit ici.
    ///
    /// « 80 km » ne décrit pas une course de montagne, « 80 km · 4000 m D+ » si. Et il vient
    /// avant le chrono : c'est le second nombre qui dit ce qu'on prépare.
    func testUnUltraCiteSonDenivele() {
        let vm = inscription(.ultraTrail)
        vm.distance = .ultra80
        vm.raceElevationGain = "4000"
        vm.chrono = "12:00"
        vm.raceDate = Date(timeIntervalSince1970: 1_800_000_000)

        let pastilles = PlanRecap.pastilles(vm)
        XCTAssertEqual(pastilles[0], "80 km")
        XCTAssertTrue(pastilles[1].contains("4000"), pastilles[1])
        XCTAssertTrue(pastilles[2].contains("12:00"), pastilles[2])
    }

    /// Un D+ laissé vide ne fabrique pas une pastille « 0 m D+ ».
    func testUnUltraSansDeniveleNAPasDePastilleDeDenivele() {
        let vm = inscription(.ultraTrail)
        vm.distance = .ultra50
        vm.chrono = "7:30"
        vm.raceDate = Date(timeIntervalSince1970: 1_800_000_000)

        let pastilles = PlanRecap.pastilles(vm)
        XCTAssertFalse(pastilles.contains { $0.contains("D+") }, "\(pastilles)")
    }

    /// « Autre distance » laissée vide ne donne pas une pastille vide.
    func testUneDistanceLibreVideNeFabriquePasDePastille() {
        let vm = inscription(.race)
        vm.distance = .other
        vm.customDistance = "   "
        vm.chrono = "2:00"
        vm.raceDate = Date(timeIntervalSince1970: 1_800_000_000)

        let pastilles = PlanRecap.pastilles(vm)
        XCTAssertFalse(pastilles.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }, "\(pastilles)")
        XCTAssertTrue(pastilles.contains { $0.contains("2:00") }, "\(pastilles)")
    }

    /// « Mon propre temps » laisse le champ libre : une chaîne vide est une non-réponse, pas un
    /// objectif. C'est la même lecture que `canProceed`, et l'oublier donnait « Objectif  ».
    func testUnChronoVideNeFabriquePasDObjectif() {
        let vm = inscription(.race)
        vm.distance = .semi
        vm.isCustomChrono = true
        vm.chrono = ""
        vm.raceDate = Date(timeIntervalSince1970: 1_800_000_000)

        let pastilles = PlanRecap.pastilles(vm)
        XCTAssertEqual(pastilles.count, 3, "\(pastilles)")
    }

    /// Un objectif SANS date n'invente pas de jour J, même si une date traîne dans le brouillon.
    ///
    /// Elle y traîne pour de vrai : on peut choisir une course, saisir sa date, puis revenir en
    /// arrière avec le chevron et changer d'objectif. La date reste dans le brouillon, et c'est
    /// voulu — elle sert si l'on repasse par la course. Elle ne doit juste pas ressortir sur un
    /// plan « Rester en forme », qui n'a pas de ligne d'arrivée.
    func testUnObjectifSansDateNaPasDeJourJ() {
        let vm = inscription(.health)
        vm.raceDate = Date(timeIntervalSince1970: 1_800_000_000)
        vm.weeklyTimeBudget = "2h"
        vm.preferredTimeOfDay = "morning"

        // Budget, moment, rythme — et rien d'autre.
        XCTAssertEqual(PlanRecap.pastilles(vm).count, 3, "\(PlanRecap.pastilles(vm))")
    }

    // MARK: Les objectifs sans date

    /// Les deux réponses de « Rester en forme » sont relues, et avec les libellés que l'app
    /// affiche — pas une recopie.
    func testResterEnFormeCiteSonBudgetEtSonMoment() {
        let vm = inscription(.health)
        vm.weeklyTimeBudget = "3h"
        vm.preferredTimeOfDay = "evening"

        let pastilles = PlanRecap.pastilles(vm)
        let budget = OnboardingChoices.libelle("3h", dans: OnboardingChoices.budgetsHebdo)
        let moment = OnboardingChoices.libelle("evening", dans: OnboardingChoices.momentsDeLaJournee)
        XCTAssertNotNil(budget)
        XCTAssertNotNil(moment)
        XCTAssertTrue(pastilles.contains { $0.contains(budget!) }, "\(pastilles)")
        XCTAssertTrue(pastilles.contains { $0 == moment! }, "\(pastilles)")
    }

    /// L'écart de poids, pas les deux poids : « -6 kg » est l'objectif, « 72 → 66 » est une
    /// fiche médicale.
    func testLaPerteDePoidsEstUnEcart() {
        let vm = inscription(.weight)
        vm.weightNow = "72"
        vm.weightTarget = "66"

        XCTAssertTrue(PlanRecap.pastilles(vm).contains { $0.contains("6") && $0.contains("kg") },
                      "\(PlanRecap.pastilles(vm))")
    }

    /// La virgule décimale est ce que donne un clavier français. « 72,5 » n'est pas une
    /// non-réponse.
    func testUnPoidsALaVirguleEstLu() {
        let vm = inscription(.weight)
        vm.weightNow = "72,5"
        vm.weightTarget = "66,5"

        XCTAssertTrue(PlanRecap.pastilles(vm).contains { $0.contains("6") && $0.contains("kg") },
                      "\(PlanRecap.pastilles(vm))")
    }

    /// UN OBJECTIF AU-DESSUS DU POIDS ACTUEL N'EST PAS UNE PERTE. Prendre du poids est une
    /// demande légitime ; « -0 kg » et « --3 kg » ne sont pas des façons de l'annoncer.
    func testUnObjectifSansPerteNeFabriquePasDePastille() {
        for (depart, cible) in [("66", "72"), ("70", "70"), ("", "66"), ("70", "")] {
            let vm = inscription(.weight)
            vm.weightNow = depart
            vm.weightTarget = cible
            XCTAssertFalse(PlanRecap.pastilles(vm).contains { $0.contains("kg") },
                           "\(depart) → \(cible) : \(PlanRecap.pastilles(vm))")
        }
    }

    // MARK: La blessure

    /// « Aucune » se choisit mais ne se relit pas : « On surveille : aucune » ne dit rien.
    func testAucuneBlessureNeFabriquePasDePastille() {
        let vm = inscription(.health)
        vm.weeklyTimeBudget = "2h"
        vm.preferredTimeOfDay = "noon"
        let sansReponse = PlanRecap.pastilles(vm).count

        vm.injuryArea = OnboardingChoices.aucuneBlessure
        XCTAssertEqual(PlanRecap.pastilles(vm).count, sansReponse)

        vm.injuryArea = "knee"
        let genou = OnboardingChoices.libelle("knee", dans: OnboardingChoices.blessures)
        XCTAssertNotNil(genou)
        XCTAssertEqual(PlanRecap.pastilles(vm).count, sansReponse + 1)
        XCTAssertTrue(PlanRecap.pastilles(vm).contains { $0.contains(genou!) }, "\(PlanRecap.pastilles(vm))")
    }

    /// Un identifiant inconnu — un brouillon d'inscription repris après une mise à jour qui a
    /// retiré un choix — ne fabrique pas une pastille portant le code.
    func testUnIdentifiantInconnuNeFabriquePasDePastille() {
        let vm = inscription(.health)
        vm.injuryArea = "epaule_gauche"
        XCTAssertFalse(PlanRecap.pastilles(vm).contains { $0.contains("epaule_gauche") },
                       "\(PlanRecap.pastilles(vm))")
    }

    // MARK: Les garde-fous qui valent pour les neuf objectifs

    /// Aucun objectif ne donne une rangée vide, et aucun ne dépasse le plafond.
    ///
    /// Le plafond n'est pas décoratif : au-delà, la rangée passe à trois lignes et l'écran cesse
    /// d'être lisible d'un coup d'œil — or c'est tout ce qu'on lui demande.
    func testChaqueObjectifTientDansLePlafond() {
        for objectif in GoalType.allCases {
            let vm = inscription(objectif)
            vm.distance = objectif == .ultraTrail ? .ultra100 : .marathon
            vm.raceElevationGain = "5000"
            vm.chrono = "4:15"
            vm.raceDate = Date(timeIntervalSince1970: 1_800_000_000)
            vm.hyroxDivision = .pro
            vm.triathlonFormat = .olympique
            vm.nageNiveau = .pasEncore
            vm.duathlonFormat = .standard
            vm.focusArea = "speed"
            vm.bestRecentPerf = "10 km en 52 min"
            vm.lastRanRecency = "1y+"
            vm.weeklyTimeBudget = "3h+"
            vm.preferredTimeOfDay = "varies"
            vm.weightNow = "80"
            vm.weightTarget = "72"
            vm.injuryArea = "back"

            let pastilles = PlanRecap.pastilles(vm)
            XCTAssertFalse(pastilles.isEmpty, "\(objectif) : aucune pastille")
            XCTAssertLessThanOrEqual(pastilles.count, PlanRecap.maximum, "\(objectif) : \(pastilles)")
            XCTAssertFalse(pastilles.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty },
                           "\(objectif) : une pastille vide — \(pastilles)")
        }
    }

    /// LE PLAFOND COUPE PAR LA FIN, DONC PAR LE MOINS PERSONNEL. Un ultra entièrement renseigné
    /// produit plus de pastilles que le plafond ; celles qui restent sont celles qui changent
    /// d'une personne à l'autre.
    func testLePlafondCoupeParLaFin() {
        let vm = inscription(.ultraTrail)
        vm.distance = .ultra100
        vm.raceElevationGain = "6000"
        vm.chrono = "20:00"
        vm.raceDate = Date(timeIntervalSince1970: 1_800_000_000)
        vm.injuryArea = "ankle"

        let pastilles = PlanRecap.pastilles(vm)
        XCTAssertEqual(pastilles.count, PlanRecap.maximum, "\(pastilles)")
        XCTAssertEqual(pastilles[0], "100 km")
        XCTAssertTrue(pastilles[1].contains("6000"), pastilles[1])
        XCTAssertTrue(pastilles[2].contains("20:00"), pastilles[2])
    }

    /// Le rythme est toujours là : c'est la seule réponse que tout le monde donne.
    func testLeRythmeEstToujoursCite() {
        for jours in [2, 3, 5, 7] {
            let vm = inscription(.progress)
            vm.focusArea = "endurance"
            vm.runningDays = Set(0..<jours)
            XCTAssertTrue(PlanRecap.pastilles(vm).contains { $0.contains("\(jours)") },
                          "\(jours) jours : \(PlanRecap.pastilles(vm))")
        }
    }

    // MARK: La phrase de clôture

    /// Elle appelle la personne par son prénom, et se passe de lui quand il manque — sans
    /// laisser « C'est prêt,  . » derrière elle.
    func testLaClotureUtiliseLePrenomQuandIlExiste() {
        let vm = inscription(.health)
        XCTAssertTrue(PlanRecap.cloture(vm).contains("Charlotte"), PlanRecap.cloture(vm))

        vm.name = "   "
        let sansPrenom = PlanRecap.cloture(vm)
        XCTAssertFalse(sansPrenom.isEmpty)
        XCTAssertFalse(sansPrenom.contains(",  "), sansPrenom)
        XCTAssertFalse(sansPrenom.contains(" ."), sansPrenom)
    }
}
