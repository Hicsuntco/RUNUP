import SwiftUI

/// Floating frosted-glass tab bar with a raised center "Run" button. See README § Global Chrome.
struct TabBarView: View {
    var selected: AppScreen
    var onSelect: (AppScreen) -> Void
    var onStartRun: () -> Void
    /// La discipline que le bouton lancera. Il la PORTE à l'écran, et c'est ce qui reste de la
    /// bascule d'origine : le libellé dit « TRAIL », donc on sait ce qui part sans rien ouvrir.
    var discipline: Discipline = .run
    /// Le cadran est-il ouvert ? LU, jamais écrit ici.
    ///
    /// L'état vit dans `RootTabView`, qui dessine le cadran. Le garder aussi ici en donnerait deux
    /// copies, et deux copies d'un même booléen divergent toujours par le même chemin : un appui
    /// à côté referme le cadran chez l'un et pas chez l'autre, et le geste suivant part dans la
    /// mauvaise branche sans que rien ne l'explique.
    var dialOpen: Bool = false
    /// L'appui long a duré : il faut ouvrir le cadran.
    var onOpenDial: () -> Void = {}
    /// Le doigt bouge, cadran ouvert. Le déplacement est compté depuis le centre du bouton, ce qui
    /// est précisément le repère de la géométrie de `DisciplineDial`.
    var onDialDrag: (CGSize) -> Void = { _ in }
    /// Le doigt se lève. C'est le moment où l'on choisit — ou pas.
    var onDialEnd: (CGSize) -> Void = { _ in }
    /// Faux pendant une course : on ne change pas de discipline au milieu d'une sortie. Un
    /// booléen séparé plutôt qu'une closure optionnelle — un ternaire qui rend `nil` ou une
    /// fermeture est une inférence que Swift refuse selon le contexte, et ce n'est pas le genre
    /// de risque à prendre quand chaque compilation coûte un quart d'heure.
    var canChooseDiscipline: Bool = true

    /// QUATRE ONGLETS AUTOUR DU BOUTON, ET LA RÈGLE QUI DÉCIDE LESQUELS.
    ///
    /// Un onglet est pour une DESTINATION QUE RIEN D'AUTRE N'OUVRE. C'est cette règle qui avait
    /// sorti le Club de la barre : depuis que le Profil est un hub social, l'onglet Club menait
    /// au même couple d'écrans par un second chemin — deux hubs vers deux écrans identiques.
    ///
    /// # LE FIL A PRIS LA PLACE DE STATS PENDANT UN BUILD, ET LA RAISON ÉTAIT FAUSSE
    ///
    /// L'argument était : « Stats a sa propre carte sur l'accueil, avec ses quatre chiffres
    /// dessus ; une carte qui porte déjà ce qu'elle ouvre est un meilleur chemin qu'un onglet. »
    /// La carte existe bien. Mais personne n'avait regardé où elle TOMBE une fois rendue :
    ///
    ///   • c'est le 4e bloc de l'accueil, après la séance du jour, l'anneau et la semaine — soit
    ///     environ deux écrans et demi de défilement ;
    ///   • et elle est posée sous `if trenteJours.count > 0`, donc elle DISPARAÎT quand le mois
    ///     est creux. Un mois sans sortie, et il n'existait plus aucun accès aux statistiques
    ///     dans toute l'app : les trois autres `go(.stats)` du code sont des boutons RETOUR,
    ///     depuis des écrans qu'on n'atteint que par les Stats.
    ///
    /// Un chemin unique, sous la ligne de flottaison et escamotable, n'est pas « un meilleur
    /// chemin qu'un onglet ». La règle n'était pas en cause — la mesure l'était.
    ///
    /// # LE FIL, LUI, RESTE UN ÉCRAN À PART ENTIÈRE
    ///
    /// Il ne redevient PAS un mode du hub social : `AppScreen.fil` existe toujours, avec son
    /// propre en-tête et son état déconnectée. Il s'ouvre par sa carte en tête de la section
    /// Communauté du Profil, et le Profil reste allumé pendant qu'on y est (voir
    /// `RootTabView.tabSelection`), exactement comme pour le Club.
    private let items: [(AppScreen, String, String)] = [
        (.home, "Prog", "list.bullet"),
        (.coach, "Coach", "bubble.left.and.bubble.right"),
        (.stats, "Stats", "chart.bar"),
        (.profile, "Profil", "person.crop.circle")
    ]

    var body: some View {
        // UNE SEULE DÉCISION POUR TOUTE LA BARRE, ET PAS CINQ.
        //
        // # CE QU'ON VOYAIT
        //
        // Le libellé de l'onglet SÉLECTIONNÉ disparaissait — « Stats » sur l'écran Stats,
        // « Profil » sur le profil — pendant que les quatre autres gardaient le leur. Une barre
        // dépareillée, et qui se dépareillait différemment à chaque navigation.
        //
        // # POURQUOI
        //
        // Chaque onglet portait son propre `ViewThatFits`, donc décidait POUR LUI SEUL s'il avait
        // la place d'afficher son mot. Deux choses rendent cette décision différente d'un onglet
        // à l'autre, et je les avais toutes les deux manquées :
        //
        //   • les symboles SF n'ont pas la même hauteur à taille de police égale —
        //     `person.crop.circle` et `chart.bar` remplissent leur cadre, `list.bullet` non ;
        //   • l'icône de l'onglet actif est en `.semibold`, les autres en `.regular`, et le gras
        //     la fait grandir de la fraction de point qui manquait.
        //
        // D'où un défaut qui ne frappe QUE l'onglet où l'on se trouve, et seulement pour certains
        // symboles : la pire forme possible, puisqu'elle ressemble à un bug d'affichage aléatoire.
        //
        // # LA RÈGLE MAINTENANT
        //
        // La barre entière est la candidate, en trois états : tout le monde a son mot, puis le
        // bouton RUN cède le sien (le rond et son triangle disent déjà « ça démarre »), puis plus
        // personne. Un `ViewThatFits` POSÉ ICI ne peut rendre qu'un seul de ces trois états, donc
        // la barre ne peut plus être dépareillée — quelle que soit la taille du texte, quel que
        // soit l'onglet actif, quels que soient les symboles choisis demain.
        ViewThatFits(in: .vertical) {
            barre(libelles: true, libelleRun: true)
            barre(libelles: true, libelleRun: false)
            barre(libelles: false, libelleRun: false)
        }
        .padding(.horizontal, 6)
        .frame(height: RUSpacing.tabBarHeight)
        // `in: Capsule()` sur chaque fond, et SURTOUT plus de `.clipShape(Capsule())` en aval.
        //
        // Le bouton RUN est censé DÉPASSER de la barre — c'est tout son principe. Un `clipShape`
        // posé sur la pile entière rognait donc précisément ce qui devait dépasser, et le rond
        // apparaissait coupé net par le haut. Le défaut était masqué tant que le bouton mesurait
        // exactement la hauteur de la barre ; agrandir les libellés d'onglet l'a rendu visible.
        //
        // Un fond dessiné DANS une forme habille la barre sans toucher au contenu.
        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
        // La barre FLOTTE au-dessus du contenu, donc elle doit se lire comme une surface
        // surélevée — c'est-à-dire `card`, comme toutes les autres surfaces surélevées depuis
        // l'inversion du thème clair. Elle était figée à #EDEDF4, soit la couleur de la page en
        // un peu plus foncé : une barre censée être posée au-dessus se lisait comme un trou.
        .background(RUColor.card.opacity(RUColor.isLight ? 0.92 : 0.72), in: Capsule())
        .overlay(Capsule().stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        // Et la barre elle-même arrête les touches, y compris dans les marges au-dessus et en
        // dessous des libellés : elle est posée SUR le contenu, elle doit se comporter comme
        // telle. Un fond dessiné `in: Capsule()` habille sans rien intercepter.
        .contentShape(Capsule())
        // Une barre flottante a droit à plus d'élévation qu'une carte — mais pas à quatre fois
        // plus. C'était 30 % d'encre là où les cartes sont passées à 4 et 8 %, reliquat de
        // l'ancien langage d'ombre que le portage de la maquette a justement corrigé ailleurs.
        .shadow(color: .black.opacity(RUColor.isLight ? 0.10 : 0.5), radius: 18, x: 0, y: 8)
    }

    /// Les cinq éléments, dans un état donné. Les trois appels de `body` en sont les trois
    /// candidats, et c'est `ViewThatFits` qui en retient un — jamais un mélange.
    private func barre(libelles: Bool, libelleRun: Bool) -> some View {
        // ALIGNÉ SUR LE BAS, ET C'EST CE QUI MET LES LIBELLÉS SUR UNE MÊME LIGNE.
        //
        // Les cinq éléments n'ont pas la même hauteur, et ne peuvent pas l'avoir : un onglet
        // empile un point de sélection (4), une icône et son mot ; le bouton RUN empile un rond
        // de 40 et le sien. Centrés chacun pour soi dans la même barre de 56, leurs mots ne
        // peuvent tomber à la même hauteur que si l'icône mesurait exactement 29 points. Elle en
        // mesure ~21 : « RUN » se posait donc ~4 points plus bas que « Prog », « Coach »,
        // « Stats » et « Profil ». Un écart petit, visible sur tous les écrans, et garanti par la
        // géométrie plutôt que par un accident.
        //
        // Aligner par le bas fait tomber les cinq mots sur la même ligne SANS fixer aucune
        // hauteur à la main : le rond, plus grand, monte alors plus haut que les icônes — ce qui
        // est exactement l'effet voulu pour un bouton central surélevé.
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(items[0], libelle: libelles)
            tabButton(items[1], libelle: libelles)
            runButton(libelle: libelleRun)
            tabButton(items[2], libelle: libelles)
            tabButton(items[3], libelle: libelles)
        }
    }

    /// La pile d'un onglet : le point de sélection, l'icône, et le libellé — ou pas.
    private func pileDonglet(icon: String, label: String, color: Color,
                             on: Bool, avecLibelle: Bool) -> some View {
        VStack(spacing: Self.ecartDeLaPile) {
            Circle()
                .fill(RUColor.rose)
                .frame(width: Self.diametreDuPoint, height: Self.diametreDuPoint)
                .opacity(on ? 1 : 0)
                .scaleEffect(on ? 1 : 0.3)
                // Snapped on/off before this — RootTabView already animates the screen swap
                // itself, but the selection dot one layer down didn't match that with its own.
                .animation(.easeOut(duration: 0.2), value: on)
            Image(systemName: icon)
                .font(.system(size: 18, weight: on ? .semibold : .regular))
                .foregroundColor(color)
                // UN CADRE FIXE, ET C'EST LA MOITIÉ DU CORRECTIF.
                //
                // À taille de police égale, deux symboles SF n'occupent pas la même hauteur :
                // `person.crop.circle` remplit son cadre, `list.bullet` est plat. Et le passage
                // de `.regular` à `.semibold` sur l'onglet actif en rajoute une fraction. Sans
                // cadre, la pile de chaque onglet avait donc sa propre hauteur, qui changeait en
                // plus selon l'onglet sélectionné — les icônes ne s'alignaient pas entre elles,
                // et les mots en dessous non plus.
                //
                // 22 points : un symbole de 18 points mesure ~21,5 de haut, donc le cadre le
                // contient sans le laisser déborder — un cadre plus serré que son contenu ne
                // rogne pas (SwiftUI ne coupe rien par défaut), il déborde, ce qui
                // réintroduirait le décalage qu'on retire. C'était 24 ; voir le calcul de
                // hauteur en tête de `runButton`, chaque point compte dans une barre de 56.
                .frame(height: Self.cotesDeLIcone)
            if avecLibelle {
                Text(LocalizedStringKey(label))
                    .font(RUFont.sans(.micro, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func tabButton(_ item: (AppScreen, String, String), libelle: Bool) -> some View {
        let (screen, label, icon) = item
        let on = selected == screen
        // Les onglets inactifs passaient par une valeur codée en dur — noir à 32 % sur des
        // libellés de 8 pt, soit 2,21:1. `text3` a précisément été recalibré pour ce cas, et
        // contourner le jeton revenait à refaire l'erreur qu'il corrige.
        let color = on ? RUColor.rose2 : RUColor.text3
        return Button(action: {
            Haptics.selection()
            onSelect(screen)
        }) {
            // LA BARRE NE GRANDIT PAS, SON CONTENU S'ADAPTE — mais la décision n'est plus
            // prise ici. Sa hauteur est une constante partagée : `RUSpacing.tabBarHeight` sert
            // aussi à calculer l'encart que chaque écran réserve en bas pour ne pas passer
            // dessous, donc une barre qui grandirait avec le texte recouvrirait le contenu.
            // C'est bien le CONTENU qui doit céder — mais tous les onglets ENSEMBLE, sinon la
            // barre se dépareille. Voir `body`.
            //
            // Le libellé rétrécit d'abord jusqu'à 80 %, pas en dessous : sinon on remplace une
            // troncature par une illisibilité. Le nom reste annoncé à VoiceOver dans tous les
            // cas — c'est la forme qui se simplifie, pas l'information.
            pileDonglet(icon: icon, label: label, color: color, on: on, avecLibelle: libelle)
            // `alignment: .bottom`, pour la même raison que la pile : ce cadre ne sert qu'à
            // porter la cible de 44 points, et son alignement par défaut (centré) recentrerait
            // le contenu dans les 44, donc défirait l'alignement par le bas juste au-dessus dès
            // que la pile mesure moins que ça.
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottom)
            // Sans forme de contact, un `Button` dont le libellé est une pile d'un point, d'une
            // icône et d'un mot n'est touchable QUE sur ces trois formes — les creux entre elles
            // ne répondent pas, et le doigt les traverse. Sur l'accueil, ce qui se trouve juste
            // dessous est « Refaire un programme », en pleine largeur : viser Profil déclenchait
            // la remise à zéro du programme. Le reste de l'app pose déjà ce `contentShape`
            // partout ; la seule chrome permanente de l'app était la seule à ne pas l'avoir.
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        // LE NOM EST POSÉ EXPLICITEMENT, ET PLUS SEULEMENT PORTÉ PAR LE LIBELLÉ VISIBLE.
        //
        // Tant que le `Text` était toujours là, l'onglet se nommait tout seul. Il peut désormais
        // disparaître quand le texte est très grand — et un onglet réduit à son icône, sans nom,
        // s'annonce « bouton ». Soit exactement le défaut que `check_a11y.py` traque ailleurs,
        // et qu'il n'aurait PAS vu ici : le `Text` est toujours écrit dans le fichier, il n'est
        // simplement plus toujours rendu.
        .accessibilityLabel(LocalizedStringKey(label))
        // The only persistent navigation chrome in the app, visible on every screen — without
        // this, VoiceOver conveyed the active tab purely through color (the dot + icon/label
        // tint), so a screen-reader user had no way to tell which of Prog/Coach/Stats/Profil was
        // currently selected.
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// La pile du bouton central : le rond, et le libellé de discipline — ou pas. Elle ne décide
    /// pas elle-même : `avecLibelle` descend de `body`, qui tranche pour les cinq éléments à la
    /// fois. Même règle que `pileDonglet`.
    private func pileDuBouton(avecLibelle: Bool) -> some View {
        VStack(spacing: Self.ecartDuBouton) {
            Circle()
                .fill(LinearGradient(colors: [RUColor.rose2, RUColor.rose], startPoint: .top, endPoint: .bottom))
                .frame(width: Self.diametreDuRond, height: Self.diametreDuRond)
                // Le triangle reste, quelle que soit la discipline : il dit « ça démarre »,
                // et c'est la seule chose que ce rond ait jamais eu à dire. C'est le libellé
                // en dessous qui porte le vélo — changer les deux ferait un bouton différent
                // au lieu du même bouton dans un autre mode.
                .overlay(Image(systemName: "play.fill").foregroundColor(RUColor.onRose).font(.system(size: 13)))
                // 0,55 de rose sur 14 points de flou : le bouton RUN ne se posait pas sur
                // la barre, il l'éclairait. Ramené à une ombre qui le décolle sans le faire
                // rayonner — c'est un bouton, pas une lampe.
                .shadow(color: .black.opacity(RUColor.isLight ? 0 : 0.45), radius: 10, x: 0, y: 5)
            if avecLibelle {
                Text(discipline.tabLabel)
                    .font(RUFont.sans(.micro, weight: .bold))
                    .tracking(1)
                    .foregroundColor(RUColor.rose2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
            }
        }
    }

    /// Appuyé. Rend ce que `PressableStyle` rendait, puisque ce contrôle n'est plus un `Button`.
    @State private var runPressed = false

    /// Combien de temps il faut maintenir avant que le cadran ne s'ouvre.
    private static let dureeAppuiLong: Duration = .milliseconds(450)
    /// En dessous, un appui qui se lève est un APPUI et non un glissement avorté. Sans cette
    /// borne, un doigt qui balaie l'écran en passant sur le bouton lancerait une course.
    private static let toleranceDAppui: CGFloat = 12

    /// Un appui est en cours. Sert à reconnaître le PREMIER `onChanged` d'un geste : `DragGesture`
    /// en envoie des dizaines, et seul le premier doit armer le minuteur d'ouverture.
    @State private var appuiEnCours = false
    /// Le minuteur d'ouverture. Annulé si le doigt se lève avant la fin — c'est ce qui distingue
    /// un appui d'un maintien.
    @State private var ouvertureEnCours: Task<Void, Never>?

    /// Arme l'ouverture du cadran. Annulée par `onEnded` si le doigt se lève avant la fin — c'est
    /// toute la différence entre un appui, qui lance une course, et un maintien, qui ouvre le
    /// choix.
    ///
    /// `@MainActor` écrit explicitement : la tâche touche à de l'état de vue et déclenche un
    /// retour haptique, et ni l'un ni l'autre ne se fait depuis un fil quelconque.
    private func armerLOuverture() {
        ouvertureEnCours = Task { @MainActor in
            try? await Task.sleep(for: Self.dureeAppuiLong)
            guard !Task.isCancelled, canChooseDiscipline else { return }
            // Le bouton se détend au moment où le cadran sort : le doigt ne le quitte pas, mais
            // ce n'est plus lui qu'on appuie, c'est le cadran qu'on vise.
            runPressed = false
            Haptics.impact(.medium)
            onOpenDial()
        }
    }

    /// Ce que fait l'appui simple, dit en entier — « Démarrer une sortie trail ».
    private var startLabel: LocalizedStringKey {
        switch discipline {
        case .run: return "Démarrer une course"
        case .bike: return "Démarrer une sortie vélo"
        case .trail: return "Démarrer une sortie trail"
        // Inatteignable : le cadran ne propose que `Discipline.demarrables`, et la nage n'en est
        // pas. Le libellé est juste quand même — une phrase fausse posée « en attendant » est
        // celle que VoiceOver finit par lire un jour.
        case .swim: return "Démarrer une nage"
        }
    }

    /// Le nom de l'action d'accessibilité. Il ne nomme plus une destination mais le panneau :
    /// c'est lui qui liste les trois disciplines, et chacune de ses lignes porte son propre nom.
    ///
    /// Calculé ici et pas en ligne : `accessibilityAction` a une surcharge `LocalizedStringKey` et
    /// une surcharge `StringProtocol`, et un littéral entre les deux est exactement le genre
    /// d'inférence qui ne se découvre qu'au bout d'un quart d'heure de compilation. Un `String`
    /// explicite dans un `Text` ne laisse aucun choix au compilateur.
    ///
    /// Et il passe par `String(localized:)` : un `String` nu dans `Text(_:)` est pris au mot, sans
    /// passer par le catalogue. Le nom de l'action serait resté en français sur un téléphone
    /// anglais, et aucun contrôle ne l'aurait vu — `check_strings` lit les littéraux AFFICHÉS, et
    /// celui-là ne l'est plus.
    private var choixActionName: String {
        String(localized: "Choisir la discipline")
    }

    /// Le bouton central, CONTENU dans la barre.
    ///
    /// Il a été essayé en débordement — rond agrandi, remonté au-dessus du bord — pour réparer un
    /// rognage. Sur un vrai téléphone ça ne donnait pas un bouton surélevé mais une pastille
    /// collée par-dessus la barre, sans rapport avec elle. Le rognage n'était que le symptôme ; la
    /// cause était un bouton dimensionné exactement à la hauteur de sa barre.
    ///
    /// 40 + 3 + le libellé ≈ 54 dans une barre de 56 : il rentre, avec sa marge, et il ne peut
    /// plus être coupé — ni flotter. Le `clipShape` reste retiré du `body` malgré tout : il
    /// rognait par principe ce qui dépassait, et ce piège n'a aucune raison d'être remis en place.
    ///
    /// Et ce n'est plus un `Button` — c'est le correctif de l'appui long.
    ///
    /// `Button` + `.onLongPressGesture` sur la même vue est un faux ami : le reconnaisseur du
    /// bouton remporte l'arbitrage, l'appui long ne part jamais. L'option vélo était donc
    /// inatteignable, alors que tout le reste était en place. Un tap et un appui long posés tous
    /// les deux sur une vue ordinaire, eux, cohabitent — le long échoue si l'on relâche avant
    /// 0,45 s, le tap n'a donc rien à lui disputer.
    ///
    /// Ce qu'un `Button` donnait gratuitement est rendu à la main : le retour visuel à l'appui
    /// (`pressing:`), et l'accessibilité — trait de bouton, action par défaut, et une action
    /// NOMMÉE pour la bascule, qui vaut mieux qu'un appui long pour qui navigue à VoiceOver.
    /// Le diamètre du rond central.
    ///
    /// # 40 → 34, ET CE N'EST PAS UN CHOIX ESTHÉTIQUE : C'EST DE L'ARITHMÉTIQUE
    ///
    /// La barre mesure 56 points, une constante partagée avec l'encart que chaque écran réserve
    /// en bas. Le plus haut des cinq éléments décide donc si les libellés tiennent, et c'est le
    /// bouton central. À la taille de texte par défaut :
    ///
    ///     libellé  = 8,5 × 1,25 (`bodySizeFactor`) = 10,6 pt, soit ~13,2 de hauteur de ligne
    ///     onglet   = 4 (point) + 5 + 22 (icône) + 5 + 13,2  = 49,2
    ///     bouton   = Ø + 3 + 13,2
    ///
    /// À Ø = 40 : **56,2 dans une barre de 56**. Il manquait DEUX DIXIÈMES de point, et comme la
    /// barre entière passe par un `ViewThatFits`, ce qui dépasse ne déborde plus — il DISPARAÎT.
    /// Le mot « RUN » n'était donc plus affiché pour personne, à la taille de texte par défaut,
    /// depuis le build 270. C'est le défaut rapporté par le testeur.
    ///
    /// À Ø = 34 : 50,2, soit **5,8 points de marge**. Les libellés ne tombent plus qu'à partir
    /// d'un texte agrandi d'environ 40 %, ce qui est le comportement voulu — et non à cause d'un
    /// dixième de point sur une hauteur de ligne que personne ne peut mesurer de tête.
    ///
    /// Le rond reste de loin le plus gros élément de la barre (34 contre 22 pour une icône) :
    /// c'est toujours un bouton central surélevé, et il garde son mot, qui porte la discipline.
    private static let diametreDuRond: CGFloat = 34

    // LES QUATRE AUTRES NOMBRES DE L'ÉQUATION, NOMMÉS POUR POUVOIR ÊTRE VÉRIFIÉS.
    //
    // Ils étaient écrits à la main dans les vues, donc invérifiables autrement qu'en les
    // additionnant de tête — ce qui s'est trompé deux fois. `ci_scripts/check_barre.py` les lit
    // ici, lit la hauteur de la barre et la taille du libellé dans leurs fichiers, refait
    // l'addition et refuse une barre dont les libellés ne tiennent plus à la taille de texte
    // par défaut.
    private static let cotesDeLIcone: CGFloat = 22
    private static let diametreDuPoint: CGFloat = 4
    private static let ecartDeLaPile: CGFloat = 5
    private static let ecartDuBouton: CGFloat = 3

    private func runButton(libelle: Bool) -> some View {
        // IL CÈDE COMME LES ONGLETS, et il ne le faisait pas — il cède même LE PREMIER.
        //
        // La barre a une hauteur FIXE, la même constante que l'encart réservé en bas de chaque
        // écran : une barre qui grandirait recouvrirait le contenu puisque l'encart, lui, ne
        // bougerait pas. Le calcul exact — et l'erreur de deux dixièmes de point qui a fait
        // disparaître le mot « RUN » au build 270 — est écrit sur `diametreDuRond` juste
        // au-dessus.
        //
        // C'est lui qui lâche son mot avant les autres parce que son rond de 40 points le rend
        // de loin le plus haut des cinq : garder « RUN » coûterait les quatre autres libellés.
        // Et c'est le seul dont le mot soit redondant — un rond rose avec un triangle dit déjà
        // « ça démarre ». La discipline reste annoncée à VoiceOver (`startLabel`), donc c'est
        // bien la forme qui se simplifie et pas l'information.
        pileDuBouton(avecLibelle: libelle)
        // MÊME LARGEUR QUE LES AUTRES, et c'est le deuxième décalage.
        //
        // Il était fixé à 60 quand les quatre onglets se partagent le reste : sur un écran de
        // 375 points, chaque onglet en prend 75,8 et le centre 60. Les écarts d'icône à icône
        // devenaient donc 75,8 · 67,9 · 67,9 · 75,8 — les deux voisins du bouton RUN tiraient
        // de 8 points vers l'intérieur. Cinq largeurs égales rendent les quatre écarts égaux, et
        // le rond de 40 tient sans peine dans les 72,6 qui lui reviennent.
        //
        // La cible de 44 points reste, et par un second appel : `frame` a une surcharge à
        // dimensions fixes et une à bornes, et les deux familles ne se mélangent pas dans le
        // même appel.
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44, alignment: .bottom)
        .contentShape(Rectangle())
        .scaleEffect(runPressed ? 0.96 : 1)
        .opacity(runPressed ? 0.88 : 1)
        .animation(.easeOut(duration: 0.12), value: runPressed)
        // UN SEUL GESTE POUR TOUT, ET C'EST LE TROISIÈME ESSAI.
        //
        // D'abord `Button` + `.onLongPressGesture` : le reconnaisseur du bouton remportait
        // l'arbitrage et l'appui long ne partait jamais. Puis `.onTapGesture` +
        // `.onLongPressGesture`, qui marchait — mais `TapGesture` n'a aucune durée MAXIMALE, donc
        // le relâchement d'un maintien pouvait aussi arriver comme un tap, et il fallait un
        // drapeau pour l'avaler.
        //
        // Maintenant il faut en plus suivre le doigt APRÈS l'appui long, sans qu'il se lève. La
        // composition documentée pour ça est `LongPressGesture().sequenced(before: DragGesture())`,
        // et elle aurait sans doute marché — mais elle fait dépendre quatre comportements de la
        // façon dont SwiftUI enchaîne deux reconnaisseurs, c'est-à-dire de ce qui a déjà échoué
        // deux fois ici, sur un code que je ne peux pas essayer avant un quart d'heure de
        // compilation.
        //
        // Un `DragGesture(minimumDistance: 0)` voit tout : le doigt qui se pose, chacun de ses
        // déplacements, et le moment où il se lève. La durée de l'appui n'est alors plus un
        // reconnaisseur à composer mais un minuteur qu'on arme et qu'on annule — trois lignes
        // dont chaque branche est écrite ici.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { valeur in
                    if !appuiEnCours {
                        appuiEnCours = true
                        runPressed = true
                        // Pas de minuteur si le cadran est DÉJÀ ouvert : ce nouvel appui sert à en
                        // sortir, ou à viser un rond sans avoir à re-maintenir.
                        if !dialOpen { armerLOuverture() }
                    }
                    if dialOpen { onDialDrag(valeur.translation) }
                }
                .onEnded { valeur in
                    appuiEnCours = false
                    runPressed = false
                    ouvertureEnCours?.cancel()
                    ouvertureEnCours = nil
                    if dialOpen {
                        onDialEnd(valeur.translation)
                    } else if hypot(valeur.translation.width, valeur.translation.height)
                                < Self.toleranceDAppui {
                        onStartRun()
                    }
                }
        )
        .animation(RUMotion.snap, value: discipline)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(startLabel)
        // Le GESTE, pas une destination : le cadran montre les trois, c'est lui qui dit où l'on
        // va. Et il faut le décrire en entier — « appui long » seul laisserait croire qu'il suffit
        // de relâcher, alors que relâcher sans bouger annule.
        .accessibilityHint(canChooseDiscipline
                           ? "Appui long puis glisse le doigt pour choisir la discipline" : "")
        .accessibilityAction {
            onStartRun()
        }
        // L'action nommée ouvre le cadran SANS aucun glissement, et c'est sa raison d'être : ni
        // le maintien de 0,45 s ni le glissement qui le suit ne sont transmis par VoiceOver. Le
        // rotor d'actions est la façon dont ses utilisateurs découvrent ce qu'une vue sait faire,
        // et les trois ronds restent des boutons qu'on atteint ensuite un par un.
        .accessibilityAction(named: Text(choixActionName)) {
            guard canChooseDiscipline else { return }
            onOpenDial()
        }
    }
}

/// Floating pill shown above the tab bar when a run is active but the user navigated away.
struct RunInProgressPill: View {
    var elapsed: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(RUColor.onRose).frame(width: 7, height: 7)
                Text("RUN EN COURS · \(elapsed)")
                    .font(RUFont.display(.caption))
                    .tracking(1)
                    .foregroundColor(RUColor.onRose)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
            .background(RUColor.rose, in: Capsule())
            // Même geste : la barre entière baignait dans un halo rose de 20 points. Une barre
            // d'onglets se pose au-dessus du contenu, elle ne l'illumine pas.
            .shadow(color: .black.opacity(RUColor.isLight ? 0 : 0.5), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(PressableStyle())
    }
}
