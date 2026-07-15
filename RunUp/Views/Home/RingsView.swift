import SwiftUI

/// Rings detail — mirrors `RingsScreen` in screensA.jsx.
struct RingsView: View {
    @Environment(AppState.self) private var appState
    private var p: UserProfile { appState.profile }

    private var remainingRunKm: String {
        String(format: "%.1f", max(0, p.runGoal - p.runValue))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.home) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: "Aujourd'hui", color: RUColor.rose)
                        Text("Ta journée").displayStyle(22).foregroundColor(.white)
                    }
                }

                VStack(spacing: 14) {
                    Text("\(p.ringsDone) / 3 bouclés").font(RUFont.sans(13, weight: .semibold)).tracking(1).foregroundColor(RUColor.text2)
                    HStack(spacing: 22) {
                        ringWithLabel(name: "Bouger", pct: p.moveValue / p.moveGoal * 100, color: RUColor.rose)
                        ringWithLabel(name: "Actif", pct: p.activeValue / p.activeGoal * 100, color: RUColor.lime)
                        ringWithLabel(name: "Courir", pct: p.runValue / p.runGoal * 100, color: RUColor.cyan)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                VStack(spacing: 9) {
                    ringRow(name: "Bouger", color: RUColor.rose, value: p.moveValue, goal: p.moveGoal, unit: "kcal")
                    ringRow(name: "Actif", color: RUColor.lime, value: p.activeValue, goal: p.activeGoal, unit: "min actives")
                    ringRow(name: "Courir", color: RUColor.cyan, value: p.runValue, goal: p.runGoal, unit: "km du jour")
                }

                if p.ringsDone < 3 {
                    HStack(spacing: 12) {
                        AppMarkView(size: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            EyebrowLabel(text: "Coach", color: RUColor.rose2)
                            Text("Plus que ") .font(RUFont.sans(12.5)).foregroundColor(.white)
                                + Text("\(remainingRunKm) km").font(RUFont.sans(12.5, weight: .bold)).foregroundColor(RUColor.cyan)
                                + Text(" pour boucler Courir. Une sortie footing ce soir ?").font(RUFont.sans(12.5)).foregroundColor(.white)
                        }
                    }
                    .padding(15)
                    .ruHeroCard(radius: 18)
                } else {
                    VStack(spacing: 6) {
                        Text("JOURNÉE BOUCLÉE").displayStyle(26).foregroundColor(.white)
                        Text("Les 3 anneaux fermés 👏 +120 XP").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(RadialGradient(colors: [RUColor.rose.opacity(0.2), .clear], center: .top, startRadius: 0, endRadius: 200), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private func ringRow(name: String, color: Color, value: Double, goal: Double, unit: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10).shadow(color: color.opacity(0.4), radius: 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(name).font(RUFont.sans(16, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    (Text(formattedValue(value)).font(RUFont.sans(11, weight: .bold)).foregroundColor(color)
                        + Text(" / \(formattedValue(goal)) \(unit)").font(RUFont.mono(11)).foregroundColor(RUColor.text2))
                }
                LinearBar(fraction: goal == 0 ? 0 : value / goal, color: color, height: 5)
            }
        }
        .padding(14)
        .ruCard()
    }

    private func formattedValue(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func ringWithLabel(name: String, pct: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            RingView(pct: pct, color: color, size: 84, strokeWidth: 10) {
                Text("\(Int(max(0, min(pct, 100))))%").font(RUFont.mono(13, weight: .medium)).foregroundColor(color)
            }
            Text(name).font(RUFont.sans(11, weight: .semibold)).foregroundColor(RUColor.text2)
        }
    }
}
