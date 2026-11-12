import Foundation

/// Les objectifs de l'inscription, dans l'ordre où l'étape 2 les affiche.
///
/// Six à l'origine, puis HYROX, puis l'ultra-trail, puis le triathlon — et le commentaire a
/// annoncé « six » pendant deux ajouts, en renvoyant à une section du README qui n'existe plus.
/// Il ne compte donc plus : la liste qui fait foi est celle de `GoalStepView`, qui lit `allCases`
/// filtré par `estProposable`, et l'ordre de déclaration ci-dessous EST l'ordre à l'écran.
enum GoalType: String, Codable, CaseIterable, Identifiable {
    case race, progress, restart, weight, health, hyrox, ultraTrail, triathlon, duathlon

    var id: String { rawValue }

    /// `String(localized:)` et non un littéral nu : ces libellés sont composés au niveau du
    /// MODÈLE, donc rendus comme de simples `String` que SwiftUI ne localise pas tout seul —
    /// contrairement à un `Text("…")` écrit dans une vue. Ils apparaissent sur l'onboarding, le
    /// profil, l'écran objectif et le plan : c'est le libellé le plus vu de l'app.
    var title: String {
        switch self {
        case .race: return String(localized: "Préparer une course")
        case .progress: return String(localized: "Progresser")
        case .restart: return String(localized: "(Re)commencer")
        case .weight: return String(localized: "Perdre du poids")
        case .health: return String(localized: "Rester en forme")
        case .hyrox: return String(localized: "Préparer un HYROX")
        case .ultraTrail: return String(localized: "Préparer un ultra-trail")
        case .triathlon: return String(localized: "Préparer un triathlon")
        case .duathlon: return String(localized: "Préparer un duathlon")
        }
    }

    var subtitle: String {
        switch self {
        case .race: return String(localized: "Un dossard en vue — on construit le plan pour le jour J")
        case .progress: return String(localized: "Courir plus vite ou plus longtemps, sans course précise")
        case .restart: return String(localized: "Reprendre en douceur, sans se blesser")
        case .weight: return String(localized: "Un programme qui allie course et rééquilibrage alimentaire")
        case .health: return String(localized: "Une routine régulière qui tient dans ta semaine")
        case .hyrox: return String(localized: "8 × 1 km de course + stations fonctionnelles — un vrai plan hybride")
        case .ultraTrail: return String(localized: "Dénivelé, descente technique et sorties enchaînées — un plan qui compte en heures")
        case .triathlon: return String(localized: "Nager, rouler, courir — et surtout enchaîner les trois")
        case .duathlon: return String(localized: "Courir, rouler, courir — et tenir la seconde course")
        }
    }

    /// Cet objectif est-il proposable à l'inscription ?
    ///
    /// LE ROBINET D'UN OBJECTIF LIVRÉ EN PLUSIEURS MORCEAUX. L'ultra-trail est arrivé en cinq
    /// temps — le modèle d'effort, l'objectif et ses questions, les onze séances, les garde-fous,
    /// le jour J. Entre le deuxième et le quatrième, le choisir aurait donné un plan de ROUTE
    /// dimensionné en kilomètres plats : exactement le défaut que tout ce travail existe pour
    /// corriger, servi sous le nom qui promet le contraire. Mieux vaut un objectif absent qu'un
    /// objectif qui ment, donc il était retenu ici.
    ///
    /// LE TRIATHLON EST OUVERT, ET VOICI CE QUI DEVAIT ÊTRE VRAI AVANT.
    ///
    /// Il est arrivé en six temps, et il est resté retenu ici pendant cinq d'entre eux : la
    /// natation comme discipline, l'import depuis la montre, la saisie à la main, l'objectif et
    /// ses quatre formats, les séances. Le choisir avant la cinquième aurait donné un plan de
    /// COURSE portant le nom « triathlon » — aucune natation, aucun vélo, aucune transition, et
    /// trois quarts de la préparation absents sans qu'une seule ligne ne le signale.
    ///
    /// Il s'ouvre maintenant parce que les deux surfaces qui le proposent savent demander son
    /// format ET le niveau de natation : l'inscription et l'assistant de nouvel objectif. La
    /// seconde était le piège — elle lit cette propriété exactement comme la première, donc
    /// ouvrir l'objectif l'y faisait apparaître sans ses deux questions. Un test le réclamait,
    /// et c'est en le faisant échouer qu'on a su qu'il fallait reprendre l'assistant.
    ///
    /// Le robinet reste. C'est par lui que passera le prochain objectif construit par morceaux,
    /// et une liste qui se filtre dit à qui la lit qu'un objectif peut exister dans le modèle
    /// sans être encore offert.
    var estProposable: Bool {
        switch self {
        // LE DUATHLON EST REFERMÉ, ET CE N'EST PAS PARCE QU'IL EST INCOMPLET.
        //
        // Il est arrivé en six lots — le modèle des quatre formats, l'objectif, le format qui
        // voyage jusqu'en base, l'écran d'inscription, les séances d'enchaînement, l'étape de
        // l'assistant de nouvel objectif — et les six sont là. `DuathlonTests`,
        // `DuathlonWeekTests` et `DuathlonRaceDayTests` continuent de le vérifier : rien n'est
        // démonté, et le rouvrir est ce seul `case` à déplacer.
        //
        // Il est retiré de la LISTE parce que les huit vidéos qui vendent l'app n'en montrent
        // aucune trace : elles présentent sept objectifs, et le duathlon n'en fait pas partie.
        // Proposer dans l'app un objectif que rien ne prépare au-dehors, c'est le proposer à
        // quelqu'un qui ne l'a pas cherché — et c'est le format le plus exigeant des neuf.
        //
        // CE QUE ÇA NE FAIT PAS : refermer le plan de qui l'a déjà choisi. Cette propriété ne
        // filtre que les deux écrans qui PROPOSENT un objectif (l'inscription, l'assistant de
        // nouvel objectif). Un profil dont `goalId` vaut déjà `duathlon` garde son plan, ses
        // séances d'enchaînement et sa date de course, exactement comme avant.
        case .duathlon:
            return false
        case .race, .progress, .restart, .weight, .health, .hyrox, .ultraTrail, .triathlon:
            return true
        }
    }

    /// Cet objectif se périodise-t-il vers une DATE ?
    ///
    /// # CE QUE CETTE PROPRIÉTÉ RÉPARE
    ///
    /// La liste était écrite en dur au milieu de `ProgramShape.compute` : `goal == .race ||
    /// goal == .hyrox`. L'ultra-trail n'y figurait pas, donc son plan tombait dans la branche
    /// « programme ouvert » : zéro semaine de base, zéro de spécifique, zéro d'affûtage, et un
    /// cycle base/décharge qui tourne indéfiniment.
    ///
    /// Autrement dit : les onze séances d'ultra existaient, le moteur savait les produire, et il
    /// n'en servait jamais que deux blocs sur quatre — parce que personne ne lui avait dit que cet
    /// objectif avait une ligne d'arrivée. Pas de bloc spécifique, donc aucune sortie longue
    /// spécifique, aucun enchaînement du week-end, aucune sortie de nuit, aucun affûtage. Un plan
    /// d'ultra sans affûtage, c'est une course qu'on aborde fatiguée.
    ///
    /// La liste vit désormais sur le type, pour que l'oubli ne puisse plus se répéter en silence :
    /// ajouter un objectif à date force à répondre ici.
    var periodiseVersUneDate: Bool {
        switch self {
        // Le triathlon a une date, et il en a plus besoin que les autres : l'affûtage d'une
        // épreuve à trois disciplines ne consiste pas à réduire un volume mais trois, et
        // l'enchaînement vélo→course est la dernière chose à relâcher.
        case .race, .hyrox, .ultraTrail, .triathlon, .duathlon: return true
        case .progress, .restart, .weight, .health: return false
        }
    }

    // MARK: L'étape qui suit le choix

    /// # UNE FOIS L'OBJECTIF CHOISI, L'ÉTAPE SUIVANTE LUI APPARTIENT
    ///
    /// Trois objectifs avaient déjà leur écran, avec leur surtitre, leur question et leur
    /// promesse : la course, HYROX, le triathlon. Les QUATRE AUTRES partageaient un seul écran
    /// générique — même surtitre « Étape 3 · sur mesure », même sous-titre « Plus on en sait,
    /// plus le plan colle à ta réalité », pour quatre objectifs qui n'ont rien à voir.
    ///
    /// Ce n'est pas un détail d'habillage. L'étape 3 est la première chose qu'on voit APRÈS
    /// avoir dit ce qu'on veut, et c'est elle qui répond « j'ai compris ». Un écran qui dit
    /// « sur mesure » à quelqu'un qui vient de choisir « reprendre en douceur » dit exactement
    /// le contraire de ce que la phrase promet.
    ///
    /// Les trois propriétés vivent ici plutôt que dans les quatre vues, pour la même raison que
    /// tout le reste de ce fichier : un objectif de plus ne compilera pas tant qu'il n'aura pas
    /// répondu, au lieu de retomber en silence sur le texte générique de quelqu'un d'autre.
    var etapeEyebrow: String {
        switch self {
        case .race: return String(localized: "Étape 3 · ta course")
        case .progress: return String(localized: "Étape 3 · ta priorité")
        case .restart: return String(localized: "Étape 3 · ta dernière sortie")
        case .weight: return String(localized: "Étape 3 · ton point de départ")
        case .health: return String(localized: "Étape 3 · ton temps")
        case .hyrox: return String(localized: "Étape 3 · ton HYROX")
        case .ultraTrail: return String(localized: "Étape 3 · ton ultra")
        case .triathlon: return String(localized: "Étape 3 · ton triathlon")
        case .duathlon: return String(localized: "Étape 3 · ton duathlon")
        }
    }

    var etapeTitre: String {
        switch self {
        case .race: return String(localized: "QUELLE COURSE ?")
        case .progress: return String(localized: "TU VEUX QUOI, AU JUSTE ?")
        case .restart: return String(localized: "TA DERNIÈRE SORTIE")
        case .weight: return String(localized: "TON POINT DE DÉPART")
        case .health: return String(localized: "COMBIEN DE TEMPS ?")
        case .hyrox: return String(localized: "QUEL HYROX ?")
        case .ultraTrail: return String(localized: "QUEL ULTRA ?")
        case .triathlon: return String(localized: "QUEL TRIATHLON ?")
        case .duathlon: return String(localized: "QUEL DUATHLON ?")
        }
    }

    /// LA PROMESSE, ET PAS UNE DESCRIPTION.
    ///
    /// Chacune dit ce que le plan FERA de la réponse qu'on s'apprête à donner, et pourquoi la
    /// question est posée. « Plus on en sait, plus le plan colle à ta réalité » ne disait rien
    /// de tel : c'était vrai de n'importe quelle question de n'importe quelle app.
    ///
    /// Les quatre nouvelles sont écrites sur le même patron que les trois qui existaient — une
    /// affirmation, puis sa conséquence. « Le plan part d'aujourd'hui. Pas d'où tu étais avant »
    /// répond à l'inquiétude exacte de quelqu'un qui reprend après un an.
    var etapePromesse: String {
        switch self {
        case .race:
            return String(localized: "Route, trail, obstacle… précise ce que tu prépares.")
        case .progress:
            return String(localized: "Pas de dossard en vue ? Tu n'en as pas besoin pour progresser.")
        case .restart:
            return String(localized: "Le plan part d'aujourd'hui, pas d'où tu étais avant.")
        case .weight:
            return String(localized: "La course et l'assiette, dans un seul plan.")
        case .health:
            return String(localized: "Le plan se cale sur ton agenda. Pas l'inverse.")
        case .hyrox:
            return String(localized: "8 × 1 km de course, 8 stations fonctionnelles — le format ne change pas, ta préparation si.")
        case .ultraTrail:
            return String(localized: "La distance ET le dénivelé — c'est le second qui décide du plan.")
        case .triathlon:
            return Accord.selon(
                f: String(localized: "Nager, rouler, courir — dans cet ordre, et fatiguée de la précédente à chaque fois."),
                m: String(localized: "Nager, rouler, courir — dans cet ordre, et fatigué de la précédente à chaque fois."))
        case .duathlon:
            return String(localized: "Courir, rouler, courir — et c'est la seconde course qui décide de la journée.")
        }
    }

    /// LE NOMBRE MINIMAL DE JOURS PAR SEMAINE QUE CET OBJECTIF EXIGE.
    ///
    /// Deux pour tout ce qui se court : c'est peu, et c'est assumé — quelqu'un qui ne peut donner
    /// que deux séances mérite un plan plutôt qu'un refus.
    ///
    /// TROIS POUR LE TRIATHLON, et ce n'est pas une préférence. Une semaine à deux jours ne peut
    /// pas contenir trois disciplines : il en manquerait forcément une, et ce serait la natation
    /// — celle qui arrive en dernier dans l'ordre de priorité des séances, et celle dont
    /// l'absence ne se verrait nulle part puisque l'app ne la mesure pas. Un plan de triathlon
    /// sans natation porterait le nom du format et n'en préparerait que deux tiers.
    ///
    /// Ce nombre vivait en littéral dans QUATRE endroits — l'inscription, l'écran des jours,
    /// l'assistant de nouvel objectif et les réglages du programme. Il ne pouvait donc pas
    /// dépendre de l'objectif, et la question ne s'était jamais posée. Elle se pose ici.
    var joursMinimumParSemaine: Int {
        switch self {
        case .race, .progress, .restart, .weight, .health, .hyrox, .ultraTrail: return 2
        case .triathlon: return 3
        // DEUX POUR LE DUATHLON, ET PAS TROIS COMME LE TRIATHLON. La raison du trois était la
        // natation : une semaine à deux jours ne peut pas contenir trois disciplines, et c'est
        // toujours la nage qui saute — celle que l'app ne mesure pas, donc dont l'absence ne se
        // voit nulle part. Ici il n'y a que deux disciplines, et l'enchaînement vélo→course les
        // porte TOUTES LES DEUX dans une seule séance. Une semaine à deux jours tient donc un
        // vrai duathlon : une séance de qualité à pied, un enchaînement. Rien ne disparaît en
        // silence, et l'app voit les deux.
        case .duathlon: return 2
        }
    }

    /// Recovery length (days) once a 9-week program built for this goal ends. See README § 14.
    var recoveryDays: Int {
        switch self {
        case .race: return 6
        case .weight: return 3
        case .progress: return 4
        case .restart: return 5
        case .health: return 3
        case .hyrox: return 6
        // Sept jours : c'est l'épreuve qui laisse les traces les plus longues de la liste.
        // Un ultra ne se récupère pas en quatre jours, et proposer de repartir trop tôt est
        // le meilleur moyen de transformer une belle course en blessure.
        case .ultraTrail: return 7
        // Six jours, comme une course sur route — mais pour une raison différente : ce n'est pas
        // la distance qui laisse des traces, c'est d'avoir tenu trois disciplines dans la même
        // journée. Un format long tire plus que ça ; c'est le plan de la préparation suivante
        // qui s'en charge, pas ce compteur-là.
        case .triathlon: return 6
        // Cinq jours : moins qu'un triathlon, parce que la journée est plus courte et qu'il y
        // manque une discipline. Mais pas trois non plus — deux courses sur des jambes déjà
        // chargées laissent aux cuisses ce qu'une seule ne laisse pas.
        case .duathlon: return 5
        }
    }
}

/// La division HYROX dans laquelle on court.
///
/// # QUATRE, PAS DEUX, ET C'EST LE RÈGLEMENT QUI LE DIT
///
/// L'app en proposait deux, Open et Pro. Le règlement officiel est explicite : « HYROX offers four
/// divisions. The divisions differ in gender and/or weight. » Les quatre sont WOMEN, WOMEN PRO, MEN
/// et MEN PRO — et c'est le genre, autant que le niveau, qui décide des charges. Men Open et Women
/// Pro portent d'ailleurs exactement les mêmes.
///
/// Deux cartes au lieu de quatre n'était donc pas une simplification : c'était l'impossibilité de
/// savoir quelles charges une coureuse allait affronter. Le plan ne pouvait prescrire ni un sled de
/// 102 kg ni un sled de 202 kg, donc il ne prescrivait rien — il disait « charge standard ».
///
/// # CE QUE CETTE QUESTION N'EST PAS
///
/// Elle ne demande pas un genre comme donnée de santé. Elle demande dans quelle CATÉGORIE on s'est
/// inscrit, ce que l'écran demandait déjà — et une seule réponse remplace deux questions. Rien
/// d'autre dans l'app ne lit cette valeur, et elle ne sert qu'à nommer les charges du règlement.
///
/// Source : HYROX Single Rulebook, saison 26/27, section 4.1. Voir `ChargesHyrox`, qui porte le
/// tableau et sa date.
enum HyroxDivision: String, Codable, CaseIterable, Identifiable {
    case femmes = "women"
    case femmesPro = "women_pro"
    case hommes = "men"
    case hommesPro = "men_pro"

    // LES DEUX DIVISIONS D'AVANT, GARDÉES POUR POUVOIR RELIRE UN PROFIL DÉJÀ ENREGISTRÉ.
    //
    // Elles ne sont pas proposées (voir `proposees`) et elles n'ont pas de charges : « Open » ne
    // dit pas si la coureuse affronte 102 ou 152 kg, et l'inventer serait pire que se taire. Un
    // profil qui les porte garde donc le plan qu'il avait, sans kilos annoncés, jusqu'à ce que sa
    // division soit rechoisie.
    case open
    case pro

    var id: String { rawValue }

    /// Les divisions proposées à l'inscription : les quatre du règlement, et pas les héritées.
    static let proposees: [HyroxDivision] = [.femmes, .femmesPro, .hommes, .hommesPro]

    var title: String {
        switch self {
        case .femmes: return String(localized: "Femmes")
        case .femmesPro: return String(localized: "Femmes Pro")
        case .hommes: return String(localized: "Hommes")
        case .hommesPro: return String(localized: "Hommes Pro")
        case .open: return "Open"
        case .pro: return "Pro"
        }
    }

    /// Les charges sont-elles celles d'une division Pro ?
    ///
    /// Le moteur testait `division == .pro`, ce qui ne pouvait pas survivre au passage à quatre
    /// divisions : `.femmesPro` et `.hommesPro` sont Pro toutes les deux, et aucune n'est `.pro`.
    /// La question se pose donc ici une fois, au lieu d'un test d'égalité recopié.
    var estPro: Bool {
        switch self {
        case .femmesPro, .hommesPro, .pro: return true
        case .femmes, .hommes, .open: return false
        }
    }

    /// Les charges du règlement pour cette division, ou `nil` quand on ne les connaît pas.
    ///
    /// # DEUX DÉCOUPAGES QUI NE SE SUPERPOSENT PAS
    ///
    /// Les POIDS groupent Hommes avec Femmes Pro — c'est ainsi que le tableau du règlement est
    /// écrit, ce n'est pas un raccourci de code. Mais la HAUTEUR DE CIBLE des wall balls groupe
    /// autrement, Femmes avec Femmes Pro à 2,70 m et Hommes avec Hommes Pro à 3,00 m.
    ///
    /// Les quatre divisions ont donc quatre valeurs distinctes, et les deux colonnes de poids
    /// identiques sont écrites deux fois exprès : les factoriser reviendrait à affirmer que ces
    /// deux divisions s'entraînent pareil, ce qui est faux de trente centimètres, cent fois.
    /// `ChargesHyroxTests` tient l'égalité des poids pour que la duplication ne dérive pas.
    var charges: ChargesHyrox? {
        switch self {
        case .femmes:
            return ChargesHyrox(sledPushKg: 102, sledPullKg: 78, kettlebellKg: 16,
                                sandbagKg: 10, wallBallKg: 4, wallBallCibleM: 2.70)
        case .femmesPro:
            return ChargesHyrox(sledPushKg: 152, sledPullKg: 103, kettlebellKg: 24,
                                sandbagKg: 20, wallBallKg: 6, wallBallCibleM: 2.70)
        case .hommes:
            return ChargesHyrox(sledPushKg: 152, sledPullKg: 103, kettlebellKg: 24,
                                sandbagKg: 20, wallBallKg: 6, wallBallCibleM: 3.00)
        case .hommesPro:
            return ChargesHyrox(sledPushKg: 202, sledPullKg: 153, kettlebellKg: 32,
                                sandbagKg: 30, wallBallKg: 9, wallBallCibleM: 3.00)
        case .open, .pro:
            return nil
        }
    }

    /// Ce que la carte annonce sous le nom de la division : deux charges concrètes.
    ///
    /// Le sled et les wall balls plutôt qu'une phrase : ce sont la charge la plus lourde de
    /// l'épreuve et celle qu'on soulève cent fois, et deux nombres distinguent les quatre
    /// divisions mieux que « pour un niveau confirmé ». L'ancien sous-titre d'Open disait « le
    /// format le plus couru », une affirmation sur la participation que rien ne sourçait.
    var subtitle: String {
        guard let c = charges else {
            return String(localized: "Division d'une version précédente — à rechoisir")
        }
        return String(localized: "Sled \(c.sledPushKg) kg · wall balls \(c.wallBallKg) kg")
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case debutante, intermediaire, confirmee

    var id: String { rawValue }

    /// « Intermédiaire » est épicène, les deux autres non — et ces trois mots sont une carte
    /// qu'on touche pour se décrire. Se voir proposer « Débutante » quand on a répondu « Homme »
    /// à la question d'avant est la forme la plus directe de « cette app ne t'a pas écouté ».
    var title: String {
        switch self {
        case .debutante:
            return Accord.selon(f: String(localized: "Débutante"), m: String(localized: "Débutant"))
        case .intermediaire:
            return String(localized: "Intermédiaire")
        case .confirmee:
            return Accord.selon(f: String(localized: "Confirmée"), m: String(localized: "Confirmé"))
        }
    }

    var subtitle: String {
        switch self {
        case .debutante: return String(localized: "Je cours depuis moins de 6 mois")
        case .intermediaire: return String(localized: "Je cours 2-3 fois par semaine")
        case .confirmee: return String(localized: "Je m'entraîne sérieusement depuis des années")
        }
    }

    /// LA TRANCHE DE FOOTING QU'ELLE AURAIT PROBABLEMENT COCHÉE — et rien de plus.
    ///
    /// # CE QUI ÉTAIT FAUX
    ///
    /// `PaceModel` portait trois VDOT écrits en dur — 36,34 / 43,61 / 53,94 — hérités de trois
    /// allures de seuil littérales (5:30, 4:45, 4:00 au kilomètre). Converties à la fraction du
    /// footing, elles supposent des footings de **6:54, 5:58 et 5:02 au kilomètre**.
    ///
    /// Or l'app propose elle-même quatre tranches de footing, dont la plus lente est « plus de
    /// 7 min/km ». Donc quelqu'un qui se déclarait **débutante** et répondait « je ne sais pas »
    /// à la question de l'allure recevait un plan calé sur 6:54 — **plus rapide** que s'il avait
    /// coché la tranche la plus lente. Une non-réponse était plus optimiste que la réponse la
    /// plus prudente, ce qui n'a aucun sens : c'est exactement au niveau « débutante » que
    /// vivent les gens qui courent à plus de 7 min/km.
    ///
    /// # LA MESURE, ET CE QU'ELLE N'EST PAS
    ///
    /// Ce n'est pas une mesure de ce que courent les gens — personne n'a ces données ici, et
    /// l'ancien commentaire le disait déjà. C'est une mesure d'**incohérence interne**, et elle
    /// se vérifie : deux chemins d'entrée répondent à la même question, et l'un d'eux sortait de
    /// l'échelle de l'autre.
    ///
    /// Les trois niveaux prennent donc les trois tranches les plus lentes, dans l'ordre. La
    /// quatrième — « moins de 5 min/km » — ne s'atteint que si elle la coche : un libellé qu'on
    /// touche pour se décrire ne doit pas suffire à produire un footing sous les 5 minutes.
    ///
    /// | niveau | tranche supposée | 5 km équivalent | avant |
    /// | --- | --- | --- | --- |
    /// | débutante | 7:30/km | 28:35 | 26:08 |
    /// | intermédiaire | 6:30/km | 24:29 | 22:23 |
    /// | confirmée | 5:30/km | 20:28 | 18:40 |
    ///
    /// # POURQUOI UNE TRANCHE ET PAS UN NOMBRE
    ///
    /// Les deux chemins passent maintenant par le même `Vdot.depuisAllure(…, fraction: .footing)`
    /// sur la même valeur, donc ils ne peuvent plus diverger. Trois nombres en dur, c'est trois
    /// occasions de corriger un chemin et pas l'autre — c'est déjà arrivé sur ce calcul, avec le
    /// `/ 1.20` qui se trompait des deux côtés à la fois et dans des sens opposés.
    var allureDeFootingSupposee: AllureFooting {
        switch self {
        case .debutante: return .plusDe7
        case .intermediaire: return .de6a7
        case .confirmee: return .de5a6
        }
    }
}

enum RaceDistance: String, Codable, CaseIterable, Identifiable {
    case k5, k10, semi, marathon, other
    // Les quatre formats d'ultra. Séparés des distances de route et JAMAIS mélangés à l'écran :
    // proposer « 5 km » à quelqu'un qui prépare un 100 miles, ou « 100 km » à quelqu'un qui
    // prépare son premier 10, c'est faire relire toute la grille pour rien.
    case ultra50, ultra80, ultra100, ultra100M

    var id: String { rawValue }

    var label: String {
        switch self {
        case .k5: return "5 km"
        case .k10: return "10 km"
        case .semi: return String(localized: "Semi")
        case .marathon: return String(localized: "Marathon")
        case .other: return String(localized: "Autre distance")
        case .ultra50: return "50 km"
        case .ultra80: return "80 km"
        case .ultra100: return "100 km"
        case .ultra100M: return "100 miles"
        }
    }

    /// Les distances à proposer pour un objectif donné.
    ///
    /// `allCases` ne convient plus depuis qu'il y a des formats d'ultra : la grille montrerait
    /// « 5 km » à quelqu'un qui prépare un 100 miles. Deux listes, chacune complète pour son
    /// monde, et « Autre distance » dans les deux — c'est par là que passent l'Ekiden, le trail
    /// de 22 km et le 110 km qui n'est dans aucune liste.
    static func choix(pour objectif: GoalType?) -> [RaceDistance] {
        objectif == .ultraTrail
            ? [.ultra50, .ultra80, .ultra100, .ultra100M, .other]
            : [.k5, .k10, .semi, .marathon, .other]
    }

    var chronoPresets: [String] {
        switch self {
        case .k5: return ["20:00", "22:30", "25:00", "28:00"]
        case .k10: return ["42:00", "47:30", "52:00", "58:00"]
        case .semi: return ["1:40", "1:50", "2:00", "2:15"]
        case .marathon: return ["3:30", "3:50", "4:15", "4:45"]
        case .other: return []
        // Des temps de FINISSEUR, pas des objectifs de performance : en ultra, la question
        // n'est pas « combien » mais « est-ce que j'arrive au bout ». Les fourchettes sont
        // celles d'un parcours de montagne ordinaire pour chaque format.
        case .ultra50: return ["6:00", "7:30", "9:00", "11:00"]
        case .ultra80: return ["10:00", "12:00", "15:00", "18:00"]
        case .ultra100: return ["13:00", "16:00", "20:00", "24:00"]
        case .ultra100M: return ["24:00", "30:00", "36:00", "44:00"]
        }
    }

    /// nil for `.other` — a bare enum case has no way to hold the number from a free-text custom
    /// distance ("Trail 22 km"). That number still exists on `UserProfile.raceDistanceCustom`
    /// though, so anything scaling pace/periodization to the real race distance should read
    /// `UserProfile.effectiveRaceDistanceKm` instead of this property directly — it falls back to
    /// parsing the custom text rather than silently discarding a real, just-not-preset distance.
    var km: Double? {
        switch self {
        case .k5: return 5
        case .k10: return 10
        case .semi: return 21.0975
        case .marathon: return 42.195
        case .ultra50: return 50
        case .ultra80: return 80
        case .ultra100: return 100
        // 100 miles. La valeur exacte, pas 160 : c'est elle qui alimente le temps d'effort, et
        // un kilomètre d'écart sur un format pareil vaut dix minutes debout.
        case .ultra100M: return 160.934
        case .other: return nil
        }
    }
}

enum ConnectedSource: String, Codable, CaseIterable, Identifiable {
    case apple, strava, garmin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return String(localized: "Apple Santé")
        case .strava: return "Strava"
        case .garmin: return "Garmin Connect"
        }
    }

    var subtitle: String {
        switch self {
        case .apple: return String(localized: "FC, sommeil, course")
        case .strava: return String(localized: "Historique & segments")
        case .garmin: return String(localized: "Montre & données avancées")
        }
    }

    /// Apple Health (HealthKit) and Strava (real OAuth, see `StravaService`) both have a real
    /// integration; Garmin is still a UI stub.
    var isNativelySupported: Bool { self == .apple || self == .strava }
}

enum ProgramPhase: String, Codable {
    case active, recovery, choice, freerun
}

enum RPE: Int, Codable, CaseIterable, Identifiable {
    case tropDur, dur, justeBien, facile

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .tropDur: return String(localized: "Trop dur")
        case .dur: return String(localized: "Dur")
        case .justeBien: return String(localized: "Juste bien")
        case .facile: return String(localized: "Facile")
        }
    }
}
