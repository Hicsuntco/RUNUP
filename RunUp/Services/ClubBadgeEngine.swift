import Foundation

/// Le calcul des badges « à moi », sorti de `ClubView`.
///
/// Il vivait dans une propriété privée de l'écran Club, et c'était le seul endroit qui savait
/// dériver l'état des badges depuis l'historique local (`RunRecord`) et la série en cours. Le
/// profil affiche déjà un compte de badges et voulait en montrer le détail ; le recopier aurait
/// donné deux dérivations à faire évoluer ensemble, avec la garantie qu'elles finiraient par
/// diverger — un badge gagné ici, pas là.
///
/// Fonction pure sur (`runs`, `profile`) : rien à observer, rien à instancier, testable telle
/// quelle.
enum ClubBadgeEngine {
    /// Tous les badges du catalogue, chacun avec son état gagné/verrouillé et, quand ça a du sens,
    /// sa progression. C'est ce device qui a l'historique, donc c'est le seul à pouvoir calculer
    /// la progression vers un badge non débloqué ; les clés gagnées sont ensuite synchronisées au
    /// serveur (voir `syncBadgesIfNeeded`), ce qui les rend visibles aux autres membres du club.
    static func badges(runs: [RunRecord], profile: UserProfile) -> [ClubBadge] {
        // Compté sur `sessionKind`, pas sur le titre : depuis que `RunRecord.title` porte le texte
        // AFFICHÉ (donc traduit), chercher le mot « Fractionné » dedans ne trouverait plus rien en
        // anglais ni en espagnol, et ce badge ne se débloquerait jamais. Les courses antérieures
        // au champ n'ont pas de `kind` — pour elles seulement on garde la recherche de texte, qui
        // reste exacte puisque leur titre, lui, est resté français.
        // ── SEPT PARCOURS SONT DEVENUS UN, ET LE CALENDRIER SORT DE LA BOUCLE ───────────────
        //
        // Cette fonction est lue depuis le `body` de deux écrans — le Profil et le Club — donc
        // recalculée à CHAQUE évaluation de leur corps, c'est-à-dire plusieurs fois pendant la
        // transition qui amène l'écran. Elle parcourait l'historique sept fois, et trois de ces
        // parcours appelaient `Calendar.current` À L'INTÉRIEUR de la boucle.
        //
        // `Calendar.current` n'est pas une constante : chaque accès reconstruit un calendrier,
        // et `component(_:from:)` est l'une des opérations les plus coûteuses de Foundation.
        // Trois fois par course, sur tout l'historique, plusieurs fois par transition — c'est
        // du travail sur le fil principal exactement pendant l'animation.
        //
        // Un seul parcours, un seul calendrier. Les valeurs produites sont identiques ;
        // `ClubBadgeEngineTests` le vérifie.
        let calendrier = Calendar.current
        var intervalRuns = 0
        var earlyRun = false
        var nightRun = false
        var weekendRuns = 0
        var totalElevation = 0
        var totalDistance = 0.0
        var longestRun = 0.0
        for run in runs {
            if run.sessionKind.map(\.isIntervalWorkout)
                ?? run.title.localizedCaseInsensitiveContains("Fractionné") {
                intervalRuns += 1
            }
            let heure = calendrier.component(.hour, from: run.date)
            if heure < 7 { earlyRun = true }
            if heure >= 21 { nightRun = true }
            let jour = calendrier.component(.weekday, from: run.date)
            if jour == 1 || jour == 7 { weekendRuns += 1 }
            // Des badges de COURSE : trois cents mètres de dénivelé à vélo ne valent pas les
            // mêmes. `onFoot` filtrait l'historique une fois de plus ; le test se fait ici.
            guard run.discipline.wearsShoes else { continue }
            totalElevation += run.elevationGainM
            totalDistance += run.distanceKm
            longestRun = max(longestRun, run.distanceKm)
        }
        let earned: [String: Bool] = [
            "streak3": profile.streak >= 3,
            "interval3": intervalRuns >= 3,
            "earlyRun": earlyRun,
            "elevation300": totalElevation >= 300,
            "firstRun": !runs.isEmpty,
            "streak7": profile.streak >= 7,
            "streak30": profile.streak >= 30,
            "tenRuns": runs.count >= 10,
            "fiftyRuns": runs.count >= 50,
            "distance50": totalDistance >= 50,
            "distance250": totalDistance >= 250,
            "distance1000": totalDistance >= 1000,
            "halfMarathonDistance": longestRun >= 21,
            "marathonDistance": longestRun >= 42,
            "nightRun": nightRun,
            "weekendWarrior": weekendRuns >= 10
        ]
        let progress: [String: String?] = [
            // Seules les lignes qui portent un mot français passent par le catalogue — les autres
            // ne sont que des chiffres et des unités identiques dans les trois langues.
            "streak3": String(localized: "\(min(profile.streak, 3))/3 jours"),
            "interval3": String(localized: "\(min(intervalRuns, 3))/3 séances"),
            "earlyRun": nil,
            "elevation300": "\(min(Int(totalElevation), 300))/300 m",
            "firstRun": nil,
            "streak7": String(localized: "\(min(profile.streak, 7))/7 jours"),
            "streak30": String(localized: "\(min(profile.streak, 30))/30 jours"),
            "tenRuns": "\(min(runs.count, 10))/10",
            "fiftyRuns": "\(min(runs.count, 50))/50",
            "distance50": "\(min(Int(totalDistance), 50))/50 km",
            "distance250": "\(min(Int(totalDistance), 250))/250 km",
            "distance1000": "\(min(Int(totalDistance), 1000))/1000 km",
            "halfMarathonDistance": "\(String(format: "%.1f", min(longestRun, 21)))/21 km",
            "marathonDistance": "\(String(format: "%.1f", min(longestRun, 42)))/42 km",
            "nightRun": nil,
            "weekendWarrior": "\(min(weekendRuns, 10))/10"
        ]
        return ClubBadgeCatalog.all.map { def in
            ClubBadge(
                key: def.key, emoji: def.emoji, name: def.name, detail: def.detail,
                progressText: progress[def.key] ?? nil,
                earned: earned[def.key] ?? false
            )
        }
    }
}
