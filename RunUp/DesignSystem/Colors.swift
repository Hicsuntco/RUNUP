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

    static var bg: Color { isLight ? Color(hex: 0xFFFFFF) : Color(hex: 0x0E0E14) }
    static var bg2: Color { isLight ? Color(hex: 0xF2F2F6) : Color(hex: 0x15151E) }

    // Theme-aware — follow the user's chosen accent (Profil → Apparence → Couleur de l'app, see
    // `AccentTheme`/`ThemeStore`).
    static var rose: Color { AccentTheme.current.primary }
    /// On a dark background this is a *lighter* tint (pops against near-black) — on a white
    /// background that same tint reads as too pale to use as text, so this darkens the base
    /// accent instead, to keep the same "accent, but for text" relationship in both directions.
    static var rose2: Color { isLight ? AccentTheme.current.primary.darkened(0.14) : AccentTheme.current.light }
    static var violet: Color { AccentTheme.current.tail }

    // Fixed semantic colors (readiness, coach, warnings) — meaning, not brand, so they don't
    // follow the accent theme. Deeper shades in light mode: the dark-mode values are tuned to pop
    // against near-black and would read as barely-visible text on white.
    static var lime: Color { isLight ? Color(hex: 0x6B9E00) : Color(hex: 0xC8FF3D) }
    static var cyan: Color { isLight ? Color(hex: 0x0E9C8C) : Color(hex: 0x38E0D0) }
    static var amber: Color { isLight ? Color(hex: 0xB86A00) : Color(hex: 0xFFB03D) }

    static var textPrimary: Color { isLight ? Color(hex: 0x15151C) : Color.white }
    static var text2: Color { isLight ? Color.black.opacity(0.55) : Color.white.opacity(0.5) }
    static var text3: Color { isLight ? Color.black.opacity(0.38) : Color.white.opacity(0.32) }
    static var text4: Color { isLight ? Color.black.opacity(0.22) : Color.white.opacity(0.2) }

    static var card: Color { isLight ? Color.black.opacity(0.035) : Color.white.opacity(0.045) }
    static var card2: Color { isLight ? Color.black.opacity(0.025) : Color.white.opacity(0.03) }
    static var line: Color { isLight ? Color.black.opacity(0.09) : Color.white.opacity(0.08) }

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [rose, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [isLight ? Color(hex: 0xFBEFF5) : Color(hex: 0x20101C), bg], startPoint: .top, endPoint: .bottom)
    }

    static var violetRoseGradient: LinearGradient {
        LinearGradient(colors: [violet, rose], startPoint: .leading, endPoint: .trailing)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Pushes RGB channels down uniformly — used to turn a dark-mode "light tint" accent (see
    /// `RUColor.rose2`) into something with real contrast as text on a white background, without
    /// hand-authoring a second value per accent swatch.
    func darkened(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: max(0, r - amount), green: max(0, g - amount), blue: max(0, b - amount), opacity: a)
    }
}
