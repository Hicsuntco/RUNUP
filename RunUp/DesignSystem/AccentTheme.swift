import SwiftUI
import Observation

/// One swatch in the "nuancier" a user can pick as their app's accent color, from
/// Profil → Apparence. Each entry supplies the same 3-color relationship the app's original
/// fixed rose/rose2/violet trio had (a primary, a lighter tint of it, and a contrasting "tail"
/// used at the far end of gradients) so every existing `RUColor.rose`/`.rose2`/`.violet` call
/// site re-themes coherently without any of those call sites needing to change.
struct AccentTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let primary: Color
    let light: Color
    let tail: Color

    static let all: [AccentTheme] = [
        AccentTheme(id: "rose", name: "Rose", primary: Color(hex: 0xFF0F5B), light: Color(hex: 0xFF4D7D), tail: Color(hex: 0x7C5CFF)),
        AccentTheme(id: "violet", name: "Violet", primary: Color(hex: 0x7C5CFF), light: Color(hex: 0xA78BFF), tail: Color(hex: 0xFF0F5B)),
        AccentTheme(id: "bleu", name: "Bleu", primary: Color(hex: 0x3D8BFF), light: Color(hex: 0x8AB8FF), tail: Color(hex: 0x7C5CFF)),
        AccentTheme(id: "cyan", name: "Cyan", primary: Color(hex: 0x2FD9C4), light: Color(hex: 0x7CF0E4), tail: Color(hex: 0x3D8BFF)),
        AccentTheme(id: "lime", name: "Lime", primary: Color(hex: 0x9FE83D), light: Color(hex: 0xDFFF8C), tail: Color(hex: 0x2FD9C4)),
        AccentTheme(id: "amber", name: "Ambre", primary: Color(hex: 0xFFB03D), light: Color(hex: 0xFFD08A), tail: Color(hex: 0xFF4D7D)),
        AccentTheme(id: "corail", name: "Corail", primary: Color(hex: 0xFF5A3D), light: Color(hex: 0xFF9478), tail: Color(hex: 0xFFB03D)),
        AccentTheme(id: "magenta", name: "Magenta", primary: Color(hex: 0xE0399B), light: Color(hex: 0xFF7ACB), tail: Color(hex: 0x7C5CFF))
    ]

    static let defaultID = "rose"

    static var current: AccentTheme {
        all.first { $0.id == ThemeStore.shared.themeID } ?? all[0]
    }

    /// Les valeurs claires que la maquette fixe À LA MAIN pour la palette de marque.
    ///
    /// Depuis que `darkened()` multiplie au lieu de soustraire, la dérivation retombe d'elle-même
    /// sur les valeurs de la maquette pour `primary` (#E60E52) et `tail` (#7053E6). Le troisième,
    /// `light` — le token `rose2` — ne suit aucune règle : la maquette y déclare `#F0356F`, une
    /// version à la fois plus sombre ET plus saturée de `#FF4D7D`, choisie à l'œil. Aucune
    /// formule ne la produit, donc elle est écrite ici.
    ///
    /// Seule la palette « rose » figure dans cette table : c'est la seule dont la maquette
    /// définisse une déclinaison claire. Les sept autres suivent la règle multiplicative, qui
    /// conserve leur teinte.
    /// Le rose clair est désormais CELUI DU MODE SOMBRE, `#FF0F5B`, et non plus sa version
    /// assombrie `#E60E52`.
    ///
    /// Assombrir pour gagner du contraste enlève de l'éclat : c'est mécanique, et c'est ce qui
    /// faisait dire de ce mode clair qu'il était fade. `#FF0F5B` sur blanc vaut 3,84:1 — au-dessus
    /// du seuil de 3:1 pour un élément graphique ou du gros texte, en dessous des 4,5:1 exigés
    /// pour du petit texte. Le compromis est assumé, et il est nommé ici plutôt que découvert.
    ///
    /// `light` (le token `rose2`) reste ÉCLATANT, `#F0356F` — la valeur de la maquette, 3,86:1,
    /// soit exactement le contraste du rose principal.
    ///
    /// Il avait été passé à `#D40B4A`, une teinte profonde, au motif qu'elle resterait lisible en
    /// petit texte. C'était une erreur de lecture du jeton : `rose2` est employé à 74 endroits —
    /// l'anneau d'objectifs, l'onglet actif, le libellé RUN, les métriques de l'écran de course —
    /// et tous veulent de l'éclat. L'assombrir revenait à réintroduire la fadeur à l'endroit
    /// précis d'où elle venait, sous couvert de l'améliorer.
    ///
    /// Seule la palette « rose » est traitée ainsi. Les sept autres gardent la dérivation par
    /// assombrissement : lime, ambre et cyan à pleine intensité seraient illisibles sur blanc,
    /// leurs teintes étant intrinsèquement claires.
    private static let mockupLightPalettes: [String: (primary: Color, light: Color, tail: Color)] = [
        "rose": (Color(hex: 0xFF0F5B), Color(hex: 0xF0356F), Color(hex: 0x7053E6))
    ]

    /// L'accent principal sur fond clair — celui de la maquette si elle en fixe un, sinon la
    /// version assombrie qui conserve la teinte.
    var primaryOnLight: Color { Self.mockupLightPalettes[id]?.primary ?? primary.darkened(0.10) }
    /// Le pendant de `light` sur fond clair (token `RUColor.rose2`).
    ///
    /// Le repli assombrit `primary` et non `light`, contrairement à ce que fait la maquette pour
    /// la palette de marque. C'est délibéré et documenté dans `RUColor.rose2` : sur fond sombre
    /// `light` est une teinte ÉCLAIRCIE, et plusieurs palettes (lime, ambre, cyan) l'ont si pâle
    /// qu'assombrie de 14 % elle resterait illisible en texte sur du blanc. Le rose, lui, a sa
    /// valeur exacte dans la table ci-dessus, donc il n'a pas besoin de ce repli.
    var lightOnLight: Color { Self.mockupLightPalettes[id]?.light ?? primary.darkened(0.14) }
    /// Le pendant de `tail` sur fond clair (token `RUColor.violet`).
    var tailOnLight: Color { Self.mockupLightPalettes[id]?.tail ?? tail.darkened(0.10) }
}

/// Live holder for the chosen accent theme's id, read by `RUColor`'s theme-aware tokens from
/// anywhere in the app without threading `@Environment(AppState.self)` through every file that
/// uses a brand color — the Observation framework tracks access to this object's properties
/// during any view's `body`, however that reference was obtained, so `RUColor.rose` etc. stay
/// reactive with zero call-site changes. `AppState` mirrors `UserProfile.accentThemeID` (the
/// persisted source of truth) into this on load; `ProfileView`'s picker updates both together.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()
    var themeID: String = AccentTheme.defaultID
    /// Mirrors `UserProfile.isLightMode` the same way `themeID` mirrors `accentThemeID` — see
    /// `RUColor`'s theme-aware tokens.
    var isLightMode: Bool = false
    private init() {}
}
