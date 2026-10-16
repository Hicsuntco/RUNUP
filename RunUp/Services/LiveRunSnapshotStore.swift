import Foundation

/// Ce qu'une course a accumulé jusqu'ici, écrit sur disque pendant qu'elle se déroule.
///
/// Sans ça, tout l'état d'une course vivait en mémoire et rien n'était persisté avant l'arrêt :
/// une app tuée en plein effort — iOS qui récupère de la mémoire pendant une sortie longue écran
/// verrouillé, ou un balayage dans le sélecteur d'apps — faisait disparaître la course
/// intégralement. Pas d'entrée dans l'historique, rien dans Apple Santé, aucun message : au
/// relancement, l'écran d'accueil comme si de rien n'était. La Live Activity orpheline était même
/// terminée au démarrage, donc la dernière trace visible disparaissait aussi.
struct LiveRunSnapshot: Codable {
    var startedAt: Date
    var updatedAt: Date
    var accumulatedPauseSeconds: Double
    var elapsedSeconds: Double
    var distanceMeters: Double
    var elevationGainMeters: Double
    var splitSecondsPerKm: [Double]
    var sessionTitle: String
    /// Optionnel : un instantané écrit avant ce champ le décode à nil, et la course récupérée
    /// vaut alors ce que valaient toutes les courses avant `SessionKind`.
    var sessionKind: SessionKind?
    var route: [RunRecord.RoutePoint]

    init(startedAt: Date, updatedAt: Date, accumulatedPauseSeconds: Double, elapsedSeconds: Double,
         distanceMeters: Double, elevationGainMeters: Double, splitSecondsPerKm: [Double],
         sessionTitle: String, sessionKind: SessionKind?, route: [RunRecord.RoutePoint]) {
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.accumulatedPauseSeconds = accumulatedPauseSeconds
        self.elapsedSeconds = elapsedSeconds
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.splitSecondsPerKm = splitSecondsPerKm
        self.sessionTitle = sessionTitle
        self.sessionKind = sessionKind
        self.route = route
    }

    /// LE DÉCODAGE NE DOIT RIEN EXIGER — et c'est une course en cours qui est en jeu.
    ///
    /// Swift synthétisait `decode` pour les dix propriétés non optionnelles. L'enchaînement
    /// réel : une course tourne, iOS tue l'app pour récupérer de la mémoire, iOS installe la
    /// mise à jour en attente, l'app relance — et la nouvelle version a ajouté un champ. Le
    /// décodage lève, `loadRecoverable` attrape sous `try?` et appelle `clear()` : le fichier
    /// est SUPPRIMÉ. La course disparaît sans laisser la moindre trace, ce qui est exactement la
    /// panne que ce fichier existe pour empêcher.
    ///
    /// Même règle qu'en tête de `Session.swift`, pour une raison voisine : ici `JSONDecoder`
    /// lève au lieu d'arrêter le processus, mais le résultat — la donnée effacée — est pire.
    /// Les replis sont neutres : une course reprise avec un dénivelé à zéro reste une course
    /// reprise.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        accumulatedPauseSeconds = try c.decodeIfPresent(Double.self, forKey: .accumulatedPauseSeconds) ?? 0
        elapsedSeconds = try c.decodeIfPresent(Double.self, forKey: .elapsedSeconds) ?? 0
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? 0
        elevationGainMeters = try c.decodeIfPresent(Double.self, forKey: .elevationGainMeters) ?? 0
        splitSecondsPerKm = try c.decodeIfPresent([Double].self, forKey: .splitSecondsPerKm) ?? []
        sessionTitle = try c.decodeIfPresent(String.self, forKey: .sessionTitle) ?? ""
        // `try?` sur l'énumération, et sur elle seule : un `rawValue` inconnu ne rend pas nil,
        // il LÈVE. Voir `WorkoutSession.init(from:)`, même piège, même parade.
        sessionKind = (try? c.decodeIfPresent(SessionKind.self, forKey: .sessionKind)) ?? nil
        route = try c.decodeIfPresent([RunRecord.RoutePoint].self, forKey: .route) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case startedAt, updatedAt, accumulatedPauseSeconds, elapsedSeconds, distanceMeters
        case elevationGainMeters, splitSecondsPerKm, sessionTitle, sessionKind, route
    }
}

/// Lit et écrit l'instantané dans un fichier du conteneur de l'app, pas dans `UserDefaults`.
///
/// La raison est le tracé : une sortie d'une heure accumule un bon millier de points, et
/// `UserDefaults` est chargé en mémoire à chaque lancement et réécrit en entier à chaque
/// modification. Un fichier est le bon outil pour une donnée de cette taille écrite en continu.
enum LiveRunSnapshotStore {
    /// Au-delà, on ne propose plus rien. Une course oubliée depuis la veille ne se récupère pas :
    /// on ne saurait ni quand elle s'est vraiment arrêtée, ni si la coureuse a couru entre-temps.
    /// Douze heures couvrent largement le cas réel — l'app tuée pendant une sortie, rouverte le
    /// jour même — sans jamais ressortir un fantôme.
    static let maxAge: TimeInterval = 12 * 3600

    /// En dessous, il n'y a rien à récupérer : une course de trente secondes ou de cinquante
    /// mètres est un démarrage accidentel, et proposer de l'enregistrer serait du bruit.
    static let minRecoverableSeconds: Double = 120
    static let minRecoverableMeters: Double = 300

    private static var url: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appending(path: "liveRunSnapshot.json")
    }

    static func save(_ snapshot: LiveRunSnapshot) {
        guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }
        // `.atomic` : l'écriture passe par un fichier temporaire renommé d'un bloc. Une app tuée
        // au milieu d'une écriture laisserait sinon un JSON tronqué — donc illisible — c'est-à-dire
        // qu'elle échouerait exactement dans le scénario pour lequel ce fichier existe.
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// L'instantané s'il existe, est lisible, assez récent et assez consistant pour valoir la
    /// peine d'être proposé. Renvoie nil dans tous les autres cas — y compris un fichier corrompu,
    /// qui est alors nettoyé.
    static func loadRecoverable() -> LiveRunSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(LiveRunSnapshot.self, from: data) else {
            clear()
            return nil
        }
        guard Date().timeIntervalSince(snapshot.updatedAt) < maxAge else {
            clear()
            return nil
        }
        guard snapshot.elapsedSeconds >= minRecoverableSeconds,
              snapshot.distanceMeters >= minRecoverableMeters else {
            clear()
            return nil
        }
        return snapshot
    }

    static func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
