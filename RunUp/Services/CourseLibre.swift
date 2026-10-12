import Foundation

/// La séance du jour en COURSE LIBRE — celle de quelqu'un qui ne suit pas de programme.
///
/// # CE QU'IL Y AVAIT AVANT : RIEN
///
/// `AdaptivePlanEngine.freeRunTemplates` contenait trois séances, et une seule était jamais
/// lue — `freeRunTemplates.first`, posée une fois en entrant dans le mode. `freeRunTemplateIndex`
/// existait pour les faire tourner et n'a jamais été incrémenté nulle part. Et l'accueil ne
/// montrait de toute façon aucune des trois : la carte disait « On sort courir ? », tous les
/// jours, indéfiniment.
///
/// Course libre était donc un chronomètre avec un joli fond. Ce qui se défend — et ce n'est pas
/// ce qu'on veut : quelqu'un qui ne suit pas de plan a BESOIN qu'on lui dise quoi faire
/// aujourd'hui, plus encore que quelqu'un qui en suit un.
///
/// # LES QUATRE CHOSES QUE LA SUGGESTION DOIT FAIRE
///
/// 1. CHANGER TOUS LES JOURS. Une carte identique chaque matin cesse d'être lue au bout de
///    trois jours.
/// 2. PROGRESSER. Pas une roue de séances interchangeables : la sortie longue repart à chaque
///    fois de la plus longue réellement courue, et la gagne de 10 % — la même règle que le plan
///    structuré s'applique à lui-même.
/// 3. S'ADAPTER À HIER. Deux séances dures de suite est la façon la plus courante de se blesser
///    quand personne ne tient le compte à votre place. Ici, c'est le moteur qui le tient.
/// 4. S'ADAPTER À LA FORME. `readiness` existe depuis longtemps, calculé à partir des ressentis
///    et de l'enchaînement des jours, et il ne décidait de rien.
///
/// # POURQUOI UNE FONCTION PURE, ET PAS UN ÉTAT ENREGISTRÉ
///
/// La suggestion n'est stockée nulle part : elle se recalcule à l'ouverture de l'accueil, à
/// partir de l'historique et du jour. C'est ce qui la rend STABLE dans la journée (les mêmes
/// entrées rendent la même séance) et juste le lendemain (une course enregistrée ce soir change
/// la suggestion de demain matin, sans qu'aucune tâche de fond n'ait à tourner).
///
/// C'est aussi ce qui la rend testable sans base ni horloge : tout ce dont elle dépend lui est
/// passé en argument, le jour compris.
enum CourseLibre {

    /// La séance proposée, et la phrase qui dit pourquoi celle-là aujourd'hui.
    ///
    /// La RAISON compte autant que la séance. Une suggestion sans raison est un ordre, et on
    /// n'obéit pas longtemps à une app ; « Hier c'était dur, aujourd'hui on récupère » est une
    /// phrase qu'on peut accepter ou refuser en connaissance de cause.
    struct Suggestion: Equatable {
        var seance: WorkoutSession
        var raison: String
    }

    /// L'intention d'entraînement du jour, décidée AVANT de choisir quelle séance l'incarne.
    ///
    /// Séparer les deux est ce qui permet à la fois la règle et la variété : l'intention vient
    /// de l'historique et de la forme, la séance vient de l'intention et du jour. Deux lundis de
    /// suite en endurance ne montrent pas la même carte, sans que la charge ait bougé d'une
    /// minute.
    enum Intention: String, Equatable {
        case repos, recuperation, endurance, tonique, qualite, longue
    }

    // MARK: Les fenêtres de décision, nommées une fois

    /// Au-delà, on ne reprend pas où l'on s'était arrêté — on reprend.
    static let joursAvantReprise = 14
    /// Une sortie longue par semaine, pas plus.
    static let joursEntreSortiesLongues = 6
    /// Deux jours pleins entre deux séances de qualité : c'est la règle que le plan structuré
    /// applique déjà par son plafond hebdomadaire, dite ici en jours parce qu'ici il n'y a pas
    /// de semaine.
    static let joursEntreSeancesDeQualite = 3
    /// La fenêtre d'historique qui sert de référence. Quatre semaines : assez pour une tendance,
    /// assez court pour qu'une forme d'il y a deux mois ne décide pas d'aujourd'hui.
    static let fenetreJours = 28

    // MARK: L'entrée

    static func duJour(profil: UserProfile,
                       courses: [RunRecord],
                       jour: Date = .now,
                       calendrier: Calendar = .current) -> Suggestion {
        let aujourdhui = calendrier.startOfDay(for: jour)
        let debut = calendrier.date(byAdding: .day, value: -fenetreJours, to: aujourdhui) ?? .distantPast
        // Les courses d'AUJOURD'HUI sont écartées : la question posée est « que faire
        // maintenant », et une sortie déjà faite ce matin ne doit pas se répondre elle-même.
        // L'accueil montre de toute façon l'état « séance faite » dans ce cas.
        let passe = courses
            .filter { $0.date >= debut && calendrier.startOfDay(for: $0.date) < aujourdhui }
            .sorted { $0.date > $1.date }

        let forme = profil.hasReadinessData ? profil.readiness : 75
        let reperes = Reperes(courses: passe, aujourdhui: aujourdhui, calendrier: calendrier)
        let (intention, raison) = intentionDuJour(reperes: reperes, forme: forme)
        let seance = seancePour(intention, reperes: reperes, profil: profil,
                                jour: aujourdhui, calendrier: calendrier)
        return Suggestion(seance: seance, raison: raison)
    }

    // MARK: Ce que l'historique dit

    /// Les quelques nombres que la décision regarde, calculés une fois.
    struct Reperes {
        /// Jours pleins depuis la dernière course. `nil` si l'on n'en a aucune dans la fenêtre.
        var joursDepuisLaDerniere: Int?
        /// Jours courus d'affilée en remontant depuis hier.
        var joursConsecutifs: Int
        /// La dernière course était-elle une séance dure ? Une sortie longue ?
        var laDerniereEtaitDure: Bool
        var laDerniereEtaitLongue: Bool
        var joursDepuisUneSeanceDure: Int?
        var joursDepuisUneSortieLongue: Int?
        /// La durée habituelle et la plus longue, en minutes, sur la fenêtre.
        var typiqueMinutes: Int
        var plusLongueMinutes: Int

        init(courses: [RunRecord], aujourdhui: Date, calendrier: Calendar) {
            func ecart(_ date: Date) -> Int {
                calendrier.dateComponents([.day], from: calendrier.startOfDay(for: date),
                                          to: aujourdhui).day ?? 0
            }
            let minutes = courses.map { max(0, $0.durationSeconds) / 60 }.filter { $0 > 0 }
            // La MÉDIANE et pas la moyenne : une seule sortie de deux heures dans le mois
            // tirerait la moyenne vers le haut et ferait proposer des footings que personne ne
            // fait d'habitude. C'est l'habitude qu'on cherche, pas l'exploit.
            //
            // Des variables LOCALES, puis l'affectation : une fermeture qui lirait
            // `typiqueMinutes` capturerait `self` avant la fin de l'initialisation, ce que
            // Swift refuse — et ce refus a raison, la valeur n'existerait pas encore pour tous
            // les chemins.
            let typique = minutes.isEmpty ? 30 : minutes.sorted()[minutes.count / 2]
            let longue = { (run: RunRecord) in Self.estLongue(run, typiqueMinutes: typique) }
            typiqueMinutes = typique
            plusLongueMinutes = minutes.max() ?? typique

            joursDepuisLaDerniere = courses.first.map { ecart($0.date) }
            laDerniereEtaitDure = courses.first.map(Self.estDure) ?? false
            laDerniereEtaitLongue = courses.first.map(longue) ?? false
            joursDepuisUneSeanceDure = courses.first(where: Self.estDure).map { ecart($0.date) }
            joursDepuisUneSortieLongue = courses.first(where: longue).map { ecart($0.date) }

            var consecutifs = 0
            var curseur = 1
            let joursCourus = Set(courses.map { ecart($0.date) })
            while joursCourus.contains(curseur) {
                consecutifs += 1
                curseur += 1
            }
            joursConsecutifs = consecutifs
        }

        /// Une course est DURE si son type le dit. Une sortie enregistrée sans type — un
        /// chronomètre lancé sans rien choisir, ce qui est le cas courant en course libre — ne
        /// l'est pas : mieux vaut proposer un footing de trop qu'interdire une séance sur une
        /// supposition.
        static func estDure(_ run: RunRecord) -> Bool {
            guard let famille = run.sessionKind?.family else { return false }
            return famille == .intervals || famille == .tempo
        }

        /// Longue, ça ne veut rien dire dans l'absolu : une heure est une sortie longue pour qui
        /// court trente minutes d'habitude, et un footing pour qui en court quatre-vingt-dix.
        /// Le seuil suit donc l'habitude, avec un plancher à quarante-cinq minutes.
        static func estLongue(_ run: RunRecord, typiqueMinutes: Int) -> Bool {
            if run.sessionKind?.family == .longRun { return true }
            let minutes = max(0, run.durationSeconds) / 60
            return minutes >= max(45, Int(Double(typiqueMinutes) * 1.4))
        }
    }

    // MARK: La décision

    /// Les règles, dans l'ordre, la première qui répond l'emporte.
    ///
    /// L'ordre EST la règle de sécurité : tout ce qui protège passe avant tout ce qui
    /// progresse. Une sortie longue attendue depuis huit jours ne doit pas s'imposer au
    /// lendemain d'un fractionné.
    static func intentionDuJour(reperes: Reperes, forme: Int) -> (Intention, String) {
        guard let joursDepuis = reperes.joursDepuisLaDerniere else {
            return (.recuperation, String(localized: "Première sortie : court et facile, on verra après."))
        }
        if joursDepuis >= joursAvantReprise {
            return (.recuperation, String(localized: "Ça fait un moment. On repart doucement, sans chrono."))
        }
        // Quatre jours d'affilée sans jamais souffler, ou trois quand la forme baisse déjà.
        if reperes.joursConsecutifs >= 4 || (reperes.joursConsecutifs >= 3 && forme < 70) {
            return (.repos, String(localized: "\(reperes.joursConsecutifs) jours d'affilée. Aujourd'hui, repos — c'est là que ça progresse."))
        }
        if joursDepuis <= 1, reperes.laDerniereEtaitDure {
            return (.recuperation, String(localized: "Hier c'était dur. Aujourd'hui on récupère, vraiment."))
        }
        if joursDepuis <= 1, reperes.laDerniereEtaitLongue {
            return (.recuperation, String(localized: "Après ta sortie longue d'hier, on reste très facile."))
        }
        if forme < 55 {
            return (.endurance, String(localized: "Ta forme est en baisse ces jours-ci. On garde ça tranquille."))
        }
        if joursDepuis >= 2, forme >= 65,
           (reperes.joursDepuisUneSortieLongue ?? 99) >= joursEntreSortiesLongues {
            return (.longue, String(localized: "Pas de sortie longue depuis une semaine. C'est le bon jour."))
        }
        if joursDepuis >= 2, forme >= 60,
           (reperes.joursDepuisUneSeanceDure ?? 99) >= joursEntreSeancesDeQualite {
            return (.qualite, String(localized: "Trois jours sans rien de rapide — on met un peu de vitesse."))
        }
        if joursDepuis <= 1 {
            return (.endurance, String(localized: "Tu as couru hier : footing facile, les jambes travaillent encore."))
        }
        return (.tonique, String(localized: "Rien de particulier à rattraper. Un footing avec un peu de jus."))
    }

    // MARK: De l'intention à la séance

    /// Les séances qui peuvent incarner chaque intention.
    ///
    /// AUCUN NOUVEAU TYPE DE SÉANCE n'est inventé ici : la palette réutilise ceux du plan
    /// structuré, qui ont déjà leur titre et leur sous-titre dans les trois langues, et leur
    /// couleur de famille. Un type de plus, c'est deux entrées de catalogue par langue et une
    /// branche de plus dans sept `switch` — pour une séance qui existe déjà sous un autre nom.
    ///
    /// Plusieurs variantes par intention, et c'est le point : deux jours d'endurance de suite ne
    /// montrent pas la même carte.
    static func variantes(_ intention: Intention) -> [SessionKind] {
        switch intention {
        case .repos: return [.rest]
        case .recuperation: return [.recoveryFooting]
        case .endurance: return [.easyFooting, .freeRunMaintenance, .enduranceFooting, .freeRunDiscovery]
        case .tonique: return [.stridesFooting, .freeRunDiscovery, .easyFooting]
        case .qualite: return [.freeRunLightIntervals, .tempoRun, .vo2maxIntervals]
        case .longue: return [.longRun]
        }
    }

    /// La durée visée, en minutes, avant plafonnement par le temps déclaré.
    ///
    /// C'EST ICI QU'EST LA PROGRESSION. La sortie longue repart de la plus longue réellement
    /// courue dans le mois et la gagne de 10 % — la même règle que `rampedLongRunKm` applique au
    /// plan structuré, et la seule qui fasse monter le reste avec elle : une longue plus longue
    /// finit par tirer la médiane, donc les footings, donc la longue suivante.
    static func minutes(_ intention: Intention, reperes: Reperes) -> Int {
        let typique = min(max(reperes.typiqueMinutes, 20), 120)
        switch intention {
        case .repos: return 0
        case .recuperation: return arrondi(max(20, Int(Double(typique) * 0.6)))
        case .endurance: return arrondi(typique)
        case .tonique: return arrondi(typique)
        // Une séance de qualité est plus courte qu'un footing, pas plus longue : l'intensité
        // remplace la durée, et une heure de fractionné n'est pas une progression, c'est une
        // blessure.
        case .qualite: return arrondi(min(45, max(28, typique)))
        case .longue:
            let depart = max(reperes.plusLongueMinutes, typique)
            // +10 %, et jamais plus d'un quart d'heure de plus d'un coup : le pourcentage seul
            // laisserait quelqu'un qui vient de faire trois heures en prendre dix-huit de plus.
            return arrondi(min(Int(Double(depart) * 1.10), depart + 15))
        }
    }

    /// Au multiple de cinq le plus proche — une suggestion de durée n'a pas à prétendre à la
    /// minute près, et « 37 min » se lit comme un calcul là où « 35 min » se lit comme un conseil.
    private static func arrondi(_ minutes: Int) -> Int {
        guard minutes > 0 else { return 0 }
        return max(5, Int((Double(minutes) / 5).rounded()) * 5)
    }

    private static func seancePour(_ intention: Intention, reperes: Reperes, profil: UserProfile,
                                   jour: Date, calendrier: Calendar) -> WorkoutSession {
        let choix = variantes(intention)
        // LE JOUR DE L'ANNÉE CHOISIT LA VARIANTE. Deux propriétés d'un coup : la carte change
        // d'un jour à l'autre à intention égale, et elle ne change PAS si l'on rouvre l'accueil
        // dix fois dans la journée. Un tirage au hasard aurait donné la première sans la
        // seconde, et une carte qui se réécrit sous les yeux ne se croit plus.
        let rang = calendrier.ordinality(of: .day, in: .year, for: jour) ?? 1
        let kind = choix[rang % choix.count]

        let zones = PaceModel.zones(for: profil)
        var duree = minutes(intention, reperes: reperes)
        // Le temps qu'elle a dit avoir, le jour où ça tombe — la même règle que le plan
        // structuré (voir `TempsDisponible`). Un repos n'a pas de durée à plafonner.
        if duree > 0, let plafond = TempsDisponible.plafond(jour: indexDuJour(jour, calendrier),
                                                            semaine: profil.tempsSemaineMin,
                                                            weekEnd: profil.tempsWeekEndMin) {
            duree = min(duree, plafond)
        }

        return WorkoutSession(
            title: titreFrancais(kind),
            subtitle: "",
            durationMinutes: duree,
            pace: allure(intention, zones: zones),
            zone: zoneTexte(intention),
            kind: kind,
            intervals: kind == .freeRunLightIntervals
                ? IntervalStructure(reps: 5, repMeters: 500, recoveryMeters: 300)
                : (kind == .vo2maxIntervals
                   ? IntervalStructure(reps: 6, repMeters: 800, recoveryMeters: 400) : nil)
        )
    }

    /// 0 = lundi … 6 = dimanche, comme partout ailleurs dans l'app — `Calendar` compte à partir
    /// de dimanche, lui, et l'oublier décalerait le plafond du week-end d'un jour.
    static func indexDuJour(_ jour: Date, _ calendrier: Calendar) -> Int {
        (calendrier.component(.weekday, from: jour) + 5) % 7
    }

    private static func allure(_ intention: Intention, zones: PaceModel.Zones) -> String {
        switch intention {
        case .repos: return "—"
        case .recuperation, .endurance, .longue: return zones.easy
        case .tonique: return zones.easy
        case .qualite: return zones.threshold
        }
    }

    private static func zoneTexte(_ intention: Intention) -> String {
        switch intention {
        case .repos: return "—"
        case .recuperation: return "Z1-2"
        case .endurance, .longue: return "Z2"
        case .tonique: return "Z2-3"
        case .qualite: return "Z3"
        }
    }

    /// Le libellé français écrit dans `WorkoutSession.title`, comme le fait le plan structuré.
    ///
    /// Ce n'est PAS ce qui s'affiche — `displayTitle` lit le catalogue par le `kind` — mais le
    /// champ existe, les séances enregistrées avant les types n'ont que lui, et le laisser vide
    /// casserait l'historique d'une sortie faite depuis cette carte.
    private static func titreFrancais(_ kind: SessionKind) -> String {
        switch kind {
        case .rest: return "Repos"
        case .recoveryFooting: return "Footing récup"
        case .easyFooting: return "Footing tranquille"
        case .enduranceFooting: return "Footing endurance"
        case .freeRunMaintenance: return "Footing d'entretien"
        case .freeRunDiscovery: return "Sortie découverte"
        case .stridesFooting: return "Footing tonique"
        case .freeRunLightIntervals: return "Fractionné léger 5 × 500 m"
        case .tempoRun: return "Tempo run"
        case .vo2maxIntervals: return "Fractionné VMA 6 × 800 m"
        default: return "Footing"
        }
    }
}
