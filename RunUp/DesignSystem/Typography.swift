import SwiftUI
import Observation
import UIKit

/// Font tokens — see README § Typography.
///
/// Une seule famille de texte, `DisplayFont.family` (Inter), déclinée par taille et par graisse :
/// - Display/numerals (Medium, class `.b`): big numbers, headlines,
///   buttons — voir `display(_:)` et son facteur de taille.
/// - Body (300–700 + italic): body copy, labels.
/// - Monospace ("DM Mono", class `.m`): timestamps, XP counters, precise numeric readouts.
/// - Eyebrow (class `.eye`): 9px, 3px tracking, uppercase, weight 700, used above section titles.
///
/// # Dynamic Type
/// Every token below routes its design point size through `scaled(_:)` and then hands the result
/// to a NON-scaling font initializer (`.custom(_:fixedSize:)` / `.system(size:)`), so this file is
/// the single place that decides how the app answers the iOS text-size setting. That indirection
/// is deliberate, and it fixes two different problems at once:
///
/// 1. La police de titrage avait, en mode clair, une branche `.system(size:)` qui ne suit PAS
///    Dynamic Type — en mode clair, chaque grand chiffre, titre et libellé de bouton de l'app
///    restait figé à sa taille codée en dur, quoi que l'utilisatrice ait choisi dans
///    Réglages → Affichage → Taille du texte. Cette branche a disparu avec Bebas (voir
///    `display(_:)`), mais l'indirection qui l'avait corrigée reste ce qui garantit qu'aucun
///    token ne puisse la réintroduire.
/// 2. The `.custom(_:size:)` initializer the other tokens used *does* scale (Apple: "scales with
///    the body text style"), but with no ceiling whatsoever: at the largest accessibility size
///    `.body` grows 17pt → 53pt, i.e. ≈3.1×. Applied to the week strip, the 3-up stat rows, the
///    prediction tiles or the tab bar labels — all fixed-width, side-by-side layouts — that
///    doesn't degrade gracefully, it collapses into unreadable truncation.
///
/// Les deux branches avaient fini par ne plus s'accorder : le même écran suivait ou non le
/// réglage selon que le mode clair était actif. Un seul chemin, plafonné, les rend cohérentes —
/// et il n'y a plus qu'une seule police de titrage à suivre, sur les deux fonds.
///
/// Reactivity works exactly like `RUColor`'s theme tokens do (see `ThemeStore`): the sizes are
/// computed, not stored, and they read an `@Observable` singleton — `TextSizeStore` — so every
/// existing call site re-scales live when the setting changes, with zero call-site changes.
enum RUFont {
    /// Ceiling on how far a design size is allowed to grow, as a multiple of itself.
    ///
    /// # 1,6× → 2,0×, PARCE QUE LES MISES EN PAGE QUI LE BLOQUAIENT SE RÉORGANISENT MAINTENANT
    ///
    /// Le plafond valait 1,6× : il couvrait toute la plage ordinaire du curseur iOS
    /// (xSmall…xxxLarge culmine à ≈1,35× pour `.body`) et coupait les CINQ tailles
    /// d'accessibilité, parce qu'au-delà les cartes multi-colonnes de l'app ne se dégradaient
    /// pas, elles s'effondraient en troncature. Le commentaire d'alors disait ce qu'il faudrait
    /// pour le lever : « un travail par écran — des `HStack` de mesures qui deviennent des
    /// `VStack` au-delà d'un seuil ».
    ///
    /// Ce travail est fait, et pas avec un seuil :
    ///
    ///   • les rangées de mesures (`RUMetricRow`) et les tuiles de records et de prédiction
    ///     (`RUTileRow`) passent en colonne quand elles ne tiennent plus ;
    ///   • la bande des sept jours laisse tomber le quantième et garde l'initiale, la marque
    ///     d'état et la date annoncée à VoiceOver ;
    ///   • la barre d'onglets laisse tomber ses libellés et garde ses noms accessibles, sans
    ///     grandir — sa hauteur sert d'encart au bas de chaque écran.
    ///
    /// 2,0× COUVRE DEUX DES CINQ TAILLES D'ACCESSIBILITÉ en entier : AX1 (≈1,65×) et AX2
    /// (≈1,94×). Les trois dernières montent à 2,35×, 2,76× et 3,12× et restent écrêtées.
    ///
    /// Le plafond ne disparaît donc pas, et ce n'est pas de la prudence pour la forme : il reste
    /// dans l'app des mises en page denses que personne n'a encore éprouvées à ces tailles-là.
    /// Annoncer un support complet en le découvrant faux chez quelqu'un qui en dépend coûte plus
    /// cher que d'avancer d'un cran et de le dire. Le prochain cran se gagne de la même façon :
    /// en réorganisant, puis en levant.
    private static let maxScale: CGFloat = 2.0

    /// Turns a design point size into the size actually rendered, honouring the user's text-size
    /// setting up to `maxScale`.
    ///
    /// `.body` as the reference style for every token, rather than trying to map each call site's
    /// size onto the "right" text style: the sizes passed in here (8 → 44) were all drawn against
    /// each other in one mockup, and scaling them on different curves would pull the design apart
    /// at exactly the sizes it's meant to hold together. `.body`'s multiplier is 1.0 at the default
    /// (Large) category, so this is a no-op for anyone who never touched the setting — nothing
    /// about the default rendering of the app changes.
    ///
    /// Scaled `compatibleWith:` an explicit trait collection built from `TextSizeStore`, rather
    /// than letting `UIFontMetrics` fall back to the ambient `UITraitCollection.current`: that
    /// ambient value is only meaningfully set inside a UIKit view-update pass, and reading it
    /// would also make this function invisible to the Observation framework — the fonts would go
    /// stale until something else happened to re-render the screen. Going through the store gives
    /// a deterministic input AND registers the dependency, so a change to the setting invalidates
    /// every view that drew text, immediately.
    private static func scaled(_ size: CGFloat) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: TextSizeStore.shared.category)
        let scaledSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: size, compatibleWith: traits)
        return min(scaledSize, size * maxScale)
    }

    /// La police de titrage : titres, grands chiffres, libellés en capitales, boutons.
    ///
    /// C'était Bebas Neue — des capitales d'affiche condensées, énergiques, registre salle de
    /// sport. Elle avait deux défauts. Elle ne tenait pas sur fond clair, au point que le mode
    /// clair la remplaçait par une system sans lourde : l'app avait donc DEUX identités
    /// typographiques selon le thème. Et elle est une police d'affiche, un genre qui date vite.
    ///
    /// C'est désormais Inter Medium — la même famille que le texte courant, une graisse plus
    /// haut. Elle tient sur les deux fonds, d'où la disparition de la bifurcation.
    ///
    /// Le nom de la police et le facteur de taille vivent dans `DisplayFont` (RunUp/Shared) :
    /// le widget et la montre les utilisent aussi, et une police nommée à trois endroits finit
    /// toujours par n'être changée qu'à deux.
    ///
    /// Le point d'entrée normal : un cran nommé, pas un nombre.
    static func display(_ step: RUDisplaySize) -> Font {
        display(horsEchelle: step.rawValue, grasse: step.grasse)
    }

    /// La sortie de l'échelle, et son nom le dit à l'appel.
    ///
    /// Un paramètre étiqueté plutôt qu'une surcharge muette : `display(26)` se serait écrit tout
    /// seul, sans que personne ait à se demander si 26 existait. `display(horsEchelle: 26)` ne
    /// s'écrit pas par distraction, et un seul `grep horsEchelle` donne la liste complète des
    /// exceptions — donc la liste de ce qui reste à justifier. Il y en a douze, et elles tiennent
    /// en trois raisons :
    ///
    ///   • les cartes d'export (`RunShareCardView`, `RunVideoFrameView`, `BadgeShareCardView`) :
    ///     une image partagée est rendue à une géométrie de pixels fixe, et sa typographie ne
    ///     doit pas se déplacer parce que l'échelle de l'app s'est déplacée ;
    ///   • les initiales d'un avatar, à 0,4 × son diamètre : une suite continue, pas un cran ;
    ///   • le chronomètre de la course en cours — 96 pt pour le décompte de départ, 52 ou 64 pour
    ///     le temps écoulé selon qu'une consigne est affichée. Un seul écran, lu à bout de bras.
    static func display(horsEchelle size: CGFloat, grasse: Bool = false) -> Font {
        // ── LES CHIFFRES À CHASSE FIXE, POUR TOUTE L'APP ─────────────────────────────────────
        //
        // Trois fichiers appelaient `.monospacedDigit()` à la main — l'accueil, la course en
        // cours, l'onboarding — et les quarante autres l'oubliaient. Conséquence sur une app de
        // course : partout ailleurs, un « 1 » occupe moins de place qu'un « 8 », donc une
        // colonne de distances se décale d'une ligne à l'autre et un chronomètre tremble à
        // chaque seconde. C'est le genre de défaut qu'on ne sait pas nommer en regardant un
        // écran — on le lit comme « ça n'a pas été fait avec soin », et on a raison.
        //
        // Ici plutôt qu'aux cent appels : c'est une propriété de la police de titrage, pas le
        // réglage d'un écran. Inter livre bien `tnum`, et `monospacedDigit()` est un réglage de
        // fonctionnalité OpenType — il ne change pas de famille, donc rien d'autre ne bouge.
        //
        // Pas sur `sans` : du texte courant à chasse fixe se lit mal, et les chiffres d'une
        // phrase n'ont aucune colonne à tenir.
        //
        // ── ET LA GRAISSE, AU-DESSUS DE 24 POINTS ────────────────────────────────────────────
        //
        // Toute l'app titrait en Inter Medium : le prénom en haut de l'accueil, un titre de
        // feuille, et le chiffre de 48 points de l'allure moyenne, tous dans la MÊME graisse.
        // Or la graisse perçue d'un caractère baisse quand sa taille monte — à 30 ou 48 points,
        // une moyenne lit maigre et délavée là où, à 14, elle lit juste. C'est ce que corrige
        // l'optical sizing des familles qui en ont ; Inter n'en a pas, donc on le fait à la main.
        //
        // Au-dessus de 24 points DESSINÉS, c'est-à-dire aux trois crans qui portent les grands
        // chiffres et les accroches. En dessous, rien ne bouge : un titre de carte en gras
        // écraserait le texte qu'il coiffe.
        //
        // Inter-Bold est déjà livrée et déjà enregistrée dans les trois cibles — c'est la graisse
        // du texte courant en gras. Aucun fichier de plus, et le nom est écrit en toutes lettres
        // juste derrière `.custom` pour que `check_fonts.py` le voie : une police demandée qu'il ne
        // voit pas est exactement la panne silencieuse qu'il existe pour empêcher.
        let taille = scaled(DisplayFont.pointSize(for: size))
        let police: Font = grasse
            ? .custom("\(DisplayFont.family)-Bold", fixedSize: taille)
            : .custom(DisplayFont.postScriptName, fixedSize: taille)
        return police.monospacedDigit()
    }

    /// Le texte courant et les métriques, relevés de 6 %.
    ///
    /// Séparé du facteur de titrage parce que les deux problèmes sont distincts : celui du
    /// titrage venait du changement de police, celui-ci est un jugement sur l'app telle qu'elle
    /// est — les libellés de 10 à 13 pt de la maquette sont serrés pour un écran lu en courant,
    /// souvent au soleil, souvent en bougeant.
    ///
    /// 6 % et pas davantage : les rangées de trois métriques côte à côte sont à largeur fixe, et
    /// au-delà elles tronquent au lieu de s'adapter. Comme le facteur de titrage, c'est un nombre,
    /// à un seul endroit, qu'on rouvre après avoir regardé un écran.
    /// 1,25, et comme pour le titrage ce chiffre en baisse ne rapetisse rien : il maintient.
    ///
    /// Le relèvement décidé plus tôt — le texte courant devait passer d'environ 12 pt dessinés à
    /// la générosité des références, autour de 16 — reste entier. Seule la compensation de police
    /// change : Inter a une hauteur d'x de 0,546 em contre 0,526 pour Archivo, donc 1,30 × 0,964
    /// ≈ 1,25 rend très exactement la même taille perçue, qui est celle qui a été validée.
    ///
    /// Le garde-fou reste les rangées de métriques côte à côte, à largeur fixe. Il tient :
    /// Inter est 4,9 % plus large qu'Archivo et le facteur baisse de 3,8 %, donc une ligne occupe
    /// 1 % de plus qu'avant. Les neuf libellés d'une seule ligne gardent par ailleurs leur
    /// `minimumScaleFactor` — ils rétrécissent au lieu de se couper.
    private static let bodySizeFactor: CGFloat = 1.25

    /// LA TROISIÈME FAMILLE AVAIT LE MÊME DÉFAUT QUE LES DEUX AUTRES.
    ///
    /// DM Mono sert aux relevés chiffrés — horodatages, compteurs d'XP, kilométrage d'une paire
    /// de chaussures, temps de fractionnés. C'est un rôle légitime et il ne change pas. Mais ses
    /// tailles étaient écrites à la main, 26 appels sur HUIT valeurs : 8, 9,5, 10, 10,5, 11, 12,
    /// 13, 20. Avec 10, 10,5 et 11 voisinant sur dix-sept appels — trois tailles dans un point.
    ///
    /// Elle reprend donc l'échelle du texte courant, `RUTextSize`, plutôt qu'une quatrième à
    /// elle : un relevé chiffré vit à côté du texte qu'il complète, et les deux doivent
    /// s'accorder. Cinq crans employés sur les six.
    static func mono(_ step: RUTextSize, weight: DMWeight = .regular) -> Font {
        mono(horsEchelle: step.rawValue, weight: weight)
    }

    /// Voir `display(horsEchelle:)` : l'étiquette est là pour que l'exception se voie. Il y en a
    /// trois, toutes dans des cartes d'export — une image partagée est rendue à une géométrie de
    /// pixels fixe, et sa typographie ne doit pas bouger quand l'échelle de l'app bouge.
    static func mono(horsEchelle size: CGFloat, weight: DMWeight = .regular) -> Font {
        let pointSize = scaled(size * bodySizeFactor)
        switch weight {
        case .medium: return .custom("DMMono-Medium", fixedSize: pointSize)
        default: return .custom("DMMono-Regular", fixedSize: pointSize)
        }
    }

    /// La famille du texte courant, nommée UNE fois.
    ///
    /// C'est elle qui dessine l'écrasante majorité de ce qu'on lit : 348 appels à `sans` contre
    /// 82 au titrage. Autrement dit, changer la police de titrage ne change presque rien à
    /// l'impression que donne un écran — c'est ici qu'il faut agir, et c'est ici qu'on agira la
    /// prochaine fois, en modifiant cette seule chaîne.
    private static let bodyFamily = DisplayFont.family

    /// Le point d'entrée normal : un cran nommé, pas un nombre.
    static func sans(_ step: RUTextSize, weight: DMWeight = .regular) -> Font {
        sans(step.rawValue, weight: weight)
    }

    static func sansItalic(_ step: RUTextSize) -> Font { sansItalic(step.rawValue) }

    /// La variante numérique, `private` exprès : c'est par elle que les dix-neuf tailles sont
    /// arrivées. Le compilateur refuse maintenant un nombre écrit à la main hors de ce fichier,
    /// ce qu'aucune vérification d'intégration continue ne garantirait aussi bien — celle-ci ne
    /// peut pas être contournée ni oubliée.
    private static func sans(_ size: CGFloat, weight: DMWeight = .regular) -> Font {
        let pointSize = scaled(size * bodySizeFactor)
        switch weight {
        case .light: return .custom("\(bodyFamily)-Light", fixedSize: pointSize)
        case .regular: return .custom("\(bodyFamily)-Regular", fixedSize: pointSize)
        case .medium: return .custom("\(bodyFamily)-Medium", fixedSize: pointSize)
        case .semibold: return .custom("\(bodyFamily)-SemiBold", fixedSize: pointSize)
        case .bold: return .custom("\(bodyFamily)-Bold", fixedSize: pointSize)
        }
    }

    private static func sansItalic(_ size: CGFloat) -> Font {
        .custom("\(bodyFamily)-Italic", fixedSize: scaled(size * bodySizeFactor))
    }

    enum DMWeight {
        case light, regular, medium, semibold, bold
    }
}

/// Live holder for the user's iOS text-size setting, read by `RUFont`'s scaled sizes from anywhere
/// in the app. Exactly the same shape and rationale as `ThemeStore` (see `AccentTheme.swift`): the
/// Observation framework tracks access to this object's properties during any view's `body`,
/// however that reference was obtained, so `RUFont.sans(.label)` and friends stay reactive without a
/// single call site having to take an `@Environment(\.dynamicTypeSize)` of its own.
///
/// Seeded from `UIApplication.shared` and kept current by the system notification rather than by
/// polling — the setting can change while the app is in the foreground (Réglages via the app
/// switcher, or the text-size control in the Centre de contrôle), not only across a relaunch.
@Observable
final class TextSizeStore {
    static let shared = TextSizeStore()

    private(set) var category: UIContentSizeCategory

    private init() {
        category = UIApplication.shared.preferredContentSizeCategory
        // Delivered on `.main` so the mutation below — observed by SwiftUI views — always happens
        // on the main actor, and `[weak self]` purely out of habit: this singleton outlives the
        // observer either way, so there is no retain cycle to break and no removal to schedule.
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Re-read the app-level value rather than unwrapping the notification's userInfo: the
            // notification is posted after `UIApplication` has already adopted the new category,
            // so the two always agree, and this needs no optional-cast fallback path that could
            // silently leave the store stale.
            self?.category = UIApplication.shared.preferredContentSizeCategory
        }
    }
}

extension Text {
    /// Class `.b` in the prototype — la police de titrage, interlettrage serré (négatif).
    /// `.tracking`/`.textCase` are `View`-only modifiers (not declared on `Text` itself), so this
    /// returns `some View` rather than `Text` — safe everywhere it's used since none of these
    /// call sites concatenate the result with `+` (that requires `Text` on both sides).
    func displayStyle(_ step: RUDisplaySize) -> some View {
        displayStyle(horsEchelle: step.rawValue, grasse: step.grasse)
    }

    /// Voir `RUFont.display(horsEchelle:)` : l'étiquette est là pour que l'exception se voie.
    func displayStyle(horsEchelle size: CGFloat, grasse: Bool = false) -> some View {
        // Interlettrage NÉGATIF, proportionnel à la taille (−3 %), là où il était fixé à +0,5.
        //
        // Un titrage gras espacé positivement se lit comme du texte agrandi ; c'est le resserrage
        // qui le fait lire comme un titre. La proportionnalité compte autant que le signe : à
        // 11 pt, −0,33 se remarque à peine, à 46 pt, −1,4 change la ligne entière. Une valeur
        // fixe ne peut pas servir les deux.
        self.font(RUFont.display(horsEchelle: size, grasse: grasse)).tracking(-size * 0.03)
    }

    /// Le sourcil posé au-dessus d'un titre de page ou de section.
    ///
    /// CE QU'IL REND AUJOURD'HUI : `.small` demi-gras, soit 13,1 pt, interlettrage 0,2, `text3`.
    /// Ni 8,5 pt, ni capitales, ni interlettrage 3 — voir la décision écrite dans le corps de la
    /// méthode, en bas de cette suite de notes. L'historique qui suit se lit donc comme un
    /// historique : c'est l'état d'une étape antérieure, pas la description du rendu actuel.
    /// (Ce décalage a déjà coûté une mesure fausse : 10,6 pt annoncés pour un jeton qui en rend
    /// 13,1.)
    ///
    /// Étape antérieure, recalée sur le `.ru-eyebrow` de la maquette : `font-size: 8.5px;
    /// font-weight: 700; letter-spacing: 0.18em; color: var(--ru-ink3)`.
    ///
    /// - Taille 9 → 10 : le gabarit téléphone de la maquette (268px pour ~393pt réels) donne un
    ///   facteur ~1,25, calibré sur deux repères non ambigus — ses micro-libellés de métriques font
    ///   7,5px là où l'app utilise `sans(9)`, et sa barre de progression d'onboarding fait 2,5px là
    ///   où l'app utilise 3. 8,5 × 1,25 ≈ 10,6. L'app posait l'eyebrow et les micro-libellés à la
    ///   MÊME taille (9) alors que la maquette hiérarchise les deux.
    /// - Interlettrage 3 → 1,8 : 0,18em à 10pt vaut 1,8pt. L'ancien 3pt à 9pt valait 0,33em, soit
    ///   presque le double de la maquette — c'est l'écart le plus net de toute la typographie
    ///   partagée, et le plus visible (un eyebrow trop étiré se lit comme un titre de rubrique de
    ///   presse, pas comme une étiquette discrète).
    ///   Les deux changements se compensent en largeur : ~8,4pt par caractère avant, ~7,8pt après.
    /// - Couleur par défaut `text2` → `text3` : la maquette réserve `--ru-ink2` à la prose
    ///   secondaire (`.callout p`, `.insight-line`, `.alert-card .s8`) et emploie `--ru-ink3` pour
    ///   TOUTES ses micro-étiquettes — eyebrows, libellés de métriques, horodatages. Les deux
    ///   tokens se correspondent d'ailleurs exactement (`ink3` sombre = 32% blanc = `text3`).
    ///   Sans effet sur les ~66 des 83 `EyebrowLabel` qui passent déjà une couleur explicite.
    func eyebrowStyle(color: Color = RUColor.text3) -> some View {
        // Plus de capitales, et une graisse en moins. Ce style coiffe désormais des libellés
        // de CHAMP et des chapeaux de page ; les quatre références écrivent les deux en
        // minuscules — « Good morning! » au-dessus d'un nom en gras, jamais « GOOD MORNING! ».
        // Les capitales espacées donnaient à chaque micro-libellé le poids d'un titre : c'est
        // une convention de tableau de bord technique, et elle fabriquait du bruit là où ces
        // écrans ont besoin de calme.
        self.font(RUFont.sans(.small, weight: .semibold)).tracking(0.2).foregroundColor(color)
    }
}

/// Les sept crans de la police de titrage.
///
/// Il y en avait VINGT-SIX, écrits à la main sur 103 appels : 11, 12, 13, 14, 15, 16, 17, 18, 19,
/// 20, 21, 22, 23, 24, 25, 26, 28, 29, 30, 33, 34, 36, 40, 42, 44, 96. Ce n'est pas le nombre qui
/// était le défaut — c'est que les voisines ne se distinguaient pas : 20, 21, 22, 23, 24, 25 et 26
/// font sept tailles dans six points, et à l'écran (× 1,09) elles rendent 21,8 / 22,9 / 24,0 /
/// 25,1 / 26,2 / 27,3 / 28,3. Personne ne lit ça comme une hiérarchie ; on lit sept écrans réglés
/// à l'œil, séparément, et c'est exactement l'impression de bricolage que l'app donnait.
///
/// Les crans ci-dessous valent chacun 1,22 à 1,29 fois le précédent — assez pour que le saut se
/// voie, assez peu pour qu'il reste une progression et non une rupture. À l'écran (× 1,09) :
/// 12,0 / 15,3 / 19,6 / 24,0 / 30,5 / 38,2 / 48,0.
///
/// Chaque cran a été choisi sur une valeur qui existait DÉJÀ et qui portait le plus d'appels :
/// 22 en portait 18, 26 en portait 13, 34 et 11 six chacun. L'échelle ne vient donc pas d'une
/// table de ratios appliquée par-dessus l'app — elle vient de l'app, dont on a gardé les
/// paliers dominants et jeté les hésitations autour.
///
/// Comme `RUTextSize`, la variante numérique est étiquetée `horsEchelle:` pour que les
/// vingt-six valeurs ne reviennent pas une par une.
enum RUDisplaySize: CGFloat {
    /// 11 → 12,0 pt. Micro-chiffres, valeurs de pastille.
    case caption = 11
    /// 14 → 15,3 pt. Libellés de bouton, valeurs en ligne.
    case label = 14
    /// 18 → 19,6 pt. Titres de ligne de liste, valeurs d'une grille de mesures dense.
    case subtitle = 18
    /// 22 → 24,0 pt. Titres de page et de feuille, titres de carte, valeurs mises en avant.
    case title = 22
    /// 28 → 30,5 pt. LE chiffre d'une carte — un cumul, une moyenne, une allure.
    case figure = 28
    /// 35 → 38,2 pt. Le chiffre unique d'un écran.
    case hero = 35
    /// 44 → 48,0 pt. Une accroche, un record : au plus un par écran.
    case banner = 44

    /// LA GRAISSE SUIT LE CRAN, parce que la graisse PERÇUE baisse quand la taille monte.
    ///
    /// Un `switch` exhaustif plutôt qu'une comparaison de nombres : ajouter un cran demandera
    /// alors de répondre à la question, au lieu de la laisser se décider toute seule par un
    /// seuil que personne ne relira.
    var grasse: Bool {
        switch self {
        case .caption, .label, .subtitle, .title: return false
        case .figure, .hero, .banner: return true
        }
    }
}

/// Les six crans de texte de l'app.
///
/// Il y en avait DIX-NEUF, de 7 à 18 pt par pas de 0,5 — un 12,5 à côté d'un 13, un 11,5 à côté
/// d'un 12. Des écarts trop petits pour se lire comme une hiérarchie, et assez grands pour que
/// rien ne s'aligne : chaque écran avait été réglé à l'œil, séparément.
///
/// Le premier rangement les avait posées au plus près des dix-neuf valeurs d'origine, exprès :
/// il ne fallait pas modifier en douce une app qui venait d'être validée. C'est désormais un
/// choix assumé, et les écarts sont ceux d'une vraie progression — chaque cran vaut 1,14 à 1,23
/// fois le précédent, là où quatre d'entre eux tenaient dans un seul point.
///
/// `body` ne bouge pas d'un dixième : c'est l'ancre, la taille du texte courant qui a été
/// approuvée. Tout se déplace AUTOUR d'elle — les deux crans du bas descendent pour laisser
/// respirer les unités et les notes, les trois du haut montent pour que les titres se lisent
/// comme des titres. À l'écran (facteur 1,25) : 10,6 / 13,1 / 15 / 17,5 / 20 / 23,1.
///
/// La variante numérique est `private` pour que les dix-neuf valeurs ne reviennent pas une par
/// une : le compilateur refuse un nombre écrit à la main hors de ce fichier.
enum RUTextSize: CGFloat {
    /// 8,5 — suffixes d'unité, micro-libellés sous un chiffre.
    case micro = 8.5
    /// 10,5 — valeurs secondaires, notes, sous-titres de ligne.
    case small = 10.5
    /// 12 — le texte courant. Le seul cran qui ne bouge pas.
    case body = 12
    /// 14 — libellés de carte, titres de ligne de liste.
    case label = 14
    /// 16 — libellés qui doivent primer sur leurs voisins.
    case emphasis = 16
    /// 18,5 — titres de carte et de section.
    case title = 18.5
}

struct EyebrowLabel: View {
    var text: String
    /// Voir `eyebrowStyle(color:)` : `text3`, pas `text2` — la maquette réserve `ink2` à la prose
    /// secondaire et met toutes ses micro-étiquettes en `ink3`.
    var color: Color = RUColor.text3

    var body: some View {
        // `Text(text)` with a plain `String` never resolves through Localizable.xcstrings — only
        // `Text(_ key: LocalizedStringKey)` does, and that overload only kicks in for a string
        // literal passed directly at a `Text`/`Text`-taking-component call site. Since every call
        // site here passes a literal into this `String`-typed `text` property first, the literal
        // was being absorbed as a `String` before ever reaching a real `Text` init — wrapping in
        // `LocalizedStringKey(text)` performs the same catalog lookup a literal argument would,
        // for every caller, without needing to touch any of the ~75 call sites individually. A
        // caller passing a genuinely dynamic, already-formatted string (not a catalog key) just
        // falls through to the same verbatim rendering it had before — never worse, often fixed.
        Text(LocalizedStringKey(text)).eyebrowStyle(color: color)
    }
}
