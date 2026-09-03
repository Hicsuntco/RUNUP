import Foundation

/// Ce que le coach peut changer au programme, et rien d'autre.
///
/// La liste est fermée à dessein. Le coach écrit dans les ENTRÉES du générateur — jamais dans les
/// séances qu'il produit, qui sont regénérées chaque semaine (voir `TrainingEase`). Chaque cas
/// ci-dessous correspond donc à un levier qui existait déjà dans `AdaptivePlanEngine` et que la
/// coureuse pouvait actionner elle-même depuis les réglages ; le coach n'en gagne aucun nouveau.
enum CoachAction: Equatable, Sendable {
    /// Plafonner la durée des séances et/ou couper le travail de vitesse, jusqu'à une date.
    case ease(TrainingEase)
    /// Signaler (ou lever, avec `nil`) une zone sensible — le levier de `adjustForWellbeing`.
    case sensitiveArea(String?)
    /// Changer les jours de course et le jour de sortie longue.
    case runningDays(days: [Int], longRunDay: Int?)
    /// Décaler la séance du jour à demain.
    case moveTodaysSession
    /// Tout lever : plus d'allègement, plus de zone sensible.
    case resumeNormal
}

/// Les champs que peuvent porter les appels d'outil, tous réunis dans une seule structure.
///
/// Un type par outil serait plus orthodoxe, et n'apporterait rien ici : les cinq schémas sont
/// définis par nous, dans `api/coach.js`, et leurs champs sont disjoints. Ce que le décodage doit
/// garantir, c'est qu'un champ absent ou du mauvais type ne fasse pas échouer l'appel entier —
/// d'où des optionnels partout, et la validation réelle dans `CoachAction.make`.
private struct CoachToolInput: Decodable {
    var max_minutes: Int?
    var no_speed_work: Bool?
    var until: String?
    var reason: String?
    var area: String?
    var days: [Int]?
    var long_run_day: Int?
}

extension CoachAction {
    /// Zones sensibles reconnues — les mêmes identifiants que les réglages et que
    /// `AdaptivePlanEngine.injuryLabel`. Tout le reste est refusé plutôt que traduit au jugé :
    /// une zone inconnue afficherait son propre identifiant brut à la coureuse.
    static let knownAreas: Set<String> = ["knee", "ankle", "back", "other"]

    /// Le format de date des appels d'outil. `en_US_POSIX` et pas la locale courante : un
    /// formateur laissé sur la locale de l'appareil interprète « 2026-09-17 » différemment selon
    /// le calendrier configuré, et échoue pour de bon sur un calendrier non grégorien.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Traduit un appel d'outil en action, ou renvoie `nil` si rien d'applicable n'en sort.
    ///
    /// Renvoyer `nil` n'est pas un cas d'erreur à signaler à la coureuse : la réponse texte du
    /// coach s'affiche normalement, seul l'effet sur le programme n'a pas lieu. Un bandeau
    /// « action impossible » lui demanderait de comprendre une plomberie qui ne la regarde pas.
    static func make(name: String, input: Data, today: Date = .now, calendar: Calendar = .current) -> CoachAction? {
        guard let fields = try? JSONDecoder().decode(CoachToolInput.self, from: input) else { return nil }

        switch name {
        case "ease_training_load":
            guard let untilString = fields.until, let until = dayFormatter.date(from: untilString) else { return nil }
            let eased = TrainingEase.sanitized(
                maxMinutes: fields.max_minutes,
                noSpeedWork: fields.no_speed_work ?? false,
                until: until,
                reason: fields.reason ?? "",
                from: today,
                calendar: calendar
            )
            return eased.map { CoachAction.ease($0) }

        case "set_sensitive_area":
            guard let area = fields.area else { return nil }
            if area == "none" { return .sensitiveArea(nil) }
            guard knownAreas.contains(area) else { return nil }
            return .sensitiveArea(area)

        case "set_running_days":
            guard let raw = fields.days else { return nil }
            let days = Array(Set(raw.filter { (0...6).contains($0) })).sorted()
            // Moins de deux jours n'est pas un programme, c'est une sortie. Le générateur
            // produirait une semaine quasi vide et la coureuse n'aurait rien demandé de tel.
            guard days.count >= 2 else { return nil }
            let longRun = fields.long_run_day.flatMap { days.contains($0) ? $0 : nil }
            return .runningDays(days: days, longRunDay: longRun)

        case "move_todays_session":
            return .moveTodaysSession

        case "resume_normal_training":
            return .resumeNormal

        default:
            return nil
        }
    }
}
