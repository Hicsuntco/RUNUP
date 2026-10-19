import Foundation
import Observation

/// Drives the 9-step onboarding wizard. Mirrors the local state hooks in `Onboarding` (onboarding.jsx),
/// plus a step 4 (injury/cycle) split out of what used to be a combined step 3.
@Observable
final class OnboardingViewModel {
    static let totalSteps = 10

    /// Le dernier écran qui POSE UNE QUESTION. Au-delà, il ne reste que la construction du
    /// programme, qui ne demande rien et se regarde.
    ///
    /// Séparé de `totalSteps` parce que les deux répondent à deux questions différentes :
    /// `totalSteps` borne l'index, celui-ci borne l'effort. C'est lui que la barre de
    /// progression et la ligne « plus que N écrans » doivent compter — une barre qui réserve un
    /// trait pour un écran sans question n'atteint jamais son bout quand la personne a fini de
    /// répondre.
    static let dernierEcranDeQuestions = totalSteps - 2

    /// Le nombre d'écrans de questions — neuf.
    static let totalEcransDeQuestions = dernierEcranDeQuestions + 1

    /// À partir d'où la ligne « plus que N écrans » s'affiche.
    ///
    /// Quatre, soit l'écran qui suit immédiatement celui de l'objectif. Les huit vidéos qui
    /// vendent l'app s'arrêtent à celui-là, bouton « BUILD MY PLAN » compris : c'est exactement
    /// là que quelqu'un qui les a vues croit avoir fini. Voir `ObResteALire`.
    static let premierEcranAvecLeReste = 4

    /// Ce qu'il reste à lire, dit à la personne — ou `nil` quand il n'y a rien à dire.
    ///
    /// Le calcul vit ICI, avec les trois bornes dont il dépend, et pas dans la vue : c'est la
    /// seule façon de le vérifier sans lancer l'app, et c'est exactement le genre d'arithmétique
    /// qu'une étape insérée au milieu rend fausse en silence. Voir `ObResteALire` pour le
    /// pourquoi de la phrase, et `ResteALireTests` pour ce qu'elle doit dire.
    static func resteALire(apres etape: Int) -> String? {
        guard etape >= premierEcranAvecLeReste, etape <= dernierEcranDeQuestions else { return nil }
        let restants = dernierEcranDeQuestions - etape
        if restants == 0 {
            return String(localized: "Dernier écran — ton plan arrive juste après.")
        }
        return Pluriel.choisir(restants,
                               String(localized: "Plus qu'un écran, et ton plan est prêt."),
                               String(localized: "Plus que \(restants) écrans, et ton plan est prêt."))
    }

    var showWelcome = true
    var step = 0

    init() {
        loadDraft()
    }

    // Step 0
    var name = ""
    /// Le nom de famille, demandé sur le même écran que le prénom — voir `NameStepView`.
    var lastName = ""
    // Step 1
    var birthdate: Date?
    var sex: String?
    // Step 2
    var goal: GoalType?
    // Step 3 — race branch
    var distance: RaceDistance?
    var customDistance = ""
    /// Le D+ de la course, saisi en mètres. Une chaîne et non un `Int` : c'est un champ de
    /// texte, et l'état d'un champ de texte à moitié rempli n'est pas un nombre.
    var raceElevationGain = ""
    var chrono: String?
    var isCustomChrono = false
    var raceDate: Date?
    // Step 3 — HYROX branch (reuses `chrono`/`raceDate` above for target finish time/event date)
    var hyroxDivision: HyroxDivision?
    // Step 3 — branche triathlon. Réutilise `chrono` (le temps visé) et `raceDate` (la date de
    // l'épreuve) comme HYROX : les deux veulent dire exactement la même chose ici.
    var triathlonFormat: TriathlonFormat?
    /// Ce qu'elle nage en continu AUJOURD'HUI. Sans valeur par défaut, volontairement : c'est la
    /// seule question de l'inscription dont une réponse supposée peut faire du mal, et « 1500 m
    /// et plus » pré-cochée serait une réponse supposée. Voir `NiveauDeNage`.
    var nageNiveau: NiveauDeNage?
    // Step 3 — branche duathlon. Même réutilisation de `chrono` et `raceDate`, et UN SEUL
    // champ : il n'y a pas de question de vélo à poser. Voir `DuathlonFormat`.
    var duathlonFormat: DuathlonFormat?
    // Étape « où tu en es » — posée à TOUS les objectifs, voir `PointDeDepart.swift`.
    var volumeActuel: VolumeActuel?
    var plusLongueSortie: PlusLongueSortie?
    /// Le repli d'allure, demandé seulement quand aucune perf récente n'est donnée.
    var allureFooting: AllureFooting?
    /// Le temps disponible pour UNE séance, posé avec les jours de course — c'est la même
    /// question, vue de l'autre côté : quels jours, et combien de temps ces jours-là.
    var tempsSemaineMin: Int?
    var tempsWeekEndMin: Int?
    // Step 3 — non-race branches
    var weightNow = ""
    var weightTarget = ""
    var height = ""
    var focusArea: String?
    var bestRecentPerf = ""
    var lastRanRecency: String?
    var weeklyTimeBudget: String?
    var preferredTimeOfDay: String?
    // Step 4 — shared across every branch (race included): injury is asked regardless of goal,
    // cycle tracking only ever offered when `sex == "female"`.
    var injuryArea: String?
    /// Depuis quand — posé seulement si une zone a été cochée. Voir `AncienneteBlessure`.
    var injuryWhen: AncienneteBlessure?
    var terrains: Set<Terrain> = []
    var autresSports: Set<AutreSport> = []
    var cycleTrackingEnabled = false
    var lastPeriodStartDate: Date?
    var averageCycleLengthDays = 28
    // Step 5
    var runningDays: Set<Int> = [1, 2, 4, 6]
    var preferredLongRunDay: Int?
    /// Set the moment she taps any day toggle — `runningDays` starts pre-filled with a plausible
    /// default so the screen isn't empty, but a plan built from that default without her ever
    /// touching it would be guessing at her real rhythm, not asking. Gates `canProceed(fromStep:
    /// 5)` alongside the existing 2-day minimum.
    var runningDaysTouched = false

    /// The day the long run actually lands on — falls back to the latest selected running day if
    /// none was explicitly chosen, or if the chosen one got deselected.
    var effectiveLongRunDay: Int? {
        if let day = preferredLongRunDay, runningDays.contains(day) { return day }
        return runningDays.max()
    }
    // Step 6
    var level: ExperienceLevel = .intermediaire
    /// Same reasoning as `runningDaysTouched` — `level` defaults to `.intermediaire` so a card is
    /// always shown as selected, but the plan's whole starting difficulty comes from this one
    /// answer and shouldn't ship on a default she never confirmed.
    var levelTouched = false
    // Step 7
    var connected: Set<ConnectedSource> = []
    var connecting: ConnectedSource?
    // Step 8
    var buildProgress = 0

    var isRace: Bool { goal == .race }
    var isHyrox: Bool { goal == .hyrox }
    var isUltra: Bool { goal == .ultraTrail }
    var isTriathlon: Bool { goal == .triathlon }
    var isDuathlon: Bool { goal == .duathlon }

    /// Le nombre de jours que l'objectif choisi exige. Deux tant qu'aucun objectif n'est encore
    /// choisi : l'étape des jours vient après celle de l'objectif, donc ce repli n'est atteint
    /// que par un brouillon incomplet.
    var joursMinimum: Int { goal?.joursMinimumParSemaine ?? 2 }
    /// L'étape « ta course » sert aux deux : un ultra-trail EST une course, avec une question
    /// de plus. Lui faire un écran séparé aurait dupliqué la distance, le chrono et la date
    /// pour un seul champ de différence.
    var isCourseOuUltra: Bool { isRace || isUltra }
    /// Le D+ saisi, quand c'en est un. Zéro et le vide sont la même réponse ici : « je ne sais
    /// pas », auquel cas le plan retombe sur une course plate.
    var raceElevationGainM: Int? {
        let brut = Int(raceElevationGain.trimmingCharacters(in: .whitespaces))
        return (brut ?? 0) > 0 ? brut : nil
    }

    var age: Int? {
        guard let birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: .now).year
    }

    var daysUntilRace: Int? {
        guard let raceDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: raceDate).day ?? 0
        return max(1, days)
    }

    /// L'ÉTAPE COURANTE PEUT-ELLE ÊTRE QUITTÉE — lue sur le modèle, jamais recopiée.
    ///
    /// Chaque écran écrivait son propre numéro : `canProceed(fromStep: 5)` dans la vue des
    /// jours, 6 dans celle du niveau. Le même nombre vivait donc à deux endroits — ici dans le
    /// `switch`, et là-bas dans la vue — et il a suffi d'insérer une étape au milieu pour que
    /// les deux divergent en silence. Trois écrans se sont mis à valider les réponses de leur
    /// voisin ; celui des jours de course, en particulier, laissait passer une semaine à zéro
    /// jour, parce qu'il interrogeait une étape qui répond toujours oui.
    ///
    /// Rien ne cassait, rien ne compilait de travers, aucun test ne tombait. C'est le propre
    /// d'un nombre recopié : il reste juste jusqu'au jour où il ne l'est plus.
    var peutContinuer: Bool { canProceed(fromStep: step) }

    func canProceed(fromStep step: Int) -> Bool {
        switch step {
        // LES DEUX, ET PAS SEULEMENT LE PRÉNOM.
        //
        // Le nom ne sert à rien hors du Club — le coach dit « Charlotte ». Il est exigé quand
        // même, parce que c'est l'autre moitié de ce que la recherche de « Mes amis » interroge
        // (`name || ' ' || last_name` côté serveur) : sans lui et sans pseudo, un compte n'est
        // trouvable que par son adresse e-mail exacte, ce qui n'est le chemin de personne.
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return birthdate != nil && sex != nil
        case 2: return goal != nil
        case 3:
            if isCourseOuUltra { return raceStepValid }
            if isHyrox { return hyroxStepValid }
            if isTriathlon { return triathlonStepValid }
            if isDuathlon { return duathlonStepValid }
            return deepDiveValid
        // LES DEUX PREMIÈRES SONT EXIGÉES, LA TROISIÈME NON.
        //
        // Le volume et la plus longue sortie ancrent le plan ; sans eux il repart de la distance
        // de la course, c'est-à-dire du défaut que cette étape existe pour corriger. L'allure,
        // elle, a « Je ne sais pas » dans sa liste : c'est une vraie réponse, et exiger un choix
        // reviendrait à exiger qu'on invente un chiffre que le plan prendrait au mot.
        case 4: return volumeActuel != nil && plusLongueSortie != nil
        // Injury/cycle fields are always optional — a real, known injury/blessure worth flagging
        // is the exception, not the rule, so requiring an answer here would just add friction for
        // the common case of "nothing to report."
        case 5: return true
        // Le minimum vient de l'OBJECTIF, pas d'un littéral : un triathlon en exige trois,
        // parce qu'une semaine à deux jours ne peut pas contenir trois disciplines. Voir
        // `GoalType.joursMinimumParSemaine`.
        // Le temps par séance est EXIGÉ, comme les jours : c'est lui qui plafonne chaque
        // durée du plan, et sans lui le programme repart de ses constantes d'archétype —
        // c'est-à-dire du défaut que la question existe pour corriger.
        case 6: return runningDays.count >= joursMinimum && runningDaysTouched
                    && tempsSemaineMin != nil && tempsWeekEndMin != nil
        case 7: return levelTouched
        case 8: return true
        default: return true
        }
    }

    private var raceStepValid: Bool {
        guard let distance else { return false }
        if distance == .other && customDistance.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        // Le dénivelé est EXIGÉ pour un ultra, et seulement pour lui. Sans ce nombre, le plan ne
        // peut pas calculer un temps d'effort, donc il retomberait sur des kilomètres plats —
        // c'est-à-dire sur le défaut que tout l'objectif existe pour corriger. Mieux vaut une
        // question de plus qu'un plan faux.
        if isUltra && raceElevationGainM == nil { return false }
        return hasChrono && raceDate != nil
    }

    private var hyroxStepValid: Bool {
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        return hasChrono && raceDate != nil && hyroxDivision != nil
    }

    /// Le format ET le niveau de natation sont exigés, et le niveau n'a pas de valeur par
    /// défaut — c'est ce qui le rend obligatoire. Le chrono et la date, comme pour HYROX.
    ///
    /// Exiger le niveau de natation est le pendant d'exiger le dénivelé pour un ultra (voir
    /// `raceStepValid`) : sans ce nombre, le plan ne peut pas dimensionner la seule discipline
    /// qu'il ne saura jamais mesurer. Mieux vaut une question de plus qu'un plan faux — et ici,
    /// qu'un plan qui envoie quelqu'un nager 1500 m sans l'avoir demandé.
    private var triathlonStepValid: Bool {
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        return hasChrono && raceDate != nil && triathlonFormat != nil && nageNiveau != nil
    }

    /// TROIS RÉPONSES, PAS QUATRE. Le format, un chrono, une date.
    ///
    /// Rien sur le vélo, et c'est le seul écart avec le triathlon juste au-dessus : la question
    /// de natation y est obligatoire parce que le plan ne pourra jamais la corriger tout seul.
    /// Le vélo, l'app le mesure — distance, durée, cardio — donc une réponse approximative se
    /// rattrape à la première sortie. Une question qui ne change pas une décision ne vaut pas
    /// une étape.
    ///
    /// La lecture du chrono est la MÊME qu'au triathlon, délibérément : « Mon propre temps »
    /// laisse le champ libre, et un `chrono != nil` seul laisserait passer une chaîne vide.
    private var duathlonStepValid: Bool {
        let hasChrono = isCustomChrono ? !(chrono ?? "").isEmpty : chrono != nil
        return hasChrono && raceDate != nil && duathlonFormat != nil
    }

    private var deepDiveValid: Bool {
        switch goal {
        // La taille n'est plus exigée : elle n'enrichit qu'une phrase du contexte envoyé au
        // coach, qui sait déjà écrire « ? » quand elle manque. Bloquer l'étape sur une
        // troisième mesure corporelle était de la friction sans contrepartie.
        case .weight: return !weightNow.isEmpty && !weightTarget.isEmpty
        case .progress: return focusArea != nil
        case .restart: return lastRanRecency != nil
        // Le budget hebdomadaire n'est plus demandé — voir `DeepDiveStepView`. Il reste sur le
        // modèle et en base : les profils qui l'ont répondu le gardent, et le coach continue de
        // le lire.
        case .health: return preferredTimeOfDay != nil
        default: return true
        }
    }

    /// Choisir un format pré-remplit le chrono, comme `selectDistance` le fait pour une course.
    /// Le deuxième preset et non le premier : le premier est une belle performance, le deuxième
    /// est le temps que fait la plupart des gens qui finissent.
    func selectTriathlonFormat(_ f: TriathlonFormat) {
        triathlonFormat = f
        chrono = f.chronoPresets[safe: 1]
        isCustomChrono = false
    }

    /// Même geste pour le duathlon, et le même deuxième preset : le premier est une belle
    /// performance, le deuxième est le temps que fait la plupart des gens qui finissent.
    func selectDuathlonFormat(_ f: DuathlonFormat) {
        duathlonFormat = f
        chrono = f.chronoPresets[safe: 1]
        isCustomChrono = false
    }

    func selectDistance(_ d: RaceDistance) {
        distance = d
        if d != .other {
            chrono = d.chronoPresets[safe: 1]
            isCustomChrono = false
        } else {
            chrono = nil
        }
    }


    func buildResult() -> AdaptivePlanEngine.OnboardingResult {
        AdaptivePlanEngine.OnboardingResult(
            name: name.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            birthdate: birthdate,
            sex: sex,
            goal: goal ?? .health,
            raceDistance: isCourseOuUltra ? distance : nil,
            raceDistanceCustom: isCourseOuUltra ? customDistance : nil,
            raceElevationGainM: isUltra ? raceElevationGainM : nil,
            // Les trois objectifs à date partagent ces deux champs : la course et l'ultra par
            // `isCourseOuUltra`, HYROX et le triathlon chacun pour soi. `periodiseVersUneDate`
            // dit la même chose en une propriété, et c'est elle qu'il faudra lire le jour où un
            // quatrième arrive — cette chaîne de ternaires a déjà atteint sa limite.
            raceChrono: (goal?.periodiseVersUneDate ?? false) ? chrono : nil,
            raceDate: (goal?.periodiseVersUneDate ?? false) ? raceDate : nil,
            hyroxDivision: isHyrox ? hyroxDivision?.rawValue : nil,
            triathlonFormat: isTriathlon ? triathlonFormat?.rawValue : nil,
            nageNiveau: isTriathlon ? nageNiveau?.rawValue : nil,
            duathlonFormat: isDuathlon ? duathlonFormat?.rawValue : nil,
            tempsSemaineMin: tempsSemaineMin,
            tempsWeekEndMin: tempsWeekEndMin,
            volumeActuel: volumeActuel?.rawValue,
            plusLongueSortie: plusLongueSortie?.rawValue,
            allureFooting: allureFooting?.rawValue,
            runningDays: Array(runningDays),
            preferredLongRunDay: effectiveLongRunDay,
            level: level,
            connectedSources: Array(connected),
            weightNowKg: Double(weightNow),
            weightTargetKg: Double(weightTarget),
            heightCm: Double(height),
            focusArea: focusArea,
            bestRecentPerf: bestRecentPerf.isEmpty ? nil : bestRecentPerf,
            lastRanRecency: lastRanRecency,
            injuryArea: injuryArea,
            injuryWhen: injuryWhen?.rawValue,
            terrains: terrains.map(\.rawValue).sorted(),
            autresSports: autresSports.map(\.rawValue).sorted(),
            weeklyTimeBudget: weeklyTimeBudget,
            preferredTimeOfDay: preferredTimeOfDay,
            cycleTrackingEnabled: sex == "female" && cycleTrackingEnabled,
            lastPeriodStartDate: cycleTrackingEnabled ? lastPeriodStartDate : nil,
            averageCycleLengthDays: averageCycleLengthDays
        )
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
