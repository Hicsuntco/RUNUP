import Foundation

/// Ce que le widget de l'écran d'accueil affiche PENDANT une course.
///
/// # POURQUOI UN SECOND INSTANTANÉ
///
/// `DailyGoalsSnapshot` dit où en est la journée : l'anneau, les objectifs, la série. Pendant une
/// course, ce n'est plus la question. Le widget continuait pourtant d'annoncer « 2/3 bouclés »
/// avec son anneau, en pleine sortie — un widget d'app de course qui ne sait pas qu'on court.
///
/// Les deux sont séparés parce qu'ils n'ont ni la même durée de vie ni la même cadence : les
/// objectifs changent quelques fois par jour, une course bouge toutes les secondes et disparaît.
/// Les mêler aurait fait republier l'un à chaque fois que l'autre change.
///
/// # LE CHRONO N'EST PAS DANS CET OBJET, ET C'EST VOULU
///
/// Un widget d'écran d'accueil ne se redessine pas quand il veut : WidgetKit rationne les
/// rechargements à quelques dizaines par jour. Un chrono republié chaque seconde est impossible,
/// et republié chaque minute il serait faux cinquante-neuf secondes sur soixante.
///
/// D'où `startedAt` : la vue dessine un `Text(timerInterval:)`, que le système fait avancer
/// LUI-MÊME, sans rechargement ni réveil de l'app. Le chrono est donc toujours juste, même quand
/// le budget est épuisé. C'est exactement le procédé que la Live Activity emploie déjà avec son
/// `timerReference`. La distance et le rythme, eux, ne peuvent pas s'extrapoler : ils ne bougent
/// qu'aux republications, espacées exprès.
///
/// # LA PÉREMPTION
///
/// Si l'app est tuée en pleine course, plus personne ne republie — et un chrono qui avance tout
/// seul continuerait de tourner indéfiniment sur l'écran d'accueil, affichant une course qui n'a
/// plus lieu. `publishedAt` date donc chaque écriture, et au-delà de `fraicheurMaximale` le widget
/// revient aux objectifs du jour.
///
/// Mieux : la date de péremption est CALCULABLE à l'avance, donc le widget programme d'emblée une
/// entrée à cet instant-là. Le retour aux objectifs se fait même si plus aucun rechargement n'est
/// accordé — sans quoi la péremption aurait eu besoin, pour s'appliquer, de la chose même dont son
/// absence est le symptôme.
struct LiveRunWidgetSnapshot: Codable, Equatable {

    /// L'instant de départ, corrigé des pauses : `maintenant - elapsedSeconds`. C'est ce que le
    /// chrono auto-porté prend comme origine, donc il doit décrire le temps ÉCOULÉ, pas l'heure à
    /// laquelle on est parti.
    var startedAt: Date
    /// Le temps écoulé au moment de l'écriture. Seul affiché quand la course est en pause — un
    /// chrono qui avance pendant une pause serait un mensonge que personne ne corrigerait.
    var elapsedSeconds: Double
    var isPaused: Bool
    var distanceKm: Double
    /// Déjà formaté par l'app : « 5:12 » à pied, « 24,5 » à vélo. Le widget ne refait aucun calcul
    /// — il n'a ni les relevés ni le modèle d'allure, et deux formatages de la même course finiraient
    /// par ne pas dire la même chose.
    var rythmeValeur: String
    var sessionTitle: String
    /// Optionnelle comme partout ailleurs : un instantané écrit par la version précédente de l'app
    /// n'a pas la clé, et doit se décoder quand même. Voir `RunRecord.disciplineRaw`.
    var disciplineRaw: String?
    var publishedAt: Date

    var discipline: Discipline {
        disciplineRaw.flatMap(Discipline.init(rawValue:)) ?? .legacy
    }

    /// Un quart d'heure sans nouvelle de l'app. Assez long pour couvrir un trou de republication
    /// — WidgetKit peut rationner, le téléphone peut être économe —, assez court pour qu'une app
    /// tuée ne laisse pas une fausse course tourner tout un après-midi.
    static let fraicheurMaximale: TimeInterval = 15 * 60

    /// L'instant où cet instantané cesse d'être croyable.
    var perimeeA: Date { publishedAt.addingTimeInterval(Self.fraicheurMaximale) }

    func estFraiche(a instant: Date) -> Bool { instant < perimeeA }

    // MARK: Le stockage partagé

    private static let defaultsKey = "runup.widget.live-run-snapshot"
    private static let defaults = UserDefaults(suiteName: DailyGoalsSnapshot.appGroupID)
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func save(_ snapshot: LiveRunWidgetSnapshot) {
        guard let defaults, let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    /// Lue sans jugement de fraîcheur : c'est le widget qui décide, parce que lui seul connaît
    /// l'instant de l'entrée qu'il est en train de construire — et il en construit une qui est
    /// dans le futur.
    static func load() -> LiveRunWidgetSnapshot? {
        guard let defaults, let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? decoder.decode(LiveRunWidgetSnapshot.self, from: data)
    }

    /// Effacée à l'arrêt de la course. Sans ça, le widget garderait la dernière course affichée
    /// pendant un quart d'heure après la ligne d'arrivée.
    static func clear() {
        defaults?.removeObject(forKey: defaultsKey)
    }
}
