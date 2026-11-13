import Foundation

/// COMPARER UNE SEMAINE À UNE AUTRE SANS COMPARER DEUX CHOSES DIFFÉRENTES.
///
/// # LE DÉFAUT
///
/// La pastille d'écart de `WeekKmSummary` affichait `cetteSemaine − semainePassée`, où la première
/// est la semaine EN COURS — donc partielle — et la seconde une semaine ENTIÈRE. Deux grandeurs de
/// nature différente, soustraites l'une à l'autre.
///
/// Conséquence : le lundi matin, TOUTE le monde est « en retard ». Quelqu'un parfaitement à jour
/// de son plan, qui n'a simplement pas encore couru cette semaine, lisait « ▼ 19,6 km » en ambre
/// — la couleur d'alerte du système. Et une semaine d'allègement, de maladie ou de vacances était
/// peinte comme une faute.
///
/// Quelqu'un avait déjà vu la moitié symétrique du problème, et l'avait écrite dans
/// `WeekKmSummary` : « une semaine passée à zéro ne produit pas une pastille +5,0, qui ferait
/// passer un début pour un progrès ». Le cas partiel-contre-complet n'avait pas été posé.
///
/// # CE QUE CE TYPE FAIT, ET CE QU'IL NE FAIT PAS
///
/// Il coupe la semaine passée AU MÊME POINT que celui où en est la semaine en cours. Lundi à midi,
/// il compare le lundi-midi d'il y a sept jours. L'écart redevient une information : « à ce
/// moment-là de la semaine dernière, j'en étais là ».
///
/// Il ne décide PAS de la couleur ni du mot. Qu'un écart négatif s'affiche en ambre, c'est-à-dire
/// comme une alerte, reste une question de ton de voix — elle appartient à la direction du
/// produit, pas à ce calcul.
///
/// # POURQUOI UN TYPE PARTAGÉ
///
/// Le calcul était écrit DEUX FOIS, dans `HomeView` et dans `StatsView`, chacune avec sa propre
/// façon de borner la semaine. Deux copies d'une comparaison, c'est deux occasions de la réparer
/// à moitié.
///
/// Une première version de ce fichier portait aussi un `kilometresEntiers(semainesAvant:)`, pour
/// « les usages qui voudraient un total de semaine entière ». Aucun ne le voulait : il est parti.
/// Une fonction gardée au cas où est du code mort qui a l'air d'une intention.
enum SemaineComparable {

    /// Les kilomètres de cette semaine, et ceux de la semaine passée AU MÊME POINT.
    ///
    /// `maintenant` est un paramètre pour que les cas puissent fixer l'instant : une comparaison
    /// qui dépend de l'heure à laquelle on la teste n'est pas testable.
    /// `.onFoot` ET PAS `.only(.run)`, et le choix se lit dans `RunRecordDiscipline`. Le
    /// paragraphe qui réserve la comparaison de semaine à semaine à `.only(.run)` parle de
    /// l'ALLURE : « une allure de trail et une allure de route ne se comparent pas ». Ici on
    /// compare des KILOMÈTRES, et un kilomètre de trail est couru à pied comme un autre.
    ///
    /// Le filtre est appliqué ICI plutôt que laissé aux appelants, qui le faisaient chacun de
    /// leur côté : `check_disciplines.py` exige que le site d'agrégation dise de quoi il parle,
    /// et c'est la bonne exigence — un total qui hérite sa discipline de son appelant ne peut
    /// pas être relu tout seul.
    static func kilometres(_ toutesLesCourses: [RunRecord],
                           maintenant: Date = .now,
                           calendar: Calendar = .current) -> (cette: Double, passee: Double) {
        let courses = toutesLesCourses.onFoot
        let semaine = AdaptivePlanEngine.currentWeekRange(from: maintenant)
        let deCetteSemaine = courses.filter { $0.date >= semaine.lowerBound && $0.date <= maintenant }
        let cette = deCetteSemaine.reduce(0) { $0 + $1.distanceKm }

        // LE MÊME POINT, PAS LE MÊME JOUR DE CALENDRIER. On recule de sept jours exactement, ce
        // qui conserve l'heure : comparer « lundi 12 h » à « lundi 00 h » rendrait l'écart faux
        // d'une demi-journée, et toujours dans le même sens.
        guard let debutPassee = calendar.date(byAdding: .day, value: -7, to: semaine.lowerBound),
              let memePoint = calendar.date(byAdding: .day, value: -7, to: maintenant) else {
            return (cette, 0)
        }
        let dejaCouruesLaSemainePassee = courses.filter { $0.date >= debutPassee && $0.date <= memePoint }
        let passee = dejaCouruesLaSemainePassee.reduce(0) { $0 + $1.distanceKm }
        return (cette, passee)
    }
}
