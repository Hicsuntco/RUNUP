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
    static var bg: Color { isLight ? Color(hex: 0xF4F4F8) : Color(hex: 0x0E0E14) }
    /// Un cran plus ENFONCÉ que `bg` en clair, un cran plus haut en sombre — dans les deux cas
    /// « la rainure dans laquelle une pastille `card` vient se poser » (rail des sélecteurs
    /// segmentés). C'est la relation qui compte, pas la direction.
    static var bg2: Color { isLight ? Color(hex: 0xE9E9F0) : Color(hex: 0x15151E) }

    // Theme-aware — follow the user's chosen accent (Profil → Apparence → Couleur de l'app, see
    // `AccentTheme`/`ThemeStore`).
    /// A light touch of the same light-mode darkening `rose2` already gets — `rose` is a whole
    /// accent swatch away from just "rose" (lime, cyan, amber are all pickable), and several of
    /// those swatches' `primary` are pale enough that white text on a `rose`-filled button, or
    /// `rose` used directly as text/icon color, reads weak on a white background. A lighter darken
    /// than `rose2`'s 0.14: this token still needs to look "vivid" as a fill, not muted like text.
    static var rose: Color { isLight ? AccentTheme.current.primary.darkened(0.10) : AccentTheme.current.primary }
    /// On a dark background this is a *lighter* tint (pops against near-black) — on a white
    /// background that same tint reads as too pale to use as text, so this darkens the base
    /// accent instead, to keep the same "accent, but for text" relationship in both directions.
    static var rose2: Color { isLight ? AccentTheme.current.primary.darkened(0.14) : AccentTheme.current.light }
    /// Same reasoning as `rose` above — `violet` is `AccentTheme.current.tail`, and a couple of
    /// swatches' tails (lime → cyan, corail → amber) are similarly pale.
    static var violet: Color { isLight ? AccentTheme.current.tail.darkened(0.10) : AccentTheme.current.tail }

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
    static var text2: Color { isLight ? Color.black.opacity(0.55) : Color.white.opacity(0.5) }
    /// Light-mode value was 0.38 — roughly a 2.7:1 contrast ratio against `bg`'s white, well under
    /// WCAG's 4.5:1 for normal text, even though this token is read as real caption/timestamp text
    /// (not purely decorative) all over the app. 0.5 brings that to ~4:1 while staying visibly
    /// lighter than `text2`'s 0.55, preserving the two tokens' hierarchy.
    static var text3: Color { isLight ? Color.black.opacity(0.5) : Color.white.opacity(0.32) }
    static var text4: Color { isLight ? Color.black.opacity(0.22) : Color.white.opacity(0.2) }

    /// A near-invisible opacity-on-white (was 0.035) reads as almost no card at all — dark mode's
    /// 0.045-on-near-black works because that background is already dark enough for a faint white
    /// wash to register; the same trick barely shows on white. A real (if still soft) off-white
    /// fill instead, matching the energy the "Midnight Rose" reference has via its own high-
    /// contrast dark cards.
    static var card: Color { isLight ? Color(hex: 0xFFFFFF) : Color.white.opacity(0.045) }
    /// Sous-surface DANS une carte (ligne de classement, tuile de jour) : elle doit reculer par
    /// rapport à `card`, donc gris pâle sur une carte devenue blanche.
    static var card2: Color { isLight ? Color(hex: 0xF1F1F6) : Color.white.opacity(0.03) }
    static var line: Color { isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.08) }

    /// Le contour d'une CARTE, distinct de `line`. Une carte blanche posée sur un fond gris est
    /// déjà séparée par le fond : lui garder le filet de `line` (noir à 14 %) sur 1 pt la
    /// redessinerait au trait, et l'écran redeviendrait une grille de rectangles cerclés. `line`
    /// reste inchangé partout où il sépare vraiment — filets entre colonnes de chiffres, lignes
    /// de liste, pistes de barres de progression.
    static var cardBorder: Color { isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.08) }

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
    static func tint(_ color: Color, _ amount: Double, over base: Color) -> Color {
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        UIColor(color).getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
        UIColor(base).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(
            red: Double(cr * t + br * (1 - t)),
            green: Double(cg * t + bg * (1 - t)),
            blue: Double(cb * t + bb * (1 - t))
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
            colors: [isLight ? Color(hex: 0xFBF8FB) : Color(hex: 0x20101C), isLight ? card : bg],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var violetRoseGradient: LinearGradient {
        LinearGradient(colors: [violet, rose], startPoint: .leading, endPoint: .trailing)
    }
}
