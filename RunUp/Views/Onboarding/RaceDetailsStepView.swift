import SwiftUI

/// Step 3 for the "race" goal: distance → target time → race date. Mirrors the `isRace` branch
/// of step 3 in onboarding.jsx.
struct RaceDetailsStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ObScreen {
            ScrollView {
                ObTitle(eyebrow: "Étape 3 · ta course", title: "QUELLE COURSE ?", subtitle: "Route, trail, obstacle… précise ce que tu prépares.")

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(RaceDistance.allCases) { d in
                        Button(action: { vm.selectDistance(d) }) {
                            Text(d.label)
                                .displayStyle(d == .other ? 16 : 22)
                                .foregroundColor(vm.distance == d ? RUColor.rose2 : RUColor.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(vm.distance == d ? RUColor.rose.opacity(0.12) : RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(vm.distance == d ? RUColor.rose.opacity(0.4) : RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                        .buttonStyle(PressableStyle())
                        .gridCellColumns(d == .other ? 2 : 1)
                    }
                }
                .padding(.top, 20)

                if vm.distance == .other {
                    ObTextField(placeholder: "Ex. Trail 22 km, Ekiden, 15 km…", text: $vm.customDistance)
                        .padding(.top, 12)
                }

                if vm.distance != nil {
                    EyebrowLabel(text: "Ton objectif chrono", color: RUColor.text3)
                        .padding(.top, 22).padding(.bottom, 10)
                    ChipFlowLayout {
                        if vm.distance != .other {
                            ForEach(vm.distance?.chronoPresets ?? [], id: \.self) { t in
                                SelectableChip(label: t, selected: vm.chrono == t && !vm.isCustomChrono) {
                                    vm.chrono = t; vm.isCustomChrono = false
                                }
                            }
                        }
                        SelectableChip(label: "Juste finir 😅", selected: vm.chrono == "finir" && !vm.isCustomChrono) {
                            vm.chrono = "finir"; vm.isCustomChrono = false
                        }
                        SelectableChip(label: "Mon propre temps", selected: vm.isCustomChrono) {
                            vm.isCustomChrono = true; vm.chrono = ""
                        }
                    }

                    if vm.isCustomChrono {
                        ObTextField(placeholder: "Ex. 1:52:00", text: Binding(get: { vm.chrono ?? "" }, set: { vm.chrono = $0 }))
                            .padding(.top, 10)
                    }

                    EyebrowLabel(text: "Date de la course", color: RUColor.text3)
                        .padding(.top, 22).padding(.bottom, 10)
                    DatePicker(
                        "",
                        selection: Binding(get: { vm.raceDate ?? Calendar.current.date(byAdding: .day, value: 60, to: .now)! }, set: { vm.raceDate = $0 }),
                        in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(RUColor.colorScheme)
                    .padding(13)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))

                    if let days = vm.daysUntilRace {
                        Text("J-\(days)").font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.rose2).padding(.top, 10)
                    }
                }

                WellbeingFieldsView(vm: vm)
            }
            ObNext(disabled: !vm.canProceed(fromStep: 3), action: onNext)
        }
    }
}

/// Simple wrapping flow layout for chip groups (iOS 16+ `Layout` protocol).
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 7

    // `sizeThatFits` and `placeSubviews` must wrap chips onto IDENTICAL rows, or the parent stack
    // reserves the wrong height for whatever this reports and the next sibling overlaps the last
    // row (exactly what happened before this fix: a card's caption text drawn on top of a wrapped
    // "Autre" chip in Profil → Santé & blessures). The old code defaulted an unspecified
    // `proposal.width` to `.infinity` — a correct "ideal size" answer in isolation (everything
    // fits on one row given infinite space), but SwiftUI's own stacks ask this exact question, with
    // this exact nil-width fallback, to size a non-flexible child *before* they've settled on its
    // real width — then reuse that (single-row, too-short) height once the child is actually placed
    // at its real, narrower width. `replacingUnspecifiedDimensions()` leaves a real proposal's width
    // untouched and only swaps in a small, finite placeholder for a genuinely unspecified one, so an
    // ideal-size probe now over-wraps (extra whitespace, never overlap) instead of under-wrapping.
    private func layout(subviews: Subviews, containerWidth: CGFloat) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (positions, CGSize(width: containerWidth, height: y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, containerWidth: proposal.replacingUnspecifiedDimensions().width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, containerWidth: proposal.replacingUnspecifiedDimensions().width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
}
