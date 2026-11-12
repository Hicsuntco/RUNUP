import Foundation

/// Ce qu'une coureuse a demandé pour la semaine en cours, sous la forme que le générateur relit.
///
/// # LE PRINCIPE ÉTAIT DÉJÀ ÉCRIT, DEUX CHANGEMENTS NE LE SUIVAIENT PAS
///
/// `TrainingEase` l'énonce en toutes lettres : « une séance éditée à la main serait effacée au
/// passage suivant […] ce qui survit, ce sont les ENTRÉES du générateur, relues à chaque
/// génération ». Deux changements l'ignoraient et écrivaient directement dans `weekSessions` :
/// le déplacement d'une séance (`AppState.moveSession`, `moveTodaySessionToTomorrow`) et
/// l'allègement du jour (`applySameDayAdjustmentIfNeeded`).
///
/// `applyProgramSettingsChange` reconstruit la semaine de zéro. Il préserve les jours faits, et
/// rien d'autre. Les deux changements ci-dessus disparaissaient donc au prochain passage — et ce
/// passage n'a même pas besoin qu'elle demande quoi que ce soit : l'allègement du coach expire
/// tout seul au lancement et déclenche la régénération. Un déplacement posé mardi n'existait
/// plus jeudi matin, sans un mot.
///
/// Pire que l'effacement, l'inversion. Nuit de cinq heures à 8 h : le fractionné du jour passe
/// de 60 à 42 minutes, en souple. Elle écrit au coach à 10 h « j'ai mal au genou, allège » : la
/// semaine est régénérée, la séance revient à 45 minutes avec ses intervalles. Elle avait
/// demandé moins, elle obtenait plus dur qu'une minute avant.
///
/// # DEUX ENTRÉES, PAS UNE SÉANCE
///
/// Un déplacement est un ÉCHANGE DE DEUX JOURS, pas une séance posée ailleurs. Rejoué sur la
/// semaine fraîchement générée, il survit à toutes les régénérations — et, surtout, les règles
/// qui dépendent du jour (le plafond de temps du jour, la phase du cycle de ce jour-là) se
/// calculent alors sur le jour FINAL, ce qu'un déplacement appliqué après coup ne pouvait pas
/// faire : il emportait la durée et la note calculées pour le jour de départ.
struct DeplacementDeSeance: Codable, Equatable, Sendable {
    /// Le jour d'où la séance part, 0 = lundi … 6 = dimanche, comme partout dans l'app.
    var de: Int
    /// Le jour où elle atterrit. Le contenu des deux jours s'échange ; voir `SessionMove`.
    var vers: Int
    /// La semaine du programme à laquelle ce déplacement appartient.
    ///
    /// `generateWeekSessions` est appelé pour CHAQUE semaine du plan par `PlanView`, qui les
    /// prévisualise toutes. Sans ce numéro, un déplacement posé en semaine 4 se rejouerait sur
    /// la semaine 11 affichée en aperçu, et sur toutes les autres.
    var semaine: Int
    /// Les jours de course, et le jour de sortie longue, contre lesquels ce déplacement a été
    /// demandé.
    ///
    /// # UN DÉPLACEMENT NE SURVIT PAS À LA REFONTE DE LA SEMAINE
    ///
    /// « Déplace ma séance du jeudi au vendredi » ne veut plus rien dire une fois que le jeudi
    /// n'est plus un jour de course. Rejoué quand même, l'échange tirerait la séance du vendredi
    /// VERS le jeudi — c'est-à-dire reposerait une séance sur le jour qu'elle vient de déclarer
    /// impossible, en invoquant une demande qui disait l'inverse. Le symétrique est aussi faux :
    /// retirer le vendredi de ses jours de course doit emporter la séance qu'un déplacement y
    /// avait posée, sa dernière réponse comptant plus que l'avant-dernière.
    ///
    /// La forme est donc PORTÉE PAR LE DÉPLACEMENT, plutôt que l'oubli n'étant déclenché aux
    /// endroits qui changent les jours de course. Il y en a trois — les réglages du programme et
    /// deux actions du coach — c'est-à-dire trois occasions de l'oublier. Ici, aucun appelant ne
    /// peut passer à côté.
    var joursDeCourse: [Int]
    var jourSortieLongue: Int?

    /// Ce déplacement parle-t-il de la semaine qu'on est en train de construire ?
    ///
    /// Les bornes sont vérifiées ici et pas seulement à l'enregistrement, parce qu'un
    /// déplacement relu du disque peut avoir perdu une clé — voir `init(from:)`. Un échange
    /// portant sur un jour hors semaine déplacerait la séance vers une case qui n'existe pas,
    /// c'est-à-dire l'effacerait.
    func concerne(semaine numero: Int, joursDeCourse jours: [Int], jourSortieLongue jour: Int?) -> Bool {
        guard (0..<7).contains(de), (0..<7).contains(vers), de != vers else { return false }
        return semaine == numero && joursDeCourse == jours && jourSortieLongue == jour
    }

    init(de: Int, vers: Int, semaine: Int, joursDeCourse: [Int], jourSortieLongue: Int?) {
        self.de = de
        self.vers = vers
        self.semaine = semaine
        self.joursDeCourse = joursDeCourse
        self.jourSortieLongue = jourSortieLongue
    }

    /// Rien que des `decodeIfPresent` : cette structure est ENREGISTRÉE dans `UserProfile`, et
    /// le décodeur de SwiftData arrête le processus sur un `decode` dont la clé manque. La règle,
    /// et la panne de 0,2 seconde qui l'a imposée, sont en tête de `Session.swift` ;
    /// `ci_scripts/check_decodage.py` la tient pour toutes les structures enregistrées.
    ///
    /// Les replis de `de` et `vers` sont HORS SEMAINE, volontairement : un déplacement dont on ne
    /// sait plus quel jour il concernait n'est pas un déplacement vers lundi, c'est un
    /// déplacement à jeter. `concerne` le rejette, et la semaine est générée comme s'il n'avait
    /// jamais été demandé — ce qui est la seule chose honnête à faire d'une demande illisible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        de = try c.decodeIfPresent(Int.self, forKey: .de) ?? -1
        vers = try c.decodeIfPresent(Int.self, forKey: .vers) ?? -1
        semaine = try c.decodeIfPresent(Int.self, forKey: .semaine) ?? -1
        joursDeCourse = try c.decodeIfPresent([Int].self, forKey: .joursDeCourse) ?? []
        jourSortieLongue = try c.decodeIfPresent(Int.self, forKey: .jourSortieLongue)
    }

    private enum CodingKeys: String, CodingKey {
        case de, vers, semaine, joursDeCourse, jourSortieLongue
    }

    /// La semaine après rejeu des déplacements, dans l'ordre où ils ont été demandés.
    ///
    /// Générique sur la valeur, et sans aucune connaissance de ce qu'est une séance : ce sont
    /// des échanges de clés, ils se vérifient avec des entiers. Un jour vide participe à
    /// l'échange comme un autre — déplacer une séance vers un jour de repos doit laisser le
    /// jour de départ vide, pas la dupliquer.
    static func rejouer<V>(_ deplacements: [DeplacementDeSeance], sur assignation: [Int: V]) -> [Int: V] {
        var resultat = assignation
        for d in deplacements {
            let depart = resultat[d.de]
            // Affecter un optionnel RETIRE la clé quand il vaut `nil` : c'est ce qu'on veut, et
            // c'est pour ça qu'il n'y a pas de `if let` ici. Une séance déplacée vers un jour de
            // repos doit laisser son jour de départ VIDE, pas garder une copie d'elle-même.
            resultat[d.de] = resultat[d.vers]
            resultat[d.vers] = depart
        }
        return resultat
    }
}

/// L'allègement réactif du jour, tel que le générateur le relit à chaque passage.
///
/// Il ne vaut que pour SON jour civil. Ce n'est pas une contrainte datée comme `TrainingEase`,
/// qui court jusqu'à une échéance : c'est une réponse à une nuit courte ou à une séance jugée
/// trop dure la veille, et elle n'a aucune raison de survivre à la nuit suivante. Stocké plutôt
/// que appliqué sur place pour une seule raison : pour que la régénération le relise au lieu de
/// l'effacer.
struct AllegementDuJour: Codable, Equatable, Sendable {
    /// Le jour civil pour lequel l'allègement a été décidé.
    var le: Date
    /// La mention affichée sous le titre. Une clé française, traduite à l'affichage comme
    /// `WorkoutSession.adjustment` — voir `ChipView.StatChip` et `HomeView`.
    var raison: String

    // CE QUI N'EST PAS STOCKÉ ICI, ET POURQUOI.
    //
    // Ni le facteur appliqué à la durée, ni « la séance passe en souple ». Les deux se déduisent
    // d'un seul test — la séance du jour est-elle une séance de qualité — que le générateur est
    // le seul à pouvoir poser au bon moment : sur la séance qui se trouve VRAIMENT là, après les
    // déplacements. Les figer à la décision reviendrait à raccourcir de 30 % un footing parce que
    // la séance qui occupait ce jour-là ce matin était un fractionné.

    func sApplique(a jour: Date, calendrier: Calendar = .current) -> Bool {
        calendrier.isDate(le, inSameDayAs: jour)
    }

    /// La séance, allégée.
    ///
    /// # LA RÈGLE N'EXISTE QU'ICI, ET C'EST LE POINT
    ///
    /// Elle vivait dans le générateur de programme. La course libre n'a pas de semaine générée —
    /// sa séance du jour est recalculée à chaque affichage par `CourseLibre.duJour` — donc elle
    /// ne l'appliquait pas : la notification « Séance allégée aujourd'hui » partait en promettant
    /// un allègement que l'écran ne montrait jamais. Une notification qui ment est pire qu'une
    /// notification absente.
    ///
    /// Forcer de la VMA sur cinq heures de sommeil n'est pas un entraînement, c'est un risque :
    /// une séance de qualité PERD SA STRUCTURE plutôt que de faire la même en plus court. Une
    /// séance déjà souple est seulement raccourcie.
    ///
    /// S'applique sur la séance CONSTRUITE, en dernier. Les plafonds du coach et du temps
    /// disponible bornent un plan ; celui-ci répond à une nuit précise, et il a le dernier mot —
    /// y compris sur la mention affichée, pour la même raison que la blessure passe devant la
    /// phase du cycle : c'est l'explication la plus forte et la plus immédiate de ce qu'elle a
    /// sous les yeux aujourd'hui.
    func appliquee(a seance: WorkoutSession) -> WorkoutSession {
        // UN JOUR DE REPOS NE S'ALLÈGE PAS. La course libre en propose de vrais, à zéro minute :
        // il n'y a rien à raccourcir, et poser la mention dessus annoncerait une séance allégée
        // là où il n'y a pas de séance.
        guard seance.durationMinutes > 0 else { return seance }
        var allegee = seance
        // POURQUOI PAS `role == .speed` ICI, alors que c'est la réponse unique ailleurs.
        //
        // Le rôle dit ce qu'une séance coûte au budget de la SEMAINE, et seules les séances du
        // générateur en portent un. L'allègement du jour s'applique aussi en course libre, où la
        // séance est recalculée à chaque affichage et n'a pas de rôle — lire le rôle y rendrait
        // l'allègement muet sur un fractionné.
        //
        // La question posée ici est d'ailleurs une TROISIÈME, voisine des deux autres : non pas
        // « est-ce que ça compte au budget » (le rôle), ni « faut-il un jour de récupération
        // derrière » (`SessionFamily.isDemanding`), mais « y a-t-il de l'intensité à retirer ».
        // Elle se répond sur le contenu de la séance, donc partout.
        let qualite = seance.isIntervalSession
            || seance.zone.contains("3") || seance.zone.contains("4")
        allegee.durationMinutes = Int(Double(seance.durationMinutes) * (qualite ? 0.7 : 0.85))
        if qualite {
            allegee.zone = "Z2"
            allegee.intervals = nil
            allegee.adaptationNote = "séance allégée aujourd'hui — allure confort, écoute-toi"
        }
        allegee.adjustment = raison
        return allegee
    }

    init(le: Date, raison: String) {
        self.le = le
        self.raison = raison
    }

    /// Rien que des `decodeIfPresent`, pour la raison donnée sur `DeplacementDeSeance`.
    ///
    /// Un allègement dont on a perdu le jour est un allègement EXPIRÉ, pas un allègement
    /// éternel : `.distantPast` ne vaut aucun jour civil, donc `sApplique` répond faux à la
    /// première question. Un allègement dont on a perdu la mention garde sa raison la plus
    /// générale — elle est au catalogue, donc traduite comme les autres. Mieux vaut une mention
    /// vague qu'une pastille vide sous une séance raccourcie sans explication.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        le = try c.decodeIfPresent(Date.self, forKey: .le) ?? .distantPast
        raison = try c.decodeIfPresent(String.self, forKey: .raison) ?? "Allégée · récupération"
    }

    private enum CodingKeys: String, CodingKey {
        case le, raison
    }
}
