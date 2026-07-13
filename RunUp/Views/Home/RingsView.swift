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

                HStack {
                    Spacer()
                    Rings3View(vals: [p.moveValue / p.moveGoal * 100, p.activeValue / p.activeGoal * 100, p.runValue / p.runGoal * 100], size: 210, strokeWidth: 18, gap: 6) {
                        VStack(spacing: 2) {
                            Text("\(p.ringsDone) / 3").font(RUFont.sans(15, weight: .semibold)).tracking(1).foregroundColor(RUColor.text2)
                            Text("bouclés").font(RUFont.sans(9)).foregroundColor(RUColor.text3)
                        }
                    }
                    Spacer()
                }
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
}
