import Foundation

/// La structure réelle d'une séance en répétitions — extraite du TITRE jusqu'ici, par expression
/// régulière sur « N × D m ».
///
/// C'est ce qui pilote le guidage vocal segment par segment pendant la course et le découpage
/// affiché dans le détail de séance. Tant que le titre était toujours français, le lire
/// fonctionnait ; il suffisait de le traduire pour que « 6 × 800 m » cesse d'être reconnu et que
/// tout le coaching guidé retombe silencieusement en mode plat. La structure est donc une donnée
/// à part entière, plus une propriété du texte.
struct IntervalStructure: Codable, Equatable {
    var reps: Int
    var repMeters: Int
    /// La récupération entre répétitions, quand l'archétype en déclare une.
    var recoveryMeters: Int?

    var repKm: Double { Double(repMeters) / 1000 }
}

/// L'identité d'une séance, indépendante de la langue.
///
/// Les titres et sous-titres étaient composés en français par le moteur puis ÉCRITS EN BASE, donc
/// le français vivait dans les données et pas dans l'affichage : traduire l'interface laissait le
/// programme en français sur un téléphone anglais. Un `kind` permet de stocker QUOI est la séance
/// et de rédiger le texte au moment de l'afficher, dans la langue du moment.
///
/// `rawValue` explicite et stable : c'est ce qui est persisté. Renommer un cas Swift ne doit
/// jamais invalider les plans déjà enregistrés.
/// Les sept familles de séance, de la plus calme à la plus dure.
///
/// L'ordre des cas est celui de l'effort : il sert de tri naturel partout où une légende ou un
/// récapitulatif doit les présenter, sans qu'aucun écran ait à réinventer le classement.
enum SessionFamily: String, CaseIterable, Codable, Equatable {
    case rest
    case recovery
    case endurance
    case longRun
    case tempo
    case intervals
    /// Le renforcement et la technique HYROX. Hors de l'axe d'effort de la course — il vient donc
    /// en dernier plutôt qu'à une place qu'il ne mérite ni d'un côté ni de l'autre.
    case functional

    /// Les familles qui demandent un jour de récupération derrière elles.
    ///
    /// C'est la règle que le générateur applique déjà — deux séances de qualité par semaine au
    /// maximum, jamais dos à dos — exprimée sur l'axe des familles, pour que le déplacement manuel
    /// d'une séance puisse prévenir quand il s'apprête à la défaire.
    ///
    /// Le renforcement en fait partie. Toutes les séances fonctionnelles ne sont pas dures — la
    /// technique de station l'est peu — mais les circuits intenses et les courses compromises
    /// dominent la famille, et sur une question de blessure, avertir en trop coûte un haussement
    /// d'épaules là où avertir en moins coûte une semaine d'arrêt.
    var isDemanding: Bool {
        switch self {
        case .rest, .recovery, .endurance: return false
        case .longRun, .tempo, .intervals, .functional: return true
        }
    }
}

enum SessionKind: String, Codable, Equatable, CaseIterable {
    case easyFooting = "easy_footing"
    case lightIntervals = "light_intervals"
    case longRun = "long_run"
    case vo2maxIntervals = "vo2max_intervals"
    case tempoRun = "tempo_run"
    case enduranceFooting = "endurance_footing"
    case specificLongRun = "specific_long_run"
    case maintenanceFooting = "maintenance_footing"
    case racePaceReminder = "race_pace_reminder"
    case shortRun = "short_run"
    case recoveryFooting = "recovery_footing"
    case stridesFooting = "strides_footing"
    case easedLongRun = "eased_long_run"
    case hyroxBaseFooting = "hyrox_base_footing"
    /// Les deux séances fonctionnelles existent en version standard et « charge renforcée »
    /// (division pro). C'était une interpolation dans le sous-titre — deux cas distincts plutôt
    /// qu'une phrase à trous, parce qu'une phrase à trous se traduit mal : l'espagnol et l'anglais
    /// ne placent pas ce complément au même endroit.
    case hyroxTechnique = "hyrox_technique"
    case hyroxTechniquePro = "hyrox_technique_pro"
    case hyroxIntenseCircuitPro = "hyrox_intense_circuit_pro"
    case hyroxCompromisedRun3 = "hyrox_compromised_run_3"
    case hyroxIntenseCircuit = "hyrox_intense_circuit"
    case hyroxTempoSled = "hyrox_tempo_sled"
    case hyroxCompromisedRun6 = "hyrox_compromised_run_6"
    case hyroxMaintenanceFooting = "hyrox_maintenance_footing"
    case hyroxStationsReminder = "hyrox_stations_reminder"
    case hyroxLightSimulation = "hyrox_light_simulation"
    case hyroxRecoveryFooting = "hyrox_recovery_footing"
    case hyroxLightFunctional = "hyrox_light_functional"
    case hyroxCompromisedRunLight2 = "hyrox_compromised_run_light_2"
    case rest = "rest"
    case comeback = "comeback"
    case freeRunMaintenance = "free_run_maintenance"
    case freeRunLightIntervals = "free_run_light_intervals"
    case freeRunDiscovery = "free_run_discovery"

    /// Les clés du catalogue de traduction. Le préfixe évite toute collision avec une phrase
    /// d'interface qui se trouverait dire la même chose.
    var titleKey: String { "session.\(rawValue).title" }
    var subtitleKey: String { "session.\(rawValue).subtitle" }

    /// Les séances qui comptent comme du fractionné — celles dont l'ancien code détectait le
    /// titre par les mots « fractionné » et « rappel d'allure ».
    ///
    /// À ne pas confondre avec « possède une structure en répétitions » : les courses compromises
    /// HYROX sont bien découpées en « N × 1 km » et recevaient donc un guidage segment par
    /// segment, sans jamais être étiquetées fractionné. Cette différence était portée par deux
    /// mécanismes distincts (recherche de mots d'un côté, expression régulière de l'autre) ; la
    /// perdre en unifiant aurait changé l'affichage de toutes les séances HYROX.
    /// La FAMILLE de la séance — l'axe que quelqu'un lit vraiment en ouvrant son plan.
    ///
    /// Trente-deux types de séance, c'est un vocabulaire de moteur d'entraînement, pas une chose
    /// qu'on regarde. Sept familles, c'est une palette : trois vertes, une rouge, une violette, et
    /// la semaine se lit sans lire un mot. C'est ce qui manquait au plan, dont les lignes étaient
    /// toutes de la même couleur et devaient donc être lues une par une.
    ///
    /// `.intervals` reprend EXACTEMENT `isIntervalWorkout`, et pas « ce qui a une structure en
    /// répétitions » : les courses compromises HYROX sont découpées en « N × 1 km » sans avoir
    /// jamais été étiquetées fractionné, et la distinction est déjà portée ailleurs dans l'app.
    /// Deux classifications qui se contrediraient seraient pires qu'une seule imparfaite.
    ///
    /// Le `switch` est exhaustif, sans `default:` — un type de séance ajouté demain ne compilera
    /// pas tant que sa famille n'aura pas été choisie. C'est voulu : le repli silencieux d'un
    /// `default` donnerait une couleur plausible à une séance mal classée, ce qui est le seul
    /// résultat vraiment coûteux ici.
    var family: SessionFamily {
        switch self {
        case .rest:
            return .rest

        case .recoveryFooting, .hyroxRecoveryFooting:
            return .recovery

        case .easyFooting, .enduranceFooting, .maintenanceFooting, .shortRun, .stridesFooting,
             .hyroxBaseFooting, .hyroxMaintenanceFooting, .freeRunMaintenance, .freeRunDiscovery,
             .comeback:
            return .endurance

        case .tempoRun, .hyroxTempoSled:
            return .tempo

        case .lightIntervals, .vo2maxIntervals, .racePaceReminder, .freeRunLightIntervals:
            return .intervals

        case .longRun, .specificLongRun, .easedLongRun:
            return .longRun

        case .hyroxTechnique, .hyroxTechniquePro, .hyroxIntenseCircuit, .hyroxIntenseCircuitPro,
             .hyroxCompromisedRun3, .hyroxCompromisedRun6, .hyroxCompromisedRunLight2,
             .hyroxStationsReminder, .hyroxLightSimulation, .hyroxLightFunctional:
            return .functional
        }
    }

    var isIntervalWorkout: Bool {
        switch self {
        case .lightIntervals, .vo2maxIntervals, .racePaceReminder, .freeRunLightIntervals:
            return true
        default:
            return false
        }
    }
}

/// A single planned workout — today's hero session, or a day in the full plan. Embedded value
/// type (Codable), not its own SwiftData entity: it only ever exists nested inside `UserProfile`
/// or generated on the fly for the Plan screen's week list.
struct WorkoutSession: Codable, Equatable {
    /// Le libellé français tel que le moteur le compose. Il n'est PLUS ce qu'on affiche — voir
    /// `displayTitle` — mais il est conservé, et il garde deux rôles :
    ///
    /// 1. Les plans enregistrés avant `kind` n'ont que lui. Le retirer les rendrait muets.
    /// 2. Il reste **toujours français**, quelle que soit la langue de l'appareil, ce qui en fait
    ///    un identifiant interne stable. `SessionDetailSheet` continue de s'en servir pour
    ///    classer une séance (tempo, HYROX, côtes…) sans que traduire l'affichage ne casse cette
    ///    classification — c'est précisément le piège qui rendait la traduction impossible.
    var title: String
    var subtitle: String
    var durationMinutes: Int
    var pace: String
    var zone: String
    /// e.g. "+1 palier" when the coach bumped difficulty — nil when unchanged.
    var adjustment: String?
    /// Nil pour toute séance enregistrée avant l'introduction de ce champ : le décodage d'un
    /// optionnel absent donne nil, donc aucune migration n'est nécessaire et aucun plan en cours
    /// n'est perdu.
    var kind: SessionKind? = nil
    /// Nil pour un effort continu (footing, tempo, sortie longue) — et pour les séances
    /// anciennes, qui retombent alors sur l'analyse du titre.
    var intervals: IntervalStructure? = nil

    /// Le titre à AFFICHER, dans la langue courante. Retombe sur le texte enregistré quand la
    /// séance est antérieure à `kind`.
    var displayTitle: String {
        guard let kind else { return title }
        return String(localized: String.LocalizationValue(kind.titleKey))
    }

    var displaySubtitle: String {
        guard let kind else { return subtitle }
        return String(localized: String.LocalizationValue(kind.subtitleKey))
    }

    static let reprise = WorkoutSession(
        title: "Footing de reprise",
        subtitle: "on repart en douceur sur de nouvelles bases",
        durationMinutes: 30, pace: "5:30", zone: "Z2", adjustment: nil,
        kind: .comeback
    )

    /// True only for the archetypes actually structured as reps + recovery (see
    /// `AdaptivePlanEngine.archetypes`) — a footing/tempo/sortie longue is one continuous effort,
    /// not a set of intervals. Shared by `SessionDetailSheet` (step breakdown) and the Live Run
    /// screen (interval-progress badge) so both agree on what counts as an interval session.
    /// Vrai quand la séance est réellement structurée en répétitions.
    ///
    /// Repose désormais sur `intervals`, une donnée, et non plus sur la présence des mots
    /// « fractionné » ou « rappel d'allure » dans le titre. Cette recherche de mots français est
    /// conservée UNIQUEMENT pour les séances enregistrées avant `kind` : traduire un titre
    /// l'aurait rendue fausse partout, et le guidage vocal segment par segment serait retombé en
    /// mode plat sans que rien ne le signale.
    var isIntervalSession: Bool {
        if let kind { return kind.isIntervalWorkout }
        let t = title.lowercased()
        return t.contains("fractionné") || t.contains("rappel d'allure")
    }

    /// La famille de cette séance, pour la couleur qui la désigne dans le plan.
    ///
    /// Les plans enregistrés avant l'introduction de `kind` n'ont pas de type, et il n'est pas
    /// question de les laisser sans couleur : le repli reprend la seule distinction que ces
    /// séances-là portent encore — durée nulle, donc repos ; sinon fractionné ou endurance, lu
    /// dans le titre par `isIntervalSession`. Trois familles au lieu de sept sur les vieux plans,
    /// mais aucune ligne muette au milieu d'une semaine colorée.
    var family: SessionFamily {
        if let kind { return kind.family }
        if durationMinutes == 0 { return .rest }
        return isIntervalSession ? .intervals : .endurance
    }

    /// Parses "N × Dm" / "N × D km" straight from the title (e.g. "5 × 500 m", "6 × 800m",
    /// "3 × 1 km") — the same pattern `SessionDetailSheet.intervalDescription` already extracts
    /// for display, reused here so Live can actually DRIVE guided execution (real segment-by-
    /// segment cues) instead of just labeling a flat distance-based progress chip. Nil when the
    /// title doesn't declare a real rep/distance structure — callers fall back to non-guided
    /// behavior rather than guessing a shape that isn't there.
    var intervalStructure: (reps: Int, repKm: Double)? {
        if let intervals { return (intervals.reps, intervals.repKm) }
        // Repli sur l'ancien format : uniquement pour les séances sans `kind`.
        guard kind == nil else { return nil }
        guard let range = title.range(of: #"\d+\s*×\s*\d+\s?(m|km)"#, options: .regularExpression) else { return nil }
        let matched = String(title[range])
        let parts = matched.components(separatedBy: "×")
        guard parts.count == 2, let reps = Int(parts[0].trimmingCharacters(in: .whitespaces)), reps > 0 else { return nil }
        var distancePart = parts[1].trimmingCharacters(in: .whitespaces)
        let isKm = distancePart.lowercased().hasSuffix("km")
        distancePart = distancePart.replacingOccurrences(of: "km", with: "").replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = Double(distancePart), value > 0 else { return nil }
        return (reps, isKm ? value : value / 1000)
    }
}

/// One day in the current week's real training plan (as opposed to `DayStatus`, which only
/// tracks the home strip's done/today/rest badge). `session == nil` means a rest day. Generated
/// fresh for the whole week at once by `AdaptivePlanEngine.generateWeekSessions`, so every day is
/// already planned before the week starts — adaptation only regenerates this at a week boundary,
/// never after an individual run.
struct PlannedDay: Codable, Equatable, Identifiable {
    var id: Int { weekday }
    /// 0 = Monday ... 6 = Sunday.
    var weekday: Int
    var session: WorkoutSession?
    var completed: Bool = false
}

/// One day in the 7-cell week strip on Home.
struct DayStatus: Codable, Equatable, Identifiable {
    enum State: String, Codable {
        case done, today, upcoming, rest
    }

    var id: Int { weekday }
    /// 0 = Monday ... 6 = Sunday.
    var weekday: Int
    /// ⚠️ Conservé pour décoder les profils existants, mais **à ne jamais afficher**.
    ///
    /// `weekStrip` est persisté dans SwiftData, donc cette lettre a été calculée UNE FOIS, dans la
    /// langue de l'app à la création du profil, et écrite en base. Un téléphone passé en anglais
    /// affichait donc « L M M J V S D » au milieu d'une interface anglaise — exactement le défaut
    /// que `SessionKind` avait éliminé pour les titres de séance, reproduit un cran plus loin.
    ///
    /// Utiliser `displayLetter` à la place : il se recalcule à chaque affichage.
    var letter: String
    var state: State
    /// The real calendar date this cell represents — lets the strip show an actual date number
    /// (like "12", today circled) instead of just a bare weekday letter. Defaults to `.now` when
    /// decoding a `weekStrip` persisted before this field existed, so existing profiles don't
    /// crash on launch.
    var date: Date = .now

    /// L'initiale à AFFICHER, dans la langue courante — dérivée du jour de la semaine, jamais
    /// relue de la base.
    var displayLetter: String { DayStatus.letters[min(max(weekday, 0), DayStatus.letters.count - 1)] }

    /// Dérivées des noms complets, et non écrites en dur : « L M M J V S D » n'est juste qu'en
    /// français et en espagnol. L'initiale du nom traduit donne la bonne lettre dans chaque
    /// langue (M T W T F S S en anglais) sans avoir à maintenir une seconde liste — et sans clé
    /// de catalogue ambiguë, deux jours partageant la même initiale.
    static let letters = DayStatus.fullNames.map { String($0.prefix(1)).uppercased() }
    /// Mardi/Mercredi share the same letter — VoiceOver needs the real name behind a day button,
    /// not just its ambiguous glyph.
    static let fullNames = [
        String(localized: "Lundi"),
        String(localized: "Mardi"),
        String(localized: "Mercredi"),
        String(localized: "Jeudi"),
        String(localized: "Vendredi"),
        String(localized: "Samedi"),
        String(localized: "Dimanche"),
    ]

    private enum CodingKeys: String, CodingKey { case weekday, letter, state, date }

    init(weekday: Int, letter: String, state: State, date: Date = .now) {
        self.weekday = weekday
        self.letter = letter
        self.state = state
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekday = try c.decode(Int.self, forKey: .weekday)
        letter = try c.decode(String.self, forKey: .letter)
        state = try c.decode(State.self, forKey: .state)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? .now
    }
}
