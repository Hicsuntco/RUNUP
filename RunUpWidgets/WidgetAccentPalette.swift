import SwiftUI

/// Mirrors just the hex triples from the app's `AccentTheme.all`
/// (`RunUp/DesignSystem/AccentTheme.swift`) — duplicated by hand rather than shared across the
/// app/widget target boundary, since the live `ThemeStore`/`RUColor` machinery is an in-process
/// `@Observable` singleton the widget's separate process could never actually receive live updates
/// from anyway. Keep in sync by hand if `AccentTheme.all`'s hex values ever change.
enum WidgetAccentPalette {
    private static let swatches: [String: (primary: UInt32, light: UInt32, tail: UInt32)] = [
        "rose": (0xFF0F5B, 0xFF4D7D, 0x7C5CFF),
        "violet": (0x7C5CFF, 0xA78BFF, 0xFF0F5B),
        "bleu": (0x3D8BFF, 0x8AB8FF, 0x7C5CFF),
        "cyan": (0x2FD9C4, 0x7CF0E4, 0x3D8BFF),
        "lime": (0x9FE83D, 0xDFFF8C, 0x2FD9C4),
        "amber": (0xFFB03D, 0xFFD08A, 0xFF4D7D),
        "corail": (0xFF5A3D, 0xFF9478, 0xFFB03D),
        "magenta": (0xE0399B, 0xFF7ACB, 0x7C5CFF)
    ]

    /// [rose2, rose, violet], in that order — same order `DailyGoalsBarsView.fillColors` returns
    /// in-app, so the widget's ring reads identically to the in-app one for the same profile.
    static func ringColors(themeID: String, isLight: Bool) -> [Color] {
        let swatch = swatches[themeID] ?? swatches["rose"]!
        let primary = Color(hex: swatch.primary)
        let light = Color(hex: swatch.light)
        let tail = Color(hex: swatch.tail)
        let rose2 = isLight ? primary.darkened(0.14) : light
        return [rose2, primary, tail]
    }
}
