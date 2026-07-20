import SwiftUI

/// Selectable pill chip used throughout onboarding deep-dive steps and quick filters.
struct SelectableChip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(RUFont.sans(13, weight: .semibold))
                .foregroundColor(selected ? .white : RUColor.text2)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(selected ? RUColor.rose : RUColor.card, in: Capsule())
                .overlay(Capsule().stroke(selected ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Small static status badge — class `.chip` (e.g. "+1 palier", "Zone optimale", "▲ +2.1").
struct StatChip: View {
    var text: String
    var color: Color
    var background: Color? = nil

    var body: some View {
        Text(text)
            .font(RUFont.sans(10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background ?? color.opacity(0.14), in: Capsule())
    }
}

/// Value + label column — class `.metric` (duration/pace/zone triplets, etc.).
struct MetricColumn: View {
    var value: String
    var label: String
    var valueColor: Color = RUColor.textPrimary
    var valueSize: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).displayStyle(valueSize).foregroundColor(valueColor)
            Text(label)
                .font(RUFont.sans(9, weight: .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(RUColor.text2)
        }
    }
}
