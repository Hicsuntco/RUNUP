import XCTest
@testable import RunUp

/// Verrouille ce que la pastille d'écart hebdomadaire ne doit plus faire.
///
/// LE DÉFAUT. `WeekKmSummary` soustrayait une semaine ENTIÈRE d'une semaine EN COURS. Le lundi
/// matin, quelqu'un parfaitement à jour de son plan lisait « ▼ 19,6 km » en ambre — la couleur
/// d'alerte du système — pour la seule raison qu'il n'avait pas encore couru cette semaine-là.
///
/// Il n'avait aucun symptôme technique : la valeur était juste, la soustraction correcte, les
/// deux nombres vrais. C'est ce qu'ils MESURAIENT qui ne se comparait pas.
final class SemaineComparableTests: XCTestCase {

    /// Un lundi à midi, pour que rien ne dépende de l'heure à laquelle les cas tournent.
    private func lundiMidi() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 2; c.hour = 12   // 2 mars 2026 est un lundi
        return Calendar.current.date(from: c) ?? .now
    }

    private func course(_ date: Date, _ km: Double) -> RunRecord {
        RunRecord(date: date, title: "Sortie", distanceKm: km, durationSeconds: Int(km * 330),
                  avgPace: "5:30", avgHeartRate: 150, kcal: Int(km * 62), elevationGainM: 0)
    }

    private func decalee(_ depuis: Date, jours: Int, heures: Int = 0) -> Date {
        Calendar.current.date(byAdding: DateComponents(day: jours, hour: heures), to: depuis) ?? depuis
    }

    // ── LE DÉFAUT LUI-MÊME ───────────────────────────────────────────────────────────────────

    func testLeLundiMatinPersonneNEstEnRetard() {
        let maintenant = lundiMidi()
        // La semaine passée : 20 km, mais répartis APRÈS le lundi midi — mercredi et samedi.
        let courses = [
            course(decalee(maintenant, jours: -5), 12),   // mercredi dernier
            course(decalee(maintenant, jours: -2), 8),    // samedi dernier
        ]
        let (cette, passee) = SemaineComparable.kilometres(courses, maintenant: maintenant)
        XCTAssertEqual(cette, 0, "aucune course cette semaine")
        XCTAssertEqual(passee, 0, accuracy: 0.001,
                       "au même point de la semaine passée, elle n'avait rien couru non plus — "
                       + "l'ancien calcul rendait 20 et affichait « ▼ 20,0 km » en ambre")
    }

    func testLEcartCompareLesMemesPortionsDeSemaine() {
        let maintenant = decalee(lundiMidi(), jours: 3)   // jeudi midi
        let courses = [
            // Cette semaine : lundi 5 km, mercredi 6 km.
            course(decalee(lundiMidi(), jours: 0, heures: 1), 5),
            course(decalee(lundiMidi(), jours: 2), 6),
            // La semaine passée, AVANT le même point : 9 km.
            course(decalee(lundiMidi(), jours: -6), 9),
            // La semaine passée, APRÈS le même point : 30 km, qui ne doivent PAS compter.
            course(decalee(lundiMidi(), jours: -2), 30),
        ]
        let (cette, passee) = SemaineComparable.kilometres(courses, maintenant: maintenant)
        XCTAssertEqual(cette, 11, accuracy: 0.001)
        XCTAssertEqual(passee, 9, accuracy: 0.001,
                       "les 30 km du week-end dernier sont postérieurs au point de comparaison")
    }

    // ── CE QUE LE CALCUL NE DOIT PAS PERDRE ──────────────────────────────────────────────────

    func testUneCourseAVenirNeComptePas() {
        let maintenant = decalee(lundiMidi(), jours: 2)
        let courses = [course(decalee(lundiMidi(), jours: 4), 10)]   // vendredi, pas encore couru
        let (cette, _) = SemaineComparable.kilometres(courses, maintenant: maintenant)
        XCTAssertEqual(cette, 0, "une course datée dans le futur n'est pas un kilomètre parcouru")
    }

    func testLHeureCompteDansLaComparaison() {
        // Même jour de la semaine, mais huit heures plus tôt la semaine passée : la course doit
        // compter. Deux heures plus tard : elle ne doit pas.
        let maintenant = decalee(lundiMidi(), jours: 3)
        let avant = [course(decalee(maintenant, jours: -7, heures: -8), 7)]
        let apres = [course(decalee(maintenant, jours: -7, heures: 2), 7)]
        XCTAssertEqual(SemaineComparable.kilometres(avant, maintenant: maintenant).passee,
                       7, accuracy: 0.001)
        XCTAssertEqual(SemaineComparable.kilometres(apres, maintenant: maintenant).passee,
                       0, accuracy: 0.001,
                       "comparer « jeudi 12 h » à tout le jeudi fausse l'écart d'une demi-journée, "
                       + "et toujours dans le même sens")
    }

    func testUneSemaineSansRienRendDeuxZeros() {
        let (cette, passee) = SemaineComparable.kilometres([], maintenant: lundiMidi())
        XCTAssertEqual(cette, 0)
        XCTAssertEqual(passee, 0)
    }

    func testLaFenetreComparableSArreteAuLundiPrecedent() {
        // Ce cas disait « dix jours en arrière, c'est l'avant-dernière semaine ». C'était faux, et
        // il a échoué sur CI : depuis un JEUDI, dix jours en arrière tombent sur le lundi de la
        // semaine passée, c'est-à-dire le PREMIER jour de la fenêtre comparable. Le code comptait
        // les 42 km, et il avait raison.
        //
        // Il est réécrit sur la borne elle-même plutôt que sur un nombre de jours compté de tête :
        // une seconde avant le début de la fenêtre, et une seconde après.
        let maintenant = decalee(lundiMidi(), jours: 3)       // un jeudi midi
        let debutDeLaFenetre = decalee(lundiMidi(), jours: -7) // le lundi d'avant, à midi
        let justeAvant = Calendar.current.startOfDay(for: debutDeLaFenetre).addingTimeInterval(-1)
        let justeApres = Calendar.current.startOfDay(for: debutDeLaFenetre).addingTimeInterval(1)

        let (_, dehors) = SemaineComparable.kilometres([course(justeAvant, 42)], maintenant: maintenant)
        XCTAssertEqual(dehors, 0, "une seconde avant le lundi, c'est l'avant-dernière semaine")

        let (_, dedans) = SemaineComparable.kilometres([course(justeApres, 42)], maintenant: maintenant)
        XCTAssertEqual(dedans, 42, accuracy: 0.001,
                       "le lundi de la semaine passée ouvre la fenêtre comparable")
    }

    func testDeuxSemainesEnArriereNeComptentNullePart() {
        let maintenant = decalee(lundiMidi(), jours: 3)
        let courses = [course(decalee(maintenant, jours: -14), 42)]
        let (cette, passee) = SemaineComparable.kilometres(courses, maintenant: maintenant)
        XCTAssertEqual(cette, 0)
        XCTAssertEqual(passee, 0)
    }
}
