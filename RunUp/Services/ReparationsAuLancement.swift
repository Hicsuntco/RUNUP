import Foundation
import SwiftData

/// Les réparations qu'on fait une fois, au lancement, sur ce qui est DÉJÀ sur le téléphone.
///
/// # POURQUOI ELLES SORTENT D'`AppState`
///
/// `AppState` est un objet-dieu : la navigation, les feuilles, la course en direct, le compte, la
/// sauvegarde, les objectifs du jour et ces réparations, dans le même fichier. Le coût n'est pas
/// le nombre de lignes, c'est que ces deux réparations-ci étaient des méthodes PRIVÉES d'un objet
/// qu'un test ne peut pas construire sans toute l'app derrière.
///
/// Elles ne demandent pourtant qu'un contexte de données. Sorties ici, elles prennent ce contexte
/// en paramètre et se vérifient avec une base en mémoire — c'est la même histoire que
/// `LocationService.majDeLaDistance`, dont le commentaire raconte qu'une règle corrigeant une
/// erreur de cinquante pour cent n'avait aucun test parce qu'elle était inatteignable depuis
/// l'extérieur de son fichier.
///
/// # CE QUI N'EST PAS SORTI, ET POURQUOI
///
/// `recoverInterruptedRunIfNeeded` est restée dans `AppState`. Elle lit le profil, et surtout elle
/// NOTIFIE — elle touche l'état vivant de l'app, ce qui est précisément le travail d'`AppState`.
/// La déplacer pour faire baisser un compteur de lignes aurait été du brassage : il aurait fallu
/// lui faire rendre ce qu'elle voulait annoncer, pour que l'appelant l'annonce à sa place, sans
/// qu'aucun test n'y gagne.
///
/// Le découpage se fait par morceaux et seulement là où il paie. C'est la règle écrite dans
/// `PHASE2.md` au regard de ce chantier, et elle reste la bonne.
enum ReparationsAuLancement {

    /// Les marqueurs « c'est fait », dans `UserDefaults`.
    ///
    /// Nommés ici plutôt qu'écrits dans le corps de chaque fonction, pour que les tests les
    /// LISENT au lieu de les recopier : une clé recopiée qui dérive donne un test qui passe sur
    /// une réparation qui ne tourne plus.
    enum Marqueur {
        static let titresDesJoursDeRepos = "repair.restDayRunTitles.v1"
        static let denivelePositif = "repair.elevationGain.v1"
    }
    /// Renomme les sorties DÉJÀ enregistrées sous le titre d'un jour de repos.
    ///
    /// `buildRunRecord` empêche désormais d'en écrire de nouvelles, mais il ne touche pas à
    /// celles qui sont sur le téléphone — et « Repos · 7,4 km · 45:18 » est une ligne qui se
    /// contredit dans sa propre largeur. Elle ne se répare pas toute seule.
    ///
    /// LE CRITÈRE EST `sessionKind`, PAS LE TEXTE. Le titre est stocké traduit : chercher « Repos »
    /// raterait exactement les mêmes lignes sur un téléphone anglais ou espagnol, et c'est le
    /// genre de correctif qui marche chez soi et nulle part ailleurs. Une course avec une vraie
    /// distance ne peut de toute façon pas être une séance de repos.
    ///
    /// Une fois par installation : ce n'est pas une règle, c'est une réparation. Le marqueur est
    /// posé APRÈS l'enregistrement — une réparation interrompue doit pouvoir recommencer.
    static func renommerLesCoursesDuJourDeRepos(_ modelContext: ModelContext) {
        let cle = Marqueur.titresDesJoursDeRepos
        // LE MAGASIN DE SECOURS BRÛLERAIT CETTE RÉPARATION POUR TOUJOURS.
        //
        // `PersistenceController` ouvre un conteneur en mémoire VIDE quand le fichier sur disque
        // refuse de s'ouvrir. Le `fetch` rendrait alors zéro ligne, le `save` serait sauté, et le
        // marqueur serait quand même posé — or il vit dans `UserDefaults`, qui n'est pas dans le
        // magasin. La réparation serait donc marquée faite sans avoir rien lu, et ne se
        // relancerait JAMAIS quand le vrai fichier redeviendrait lisible.
        //
        // C'est exactement la perte que le chemin de secours promet d'éviter : les données
        // reviennent après une mise à jour, leurs réparations non.
        guard !PersistenceController.enSecours else { return }
        guard !UserDefaults.standard.bool(forKey: cle) else { return }
        guard let toutes = try? modelContext.fetch(FetchDescriptor<RunRecord>()) else { return }
        let libre = String(localized: "Séance libre")
        var renommees = 0
        for course in toutes where course.title != libre && estUnJourDeRepos(course) {
            course.title = libre
            renommees += 1
        }
        if renommees > 0 {
            guard (try? modelContext.save()) != nil else { return }
        }
        UserDefaults.standard.set(true, forKey: cle)
    }

    /// Recalcule le dénivelé positif des sorties DÉJÀ enregistrées.
    ///
    /// `ElevationGain` empêche désormais d'en écrire de faux, mais il ne touche pas à ce qui est
    /// sur le téléphone. Et l'ancien calcul ne se trompait pas de quelques pour cent : il sommait
    /// chaque écart d'altitude positif entre deux fixes GPS, c'est-à-dire la moitié positive d'un
    /// bruit symétrique, et fabriquait deux mille mètres de D+ sur une heure d'immobilité. Toutes
    /// les sorties de l'historique portent ce chiffre-là. Le badge « 300 m de D+ » du Club s'est
    /// décerné dessus.
    ///
    /// Les altitudes du tracé sont la MÊME suite de nombres que celle sur laquelle l'ancien total
    /// a été calculé — `ElevationGain.rejoue(altitudes:intervalleSecondes:)` explique pourquoi en
    /// détail. Ce n'est donc pas une estimation rétrospective, c'est le même calcul refait.
    ///
    /// Trois refus, et chacun compte :
    ///
    /// - **Pas de tracé, ou moins de dix altitudes connues.** Une sortie saisie à la main, importée
    ///   de Santé ou marquée « faite » sans GPS n'a rien à rejouer. Elle garde sa valeur plutôt que
    ///   d'en recevoir une tirée de trois points — et surtout, elle ne se fait pas remettre à zéro.
    /// - **Un résultat qui monterait.** Voir `RunRecord.deniveleRecalcule` : le défaut ne peut que
    ///   sur-compter, donc un rejeu qui propose davantage est un rejeu qui se trompe.
    /// - **Un résultat identique.** Rien à écrire, donc rien d'écrit.
    ///
    /// Une fois par installation, et le marqueur est posé APRÈS l'enregistrement — une réparation
    /// interrompue doit pouvoir recommencer. Exactement comme celle des titres au-dessus.
    ///
    /// CE QU'ELLE NE RÉPARE PAS : les itinéraires déjà PUBLIÉS au Club. Leur dénivelé est parti
    /// sur le serveur avec le reste, et il y reste. Rien ici ne peut l'atteindre.
    static func recalculerLeDenivelePositif(_ modelContext: ModelContext) {
        let cle = Marqueur.denivelePositif
        // Même garde que la réparation précédente : sur le magasin de secours, le marqueur
        // serait posé sans que rien n'ait été lu, et cette réparation ne se relancerait jamais.
        guard !PersistenceController.enSecours else { return }
        guard !UserDefaults.standard.bool(forKey: cle) else { return }
        guard let toutes = try? modelContext.fetch(FetchDescriptor<RunRecord>()) else { return }
        var corrigees = 0
        for course in toutes {
            guard let recalcule = course.deniveleRecalcule else { continue }
            course.elevationGainM = recalcule
            corrigees += 1
        }
        if corrigees > 0 {
            guard (try? modelContext.save()) != nil else { return }
        }
        UserDefaults.standard.set(true, forKey: cle)
    }

    /// Deux critères, parce que le champ qui sert au premier n'a pas toujours existé.
    ///
    /// `sessionKind` est arrivé le 16 août 2026 : les courses enregistrées avant valent `nil`, et
    /// s'arrêter au type laisserait les plus anciennes — justement celles qui traînent depuis le
    /// plus longtemps — avec leur titre absurde.
    ///
    /// Pour celles-là, et pour elles seulement, le TEXTE est fiable : la traduction à l'écriture
    /// est arrivée par le même changement, donc le titre d'une course antérieure est resté
    /// français. C'est exactement le repli que documente déjà `RunRecord.sessionKind` pour le
    /// comptage des séances. Et personne n'intitule « Repos » une course de sept kilomètres.
    private static func estUnJourDeRepos(_ course: RunRecord) -> Bool {
        if let kind = course.sessionKind { return kind == .rest }
        return course.title == "Repos"
    }
}
