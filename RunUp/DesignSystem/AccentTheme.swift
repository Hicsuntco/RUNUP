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
        AccentTheme(id: "rose", name: "Rose", primary: Color(hex: 0xFF0A78), light: Color(hex: 0xFF4D9E), tail: Color(hex: 0x7C5CFF)),
        AccentTheme(id: "violet", name: "Violet", primary: Color(hex: 0x7C5CFF), light: Color(hex: 0xA78BFF), tail: Color(hex: 0xFF0A78)),
        AccentTheme(id: "bleu", name: "Bleu", primary: Color(hex: 0x3D8BFF), light: Color(hex: 0x8AB8FF), tail: Color(hex: 0x7C5CFF)),
        AccentTheme(id: "cyan", name: "Cyan", primary: Color(hex: 0x2FD9C4), light: Color(hex: 0x7CF0E4), tail: Color(hex: 0x3D8BFF)),
        AccentTheme(id: "lime", name: "Lime", primary: Color(hex: 0x9FE83D), light: Color(hex: 0xDFFF8C), tail: Color(hex: 0x2FD9C4)),
        AccentTheme(id: "amber", name: "Ambre", primary: Color(hex: 0xFFB03D), light: Color(hex: 0xFFD08A), tail: Color(hex: 0xFF4D9E)),
        AccentTheme(id: "corail", name: "Corail", primary: Color(hex: 0xFF5A3D), light: Color(hex: 0xFF9478), tail: Color(hex: 0xFFB03D)),
        AccentTheme(id: "magenta", name: "Magenta", primary: Color(hex: 0xD633B8), light: Color(hex: 0xF07ADB), tail: Color(hex: 0x7C5CFF))
    ]

    static let defaultID = "rose"

    static var current: AccentTheme {
        all.first { $0.id == ThemeStore.shared.themeID } ?? all[0]
    }

    /// Les trois valeurs claires de la palette de marque, fixées À LA MAIN.
    ///
    /// Elles venaient de la maquette, et `tail` (#7053E6) en vient toujours. Les deux roses, non :
    /// la maquette les donnait à la teinte 341, et c'est précisément cette teinte qui a été
    /// changée. Aucune formule ne les produit — ni la dérivation par assombrissement, ni la
    /// descente au seuil de contraste — donc elles sont écrites ici.
    ///
    /// # LE ROSE A CHANGÉ DE TEINTE, ET VOICI POURQUOI CE N'EST PAS L'ESSAI QUI AVAIT ÉCHOUÉ
    ///
    /// La famille était à la teinte 341 — un rose qui tire sur le rouge. Elle a été jugée
    /// « vieille » : juste, le rouge y domine et la rend sourde plutôt que vive.
    ///
    /// UN PREMIER ESSAI AVAIT DÉJÀ ÉCHOUÉ, et il faut le garder en tête. On avait remonté le rose
    /// clair de `#E60E52` à `#FF0F5B` — la VALEUR du mode sombre, à teinte inchangée — pour gagner
    /// en éclat. Sur un vrai téléphone, le résultat a été jugé pire : à la teinte 341, monter la
    /// valeur fait virer à l'orangé au lieu de paraître vif, parce que c'est le canal rouge, déjà
    /// saturé, qui prend tout. Le contraste y était pour quelque chose — 3,84:1 contre 4,62:1 —
    /// mais c'est le rendu qui avait tranché.
    ///
    /// Ce changement-ci va dans une AUTRE direction : la teinte, pas la valeur. Toute la famille
    /// descend de 341 à ~332, vers le magenta, et la saturation monte au maximum. C'est là que
    /// vivent les roses qu'on perçoit comme fluo — le bleu qu'on ajoute éloigne du rouge sans
    /// alourdir, alors que monter la valeur à teinte constante ne faisait que délaver vers
    /// l'orangé.
    ///
    /// | jeton                | avant     | après     | contraste sur blanc |
    /// |----------------------|-----------|-----------|---------------------|
    /// | clair `primary`      | `#E60E52` | `#F50D7A` | 4,62 → **4,02**     |
    /// | clair `light`/rose2  | `#F0356F` | `#FF1F85` | 3,86 → **3,63**     |
    /// | sombre `primary`     | `#FF0F5B` | `#FF0A78` | —                   |
    /// | sombre `light`       | `#FF4D7D` | `#FF4D9E` | —                   |
    ///
    /// Les deux valeurs claires perdent du contraste, et c'est le prix assumé de l'éclat. Elles
    /// restent au-dessus du plancher de 3,5 documenté plus bas, et `primary` reste au-dessus du
    /// 3,84 de l'essai refusé. Si celui-ci devait être refusé à son tour, LA LEÇON À EN TIRER
    /// SERAIT QUE CE N'EST PAS UNE QUESTION DE TEINTE NON PLUS — et il faudra alors chercher
    /// ailleurs que dans l'accent, comme le disait déjà la note précédente.
    ///
    /// `light` (le token `rose2`) reste le plus ÉCLATANT des deux : il sert à 74 endroits —
    /// l'anneau d'objectifs, l'onglet actif, le libellé RUN, les métriques de l'écran de course —
    /// et tous veulent de l'éclat. Il avait été passé une fois à une teinte profonde au motif
    /// qu'elle resterait lisible en petit texte : c'était une erreur de lecture du jeton, et
    /// l'assombrir revenait à réintroduire la fadeur à l'endroit précis d'où elle venait.
    ///
    /// LE NUANCIER « MAGENTA » A BOUGÉ AVEC. Il était à la teinte 325, à sept degrés du nouveau
    /// rose : deux pastilles presque identiques dans le sélecteur de thème. Il descend à 311,
    /// franchement vers le violet, ce qui rend les deux choix de nouveau distincts. Ce n'est pas
    /// une amélioration du magenta, c'est la réparation de ce que le déplacement du rose lui
    /// faisait.
    ///
    /// Seule la palette « rose » figure dans cette table : c'est la seule dont la maquette
    /// définisse une déclinaison claire à la main. Les sept autres suivent la règle
    /// multiplicative, qui conserve leur teinte.
    private static let mockupLightPalettes: [String: (primary: Color, light: Color, tail: Color)] = [
        "rose": (Color(hex: 0xF50D7A), Color(hex: 0xFF1F85), Color(hex: 0x7053E6))
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
