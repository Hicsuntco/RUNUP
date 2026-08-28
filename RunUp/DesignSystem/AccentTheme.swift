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
    /// Le rose clair est `#E60E52`, la valeur de la maquette.
    ///
    /// Il avait été remplacé par `#FF0F5B`, celui du mode sombre, pour gagner en éclat. Vu sur un
    /// vrai téléphone, le résultat a été jugé pire : sur un fond blanc, ce rose-là vire au fluo et
    /// tire vers l'orangé au lieu de paraître vif. Le contraste y était aussi pour quelque chose —
    /// 3,84:1 contre 4,62:1 — mais c'est le rendu qui a tranché, pas la mesure.
    ///
    /// À retenir pour la prochaine fois : la fadeur de ce mode clair ne venait pas de la
    /// saturation de l'accent. Le chercher là était une erreur de diagnostic.
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
        "rose": (Color(hex: 0xE60E52), Color(hex: 0xF0356F), Color(hex: 0x7053E6))
    ]

    /// Le seuil de contraste que les accents doivent atteindre sur du blanc.
    ///
    /// 3,5:1 et pas 4,5:1 — le seuil WCAG AA du petit texte — et c'est un arbitrage assumé. Le
    /// rose de la marque est à 3,86:1 en `light` ; le pousser à 4,5 l'assombrit en bordeaux, ce
    /// qui a déjà été essayé et refusé, à juste titre : ce jeton sert à 74 endroits qui veulent
    /// tous de l'éclat (anneau d'objectifs, onglet actif, métriques en direct). Un seuil à 3,5
    /// ne touche AUCUNE des trois valeurs de la palette rose, ni celles du violet, du bleu, du
    /// magenta ou du corail. Il ne corrige que ce qui est cassé.
    ///
    /// Et ce qui était cassé l'était vraiment : lime à 1,87:1, ambre à 2,26, cyan à 2,20. Ce ne
    /// sont pas des accents un peu pâles, c'est du texte qui disparaît dans la page. Une
    /// utilisatrice qui choisissait le nuancier Lime obtenait un mode clair inutilisable.
    private static let lightContrastFloor = 3.5

    /// Les trois accents résolus pour le fond clair, calculés UNE fois par nuancier.
    ///
    /// La recherche dichotomique de `meetingContrastOnWhite` coûte une vingtaine de conversions
    /// de couleur ; `RUColor.rose` est lu à plus de mille endroits et à chaque redessin. Un `let`
    /// statique est initialisé paresseusement et une seule fois par Swift, donc le coût est payé
    /// au premier accès et jamais ensuite.
    private static let resolvedOnLight: [String: (primary: Color, light: Color, tail: Color)] = {
        var out: [String: (primary: Color, light: Color, tail: Color)] = [:]
        for theme in all {
            if let fixed = mockupLightPalettes[theme.id] { out[theme.id] = fixed; continue }
            let p = theme.primary.meetingContrastOnWhite(lightContrastFloor)
            // `light` reste distinct de `primary` : une fois les deux ramenés au même seuil, ils
            // tombaient sur la MÊME couleur, et la palette perdait un cran. Un cran plus sombre
            // plutôt qu'un cran plus clair — c'est l'inversion que ce fichier documente déjà pour
            // le fond clair, et ça ne peut que faire monter le contraste.
            out[theme.id] = (p, p.darkened(0.08), theme.tail.meetingContrastOnWhite(lightContrastFloor))
        }
        return out
    }()

    /// L'accent principal sur fond clair — celui de la maquette si elle en fixe un, sinon la
    /// teinte descendue juste assez pour être lisible.
    var primaryOnLight: Color { Self.resolvedOnLight[id]?.primary ?? primary }
    /// Le pendant de `light` sur fond clair (token `RUColor.rose2`).
    var lightOnLight: Color { Self.resolvedOnLight[id]?.light ?? light }
    /// Le pendant de `tail` sur fond clair (token `RUColor.violet`).
    var tailOnLight: Color { Self.resolvedOnLight[id]?.tail ?? tail }
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
