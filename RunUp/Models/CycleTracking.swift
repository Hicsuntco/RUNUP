import Foundation

/// Réancrer le suivi du cycle sur ce qui vient réellement d'arriver.
///
/// La phase est calculée par pas fixes depuis la dernière date connue et la durée moyenne. Un vrai
/// cycle ne fait pas la même longueur tous les mois : dès qu'il s'écarte de la moyenne, l'écart se
/// reporte au cycle suivant, puis s'ajoute à celui d'après. Au bout de trois mois l'app annonce une
/// phase lutéale à quelqu'un qui a ses règles, et adapte son programme sur cette erreur — c'est
/// `AdaptivePlanEngine.adjustForWellbeing` qui lit cette phase.
///
/// Le remède n'est pas de laisser corriger la phase à la main, qui serait vraie un jour et fausse
/// le lendemain. C'est de laisser dire « mes règles ont commencé aujourd'hui » : une date, la seule
/// chose qu'on observe vraiment, dont tout le reste se déduit.
enum CycleTracking {

    /// Ce que devient le suivi quand un nouveau cycle commence.
    ///
    /// La durée moyenne apprend de l'écart observé, mais à moitié : un cycle décalé par un voyage,
    /// une maladie ou un stress ne doit pas redéfinir la moyenne à lui seul. En prenant le milieu
    /// entre ce qu'on croyait et ce qu'on vient de voir, une vraie tendance s'installe en deux ou
    /// trois cycles et un accident isolé s'efface au suivant.
    static func recordingPeriodStart(
        lastStart: Date?,
        averageLength: Int,
        newStart: Date,
        calendar: Calendar = .current
    ) -> (lastStart: Date, averageLength: Int) {
        guard let lastStart else { return (newStart, clamped(averageLength)) }

        let observed = calendar.dateComponents([.day], from: lastStart, to: newStart).day ?? 0

        // En dehors de 15 à 60 jours, ce n'est pas un cycle : c'est une correction de saisie, une
        // reprise après une longue interruption, ou deux appuis le même jour. On réancre la date
        // sans rien apprendre — mieux vaut une moyenne inchangée qu'une moyenne fausse.
        guard (15...60).contains(observed) else { return (newStart, clamped(averageLength)) }

        let blended = Int(((Double(averageLength) + Double(observed)) / 2).rounded())
        return (newStart, clamped(blended))
    }

    /// Les bornes que `UserProfile.cyclePhase` applique déjà de son côté. Les appliquer aussi à
    /// l'écriture évite de STOCKER une valeur que le calcul écrêterait ensuite en silence : le
    /// réglage afficherait alors un nombre que l'app n'utilise pas.
    static func clamped(_ days: Int) -> Int { max(21, min(35, days)) }
}
