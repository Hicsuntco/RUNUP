import Foundation

/// La série : combien de jours d'affilée on a couru.
///
/// # Pourquoi elle vit ici
///
/// La même règle était écrite DEUX FOIS, dans deux méthodes du moteur de plan. L'une avançait la
/// série après un débriefing, l'autre la recalculait depuis l'historique après une modification —
/// et toutes deux affirmaient, chacune de son côté, qu'un écart de plus de trois jours rompt la
/// chaîne. Un commentaire le disait explicitement : « matches `applyDebrief`'s own rule ». Deux
/// implémentations qui doivent s'accorder finissent toujours par diverger, et celle-ci divergerait
/// en silence : la série ne planterait pas, elle afficherait simplement un nombre faux.
///
/// Le nombre compte. C'est la mesure la plus regardée de l'app — elle est sur l'accueil, sur le
/// profil, dans le débriefing après chaque course — et une série que l'on croit perdue à tort est
/// une raison d'arrêter, pas seulement un chiffre erroné.
///
/// # La règle, en trois phrases
///
/// Un incrément par JOUR CALENDAIRE : deux séances le même jour comptent pour un. Un écart de
/// trois jours ou moins ne rompt rien — c'est plus large que le plus long bloc de repos d'un
/// programme à trois ou quatre séances par semaine, donc les jours de repos prévus ne punissent
/// personne. Au-delà, la chaîne est finie.
enum Streak {
    /// L'écart, en jours, qu'une chaîne survit.
    ///
    /// Trois et pas deux : un plan à trois séances par semaine peut poser mardi, puis vendredi.
    /// Deux jours d'écart serait donc un seuil qui casse la série de quelqu'un qui suit
    /// exactement le programme qu'on lui a donné.
    static let toleratedGapDays = 3

    struct State: Equatable {
        var count: Int
        var lastDay: Date?
    }

    /// Après une séance terminée.
    static func afterSession(_ state: State, on day: Date, calendar: Calendar = .current) -> State {
        let today = calendar.startOfDay(for: day)
        guard let last = calendar.startOfDay(for: state.lastDay ?? today) as Date?, state.lastDay != nil else {
            // Première séance connue — ou une série héritée d'avant que la date soit suivie.
            return State(count: max(1, state.count == 0 ? 1 : state.count + 1), lastDay: today)
        }
        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        if gap == 0 { return State(count: max(1, state.count), lastDay: today) }
        if gap <= toleratedGapDays { return State(count: state.count + 1, lastDay: today) }
        return State(count: 1, lastDay: today)
    }

    /// Depuis les dates de course réellement enregistrées.
    ///
    /// Appelé après toute modification de l'historique : supprimer une course ou en saisir une
    /// après coup ne passe pas par un débriefing, donc `afterSession` ne les voit jamais. Sans ce
    /// recalcul, la série restait figée trop haut après une suppression, ou ignorait un jour
    /// ajouté à la main.
    static func recompute(runDays: [Date], today: Date = .now, calendar: Calendar = .current) -> State {
        let days = Set(runDays.map { calendar.startOfDay(for: $0) }).sorted(by: >)
        guard let mostRecent = days.first else { return State(count: 0, lastDay: nil) }

        var count = 1
        var cursor = mostRecent
        for day in days.dropFirst() {
            let gap = calendar.dateComponents([.day], from: day, to: cursor).day ?? 0
            guard gap <= toleratedGapDays else { break }
            count += 1
            cursor = day
        }

        // Une chaîne dont la dernière course remonte à plus de trois jours est finie, même si
        // elle a existé. Sans ce dernier contrôle, quelqu'un revenant après un mois d'arrêt
        // retrouverait sa série d'avant, intacte.
        let gapToToday = calendar.dateComponents([.day], from: mostRecent, to: calendar.startOfDay(for: today)).day ?? 0
        guard gapToToday <= toleratedGapDays else { return State(count: 0, lastDay: nil) }
        return State(count: count, lastDay: mostRecent)
    }
}
