import SwiftUI
import UIKit

/// Design tokens — see design_handoff_runup_app/README.md § Design Tokens / Colors. Every token
/// here is theme-aware (dark/light — see `ThemeStore.isLightMode`, set from Profil → Apparence),
/// computed rather than `let`, so every existing call site re-themes live with zero call-site
/// changes — the same mechanism the accent-color nuancier already relies on.
enum RUColor {
    static var isLight: Bool { ThemeStore.shared.isLightMode }
    /// For `.preferredColorScheme(...)` call sites — one place computing this so root/sheet
    /// presentations can't drift out of sync with the tokens above.
    static var colorScheme: ColorScheme { isLight ? .light : .dark }

    // Thème clair : le fond de page est un gris doux et les cartes sont BLANCHES — l'inverse de
    // ce que l'app faisait, et l'inverse de ce que la maquette déclare.
    //
    // Pourquoi contredire la maquette ici : ses valeurs claires (`--ru-bg: #FFFFFF`,
    // `--ru-card: #F0F0F6`) ont été transcrites DEPUIS ces tokens, elle les a donc hérités et ne
    // peut pas les arbitrer — et ses 29 écrans n'ont jamais été regardés qu'en sombre. En sombre
    // le couple fonctionne : une carte est du blanc à 4,5 % sur un fond quasi noir, elle se
    // détache par sa clarté. Transposé en clair, il donnait une carte grise sur du blanc, 6 %
    // d'écart, que seule une ombre marquée rendait lisible — l'ombre que le portage de la
    // maquette a justement divisée par quatre. D'où des cartes délavées, qui flottent sans se
    // poser.
    //
    // Inverser le rapport produit en clair ce que le sombre obtient déjà, par la même logique :
    // la carte est la surface CLAIRE, le fond recule. Le filet et l'ombre redeviennent des
    // finitions au lieu de porter seuls la séparation.
    /// Un fond TEINTÉ en clair, et une carte blanche posée dessus.
    ///
    /// # Cette décision a déjà été prise dans les deux sens
    ///
    /// Les commentaires au-dessus racontent l'aller-retour : fond teinté, puis blanc pur « demandé
    /// tel quel », avec un filet remonté à 13 % pour compenser. Elle repasse ici du côté teinté, et
    /// ce n'est pas un revirement de goût — deux choses ont changé dans l'app entre-temps.
    ///
    /// L'app a gagné des IMAGES. Le tracé d'une sortie occupe maintenant le haut d'une carte de
    /// fil, sur fond sombre, plein cadre. Sur une page blanche, une carte blanche portant un
    /// rectangle sombre à ras bord ne se lit pas comme une surface : elle se lit comme un trou.
    /// Il faut que la page recule pour que la carte existe.
    ///
    /// Et le filet à 13 % dessinait chaque carte au trait. Sur un écran qui en empile trois ou
    /// quatre, ça donne une grille de rectangles cerclés — précisément ce qu'on nous a demandé de
    /// ne plus avoir. Le fond teinté sépare mécaniquement, donc le filet peut redescendre à une
    /// finition qu'on ne remarque pas, et l'ombre s'élargir et s'adoucir.
    ///
    /// # LE NEUTRE EST CHAUD, ET IL A ÉTÉ FROID
    ///
    /// Il a longtemps penché vers le violet de l'accent, avec cette raison : « un gris pur à côté
    /// d'un rose vif prend l'air sale, un gris qui partage sa famille non ». L'argument est bon et
    /// il ne tient pas, parce qu'il suppose UN accent. L'app en propose huit (décision D1), dont
    /// le cyan, le lime et le bleu : un fond violet ne partageait la famille que du rose et du
    /// violet, et se retrouvait en désaccord avec les six autres.
    ///
    /// Le fond prend donc la position du PAPIER — un blanc cassé chaud, sur lequel n'importe
    /// quelle encre se pose — plutôt que celle d'un écho de l'accent. C'est la direction que le
    /// brief demandait depuis le début (`#FBF9F7`), et Charlotte l'a ouverte le 12 novembre.
    ///
    /// LA TEINTE DU BRIEF, PAS SA LUMINOSITÉ, comme pour les jetons de texte. `#FBF9F7` est
    /// presque blanc : sous une carte blanche il ne recule que de 1,050:1, contre 1,104 pour
    /// l'ancien froid — la moitié de la séparation, et c'est précisément ce recul qui empêche une
    /// carte à image pleine de se lire comme un trou. La valeur retenue garde la luminance de
    /// l'ancienne et retourne sa famille : 1,100:1, l'écart est tenu.
    ///
    /// Les trois surfaces claires ont bougé ensemble, et c'était obligatoire : une page chaude
    /// sous des sous-surfaces lavande, c'est un écran qui se contredit.
    static var bg: Color { fond(pour: habillage) }

    /// LE FOND D'UN HABILLAGE DONNÉ, et pas seulement de celui qui est actif.
    ///
    /// `bg` ne sait répondre que pour l'habillage courant, ce qui ne suffit pas à l'aperçu des
    /// réglages : il montre les DEUX habillages côte à côte, dont celui qu'on n'a pas. Faute de
    /// cette fonction, l'aperçu recopiait la formule — le neutre, le rose, le pourcentage — et
    /// la copie a fait exactement ce que font les copies : le pourcentage clair est passé de
    /// 7 % à 3,5 % ici, et l'aperçu a continué d'en montrer 7. Le réglage mentait sur ce qu'il
    /// allait produire.
    static func fond(pour habillage: Habillage) -> Color {
        let neutre = isLight ? Color(hex: 0xF5F4F1) : Color(hex: 0x08070D)
        guard habillage == .teinte else { return neutre }
        // LE SOL PREND LA COULEUR. Voir `Habillage`.
        //
        // Une trace, pas un aplat : 3,5 % en clair, 10 % en sombre. Au-delà, le fond cesse d'être
        // un fond et se met à concurrencer les cartes posées dessus — et surtout il faudrait
        // reprendre tous les contrastes de texte, que `check_a11y` tient sur ces valeurs-ci.
        //
        // Plus fort en sombre qu'en clair parce qu'une teinte se voit moins sur du presque-noir :
        // à la même valeur des deux côtés, le mode sombre paraîtrait inchangé.
        //
        // LA VALEUR CLAIRE ÉTAIT À 7 %, ET CE N'ÉTAIT PLUS UNE TRACE.
        //
        // Sept pour cent du rose de marque (#F50D7A) sur le neutre clair (#F4F3F8) donne
        // #F4E3EF : une page ROSE, pas une page teintée. Sur une capture de vrai téléphone,
        // l'écran entier paraît imprimé sur du papier rose, et les cartes blanches censées
        // « flotter dessus » se lisent comme des trous. La moitié (#F4EBF4) fait ce que la
        // phrase ci-dessus promettait depuis le début.
        //
        // Baisser cette valeur ne peut que faire MONTER les contrastes : le fond se rapproche du
        // neutre sur lequel `classique` les tient déjà.
        return melange(rose, sur: neutre, part: isLight ? 0.035 : 0.10)
    }

    /// L'habillage courant — voir `Habillage`. Lu comme `isLight` : calculé, jamais stocké.
    static var habillage: Habillage { ThemeStore.shared.habillage }

    /// Deux couleurs mélangées dans les composantes, `part` de la première sur la seconde.
    ///
    /// Par les composantes et non par une superposition d'opacité : `bg` doit rendre UNE couleur
    /// opaque, pas deux calques. C'est la même technique que `onAccent` juste en dessous, qui
    /// démonte déjà une `Color` en RVB pour en calculer la luminance.
    static func melange(_ couleur: Color, sur fond: Color, part: CGFloat) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(couleur).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(fond).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let p = min(max(part, 0), 1)
        return Color(red: Double(r1 * p + r2 * (1 - p)),
                     green: Double(g1 * p + g2 * (1 - p)),
                     blue: Double(b1 * p + b2 * (1 - p)))
    }

    /// L'ENCRE DE LA PAGE — le presque-noir de ce qui appartient au sol plutôt qu'à la carte :
    /// l'ombre qui la pose, le filet qui la borde.
    ///
    /// Elle partage la famille du fond, et elle a changé de camp avec lui le 12 novembre. Elle
    /// valait `#1A162E`, soit le bleu 20 points au-dessus du rouge, avec cette raison écrite :
    /// « le gris de la page poussé vers le violet de l'accent — le même raisonnement que `bg` ».
    /// `bg` ne penche plus de ce côté, donc cette phrase était devenue fausse. `#20180C` garde sa
    /// luminance — 17,54:1 sur une carte blanche contre 17,53.
    ///
    /// Un noir PUR ne ferait pas l'affaire, et c'est le vrai sujet : sur une page teintée il se
    /// lit comme un trait tracé par-dessus le dessin, là où la même valeur dans l'encre de la page
    /// se lit comme son bord.
    static let encreDeLaPage = Color(hex: 0x20180C)

    /// L'OMBRE D'UNE CARTE, à l'opacité qu'on lui demande.
    ///
    /// Une fonction et non une constante parce que l'aperçu des réglages en veut une plus marquée
    /// (0,3) que les cartes de l'app (0,16) — et parce qu'il RECOPIAIT la formule, encre et part
    /// comprises. `fond(pour:)` raconte dix lignes plus haut ce que la dernière copie de ce genre
    /// a coûté : l'aperçu a continué d'annoncer 7 % quand la valeur était passée à 3,5.
    ///
    /// Teintée de l'accent plutôt que grise : une ombre grise sur un sol coloré pose du sale
    /// dessus. Celle-ci partage sa famille avec le sol qu'elle assombrit.
    static func ombreDeCarte(_ opacite: Double) -> Color {
        melange(rose, sur: encreDeLaPage, part: 0.35).opacity(opacite)
    }

    /// L'ombre des cartes, et elle n'existe QUE dans l'habillage teinté.
    ///
    /// En `classique`, ce qui sépare une carte de la page est son filet : l'ombre portée a été
    /// retirée du système de design, et le filet est monté en même temps (voir `CardBackground`).
    /// Les deux changements n'ont de sens qu'ensemble, et c'est toujours vrai — en `trace` c'est
    /// l'inverse qui s'applique, le filet tombe et l'ombre revient.
    static var cardShadow: Color {
        guard habillage == .teinte else { return .clear }
        return isLight ? ombreDeCarte(0.16) : Color.black.opacity(0.45)
    }

    /// Le fond de PAGE, à poser à la racine d'un écran — un dégradé en clair, une couleur en
    /// sombre.
    ///
    /// En clair il est BLANC. Il était passé par un dégradé rose pâle → crème → menthe, hérité
    /// d'une direction artistique qui a été abandonnée ensuite ; le blanc est la valeur d'avant,
    /// reprise telle quelle.
    ///
    /// Ce que le dégradé réglait, le blanc le réglait déjà autrement : une carte blanche sur une
    /// page blanche ne se détache pas d'elle-même, donc `line` et `cardBorder` remontent à 11 %
    /// et 13 % — leurs valeurs de l'époque — et `card2` se réenfonce à `#EFEEF6`. Sur une page
    /// blanche, la profondeur est portée par le filet et la sous-surface, pas par le fond.
    ///
    /// `pageBackground` ÉTAIT un `LinearGradient` à deux arrêts identiques, « pour pouvoir
    /// repasser à un dégradé un jour sans toucher un seul appel ». On ne repassera pas : la règle
    /// 7 interdit le dégradé dans l'interface, et un type qui annonce un dégradé là où il n'y en a
    /// pas est une porte laissée ouverte sur trente-neuf écrans. C'est une couleur, et le type le
    /// dit. Les appels ne changent pas : `Color` est un `ShapeStyle` et une `View`, comme
    /// `LinearGradient`.
    static var pageBackground: Color { bg }
    /// Un cran plus ENFONCÉ que `bg` en clair, un cran plus haut en sombre — dans les deux cas
    /// « la rainure dans laquelle une pastille `card` vient se poser » (rail des sélecteurs
    /// segmentés). C'est la relation qui compte, pas la direction.
    static var bg2: Color { isLight ? Color(hex: 0xE8E6DF) : Color(hex: 0x121118) }

    // Theme-aware — follow the user's chosen accent (Profil → Apparence → Couleur de l'app, see
    // `AccentTheme`/`ThemeStore`).
    /// A light touch of the same light-mode darkening `rose2` already gets — `rose` is a whole
    /// accent swatch away from just "rose" (lime, cyan, amber are all pickable), and several of
    /// those swatches' `primary` are pale enough that white text on a `rose`-filled button, or
    /// `rose` used directly as text/icon color, reads weak on a white background. A lighter darken
    /// than `rose2`'s 0.14: this token still needs to look "vivid" as a fill, not muted like text.
    static var rose: Color { isLight ? AccentTheme.current.primaryOnLight : AccentTheme.current.primary }
    /// On a dark background this is a *lighter* tint (pops against near-black) — on a white
    /// background that same tint reads as too pale to use as text, so this darkens the base
    /// accent instead, to keep the same "accent, but for text" relationship in both directions.
    static var rose2: Color { isLight ? AccentTheme.current.lightOnLight : AccentTheme.current.light }
    /// Same reasoning as `rose` above — `violet` is `AccentTheme.current.tail`, and a couple of
    /// swatches' tails (lime → cyan, corail → amber) are similarly pale.
    static var violet: Color { isLight ? AccentTheme.current.tailOnLight : AccentTheme.current.tail }

    /// L'encre à poser SUR un aplat d'accent — blanche, ou sombre quand l'accent est trop clair
    /// pour porter du blanc.
    ///
    /// Le blanc était écrit en dur sur une quinzaine de surfaces (bouton principal, bulle de chat,
    /// pastilles, jours faits, onglet actif). Sur les palettes pâles du nuancier, ça donnait un
    /// libellé blanc sur fond pastel : « DÉMARRER » à **1,49:1** en Lime, 1,77 en Cyan, 1,82 en
    /// Ambre — trois palettes sur huit rendaient le bouton principal de l'app quasi illisible,
    /// présentées comme un simple choix esthétique.
    ///
    /// La règle existait déjà, seule, dans `AvatarView` : décider par la luminance plutôt que de
    /// coder en dur quelles palettes font exception. Elle vit ici désormais, pour que tous les
    /// aplats d'accent la partagent.
    static func onAccent(_ accent: Color) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(accent).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        // La même encre que `textPrimary` en clair, et c'est une SECONDE écriture de cette
        // valeur. Elle ne peut pas lire le jeton : `textPrimary` suit le thème, alors que l'encre
        // sur un aplat d'accent dépend de l'aplat et de rien d'autre — un bouton rose vif porte la
        // même encre que l'app soit en clair ou en sombre. Les deux ont basculé ensemble le
        // 12 novembre ; `check_encres.py` les tient maintenant d'accord.
        return luminance > 0.6 ? Color(hex: 0x181511) : .white
    }

    /// Le cas courant : l'encre sur un aplat de `rose`, l'accent principal.
    static var onRose: Color { onAccent(rose) }

    // Fixed semantic colors (readiness, coach, warnings) — meaning, not brand, so they don't
    // follow the accent theme. Deeper shades in light mode: the dark-mode values are tuned to pop
    // against near-black and would read as barely-visible text on white.
    static var lime: Color { isLight ? Color(hex: 0x6B9E00) : limeSombre }
    static var cyan: Color { isLight ? Color(hex: 0x0E9C8C) : cyanSombre }
    static var amber: Color { isLight ? Color(hex: 0xB86A00) : amberSombre }

    // ── LES MÊMES, POUR LA NUIT ──────────────────────────────────────────────────────────────
    //
    // Le commentaire juste au-dessus dit tout : « les valeurs du mode sombre sont calibrées pour
    // ressortir sur du presque-noir ». La nuit EST du presque-noir, dans les deux thèmes. Une
    // couleur sémantique posée dessus doit donc être la variante sombre, quel que soit le thème
    // de la page — sinon le point RECORD de la courbe d'allure, qui est en lime, tombe à 3,4:1
    // en thème clair au lieu de 13,8.
    //
    // Ces constantes ne sont pas des copies : ce sont LES valeurs, et les jetons ci-dessus les
    // lisent. Une valeur écrite deux fois diverge, c'est ce fichier qui le répète le plus souvent.
    static let limeSombre = Color(hex: 0xC8FF3D)
    static let cyanSombre = Color(hex: 0x38E0D0)
    static let amberSombre = Color(hex: 0xFFB03D)
    static let emberSombre = Color(hex: 0xFF6B5A)
    static let azureSombre = Color(hex: 0x5AA9FF)
    static let grapeSombre = Color(hex: 0x9B7CFF)
    /// Amber warning *text* on an amber-tinted card (`CoachView`'s error bubble) — the plain
    /// `amber` token is tuned for icons/accents, not for body text at length, same reasoning as
    /// `rose2` above.
    static var amberText: Color { isLight ? Color(hex: 0x8A5A00) : Color(hex: 0xFFD79A) }

    // Trois teintes ajoutées pour la palette des familles de séance (voir `SessionFamily.tint`).
    // Elles sont FIXES, comme les trois précédentes et pour la même raison, mais celle-ci compte
    // double : une famille de séance est une information, pas une décoration. Si « sortie longue »
    // empruntait le violet de l'accent, elle changerait de couleur quand on change de thème
    // d'accent — et la palette qu'on vient d'apprendre ne voudrait plus rien dire.
    //
    // Toutes tiennent au-dessus de 3:1 sur `card`, dans les deux thèmes : ember 6,4 / 5,5 —
    // azure 7,3 / 5,8 — grape 5,8 / 6,7.
    /// LE CYCLE A SA PROPRE TEINTE, et il n'en avait aucune.
    ///
    /// Les quatre phases empruntaient leurs couleurs ailleurs : `.menstrual` prenait `rose`,
    /// c'est-à-dire L'ACCENT DE LA COUREUSE — donc la phase menstruelle était rose pour l'une et
    /// vert lime pour celle qui a choisi le nuancier Lime. C'est exactement ce que le commentaire
    /// de `SessionFamily.tint` interdit vingt lignes plus bas : une information qui emprunte
    /// l'accent change de couleur quand on change de goût, et la palette ne veut plus rien dire.
    ///
    /// Les trois autres prenaient `lime`, `cyan` et `amber`, c'est-à-dire les teintes des
    /// FAMILLES DE SÉANCE. Un point lime disait « endurance » sur un écran et « phase
    /// folliculaire » sur l'autre.
    ///
    /// UNE SEULE TEINTE POUR LES QUATRE PHASES, et c'est une mesure, pas une simplification.
    /// L'app n'affiche jamais deux phases à la fois : on est dans une phase, elle est nommée en
    /// toutes lettres à côté du point. Quatre couleurs distinguaient donc des choses qu'on ne
    /// voit jamais ensemble — elles coûtaient quatre entrées de palette pour une différence que
    /// personne ne peut percevoir, puisqu'il n'y a rien à comparer.
    ///
    /// La teinte est celle que la direction artistique demande, `#F2B8A0`, et elle est ici telle
    /// quelle en SOMBRE. En clair elle donne 1,73:1 sur une carte blanche, loin des 3:1 d'un objet
    /// graphique et plus loin encore des 4,5 d'un texte — la branche claire descend donc à la même
    /// teinte, assez foncée pour être lue : 5,93:1 au pire des cinq fonds.
    static var cycle: Color { isLight ? Color(hex: 0x80462E) : Color(hex: 0xF2B8A0) }

    /// La surface douce du cycle, pour une carte ou un bandeau qui lui appartient.
    ///
    /// LA TEINTE DE LA DA, PAS SA LUMINOSITÉ, pour la troisième fois de la semaine. `#FDF1EC` a
    /// été dessiné contre le `#FBF9F7` du brief ; sur notre page chaude il donne **1,006:1**,
    /// c'est-à-dire rien du tout. La valeur retenue garde sa teinte — vert 12 et bleu 17 sous le
    /// rouge — et reprend la séparation qu'une sous-surface doit avoir : 1,179:1 sous une carte
    /// blanche, soit celle de `card2`.
    static var cycleSurface: Color { isLight ? Color(hex: 0xF6EAE5) : Color(hex: 0x130702) }

    static var ember: Color { isLight ? Color(hex: 0xC2352A) : emberSombre }
    static var azure: Color { isLight ? Color(hex: 0x0F62C8) : azureSombre }
    static var grape: Color { isLight ? Color(hex: 0x5B3FD6) : grapeSombre }

    // ── LES QUATRE JETONS DE TEXTE ───────────────────────────────────────────────────────────
    //
    // OPAQUES, ET DANS LA FAMILLE DU FOND. Les trois jetons secondaires étaient des opacités de
    // noir et de blanc — 0,72 / 0,62 / 0,22. Deux défauts, dont un seul se voyait.
    //
    // Le premier, mineur : une opacité se mélange à ce qui passe dessous, donc le même jeton ne
    // rend pas la même couleur selon la surface. `text3` sortait à #616161 sur une carte blanche
    // et à #5A595D sur la sous-surface lavande. Quatre points d'écart sur une seule voie —
    // négligeable à l'œil, mais c'est une couleur du système de design que le système de design
    // ne décide pas.
    //
    // Le second, celui qui se voit : les fonds ont une famille, et le texte sortait en GRIS
    // NEUTRE PUR. La règle était écrite au-dessus de `bg`, appliquée aux fonds, et pas aux 835
    // emplois de texte qui se posent dessus.
    //
    // LA RÈGLE EST « LA FAMILLE DU FOND », PAS « VIOLET ». Elle a été posée quand les fonds
    // clairs penchaient vers le violet, et les jetons clairs étaient donc violets. Le 12 novembre
    // le fond clair est passé au chaud — voir `bg` — et les jetons clairs ont suivi le même jour.
    // C'est la preuve que la règle est la bonne : elle a survécu au retournement de ce qu'elle
    // décrivait, et `check_jetons_de_texte.py` la vérifie en LISANT les fonds, sans jamais
    // nommer une famille.
    //
    // LA TEINTE EST CELLE DU BRIEF, PAS SA LUMINOSITÉ. Le brief demande #6B6473 en secondaire :
    // même signature de famille que nos fonds (bleu +8, vert −7), mais mesuré sur NOS surfaces il
    // tombe à 4,56:1 sur `bg2` et 4,81 sur `card2` — au-dessus du seuil, et en dessous de ce que
    // `text3` donnait déjà (5,76 et 5,89). Adopter la valeur telle quelle aurait fait reculer la
    // lisibilité pour gagner une teinte. On garde donc la DIRECTION (vert −6, bleu +8 en clair ;
    // vert −5, bleu +8 en sombre) et on résout la luminosité sous une contrainte : AUCUN FOND NE
    // PERD DE CONTRASTE. Un gris violet se détache moins d'un fond lavande qu'un gris neutre, donc
    // chaque valeur est calée sur le PIRE des quatre fonds et non sur le plus fréquent — calée sur
    // la carte blanche, `text3` serait tombé à 4,94:1 sur `bg2`.
    //
    // LA CONTRAINTE EST TENUE FOND PAR FOND, et pas sur la moyenne ni sur le minimum. Un premier
    // jet calé sur le minimum des quatre surfaces avait fait reculer `text4` sombre de 1,92 à
    // 1,75:1 sur `card2` sans que rien ne le signale : le minimum global était respecté, un fond
    // en particulier non. `check_jetons_de_texte.py` compare les cinq fonds un par un — les quatre
    // surfaces littérales et une BORNE du fond teinté — et imprime le tableau mesuré à chaque CI.
    // Aucun chiffre de contraste n'est donc recopié ici : il serait faux au premier réglage.
    //
    // `text4` ne colore pas du texte à lire — voir `check_contraste.py`, qui tient la liste fermée
    // de ses emplois. Ses 1,7:1 sont voulus, et il suit la famille pour la même raison que les
    // autres : un point médian gris neutre entre deux liens se voit, lui aussi.

    /// LE PRIMAIRE A BOUGÉ AU DEUXIÈME CHANTIER, ET C'EST LE GARDE QUI L'A VU.
    ///
    /// Au premier, il n'avait pas bougé, et la raison écrite ici était juste : `#15151C` portait
    /// le bleu 7 points au-dessus du rouge, donc il était déjà dans la famille des fonds lavande.
    /// Quand les fonds sont passés au chaud, cette phrase est devenue fausse sans que rien ne
    /// l'écrive — le primaire se retrouvait seul, froid, sur cinq fonds chauds.
    ///
    /// `check_jetons_de_texte.py` l'a refusé à la première exécution. Il ne nomme aucune couleur :
    /// il lit les fonds et compare les penchants. C'est exactement ce qu'on lui demande, et c'est
    /// pour ça que la règle est « la famille du fond » et jamais « violet » ni « chaud ».
    ///
    /// `#181511` garde la luminance de l'ancien — 18,19:1 sur une carte contre 18,17 — et
    /// retourne sa famille.
    ///
    /// En sombre il reste le BLANC PUR, hors famille et volontairement : le primaire sombre est
    /// le seul jeton dont on veut le maximum de lisibilité.
    static var textPrimary: Color { isLight ? Color(hex: 0x181511) : Color.white }
    static var text2: Color { isLight ? Color(hex: 0x443F3A) : Color(hex: 0xBBB6C3) }
    /// `text3` échouait au contraste dans LES DEUX thèmes — et le sombre, qui était alors le thème
    /// par défaut, était le pire des deux : 2,85:1 sur le fond de page contre 3,90 en clair, pour
    /// un seuil de 4,5. Le sombre passait même sous le seuil « gros texte » de 3:1.
    ///
    /// Ce n'est pas un jeton décoratif : c'est celui de 318 appels — tous les eyebrows, tous les
    /// libellés de métriques, tous les horodatages. Une passe précédente avait posé le diagnostic
    /// et n'avait relevé que la branche claire, à 0,5, ce qui ne suffisait pas non plus.
    ///
    /// Le passage à l'opaque conserve cette correction et l'améliore sur chacun des cinq fonds,
    /// dans les deux thèmes. `check_jetons_de_texte.py` le vérifie et imprime les valeurs.
    static var text3: Color { isLight ? Color(hex: 0x5B5651) : Color(hex: 0x9893A0) }
    static var text4: Color { isLight ? Color(hex: 0xB7B2AD) : Color(hex: 0x514C59) }

    /// A near-invisible opacity-on-white (was 0.035) reads as almost no card at all — dark mode's
    /// 0.045-on-near-black works because that background is already dark enough for a faint white
    /// wash to register; the same trick barely shows on white. A real (if still soft) off-white
    /// fill instead, matching the energy the "Midnight Rose" reference has via its own high-
    /// contrast dark cards.
    /// Opaque des deux côtés désormais. En sombre, `#16161C` — la valeur relevée sur les
    /// aperçus — remplace le voile blanc à 4,5 % : sur le nouveau fond `#0B0B0F`, le voile rendait
    /// une surface plus claire et plus froide que voulu, et sa translucidité laissait remonter ce
    /// qui passait dessous.
    static var card: Color { isLight ? Color(hex: 0xFFFFFF) : Color(hex: 0x16161F) }
    /// Sous-surface DANS une carte (ligne de classement, tuile de jour) : elle doit reculer par
    /// rapport à `card`, donc gris pâle sur une carte devenue blanche.
    /// Assombri à `#EFEEF6` : sur une page blanche c'est LUI qui porte la profondeur, puisque la
    /// carte ne peut plus le faire. 1,15:1 contre le blanc — faible dans l'absolu, mais c'est le
    /// maximum tolérable avant que la sous-surface ne devienne une carte à son tour.
    static var card2: Color { isLight ? Color(hex: 0xEEECE7) : Color(hex: 0x201F2A) }

    // ── LES DEUX SURFACES DE L'ÉCRAN DE SÉANCE ──────────────────────────────────────────────
    //
    // FIXES DANS LES DEUX THÈMES, et ce n'est pas un oubli. L'écran de course reste sombre même
    // en apparence claire : on le regarde dehors, en mouvement, à bout de bras, et un fond blanc
    // y perdrait le contraste que les chiffres demandent. Elles ne prennent donc PAS `isLight`.
    //
    // Elles vivaient dans un `enum Ink` au milieu de `LiveRunView`, avec leur raison. Deux
    // couleurs écrites dans un fichier de vue restent deux valeurs en dur dans un écran — règle
    // 4 — et surtout personne ne les trouve en ouvrant le système. Leur raison descend avec
    // elles ; `Ink` garde ce qui dépend vraiment de cet écran.

    /// Le fond des surfaces de l'écran de séance : la carte, le voile du bas.
    static let seanceSurface = Color(hex: 0x0E0E14)

    /// Le fond de l'écran de séance, DERRIÈRE les surfaces. Un cran plus sombre que
    /// `seanceSurface`, à quatre centièmes de bleu près — l'écart est volontairement minuscule,
    /// il ne sert qu'à poser les surfaces. Les deux étaient écrits à la main à des endroits
    /// différents, et deux noirs presque identiques écrits à la main sont la façon exacte dont on
    /// obtient, un jour, deux noirs visiblement différents.
    static let seanceFond = Color(hex: 0x0A0A0E)
    /// Laissé à 11 %, volontairement, alors que `cardBorder` juste en dessous tombe à 5 %.
    ///
    /// Les deux ne font pas le même travail, et c'est écrit dans ce fichier depuis longtemps :
    /// `cardBorder` DÉTOURE une carte — c'est lui qui fabriquait la grille de rectangles cerclés
    /// qu'on vient de retirer. `line` SÉPARE : filets entre colonnes de chiffres, lignes de liste,
    /// pistes de barres de progression. Baisser le second en même temps que le premier, c'était
    /// effacer des séparateurs qui font leur travail sous prétexte de retirer des contours qui ne
    /// le faisaient pas.
    static var line: Color { isLight ? Color.black.opacity(0.11) : Color.white.opacity(0.08) }

    /// Le contour d'une CARTE, distinct de `line`. Une carte blanche posée sur un fond gris est
    /// déjà séparée par le fond : lui garder le filet de `line` (noir à 14 %) sur 1 pt la
    /// redessinerait au trait, et l'écran redeviendrait une grille de rectangles cerclés. `line`
    /// reste inchangé partout où il sépare vraiment — filets entre colonnes de chiffres, lignes
    /// de liste, pistes de barres de progression.
    /// Remonté de 6 % à 10 % : à 6 % sur blanc le filet vaut 1,13:1, il ne dessine rien. Il
    /// reste une finition — le fond, désormais plus sombre, porte la séparation — mais une
    /// finition qu'on voit.
    /// Redescendu à 5 %, pour de bon cette fois. Sur un fond teinté, la carte se détache par sa
    /// COULEUR ; le filet n'a plus qu'à empêcher son bord de se dissoudre dans l'ombre. À 13 % il
    /// redessinait chaque carte au trait, et trois cartes empilées faisaient une grille.
    ///
    /// En sombre il tombe carrément à zéro : un contour clair sur une carte claire posée sur un
    /// fond noir ne finit rien, il souligne. C'est l'écart de luminosité qui sépare, comme sur
    /// toutes les interfaces sombres qui tiennent.
    /// ── L'OMBRE TOMBE, LE FILET REPREND LE TRAVAIL ───────────────────────────────────────
    ///
    /// Le filet était à 5 % parce qu'il ne portait RIEN : deux ombres posaient la carte, et un
    /// contour par-dessus n'aurait fait que la redessiner au trait. Les ombres parties, il reste
    /// seul, et 5 % de noir ne sépare pas un blanc d'un lavande à 96 % de luminosité.
    ///
    /// 10 %, DONC — mais pas 10 % de NOIR. C'est à cette valeur-là, en noir, que l'écran est
    /// devenu « une grille de rectangles cerclés » et que le filet avait été redescendu. Un noir
    /// pur sur une page teintée se lit comme un trait tracé par-dessus le dessin ; la même valeur
    /// dans l'encre de la page se lit comme son bord. C'est le changement, pas le pourcentage.
    ///
    /// L'encre est celle de la page — voir `encreDeLaPage`, qui porte la valeur et son histoire.
    /// Elle penche du même côté que le fond, et elle a changé de camp avec lui.
    static var cardBorder: Color {
        // En habillage teinté, le filet TOMBE : c'est l'ombre colorée qui sépare (voir
        // `cardShadow`). Garder les deux donnerait une carte cernée ET flottante, soit deux
        // réponses à la même question — exactement ce que la suppression de l'ombre avait
        // corrigé dans l'autre sens.
        guard habillage != .teinte else { return .clear }
        return isLight ? encreDeLaPage.opacity(0.10) : Color.clear
    }

    /// Mélange opaque de `color` dans `base`, exactement `color-mix(in srgb, color N%, base)` en CSS.
    ///
    /// La maquette n'utilise jamais une couleur d'accent translucide posée sur ce qui se trouve
    /// derrière : elle calcule un aplat opaque (`background: color-mix(in srgb, var(--ru-rose) 12%,
    /// var(--ru-bg))`). La différence est visible dès qu'une pastille se trouve SUR une carte —
    /// `card` (#F0F0F6 en clair) n'est pas `bg` (#FFFFFF) : un `rose.opacity(0.12)` translucide se
    /// teinte du gris de la carte, alors que le mélange sur `bg` reste plus clair que la carte et
    /// se détache comme une découpe. La maquette mélange TOUJOURS sur `--ru-bg` pour les pastilles,
    /// y compris celles posées sur une carte (`.follow-chip` vit dans `.suggest-card`) — d'où le
    /// `over:` explicite plutôt qu'un `.opacity()` implicite.
    ///
    /// Calculé en sRGB non-prémultiplié, comme `color-mix(in srgb, …)`. Les tokens d'accent étant
    /// des propriétés calculées lisant `ThemeStore`, appeler ce helper depuis un `body` enregistre
    /// la dépendance d'observation comme n'importe quel autre token — le mélange se recalcule seul
    /// au changement de thème ou d'accent.
    /// Aplatit une couleur éventuellement translucide sur `bg` (opaque dans les deux thèmes),
    /// pour obtenir la couleur qu'elle DONNE À VOIR plutôt que celle qu'elle déclare.
    ///
    /// Sans ça, `tint(_:_:over:)` lisait `card` en thème sombre — `Color.white.opacity(0.045)` —
    /// comme du BLANC PUR, parce que `getRed` rend les composantes non prémultipliées et que le
    /// mélange jetait l'alpha. Les deux cartes teintées du Profil, mélangées « sur card »,
    /// sortaient donc quasi blanches en mode sombre, avec du texte blanc dessus : illisibles.
    private static func flattened(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        guard a < 1 else { return (r, g, b) }
        var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
        UIColor(bg).getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
        return (r * a + pr * (1 - a), g * a + pg * (1 - a), b * a + pb * (1 - a))
    }

    static func tint(_ color: Color, _ amount: Double, over base: Color) -> Color {
        let c = flattened(color)
        let b = flattened(base)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(
            red: Double(c.r * t + b.r * (1 - t)),
            green: Double(c.g * t + b.g * (1 - t)),
            blue: Double(c.b * t + b.b * (1 - t))
        )
    }

    // `accentGradient` (rose2 → rose) et `violetRoseGradient` (violet → rose) VIVAIENT ICI, et
    // c'est de là qu'ils se répandaient : bouton principal, pastilles, barres de progression,
    // avatar du profil, tableau du club, paywall, bouton RUN de la barre d'onglets. Ils sont
    // partis. La règle 7 dit « aucun dégradé dans l'interface », et la direction artistique
    // réserve le rose → violet à l'icône, au splash et au logo — c'est-à-dire à `brandGradient`
    // ci-dessous, et à lui seul.
    //
    // Ce n'étaient pas vingt-quatre décisions d'écran : c'était UN jeton, recopié vingt-quatre
    // fois par des gens qui faisaient bien leur travail en appelant le système de design. C'est
    // la raison pour laquelle le brief dit « le design system d'abord ».
    //
    // Ce qui reste permis, et pourquoi, est écrit une fois pour toutes dans
    // `ci_scripts/check_degrade.py`, qui refuse tout dégradé hors de sa liste.

    /// LE SEUL DÉGRADÉ DE L'INTERFACE, et il ne peint que la marque.
    ///
    /// `AppMarkView` l'emploie pour le logo, qui est aussi ce que montrent l'icône et l'écran de
    /// lancement. La direction artistique le nomme explicitement, et seulement là.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [rose, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// LA SURFACE D'UNE CARTE HÉROS — un aplat, et plus un lavis.
    ///
    /// C'était un dégradé qui descendait d'un lavis d'accent à 12 % vers la couleur de la carte.
    /// Sa raison d'être n'a jamais été le dégradé lui-même, mais le fait qu'une carte héros se
    /// distingue des autres : un aplat le fait aussi bien, et la règle 7 tranche le reste.
    ///
    /// 6 % et non 12 % : le lavis descendait LINÉAIREMENT de 12 % à 0, donc sa moyenne sur la
    /// hauteur de la carte valait 6 %. Reprendre 12 % aurait doublé le poids perçu de onze cartes
    /// d'un coup. Même raisonnement en sombre, où le lavis partait de 10 %.
    ///
    /// Le lavis est DÉRIVÉ de l'accent courant, pas écrit en dur : avec huit palettes au choix
    /// (décision du 9 novembre, les huit restent), un gris ou un prune fixe serait faux pour sept
    /// personnes sur huit. Les deux branches sont tombées dans ce piège, à des moments différents.
    ///
    /// En clair il se pose sur `card`, la surface à laquelle la carte appartient ; en sombre sur
    /// `bg`, où sa teinte doit se fondre.
    static var heroSurface: Color {
        isLight ? tint(rose, 0.06, over: card) : tint(rose, 0.05, over: bg)
    }

    /// LE FOND SUR LEQUEL UN TRACÉ SE DESSINE, dans les DEUX thèmes.
    ///
    /// Il vivait en privé dans `ActivityFeedRow`, parce qu'un seul écran en avait besoin. Le
    /// bandeau de l'accueil en a besoin aussi, et une deuxième copie aurait divergé au premier
    /// réglage — c'est exactement ce qui est arrivé aux dix rayons et aux dix-neuf écarts.
    ///
    /// Il ne suit pas le thème, et c'est voulu : un tracé lumineux se lit sur du sombre. Posé
    /// sur du blanc, il faudrait l'assombrir, donc changer ses couleurs selon le thème — et
    /// l'app aurait deux tracés au lieu d'un. Une photo, elle non plus, ne s'éclaircit pas
    /// parce que la page est claire.
    ///
    /// C'était un dégradé diagonal de `#1A1926` à `#0E0D16` — une vignette, c'est-à-dire de la
    /// décoration, et la règle 7 l'interdit. `#14131E` est le milieu exact des deux : la nuit sur
    /// laquelle le tracé se lit est la même, elle n'est simplement plus dégradée.
    static var traceBackground: Color { Color(hex: 0x14131E) }

    // MARK: Ce qu'on pose SUR la nuit

    /// # LA NUIT NE SUIT PAS LE THÈME, ET CE QU'ON Y PEINT NE DOIT PAS LE SUIVRE NON PLUS
    ///
    /// `traceBackground` vaut `#14131E` dans les deux thèmes — c'est écrit juste au-dessus, et
    /// c'est juste. Mais le dessin posé dessus, lui, était peint avec les jetons de la page :
    /// `RUColor.textPrimary` pour l'anneau de départ, la trace fantôme et la tête du tracé.
    ///
    /// En thème clair, `textPrimary` vaut `#181511`. L'anneau de départ était donc du presque-noir
    /// à 85 % posé sur du presque-noir : sur la capture de l'accueil, il ne se lit pas comme un
    /// repère mais comme un TROU percé dans la lueur. La trace fantôme à 7 % disparaissait tout
    /// court. Le thème clair est le thème par défaut depuis la décision D2 : c'était donc le cas
    /// NORMAL.
    ///
    /// Même histoire pour l'accent. `RUColor.rose` rend `primaryOnLight` en thème clair, une
    /// valeur descendue par `meetingContrastOnWhite` pour rester lisible SUR DU BLANC. Sur la
    /// nuit, cette correction n'a aucun objet, et elle coûte — mesuré sur les huit nuanciers, en
    /// rapport de luminance contre `#14131E` :
    ///
    /// | nuancier | sombre | clair | perte |
    /// | --- | --- | --- | --- |
    /// | rose, violet, bleu, magenta | 4,23 à 5,55 | idem à 6 % près | ≤ 6 % |
    /// | corail | 5,94 | 5,25 | 12 % |
    /// | ambre | 10,10 | 5,26 | 48 % |
    /// | cyan | 10,37 | 5,25 | 49 % |
    /// | lime | 12,34 | 5,23 | 58 % |
    ///
    /// Le nuancier par défaut ne perdait presque rien, ce qui explique que personne ne l'ait vu :
    /// trois nuanciers sur huit perdaient la moitié de l'éclat de leur tracé, et ce sont
    /// précisément ceux que la maquette avait dû assombrir pour le blanc.
    ///
    /// D'où cette famille. Sur la nuit, on ne lit JAMAIS `textPrimary`, `rose`, `rose2` ni
    /// `violet` : on lit ce qui suit. `check_nuit.py` le tient.

    /// L'encre pleine sur la nuit : du blanc, dans les deux thèmes.
    static let surLaNuit = Color.white

    /// L'encre seconde sur la nuit — la date, les unités, ce qui accompagne un chiffre.
    ///
    /// 0,72 et pas 0,60 : c'est la valeur que le bandeau de l'accueil portait déjà en dur à trois
    /// endroits, elle est vérifiée sur capture depuis septembre, et la changer en la nommant
    /// aurait fait passer une retouche pour un rangement.
    static let surLaNuit2 = Color.white.opacity(0.72)

    /// L'encre d'appoint — un trait de grille, le reste d'un parcours pas encore couru.
    static let surLaNuit3 = Color.white.opacity(0.16)

    /// Les trois couleurs d'accent TELLES QU'ELLES SONT, sans la correction pour fond blanc.
    ///
    /// L'ordre est celui du dégradé du tracé : le clair part en bas à gauche, la queue arrive en
    /// haut à droite. Ce sont les variantes sombres quel que soit le thème, pour la raison dite
    /// plus haut — la nuit n'est pas du blanc, et une couleur assombrie pour du blanc y est
    /// seulement éteinte.
    static var accentsDeLaNuit: [Color] {
        [AccentTheme.current.light, AccentTheme.current.primary, AccentTheme.current.tail]
    }

    /// L'accent principal sur la nuit, quand un seul suffit.
    static var accentDeLaNuit: Color { AccentTheme.current.primary }
}

/// La palette des familles de séance : une couleur par famille, la même partout.
///
/// Elle vit ici, dans le système de design, et pas dans le modèle : `SessionFamily` doit rester
/// une classification d'entraînement, lisible et testable sans SwiftUI. C'est l'interface qui
/// décide de quelle couleur elle l'habille.
extension SessionFamily {
    var tint: Color {
        switch self {
        case .rest: return RUColor.text3
        case .recovery: return RUColor.cyan
        case .endurance: return RUColor.lime
        case .longRun: return RUColor.grape
        case .tempo: return RUColor.amber
        case .intervals: return RUColor.ember
        case .functional: return RUColor.azure
        }
    }

    /// Les mêmes sept, sur une carte de nuit.
    ///
    /// Six d'entre elles sont des couleurs sémantiques, dont le commentaire dit déjà que « les
    /// valeurs du mode sombre sont calibrées pour ressortir sur du presque-noir » — et la nuit
    /// EST du presque-noir, dans les deux thèmes. Le repos passe de `text3`, un gris sombre
    /// invisible sur `#14131E`, à du blanc très voilé : un jour sans séance doit se lire comme
    /// un creux, pas comme une absence de pixel.
    var tintSurLaNuit: Color {
        switch self {
        case .rest: return RUColor.surLaNuit.opacity(0.28)
        case .recovery: return RUColor.cyanSombre
        case .endurance: return RUColor.limeSombre
        case .longRun: return RUColor.grapeSombre
        case .tempo: return RUColor.amberSombre
        case .intervals: return RUColor.emberSombre
        case .functional: return RUColor.azureSombre
        }
    }

    /// Le symbole qui accompagne la couleur.
    ///
    /// Une couleur seule ne suffit pas : environ un homme sur douze distingue mal le rouge du
    /// vert, et ce sont précisément les deux extrémités de cette palette — le footing facile et le
    /// fractionné. Chaque famille porte donc aussi une forme.
    var symbol: String {
        switch self {
        case .rest: return "moon.zzz.fill"
        case .recovery: return "leaf.fill"
        case .endurance: return "figure.run"
        case .longRun: return "arrow.right.to.line"
        case .tempo: return "speedometer"
        case .intervals: return "bolt.fill"
        case .functional: return "dumbbell.fill"
        }
    }
}

/// La couleur d'un objectif, pour l'écran « TON PLAN » qui ferme l'inscription.
///
/// Elle vit ici et pas dans `GoalType` pour la même raison que `SessionFamily.tint` juste
/// au-dessus : `GoalType` doit rester un modèle d'entraînement, lisible et testable sans SwiftUI.
/// C'est l'interface qui décide de quelle couleur elle l'habille.
///
/// # DEUX COULEURS SONT PORTÉES PAR DEUX OBJECTIFS CHACUNE, ET C'EST VOLONTAIRE
///
/// La palette des familles de séance est FIXE parce qu'on en compare sept d'un coup, sur une même
/// semaine : deux familles de la même couleur s'y liraient comme la même chose. Un objectif ne se
/// compare à rien — on en a UN, et l'écran qui le montre n'en montre pas d'autre. Inventer trois
/// teintes de plus pour un écran qui n'en affiche jamais qu'une à la fois aurait élargi la palette
/// de l'app sans que personne ne puisse jamais voir la différence.
///
/// La course prend l'accent — c'est l'objectif principal de l'app, et la couleur que l'utilisatrice
/// choisira plus tard dans Profil → Apparence. Les huit autres prennent des teintes fixes, pour ne
/// pas changer de couleur avec le thème : le vert d'une reprise en douceur dit quelque chose du
/// geste, pas de la marque.
extension GoalType {
    var tint: Color {
        switch self {
        case .race: return RUColor.rose
        case .progress: return RUColor.azure
        case .restart: return RUColor.lime
        case .weight: return RUColor.ember
        case .health: return RUColor.amber
        // Les deux hybrides partagent le violet, et les deux épreuves « à plusieurs
        // disciplines » le bleu : si deux objectifs doivent porter la même teinte, autant que
        // ce soit ceux qui se ressemblent.
        case .hyrox: return RUColor.grape
        case .duathlon: return RUColor.grape
        case .ultraTrail: return RUColor.cyan
        case .triathlon: return RUColor.azure
        }
    }

    /// Le symbole de l'objectif, pour la même raison que `SessionFamily.symbol` juste au-dessus :
    /// une couleur seule ne suffit pas, et il faut une forme.
    ///
    /// # IL Y AVAIT UN EMOJI ICI, ET LE PREMIER ÉCRAN DE L'APP EN PORTAIT NEUF
    ///
    /// 🏁 📈 🌱 🔥 ⚡ 🏋️ ⛰️ 🏊 🚴, sur « POURQUOI TU COURS ? ». Un emoji n'est pas un élément
    /// d'identité : il est dessiné par le système, il change de style à chaque version d'iOS, il
    /// ne prend pas la teinte de l'objectif, et il ne ressemble à rien d'autre dans l'app — qui
    /// n'utilise que des symboles SF partout ailleurs.
    ///
    /// Sept des neuf noms ci-dessous étaient DÉJÀ employés ailleurs dans le dépôt, donc déjà
    /// éprouvés : « dumbbell.fill » est le symbole du renforcement, « mountain.2.fill » celui
    /// d'une course de trail, « leaf.fill » celui de la récupération. Les faire se répondre d'un
    /// écran à l'autre vaut mieux que d'en inventer neuf nouveaux.
    ///
    /// Deux changements de SENS, et non de dessin :
    ///
    ///   · la perte de poids portait 🔥, qui parle de dépense. Elle porte une BALANCE, qui est ce
    ///     qu'on regarde. Le feu, lui, revient à la série en cours, où il veut dire ce qu'il dit.
    ///   · « Rester en forme » portait ⚡, qui parle d'intensité — l'inverse de ce que cet
    ///     objectif propose. Il porte un cœur.
    ///
    /// `ci_scripts/check_symboles.py` et `SymbolesTests` garantissent que chacun de ces noms
    /// existe : un nom faux ne dessine rien, en silence, et c'est exactement le risque qu'on prend
    /// en écrivant neuf noms d'un coup.
    var symbole: String {
        switch self {
        case .race: return "flag.checkered"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .restart: return "leaf.fill"
        case .weight: return "scalemass"
        case .health: return "heart.fill"
        case .hyrox: return "dumbbell.fill"
        case .duathlon: return "bicycle"
        case .ultraTrail: return "mountain.2.fill"
        case .triathlon: return "figure.pool.swim"
        }
    }
}
