import XCTest
@testable import RunUp

/// Verrouille ce qui sépare une sortie vélo d'une course — c'est-à-dire tout ce qui, sans ça,
/// deviendrait faux en silence le jour du premier coup de pédale.
///
/// L'app n'a longtemps su faire qu'une chose, donc aucune agrégation n'avait à préciser ce
/// qu'elle comptait. Treize sommaient des kilomètres, d'autres cherchaient la meilleure allure
/// ou la plus longue sortie, les chaussures accumulaient leur usure, le plan cochait la séance
/// du jour. Toutes avaient raison faute de concurrence. Quarante kilomètres de vélo les rendent
/// toutes fausses sans qu'une seule ligne ne casse.
final class DisciplineTests: XCTestCase {

    private func releve(_ d: Discipline, km: Double, secondes: Int, allure: String) -> RunRecord {
        RunRecord(title: "Sortie", distanceKm: km, durationSeconds: secondes,
                  avgPace: allure, avgHeartRate: 0, kcal: 0, discipline: d)
    }

    // MARK: - Ce que la discipline décide

    func testUneSortieVeloNUsePasLesChaussures() {
        XCTAssertTrue(Discipline.run.wearsShoes)
        XCTAssertFalse(Discipline.bike.wearsShoes)
    }

    /// Tant qu'il n'y a pas de plan triathlon, le plan est un plan de course : rouler le mardi
    /// ne doit pas valider le fractionné du mardi, sinon le moteur adapte la semaine suivante
    /// sur une séance qui n'a jamais eu lieu.
    func testRoulerNeCochePasLaSeanceDeCourse() {
        XCTAssertTrue(Discipline.run.completesRunningPlan)
        XCTAssertFalse(Discipline.bike.completesRunningPlan)
    }

    /// La série mesure l'assiduité, pas le kilométrage : une heure de vélo n'est pas un jour sans
    /// rien faire.
    func testLesDeuxDisciplinesComptentPourLaSerie() {
        XCTAssertTrue(Discipline.allCases.allSatisfy { $0.countsTowardStreak })
    }

    /// Un relevé écrit avant que ce champ n'existe est une course : l'app ne savait rien faire
    /// d'autre. Si ce défaut changeait, toute l'histoire basculerait de discipline d'un coup.
    func testLeDefautEstLaCourse() {
        let ancien = RunRecord(title: "Footing", distanceKm: 5, durationSeconds: 1800,
                               avgPace: "6:00", avgHeartRate: 0, kcal: 0)
        XCTAssertEqual(ancien.discipline, .run)
        XCTAssertEqual(Discipline.legacy, .run)
    }

    // MARK: - Le filtre, et ce qu'il empêche

    func testOnlyNeGardeQueLaDisciplineDemandee() {
        let tout = [releve(.run, km: 5, secondes: 1800, allure: "6:00"),
                    releve(.bike, km: 40, secondes: 5400, allure: "2:15"),
                    releve(.run, km: 7, secondes: 2700, allure: "6:26")]
        XCTAssertEqual(tout.only(.run).count, 2)
        XCTAssertEqual(tout.only(.bike).count, 1)
        XCTAssertEqual(tout.allDisciplines.count, 3)
    }

    /// LE DÉFAUT CENTRAL, en une mesure. Quarante kilomètres de vélo doublaient la distance
    /// courue du mois.
    func testLeVeloNEntrePasDansLaDistanceCourue() {
        let tout = [releve(.run, km: 5, secondes: 1800, allure: "6:00"),
                    releve(.run, km: 7, secondes: 2700, allure: "6:26"),
                    releve(.bike, km: 40, secondes: 5400, allure: "2:15")]
        let courues = tout.only(.run).reduce(0) { $0 + $1.distanceKm }
        XCTAssertEqual(courues, 12, accuracy: 0.001)
        XCTAssertEqual(tout.allDisciplines.reduce(0) { $0 + $1.distanceKm }, 52, accuracy: 0.001)
    }

    /// Et le record d'allure, qu'une seule sortie vélo aurait emporté pour toujours : 2:15 au
    /// kilomètre, c'est 26 km/h, et aucune course ne le reprendra jamais.
    func testLeVeloNEmportePasLeRecordDAllure() throws {
        let tout = [releve(.run, km: 5, secondes: 1800, allure: "6:00"),
                    releve(.bike, km: 40, secondes: 5400, allure: "2:15")]
        let meilleure = tout.only(.run).compactMap { PaceModel.parseSecPerKm($0.avgPace) }.min()
        XCTAssertEqual(try XCTUnwrap(meilleure), 360, accuracy: 0.001)
    }

    // MARK: - Ce qui se lit, et dans quelle unité

    func testLaCourseSeLitEnAllureEtLeVeloEnVitesse() {
        let course = TimeFormat.rythme(.run, secondesParKm: 360)
        XCTAssertEqual(course.valeur, "6:00")
        XCTAssertEqual(course.unite, "/KM")

        let velo = TimeFormat.rythme(.bike, secondesParKm: 150)   // 150 s/km = 24 km/h
        XCTAssertEqual(velo.unite, "KM/H")
        XCTAssertEqual(Double(velo.valeur.replacingOccurrences(of: ",", with: ".")) ?? 0, 24, accuracy: 0.05)
    }

    /// Le libellé et l'unité sont maintenant portés par la discipline, parce que la Live Activity
    /// en a besoin : c'est une extension, un processus séparé qui ne peut rien lire de l'app. Elle
    /// écrivait « Allure » et « /km » EN DUR, sous un chiffre devenu des kilomètres-heure dès
    /// qu'on roule.
    ///
    /// LES LIBELLÉS NE SONT PAS COMPARÉS À DU FRANÇAIS. La première version de ce test exigeait
    /// « Allure » et « Vitesse », et elle a échoué en intégration continue : le simulateur tourne
    /// en anglais, donc `String(localized:)` rend « Pace » et « Speed ». Le code était juste, le
    /// test était écrit depuis un seul pays — la même faute que la comparaison de semaines, qui a
    /// déjà coûté un build dans cette session.
    ///
    /// Ce qui se vérifie ici est la RÈGLE, pas sa traduction : la route et le trail disent la même
    /// chose, le vélo dit autre chose, et personne ne dit rien. Les unités, elles, ne passent pas
    /// par le catalogue — « km » est « km » partout — donc elles se comparent au mot près.
    func testChaqueDisciplineNommeSaMesureDeRythme() {
        XCTAssertEqual(Discipline.run.rythmeUnite, "/km")
        XCTAssertEqual(Discipline.bike.rythmeUnite, "km/h")
        // Le trail se lit en allure comme la route : l'allure y est erratique, mais c'est bien
        // une allure, et la convertir en km/h ne la rendrait pas plus lisible.
        XCTAssertEqual(Discipline.trail.rythmeUnite, "/km")

        XCTAssertEqual(Discipline.trail.rythmeLabel, Discipline.run.rythmeLabel,
                       "le trail et la route mesurent la même chose")
        XCTAssertNotEqual(Discipline.bike.rythmeLabel, Discipline.run.rythmeLabel,
                          "le vélo ne mesure pas une allure")
        for discipline in Discipline.allCases {
            XCTAssertFalse(discipline.rythmeLabel.isEmpty, "\(discipline) sans libellé")
            XCTAssertFalse(discipline.rythmeLabelMajuscules.isEmpty, "\(discipline) sans capitales")
        }
    }

    /// Et `TimeFormat` ne recopie plus l'unité : il met celle de la discipline en capitales. Deux
    /// écritures d'un même symbole finissent toujours par diverger.
    func testLUniteDeTimeFormatEstCelleDeLaDiscipline() {
        for discipline in Discipline.allCases {
            XCTAssertEqual(TimeFormat.rythme(discipline, secondesParKm: 300).unite,
                           discipline.rythmeUnite.uppercased(),
                           "\(discipline) : l'unité doit venir de la discipline")
        }
    }

    /// La Live Activity porte la discipline dans ses ATTRIBUTS — fixée au départ, elle ne change
    /// pas en cours de sortie. Et elle est optionnelle : une activité démarrée par la version
    /// précédente de l'app n'a pas la clé, et doit se décoder quand même.
    func testLaLiveActivitySaitDeQuelleDisciplineElleParle() {
        let velo = RunActivityAttributes(sessionTitle: "Sortie", plannedDurationMinutes: 60,
                                         disciplineRaw: Discipline.bike.rawValue)
        XCTAssertEqual(velo.discipline, .bike)
        XCTAssertEqual(velo.discipline.rythmeUnite, "km/h",
                       "c'est ce que l'île dynamique écrira sous le chiffre")

        let ancienne = RunActivityAttributes(sessionTitle: "Sortie", plannedDurationMinutes: 60)
        XCTAssertEqual(ancienne.discipline, .run, "sans discipline écrite, c'est une course")
    }

    /// Pas d'allure, pas de vitesse — et surtout pas l'infini qu'une division par zéro donnerait.
    func testSansAllureIlNyAPasDeVitesse() {
        XCTAssertEqual(TimeFormat.vitesse(secondesParKm: 0), "—")
        XCTAssertEqual(TimeFormat.vitesse(secondesParKm: -3), "—")
    }

    // MARK: - Les calories, et les seuils de pause

    /// À vélo la distance ne dit rien : une descente de cinq kilomètres ne coûte rien, les cinq
    /// de la montée coûtent dix fois plus. C'est la durée qui porte l'estimation.
    func testLesCaloriesDuVeloSuiventLaDureePasLaDistance() {
        let plat = Calories.estimate(.bike, distanceKm: 40, durationMinutes: 90)
        let colMemeDuree = Calories.estimate(.bike, distanceKm: 18, durationMinutes: 90)
        XCTAssertEqual(plat, colMemeDuree, accuracy: 0.001)
        XCTAssertEqual(plat, 90 * Calories.perCyclingMinute, accuracy: 0.001)
        // La course, elle, ne change pas de règle.
        XCTAssertEqual(Calories.estimate(.run, distanceKm: 10, durationMinutes: 60),
                       Calories.estimate(distanceKm: 10, durationMinutes: 60), accuracy: 0.001)
    }

    /// Entre la course et le vélo : être arrêtée, c'est être arrêtée — mais REPARTIR n'a pas le
    /// même seuil, 1,3 m/s étant une marche rapide qu'une cycliste repasse au moindre coup de
    /// pédale dans un embouteillage.
    ///
    /// Le trail fait exception sur le seuil de PAUSE, et il a sa propre série de tests plus bas :
    /// dans une pente raide, avancer vraiment se fait sous 0,6 m/s.
    func testLesSeuilsDeRepriseDifferentMaisPasCeluiDePause() {
        let course = AutoPause.Seuils.pour(.run), velo = AutoPause.Seuils.pour(.bike)
        XCTAssertEqual(course.pause, velo.pause)
        XCTAssertGreaterThan(velo.reprise, course.reprise)
        XCTAssertGreaterThan(velo.eloignement, course.eloignement)
    }

    /// Vingt-cinq mètres se parcourent en trois secondes à vingt-cinq à l'heure : la deuxième
    /// preuve de reprise ne prouverait plus rien à vélo.
    func testUnVeloALArretNeRepartPasSurVingtCinqMetres() {
        let velo = AutoPause.Seuils.pour(.bike)
        XCTAssertFalse(AutoPause.shouldResume(speed: 0.2, metersSincePause: 25, seuils: velo))
        XCTAssertTrue(AutoPause.shouldResume(speed: 0.2, metersSincePause: 70, seuils: velo))
        XCTAssertFalse(AutoPause.shouldResume(speed: 1.5, metersSincePause: 0, seuils: velo))
        XCTAssertTrue(AutoPause.shouldResume(speed: 4.0, metersSincePause: 0, seuils: velo))
    }

    /// Et la règle de course n'a pas bougé d'un cran au passage.
    func testLaRegleDeCourseEstInchangee() {
        XCTAssertTrue(AutoPause.shouldResume(speed: 1.5, metersSincePause: 0))
        XCTAssertTrue(AutoPause.shouldResume(speed: nil, metersSincePause: 30))
        XCTAssertFalse(AutoPause.shouldResume(speed: nil, metersSincePause: 10))
    }

    // MARK: - Le trail

    /// Le trail est de la COURSE : il use les chaussures et il coche la séance du jour. C'est tout
    /// l'inverse du vélo, et c'est ce qu'un `self == .run` aurait silencieusement inversé.
    func testLeTrailEstDeLaCourse() {
        XCTAssertTrue(Discipline.trail.wearsShoes)
        XCTAssertTrue(Discipline.trail.completesRunningPlan)
        XCTAssertTrue(Discipline.trail.countsTowardStreak)
        XCTAssertTrue(Discipline.trail.seLitEnAllure)
    }

    /// Mais il ne VISE pas d'allure, et c'est la distinction que le trail a rendue nécessaire :
    /// 5:10/km ne veut rien dire quand la même foulée donne 4:20 sur le plat et 9:30 dans une
    /// montée à 15 %. Un seul booléen aurait donné, au choix, une sortie trail qui ne compte pas
    /// dans le plan, ou une voix qui annonce « trop lente » pendant toute l'ascension.
    func testLeTrailCocheLaSeanceSansViserDAllure() {
        XCTAssertTrue(Discipline.trail.completesRunningPlan)
        XCTAssertFalse(Discipline.trail.followsPaceTargets)
        // La course, elle, fait les deux — et le vélo ni l'un ni l'autre.
        XCTAssertTrue(Discipline.run.completesRunningPlan)
        XCTAssertTrue(Discipline.run.followsPaceTargets)
        XCTAssertFalse(Discipline.bike.completesRunningPlan)
        XCTAssertFalse(Discipline.bike.followsPaceTargets)
    }

    /// Marcher une montée raide n'est pas une interruption. À 15 % de pente, avancer se fait à
    /// deux kilomètres-heure, soit 0,55 m/s — juste SOUS le seuil de pause de la route. L'app se
    /// serait mise en pause toute seule sur la portion la plus dure de la sortie.
    func testMarcherUneMonteeRaideNeDeclenchePasLaPause() {
        let trail = AutoPause.Seuils.pour(.trail)
        XCTAssertLessThan(trail.pause, 0.55,
                          "Deux km/h en montée doivent rester au-dessus du seuil de pause")
        XCTAssertLessThan(trail.pause, AutoPause.Seuils.pour(.run).pause)
    }

    /// Et une relance au pas lève la pause : en trail, marcher EST une progression.
    func testUneRelanceAuPasLevueLaPauseEnTrail() {
        let trail = AutoPause.Seuils.pour(.trail)
        XCTAssertTrue(AutoPause.shouldResume(speed: 1.1, metersSincePause: 0, seuils: trail))
        XCTAssertFalse(AutoPause.shouldResume(speed: 1.1, metersSincePause: 0,
                                              seuils: AutoPause.Seuils.pour(.run)))
    }

    /// Une sortie trail entre dans la distance COURUE — contrairement au vélo. C'est l'autre
    /// moitié de `only(_:)` : il ne s'agit pas d'exclure tout ce qui n'est pas `.run`.
    ///
    /// LE DÉFAUT QUE `onFoot` CORRIGE. Les quinze agrégations de l'app disaient `.only(.run)`,
    /// et c'était juste tant que la seule autre discipline était le vélo : « de la course » et
    /// « pas du vélo » désignaient le même ensemble. Le trail les sépare, et il est arrivé en ne
    /// comptant NULLE PART — ni dans la distance du mois, ni dans les statistiques, ni dans les
    /// badges, ni dans l'usure des chaussures. Pendant que `Discipline.trail.wearsShoes`
    /// affirmait le contraire, deux fichiers plus loin.
    func testLeTrailEntreDansLaDistanceCourue() {
        let releves = [releve(.run, km: 10, secondes: 3000, allure: "5:00"),
                       releve(.trail, km: 12, secondes: 5400, allure: "7:30"),
                       releve(.bike, km: 40, secondes: 4800, allure: "1:12")]
        XCTAssertEqual(releves.onFoot.map(\.distanceKm).reduce(0, +), 22, accuracy: 0.001,
                       "la route et le trail, pas le vélo")
        XCTAssertEqual(releves.only(.run).map(\.distanceKm).reduce(0, +), 10, accuracy: 0.001,
                       "`only(.run)` reste la route seule — c'est ce qu'il faut pour l'allure")
        XCTAssertEqual(releves.allDisciplines.count, 3)
    }

    // MARK: - La natation

    /// UN NAGEUR SE LIT AUX CENT MÈTRES, JAMAIS AU KILOMÈTRE.
    ///
    /// C'est ce qu'un booléen ne savait pas dire : `usesPacePerKm` n'avait que deux réponses, et
    /// la nage en demande une troisième. Vrai, et l'unité affichée devenait « /km » sur un
    /// chiffre qui est aux cent mètres ; faux, et la nage s'affichait en kilomètres-heure.
    ///
    /// La valeur est comparée, pas seulement l'unité : c'est la division par dix qui fait tout le
    /// travail, et une unité juste sur un chiffre au kilomètre serait le pire des deux mondes.
    func testLaNageSeLitEnMinutesAuxCentMetres() {
        XCTAssertEqual(Discipline.swim.rythmeUnite, "/100 m")
        XCTAssertTrue(Discipline.swim.seLitEnAllure, "une nage est une allure, pas une vitesse")

        // 1 150 s/km, soit 115 s aux cent mètres : l'allure d'une nageuse ordinaire.
        let lu = TimeFormat.rythme(.swim, secondesParKm: 1150)
        XCTAssertEqual(lu.valeur, "1:55")
        XCTAssertEqual(lu.unite, "/100 M")
        // La même allure au kilomètre s'écrirait « 19:10 » — juste, et illisible pour un nageur.
        XCTAssertEqual(TimeFormat.rythme(.run, secondesParKm: 1150).valeur, "19:10")

        // Les trois unités sont trois unités : deux disciplines qui rendraient la même ne
        // justifieraient pas l'énumération.
        let unites = Set([Discipline.run, .bike, .swim].map(\.rythmeUnite))
        XCTAssertEqual(unites.count, 3)
    }

    /// Et elle ne compte nulle part où la course compte.
    ///
    /// Le défaut que `Discipline` existe pour empêcher, dans sa version natation : quarante
    /// longueurs entrant dans la distance courue du mois, une paire de chaussures vieillissant
    /// au chlore, et la séance de course du jour cochée par une heure de bassin.
    func testLaNageNeCompteNullePartOuLaCourseCompte() {
        XCTAssertFalse(Discipline.swim.wearsShoes)
        XCTAssertFalse(Discipline.swim.completesRunningPlan)
        XCTAssertFalse(Discipline.swim.followsPaceTargets)
        // Mais elle compte pour l'assiduité : une heure de bassin n'est pas rien.
        XCTAssertTrue(Discipline.swim.countsTowardStreak)

        let releves = [releve(.run, km: 10, secondes: 3000, allure: "5:00"),
                       releve(.trail, km: 12, secondes: 5400, allure: "7:30"),
                       releve(.swim, km: 2, secondes: 2400, allure: "20:00")]
        XCTAssertEqual(releves.onFoot.map(\.distanceKm).reduce(0, +), 22, accuracy: 0.001,
                       "les deux kilomètres nagés n'entrent pas dans la distance courue")
        XCTAssertTrue(releves.only(.swim).count == 1, "mais ils se retrouvent par leur discipline")
    }

    /// Elle ne se démarre pas depuis le téléphone, et c'est le cadran qui lit ce drapeau.
    ///
    /// Il n'y a pas de GPS sous l'eau, le téléphone n'entre pas dans le bassin, et une longueur
    /// ne se compte qu'au poignet. Une nage entre par Apple Santé ou à la main — et un bouton qui
    /// démarrerait une course ne mesurant rien est le genre de chose qu'on découvre au bord d'un
    /// bassin, maillot mouillé.
    func testSeulesLesDisciplinesSuiviesParGPSSeDemarrent() {
        for discipline in Discipline.allCases {
            XCTAssertEqual(discipline.seDemarreDepuisLeTelephone, discipline != .swim,
                           "\(discipline)")
        }
        XCTAssertEqual(Discipline.demarrables, [.run, .bike, .trail])
        XCTAssertFalse(Discipline.demarrables.contains(.swim))
    }

    /// Les chaussures s'usent en trail. Le drapeau le disait déjà ; plus personne ne le
    /// contredit.
    func testLesChaussuresSUsentEnTrail() {
        let chaussure = Shoe(name: "Test", startDistanceKm: 0)
        let releves = [releve(.run, km: 10, secondes: 3000, allure: "5:00"),
                       releve(.trail, km: 12, secondes: 5400, allure: "7:30"),
                       releve(.bike, km: 40, secondes: 4800, allure: "1:12")]
        for r in releves { r.shoeID = chaussure.id }
        XCTAssertEqual(chaussure.totalKm(runs: releves), 22, accuracy: 0.001)
    }

    /// Chaque discipline a un libellé, une icône et une phrase de bascule. Aucune ne doit se
    /// retrouver avec une chaîne vide parce qu'un `switch` a été complété à moitié.
    ///
    /// Et ce test porte plus loin qu'il n'y paraît depuis que le panneau de choix existe : il
    /// dessine une ligne par `Discipline.allCases`, donc une discipline ajoutée sans libellé
    /// s'afficherait comme une case vide et touchable.
    func testChaqueDisciplineEstNommeePartout() {
        for discipline in Discipline.allCases {
            XCTAssertFalse(discipline.title.isEmpty, "\(discipline) n'a pas de titre")
            XCTAssertFalse(discipline.tabLabel.isEmpty, "\(discipline) n'a pas de libellé court")
            XCTAssertFalse(discipline.sfSymbol.isEmpty, "\(discipline) n'a pas d'icône")
            XCTAssertFalse(discipline.switchToLabel.isEmpty, "\(discipline) n'a pas de phrase de bascule")
        }
    }
}
