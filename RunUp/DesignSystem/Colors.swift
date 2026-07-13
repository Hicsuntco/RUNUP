import SwiftUI

/// Design tokens — see design_handoff_runup_app/README.md § Design Tokens / Colors.
enum RUColor {
    static let bg = Color(hex: 0x0E0E14)
    static let bg2 = Color(hex: 0x15151E)

    static let rose = Color(hex: 0xFF0F5B)
    static let rose2 = Color(hex: 0xFF4D7D)
    static let violet = Color(hex: 0x7C5CFF)
    static let lime = Color(hex: 0xC8FF3D)
    static let cyan = Color(hex: 0x38E0D0)
    static let amber = Color(hex: 0xFFB03D)

    static let textPrimary = Color.white
    static let text2 = Color.white.opacity(0.5)
    static let text3 = Color.white.opacity(0.32)
    static let text4 = Color.white.opacity(0.2)

    static let card = Color.white.opacity(0.045)
    static let card2 = Color.white.opacity(0.03)
    static let line = Color.white.opacity(0.08)

    static let brandGradient = LinearGradient(
        colors: [rose, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x20101C), bg],
        startPoint: .top,
        endPoint: .bottom
    )

    static let violetRoseGradient = LinearGradient(
        colors: [violet, rose],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
