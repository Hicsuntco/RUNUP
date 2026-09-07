import Foundation
import Observation
import HealthKit
import CoreLocation

/// Apple Santé integration — the only natively-supported data source in v1 (see README:
/// "Utilise HealthKit pour la connexion Apple Santé en priorité ... Strava/Garmin peuvent
/// rester des stubs"). Reads feed the readiness score and rings; writes record completed runs.
@Observable
final class HealthKitService {
    private let store = HKHealthStore()

    private(set) var isAuthorized = false

    static var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            // Les courses enregistrées ailleurs — une Garmin, une Coros, l'app Exercice d'une
            // Apple Watch — et la distance qu'elles portent. Voir `runWorkouts`.
            //
            // Comme pour les types d'écriture plus bas : une utilisatrice déjà connectée sera
            // redemandée une fois, pour ces deux-là.
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            // Le PARCOURS d'une séance, qui est un objet à part dans Santé — pas un champ de
            // l'entraînement. Sans lui, une course importée d'une Garmin arrivait sans tracé, et
            // sa carte de fil s'affichait dans sa version « sans image » : exactement ce qu'on
            // venait de construire le fil pour éviter.
            HKSeriesType.workoutRoute()
        ]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    /// La séance, plus les deux mesures qu'elle porte.
    ///
    /// L'ancien initialiseur `HKWorkout(totalEnergyBurned:totalDistance:)` rangeait ces deux
    /// nombres comme des PROPRIÉTÉS de la séance, sans autorisation supplémentaire.
    /// `HKWorkoutBuilder` — son remplaçant depuis iOS 17 — les écrit comme de vrais échantillons,
    /// qui demandent chacun leur propre droit d'écriture. Sans eux, la séance apparaîtrait dans
    /// Santé sans distance ni calories.
    ///
    /// Conséquence à connaître : une utilisatrice déjà connectée sera redemandée une fois, pour
    /// ces deux types-là.
    private static let writeTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
    ]

    func requestAuthorization() async throws {
        guard Self.isHealthDataAvailable else { return }
        try await store.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
        isAuthorized = true
    }

    /// Long-lived observer queries — kept so `startObservingDailyGoals` is idempotent (called on
    /// every foreground sync; only the first call actually registers anything).
    @ObservationIgnored private var observerQueries: [HKObserverQuery] = []

    /// Watches steps + active calories and fires `onChange` whenever Santé records new samples —
    /// including in the BACKGROUND (hourly batches, via `enableBackgroundDelivery` + the
    /// healthkit.background-delivery entitlement). This is what keeps the Home Screen widget's
    /// "PAS -2 400" honest while she walks all day without opening the app: each delivery wakes
    /// the app briefly, the sync re-reads today's totals and republishes the widget snapshot.
    ///
    /// `@Sendable` sur `onChange` : HealthKit appelle cette fermeture depuis sa propre file, pas
    /// depuis le fil principal. Sans l'annotation, l'appelant (`AppState`, isolé `@MainActor`)
    /// fournissait une fermeture isolée sur l'acteur principal que HealthKit invoquait quand même
    /// en arrière-plan — exactement le genre de saut d'isolation silencieux que Swift 6 refuse.
    func startObservingDailyGoals(onChange: @escaping @Sendable () -> Void) {
        guard Self.isHealthDataAvailable, observerQueries.isEmpty else { return }
        let identifiers: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned]
        for identifier in identifiers {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
                if error == nil { onChange() }
                // Always called, even on error — HealthKit throttles observers that don't
                // acknowledge deliveries.
                completionHandler()
            }
            store.execute(query)
            observerQueries.append(query)
            // Hourly is the floor iOS actually honors for these high-frequency types — matches
            // the widget's own reload budget anyway.
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    /// Steps recorded today — used as-is (not literally isolated from step-during-a-run time) for
    /// the "Pas" daily goal; a reasonable proxy since a single run is a small fraction of most
    /// days' total steps, and RunRecord doesn't store precise start/end timestamps to subtract by.
    func stepsToday() async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return await sum(type: type, unit: .count(), on: .now)
    }

    /// Active calories burned today — feeds the "Calories actives" daily goal. Deliberately not
    /// "minutes actives"/Exercise Time (`appleExerciseTime`): that quantity type is effectively
    /// Apple-Watch-only in practice (third-party sources rarely write to it), while active energy
    /// is a standard quantity type most fitness ecosystems do write to — including RunUp's own
    /// `saveRun` below, so even a runner with no watch at all gets a real, non-zero number on any
    /// day she logs a run, and a Garmin (or any other) watch's own Health-sync app contributes the
    /// rest for the days it's worn.
    func activeCaloriesToday() async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await sum(type: type, unit: .kilocalorie(), on: .now)
    }

    /// Same two reads as above, but for any past calendar day — Santé keeps this data
    /// indefinitely, RunUp just never asked for a day other than today until now. Powers the
    /// "Ta journée" day browser (`RingsView`) so a past day's ring isn't limited to what's in
    /// History (which only ever had actual runs, never the steps/calories side).
    func steps(on date: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return await sum(type: type, unit: .count(), on: date)
    }

    func activeCalories(on date: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await sum(type: type, unit: .kilocalorie(), on: date)
    }

    /// Most recent heart-rate sample within the last `maxAge` seconds — used to poll a genuinely
    /// live-ish reading during a run (see `LiveRunViewModel`). Filtered to `maxAge` rather than
    /// "the last sample ever" so a stale reading from hours/days ago (no Watch worn right now)
    /// correctly returns `nil` instead of being displayed as if it were current.
    func latestHeartRate(maxAge: TimeInterval = 90) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-maxAge), end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let bpm = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    /// Total time actually asleep last night, in hours — the window runs from 6pm yesterday to
    /// noon today, wide enough to catch any real bedtime (including a late one) without pulling
    /// in the PREVIOUS night too. Feeds `AdaptivePlanEngine.applySameDayAdjustmentIfNeeded`: sleep
    /// permission was already requested (see `readTypes`) for this from the start, but nothing
    /// ever actually read it until now. Nil — not 0 — when Santé has no sleep data for that window
    /// (no Watch/sleep tracking used, or she never actually slept with her phone/Watch nearby that
    /// night), since 0 would read as "she didn't sleep at all" rather than "no data".
    func lastNightSleepHours() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        guard let end = cal.date(bySettingHour: 12, minute: 0, second: 0, of: .now),
              let todaySixPM = cal.date(bySettingHour: 18, minute: 0, second: 0, of: .now),
              let start = cal.date(byAdding: .day, value: -1, to: todaySixPM)
        else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            store.execute(query)
        }
    }

    /// Enregistre une sortie terminée dans Santé.
    ///
    /// `duration` est le temps de mouvement réel, pauses exclues — transmis à part de start/end,
    /// parce que `end - start` inclut chaque pause et que Santé afficherait sinon une sortie de
    /// 30 min avec un café de 15 min comme une séance de 45 min.
    ///
    /// ─── POURQUOI DES ÉVÉNEMENTS DE PAUSE ────────────────────────────────────────────────────
    ///
    /// L'ancien `HKWorkout(start:end:duration:)` acceptait les trois valeurs indépendamment.
    /// `HKWorkoutBuilder` ne le permet pas : il CALCULE la durée à partir de la fenêtre de collecte
    /// moins le temps passé en pause. Deux façons de retrouver la bonne durée, et une seule est
    /// honnête.
    ///
    /// Fermer la collecte à `start + duration` donnerait la bonne durée, mais dirait que la sortie
    /// s'est terminée quinze minutes avant la réalité. Poser une paire pause/reprise couvrant
    /// l'écart garde les VRAIS début, fin et durée — les trois valeurs qu'on lit dans Santé — au
    /// prix d'une seule approximation, la position de la pause dans la sortie, que rien n'affiche.
    ///
    /// La position exacte demanderait de conserver les horodatages de pause jusqu'ici, ce que
    /// `RunRecord` ne fait pas. C'est le vrai correctif, et il est ailleurs.
    func saveRun(start: Date, end: Date, duration: TimeInterval, distanceKm: Double, kcal: Double) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)

        // Chaque mesure n'est jointe que si elle existe vraiment : une séance sans GPS n'a pas de
        // distance, et un échantillon à zéro n'est pas la même chose qu'une absence de mesure.
        var samples: [HKSample] = []
        if kcal > 0, let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            samples.append(HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: start,
                end: end
            ))
        }
        if distanceKm > 0, let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            samples.append(HKQuantitySample(
                type: distanceType,
                quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm),
                start: start,
                end: end
            ))
        }
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        let movingEnd = min(start.addingTimeInterval(duration), end)
        if movingEnd < end {
            try await builder.addWorkoutEvents([
                HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: movingEnd, duration: 0), metadata: nil),
                HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: end, duration: 0), metadata: nil)
            ])
        }

        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }

    // MARK: - Les courses enregistrées ailleurs

    /// Une course lue dans Santé, réduite à ce dont `RunRecord` a besoin.
    ///
    /// Un type à nous plutôt que `HKWorkout` : ce dernier n'est pas `Sendable`, et le faire
    /// traverser jusqu'à l'acteur principal obligerait à le décortiquer là-bas de toute façon.
    struct ImportedRun: Sendable {
        var id: UUID
        var start: Date
        var durationSeconds: Double
        var distanceKm: Double
        var kcal: Double
        var avgHeartRate: Int
        /// Le parcours, quand la source en a écrit un. Vide sinon — un tapis de course, une montre
        /// sans GPS, ou une séance saisie à la main en produisent une sans.
        ///
        /// Défaut à vide, et pas seulement par commodité : « pas de parcours » est un cas normal,
        /// pas une valeur manquante qu'un appelant devrait avoir à nommer. Les tests de la règle
        /// d'import construisent des sorties dont le tracé n'a aucune importance, et les obliger à
        /// écrire `route: []` ne dirait rien de plus que ce défaut.
        var route: [RunRecord.RoutePoint] = []
        /// Le dénivelé positif, LU dans les métadonnées de la séance et non recalculé.
        ///
        /// `HKMetadataKeyElevationAscended` est la clé standard qu'écrivent l'Apple Watch et la
        /// plupart des montres tierces. La refabriquer depuis les altitudes du parcours donnerait
        /// une seconde implémentation d'une règle qui vit déjà dans `LocationService` — et deux
        /// implémentations d'une même règle finissent toujours par diverger. `nil` quand la source
        /// n'a rien écrit : une absence de mesure, pas un zéro.
        var elevationGainM: Int?
    }

    /// Les courses écrites dans Santé par QUELQU'UN D'AUTRE que RUNUP, depuis une date donnée.
    ///
    /// # Pourquoi cette lecture existe
    ///
    /// L'app savait écrire une course dans Santé et n'a jamais su en lire une. Pour qui court
    /// avec une Garmin, une Coros, une Polar — ou simplement avec l'app Exercice d'une Apple
    /// Watch — cela voulait dire un programme qui n'avance jamais : la sortie a bien eu lieu, elle
    /// est dans Santé, et RUNUP la regardait sans la voir — elle ne demandait même pas le droit
    /// de la lire (`readTypes` ne portait que cardio, pas, calories, sommeil).
    ///
    /// # Ce qui est exclu, et pourquoi deux fois
    ///
    /// `HKSource.default()` écarte ce que RUNUP a elle-même écrit — sans quoi chaque course faite
    /// avec le bouton RUN reviendrait par la porte de Santé une seconde fois. Ce filtre suffit en
    /// théorie ; l'appelant dédoublonne quand même sur l'horaire, parce qu'une même sortie peut
    /// être écrite par deux sources (la montre ET l'application du fabricant) et que ces deux-là
    /// ne sont ni l'une ni l'autre RUNUP.
    ///
    /// # Seulement la course à pied
    ///
    /// `.running` uniquement : ni marche, ni vélo, ni rando. Le programme est un programme de
    /// course, et compter une sortie à vélo comme une séance donnerait un plan faux plutôt qu'un
    /// plan vide.
    func runWorkouts(since: Date) async -> [ImportedRun] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForSamples(withStart: since, end: .now, options: .strictStartDate),
            NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))
        ])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        var runs: [ImportedRun] = []
        for workout in workouts {
            // Les statistiques portées par l'entraînement lui-même quand la source les a écrites
            // (c'est le cas des montres), une requête sur l'intervalle sinon. La seconde coûte un
            // aller-retour par course, ce qui est acceptable : il n'y en a qu'une poignée par
            // import, et zéro les jours où rien de neuf n'est arrivé.
            guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
                  let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
                  let heartType = HKObjectType.quantityType(forIdentifier: .heartRate) else { continue }

            // Écrit en `if` et non en `??` : le membre droit de `??` est une autoclosure, qui
            // n'accepte pas d'appel asynchrone. Le compilateur le refuse — « 'await' cannot appear
            // to the right of a non-assignment operator ».
            var meters = workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter())
            if meters == nil { meters = await sum(type: distanceType, unit: .meter(), in: workout) }

            var kcal = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            if kcal == nil { kcal = await sum(type: energyType, unit: .kilocalorie(), in: workout) }

            var bpm = workout.statistics(for: heartType)?.averageQuantity()?.doubleValue(for: Self.bpm)
            if bpm == nil { bpm = await average(type: heartType, unit: Self.bpm, in: workout) }

            runs.append(ImportedRun(
                id: workout.uuid,
                start: workout.startDate,
                durationSeconds: workout.duration,
                distanceKm: (meters ?? 0) / 1000,
                kcal: kcal ?? 0,
                avgHeartRate: Int((bpm ?? 0).rounded()),
                route: await route(for: workout),
                elevationGainM: ascent(of: workout)
            ))
        }
        return runs
    }

    /// Le dénivelé positif écrit par la source, s'il y en a un.
    ///
    /// Négatif ou nul, on rend `nil` : une montre qui écrit zéro sur un parcours plat dit la même
    /// chose qu'une montre qui n'écrit rien, et le fil sait afficher une absence — il ne sait pas
    /// afficher « 0 m » sans que ça ressemble à une mesure.
    private func ascent(of workout: HKWorkout) -> Int? {
        guard let quantity = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity else { return nil }
        let meters = quantity.doubleValue(for: .meter())
        guard meters > 0 else { return nil }
        return Int(meters.rounded())
    }

    // MARK: Le parcours d'une séance importée

    /// Le tracé GPS d'un entraînement écrit par une autre source — une Garmin, une Coros, l'app
    /// Exercice d'une Apple Watch.
    ///
    /// # Deux requêtes, parce que Santé range ça en deux temps
    ///
    /// Le parcours n'est pas un champ de l'entraînement : c'est une SÉRIE, un objet séparé qui lui
    /// est rattaché. On demande d'abord les séries de cette séance, puis on lit les positions de
    /// chacune. Une séance en a normalement une, parfois zéro (tapis de course, montre sans GPS),
    /// et rien n'interdit d'en avoir plusieurs — d'où la concaténation plutôt qu'un premier
    /// élément pris au hasard.
    ///
    /// # Ce qui est écarté
    ///
    /// Les positions dont la précision horizontale est négative : dans CoreLocation, c'est la
    /// valeur qui signifie « cette coordonnée n'est pas valide », pas « elle est imprécise ». Les
    /// seuils d'altitude sont ceux de `LocationService`, pour que le dénivelé d'une course
    /// importée se calcule exactement comme celui d'une course enregistrée ici.
    ///
    /// Le résultat est décimé : une sortie longue enregistrée à la seconde produit des milliers de
    /// points, et ils vivraient dans la base du téléphone pour toujours. Mille cinq cents suffisent
    /// à redessiner un parcours au mètre près sur un écran.
    private func route(for workout: HKWorkout) async -> [RunRecord.RoutePoint] {
        let series: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: HKSeriesType.workoutRoute(),
                predicate: HKQuery.predicateForObjects(from: workout),
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, _, _ in
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }

        var points: [RunRecord.RoutePoint] = []
        for serie in series {
            points += await locations(in: serie)
        }
        return RouteGeometry.decimatedPoints(points, keeping: 1500)
    }

    /// Les positions d'une série, ramassées à travers des rappels successifs.
    ///
    /// `HKWorkoutRouteQuery` livre le parcours PAR MORCEAUX : son gestionnaire est appelé plusieurs
    /// fois, et seul le dernier appel porte `done`. Une continuation, elle, ne se reprend qu'une
    /// fois — la reprendre deux fois plante le processus. D'où l'accumulateur verrouillé ci-dessous
    /// plutôt qu'un simple booléen : les rappels n'arrivent pas sur le fil principal.
    private func locations(in serie: HKWorkoutRoute) async -> [RunRecord.RoutePoint] {
        let accumulator = RouteAccumulator()
        return await withCheckedContinuation { continuation in
            let query = HKWorkoutRouteQuery(route: serie) { _, locations, done, error in
                if let locations {
                    accumulator.add(locations.compactMap { location in
                        // Négatif = coordonnée invalide, pas « imprécise ».
                        guard location.horizontalAccuracy >= 0 else { return nil }
                        return RunRecord.RoutePoint(
                            lat: location.coordinate.latitude,
                            lng: location.coordinate.longitude,
                            // Mêmes seuils que `LocationService` : l'altitude n'est retenue que
                            // quand elle est mesurée, jamais remplacée par un zéro qui se lirait
                            // comme « niveau de la mer ».
                            altitude: location.verticalAccuracy >= 0 && location.verticalAccuracy < 20
                                ? location.altitude : nil
                        )
                    })
                }
                if done || error != nil {
                    if let collected = accumulator.finish() { continuation.resume(returning: collected) }
                }
            }
            store.execute(query)
        }
    }

    private static let bpm = HKUnit.count().unitDivided(by: .minute())

    private func sum(type: HKQuantityType, unit: HKUnit, in workout: HKWorkout) async -> Double {
        await statistic(type: type, unit: unit, in: workout, options: .cumulativeSum) { $0.sumQuantity() }
    }

    private func average(type: HKQuantityType, unit: HKUnit, in workout: HKWorkout) async -> Double {
        await statistic(type: type, unit: unit, in: workout, options: .discreteAverage) { $0.averageQuantity() }
    }

    /// Une statistique sur l'intervalle exact d'un entraînement, toutes sources confondues.
    ///
    /// Volontairement SANS le filtre `HKSource.default()` des sommes quotidiennes : on cherche ici
    /// à décrire une course précise, pas à éviter de compter deux fois la même énergie. Si la
    /// fréquence cardiaque de cette sortie a été écrite par un capteur tiers, c'est justement
    /// celle-là qu'il faut lire.
    private func statistic(type: HKQuantityType, unit: HKUnit, in workout: HKWorkout,
                           options: HKStatisticsOptions,
                           pick: @escaping (HKStatistics) -> HKQuantity?) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, stats, _ in
                continuation.resume(returning: stats.flatMap(pick)?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    /// `end` is `.now` for today (only counts what's actually happened so far — not a future
    /// window) and the real end of day for any earlier date.
    private func sum(type: HKQuantityType, unit: HKUnit, on date: Date) async -> Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.isDateInToday(date) ? Date.now : (cal.date(byAdding: .day, value: 1, to: start) ?? start)
        // Les échantillons écrits par RUNUP elle-même sont EXCLUS, et ça devient indispensable
        // maintenant que `saveRun` en écrit : `HKStatisticsQuery` somme toutes les sources sans
        // dédoublonner, là où l'app Santé, elle, choisit une source par intervalle. Sans ce
        // filtre, une sortie de 400 kcal enregistrée par RUNUP s'ajouterait aux ~400 kcal que
        // l'iPhone a mesurées sur la même période, et l'anneau de calories afficherait le double
        // après chaque course — une erreur qui n'a pas l'air d'un bug, juste d'une bonne journée.
        //
        // La requête de sommeil plus haut n'a pas besoin de ce filtre : l'app n'écrit jamais de
        // sommeil.
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: end),
            NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))
        ])
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }
}

/// Ramasse les positions d'un parcours livré par morceaux, et garantit qu'on ne rend le résultat
/// qu'UNE fois.
///
/// `HKWorkoutRouteQuery` appelle son gestionnaire plusieurs fois, depuis une file système. Reprendre
/// deux fois la même continuation ne produit pas un bug discret : ça plante le processus. Le verrou
/// est là pour ça, pas pour les performances — il protège deux lignes appelées quelques fois par
/// course importée.
private final class RouteAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var points: [RunRecord.RoutePoint] = []
    private var finished = false

    func add(_ newPoints: [RunRecord.RoutePoint]) {
        lock.lock()
        points += newPoints
        lock.unlock()
    }

    /// Les points la première fois, `nil` ensuite — l'appelant ne reprend la continuation que sur
    /// une valeur non nulle.
    func finish() -> [RunRecord.RoutePoint]? {
        lock.lock()
        defer { lock.unlock() }
        if finished { return nil }
        finished = true
        return points
    }
}
