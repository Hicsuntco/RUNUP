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
    private init() {}
}
