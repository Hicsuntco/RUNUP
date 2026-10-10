import Foundation

/// Les pastilles de l'écran « TON PLAN », celui qui ferme l'inscription.
///
/// # CE QU'IL FAIT, ET POURQUOI IL EST ICI ET PAS DANS LA VUE
///
/// L'inscription pose neuf écrans de questions, puis fabrique un programme. Entre les deux, elle
/// n'a jamais rien RENDU : l'anneau de construction se remplissait, et l'app s'ouvrait sur
/// l'accueil. Les réponses disparaissaient dans la machine, et rien ne venait dire qu'elles
/// avaient été entendues.
///
/// Les pastilles sont cette preuve. Chacune est une réponse qu'elle vient de donner, relue telle
/// quelle — sa distance, son chrono, son jour J, son rythme, sa blessure à ménager. Pas une
/// promesse marketing : une citation.
///
/// Le calcul vit à part de la vue parce qu'il est la seule chose ici qui puisse être FAUSSE, et
/// donc la seule qui vaille d'être testée : un objectif oublié, une pastille vide, un `-0 kg`.
/// Une vue SwiftUI ne se teste pas sur un simulateur de CI sans coût ; une fonction qui prend un
/// `OnboardingViewModel` et rend des chaînes, oui.
///
/// # ET IL VIT À CÔTÉ DU MODÈLE DE VUE, PAS DANS `Shared/`
///
/// `RunUp/Shared` paraît le bon dossier pour « du calcul sans interface », et c'en est un piège :
/// ce dossier est compilé EN ENTIER dans l'extension de widgets (voir `project.yml`), qui ne
/// connaît ni `OnboardingViewModel` ni `GoalType`. Un fichier posé là ne casse donc pas l'app —
/// il casse une cible qui n'a rien demandé, avec un « cannot find type in scope » qui ne parle
/// pas de la vraie raison. `Shared/` veut dire « partagé avec la montre et les widgets », pas
/// « sans interface ».
enum PlanRecap {
    /// Au plus cinq pastilles : au-delà, la rangée passe à trois lignes et l'écran cesse d'être
    /// lisible d'un coup d'œil — or c'est tout ce qu'on lui demande.
    static let maximum = 5

    /// Les pastilles, dans l'ordre : ce qui est propre à l'objectif, puis le jour J, puis le
    /// rythme, puis la blessure.
    ///
    /// Cet ordre n'est pas décoratif. Les premières sont celles qui changent d'une personne à
    /// l'autre (« 10 km », « Objectif 47:30 ») ; les dernières sont vraies pour presque tout le
    /// monde. Si le plafond coupe, il coupe par la fin, donc par le moins personnel.
    static func pastilles(_ vm: OnboardingViewModel) -> [String] {
        var out = propresALobjectif(vm)
        if let jourJ = vm.raceDate, vm.goal?.periodiseVersUneDate == true {
            out.append(String(localized: "Jour J · \(jourCourt(jourJ))"))
        }
        out.append(String(localized: "\(vm.runningDays.count) jours / semaine"))
        if let blessure = OnboardingChoices.libelle(vm.injuryArea, dans: OnboardingChoices.blessures),
           vm.injuryArea != OnboardingChoices.aucuneBlessure {
            out.append(String(localized: "On surveille : \(blessure)"))
        }
        return Array(out.prefix(maximum))
    }

    /// La phrase sous les pastilles. Elle dit ce qui se passe MAINTENANT — le programme existe,
    /// la première séance attend — et pas ce que l'app promet de faire un jour.
    static func cloture(_ vm: OnboardingViewModel) -> String {
        let prenom = vm.name.trimmingCharacters(in: .whitespaces)
        guard !prenom.isEmpty else {
            return String(localized: "C'est prêt. Ta première séance t'attend.")
        }
        return String(localized: "C'est prêt, \(prenom). Ta première séance t'attend.")
    }

    // MARK: Par objectif

    /// Chaque objectif répond pour lui-même, et le `switch` est exhaustif sans `default` : c'est
    /// la même règle que partout dans `GoalType` — un dixième objectif ne compilera pas tant
    /// qu'il n'aura pas dit ce qu'il montre ici, au lieu de retomber en silence sur une rangée
    /// qui ne contiendrait que « 4 jours / semaine ».
    private static func propresALobjectif(_ vm: OnboardingViewModel) -> [String] {
        guard let goal = vm.goal else { return [] }
        switch goal {
        case .race:
            return [distance(vm), objectif(vm)].compactMap { $0 }
        case .ultraTrail:
            // Le D+ vient AVANT le chrono, et pour la même raison qu'il figure dans le titre de
            // l'objectif : « 80 km » ne décrit pas une course de montagne, « 80 km · 4 000 m D+ »
            // si. C'est le second nombre qui dit ce qu'on prépare.
            let denivele = vm.raceElevationGainM.map { String(localized: "\($0) m D+") }
            return [distance(vm), denivele, objectif(vm)].compactMap { $0 }
        case .hyrox:
            // Le format est écrit en premier parce qu'il est la réponse à « qu'est-ce que je
            // prépare, au juste ». HYROX est la seule épreuve de la liste dont le nom ne dit pas
            // ce qu'on y fait — et c'est précisément ce que l'écran de l'étape 3 lui promettait.
            let division = vm.hyroxDivision.map { String(localized: "Division \($0.title)") }
            return [String(localized: "8 × 1 km + 8 stations"), division, objectif(vm)].compactMap { $0 }
        case .triathlon:
            // Le niveau de natation est la réponse la plus intime de toute l'inscription — c'est
            // la seule qui demande un aveu. La relire ici, sans commentaire, est la façon de dire
            // qu'elle a servi à dimensionner le plan et pas à juger.
            let format = vm.triathlonFormat.map { "Triathlon \($0.title)" }
            let nage = vm.nageNiveau?.title
            return [format, nage, objectif(vm)].compactMap { $0 }
        case .duathlon:
            let nom = String(localized: "Duathlon")
            let format = vm.duathlonFormat.map { "\(nom) \($0.title)" }
            return [format, String(localized: "Courir · Rouler · Courir"), objectif(vm)].compactMap { $0 }
        case .progress:
            let priorite = OnboardingChoices.libelle(vm.focusArea, dans: OnboardingChoices.priorites)
            let perf = vm.bestRecentPerf.trimmingCharacters(in: .whitespaces)
            return [priorite, perf.isEmpty ? nil : String(localized: "Point de départ : \(perf)")].compactMap { $0 }
        case .restart:
            let recence = OnboardingChoices.libelle(vm.lastRanRecency, dans: OnboardingChoices.recences)
            return [String(localized: "Reprise en douceur"),
                    recence.map { String(localized: "Dernière sortie : \($0.lowercased())") }].compactMap { $0 }
        case .weight:
            return [perteVisee(vm), String(localized: "Course + assiette")].compactMap { $0 }
        case .health:
            let budget = OnboardingChoices.libelle(vm.weeklyTimeBudget, dans: OnboardingChoices.budgetsHebdo)
            let moment = OnboardingChoices.libelle(vm.preferredTimeOfDay, dans: OnboardingChoices.momentsDeLaJournee)
            return [budget.map { String(localized: "\($0) / semaine") }, moment].compactMap { $0 }
        }
    }

    // MARK: Les morceaux partagés

    /// La distance d'une course ou d'un ultra. `nil` plutôt qu'un repli du genre « Ta course » :
    /// une pastille qui ne dit rien vaut moins qu'une pastille absente.
    private static func distance(_ vm: OnboardingViewModel) -> String? {
        guard let distance = vm.distance else { return nil }
        guard distance == .other else { return distance.label }
        let saisie = vm.customDistance.trimmingCharacters(in: .whitespaces)
        return saisie.isEmpty ? nil : saisie
    }

    /// Le chrono visé. La MÊME lecture que `canProceed` : « Mon propre temps » laisse le champ
    /// libre, donc une chaîne vide est une non-réponse et pas un objectif de zéro.
    private static func objectif(_ vm: OnboardingViewModel) -> String? {
        guard let chrono = vm.chrono?.trimmingCharacters(in: .whitespaces), !chrono.isEmpty else { return nil }
        return String(localized: "Objectif \(chrono)")
    }

    /// « -6 kg », et rien du tout si l'écart n'en est pas un.
    ///
    /// Les deux poids sont des champs de TEXTE, donc tout est possible : vides, non numériques,
    /// ou un objectif au-dessus du poids actuel (ce qui est une demande légitime, mais pas une
    /// perte — la pastille se taît plutôt que d'annoncer « -0 kg » ou un nombre négatif).
    private static func perteVisee(_ vm: OnboardingViewModel) -> String? {
        guard let depart = Double(vm.weightNow.replacingOccurrences(of: ",", with: ".")),
              let cible = Double(vm.weightTarget.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let ecart = Int((depart - cible).rounded())
        guard ecart > 0 else { return nil }
        return String(localized: "-\(ecart) kg")
    }

    /// « 16 nov. », dans la langue du téléphone. Le jour et le mois suffisent : un programme
    /// d'inscription ne dépasse pas l'année, et « 16 nov. 2026 » sur une pastille de trois mots
    /// coûte une ligne de plus à la rangée entière.
    private static func jourCourt(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(Locale.current))
    }
}
