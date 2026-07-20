import SwiftUI
import UIKit

/// Shared layout pieces for onboarding steps — mirrors `ObScreen`/`ObTitle`/`ObNext`/`ObProgress`
/// in onboarding.jsx.
struct ObScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 22)
    }
}

struct ObTitle: View {
    var eyebrow: String
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: eyebrow, color: RUColor.rose)
            Text(title).displayStyle(30).foregroundColor(RUColor.textPrimary).lineSpacing(-2)
            if let subtitle {
                Text(subtitle)
                    .font(RUFont.sans(13))
                    .foregroundColor(RUColor.text2)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 18)
    }
}

struct ObNext: View {
    var label: String = "CONTINUER"
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
        }
        .buttonStyle(PrimaryButtonStyle(isDisabled: disabled))
        .disabled(disabled)
        // On top of whatever horizontal padding the screen around it already applies — a
        // full-bleed edge-to-edge CTA read as too heavy/dominant; this pulls it in further so it
        // sits with real breathing room instead of touching the screen's margins.
        .padding(.horizontal, 12)
        // OnboardingContainerView's root .ignoresSafeArea() (needed so the background bleeds
        // behind the notch/home indicator) also strips the bottom safe area from this button, so
        // a plain .padding(.bottom, 24) sits almost flush with the home indicator instead of
        // clearing it — safeAreaPadding re-adds that inset on top of the 24pt so the button sits
        // with real breathing room above it, like a normal app's CTA.
        .safeAreaPadding(.bottom, 24)
    }
}

struct ObProgress: View {
    var step: Int
    var total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? RUColor.rose : RUColor.line)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }
}

/// Text field styled to match `.card` inputs across onboarding.
struct ObTextField: View {
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(RUColor.text3))
            .keyboardType(keyboard)
            .font(RUFont.sans(16))
            .foregroundColor(RUColor.textPrimary)
            .padding(14)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }
}
