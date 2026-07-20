import SwiftUI
import UIKit

/// Deliberately not shared with `RunUp/DesignSystem/Colors.swift` — that file already defines
/// `Color(hex:)`/`.darkened(_:)` inside the main app target, and `Shared/` files compile into
/// *both* targets, so redeclaring the same members there would collide with the app's own copy.
/// This tiny widget-only duplicate keeps the two targets fully decoupled instead.
extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    func darkened(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: max(0, r - amount), green: max(0, g - amount), blue: max(0, b - amount), opacity: a)
    }
}
