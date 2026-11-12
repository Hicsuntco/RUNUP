import XCTest
import SwiftData
@testable import RunUp

/// Verrouille ce qu'un changement demandé ne doit plus perdre.
///
/// Le programme est REGÉNÉRÉ — chaque lundi, à chaque changement de réglage, et même sans qu'elle
/// demande rien : l'allègement du coach expire tout seul au lancement et déclenche la
/// régénération. Deux changements écrivaient pourtant directement dans la semaine : le
/// déplacement d'une séance et l'allègement du jour. Ils disparaissaient donc au passage suivant,
/// et le second pouvait rendre la séance PLUS DURE que la demande qui l'avait allégée.
///
/// Aucun de ces défauts n'avait de symptôme. La semaine restait pleine, les séances restaient
/// justes, rien ne plantait — c'est pour ça qu'ils tiennent chacun un test ici plutôt qu'une
/// ligne de commentaire.
final class ContinuiteDuPlanTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserProfile.self, configurations: config)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    /// Sept jours de course : chaque jour porte une séance, donc chaque jour est une destination
    /// et « aujourd'hui » en est une quel que soit le jour où la CI tourne.
    @MainActor
    private func profil(semaineMin: Int? = nil, weekEndMin: Int? = nil) -> UserProfile {
        let p = UserProfile(name: "Test")
        p.goalId = .race
        p.raceDistance = .semi
        p.level = .intermediaire
        p.runningDays = [0, 1, 2, 3, 4, 5, 6]
        p.preferredLongRunDay = 6
        p.programStartDate = Date()
        p.raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())
        p.tempsSemaineMin = semaineMin
        p.tempsWeekEndMin = weekEndMin
        container.mainContext.insert(p)
        AdaptivePlanEngine.applyProgramSettingsChange(p)
        return p
    }

    private func seance(_ p: UserProfile, _ jour: Int) -> WorkoutSession? {
        p.weekSessions.first { $0.weekday == jour }?.session
    }

    // MARK: - Le rejeu, en entiers

    /// Un déplacement est un ÉCHANGE. Les deux jours troquent leur contenu ; c'est ce qu'on veut
    /// dire neuf fois sur dix en déplaçant une séance.
    func testLeRejeuEchangeLesDeuxJours() {
        let rejoue = DeplacementDeSeance.rejouer([deplacement(de: 3, vers: 4)], sur: [3: "A", 4: "B"])
        XCTAssertEqual(rejoue[3], "B")
        XCTAssertEqual(rejoue[4], "A")
    }

    /// Vers un jour de repos, le jour de départ reste VIDE — il ne garde pas une copie.
    ///
    /// C'est le cas de loin le plus fréquent : « je ne peux pas courir jeudi » déplace vers un
    /// jour où il n'y a rien. Une affectation d'optionnel retire la clé, et c'est voulu.
    func testLeRejeuVersUnJourVideNeDupliquePas() {
        let rejoue = DeplacementDeSeance.rejouer([deplacement(de: 3, vers: 4)], sur: [3: "A"])
        XCTAssertNil(rejoue[3], "le jeudi doit être libéré, pas dupliqué")
        XCTAssertEqual(rejoue[4], "A")
    }

    /// Deux déplacements de suite se composent dans l'ordre demandé.
    func testLeRejeuSeComposeDansLordre() {
        let rejoue = DeplacementDeSeance.rejouer(
            [deplacement(de: 3, vers: 4), deplacement(de: 4, vers: 5)],
            sur: [3: "A", 5: "D"]
        )
        XCTAssertEqual(rejoue[5], "A", "la séance a fini samedi")
        XCTAssertEqual(rejoue[4], "D", "et celle de samedi est passée vendredi")
        XCTAssertNil(rejoue[3])
    }

    /// Un déplacement puis son inverse rendent la semaine d'origine.
    func testLeRejeuEstReversible() {
        let depart = [0: "A", 3: "C"]
        let rejoue = DeplacementDeSeance.rejouer(
            [deplacement(de: 3, vers: 4), deplacement(de: 4, vers: 3)], sur: depart
        )
        XCTAssertEqual(rejoue, depart)
    }

    /// UN DÉPLACEMENT NE SURVIT PAS À LA REFONTE DE LA SEMAINE.
    ///
    /// « Déplace ma séance du jeudi au vendredi » ne veut plus rien dire quand le jeudi n'est
    /// plus un jour de course : rejoué, l'échange tirerait la séance du vendredi VERS le jeudi,
    /// c'est-à-dire reposerait une séance sur le jour qu'elle vient de déclarer impossible.
    func testUnDeplacementNeConcernePasUneAutreFormeDeSemaine() {
        let d = DeplacementDeSeance(de: 3, vers: 4, semaine: 2,
                                    joursDeCourse: [0, 3, 5], jourSortieLongue: 5)
        XCTAssertTrue(d.concerne(semaine: 2, joursDeCourse: [0, 3, 5], jourSortieLongue: 5))
        XCTAssertFalse(d.concerne(semaine: 3, joursDeCourse: [0, 3, 5], jourSortieLongue: 5),
                       "une autre semaine du plan")
        XCTAssertFalse(d.concerne(semaine: 2, joursDeCourse: [0, 5], jourSortieLongue: 5),
                       "le jeudi n'est plus un jour de course")
        XCTAssertFalse(d.concerne(semaine: 2, joursDeCourse: [0, 3, 5], jourSortieLongue: 3),
                       "la sortie longue a changé de jour")
    }

    private func deplacement(de: Int, vers: Int) -> DeplacementDeSeance {
        DeplacementDeSeance(de: de, vers: vers, semaine: 1, joursDeCourse: [], jourSortieLongue: nil)
    }

    // MARK: - Les règles du jour se calculent sur le jour d'arrivée

    /// LE PLAFOND DE TEMPS EST CELUI DU JOUR OÙ LA SÉANCE ATTERRIT.
    ///
    /// Elle a répondu « 30 minutes en semaine, 3 h le week-end ». Sa sortie longue du dimanche
    /// déplacée au mardi gardait la durée calculée pour le dimanche : elle lisait une séance
    /// bien plus longue un jour où elle venait de dire en avoir trente minutes. L'information
    /// était dans son profil ; le déplacement ne l'ouvrait jamais.
    ///
    /// Le plafond de semaine est à 30 et non à 45, et c'est la première version de ce test qui
    /// l'a appris : à 45, la précondition tombait sur « 45 n'est pas supérieur à 45 ». La sortie
    /// longue de la semaine 1 d'un bloc de base, pour un semi au niveau intermédiaire, vaut
    /// justement 45 minutes — le déplacement n'aurait donc rien eu à raboter, et le test aurait
    /// passé sans rien mesurer. 30 est la plus basse des durées réellement proposées à
    /// l'inscription (`TempsDisponible.enSemaine`).
    @MainActor
    func testLePlafondDeTempsSuitLeJourDarrivee() {
        let plafondEnSemaine = 30
        let p = profil(semaineMin: plafondEnSemaine, weekEndMin: 180)
        let longueAvant = seance(p, 6)?.durationMinutes ?? 0
        XCTAssertGreaterThan(longueAvant, plafondEnSemaine, "sans quoi le test ne mesure rien")

        XCTAssertTrue(AdaptivePlanEngine.enregistrerDeplacement(de: 6, vers: 1, profile: p))
        XCTAssertLessThanOrEqual(seance(p, 1)?.durationMinutes ?? .max, plafondEnSemaine,
                                 "le mardi vaut trente minutes, quelle que soit la séance qui y tombe")
    }

    /// LA NOTE DE PHASE EST CELLE DU JOUR OÙ LA SÉANCE ATTERRIT.
    ///
    /// Elle voyageait avec la séance : déplacée de quatre jours, une séance de qualité annonçait
    /// « phase lutéale estimée » un jour en phase menstruelle. Pas une mention inutile — une
    /// mention fausse, sur le sujet où l'app n'a pas le droit d'approximer.
    @MainActor
    func testLaNoteDePhaseSuitLeJourDarrivee() throws {
        let p = profil()
        p.cycleTrackingEnabled = true
        p.averageCycleLengthDays = 28
        // Le même calendrier que le moteur : semaine commençant le lundi. Les règles posées au
        // lundi de cette semaine mettent lundi à vendredi en phase menstruelle (jours 1 à 5 du
        // cycle) et le week-end en phase folliculaire — donc deux phases dans la semaine, quel
        // que soit le jour où la CI tourne.
        var cal = Calendar.current
        cal.firstWeekday = 2
        let lundi = try XCTUnwrap(cal.dateInterval(of: .weekOfYear, for: .now)?.start)
        p.lastPeriodStartDate = lundi
        AdaptivePlanEngine.applyProgramSettingsChange(p)

        func phase(_ jour: Int) -> String? {
            cal.date(byAdding: .day, value: jour, to: lundi)
                .flatMap { p.cyclePhase(on: $0) }?.rawValue
        }

        // Le jour de départ est celui qui porte une note de phase — c'est-à-dire une séance de
        // qualité, la seule dont l'intensité se discute. Il est cherché plutôt que supposé : sa
        // position dépend de la distribution de la semaine, pas d'une constante.
        guard let depart = (0..<7).first(where: { seance(p, $0)?.adaptationNote != nil }),
              let arrivee = (0..<7).first(where: { $0 != depart && phase($0) != phase(depart) })
        else {
            return XCTFail("aucune séance notée cette semaine : le test ne mesurerait rien")
        }

        let noteAvant = try XCTUnwrap(seance(p, depart)?.adaptationNote)
        XCTAssertTrue(AdaptivePlanEngine.enregistrerDeplacement(de: depart, vers: arrivee, profile: p))
        let noteApres = seance(p, arrivee)?.adaptationNote
        XCTAssertNotNil(noteApres, "la séance déplacée doit toujours dire quelque chose")
        XCTAssertNotEqual(noteApres, noteAvant,
                          "la note doit être celle de la phase du jour d'ARRIVÉE, pas celle du départ")
    }

    // MARK: - Ce qu'elle a demandé survit à la régénération

    /// UN DÉPLACEMENT SURVIT À UN CHANGEMENT DE RÉGLAGE.
    ///
    /// Il était écrit dans `weekSessions`, que `applyProgramSettingsChange` reconstruit de zéro.
    /// Un déplacement posé mardi n'existait plus jeudi matin — l'allègement du coach expire tout
    /// seul au lancement et régénère la semaine, sans qu'elle ait rien demandé et sans un mot.
    @MainActor
    func testUnDeplacementSurvitALaRegeneration() {
        let p = profil()
        let avant = seance(p, 3)?.displayTitle
        XCTAssertTrue(AdaptivePlanEngine.enregistrerDeplacement(de: 3, vers: 4, profile: p))
        let apresDeplacement = seance(p, 4)?.displayTitle
        XCTAssertEqual(apresDeplacement, avant)

        AdaptivePlanEngine.applyProgramSettingsChange(p)
        XCTAssertEqual(seance(p, 4)?.displayTitle, avant, "la régénération a repris le dessus")
    }

    /// L'ALLÈGEMENT DU JOUR N'EST PAS EFFACÉ, ET SURTOUT PAS INVERSÉ.
    ///
    /// Nuit de cinq heures à 8 h : la séance du jour passe en souple et raccourcit. Elle écrit au
    /// coach à 10 h « j'ai mal au genou, allège » : la semaine est régénérée, et la séance
    /// revenait à sa durée pleine avec ses intervalles. Elle avait demandé moins, elle obtenait
    /// plus dur qu'une minute avant — et sans recours, le garde du jour étant déjà consommé.
    @MainActor
    func testLallegementDuJourSurvitAUnePoseDuCoach() {
        let p = profil()
        let aujourdhui = AdaptivePlanEngine.currentWeekdayIndex()
        let pleine = seance(p, aujourdhui)?.durationMinutes ?? 0
        XCTAssertGreaterThan(pleine, 0)

        p.allegementDuJour = AllegementDuJour(le: Calendar.current.startOfDay(for: .now),
                                              raison: "Allégée · nuit courte")
        AdaptivePlanEngine.applyProgramSettingsChange(p)
        let allegee = seance(p, aujourdhui)?.durationMinutes ?? 0
        XCTAssertLessThan(allegee, pleine, "l'allègement doit mordre")
        XCTAssertEqual(seance(p, aujourdhui)?.adjustment, "Allégée · nuit courte")

        // La pose du coach régénère. L'allègement du jour doit toujours être là.
        _ = AdaptivePlanEngine.applyCoachAction(
            .ease(TrainingEase(maxMinutes: 45, noSpeedWork: false,
                               until: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
                               reason: "Programme allégé")),
            to: p
        )
        XCTAssertLessThanOrEqual(seance(p, aujourdhui)?.durationMinutes ?? .max, allegee,
                                 "une demande d'allègement ne doit jamais rallonger la séance")
    }

    /// Une semaine qui commence ne porte plus les déplacements de la précédente.
    @MainActor
    func testUneSemaineNeuveOublieLesDeplacements() {
        let p = profil()
        XCTAssertTrue(AdaptivePlanEngine.enregistrerDeplacement(de: 3, vers: 4, profile: p))
        XCTAssertFalse(p.deplacementsDeLaSemaine.isEmpty)
        // Le passage à la semaine suivante, tel que `refreshProgramForCurrentDate` le déclenche.
        p.programStartDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now)
        AdaptivePlanEngine.refreshProgramForCurrentDate(p)
        XCTAssertTrue(p.deplacementsDeLaSemaine.isEmpty)
    }

    /// L'ANNULATION D'UNE ACTION DU COACH DÉFAIT AUSSI L'ENTRÉE.
    ///
    /// « Décale ma séance du jour » enregistre désormais un déplacement au lieu de permuter la
    /// semaine à la main. Un instantané qui ne garderait que la semaine produite rendrait la
    /// semaine d'avant en laissant le déplacement dans la liste — et la régénération suivante le
    /// rejouerait. L'annulation se défaisait toute seule, sans un mot.
    @MainActor
    func testLannulationDuCoachDefaitAussiLeDeplacement() throws {
        // « Décaler à demain » n'a pas de sens le dimanche : le lendemain appartient à une semaine
        // qui n'est pas encore écrite, et `moveTodaySessionToTomorrow` le refuse pour cette
        // raison. Sauté plutôt que contourné — un test qui ne passerait qu'un jour sur sept ne
        // vaut rien, et un test qui truque « aujourd'hui » ne mesure plus le vrai chemin.
        try XCTSkipIf(AdaptivePlanEngine.currentWeekdayIndex() == 6,
                      "le dimanche n'a pas de lendemain dans la semaine de plan")
        let p = profil()
        let avant = p.weekSessions.map(\.session?.displayTitle)

        let instantane = AdaptivePlanEngine.snapshot(p)
        XCTAssertNotNil(AdaptivePlanEngine.applyCoachAction(.moveTodaysSession, to: p))
        XCTAssertFalse(p.deplacementsDeLaSemaine.isEmpty)

        AdaptivePlanEngine.restore(instantane, to: p)
        XCTAssertTrue(p.deplacementsDeLaSemaine.isEmpty, "le déplacement doit être défait aussi")
        // Et il ne doit pas revenir à la première régénération.
        AdaptivePlanEngine.applyProgramSettingsChange(p)
        XCTAssertEqual(p.weekSessions.map(\.session?.displayTitle), avant)
    }

    // MARK: - Le contrôle du jour ne se consomme qu'une fois qu'il a regardé

    /// UNE NUIT PAS ENCORE ÉCRITE NE BRÛLE PLUS LA JOURNÉE.
    ///
    /// Le repère se posait juste après le garde de date, avant de regarder le signal. Une
    /// ouverture à 6 h 30, avant que la montre ait versé la nuit dans Santé, consommait donc le
    /// contrôle du jour sans avoir rien lu : à 9 h la donnée était là, et le garde refusait.
    /// L'information existait, elle est arrivée dix minutes trop tard.
    @MainActor
    func testUneNuitPasEncoreEcriteNeConsommePasLaJournee() {
        let p = profil()
        XCTAssertFalse(AdaptivePlanEngine.applySameDayAdjustmentIfNeeded(p, sommeil: .pasEncoreEcrit))
        XCTAssertNil(p.lastSameDayAdjustmentCheckDay, "rien n'a été lu, rien n'est conclu")

        // La même journée, une fois la nuit versée : la décision se prend enfin.
        XCTAssertTrue(AdaptivePlanEngine.applySameDayAdjustmentIfNeeded(p, sommeil: .lu(4.5)))
        XCTAssertNotNil(p.allegementDuJour)
        XCTAssertNotNil(p.lastSameDayAdjustmentCheckDay)
    }

    /// Une bonne nuit est une RÉPONSE : elle n'allège rien, et elle clôt la journée. Sans quoi le
    /// contrôle se rejouerait à chaque synchronisation de Santé.
    @MainActor
    func testUneBonneNuitNallegeRienMaisConclutLaJournee() {
        let p = profil()
        XCTAssertFalse(AdaptivePlanEngine.applySameDayAdjustmentIfNeeded(p, sommeil: .lu(8)))
        XCTAssertNil(p.allegementDuJour)
        XCTAssertNotNil(p.lastSameDayAdjustmentCheckDay, "il n'y a plus rien à attendre")
    }

    /// Aucune source de sommeil n'est pas une absence provisoire : il n'y a rien à attendre, donc
    /// la journée se conclut tout de suite. Quelqu'un qui n'a jamais connecté Apple Santé ne doit
    /// pas voir ce contrôle se relancer à chaque ouverture.
    @MainActor
    func testSansSourceDeSommeilLaJourneeSeConclutQuandMeme() {
        let p = profil()
        XCTAssertFalse(AdaptivePlanEngine.applySameDayAdjustmentIfNeeded(p, sommeil: .aucuneSource))
        XCTAssertNotNil(p.lastSameDayAdjustmentCheckDay)
    }

    // MARK: - La bande de jours dit ce que la semaine porte

    /// La bande se lisait sur les jours de course, pas sur les séances réellement posées : elle
    /// annonçait une séance le jour qu'on venait de libérer et marquait repos celui où elle
    /// venait d'atterrir. Deux représentations de la même semaine, dont une seule avait bougé.
    @MainActor
    func testLaBandeSuitLesSeancesEtPasLesJoursDeCourse() throws {
        let p = UserProfile(name: "Test")
        p.goalId = .race
        p.raceDistance = .semi
        p.runningDays = [0, 2, 4]
        p.preferredLongRunDay = 4
        p.programStartDate = Date()
        p.raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())
        container.mainContext.insert(p)
        AdaptivePlanEngine.applyProgramSettingsChange(p)

        // Un jour qui n'est pas un jour de course : c'est précisément le genre de destination
        // qu'un déplacement sert à atteindre. Choisi AUJOURD'HUI OU PLUS TARD, parce qu'un jour
        // déjà passé est à juste titre marqué neutre même s'il porte une séance — il ne peut pas
        // être « à venir » s'il est fini. Sans ce choix, le test échouait un jour sur deux selon
        // la date à laquelle la CI tournait.
        let aujourdhui = AdaptivePlanEngine.currentWeekdayIndex()
        let arrivee = try XCTUnwrap([1, 3, 5, 6].first { $0 >= aujourdhui })
        let depart = try XCTUnwrap([0, 2, 4].first { $0 != arrivee })

        XCTAssertTrue(AdaptivePlanEngine.enregistrerDeplacement(de: depart, vers: arrivee, profile: p))
        XCTAssertNotNil(seance(p, arrivee), "la séance a bien atterri")
        XCTAssertNotEqual(p.weekStrip.first { $0.weekday == arrivee }?.state, .rest,
                          "un jour à venir qui porte une séance ne peut pas être marqué repos")
        XCTAssertEqual(p.weekStrip.first { $0.weekday == depart }?.state, .rest,
                       "le jour de départ a été libéré")
    }
}
