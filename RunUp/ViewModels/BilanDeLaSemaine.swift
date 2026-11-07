import Foundation

/// Les chiffres de l'écran « Bilan de la semaine », calculés à part de la vue.
///
/// # POURQUOI CE FICHIER EXISTE
///
/// Cet écran portait **cinq** définitions différentes de « la semaine », toutes dans des
/// propriétés privées d'une vue SwiftUI, donc aucune n'était vérifiable :
///
///   · « Parcourus » comptait les kilomètres À PIED, « Volume par jour (km) » les comptait
///     TOUS — la somme des barres pouvait dépasser le total affiché juste au-dessus ;
///   · « Ta meilleure semaine » comparait les kilomètres à pied de cette semaine aux kilomètres
///     toutes disciplines des autres, donc le titre ne paraissait jamais chez quelqu'un qui
///     roule ;
///   · le record d'allure comparait toutes les disciplines au meilleur temps de COURSE. Or
///     `avgPace` est stocké en secondes au kilomètre pour toutes : une sortie à vélo à 20 km/h
///     vaut 180 s/km et bat n'importe quelle allure de course. L'écran annonçait « Nouveau
///     record d'allure · 3:00/km » après une sortie à vélo ;
///   · « Temps actif » ne comptait que la course, sur un écran qui listait la sortie vélo juste
///     en dessous et la comptait dans « Séances » ;
///   · « Séances » comptait tout, sans que ce soit écrit nulle part.
///
/// `RunRecordDiscipline` porte déjà la doctrine : `.only(.run)`, `.onFoot`, et `.allDisciplines`
/// qui existe pour que « toutes » soit **une décision écrite, pas l'absence de décision**. Les
/// cinq agrégations l'ignoraient.
///
/// # LES KILOMÈTRES NE S'ADDITIONNENT PAS, LE TEMPS SI
///
/// C'est la règle qui tranche chaque cas ci-dessous. Vingt kilomètres à vélo ne sont pas vingt
/// kilomètres en courant — les mettre dans le même total ne mesure rien. Une heure, en revanche,
/// est une heure quelle que soit la discipline, et c'est précisément ce que « temps actif » veut
/// dire à côté d'un compteur de kilomètres.
///
/// # ET IL VIT À CÔTÉ DU MODÈLE DE VUE, PAS DANS `Shared/`
///
/// Même raison que `PlanRecap`, écrite en tête de ce fichier-là : `RunUp/Shared` est compilé en
/// entier dans l'extension de widgets, qui ne connaît pas `RunRecord`.
struct BilanDeLaSemaine {

    /// La semaine regardée, lundi inclus à lundi exclu.
    let semaine: Range<Date>
    /// Les séances de cette semaine, toutes disciplines — c'est la liste que l'écran affiche.
    let seances: [RunRecord]
    /// Tout l'historique, pour les comparaisons entre semaines.
    private let historique: [RunRecord]

    init(historique: [RunRecord], semaine: Range<Date>) {
        self.historique = historique
        self.semaine = semaine
        self.seances = historique.filter { semaine.contains($0.date) }
    }

    // MARK: Les quatre tuiles

    /// À PIED. Voir « les kilomètres ne s'additionnent pas » en tête de fichier.
    var kilometres: Double { seances.onFoot.reduce(0) { $0 + $1.distanceKm } }

    /// TOUTES DISCIPLINES, et c'est écrit. Une heure est une heure.
    var secondesActives: Int { seances.allDisciplines.reduce(0) { $0 + $1.durationSeconds } }

    /// TOUTES DISCIPLINES, et c'est écrit. Une séance est une séance.
    var nombreDeSeances: Int { seances.allDisciplines.count }

    /// Les kilomètres à pied de la semaine précédente, pour l'écart affiché sur la tuile.
    var kilometresSemainePrecedente: Double {
        let precedente = AdaptivePlanEngine.currentWeekRange(
            from: Calendar.current.date(byAdding: .day, value: -7, to: semaine.lowerBound) ?? semaine.lowerBound)
        return historique.onFoot.filter { precedente.contains($0.date) }.reduce(0) { $0 + $1.distanceKm }
    }

    /// L'allure moyenne de la COURSE À PIED sur route — la seule discipline dont une moyenne
    /// d'allures a un sens à l'échelle d'une semaine. `nil` quand elle n'a pas couru.
    var allureMoyenneSecParKm: Double? {
        let allures = seances.only(.run).compactMap { PaceModel.parseSecPerKm($0.avgPace) }
        guard !allures.isEmpty else { return nil }
        return allures.reduce(0, +) / Double(allures.count)
    }

    // MARK: Le graphique

    /// Les kilomètres À PIED par jour, lundi…dimanche. La même discipline que `kilometres`, pour
    /// que la somme des barres soit exactement le total affiché au-dessus.
    var kilometresParJour: [Double] {
        var totaux = [Double](repeating: 0, count: 7)
        for seance in seances.onFoot {
            totaux[WidgetWeekDay.rangDuJour(seance.date)] += seance.distanceKm
        }
        return totaux
    }

    // MARK: Les deux titres qui affirment quelque chose

    /// Cette semaine bat-elle toutes les autres ? À pied **des deux côtés**.
    var estLaMeilleureSemaine: Bool {
        guard kilometres > 0 else { return false }
        var parSemaine: [Date: Double] = [:]
        for seance in historique.onFoot {
            parSemaine[AdaptivePlanEngine.currentWeekRange(from: seance.date).lowerBound, default: 0] += seance.distanceKm
        }
        let meilleureAutre = parSemaine.filter { $0.key != semaine.lowerBound }.values.max() ?? 0
        return kilometres > meilleureAutre
    }

    /// Un record réellement battu CETTE semaine, ou `nil`. Jamais fabriqué.
    enum Record: Equatable {
        /// Allure de course à pied sur route, en secondes au kilomètre, et la distance tenue.
        case allure(secParKm: Double, km: Double)
        /// Distance à pied.
        case distance(km: Double)
    }

    var record: Record? {
        let avant = historique.filter { !semaine.contains($0.date) }

        // L'ALLURE SE COMPARE ENTRE COUREUSES À PIED SUR ROUTE, DES DEUX CÔTÉS.
        //
        // C'était le défaut le plus grave de l'écran : le meilleur temps d'avant ne regardait que
        // la course, celui de la semaine regardait tout. Le trail est exclu des deux côtés comme
        // avant, et c'est volontaire : une allure de trail ne se compare pas à une allure de
        // route, le dénivelé décidant de tout.
        let meilleureAvant = avant.only(.run).compactMap { PaceModel.parseSecPerKm($0.avgPace) }.min()
        let meilleureCetteSemaine = seances.only(.run)
            .compactMap { s -> (RunRecord, Double)? in PaceModel.parseSecPerKm(s.avgPace).map { (s, $0) } }
            .min(by: { $0.1 < $1.1 })
        if let meilleureAvant, let (seance, allure) = meilleureCetteSemaine, allure < meilleureAvant {
            return .allure(secParKm: allure, km: seance.distanceKm)
        }

        let plusLongueAvant = avant.onFoot.map(\.distanceKm).max() ?? 0
        if let plusLongue = seances.onFoot.max(by: { $0.distanceKm < $1.distanceKm }),
           plusLongue.distanceKm > plusLongueAvant {
            return .distance(km: plusLongue.distanceKm)
        }
        return nil
    }
}
