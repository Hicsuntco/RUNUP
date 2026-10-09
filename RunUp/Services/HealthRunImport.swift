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

    /// Une sortie DÉJÀ enregistrée, réduite à ce dont le dédoublonnage a besoin.
    struct Deja: Equatable {
        var date: Date
        var discipline: Discipline

        init(date: Date, discipline: Discipline = .run) {
            self.date = date
            self.discipline = discipline
        }
    }

    /// Ce qui mérite d'entrer dans l'historique, parmi ce que Santé a rendu.
    ///
    /// `deja` sont les sorties déjà enregistrées, quelle qu'en soit l'origine : une sortie faite
    /// avec le bouton RUN est écrite dans Santé par l'app elle-même, et le filtre par source du
    /// service devrait suffire — mais il ne couvre pas le cas où la même sortie a aussi été
    /// enregistrée par une montre tierce portée en même temps.
    ///
    /// # LE DÉDOUBLONNAGE EST PAR DISCIPLINE, ET C'EST LE TRIATHLON QUI L'A RÉVÉLÉ
    ///
    /// Il comparait les horaires sans regarder ce qui avait été fait. C'était juste tant que
    /// l'import ne ramenait que des courses : deux courses à cinq minutes d'intervalle SONT la
    /// même course, écrite deux fois par deux sources.
    ///
    /// Deux disciplines différentes à cinq minutes d'intervalle, non. C'est un enchaînement — la
    /// séance qui définit le triathlon : on sort de l'eau, on enfourche, on court. Les trois se
    /// suivent à quelques dizaines de secondes, et l'ancienne règle n'en gardait qu'une seule, en
    /// jetant les deux autres sans rien dire. Le plan aurait compté une séance sur trois, et
    /// l'entraînement le plus dur de la semaine aurait été celui qui compte le moins.
    static func selecting(_ found: [HealthKitService.ImportedRun],
                          knownIDs: Set<UUID>,
                          deja: [Deja]) -> [HealthKitService.ImportedRun] {
        var keptDates: [Discipline: [Date]] = [:]
        for d in deja { keptDates[d.discipline, default: []].append(d.date) }
        var kept: [HealthKitService.ImportedRun] = []
        for run in found.sorted(by: { $0.start < $1.start }) {
            guard !knownIDs.contains(run.id) else { continue }
            guard estUneSeance(run) else { continue }
            let memeDiscipline = keptDates[run.discipline] ?? []
            guard !memeDiscipline.contains(where: { abs($0.timeIntervalSince(run.start)) < sameRunWindow }) else { continue }
            kept.append(run)
            keptDates[run.discipline, default: []].append(run.start)
        }
        return kept
    }

    /// En dessous de cette durée, une nage sans distance n'est pas une nage.
    ///
    /// Cinq minutes. Au-delà, personne n'ouvre un entraînement par erreur et le laisse tourner.
    static let dureeMinimaleNage: TimeInterval = 300

    /// Un entraînement ouvert puis refermé n'est pas une séance. Sans ce filtre, chaque faux
    /// départ ajouterait une ligne vide à l'historique et une demande de ressenti pour zéro
    /// kilomètre.
    ///
    /// Les seuils sont bas exprès : une minute et trois cents mètres écartent les manipulations,
    /// pas les vraies sorties courtes. Ce n'est pas à l'import de juger qu'une course de dix
    /// minutes ne compte pas.
    ///
    /// # ET CE SEUIL N'EST PAS LE MÊME EN BASSIN
    ///
    /// Trois cents mètres ne sont rien à pied — c'est une manipulation. En natation, c'est un
    /// échauffement : une séance de 300 m existe, et elle compte.
    ///
    /// Surtout, UNE NAGE PEUT NE PORTER AUCUNE DISTANCE. Une montre qui ne connaît pas la
    /// longueur du bassin, un nageur qui n'a pas réglé la sienne, une traversée en eau libre sans
    /// GPS : la séance a duré quarante minutes et Santé rend zéro mètre. C'est une vraie nage, et
    /// la règle de la course la jetterait. Pour un plan de triathlon, c'est précisément la séance
    /// qu'il faut compter — c'est la DURÉE qui construit, pas le métrage.
    static func estUneSeance(_ seance: HealthKitService.ImportedRun) -> Bool {
        switch seance.discipline {
        case .run, .trail, .bike:
            return seance.durationSeconds > 60 && seance.distanceKm > 0.3
        case .swim:
            // Assez longue pour être une séance, même sans un mètre mesuré — ou mesurée, et alors
            // cent mètres suffisent à écarter la manipulation.
            return seance.durationSeconds >= dureeMinimaleNage
                || (seance.durationSeconds > 60 && seance.distanceKm > 0.1)
        }
    }
}
