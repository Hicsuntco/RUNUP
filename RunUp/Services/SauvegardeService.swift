import Foundation
import SwiftData

/// Écrire la sauvegarde, la relire, et la réappliquer. La forme du fichier est dans
/// `Sauvegarde.swift` ; ici, seulement les allers-retours avec le magasin et avec le disque.
enum SauvegardeService {
    // MARK: Le format sur le disque

    /// Les dates en ISO 8601 plutôt qu'en secondes depuis 2001 : le fichier se lit à l'œil, et
    /// un rapport de bug devient exploitable sans outil. `sortedKeys` pour que deux sauvegardes
    /// du même état donnent deux fichiers identiques — ce qui rend un diff possible.
    static func encodeur() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    static func decodeur() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Le nom du fichier proposé au partage. La date est dedans parce qu'un dossier de
    /// téléchargements finit par en contenir plusieurs, et que « lequel est le plus récent »
    /// est la seule question qu'on se pose alors.
    static func nomDeFichier(le jour: Date = .now, calendrier: Calendar = .current) -> String {
        nomSansExtension(le: jour, calendrier: calendrier) + ".json"
    }

    /// Le même nom sans son extension : c'est ce que `fileExporter` attend, puisqu'il ajoute
    /// lui-même celle du type déclaré. Lui passer « …json » donnerait « …json.json ».
    static func nomSansExtension(le jour: Date = .now, calendrier: Calendar = .current) -> String {
        let p = calendrier.dateComponents([.year, .month, .day], from: jour)
        let a = p.year ?? 0, m = p.month ?? 0, j = p.day ?? 0
        return String(format: "RUNUP-sauvegarde-%04d-%02d-%02d", a, m, j)
    }

    // MARK: Fabriquer la sauvegarde

    static func construire(
        profil: UserProfile,
        courses: [RunRecord],
        messages: [ChatMessage],
        chaussures: [Shoe],
        versionApp: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        le instant: Date = .now
    ) -> Sauvegarde {
        var s = Sauvegarde()
        s.creeLe = instant
        s.versionApp = versionApp
        s.profil = Sauvegarde.Profil(profil)
        // La fermeture plutôt que `map(Sauvegarde.Course.init)` : chaque structure porte aussi
        // un `init()` et un `init(from:)`, et nommer `.init` nu laisse trois candidats au
        // compilateur pour un gain de lisibilité nul.
        s.courses = courses.map { Sauvegarde.Course($0) }
        s.messages = messages.map { Sauvegarde.Message($0) }
        s.chaussures = chaussures.map { Sauvegarde.Chaussure($0) }
        return s
    }

    /// Écrit la sauvegarde dans un fichier temporaire et rend son URL, à passer tel quel à
    /// `ShareLink(item:)`. Nil si l'encodage ou l'écriture échoue — l'appelant doit le dire
    /// plutôt que de proposer un bouton qui ne fait rien.
    static func ecrire(_ sauvegarde: Sauvegarde, dans dossier: URL? = nil) -> URL? {
        guard let data = try? encodeur().encode(sauvegarde) else { return nil }
        let base = dossier ?? FileManager.default.temporaryDirectory
        let url = base.appendingPathComponent(nomDeFichier(le: sauvegarde.creeLe))
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func lire(_ url: URL) -> Sauvegarde? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decodeur().decode(Sauvegarde.self, from: data)
    }

    // MARK: Restaurer

    /// Pourquoi une restauration n'a pas eu lieu. Chaque cas correspond à un message distinct :
    /// « le fichier ne se lit pas » et « tes données sont déjà là » demandent deux gestes
    /// différents, et les confondre en une erreur générique laisse la personne sans issue.
    enum Echec: Error, Equatable {
        /// Le fichier est absent, illisible, ou n'est pas une sauvegarde RUNUP.
        case fichierIllisible
        /// La base contient déjà quelque chose. Voir `peutRestaurer`.
        case baseNonVide
        /// Tout a été relu, et rien n'a pu être ÉCRIT — un disque plein, typiquement, ce qui est
        /// le cas courant quand on réinstalle puis réinjecte des centaines de courses avec leurs
        /// tracés. Distinct des deux autres parce que le geste à faire est distinct : faire de
        /// la place, et recommencer. Le fichier, lui, est intact.
        case enregistrementImpossible
    }

    /// LA RESTAURATION NE S'APPLIQUE QU'À UNE BASE VIDE, et c'est un refus assumé.
    ///
    /// Vide veut dire : l'inscription n'a pas été faite ET il n'y a aucune course. C'est l'état
    /// d'après une réinstallation, et celui d'après un magasin perdu (voir
    /// `PersistenceController.StoreState.inMemoryFallback`) — donc exactement les deux moments où
    /// l'on vient chercher un fichier de sauvegarde.
    ///
    /// Fusionner demanderait de décider, course par course et message par message, s'il s'agit
    /// du même qu'un autre. Rien ne le dit de façon fiable : deux footings de 45 minutes le même
    /// matin sont indiscernables, et les clés qui existent (`healthWorkoutID`,
    /// `stravaActivityId`) ne couvrent que les courses importées. Se tromper produit un
    /// historique en double ou une perte silencieuse — et une perte silencieuse dans l'outil
    /// censé réparer les pertes est la pire issue possible.
    static func peutRestaurer(onboarded: Bool, nombreDeCourses: Int) -> Bool {
        !onboarded && nombreDeCourses == 0
    }

    /// Réapplique une sauvegarde. Le profil est MUTÉ sur place plutôt que remplacé : il n'existe
    /// qu'un seul `UserProfile` par installation, `AppState` le tient, et le remplacer laisserait
    /// toutes les vues sur l'ancien objet.
    ///
    /// Rend le nombre d'objets réellement réinsérés, pour pouvoir le dire à l'écran : « 212
    /// courses restaurées » est la seule preuve que la personne a que ça a marché.
    @discardableResult
    static func restaurer(
        _ sauvegarde: Sauvegarde,
        dans contexte: ModelContext,
        profil: UserProfile,
        nombreDeCourses: Int
    ) throws -> (courses: Int, messages: Int, chaussures: Int) {
        guard peutRestaurer(onboarded: profil.onboarded, nombreDeCourses: nombreDeCourses) else {
            throw Echec.baseNonVide
        }
        if let p = sauvegarde.profil { appliquer(p, sur: profil) }
        for c in sauvegarde.courses { contexte.insert(c.enRunRecord()) }
        for m in sauvegarde.messages { contexte.insert(m.enChatMessage()) }
        for ch in sauvegarde.chaussures { contexte.insert(ch.enShoe()) }
        // `try` ET NON `try?`. Les comptes rendus ensuite viennent du FICHIER, pas du magasin :
        // avaler l'erreur ici ferait annoncer « 212 courses restaurées » alors que rien n'a été
        // écrit, et l'app se refermerait sur un historique vide. La seule preuve que la personne
        // a que ça a marché serait fausse, dans l'outil qui existe pour ce moment-là.
        do {
            try contexte.save()
        } catch {
            throw Echec.enregistrementImpossible
        }
        return (sauvegarde.courses.count, sauvegarde.messages.count, sauvegarde.chaussures.count)
    }

    /// Chaque champ absent du fichier LAISSE la valeur que l'initialiseur de `UserProfile` a
    /// posée, au lieu d'écrire `nil` par-dessus. C'est ce qui permet de restaurer une sauvegarde
    /// écrite par une version plus ancienne de l'app sans vider les champs qu'elle ne connaissait
    /// pas encore.
    static func appliquer(_ p: Sauvegarde.Profil, sur profil: UserProfile) {
        if let v = p.name { profil.name = v }
        if let v = p.lastName { profil.lastName = v }
        if let v = p.birthdate { profil.birthdate = v }
        if let v = p.sex { profil.sex = v }
        if let v = p.goalId, let g = GoalType(rawValue: v) { profil.goalId = g }
        if let v = p.level, let n = ExperienceLevel(rawValue: v) { profil.level = n }
        if let v = p.connectedSources { profil.connectedSources = v.compactMap(ConnectedSource.init(rawValue:)) }
        if let v = p.goalDisplay { profil.goalDisplay = v }
        if let v = p.weatherAlertsEnabled { profil.weatherAlertsEnabled = v }
        if let v = p.cycleTrackingEnabled { profil.cycleTrackingEnabled = v }
        if let v = p.shareCyclePhaseWithCoach { profil.shareCyclePhaseWithCoach = v }
        if let v = p.lastPeriodStartDate { profil.lastPeriodStartDate = v }
        if let v = p.averageCycleLengthDays { profil.averageCycleLengthDays = v }
        if let v = p.volumeActuel { profil.volumeActuel = v }
        if let v = p.plusLongueSortie { profil.plusLongueSortie = v }
        if let v = p.allureFooting { profil.allureFooting = v }
        if let v = p.tempsSemaineMin { profil.tempsSemaineMin = v }
        if let v = p.tempsWeekEndMin { profil.tempsWeekEndMin = v }
        if let v = p.injuryWhen { profil.injuryWhen = v }
        if let v = p.terrains { profil.terrains = v }
        if let v = p.autresSports { profil.autresSports = v }
        // `let d = …` et non `RaceDistance(rawValue: v)` posé directement : une distance
        // inconnue (un format ajouté par une version plus récente) mettrait nil, donc
        // effacerait la distance au lieu de laisser celle en place. Même règle que pour
        // `goalId`, `level` et `programPhase` juste à côté.
        if let v = p.raceDistance, let d = RaceDistance(rawValue: v) { profil.raceDistance = d }
        if let v = p.raceDistanceCustom { profil.raceDistanceCustom = v }
        if let v = p.raceElevationGainM { profil.raceElevationGainM = v }
        if let v = p.raceChrono { profil.raceChrono = v }
        if let v = p.raceDate { profil.raceDate = v }
        if let v = p.weightNowKg { profil.weightNowKg = v }
        if let v = p.weightTargetKg { profil.weightTargetKg = v }
        if let v = p.heightCm { profil.heightCm = v }
        if let v = p.focusArea { profil.focusArea = v }
        if let v = p.bestRecentPerf { profil.bestRecentPerf = v }
        if let v = p.lastRanRecency { profil.lastRanRecency = v }
        if let v = p.injuryArea { profil.injuryArea = v }
        if let v = p.weeklyTimeBudget { profil.weeklyTimeBudget = v }
        if let v = p.preferredTimeOfDay { profil.preferredTimeOfDay = v }
        if let v = p.hyroxDivision { profil.hyroxDivision = v }
        if let v = p.triathlonFormat { profil.triathlonFormat = v }
        if let v = p.duathlonFormat { profil.duathlonFormat = v }
        if let v = p.nageNiveau { profil.nageNiveau = v }
        if let v = p.weekNumber { profil.weekNumber = v }
        if let v = p.programStartDate { profil.programStartDate = v }
        if let v = p.programPhase, let f = ProgramPhase(rawValue: v) { profil.programPhase = f }
        if let v = p.recoveryDaysLeft { profil.recoveryDaysLeft = v }
        if let v = p.recoveryStartedAt { profil.recoveryStartedAt = v }
        if let v = p.freeRunSessionDoneDate { profil.freeRunSessionDoneDate = v }
        if let v = p.runningDays { profil.runningDays = v }
        if let v = p.preferredLongRunDay { profil.preferredLongRunDay = v }
        if let v = p.todaySession { profil.todaySession = v }
        if let v = p.weekStrip { profil.weekStrip = v }
        if let v = p.weekSessions { profil.weekSessions = v }
        if let v = p.watchRunLayout { profil.watchRunLayout = v }
        if let v = p.trainingEase { profil.trainingEase = v }
        if let v = p.runningDaysBeforeEase { profil.runningDaysBeforeEase = v }
        if let v = p.longRunDayBeforeEase { profil.longRunDayBeforeEase = v }
        if let v = p.weekTier { profil.weekTier = v }
        if let v = p.weekRPESum { profil.weekRPESum = v }
        if let v = p.weekRPECount { profil.weekRPECount = v }
        if let v = p.freeRunTemplateIndex { profil.freeRunTemplateIndex = v }
        if let v = p.activeCaloriesGoal { profil.activeCaloriesGoal = v }
        if let v = p.stepsGoal { profil.stepsGoal = v }
        if let v = p.runGoal { profil.runGoal = v }
        if let v = p.streak { profil.streak = v }
        if let v = p.lastStreakDate { profil.lastStreakDate = v }
        if let v = p.xp { profil.xp = v }
        if let v = p.recentRPESeverities { profil.recentRPESeverities = v }
        if let v = p.completedDebriefsCount { profil.completedDebriefsCount = v }
        if let v = p.seenBadgeKeys { profil.seenBadgeKeys = v }
        if let v = p.defaultShoeID { profil.defaultShoeID = v }
        if let v = p.avatarImageData { profil.avatarImageData = v }
        if let v = p.onboarded { profil.onboarded = v }
        if let v = p.distanceUnit { profil.distanceUnit = v }
        if let v = p.coachNotificationsEnabled { profil.coachNotificationsEnabled = v }
        if let v = p.autoPauseEnabled { profil.autoPauseEnabled = v }
        if let v = p.paceAlertsEnabled { profil.paceAlertsEnabled = v }
        if let v = p.accentThemeID { profil.accentThemeID = v }
        if let v = p.isLightMode { profil.isLightMode = v }
        if let v = p.habillageID { profil.habillageID = v }
    }
}

// MARK: - Du magasin vers le fichier

extension Sauvegarde.Profil {
    init(_ m: UserProfile) {
        self.init()
        name = m.name
        lastName = m.lastName
        birthdate = m.birthdate
        sex = m.sex
        goalId = m.goalId.rawValue
        level = m.level.rawValue
        connectedSources = m.connectedSources.map(\.rawValue)
        goalDisplay = m.goalDisplay
        weatherAlertsEnabled = m.weatherAlertsEnabled
        cycleTrackingEnabled = m.cycleTrackingEnabled
        shareCyclePhaseWithCoach = m.shareCyclePhaseWithCoach
        lastPeriodStartDate = m.lastPeriodStartDate
        averageCycleLengthDays = m.averageCycleLengthDays
        volumeActuel = m.volumeActuel
        plusLongueSortie = m.plusLongueSortie
        allureFooting = m.allureFooting
        tempsSemaineMin = m.tempsSemaineMin
        tempsWeekEndMin = m.tempsWeekEndMin
        injuryWhen = m.injuryWhen
        terrains = m.terrains
        autresSports = m.autresSports
        raceDistance = m.raceDistance?.rawValue
        raceDistanceCustom = m.raceDistanceCustom
        raceElevationGainM = m.raceElevationGainM
        raceChrono = m.raceChrono
        raceDate = m.raceDate
        weightNowKg = m.weightNowKg
        weightTargetKg = m.weightTargetKg
        heightCm = m.heightCm
        focusArea = m.focusArea
        bestRecentPerf = m.bestRecentPerf
        lastRanRecency = m.lastRanRecency
        injuryArea = m.injuryArea
        weeklyTimeBudget = m.weeklyTimeBudget
        preferredTimeOfDay = m.preferredTimeOfDay
        hyroxDivision = m.hyroxDivision
        triathlonFormat = m.triathlonFormat
        duathlonFormat = m.duathlonFormat
        nageNiveau = m.nageNiveau
        weekNumber = m.weekNumber
        programStartDate = m.programStartDate
        programPhase = m.programPhase.rawValue
        recoveryDaysLeft = m.recoveryDaysLeft
        recoveryStartedAt = m.recoveryStartedAt
        freeRunSessionDoneDate = m.freeRunSessionDoneDate
        runningDays = m.runningDays
        preferredLongRunDay = m.preferredLongRunDay
        todaySession = m.todaySession
        weekStrip = m.weekStrip
        weekSessions = m.weekSessions
        watchRunLayout = m.watchRunLayout
        trainingEase = m.trainingEase
        runningDaysBeforeEase = m.runningDaysBeforeEase
        longRunDayBeforeEase = m.longRunDayBeforeEase
        weekTier = m.weekTier
        weekRPESum = m.weekRPESum
        weekRPECount = m.weekRPECount
        freeRunTemplateIndex = m.freeRunTemplateIndex
        activeCaloriesGoal = m.activeCaloriesGoal
        stepsGoal = m.stepsGoal
        runGoal = m.runGoal
        streak = m.streak
        lastStreakDate = m.lastStreakDate
        xp = m.xp
        recentRPESeverities = m.recentRPESeverities
        completedDebriefsCount = m.completedDebriefsCount
        seenBadgeKeys = m.seenBadgeKeys
        defaultShoeID = m.defaultShoeID
        avatarImageData = m.avatarImageData
        onboarded = m.onboarded
        distanceUnit = m.distanceUnit
        coachNotificationsEnabled = m.coachNotificationsEnabled
        autoPauseEnabled = m.autoPauseEnabled
        paceAlertsEnabled = m.paceAlertsEnabled
        accentThemeID = m.accentThemeID
        isLightMode = m.isLightMode
        habillageID = m.habillageID
    }
}

extension Sauvegarde.Course {
    init(_ m: RunRecord) {
        self.init()
        date = m.date
        title = m.title
        distanceKm = m.distanceKm
        durationSeconds = m.durationSeconds
        avgPace = m.avgPace
        avgHeartRate = m.avgHeartRate
        kcal = m.kcal
        elevationGainM = m.elevationGainM
        splits = m.splits
        sessionKind = m.sessionKind?.rawValue
        disciplineRaw = m.disciplineRaw
        route = m.route
        stravaActivityId = m.stravaActivityId
        healthWorkoutID = m.healthWorkoutID
        shoeID = m.shoeID
        debriefedAt = m.debriefedAt
    }

    func enRunRecord() -> RunRecord {
        let r = RunRecord(
            date: date ?? .now,
            title: title ?? "",
            distanceKm: distanceKm ?? 0,
            durationSeconds: durationSeconds ?? 0,
            avgPace: avgPace ?? "—",
            avgHeartRate: avgHeartRate ?? 0,
            kcal: kcal ?? 0,
            elevationGainM: elevationGainM ?? 0,
            splits: splits ?? [],
            route: route ?? [],
            stravaActivityId: stravaActivityId,
            healthWorkoutID: healthWorkoutID,
            sessionKind: sessionKind.flatMap(SessionKind.init(rawValue:))
        )
        // Posé après coup, et SANS condition. L'initialiseur n'accepte qu'une `Discipline`, donc
        // il écrit toujours « run » — ce qui mentirait deux fois : une valeur inconnue venue d'un
        // fichier plus récent serait écrasée, et une course antérieure au champ (brut à nil, donc
        // `Discipline.legacy`) se verrait prêter une valeur qu'elle n'a jamais portée.
        // `RunRecord.discipline` sait déjà quoi faire d'un nil comme d'un texte inconnu.
        r.disciplineRaw = disciplineRaw
        r.shoeID = shoeID
        r.debriefedAt = debriefedAt
        return r
    }
}

extension Sauvegarde.Message {
    init(_ m: ChatMessage) {
        self.init()
        role = m.role.rawValue
        text = m.text
        timestamp = m.timestamp
    }

    func enChatMessage() -> ChatMessage {
        ChatMessage(
            // `.system` pour un rôle illisible — le seul cas qui ne ment pas. Le texte reste
            // affiché, mais il n'est attribué ni à elle ni au coach, et il ne repart pas dans
            // l'historique envoyé au modèle (voir `ChatRole.system`).
            role: role.flatMap(ChatRole.init(rawValue:)) ?? .system,
            text: text ?? "",
            timestamp: timestamp ?? .now
        )
    }
}

extension Sauvegarde.Chaussure {
    init(_ m: Shoe) {
        self.init()
        id = m.id
        name = m.name
        createdAt = m.createdAt
        startDistanceKm = m.startDistanceKm
        retiredAt = m.retiredAt
        alertThresholdKm = m.alertThresholdKm
    }

    func enShoe() -> Shoe {
        Shoe(
            id: id ?? UUID(),
            name: name ?? "",
            createdAt: createdAt ?? .now,
            startDistanceKm: startDistanceKm ?? 0,
            retiredAt: retiredAt,
            alertThresholdKm: alertThresholdKm ?? 700
        )
    }
}
