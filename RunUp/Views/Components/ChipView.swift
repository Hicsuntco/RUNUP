import SwiftUI

/// Selectable pill chip used throughout onboarding deep-dive steps and quick filters (gender,
/// injuries, level, goal, race details...). One shared component, so a single visual pass here
/// covers every picker in the app at once instead of a dozen near-identical ones drifting apart.
struct SelectableChip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if selected {
                    // A small affordance beyond color alone — the flat rose fill used to be the
                    // only signal a chip was picked, easy to miss at a glance across a whole row.
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(LocalizedStringKey(label))
                    .font(RUFont.sans(13, weight: .semibold))
            }
            .foregroundColor(selected ? .white : RUColor.text2)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            // A flat solid fill read flat/dated — the same rose2→rose gradient the RUN button
            // already uses gives selection real depth without introducing a new accent.
            .background(
                selected
                    ? AnyShapeStyle(LinearGradient(colors: [RUColor.rose2, RUColor.rose], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(RUColor.card),
                in: Capsule()
            )
            .overlay(Capsule().stroke(selected ? Color.clear : RUColor.line, lineWidth: RUSpacing.hairline))
            .shadow(color: RUColor.rose.opacity(selected && !RUColor.isLight ? 0.3 : 0), radius: 10, x: 0, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Small static status badge — class `.chip` (e.g. "+1 palier", "Zone optimale", "▲ +2.1").
struct StatChip: View {
    var text: String
    var color: Color
    var background: Color? = nil

    var body: some View {
        Text(LocalizedStringKey(text))
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
            Text(LocalizedStringKey(label))
                .font(RUFont.sans(9, weight: .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(RUColor.text2)
        }
        // Reused across Home, Live, Stats, and History — a single fix here covers every duration/
        // pace/zone/metric pair in the app at once. Without this, VoiceOver read the value and its
        // label as two disconnected stops ("8:32" ... several stops later ... "ALLURE"); the
        // explicit label puts them in "name, value" order for clarity rather than relying on
        // `.combine`'s default top-to-bottom concatenation (value first, unit-less, then label).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(label)) + Text(", ") + Text(value))
    }
}
