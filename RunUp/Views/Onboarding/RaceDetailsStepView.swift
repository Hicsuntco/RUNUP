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
                                .foregroundColor(vm.distance == d ? RUColor.rose2 : .white)
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
                    .colorScheme(.dark)
                    .padding(13)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))

                    if let days = vm.daysUntilRace {
                        Text("J-\(days)").font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.rose2).padding(.top, 10)
                    }
                }
            }
            ObNext(disabled: !vm.canProceed(fromStep: 3), action: onNext)
        }
    }
}

/// Simple wrapping flow layout for chip groups (iOS 16+ `Layout` protocol).
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
