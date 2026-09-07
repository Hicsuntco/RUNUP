import Foundation

/// La règle de l'import depuis Apple Santé : quelle fenêtre balayer, et que garder de ce qu'on y
/// trouve.
///
/// Séparée d'`AppState` parce que c'est la seule partie qui peut se tromper en silence. Le reste
/// de l'import — lire Santé, insérer, notifier — échoue bruyamment ou pas du tout. Ici, une erreur
/// donne un historique avec la même sortie trois fois, ou une semaine qui reste à « 1/4 séances »
/// alors que les quatre ont été courues. Aucune des deux ne ressemble à un bug quand on la voit :
/// l'une ressemble à une grosse semaine, l'autre à une semaine ratée.
enum HealthRunImport {
    /// Deux sorties enregistrées à moins de cinq minutes l'une de l'autre sont la même sortie.
    ///
    /// Ce n'est pas une marge de confort : une course peut être déposée dans Santé par la montre
    /// ET par l'application du fabricant, avec des horaires de départ qui diffèrent de quelques
    /// secondes à quelques minutes selon lequel des deux compte le décompte initial. Aucune des
    /// deux n'étant RUNUP, le filtre par source ne les écarte pas.
    static let sameRunWindow: TimeInterval = 300

    /// Sept jours au premier passage. De quoi remettre d'aplomb la semaine en cours sans déverser
    /// des années d'historique — et surtout sans empiler cent demandes de ressenti, que personne
    /// ne validerait, et qui feraient de la première ouverture un formulaire.
    static let firstLookBack: TimeInterval = 7 * 86_400

    /// Un jour de recouvrement ensuite. Une montre peut déposer sa séance dans Santé bien après
    /// l'avoir enregistrée — la synchronisation passe par l'application du fabricant, qui attend
    /// parfois le Wi-Fi. Repartir exactement de la dernière fenêtre balayée perdrait ces
    /// arrivées tardives, définitivement.
    static let overlap: TimeInterval = 86_400

    static func window(lastImport: Date?, now: Date = .now) -> Date {
        guard let lastImport else { return now.addingTimeInterval(-firstLookBack) }
        return lastImport.addingTimeInterval(-overlap)
    }

    /// Ce qui mérite d'entrer dans l'historique, parmi ce que Santé a rendu.
    ///
    /// `existingDates` sont les dates des courses déjà enregistrées, quelle qu'en soit l'origine :
    /// une sortie faite avec le bouton RUN est écrite dans Santé par l'app elle-même, et le filtre
    /// par source du service devrait suffire — mais il ne couvre pas le cas où la même sortie a
    /// aussi été enregistrée par une montre tierce portée en même temps.
    static func selecting(_ found: [HealthKitService.ImportedRun],
                          knownIDs: Set<UUID>,
                          existingDates: [Date]) -> [HealthKitService.ImportedRun] {
        var keptDates = existingDates
        var kept: [HealthKitService.ImportedRun] = []
        for run in found.sorted(by: { $0.start < $1.start }) {
            guard !knownIDs.contains(run.id) else { continue }
            guard isARun(run) else { continue }
            guard !keptDates.contains(where: { abs($0.timeIntervalSince(run.start)) < sameRunWindow }) else { continue }
            kept.append(run)
            keptDates.append(run.start)
        }
        return kept
    }

    /// Un entraînement ouvert puis refermé n'est pas une course. Sans ce filtre, chaque faux départ
    /// ajouterait une ligne vide à l'historique et une demande de ressenti pour zéro kilomètre.
    ///
    /// Les seuils sont bas exprès : une minute et trois cents mètres écartent les manipulations,
    /// pas les vraies sorties courtes. Ce n'est pas à l'import de juger qu'une course de dix
    /// minutes ne compte pas.
    static func isARun(_ run: HealthKitService.ImportedRun) -> Bool {
        run.durationSeconds > 60 && run.distanceKm > 0.3
    }
}
