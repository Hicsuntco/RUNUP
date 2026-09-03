import Foundation

/// Ce que le coach a le droit d'imposer au générateur de programme, et jusqu'à quand.
///
/// # Pourquoi une contrainte datée, et pas une séance modifiée
///
/// Le programme est REGÉNÉRÉ : chaque lundi par `refreshProgramForCurrentDate`, et à chaque
/// changement de réglage par `applyProgramSettingsChange`. Une séance éditée à la main serait
/// donc effacée au passage suivant — c'est mot pour mot le bug de « Déplacer une séance » qu'on
/// a corrigé. Ce qui survit, ce sont les ENTRÉES du générateur, relues à chaque génération.
/// C'est déjà comme ça que `injuryArea` allège les fractionnés semaine après semaine sans que
/// personne ne re-coche quoi que ce soit (voir `adjustForWellbeing`).
///
/// Cette structure est donc une entrée de plus. Avec une échéance, parce qu'une tendinite passe :
/// un allègement sans date de fin devient un plafond permanent que plus personne ne pense à
/// retirer, et le programme cesse silencieusement de progresser.
struct TrainingEase: Codable, Equatable, Sendable {
    /// Plafond de durée par séance, en minutes. `nil` = pas de plafond.
    var maxMinutes: Int?
    /// Remplace tout travail de vitesse par de l'endurance souple.
    var noSpeedWork: Bool
    /// Dernier jour où la contrainte s'applique, inclus.
    var until: Date
    /// Ce que le coach en a dit. Affiché tel quel sur les séances concernées et dans le fil.
    var reason: String

    func isActive(on day: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: day) <= calendar.startOfDay(for: until)
    }

    // MARK: Bornes

    /// Les bornes existent parce que ces valeurs viennent d'un modèle de langage, pas d'un
    /// formulaire. Elles ne sont pas là pour rattraper une réponse absurde — elles sont là pour
    /// qu'une réponse absurde ne puisse pas produire un programme absurde. Une séance de 0 minute
    /// ou un bridage de dix ans ne doivent pas être représentables, quoi qu'il arrive en amont.
    static let minSessionMinutes = 10
    static let maxSessionMinutes = 180
    static let maxHorizonDays = 120

    /// Ramène des valeurs venues du dehors dans le domaine du représentable. Renvoie `nil` quand
    /// il ne reste rien à appliquer — une contrainte qui ne contraint rien (pas de plafond, pas
    /// de bridage du fractionné) est une contrainte qu'il vaut mieux ne pas poser du tout, plutôt
    /// que de l'afficher à la coureuse comme un allègement qui n'en est pas un.
    static func sanitized(
        maxMinutes: Int?,
        noSpeedWork: Bool,
        until: Date,
        reason: String,
        from today: Date = .now,
        calendar: Calendar = .current
    ) -> TrainingEase? {
        let cappedMinutes = maxMinutes.map { min(max($0, minSessionMinutes), maxSessionMinutes) }
        guard cappedMinutes != nil || noSpeedWork else { return nil }

        let startOfToday = calendar.startOfDay(for: today)
        let horizon = calendar.date(byAdding: .day, value: maxHorizonDays, to: startOfToday) ?? startOfToday
        // Une date déjà passée deviendrait une contrainte inactive dès l'instant où on la pose :
        // le coach dirait « j'allège jusqu'à hier », le programme ne bougerait pas, et rien à
        // l'écran n'expliquerait pourquoi. On la ramène à aujourd'hui — au moins la journée en
        // cours est réellement allégée, ce qui correspond à ce qui est annoncé.
        let clampedUntil = min(max(calendar.startOfDay(for: until), startOfToday), horizon)

        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return TrainingEase(
            maxMinutes: cappedMinutes,
            noSpeedWork: noSpeedWork,
            until: clampedUntil,
            reason: trimmed.isEmpty ? String(localized: "Allégé par ton coach") : String(trimmed.prefix(80))
        )
    }
}
