import SwiftUI

/// Generic "press" tap feedback (subtle scale-down), applied to nearly every tappable element
/// in the prototype via the `.press` CSS class.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Full-width primary CTA — Bebas Neue label, rose fill, rose glow shadow. Class `.b.btn-rose`.
struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    var fill: AnyShapeStyle = AnyShapeStyle(RUColor.rose)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RUFont.bebas(16))
            .tracking(1)
            .foregroundColor(.white)
            // Padding first, `minHeight` second — the padding contributes to the natural size so
            // it only pads out to 44pt when needed, instead of stacking 24pt of padding on top of
            // an already-enforced 44pt frame (the order this had right after the tap-target fix,
            // which made every primary CTA ~68pt tall instead of the intended ~44-46pt).
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: RUColor.rose.opacity(isDisabled ? 0 : 0.3), radius: 16, x: 0, y: 4)
            .opacity(isDisabled ? 0.35 : (configuration.isPressed ? 0.85 : 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension PrimaryButtonStyle {
    /// Violet→rose gradient variant used on the Paywall CTA.
    static var violetRose: PrimaryButtonStyle {
        PrimaryButtonStyle(fill: AnyShapeStyle(RUColor.violetRoseGradient))
    }
}

/// Secondary full-width button — translucent card fill, used for "Déplacer à demain", "Plus tard" etc.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RUFont.sans(13, weight: .semibold))
            .foregroundColor(RUColor.textPrimary)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
