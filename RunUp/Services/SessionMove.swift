import Foundation

/// Déplacer une séance d'un jour à l'autre de la semaine en cours.
///
/// C'est la chose que le plan ne savait pas faire. « Je ne peux pas courir jeudi » n'avait qu'une
/// réponse dans l'app — « Refaire un programme », qui repart à la semaine 1 et jette la
/// progression. Entre subir le plan et le détruire, il n'y avait rien.
///
/// **Seulement la semaine en cours**, et ce n'est pas une limite provisoire : c'est la seule
/// semaine qui existe vraiment. `weekSessions` la persiste ; les semaines suivantes sont
/// régénérées par `AdaptivePlanEngine` à chaque affichage, à partir des jours de course du profil.
/// Un déplacement posé sur une semaine future serait effacé à la prochaine ouverture de l'écran,
/// sans que rien ne le signale — pire qu'une fonction absente. Une semaine qui n'est pas encore
/// arrivée se change par ses jours de course, pas séance par séance.
///
/// Logique pure, sans SwiftData ni SwiftUI : ce sont des règles d'entraînement, elles se
/// vérifient sans écran.
enum SessionMove {

    /// La semaine après déplacement, ou `nil` quand le déplacement est refusé.
    ///
    /// Une séance déjà faite ne bouge pas. Elle a eu lieu ce jour-là ; la déplacer réécrirait
    /// l'historique et ferait mentir le décompte de la semaine comme le fil du club. C'est le seul
    /// refus catégorique — tout le reste est autorisé quitte à être signalé.
    ///
    /// Si le jour d'arrivée porte déjà une séance, les deux s'échangent plutôt que l'une n'écrase
    /// l'autre. C'est ce qu'on veut dire neuf fois sur dix en déplaçant : « je fais jeudi ce qui
    /// était vendredi, et vendredi ce qui était jeudi ».
    static func apply(to days: [PlannedDay], from: Int, to: Int) -> [PlannedDay]? {
        guard from != to, (0..<7).contains(from), (0..<7).contains(to) else { return nil }
        guard let source = days.first(where: { $0.weekday == from }), hasSession(source) else { return nil }
        guard !source.completed else { return nil }

        let target = days.first(where: { $0.weekday == to })
        if let target, hasSession(target), target.completed { return nil }

        return days.map { day in
            switch day.weekday {
            case from:
                var moved = day
                moved.session = (target.flatMap { hasSession($0) ? $0.session : nil })
                moved.completed = false
                return moved
            case to:
                var moved = day
                moved.session = source.session
                moved.completed = false
                return moved
            default:
                return day
            }
        }
    }

    /// Le déplacement collerait-il deux séances exigeantes sur deux jours consécutifs ?
    ///
    /// La règle que le générateur applique déjà — deux séances de qualité par semaine au maximum,
    /// jamais dos à dos — est ce qui sépare un plan d'une liste d'entraînements. Un déplacement
    /// libre peut la défaire en un geste, et c'est précisément ainsi qu'on se blesse en semaine 4.
    ///
    /// L'app AVERTIT, elle n'interdit pas : quelqu'un qui ne peut pas courir jeudi ne peut pas
    /// courir jeudi, et un refus le renverrait à « Refaire un programme », c'est-à-dire au
    /// problème qu'on est en train de résoudre. On ne signale que ce que le déplacement AJOUTE :
    /// une semaine qui empilait déjà deux jours durs n'a pas à se faire gronder pour ça.
    ///
    /// Le lundi et le dimanche ne sont pas voisins ici : la semaine suivante n'est pas encore
    /// écrite, et prétendre juger cette jonction serait deviner.
    static func stacksHardDays(in days: [PlannedDay], from: Int, to: Int) -> Bool {
        guard let after = apply(to: days, from: from, to: to) else { return false }
        return hardAdjacencies(in: after) > hardAdjacencies(in: days)
    }

    /// Un jour où la séance peut atterrir, et ce qu'on doit en dire avant de choisir.
    struct Destination: Identifiable, Equatable {
        var id: Int { weekday }
        let weekday: Int
        /// La séance déjà posée ce jour-là, avec laquelle on échangerait. Nil si le jour est libre.
        let occupant: WorkoutSession?
        /// Le déplacement collerait deux séances exigeantes dos à dos.
        let warns: Bool
    }

    /// Les jours de la semaine où la séance peut atterrir, avec ce qui s'y trouve déjà.
    static func destinations(in days: [PlannedDay], from: Int) -> [Destination] {
        (0..<7).compactMap { weekday in
            guard weekday != from, apply(to: days, from: from, to: weekday) != nil else { return nil }
            return Destination(
                weekday: weekday,
                occupant: days.first { $0.weekday == weekday }.flatMap { hasSession($0) ? $0.session : nil },
                warns: stacksHardDays(in: days, from: from, to: weekday)
            )
        }
    }

    private static func hasSession(_ day: PlannedDay) -> Bool {
        (day.session?.durationMinutes ?? 0) > 0
    }

    private static func hardAdjacencies(in days: [PlannedDay]) -> Int {
        let hard = (0..<7).map { weekday -> Bool in
            guard let day = days.first(where: { $0.weekday == weekday }), hasSession(day),
                  let session = day.session else { return false }
            return session.family.isDemanding
        }
        return (0..<6).filter { hard[$0] && hard[$0 + 1] }.count
    }
}
