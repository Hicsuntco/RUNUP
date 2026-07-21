import SwiftUI

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
    static var text3: Color { isLight ? Color.black.opacity(0.38) : Color.white.opacity(0.32) }
    static var text4: Color { isLight ? Color.black.opacity(0.22) : Color.white.opacity(0.2) }

    /// A near-invisible opacity-on-white (was 0.035) reads as almost no card at all — dark mode's
    /// 0.045-on-near-black works because that background is already dark enough for a faint white
    /// wash to register; the same trick barely shows on white. A real (if still soft) off-white
    /// fill instead, matching the energy the "Midnight Rose" reference has via its own high-
    /// contrast dark cards.
    static var card: Color { isLight ? Color(hex: 0xF0F0F6) : Color.white.opacity(0.045) }
    static var card2: Color { isLight ? Color(hex: 0xE7E7EF) : Color.white.opacity(0.03) }
    static var line: Color { isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.08) }

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [rose, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [isLight ? Color(hex: 0xF7D2E4) : Color(hex: 0x20101C), bg], startPoint: .top, endPoint: .bottom)
    }

    static var violetRoseGradient: LinearGradient {
        LinearGradient(colors: [violet, rose], startPoint: .leading, endPoint: .trailing)
    }
}
