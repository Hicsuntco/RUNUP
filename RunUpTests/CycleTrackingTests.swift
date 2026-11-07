import XCTest
@testable import RunUp

/// Verrouille le réancrage du suivi du cycle.
///
/// La phase pilote `AdaptivePlanEngine.adjustForWellbeing`, donc la charge d'entraînement proposée.
/// Une moyenne qui apprendrait trop vite, ou une date réancrée sur une saisie aberrante, ne se
/// verrait pas à l'écran — elle se verrait dans un programme trop dur au mauvais moment du mois.
final class CycleTrackingTests: XCTestCase {

    private func date(_ daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    /// Premier enregistrement : rien à apprendre, on pose la date.
    func testFirstRecordingJustSetsTheDate() {
        let now = Date()
        let result = CycleTracking.recordingPeriodStart(lastStart: nil, averageLength: 28, newStart: now)
        XCTAssertEqual(result.lastStart, now)
        XCTAssertEqual(result.averageLength, 28)
    }

    /// La moyenne apprend à MOITIÉ de l'écart observé.
    ///
    /// Un cycle décalé par un voyage, une maladie ou un stress ne doit pas redéfinir la moyenne à
    /// lui seul. Vingt-huit attendus, trente-deux observés : la moyenne va à trente, pas à
    /// trente-deux. Une vraie tendance s'installe en deux ou trois cycles, un accident isolé
    /// s'efface au suivant.
    func testAverageLearnsHalfOfTheObservedGap() {
        let result = CycleTracking.recordingPeriodStart(
            lastStart: date(32), averageLength: 28, newStart: Date()
        )
        XCTAssertEqual(result.averageLength, 30)
    }

    /// Un écart hors de 15–60 jours n'est pas un cycle : c'est une correction de saisie, une
    /// reprise après interruption, ou deux appuis rapprochés. On réancre la date sans rien
    /// apprendre — une moyenne inchangée vaut mieux qu'une moyenne fausse.
    func testImplausibleGapsTeachNothing() {
        let now = Date()
        let tooShort = CycleTracking.recordingPeriodStart(lastStart: date(3), averageLength: 28, newStart: now)
        XCTAssertEqual(tooShort.averageLength, 28)
        XCTAssertEqual(tooShort.lastStart, now, "la date est réancrée quand même")

        let tooLong = CycleTracking.recordingPeriodStart(lastStart: date(120), averageLength: 28, newStart: now)
        XCTAssertEqual(tooLong.averageLength, 28)
        XCTAssertEqual(tooLong.lastStart, now)
    }

    /// Deux appuis le même jour ne doivent rien casser.
    func testSameDayRecordingIsHarmless() {
        let now = Date()
        let result = CycleTracking.recordingPeriodStart(lastStart: now, averageLength: 28, newStart: now)
        XCTAssertEqual(result.averageLength, 28)
        XCTAssertEqual(result.lastStart, now)
    }

    /// La durée stockée reste dans les bornes que `UserProfile.cyclePhase` applique de son côté.
    ///
    /// Sans cet écrêtage à l'écriture, le réglage afficherait « 38 jours » pendant que le calcul de
    /// phase en utiliserait 35 : un nombre visible que l'app n'utilise pas.
    func testStoredLengthStaysWithinTheBoundsThePhaseCalculationUses() {
        let long = CycleTracking.recordingPeriodStart(lastStart: date(58), averageLength: 35, newStart: Date())
        XCTAssertLessThanOrEqual(long.averageLength, 35)

        let short = CycleTracking.recordingPeriodStart(lastStart: date(16), averageLength: 21, newStart: Date())
        XCTAssertGreaterThanOrEqual(short.averageLength, 21)

        XCTAssertEqual(CycleTracking.clamped(12), 21)
        XCTAssertEqual(CycleTracking.clamped(99), 35)
    }

    // MARK: - La phase estimée : quel jour, et quel jour du cycle

    /// Un profil qui suit son cycle, les règles ayant commencé il y a `ilYaNJours`.
    private func suivie(cycle: Int = 28, ilYaNJours: Int, jours: [Int] = [0, 1, 2, 3, 4, 5, 6]) -> UserProfile {
        let profil = UserProfile(name: "Test")
        profil.cycleTrackingEnabled = true
        profil.averageCycleLengthDays = cycle
        profil.lastPeriodStartDate = date(ilYaNJours)
        profil.runningDays = jours
        profil.preferredLongRunDay = jours.max()
        return profil
    }

    /// L'OVULATION SE COMPTE DEPUIS LA FIN DU CYCLE, PAS DEPUIS SON MILIEU.
    ///
    /// C'est la phase lutéale — de l'ovulation aux règles suivantes — qui dure à peu près
    /// toujours quatorze jours ; c'est la phase folliculaire qui s'allonge ou se raccourcit.
    /// L'ancien calcul posait l'ovulation à la moitié du cycle, ce qui tombe juste pour
    /// vingt-huit jours et faux partout ailleurs — d'autant plus faux que le cycle s'en éloigne,
    /// c'est-à-dire exactement pour celles dont le cycle n'est pas celui du manuel.
    func testOvulationIsCountedBackFromTheEndOfTheCycle() {
        for (longueur, jourAttendu) in [(21, 7), (28, 14), (35, 21)] {
            let profil = suivie(cycle: longueur, ilYaNJours: jourAttendu - 1)
            XCTAssertEqual(profil.cyclePhase, .ovulation,
                           "cycle de \(longueur) jours : l'ovulation est attendue au jour \(jourAttendu)")
        }

        // Et le milieu du cycle — l'ancien calcul — n'est plus l'ovulation dès qu'on s'éloigne
        // de vingt-huit jours : jour 10 sur un cycle de 21, jour 17 sur un cycle de 35.
        XCTAssertNotEqual(suivie(cycle: 21, ilYaNJours: 9).cyclePhase, .ovulation,
                          "cycle de 21 jours : le jour 10 est en phase lutéale, l'ovulation est passée")
        XCTAssertNotEqual(suivie(cycle: 35, ilYaNJours: 16).cyclePhase, .ovulation,
                          "cycle de 35 jours : le jour 17 est encore folliculaire")
    }

    /// La phase est calculée POUR LE JOUR DEMANDÉ.
    ///
    /// Sans ce paramètre, le plan de la semaine recopiait la phase du jour où l'app s'ouvrait sur
    /// les sept jours — et sur toutes les semaines suivantes, que l'écran du plan prévisualise.
    func testPhaseIsComputedForTheDayAskedNotForToday() {
        let profil = suivie(ilYaNJours: 4) // aujourd'hui : jour 5, dernier jour des règles
        XCTAssertEqual(profil.cyclePhase, .menstrual)
        XCTAssertEqual(profil.cyclePhase(on: date(-3)), .follicular, "jour 8")
        XCTAssertEqual(profil.cyclePhase(on: date(-9)), .ovulation, "jour 14")
        XCTAssertEqual(profil.cyclePhase(on: date(-20)), .luteal, "jour 25")
        // Un jour ANTÉRIEUR au début des règles saisi : on n'invente pas de phase.
        XCTAssertNil(profil.cyclePhase(on: date(10)))
    }

    /// L'HEURE DE LA SAISIE NE DÉCALE PAS LE CYCLE.
    ///
    /// `dateComponents([.day])` tronque : des règles enregistrées à 23 h 30 et un jour de séance
    /// qui vaut minuit étaient séparés de « −1 jour », donc la phase valait `nil` — aucune
    /// adaptation — le jour même où elle venait de l'enregistrer.
    func testTimeOfDayOfTheRecordedStartDoesNotShiftTheCycle() {
        let cal = Calendar.current
        let profil = UserProfile(name: "Test")
        profil.cycleTrackingEnabled = true
        profil.lastPeriodStartDate = cal.date(bySettingHour: 23, minute: 30, second: 0, of: Date())
        let memeJourAuPetitMatin = cal.date(bySettingHour: 1, minute: 0, second: 0, of: Date())!
        XCTAssertEqual(profil.cyclePhase(on: memeJourAuPetitMatin), .menstrual,
                       "le jour de la saisie, la phase doit être le jour 1 du cycle, pas rien")
    }

    // MARK: - Ce que la phase change dans la semaine générée

    /// Les quatre notes, telles que `AdaptivePlanEngine` les écrit. Recopiées ici exprès : ce sont
    /// des clés du catalogue de traduction, et les changer sans le vouloir sortirait la phrase en
    /// français chez tout le monde.
    private func noteAttendue(_ phase: UserProfile.CyclePhase?) -> String? {
        switch phase {
        case .menstrual: return "phase menstruelle estimée · allégée, à juger au ressenti"
        case .follicular: return "phase folliculaire estimée · à juger au ressenti"
        case .ovulation: return "ovulation estimée · à juger au ressenti"
        case .luteal: return "phase lutéale estimée · à juger au ressenti"
        case nil: return nil
        }
    }

    private var lundiCalendrier: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    /// Le lundi de la semaine en cours — le même que celui du moteur.
    private var lundi: Date {
        lundiCalendrier.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    /// CHAQUE NOTE CORRESPOND À LA PHASE DE SON PROPRE JOUR.
    ///
    /// La semaine est ancrée sur un lundi qui est le premier jour du cycle : les règles tiennent
    /// jusqu'au vendredi, le week-end est déjà folliculaire. Une note recopiée depuis « la phase
    /// d'aujourd'hui » serait donc fausse au moins deux jours sur sept.
    func testEachNoteMatchesThePhaseOfItsOwnDay() {
        let profil = suivie(ilYaNJours: 0)
        profil.lastPeriodStartDate = lundi
        profil.programStartDate = lundi

        let semaine = AdaptivePlanEngine.generateWeekSessions(weekNumber: 1, tier: 1, profile: profil)
        let phases = Set((0..<7).compactMap { jour -> UserProfile.CyclePhase? in
            lundiCalendrier.date(byAdding: .day, value: jour, to: lundi)
                .flatMap { profil.cyclePhase(on: $0) }
        })
        XCTAssertGreaterThan(phases.count, 1, "l'ancrage de ce test doit traverser un changement de phase")

        var notees = 0
        for jour in semaine {
            guard let note = jour.session?.adaptationNote else { continue }
            notees += 1
            let date = lundiCalendrier.date(byAdding: .day, value: jour.weekday, to: lundi)
            XCTAssertEqual(note, noteAttendue(date.flatMap { profil.cyclePhase(on: $0) }),
                           "jour \(jour.weekday) : la note ne dit pas la phase de ce jour-là")
        }
        XCTAssertGreaterThan(notees, 0, "aucune séance ne porte de note : le test ne vérifie rien")
    }

    /// LA SORTIE LONGUE N'EST PLUS RABOTÉE PAR LA PHASE, ni le footing.
    ///
    /// L'allègement valait 15 % sur TOUTE la semaine menstruelle. La meilleure synthèse
    /// disponible (McNulty et al., Sports Medicine 2020 : soixante-dix-huit études) mesure un
    /// effet TRIVIAL et recommande une approche individuelle — pas de quoi retirer un quart
    /// d'heure à une sortie longue au nom d'une moyenne de groupe. Il ne reste que 10 % sur la
    /// séance de qualité, la seule dont l'intensité se discute.
    func testOnlyTheQualitySessionIsEasedAndOnlyAroundThePeriod() {
        let temoin = suivie(ilYaNJours: 0)
        temoin.cycleTrackingEnabled = false
        temoin.lastPeriodStartDate = lundi
        temoin.programStartDate = lundi

        let suivi = suivie(ilYaNJours: 0)
        suivi.lastPeriodStartDate = lundi
        suivi.programStartDate = lundi

        let sans = AdaptivePlanEngine.generateWeekSessions(weekNumber: 1, tier: 1, profile: temoin)
        let avec = AdaptivePlanEngine.generateWeekSessions(weekNumber: 1, tier: 1, profile: suivi)

        for (a, b) in zip(sans, avec) {
            XCTAssertEqual(a.weekday, b.weekday)
            guard let seanceSans = a.session, let seanceAvec = b.session else { continue }
            if seanceAvec.adaptationNote == nil {
                XCTAssertEqual(seanceAvec.durationMinutes, seanceSans.durationMinutes,
                               "jour \(b.weekday) : une séance sans note a changé de durée en silence")
            } else {
                XCTAssertLessThanOrEqual(seanceAvec.durationMinutes, seanceSans.durationMinutes,
                                         "jour \(b.weekday)")
            }
        }

        // La sortie longue porte la plus grosse charge de la semaine : c'est elle que l'ancien
        // allègement rabotait sans le dire, et c'est elle qu'on vérifie nommément.
        let jourLong = suivi.preferredLongRunDay
        let longueSans = sans.first { $0.weekday == jourLong }?.session?.durationMinutes
        let longueAvec = avec.first { $0.weekday == jourLong }?.session?.durationMinutes
        XCTAssertEqual(longueAvec, longueSans, "la sortie longue ne doit plus dépendre de la phase")
        XCTAssertNotNil(longueAvec)
    }

    /// Hors des règles, la charge de la semaine est EXACTEMENT celle de quelqu'un qui ne suit pas
    /// son cycle. La phase s'écrit dans la note, elle ne se retranche plus de la durée.
    func testOutsideThePeriodNothingIsEasedAtAll() {
        let cal = lundiCalendrier
        // Le lundi tombe au jour 6 du cycle : la semaine entière est folliculaire puis ovulatoire.
        let debutRegles = cal.date(byAdding: .day, value: -5, to: lundi)

        let temoin = suivie(ilYaNJours: 0)
        temoin.cycleTrackingEnabled = false
        temoin.lastPeriodStartDate = debutRegles
        temoin.programStartDate = lundi

        let suivi = suivie(ilYaNJours: 0)
        suivi.lastPeriodStartDate = debutRegles
        suivi.programStartDate = lundi

        XCTAssertNil((0..<7).compactMap {
            cal.date(byAdding: .day, value: $0, to: lundi).flatMap { suivi.cyclePhase(on: $0) }
        }.first { $0 == .menstrual }, "l'ancrage de ce test ne doit traverser aucun jour de règles")

        let sans = AdaptivePlanEngine.generateWeekSessions(weekNumber: 1, tier: 1, profile: temoin)
        let avec = AdaptivePlanEngine.generateWeekSessions(weekNumber: 1, tier: 1, profile: suivi)
        XCTAssertEqual(sans.map { $0.session?.durationMinutes }, avec.map { $0.session?.durationMinutes })
    }

    /// Une note déjà posée pour une raison plus forte n'est pas écrasée par la phase.
    ///
    /// La blessure allège de 30 % et le dit ; la phase écrivait par-dessus, et la coureuse lisait
    /// « phase lutéale estimée » sur une séance raccourcie pour son genou.
    func testAnInjuryNoteSurvivesTheCyclePhase() {
        let profil = suivie(ilYaNJours: 0)
        profil.lastPeriodStartDate = lundi
        profil.programStartDate = lundi
        profil.injuryArea = "knee"
        profil.injuryWhen = AncienneteBlessure.enCours.rawValue

        let semaine = AdaptivePlanEngine.generateWeekSessions(weekNumber: 1, tier: 1, profile: profil)
        let notes = semaine.compactMap { $0.session?.adaptationNote }
        XCTAssertFalse(notes.isEmpty, "une blessure récente doit alléger au moins une séance")
        for note in notes {
            XCTAssertFalse(note.contains("phase") && note.contains("estimée"),
                           "la phase a écrasé la note de la blessure : « \(note) »")
        }
    }
}
