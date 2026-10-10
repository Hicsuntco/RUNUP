import XCTest
@testable import RunUp

/// L'accord en genre.
///
/// RUNUP tutoie, et le tutoiement français s'accorde. L'app était écrite au féminin de bout en
/// bout — c'est sa voix, et c'est délibéré. Mais un homme qui répond « Homme » à la question du
/// profil, et à qui l'app répond « tu es seule dans ce club », n'a pas affaire à une voix : il a
/// affaire à une app qui ne l'a pas écouté.
final class AccordTests: XCTestCase {

    override func tearDown() {
        AccordStore.shared.genre = .feminin
        super.tearDown()
    }

    /// Seul « male » donne le masculin.
    ///
    /// « Je préfère ne pas dire » garde le féminin, et c'est un choix écrit : le français n'a pas
    /// de troisième forme, donc il faut trancher. Mettre le masculin par défaut changerait la
    /// voix de l'app pour toutes celles qui ont répondu ça depuis le début — elles voient le
    /// féminin aujourd'hui. Le masculin reste une adaptation pour qui l'a demandée.
    func testSeulHommeDonneLeMasculin() {
        XCTAssertEqual(Genre.depuis(sexe: "male"), .masculin)
        XCTAssertEqual(Genre.depuis(sexe: "female"), .feminin)
        XCTAssertEqual(Genre.depuis(sexe: "unspecified"), .feminin)
        XCTAssertEqual(Genre.depuis(sexe: nil), .feminin)
        // Une valeur inconnue ne doit pas donner le masculin par accident.
        XCTAssertEqual(Genre.depuis(sexe: "Male"), .feminin)
        XCTAssertEqual(Genre.depuis(sexe: ""), .feminin)
    }

    /// Le choix suit le magasin, dans les deux sens.
    func testLeChoixSuitLeGenreEnCours() {
        AccordStore.shared.genre = .feminin
        XCTAssertEqual(Accord.selon(f: "partie", m: "parti"), "partie")
        AccordStore.shared.genre = .masculin
        XCTAssertEqual(Accord.selon(f: "partie", m: "parti"), "parti")
    }

    /// CE QUI N'EST PAS TESTÉ ICI, ET POURQUOI.
    ///
    /// La première version de ce fichier vérifiait que `ExperienceLevel.debutante.title` vaut
    /// « Débutante » au féminin et « Débutant » au masculin. Elle a échoué en intégration
    /// continue, et elle avait tort : LE SIMULATEUR DE CI TOURNE EN ANGLAIS. `String(localized:)`
    /// y rend « Beginner » dans les deux cas — l'anglais ne s'accorde pas, c'est tout le point.
    ///
    /// Un test ne peut donc pas juger le MOT rendu : il dépend de la langue de la machine qui
    /// l'exécute. Il peut juger le MÉCANISME, et c'est ce que fait ce fichier — le magasin, la
    /// fonction de choix, la lecture du sexe, et le fait que l'inscription pose le genre
    /// immédiatement. Tout cela est vrai dans n'importe quelle langue.
    ///
    /// L'autre moitié — « chaque phrase accordée passe bien par le mécanisme » — est gardée par
    /// `check_accord.py`, qui lit le CODE SOURCE et ne dépend donc d'aucune langue d'exécution.
    /// C'est lui qui refuserait un « Débutante » écrit en dur, et lui qui a trouvé les trois
    /// phrases oubliées. Les deux ensemble couvrent la règle ; aucun des deux ne la couvre seul.

    /// CHAQUE NIVEAU GARDE UN LIBELLÉ, DANS LES DEUX GENRES.
    ///
    /// Formulé plutôt qu'énuméré : un quatrième niveau, ou une quatrième discipline au même
    /// patron, serait couvert le jour où il est écrit.
    func testChaqueNiveauAUnLibelleDansLesDeuxGenres() {
        for genre in Genre.allCases {
            AccordStore.shared.genre = genre
            for niveau in ExperienceLevel.allCases {
                XCTAssertFalse(niveau.title.isEmpty, "\(niveau) n'a pas de libellé en \(genre)")
                XCTAssertFalse(niveau.subtitle.isEmpty, "\(niveau) n'a pas de sous-titre")
            }
        }
    }

    /// L'inscription pose le genre TOUT DE SUITE, sans attendre un relancement.
    ///
    /// `AppState.init` miroite le genre depuis le profil, mais il a déjà tourné quand
    /// l'inscription se termine. Sans la ligne d'`applyOnboarding`, la toute première session
    /// après l'inscription s'adresserait au féminin à quelqu'un qui vient de répondre « Homme »
    /// — et c'est exactement le moment où l'on regarde si l'app a écouté.
    @MainActor
    func testLInscriptionPoseLeGenreImmediatement() {
        AccordStore.shared.genre = .feminin
        let profil = UserProfile(name: "Test")
        AdaptivePlanEngine.applyOnboarding(resultat(sexe: "male"), to: profil)
        XCTAssertEqual(AccordStore.shared.genre, .masculin)
        XCTAssertEqual(profil.sex, "male")

        AdaptivePlanEngine.applyOnboarding(resultat(sexe: "female"), to: profil)
        XCTAssertEqual(AccordStore.shared.genre, .feminin)
    }

    private func resultat(sexe: String) -> AdaptivePlanEngine.OnboardingResult {
        AdaptivePlanEngine.OnboardingResult(
            name: "Test", birthdate: nil, sex: sexe, goal: .health,
            raceDistance: nil, raceDistanceCustom: nil, raceElevationGainM: nil,
            raceChrono: nil, raceDate: nil, hyroxDivision: nil,
            triathlonFormat: nil, nageNiveau: nil, duathlonFormat: nil,
            runningDays: [0, 2, 4], preferredLongRunDay: 4, level: .intermediaire,
            connectedSources: [], weightNowKg: nil, weightTargetKg: nil, heightCm: nil,
            focusArea: nil, bestRecentPerf: nil, lastRanRecency: nil, injuryArea: nil,
            weeklyTimeBudget: nil, preferredTimeOfDay: nil,
            cycleTrackingEnabled: false, lastPeriodStartDate: nil, averageCycleLengthDays: 28
        )
    }
}
