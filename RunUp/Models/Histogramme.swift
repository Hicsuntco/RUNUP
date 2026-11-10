import Foundation

/// Un histogramme de durées, réduit à ce qu'on peut en dire honnêtement.
///
/// # POURQUOI CE TYPE EXISTE
///
/// La phase 4 du brief promet « premier écran en moins de 2 secondes ». Personne ne l'avait
/// jamais relevé — item B7 de `PHASE2.md` : « Le temps de lancement n'a jamais été mesuré. On ne
/// peut pas tenir une promesse qu'on n'a pas mesurée. »
///
/// Et il n'y avait rien à construire pour le relever : iOS le mesure déjà sur chaque appareil
/// réel, tous les jours, et l'envoie par MetricKit. `Diagnostics` était abonné, et portait
///
///     func didReceive(_ payloads: [MXMetricPayload]) {}
///
/// une méthode VIDE. La mesure arrivait et tombait par terre.
///
/// # CE QU'ON SAIT, ET CE QU'ON NE SAIT PAS
///
/// Un histogramme MetricKit ne donne pas les durées, il donne des PALIERS : « 12 lancements ont
/// fini avant 250 ms », « 3 avant 500 ms ». On ne connaît donc aucune durée exacte, et toute
/// statistique qu'on en tire est une approximation — ce que ce type assume plutôt que de le
/// cacher derrière un nombre à la virgule près.
///
/// Les deux lectures ci-dessous sont donc des MAJORANTS, délibérément :
///
///   · `percentile(_:)` rend la borne HAUTE du palier où le cumul franchit le seuil. « p90 =
///     1 500 ms » veut dire « neuf lancements sur dix ont fini avant 1 500 ms », pas « le
///     quatre-vingt-dixième vaut 1 500 ms » ;
///   · `partAuDessusDe(ms:)` compte un palier à cheval sur le seuil comme étant AU-DESSUS.
///
/// Les deux se trompent dans le même sens : vers le pessimisme. C'est le bon sens pour une
/// promesse — on ne veut pas découvrir qu'on l'annonçait tenue parce qu'on arrondissait vers le
/// bas.
///
/// # SEULE LA BORNE HAUTE EST LUE
///
/// MetricKit donne aussi un début de palier. Il n'est pas utilisé, et ce n'est pas un oubli :
/// les paliers sont contigus, la borne haute suffit aux deux lectures ci-dessus, et le nom exact
/// de la propriété de début n'a pas pu être vérifié dans la documentation d'Apple. Lire une
/// propriété dont on n'est pas sûr, pour une donnée dont on n'a pas besoin, c'est deux risques
/// pour rien.
struct Histogramme: Equatable {
    /// Un palier : sa borne haute en millisecondes, et combien d'observations y sont tombées.
    struct Palier: Equatable {
        let finMs: Double
        let compte: Int
    }

    /// Triés par borne haute croissante — `init` s'en charge, parce que l'ordre dans lequel
    /// MetricKit énumère ses paliers n'est garanti nulle part.
    let paliers: [Palier]

    init(paliers: [Palier]) {
        self.paliers = paliers.filter { $0.compte > 0 && $0.finMs > 0 }.sorted { $0.finMs < $1.finMs }
    }

    var total: Int { paliers.reduce(0) { $0 + $1.compte } }

    var estVide: Bool { total == 0 }

    /// La borne haute du palier où le cumul franchit `part` du total, ou `nil` si rien n'a été
    /// observé.
    ///
    /// `part` vaut 0,5 pour la médiane, 0,9 pour le neuvième décile. Hors de ]0, 1], on rend
    /// `nil` plutôt que d'inventer : un appelant qui passe 90 au lieu de 0,9 doit s'en apercevoir.
    func percentile(_ part: Double) -> Double? {
        guard !estVide, part > 0, part <= 1 else { return nil }
        // `ceil` et non `round` : à 10 observations, le p50 est la 5e, pas la 5,5e. Et le
        // `max(1, …)` garde un rang valide pour une part minuscule sur un petit total.
        let rang = max(1, Int((Double(total) * part).rounded(.up)))
        var cumul = 0
        for palier in paliers {
            cumul += palier.compte
            if cumul >= rang { return palier.finMs }
        }
        return paliers.last?.finMs
    }

    /// La part des observations qui dépassent `ms`, entre 0 et 1 — ou `nil` si rien n'a été
    /// observé. Un palier à cheval sur le seuil compte comme étant au-dessus.
    func partAuDessusDe(ms seuil: Double) -> Double? {
        guard !estVide else { return nil }
        let au_dessus = paliers.filter { $0.finMs > seuil }.reduce(0) { $0 + $1.compte }
        return Double(au_dessus) / Double(total)
    }

    /// Les paliers, pour la ligne envoyée au serveur : « 250:12,500:3,1000:1 ».
    ///
    /// Compact à dessein : le sac de propriétés d'un événement est plafonné à 2 000 caractères
    /// côté serveur, et une forme JSON imbriquée doublerait la taille pour la même information.
    /// L'ordre est celui des paliers, donc croissant.
    var ligne: String {
        paliers.map { "\(Int($0.finMs.rounded())):\($0.compte)" }.joined(separator: ",")
    }
}
