import Foundation
import SwiftData

/// UN FICHIER, SUR SON TÉLÉPHONE, QUI CONTIENT TOUT CE QUI NE SE RETROUVE PAS.
///
/// # POURQUOI CE FICHIER EXISTE
///
/// Les données de l'app vivent dans un seul magasin SwiftData, et `PersistenceController` le dit
/// sans détour : quand ce magasin refuse de s'ouvrir, l'app démarre sur un conteneur en mémoire
/// jetable. Le fichier reste sur le disque, intact — mais personne ne sait le rouvrir, et aucune
/// version antérieure ne le répare puisque la donnée, elle, ne revient pas en arrière.
///
/// Apple Santé ne couvre pas ce trou. Santé contient les COURSES, et seulement elles : pas la
/// conversation avec le coach, pas les ressentis saisis après chaque séance, pas les chaussures
/// et leur kilométrage, pas la série, pas l'XP, pas le programme en cours, pas les réponses de
/// l'inscription. Tout ça n'existe qu'ici.
///
/// Le déclencheur immédiat est la migration de schéma qui vient (sortir les tracés GPS de la
/// ligne de la course). Une migration qui échoue est exactement le scénario ci-dessus, et le
/// faire sans filet reviendrait à parier son historique sur un essai.
///
/// # CE QUE LA RESTAURATION REFUSE DE FAIRE
///
/// Elle ne fusionne pas. Elle ne s'applique qu'à une base VIDE — pas encore inscrite, aucune
/// course — ce qui est précisément l'état d'après un magasin perdu ou une réinstallation. Une
/// fusion demanderait de décider, pour chaque course et chaque message, s'il s'agit du même
/// qu'un autre ; se tromper là-dessus produit un historique en double ou une perte silencieuse,
/// et aucune des deux ne se rattrape. Refuser est la seule réponse qu'on sait tenir.
///
/// # LA TOLÉRANCE DU DÉCODAGE
///
/// Le même raisonnement qu'en tête de `Session.swift`, pour une autre raison. `JSONDecoder` LÈVE
/// (il n'arrête pas le processus, contrairement au décodeur de SwiftData), donc rien ne plante
/// ici. Mais une erreur levée au milieu d'une structure fait échouer TOUT le décodage : une seule
/// course illisible, et le fichier entier ne sert plus à rien. Un filet qui lâche entièrement sur
/// un défaut local n'est pas un filet. D'où, partout dans ce fichier :
///
///   • chaque champ est optionnel et lu avec `decodeIfPresent` sous `try?`, donc indépendant de
///     ses voisins ;
///   • les énumérations sont rangées EN TEXTE BRUT (`goalId: String?` porte un `rawValue`), même
///     principe que `RunRecord.disciplineRaw` : une valeur inconnue d'une version plus ancienne
///     se relit comme une chaîne quelconque au lieu de lever ;
///   • les tableaux se décodent ÉLÉMENT PAR ÉLÉMENT (voir `Indulgent`), donc une course abîmée
///     coûte cette course et pas l'historique.
///
/// Une seule chose LÈVE ici, et c'est voulu : `container(keyedBy:)`, quand le nœud lu n'est pas
/// un objet. Sans ça, la tolérance se retournait contre elle-même — un `1` au milieu du tableau
/// des courses se décodait en une course entièrement vide, parfaitement valide, et
/// l'historique restauré se remplissait de sorties de zéro kilomètre au lieu de sauter ce qui
/// n'était pas une course. Lever à cet endroit-là est exactement ce qui permet à `Indulgent` de
/// faire la différence entre « abîmé » et « absent ».
///
/// Une sauvegarde doit se relire par une version de l'app plus récente — c'est son seul usage —
/// et souvent par une version plus ANCIENNE, celle qu'on réinstalle quand la nouvelle a cassé.
struct Sauvegarde: Codable, Equatable {
    /// La version du FORMAT, pas celle de l'app. Elle ne bouge que si la lecture d'un ancien
    /// fichier demande une règle particulière — ce que la tolérance ci-dessus est faite d'éviter.
    static let versionDuFormat = 1

    var version: Int = Sauvegarde.versionDuFormat
    var creeLe: Date = .now
    /// La version de l'app qui a écrit le fichier (`CFBundleShortVersionString`), pour pouvoir
    /// lire un rapport de bug sans deviner.
    var versionApp: String?
    var profil: Profil?
    var courses: [Course] = []
    var messages: [Message] = []
    var chaussures: [Chaussure] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.lire(Int.self, .version) ?? Sauvegarde.versionDuFormat
        creeLe = c.lire(Date.self, .creeLe) ?? .now
        versionApp = c.lire(String.self, .versionApp)
        profil = c.lire(Profil.self, .profil)
        courses = c.lireTableau(Course.self, .courses) ?? []
        messages = c.lireTableau(Message.self, .messages) ?? []
        chaussures = c.lireTableau(Chaussure.self, .chaussures) ?? []
    }

    /// Quelle structure d'ici porte quel modèle enregistré.
    /// Lue par `ci_scripts/check_sauvegarde.py` — voir ce script.
    static let correspondances: [String: String] = [
        "UserProfile": "Profil",
        "RunRecord": "Course",
        "ChatMessage": "Message",
        "Shoe": "Chaussure",
    ]

    /// Les modèles que la sauvegarde ignore ENTIÈREMENT, et pourquoi.
    static let modelesIgnores: [String: String] = [
        "AppNotification": """
        Le centre de notifications se reconstruit tout seul : chaque entrée est un message que \
        l'app a produit à partir d'autre chose (une séance faite, un badge, un kudos) et qu'elle \
        reproduira. Restaurer une liste d'alertes vieilles de six mois, toutes non lues, est \
        pire que repartir d'un centre vide.
        """,
    ]

    /// Les propriétés stockées DÉLIBÉRÉMENT absentes de la sauvegarde, et la raison de chacune.
    /// Lue par `ci_scripts/check_sauvegarde.py`, qui échoue sur toute propriété qui n'est ni
    /// sauvegardée ni inscrite ici : c'est ce qui empêche un champ ajouté demain de sortir du
    /// filet sans que personne ne l'ait décidé.
    static let nonSauvegardees: [String: String] = [
        "UserProfile.ownerAccountID": """
        Le compte propriétaire du profil. Il vient de la session en cours, et le restaurer \
        rattacherait les données au compte d'hier — exactement la fuite que \
        `AppState.startFreshForNewAccount` répare.
        """,
        "UserProfile.premium": """
        L'abonnement se lit chez StoreKit, jamais dans un fichier. Un droit d'accès qu'un fichier \
        suffit à s'accorder n'est pas un droit d'accès.
        """,
        "UserProfile.activeCaloriesToday": "Compteur du jour, relu d'Apple Santé à l'ouverture.",
        "UserProfile.stepsToday": "Compteur du jour, relu d'Apple Santé à l'ouverture.",
        "UserProfile.runValue": """
        Les kilomètres courus AUJOURD'HUI. Se recalcule depuis l'historique restauré ; le garder \
        afficherait un anneau déjà rempli le jour de la restauration.
        """,
        "UserProfile.dailyGoalsBonusAwarded": "Objectifs du jour — remis à zéro chaque matin.",
        "UserProfile.lastDailyResetDay": "Repère interne de la remise à zéro quotidienne.",
        "UserProfile.lastSameDayAdjustmentCheckDay": "Repère interne du moteur d'adaptation.",
        "UserProfile.lastHealthRunImport": """
        Jusqu'où l'import Santé est allé. À nil, il repasse sur sa fenêtre et ne crée aucun \
        doublon (`healthWorkoutID` le garantit) — c'est même ce qu'on veut après une restauration.
        """,
        "UserProfile.lastWeatherAdviceDate": "Cache météo — une prévision d'hier ne vaut rien.",
        "UserProfile.weatherAdviceDay": "Cache météo.",
        "UserProfile.weatherAdviceAvoidRaw": "Cache météo.",
        "UserProfile.weatherAdvicePreferRaw": "Cache météo.",
        "UserProfile.weatherAdviceAmended": "Cache météo.",
        "UserProfile.kudosSeenCounts": "État de lecture du club, porté par le serveur.",
        "UserProfile.commentsSeenCounts": "État de lecture du club, porté par le serveur.",
        "UserProfile.didBackfillSeenBadges": """
        Drapeau d'une reprise unique. À faux, la reprise se rejoue et marque les badges déjà \
        acquis comme vus — ce qui évite justement une volée de notifications après restauration.
        """,
        "UserProfile.lastReviewPromptDate": """
        Quand l'app a demandé une note sur l'App Store. Repère interne, et le restaurer ne peut \
        que redemander trop tôt.
        """,
    ]
}

// MARK: - Ce que le fichier contient

extension Sauvegarde {
    /// Le profil. Tous les champs sont optionnels : `nil` veut dire « ce fichier ne le portait
    /// pas », et la restauration laisse alors la valeur que l'initialiseur de `UserProfile` a
    /// posée. Les noms sont ceux de `UserProfile`, un pour un, pour que la correspondance soit
    /// mécanique et vérifiable.
    struct Profil: Codable, Equatable {
        // Identité
        var name: String?
        /// Demandé à l'inscription depuis qu'on a vu ce que coûtait son absence : sans nom et
        /// sans pseudo, un compte n'est trouvable dans « Mes amis » que par son adresse exacte.
        var lastName: String?
        var birthdate: Date?
        var sex: String?
        /// `GoalType.rawValue`. Voir « LA TOLÉRANCE DU DÉCODAGE » en tête de fichier.
        var goalId: String?
        /// `ExperienceLevel.rawValue`.
        var level: String?
        /// Les `ConnectedSource.rawValue`.
        var connectedSources: [String]?
        var goalDisplay: String?

        // Réglages dont la valeur est un choix explicite
        var weatherAlertsEnabled: Bool?
        var cycleTrackingEnabled: Bool?
        var shareCyclePhaseWithCoach: Bool?
        var lastPeriodStartDate: Date?
        var averageCycleLengthDays: Int?

        // Point de départ
        var volumeActuel: String?
        var plusLongueSortie: String?
        var allureFooting: String?
        var tempsSemaineMin: Int?
        var tempsWeekEndMin: Int?
        var injuryWhen: String?
        var terrains: [String]?
        var autresSports: [String]?

        // L'objectif et son approfondissement
        /// `RaceDistance.rawValue`.
        var raceDistance: String?
        var raceDistanceCustom: String?
        var raceElevationGainM: Int?
        var raceChrono: String?
        var raceDate: Date?
        var weightNowKg: Double?
        var weightTargetKg: Double?
        var heightCm: Double?
        var focusArea: String?
        var bestRecentPerf: String?
        var lastRanRecency: String?
        var injuryArea: String?
        var weeklyTimeBudget: String?
        var preferredTimeOfDay: String?
        var hyroxDivision: String?
        var triathlonFormat: String?
        var duathlonFormat: String?
        var nageNiveau: String?

        // Le programme en cours
        var weekNumber: Int?
        var programStartDate: Date?
        /// `ProgramPhase.rawValue`.
        var programPhase: String?
        var recoveryDaysLeft: Int?
        var recoveryStartedAt: Date?
        var freeRunSessionDoneDate: Date?
        var runningDays: [Int]?
        var preferredLongRunDay: Int?
        var todaySession: WorkoutSession?
        var weekStrip: [DayStatus]?
        var weekSessions: [PlannedDay]?
        var watchRunLayout: WatchRunLayout?
        var trainingEase: TrainingEase?
        var runningDaysBeforeEase: [Int]?
        var longRunDayBeforeEase: Int?
        var weekTier: Int?
        var weekRPESum: Int?
        var weekRPECount: Int?
        var freeRunTemplateIndex: Int?

        // Objectifs quotidiens — les CIBLES, pas les compteurs du jour
        var activeCaloriesGoal: Double?
        var stepsGoal: Double?
        var runGoal: Double?

        // Ce qui s'est accumulé et ne se reconstitue pas
        var streak: Int?
        var lastStreakDate: Date?
        var xp: Int?
        var recentRPESeverities: [Int]?
        var completedDebriefsCount: Int?
        var seenBadgeKeys: [String]?
        var defaultShoeID: UUID?
        /// Sa photo. Irremplaçable, et déjà compressée avant d'être stockée (voir
        /// `ProfileView.setAvatar`) — quelques centaines de ko en base64 dans le fichier.
        var avatarImageData: Data?

        // Préférences
        var onboarded: Bool?
        var distanceUnit: String?
        var coachNotificationsEnabled: Bool?
        var autoPauseEnabled: Bool?
        var paceAlertsEnabled: Bool?
        var accentThemeID: String?
        var isLightMode: Bool?
        /// `Habillage.rawValue` — la direction artistique choisie. Du texte brut, donc un
        /// habillage inconnu d'une version plus ancienne se relit sans faire échouer le profil.
        var habillageID: String?

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.lire(String.self, .name)
            lastName = c.lire(String.self, .lastName)
            birthdate = c.lire(Date.self, .birthdate)
            sex = c.lire(String.self, .sex)
            goalId = c.lire(String.self, .goalId)
            level = c.lire(String.self, .level)
            connectedSources = c.lire([String].self, .connectedSources)
            goalDisplay = c.lire(String.self, .goalDisplay)
            weatherAlertsEnabled = c.lire(Bool.self, .weatherAlertsEnabled)
            cycleTrackingEnabled = c.lire(Bool.self, .cycleTrackingEnabled)
            shareCyclePhaseWithCoach = c.lire(Bool.self, .shareCyclePhaseWithCoach)
            lastPeriodStartDate = c.lire(Date.self, .lastPeriodStartDate)
            averageCycleLengthDays = c.lire(Int.self, .averageCycleLengthDays)
            volumeActuel = c.lire(String.self, .volumeActuel)
            plusLongueSortie = c.lire(String.self, .plusLongueSortie)
            allureFooting = c.lire(String.self, .allureFooting)
            tempsSemaineMin = c.lire(Int.self, .tempsSemaineMin)
            tempsWeekEndMin = c.lire(Int.self, .tempsWeekEndMin)
            injuryWhen = c.lire(String.self, .injuryWhen)
            terrains = c.lire([String].self, .terrains)
            autresSports = c.lire([String].self, .autresSports)
            raceDistance = c.lire(String.self, .raceDistance)
            raceDistanceCustom = c.lire(String.self, .raceDistanceCustom)
            raceElevationGainM = c.lire(Int.self, .raceElevationGainM)
            raceChrono = c.lire(String.self, .raceChrono)
            raceDate = c.lire(Date.self, .raceDate)
            weightNowKg = c.lire(Double.self, .weightNowKg)
            weightTargetKg = c.lire(Double.self, .weightTargetKg)
            heightCm = c.lire(Double.self, .heightCm)
            focusArea = c.lire(String.self, .focusArea)
            bestRecentPerf = c.lire(String.self, .bestRecentPerf)
            lastRanRecency = c.lire(String.self, .lastRanRecency)
            injuryArea = c.lire(String.self, .injuryArea)
            weeklyTimeBudget = c.lire(String.self, .weeklyTimeBudget)
            preferredTimeOfDay = c.lire(String.self, .preferredTimeOfDay)
            hyroxDivision = c.lire(String.self, .hyroxDivision)
            triathlonFormat = c.lire(String.self, .triathlonFormat)
            duathlonFormat = c.lire(String.self, .duathlonFormat)
            nageNiveau = c.lire(String.self, .nageNiveau)
            weekNumber = c.lire(Int.self, .weekNumber)
            programStartDate = c.lire(Date.self, .programStartDate)
            programPhase = c.lire(String.self, .programPhase)
            recoveryDaysLeft = c.lire(Int.self, .recoveryDaysLeft)
            recoveryStartedAt = c.lire(Date.self, .recoveryStartedAt)
            freeRunSessionDoneDate = c.lire(Date.self, .freeRunSessionDoneDate)
            runningDays = c.lire([Int].self, .runningDays)
            preferredLongRunDay = c.lire(Int.self, .preferredLongRunDay)
            todaySession = c.lire(WorkoutSession.self, .todaySession)
            weekStrip = c.lireTableau(DayStatus.self, .weekStrip)
            weekSessions = c.lireTableau(PlannedDay.self, .weekSessions)
            watchRunLayout = c.lire(WatchRunLayout.self, .watchRunLayout)
            trainingEase = c.lire(TrainingEase.self, .trainingEase)
            runningDaysBeforeEase = c.lire([Int].self, .runningDaysBeforeEase)
            longRunDayBeforeEase = c.lire(Int.self, .longRunDayBeforeEase)
            weekTier = c.lire(Int.self, .weekTier)
            weekRPESum = c.lire(Int.self, .weekRPESum)
            weekRPECount = c.lire(Int.self, .weekRPECount)
            freeRunTemplateIndex = c.lire(Int.self, .freeRunTemplateIndex)
            activeCaloriesGoal = c.lire(Double.self, .activeCaloriesGoal)
            stepsGoal = c.lire(Double.self, .stepsGoal)
            runGoal = c.lire(Double.self, .runGoal)
            streak = c.lire(Int.self, .streak)
            lastStreakDate = c.lire(Date.self, .lastStreakDate)
            xp = c.lire(Int.self, .xp)
            recentRPESeverities = c.lire([Int].self, .recentRPESeverities)
            completedDebriefsCount = c.lire(Int.self, .completedDebriefsCount)
            seenBadgeKeys = c.lire([String].self, .seenBadgeKeys)
            defaultShoeID = c.lire(UUID.self, .defaultShoeID)
            avatarImageData = c.lire(Data.self, .avatarImageData)
            onboarded = c.lire(Bool.self, .onboarded)
            distanceUnit = c.lire(String.self, .distanceUnit)
            coachNotificationsEnabled = c.lire(Bool.self, .coachNotificationsEnabled)
            autoPauseEnabled = c.lire(Bool.self, .autoPauseEnabled)
            paceAlertsEnabled = c.lire(Bool.self, .paceAlertsEnabled)
            accentThemeID = c.lire(String.self, .accentThemeID)
            isLightMode = c.lire(Bool.self, .isLightMode)
            habillageID = c.lire(String.self, .habillageID)
        }
    }

    /// Une course. Les noms sont ceux de `RunRecord`.
    struct Course: Codable, Equatable {
        var date: Date?
        var title: String?
        var distanceKm: Double?
        var durationSeconds: Int?
        var avgPace: String?
        var avgHeartRate: Int?
        var kcal: Int?
        var elevationGainM: Int?
        var splits: [String]?
        /// `SessionKind.rawValue`.
        var sessionKind: String?
        var disciplineRaw: String?
        var route: [RunRecord.RoutePoint]?
        var stravaActivityId: Int?
        var healthWorkoutID: UUID?
        var shoeID: UUID?
        var debriefedAt: Date?

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            date = c.lire(Date.self, .date)
            title = c.lire(String.self, .title)
            distanceKm = c.lire(Double.self, .distanceKm)
            durationSeconds = c.lire(Int.self, .durationSeconds)
            avgPace = c.lire(String.self, .avgPace)
            avgHeartRate = c.lire(Int.self, .avgHeartRate)
            kcal = c.lire(Int.self, .kcal)
            elevationGainM = c.lire(Int.self, .elevationGainM)
            splits = c.lire([String].self, .splits)
            sessionKind = c.lire(String.self, .sessionKind)
            disciplineRaw = c.lire(String.self, .disciplineRaw)
            route = c.lireTableau(RunRecord.RoutePoint.self, .route)
            stravaActivityId = c.lire(Int.self, .stravaActivityId)
            healthWorkoutID = c.lire(UUID.self, .healthWorkoutID)
            shoeID = c.lire(UUID.self, .shoeID)
            debriefedAt = c.lire(Date.self, .debriefedAt)
        }
    }

    /// Un message de la conversation avec le coach. Les noms sont ceux de `ChatMessage`.
    struct Message: Codable, Equatable {
        /// `ChatRole.rawValue`.
        var role: String?
        var text: String?
        var timestamp: Date?

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            role = c.lire(String.self, .role)
            text = c.lire(String.self, .text)
            timestamp = c.lire(Date.self, .timestamp)
        }
    }

    /// Une paire de chaussures. Les noms sont ceux de `Shoe`.
    struct Chaussure: Codable, Equatable {
        /// Le même identifiant qu'en base, et pas un neuf : c'est lui que `RunRecord.shoeID` et
        /// `UserProfile.defaultShoeID` désignent. En tirer un nouveau à la restauration
        /// détacherait chaque course de sa paire, donc remettrait tous les kilométrages à zéro.
        var id: UUID?
        var name: String?
        var createdAt: Date?
        var startDistanceKm: Double?
        var retiredAt: Date?
        var alertThresholdKm: Double?

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = c.lire(UUID.self, .id)
            name = c.lire(String.self, .name)
            createdAt = c.lire(Date.self, .createdAt)
            startDistanceKm = c.lire(Double.self, .startDistanceKm)
            retiredAt = c.lire(Date.self, .retiredAt)
            alertThresholdKm = c.lire(Double.self, .alertThresholdKm)
        }
    }
}

// MARK: - La lecture tolérante

private extension KeyedDecodingContainer {
    /// Un champ, indépendant de ses voisins : absent, illisible ou d'un autre type, il rend `nil`
    /// sans faire échouer le reste de la structure. Voir « LA TOLÉRANCE DU DÉCODAGE » en tête de
    /// fichier.
    func lire<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }

    /// Un tableau lu ÉLÉMENT PAR ÉLÉMENT. `lire([Course].self, …)` perdrait les cinq cents
    /// courses du fichier à cause d'une seule ; ici une course abîmée coûte cette course.
    func lireTableau<T: Decodable>(_ type: T.Type, _ key: Key) -> [T]? {
        guard let indulgent = lire(Indulgent<T>.self, key), indulgent.estUnTableau else { return nil }
        return indulgent.valeurs
    }
}

/// Un tableau dont les éléments illisibles sont sautés.
private struct Indulgent<T: Decodable>: Decodable {
    /// Se décode depuis n'importe quoi, sans rien lire — sert uniquement à faire avancer le
    /// curseur d'un cran par-dessus un élément qu'on vient de renoncer à lire.
    private struct Passe: Decodable {
        init(from _: Decoder) throws {}
    }

    var valeurs: [T] = []
    /// Faux quand la valeur lue n'était pas un tableau du tout. Sans cette distinction, un
    /// `weekStrip` écrit de travers se relisait comme un tableau VIDE, et la restauration
    /// effaçait la bande de la semaine au lieu de la laisser telle qu'elle était.
    var estUnTableau = false

    init(from decoder: Decoder) throws {
        guard var c = try? decoder.unkeyedContainer() else { return }
        estUnTableau = true
        while !c.isAtEnd {
            let avant = c.currentIndex
            if let valeur = try? c.decode(T.self) {
                valeurs.append(valeur)
                if c.currentIndex != avant { continue }
            }
            // Un `decode` qui lève ne consomme pas l'élément — c'est `Passe` qui le fait. Les
            // deux tests qui suivent ne sont pas de la précaution ornementale : si NI l'un NI
            // l'autre ne fait bouger le curseur, la boucle tournerait sans fin sur le même
            // élément, et une sauvegarde abîmée figerait l'app au lieu de se lire à moitié.
            if c.currentIndex == avant { _ = try? c.decode(Passe.self) }
            if c.currentIndex == avant { return }
        }
    }
}
