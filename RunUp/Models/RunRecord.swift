import Foundation
import SwiftData

/// One completed run — a growing collection, queried newest-first. Mirrors `history` in app.jsx.
@Model
final class RunRecord {
    /// A GPS fix from the real route — plain lat/lng rather than `CLLocationCoordinate2D` (not
    /// natively `Codable`), so SwiftData can store it like any other value-type array (same
    /// pattern as `splits: [String]`). Feeds the share-card route trace; empty for runs with no
    /// GPS behind them (manually logged, or the no-GPS "Marquer comme faite" path).
    struct RoutePoint: Codable, Equatable {
        var lat: Double
        var lng: Double
        /// Real GPS altitude in meters, only when the fix's vertical accuracy was trustworthy
        /// (see `LocationService`) — Optional (not a 0 default) so it reads as "unknown" rather
        /// than "sea level" when there's no trustworthy reading, and so every run recorded
        /// before this field existed still decodes fine (a non-optional field with no inline
        /// default would fail Codable synthesis against old, key-less JSON).
        var altitude: Double?
    }

    var date: Date
    var title: String
    var distanceKm: Double
    var durationSeconds: Int
    var avgPace: String
    var avgHeartRate: Int
    var kcal: Int
    var elevationGainM: Int
    var splits: [String]
    /// Le type de séance que cette course a exécutée, indépendant de la langue.
    ///
    /// `title` est désormais le texte AFFICHÉ au moment de la course — donc traduit. C'est le bon
    /// choix pour l'historique (une course passée garde le libellé qu'elle a montré), mais ça
    /// casse tout ce qui LIT ce titre pour en déduire quelque chose : le badge « fractionné » du
    /// club comptait les courses dont le titre contient le mot « Fractionné », et ne se serait
    /// plus jamais débloqué en anglais ni en espagnol.
    ///
    /// C'est exactement l'erreur que le passage à `SessionKind` devait supprimer, reproduite un
    /// cran plus loin. Optionnel : les courses enregistrées avant ce champ valent nil, et le
    /// comptage retombe sur l'ancienne recherche de texte — qui reste juste pour elles, puisque
    /// leur titre, lui, est resté français.
    var sessionKind: SessionKind? = nil

    /// Courir ou rouler, STOCKÉ EN TEXTE ET OPTIONNEL. Lire `discipline` juste en dessous.
    ///
    /// # CE QUI A PLANTÉ, ET POURQUOI C'ÉTAIT INÉVITABLE
    ///
    /// La première version écrivait `var discipline: Discipline = Discipline.run`, non
    /// optionnelle avec une valeur par défaut. Elle compilait, les tests passaient, et le build
    /// plantait au lancement chez toute personne ayant déjà des données.
    ///
    /// Le mécanisme est traître parce que le filet de sécurité ne se déclenche pas : la
    /// migration légère RÉUSSIT, elle ajoute bien la colonne. Mais elle l'ajoute à NULL sur
    /// toutes les lignes existantes — une valeur par défaut écrite en Swift ne remplit pas le
    /// magasin. Au premier accès, décoder NULL dans une propriété non optionnelle est fatal, et
    /// l'accueil lit les courses dès le lancement. `PersistenceController` ne voit rien : il
    /// n'attrape que l'échec d'OUVERTURE du magasin, qui n'a pas eu lieu.
    ///
    /// Les six autres propriétés ajoutées à ce fichier au fil du temps — `sessionKind`,
    /// `stravaActivityId`, `healthWorkoutID`, `shoeID`, `debriefedAt` — sont toutes optionnelles.
    /// Ce n'était pas un hasard de style.
    ///
    /// Le texte brut plutôt que l'énumération optionnelle : l'absence et la valeur illisible se
    /// traitent alors au même endroit, et aucun appelant n'a à manipuler un optionnel.
    var disciplineRaw: String? = nil

    /// La discipline, toujours définie. Une ligne sans valeur est une course — par construction,
    /// puisque l'app ne savait rien faire d'autre quand elle a été écrite (voir
    /// `Discipline.legacy`). Une valeur illisible retombe sur la même règle plutôt que de
    /// propager un optionnel dans cinquante appelants.
    ///
    /// Calculée, donc non persistée : c'est `disciplineRaw` qui va sur le disque.
    var discipline: Discipline {
        get { disciplineRaw.flatMap(Discipline.init(rawValue:)) ?? .legacy }
        set { disciplineRaw = newValue.rawValue }
    }
    var route: [RoutePoint] = []
    /// Non-nil only for a run imported from Strava (see `StravaService.importActivities`) — lets
    /// re-importing skip activities already pulled in, instead of duplicating History on every
    /// sync.
    var stravaActivityId: Int? = nil
    /// Non-nil seulement pour une course importée d'Apple Santé — l'identifiant de l'entraînement
    /// tel que Santé le porte.
    ///
    /// Même rôle que `stravaActivityId` juste au-dessus, et pour la même raison : l'import
    /// repasse sur la même fenêtre à chaque retour au premier plan, et sans clé stable il
    /// ajouterait la même sortie à l'historique autant de fois qu'on ouvre l'app. Cet
    /// identifiant-là est attribué par Santé et ne bouge plus.
    var healthWorkoutID: UUID? = nil
    /// Which `Shoe` this run was logged in, if any — a plain field (not a `@Relationship`) so
    /// deleting a `Shoe` never cascades onto real run history; `Shoe.totalKm` just stops counting
    /// a run whose shoe no longer exists.
    var shoeID: UUID? = nil
    /// Set once, the moment `DebriefSheet`'s VALIDER actually runs for this record — the real
    /// guard against crediting XP/streak/club-feed twice for the same run (a double-tap, or
    /// reopening the debrief for an already-validated run). `run.modelContext == nil` alone only
    /// ever protected the INSERT, not re-running the reward logic on an already-inserted record.
    var debriefedAt: Date? = nil

    init(
        date: Date = .now,
        title: String,
        distanceKm: Double,
        durationSeconds: Int,
        avgPace: String,
        avgHeartRate: Int,
        kcal: Int,
        elevationGainM: Int = 0,
        splits: [String] = [],
        route: [RoutePoint] = [],
        stravaActivityId: Int? = nil,
        healthWorkoutID: UUID? = nil,
        /// Posé par l'initialiseur plutôt qu'après coup : c'est lui qui décide aussi du titre
        /// quand la séance du jour était un repos. Voir `AdaptivePlanEngine.buildRunRecord`.
        sessionKind: SessionKind? = nil,
        discipline: Discipline = .run
    ) {
        self.date = date
        self.title = title
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.avgPace = avgPace
        self.avgHeartRate = avgHeartRate
        self.kcal = kcal
        self.elevationGainM = elevationGainM
        self.splits = splits
        self.route = route
        self.stravaActivityId = stravaActivityId
        self.healthWorkoutID = healthWorkoutID
        self.sessionKind = sessionKind
        // Écrite explicitement : un relevé créé aujourd'hui sait de quoi il parle, et seules les
        // lignes antérieures au champ retombent sur `Discipline.legacy`.
        self.disciplineRaw = discipline.rawValue
    }
}

extension RunRecord {
    /// Est-ce que cette sortie bat quelque chose ? Deux records seulement, et exactement ceux que
    /// l'écran Stats affiche déjà sous « Records personnels » : la plus longue distance, et la
    /// meilleure allure moyenne (plancher de 1 km, sinon un sprint de 300 m battrait tout).
    ///
    /// Volontairement PAS un « PR » au sens chrono-sur-distance-officielle : l'app ne mesure pas
    /// de temps de passage au 5 km ou au 10 km, donc l'annoncer serait inventer un record qui n'a
    /// jamais été chronométré. `history` exclut la sortie elle-même — se comparer à soi-même
    /// ferait de toute première course un record.
    static func beatsPersonalRecord(_ run: RunRecord, history: [RunRecord]) -> Bool {
        let others = history.filter { $0 !== run }
        // Une première sortie n'est un record de rien : il n'y a rien à battre.
        guard !others.isEmpty else { return false }

        if run.distanceKm > 0.05, others.allSatisfy({ run.distanceKm > $0.distanceKm }) { return true }

        guard run.distanceKm >= 1, let pace = PaceModel.parseSecPerKm(run.avgPace) else { return false }
        let previousBest = others.compactMap { other -> Double? in
            guard other.distanceKm >= 1 else { return nil }
            return PaceModel.parseSecPerKm(other.avgPace)
        }.min()
        guard let previousBest else { return false }
        return pace < previousBest
    }
}
