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

    /// LES NIVEAUX S'ACCORDENT, ET C'EST LE CAS LE PLUS VISIBLE.
    ///
    /// Ces trois mots sont une carte qu'on touche pour se décrire, à l'étape qui suit la question
    /// du genre. Se voir proposer « Débutante » juste après avoir répondu « Homme » est la forme
    /// la plus directe de « cette app ne t'a pas écouté ».
    func testLesNiveauxSAccordent() {
        AccordStore.shared.genre = .feminin
        XCTAssertEqual(ExperienceLevel.debutante.title, "Débutante")
        XCTAssertEqual(ExperienceLevel.confirmee.title, "Confirmée")
        AccordStore.shared.genre = .masculin
        XCTAssertEqual(ExperienceLevel.debutante.title, "Débutant")
        XCTAssertEqual(ExperienceLevel.confirmee.title, "Confirmé")
    }

    /// « Intermédiaire » est épicène : les deux genres lisent le même mot, et c'est juste.
    ///
    /// Le test existe pour qu'on ne lui invente pas une seconde forme le jour où l'on passera en
    /// revue les trois ensemble — « Intermédiaire » et « Intermédiaire » dans un `Accord.selon`
    /// seraient deux clés de catalogue pour un seul mot, à traduire deux fois.
    func testLeNiveauEpiceneResteUnSeulMot() {
        AccordStore.shared.genre = .feminin
        let auFeminin = ExperienceLevel.intermediaire.title
        AccordStore.shared.genre = .masculin
        XCTAssertEqual(ExperienceLevel.intermediaire.title, auFeminin)
    }

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
            triathlonFormat: nil, nageNiveau: nil,
            runningDays: [0, 2, 4], preferredLongRunDay: 4, level: .intermediaire,
            connectedSources: [], weightNowKg: nil, weightTargetKg: nil, heightCm: nil,
            focusArea: nil, bestRecentPerf: nil, lastRanRecency: nil, injuryArea: nil,
            weeklyTimeBudget: nil, preferredTimeOfDay: nil,
            cycleTrackingEnabled: false, lastPeriodStartDate: nil, averageCycleLengthDays: 28
        )
    }
}
