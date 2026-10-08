import Foundation
import BackgroundTasks
import SwiftData

/// Le réveil en arrière-plan qui fait arriver le conseil météo sans qu'on ouvre l'app.
///
/// # CE QUE CETTE TÂCHE PEUT ET NE PEUT PAS PROMETTRE
///
/// `earliestBeginDate` est un PLANCHER, pas un rendez-vous. iOS décide seul du moment, en
/// fonction de l'autonomie, du réseau et de l'usage qu'il a appris de l'app. Chez quelqu'un qui
/// ouvre RUNUP tous les jours il accorde ces réveils assez volontiers, mais rien ne le garantit,
/// et surtout rien ne le signale quand il ne le fait pas.
///
/// C'est pour ça que `WeatherAdviceService.Source` existe et part dans la mesure : sans elle,
/// « est-ce que le réveil en arrière-plan fonctionne » serait une question sans réponse. Avec
/// elle, il suffit de regarder si des `weather_advice_sent` arrivent avec `source=background`.
///
/// # POURQUOI L'HEURE DEMANDÉE DÉPEND DU CRÉNEAU
///
/// Le conseil ne devient intéressant qu'une fois le créneau du jour entamé — c'est à ce
/// moment-là que `WeatherAdvice.jourAConseiller` bascule sur demain. Demander le réveil deux
/// heures après le début du créneau habituel tombe donc juste pour tout le monde : 19 h pour
/// quelqu'un qui court le soir, 9 h pour quelqu'un qui court le matin. Une heure fixe aurait
/// réveillé l'app au mauvais moment pour la moitié des gens.
///
/// # POURQUOI RIEN N'EST FAIT SI L'APP N'A JAMAIS COURU
///
/// La passe en arrière-plan ne demande pas la position (voir `WeatherAdviceService.conseiller`) :
/// elle se repose sur le départ de la dernière course. Sans aucune course enregistrée, il n'y a
/// pas de point, donc pas de prévision, donc rien à dire. Le réveil ne sert à rien ce jour-là, et
/// c'est sans conséquence : il ne coûte que quelques millisecondes.
@MainActor
enum WeatherBackgroundRefresh {

    /// Doit figurer à l'identique dans `BGTaskSchedulerPermittedIdentifiers` (voir `project.yml`).
    /// Un identifiant absent de cette liste fait LEVER UNE EXCEPTION à l'enregistrement, au
    /// lancement, donc l'app ne démarre pas du tout — les deux écritures ne peuvent pas diverger
    /// sans que ça se voie immédiatement.
    static let identifiant = "com.hicsuntco.runup.weather-refresh"

    /// Le délai après le début du créneau habituel.
    private static let apresLeCreneau: TimeInterval = 2 * 3600

    /// À appeler au lancement, et avant qu'il ne soit terminé — Apple l'exige, et manquer cette
    /// contrainte fait tomber le processus. D'où l'appel depuis `didFinishLaunchingWithOptions`
    /// et pas depuis une vue.
    static func enregistrer() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifiant, using: nil) { tache in
            guard let tache = tache as? BGAppRefreshTask else {
                tache.setTaskCompleted(success: false)
                return
            }
            let travail = Task { @MainActor in
                await executer()
                // Reprogrammé AVANT de se déclarer terminé, et depuis la tâche elle-même : une
                // tâche d'arrière-plan ne se répète pas, chaque exécution doit demander la
                // suivante. Oublier cette ligne donne une fonctionnalité qui marche une fois.
                programmerLaProchaine()
                tache.setTaskCompleted(success: true)
            }
            // Quelques dizaines de secondes, pas plus, et iOS tue le processus sans ménagement
            // s'il dépasse. Annuler proprement laisse la passe s'interrompre entre deux `await`.
            tache.expirationHandler = { travail.cancel() }
        }
    }

    /// Demande le prochain réveil. Appelée à chaque passage au premier plan ET à la fin de chaque
    /// exécution : une demande en remplace la précédente, donc la répéter ne les empile pas.
    static func programmerLaProchaine() {
        guard let profil = profilCourant(), profil.weatherAlertsEnabled else { return }
        let creneau = WeatherAdvice.Slot.from(profil.preferredTimeOfDay)
        let demande = BGAppRefreshTaskRequest(identifier: identifiant)
        demande.earliestBeginDate = prochainReveil(pour: creneau)
        // Une exception ici ne doit jamais empêcher l'app de fonctionner : sans autorisation
        // d'actualisation en arrière-plan, `submit` lève, et le conseil arrivera simplement à
        // l'ouverture comme avant.
        try? BGTaskScheduler.shared.submit(demande)
    }

    /// Le prochain instant où un conseil aura du sens : deux heures après le début du créneau
    /// habituel, aujourd'hui s'il est encore devant, demain sinon.
    static func prochainReveil(pour creneau: WeatherAdvice.Slot, maintenant: Date = .now,
                               calendrier: Calendar = .current) -> Date {
        let debutAujourdhui = WeatherAdvice.debut(creneau, jour: maintenant, calendrier: calendrier)
        if let cible = debutAujourdhui?.addingTimeInterval(apresLeCreneau), cible > maintenant {
            return cible
        }
        let demain = calendrier.date(byAdding: .day, value: 1, to: maintenant) ?? maintenant
        return WeatherAdvice.debut(creneau, jour: demain, calendrier: calendrier)?
            .addingTimeInterval(apresLeCreneau)
            ?? maintenant.addingTimeInterval(12 * 3600)
    }

    private static func executer() async {
        guard let profil = profilCourant() else { return }
        let service = WeatherAdviceService(modelContext: PersistenceController.partage.mainContext,
                                           weather: RunWeatherService())
        await service.conseiller(profile: profil, source: .arrierePlan,
                                 demanderLaPosition: false)
        try? PersistenceController.partage.mainContext.save()
    }

    /// Le profil, lu depuis le conteneur PARTAGÉ du processus.
    ///
    /// Pas un second conteneur : deux `ModelContainer` ouverts sur le même fichier, c'est deux
    /// contextes qui s'ignorent, et une écriture d'un côté qui écrase celle de l'autre. Le réveil
    /// en arrière-plan et l'app sont le même processus — ils doivent voir la même mémoire.
    private static func profilCourant() -> UserProfile? {
        var descripteur = FetchDescriptor<UserProfile>()
        descripteur.fetchLimit = 1
        return try? PersistenceController.partage.mainContext.fetch(descripteur).first
    }
}
