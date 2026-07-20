import SwiftUI
import UIKit

/// Lives in `Shared/` (compiles into both the `RunUp` app target and the `RunUpWidgets` extension)
/// rather than alongside `RUColor` in `RunUp/DesignSystem/Colors.swift` — this math is pure and
/// target-agnostic, so one copy here means a future fix to hex parsing or the darkening algorithm
/// reaches both targets automatically instead of needing to be applied twice (which is what
/// `RunUpWidgets/WidgetColor.swift` used to be, a hand-kept second copy of this exact code).
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
