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
    // ── Ultra-trail ───────────────────────────────────────────────────────────────────────────
    //
    // Onze séances qui n'existaient nulle part dans le moteur, parce qu'aucune d'elles n'a de
    // sens sur route. Elles se comptent en TEMPS et en dénivelé, jamais en kilomètres : voir
    // `UltraTrail`.
    case ultraEnduranceFooting = "ultra_endurance_footing"
    /// Les côtes longues : l'effort répété en montée, qui construit ce que le plat ne construit
    /// pas. Marcher dedans n'est pas un échec, c'est la technique.
    case ultraHillRepeats = "ultra_hill_repeats"
    /// La marche rapide en côte. LA compétence que personne n'entraîne et que tout le monde
    /// emploie : au-delà d'une certaine pente, marcher est plus rapide et moins coûteux que
    /// courir, et ça s'apprend.
    case ultraPowerHike = "ultra_power_hike"
    case ultraLongRun = "ultra_long_run"
    /// La descente technique. C'est elle qui détruit les quadriceps et qui décide de la seconde
    /// moitié d'un ultra — et c'est la seule qualité qu'un plan de route ne travaille jamais,
    /// puisque sur bitume on descend en roulant.
    case ultraDescentWork = "ultra_descent_work"
    case ultraSpecificLongRun = "ultra_specific_long_run"
    /// L'enchaînement du week-end, en deux séances distinctes : repartir le dimanche sur des
    /// jambes entamées reproduit la seconde moitié de l'épreuve, que rien d'autre ne reproduit
    /// sans courir huit heures d'affilée.
    case ultraBackToBackDay1 = "ultra_back_to_back_day_1"
    case ultraBackToBackDay2 = "ultra_back_to_back_day_2"
    /// La sortie de nuit, à la frontale. Un ultra se court dans le noir ; découvrir le jour J
    /// qu'on ne sait pas lire un sentier à la lampe est une mauvaise surprise évitable.
    case ultraNightRun = "ultra_night_run"
    case ultraTaperFooting = "ultra_taper_footing"
    /// Le rappel de terrain de l'affûtage : court, un peu de dénivelé, rien à construire. Les
    /// jambes gardent la mémoire du sol sans accumuler de fatigue.
    case ultraTerrainReminder = "ultra_terrain_reminder"

    // ── Triathlon ─────────────────────────────────────────────────────────────────────────────
    //
    // Dix séances, et c'est la première fois que le plan de cette app contient autre chose que
    // de la course à pied. La course, elle, réutilise les types qui existent déjà — un footing
    // d'endurance est un footing d'endurance, qu'on prépare un 10 km ou un olympique, et lui
    // écrire un jumeau n'aurait dupliqué que des traductions.
    //
    // CE QUI N'EXISTAIT PAS, C'EST DE SAVOIR DE QUELLE DISCIPLINE PARLE UNE SÉANCE. Le plan
    // était implicitement un plan de course : aucune séance n'avait à le dire. Voir
    // `disciplines` plus bas — c'est l'ajout structurel de ce lot, et c'est lui qui permet à la
    // natation d'apparaître dans une semaine.

    /// Pour qui ne nage pas encore, ou presque pas. L'objectif est le TEMPS DANS L'EAU, pas la
    /// distance : des longueurs courtes et autant de pauses qu'il faut. C'est la séance qui rend
    /// les autres possibles, et la seule que `NiveauDeNage.pasEncore` autorise au départ.
    case triSwimLearn = "tri_swim_learn"
    /// En natation, la technique fait plus de différence que la condition physique — c'est la
    /// seule des trois disciplines où c'est vrai, et c'est pour ça qu'elle a sa propre séance.
    case triSwimTechnique = "tri_swim_technique"
    case triSwimEndurance = "tri_swim_endurance"
    case triSwimIntervals = "tri_swim_intervals"
    /// L'eau libre : pas de mur pour se reposer, pas de ligne au fond pour aller droit. Relever
    /// la tête pour viser s'apprend, et une épreuve en lac se perd souvent là.
    case triOpenWater = "tri_open_water"
    case triBikeEndurance = "tri_bike_endurance"
    case triBikeThreshold = "tri_bike_threshold"
    /// LA SÉANCE QUI DÉFINIT LE TRIATHLON. Descendre du vélo et partir courir tout de suite :
    /// les premiers kilomètres ne ressemblent à rien de ce qu'on connaît, et c'est la seule
    /// chose qu'un plan de trois disciplines séparées ne construit jamais.
    case triBrick = "tri_brick"
    case triBrickRace = "tri_brick_race"
    /// Deux minutes gagnées en transition valent une séance de seuil, et personne ne les
    /// travaille. Ça se fait sur un parking, avec un vélo et des chaussures.
    case triTransitions = "tri_transitions"

    /// LA SÉANCE QUI DÉFINIT LE DUATHLON, et qui n'existe dans aucune autre discipline :
    /// courir, rouler, courir encore.
    ///
    /// Ce n'est pas un enchaînement vélo→course avec un échauffement devant. La première
    /// course change tout ce qui suit : on monte sur le vélo avec une fréquence cardiaque déjà
    /// haute, on en descend plus entamée, et la seconde course se négocie sur des jambes qui
    /// ont déjà donné deux fois. Qui ne l'a jamais fait part trop vite sur la première et
    /// marche sur la seconde — c'est l'erreur la plus courante de la discipline, et elle ne
    /// s'apprend qu'en la vivant à l'entraînement.
    ///
    /// Elle est réservée à l'affûtage : elle coûte cher, et sa valeur est d'être une
    /// RÉPÉTITION GÉNÉRALE, pas un volume de plus.
    case duaRunBikeRun = "dua_run_bike_run"

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
             .comeback,
             // Les footings d'ultra sont de l'endurance, pas autre chose : ce qui les distingue
             // est le terrain, pas la filière.
             .ultraEnduranceFooting, .ultraTaperFooting, .ultraTerrainReminder, .ultraPowerHike,
             // La natation et le vélo d'endurance sont de l'endurance : ce qui les distingue est
             // le milieu, pas la filière. Et apprendre à durer dans l'eau est de l'endurance
             // avant d'être quoi que ce soit d'autre.
             .triSwimLearn, .triSwimEndurance, .triOpenWater, .triBikeEndurance:
            return .endurance

        case .tempoRun, .hyroxTempoSled,
             // Le seuil à vélo est du tempo, et l'enchaînement aux allures du jour J aussi : on
             // y tient une intensité soutenue sans récupération, ce qui est la définition de
             // cette famille et pas celle du fractionné.
             .triBikeThreshold, .triBrick, .triBrickRace,
             // Course → vélo → course aux allures du jour J : un effort soutenu et continu,
             // sans récupération. C'est la définition du tempo, pas celle du fractionné.
             .duaRunBikeRun:
            return .tempo

        case .lightIntervals, .vo2maxIntervals, .racePaceReminder, .freeRunLightIntervals,
             // Les côtes et la descente d'ultra sont des séances en répétitions, structure à
             // l'appui : elles appartiennent donc ici, et `isIntervalWorkout` doit le dire en
             // même temps — l'invariant que `SessionFamilyTests` vérifie, et que la première
             // version de ces onze séances avait cassé.
             //
             // Ce n'est PAS ce qui les fait compter dans le plafond de deux séances dures par
             // semaine : ce plafond passe par `SessionArchetype.role`, pas par la famille. La
             // famille porte la couleur, et rien d'autre.
             .ultraHillRepeats, .ultraDescentWork,
             // Un fractionné en bassin est un fractionné : dix fois cent mètres, récupération au
             // mur. Il ne porte PAS d'`IntervalStructure` pour autant — cette structure décrit
             // des mètres mesurés au GPS, et il n'y a pas de GPS sous l'eau. L'écran de course
             // ne le verra jamais de toute façon : une nage ne se démarre pas depuis le
             // téléphone (voir `Discipline.seDemarreDepuisLeTelephone`).
             .triSwimIntervals:
            return .intervals

        case .longRun, .specificLongRun, .easedLongRun,
             .ultraLongRun, .ultraSpecificLongRun, .ultraBackToBackDay1, .ultraBackToBackDay2,
             .ultraNightRun:
            return .longRun

        case .hyroxTechnique, .hyroxTechniquePro, .hyroxIntenseCircuit, .hyroxIntenseCircuitPro,
             .hyroxCompromisedRun3, .hyroxCompromisedRun6, .hyroxCompromisedRunLight2,
             .hyroxStationsReminder, .hyroxLightSimulation, .hyroxLightFunctional,
             // La technique de nage et les transitions : hors de l'axe d'effort, comme le
             // renforcement HYROX. Ce qu'on y travaille n'est pas une filière énergétique, c'est
             // un geste — et dans les deux cas, c'est là que se trouvent les minutes les moins
             // chères de toute la préparation.
             .triSwimTechnique, .triTransitions:
            return .functional
        }
    }

    /// DE QUOI CETTE SÉANCE EST FAITE, dans l'ordre où on la fait.
    ///
    /// # L'HYPOTHÈSE QUI N'ÉTAIT ÉCRITE NULLE PART
    ///
    /// Le plan de cette app a toujours été un plan de COURSE. Aucune séance n'avait donc à dire
    /// sa discipline : il n'y en avait qu'une. Le vélo et le trail sont arrivés comme des façons
    /// d'ENREGISTRER une sortie, pas comme des choses que le plan prescrit — et la question ne
    /// s'est pas posée.
    ///
    /// Elle se pose avec le triathlon, parce qu'une semaine y contient trois disciplines et que
    /// « la séance du jour » n'est plus forcément une course. Sans cette propriété, une nage
    /// prescrite un mardi serait indistinguable d'un footing : même carte, même libellé de
    /// durée, et une case qui se cocherait en courant.
    ///
    /// # L'ENCHAÎNEMENT EN PORTE DEUX, DANS L'ORDRE
    ///
    /// `[.bike, .run]`, et pas l'inverse : tout le sens de la séance est dans cet ordre-là.
    /// Un tableau et non une valeur unique parce que réduire un enchaînement à l'une de ses deux
    /// moitiés serait écrire la moitié de la séance.
    ///
    /// # LES SÉANCES D'ULTRA SONT DU TRAIL, ET LE DISENT ENFIN
    ///
    /// Elles l'ont toujours été — « côtes longues », « descente technique », « sortie de nuit ».
    /// Elles se déclaraient course faute d'avoir où dire autre chose. Attention : ce que la
    /// séance EST et ce qui la COCHE sont deux questions différentes, et confondre les deux ici
    /// aurait fait qu'un footing sur route ne valide plus une journée de préparation d'ultra.
    /// Voir `estCompleteePar(_:)` juste en dessous.
    var disciplines: [Discipline] {
        switch self {
        case .rest:
            return []

        case .easyFooting, .lightIntervals, .longRun, .vo2maxIntervals, .tempoRun,
             .enduranceFooting, .specificLongRun, .maintenanceFooting, .racePaceReminder,
             .shortRun, .recoveryFooting, .stridesFooting, .easedLongRun,
             .comeback, .freeRunMaintenance, .freeRunLightIntervals, .freeRunDiscovery:
            return [.run]

        // HYROX : huit kilomètres de course et huit stations. La course est la seule discipline
        // que cette app sache nommer là-dedans — le renforcement n'en est pas une au sens de
        // `Discipline`, et lui en inventer une pour l'occasion serait ajouter un mode qui ne
        // mesure rien.
        case .hyroxBaseFooting, .hyroxTechnique, .hyroxTechniquePro, .hyroxIntenseCircuit,
             .hyroxIntenseCircuitPro, .hyroxCompromisedRun3, .hyroxCompromisedRun6,
             .hyroxCompromisedRunLight2, .hyroxTempoSled, .hyroxMaintenanceFooting,
             .hyroxStationsReminder, .hyroxLightSimulation, .hyroxRecoveryFooting,
             .hyroxLightFunctional:
            return [.run]

        case .ultraEnduranceFooting, .ultraHillRepeats, .ultraPowerHike, .ultraLongRun,
             .ultraDescentWork, .ultraSpecificLongRun, .ultraBackToBackDay1,
             .ultraBackToBackDay2, .ultraNightRun, .ultraTaperFooting, .ultraTerrainReminder:
            return [.trail]

        case .triSwimLearn, .triSwimTechnique, .triSwimEndurance, .triSwimIntervals,
             .triOpenWater:
            return [.swim]

        case .triBikeEndurance, .triBikeThreshold:
            return [.bike]

        // L'ordre EST la séance. Et les transitions se travaillent avec un vélo et des
        // chaussures, sur un parking : T1 au sens du matériel, T2 au sens du départ à pied.
        case .triBrick, .triBrickRace, .triTransitions:
            return [.bike, .run]
        // Les deux mêmes disciplines, dans un ordre qui commence et finit à pied. L'ordre
        // n'est pas représentable ici — `disciplines` dit CE QUI est fait, pas dans quel sens —
        // et c'est sans conséquence : les deux servent à savoir quelle séance une sortie
        // enregistrée valide, et une course comme un tour de vélo valident celle-ci.
        case .duaRunBikeRun:
            return [.run, .bike]
        }
    }

    /// Enregistrer une sortie dans CETTE discipline coche-t-il cette séance ?
    ///
    /// # POURQUOI CE N'EST PAS `disciplines.contains(_:)`
    ///
    /// Parce que ce que la séance EST et ce qui la COCHE ne sont pas la même question, et que
    /// les confondre casse un cas réel : une préparation d'ultra dont les séances sont du trail
    /// se fait en grande partie sur route — c'est même ce que fait tout le monde en semaine. Un
    /// `contains` strict aurait laissé « à faire » une journée faite, et le moteur aurait adapté
    /// la semaine suivante sur une séance qui a bien eu lieu.
    ///
    /// La règle est donc : la même discipline, ou n'importe quelle discipline CHAUSSÉE quand la
    /// séance en demande une. Courir valide une séance de trail, et le trail valide une séance
    /// de course — les deux se font avec les mêmes jambes et les mêmes chaussures.
    ///
    /// Nager, non. Rouler, non. C'est la généralisation de `Discipline.completesRunningPlan`, à
    /// ceci près qu'elle part désormais de la SÉANCE et non de la discipline : « est-ce que ça
    /// coche le plan de course » n'a plus de sens dans un plan qui contient trois disciplines.
    func estCompleteePar(_ discipline: Discipline) -> Bool {
        if disciplines.contains(discipline) { return true }
        return discipline.wearsShoes && disciplines.contains { $0.wearsShoes }
    }

    var isIntervalWorkout: Bool {
        switch self {
        case .lightIntervals, .vo2maxIntervals, .racePaceReminder, .freeRunLightIntervals,
             // Les côtes et les descentes d'ultra SONT des séances en répétitions, et elles
             // portent toutes deux une `IntervalStructure` : cinq montées de 600 m pour les
             // unes, quatre descentes de 1 200 m avec la remontée en récupération pour les
             // autres. L'écran Live doit donc les guider segment par segment comme un
             // fractionné — c'est ainsi qu'on les fait sur le terrain, et c'est ce que les
             // deux classifications doivent dire ensemble (voir `SessionFamilyTests`).
             .ultraHillRepeats, .ultraDescentWork,
             // Le fractionné en bassin, pour que `family == .intervals` et ce drapeau disent la
             // même chose — l'invariant que `SessionFamilyTests` vérifie. Sans structure
             // associée : voir le commentaire dans `family`.
             .triSwimIntervals:
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
    /// CE QUE LE MOTEUR A CHANGÉ, ET POURQUOI — « impact réduit », « allégé (phase menstruelle) ».
    ///
    /// Ces phrases étaient écrites dans `subtitle`, et `displaySubtitle` les jetait : `kind` est
    /// non optionnel sur toute séance générée, donc le sous-titre affiché venait TOUJOURS du
    /// catalogue et jamais du champ. La charge était bien allégée — durée réduite, zone abaissée —
    /// mais rien ne l'expliquait. Pour la phase folliculaire et l'ovulation, ce suffixe était le
    /// SEUL effet du suivi de cycle : la fonctionnalité ne produisait donc rien d'observable.
    ///
    /// Séparé de `subtitle` plutôt que concaténé dedans : le sous-titre décrit la séance, cette
    /// note décrit son adaptation. Les mélanger est ce qui a fait perdre la seconde.
    var adaptationNote: String? = nil

    /// Le titre à AFFICHER, dans la langue courante. Retombe sur le texte enregistré quand la
    /// séance est antérieure à `kind`.
    var displayTitle: String {
        guard let kind else { return title }
        return String(localized: String.LocalizationValue(kind.titleKey))
    }

    var displaySubtitle: String {
        let base = kind.map { String(localized: String.LocalizationValue($0.subtitleKey)) } ?? subtitle
        guard let adaptationNote else { return base }
        // La note est une clé française, comme `adjustment` : traduite ici, stockée telle quelle.
        // Une note venue du coach n'est pas au catalogue — la recherche échoue et la rend intacte,
        // ce qui est correct, le coach écrivant déjà dans la langue de l'utilisatrice.
        return base + " · " + String(localized: String.LocalizationValue(adaptationNote))
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

    /// Les initiales que la LANGUE utilise vraiment, et non la première lettre du nom complet.
    ///
    /// La version précédente prenait `String(nomComplet.prefix(1))`. C'est juste en français
    /// (L M M J V S D) et en anglais (M T W T F S S), et FAUX en espagnol : « miércoles »
    /// commence par un M, mais l'espagnol écrit X pour le distinguer de « martes ». La bande
    /// de la semaine affichait donc L M M J V S D à des hispanophones — deux M identiques là
    /// où leur calendrier, leur agenda et leur téléphone écrivent M puis X.
    ///
    /// `veryShortWeekdaySymbols` est exactement cette liste, telle que CLDR la définit pour
    /// chaque langue. Elle commence TOUJOURS par dimanche, quel que soit le premier jour de la
    /// semaine local, d'où le décalage : nos index comptent à partir de lundi.
    ///
    /// Le repli sur l'ancien calcul n'est pas décoratif — une liste de la mauvaise taille
    /// planterait l'accueil, et une initiale imparfaite vaut mieux qu'un écran qui ne s'ouvre
    /// pas.
    static let letters: [String] = {
        let symboles = DateFormatter().veryShortWeekdaySymbols ?? []
        guard symboles.count == 7 else {
            return DayStatus.fullNames.map { String($0.prefix(1)).uppercased() }
        }
        return (0..<7).map { symboles[($0 + 1) % 7].uppercased() }
    }()
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
