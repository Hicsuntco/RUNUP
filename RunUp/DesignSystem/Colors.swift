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
    /// Blanc pur en clair, demandé tel quel.
    ///
    /// La page est blanche, donc une carte blanche ne peut plus se détacher par sa COULEUR — il ne
    /// reste que le filet et l'ombre. C'est exactement la configuration qui avait produit la
    /// fadeur ; la différence est qu'on la choisit maintenant, et qu'on paie son prix ailleurs :
    /// `cardBorder` monte à 13 % (1,36:1, visible), l'ombre gagne un cran, et la profondeur passe
    /// par les SOUS-SURFACES à l'intérieur des cartes (`card2`), qui elles ont le droit d'être
    /// teintées.
    ///
    /// Un fond gris avec des cartes blanches sépare mieux, mécaniquement. Ce n'est pas ce qui est
    /// voulu ici.
    static var bg: Color { isLight ? Color(hex: 0xFFFFFF) : Color(hex: 0x0B0B0F) }

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
    /// `pageBackground` reste un dégradé du point de vue du TYPE, avec deux arrêts identiques des
    /// deux côtés : les 27 écrans qui l'utilisent à leur racine n'ont pas à savoir dans quel thème
    /// ils se trouvent, et repasser à un dégradé un jour ne touchera pas un seul appel.
    static var pageBackground: LinearGradient {
        LinearGradient(colors: [bg, bg], startPoint: .top, endPoint: .bottom)
    }
    /// Un cran plus ENFONCÉ que `bg` en clair, un cran plus haut en sombre — dans les deux cas
    /// « la rainure dans laquelle une pastille `card` vient se poser » (rail des sélecteurs
    /// segmentés). C'est la relation qui compte, pas la direction.
    static var bg2: Color { isLight ? Color(hex: 0xEDECF5) : Color(hex: 0x131319) }

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
        return luminance > 0.6 ? Color(hex: 0x15151C) : .white
    }

    /// Le cas courant : l'encre sur un aplat de `rose`, l'accent principal.
    static var onRose: Color { onAccent(rose) }

    // Fixed semantic colors (readiness, coach, warnings) — meaning, not brand, so they don't
    // follow the accent theme. Deeper shades in light mode: the dark-mode values are tuned to pop
    // against near-black and would read as barely-visible text on white.
    static var lime: Color { isLight ? Color(hex: 0x6B9E00) : Color(hex: 0xC8FF3D) }
    static var cyan: Color { isLight ? Color(hex: 0x0E9C8C) : Color(hex: 0x38E0D0) }
    static var amber: Color { isLight ? Color(hex: 0xB86A00) : Color(hex: 0xFFB03D) }
    /// Amber warning *text* on an amber-tinted card (`CoachView`'s error bubble) — the plain
    /// `amber` token is tuned for icons/accents, not for body text at length, same reasoning as
    /// `rose2` above.
    static var amberText: Color { isLight ? Color(hex: 0x8A5A00) : Color(hex: 0xFFD79A) }

    static var textPrimary: Color { isLight ? Color(hex: 0x15151C) : Color.white }
    static var text2: Color { isLight ? Color.black.opacity(0.72) : Color.white.opacity(0.68) }
    /// `text3` échouait au contraste dans LES DEUX thèmes — et le sombre, qui est le thème par
    /// défaut, était le pire des deux : 2,85:1 sur le fond de page contre 3,90 en clair, pour un
    /// seuil de 4,5. Le sombre passait même sous le seuil « gros texte » de 3:1.
    ///
    /// Ce n'est pas un jeton décoratif : c'est celui de 150 appels — tous les eyebrows, tous les
    /// libellés de métriques, tous les horodatages. Une passe précédente avait posé le diagnostic
    /// et n'avait relevé que la branche claire, à 0,5, ce qui ne suffisait pas non plus.
    ///
    /// Mesuré : clair 6,0–6,2:1, sombre 5,5–5,7:1 sur `bg`/`card`/`card2`. `text2` monte en
    /// parallèle (8,6–9,2:1) — sans quoi `text3` serait devenu PLUS foncé que lui et la hiérarchie
    /// des deux jetons se serait inversée.
    static var text3: Color { isLight ? Color.black.opacity(0.62) : Color.white.opacity(0.52) }
    static var text4: Color { isLight ? Color.black.opacity(0.22) : Color.white.opacity(0.2) }

    /// A near-invisible opacity-on-white (was 0.035) reads as almost no card at all — dark mode's
    /// 0.045-on-near-black works because that background is already dark enough for a faint white
    /// wash to register; the same trick barely shows on white. A real (if still soft) off-white
    /// fill instead, matching the energy the "Midnight Rose" reference has via its own high-
    /// contrast dark cards.
    /// Opaque des deux côtés désormais. En sombre, `#16161C` — la valeur relevée sur les
    /// aperçus — remplace le voile blanc à 4,5 % : sur le nouveau fond `#0B0B0F`, le voile rendait
    /// une surface plus claire et plus froide que voulu, et sa translucidité laissait remonter ce
    /// qui passait dessous.
    static var card: Color { isLight ? Color(hex: 0xFFFFFF) : Color(hex: 0x16161C) }
    /// Sous-surface DANS une carte (ligne de classement, tuile de jour) : elle doit reculer par
    /// rapport à `card`, donc gris pâle sur une carte devenue blanche.
    /// Assombri à `#EFEEF6` : sur une page blanche c'est LUI qui porte la profondeur, puisque la
    /// carte ne peut plus le faire. 1,15:1 contre le blanc — faible dans l'absolu, mais c'est le
    /// maximum tolérable avant que la sous-surface ne devienne une carte à son tour.
    static var card2: Color { isLight ? Color(hex: 0xEFEEF6) : Color(hex: 0x1F1F27) }
    static var line: Color { isLight ? Color.black.opacity(0.11) : Color.white.opacity(0.08) }

    /// Le contour d'une CARTE, distinct de `line`. Une carte blanche posée sur un fond gris est
    /// déjà séparée par le fond : lui garder le filet de `line` (noir à 14 %) sur 1 pt la
    /// redessinerait au trait, et l'écran redeviendrait une grille de rectangles cerclés. `line`
    /// reste inchangé partout où il sépare vraiment — filets entre colonnes de chiffres, lignes
    /// de liste, pistes de barres de progression.
    /// Remonté de 6 % à 10 % : à 6 % sur blanc le filet vaut 1,13:1, il ne dessine rien. Il
    /// reste une finition — le fond, désormais plus sombre, porte la séparation — mais une
    /// finition qu'on voit.
    /// Redescendu à 7 % : sur un fond désormais teinté, la carte blanche se détache par sa
    /// couleur, et le filet redevient une finition au lieu de porter la séparation à lui seul.
    static var cardBorder: Color { isLight ? Color.black.opacity(0.13) : Color.white.opacity(0.08) }

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

    /// L'équivalent du `--ru-gradient` de la maquette (`linear-gradient(135deg, rose2, rose)`) —
    /// le dégradé d'accent « une seule famille », à ne pas confondre avec `brandGradient`
    /// (rose → violet, deux familles).
    ///
    /// Ce couple `[rose2, rose]` était déjà recopié à l'identique dans `PrimaryButtonStyle` et
    /// `SelectableChip` ; il est nommé ici pour que les deux ne puissent plus diverger. Les points
    /// de départ/arrivée restent paramétrables parce que la maquette elle-même n'a pas une seule
    /// direction : 135° (diagonale) sur les surfaces à peu près carrées, et le CTA plein largeur
    /// garde volontairement sa version verticale (une diagonale sur un bouton large et bas se lit
    /// comme un dégradé horizontal, pas comme la diagonale voulue).
    static func accentGradient(from start: UnitPoint = .topLeading, to end: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(colors: [rose2, rose], startPoint: start, endPoint: end)
    }

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [rose, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroGradient: LinearGradient {
        // Light mode used to wash hero cards in pale pink — soft, but it's part of what read as
        // "gamified fitness app" rather than the neutral, premium register the light theme is
        // meant to carry now. A barely-there cool-gray wash instead, dark mode's own pink-black
        // tint (its energetic register is a deliberate, separate choice) is untouched.
        // Le dégradé clair descendait vers `bg`. Tant que `bg` était blanc, il rendait une carte
        // à peine grisée sur du blanc ; depuis que le fond de page est gris et les cartes
        // blanches, il aurait fini exactement de la couleur de la page — une carte hero
        // parfaitement invisible. En clair il descend donc vers `card`, la surface à laquelle
        // elle appartient. Le sombre garde son ancrage sur `bg` : c'est là que sa teinte
        // rose-noir doit se fondre.
        LinearGradient(
            // `#FBF8FB` était à 1,5 % du blanc : une carte annoncée « teintée rose » qui ne
            // l'était pas, et qui ne l'aurait de toute façon pas été pour les sept autres
            // palettes d'accent, ce gris étant écrit en dur. Un vrai lavis, dérivé de l'accent
            // courant, donc juste quelle que soit la couleur choisie dans Profil → Apparence.
            colors: [isLight ? tint(rose, 0.12, over: card) : Color(hex: 0x20101C), isLight ? card : bg],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var violetRoseGradient: LinearGradient {
        LinearGradient(colors: [violet, rose], startPoint: .leading, endPoint: .trailing)
    }
}
