import SwiftUI

/// Progression analytics — mirrors `StatsScreen` in screensB.jsx. VO2max/race-prediction values
/// are illustrative placeholders in the design (the "procedurally generated" numbers the README
/// leaves to judgement); the race-prediction footer compares against live profile goal state.
struct StatsView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    private let loadBars: [CGFloat] = [40, 55, 48, 70, 62, 80, 58, 90, 75, 100, 88]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HeaderView(eyebrow: "Analyse · progression", title: "Ta forme monte") {
                    Button(action: { appState.go(.history) }) {
                        HStack(spacing: 5) {
                            Text("Historique").font(RUFont.sans(11, weight: .semibold))
                            Text("›")
                        }
                        .foregroundColor(RUColor.text2)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RUColor.card, in: Capsule())
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                }

                vo2Card
                predictionCard
                loadCard
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private var vo2Card: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: "VO₂ max estimé")
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("52.4").displayStyle(52).foregroundColor(.white)
                StatChip(text: "▲ +2.1", color: RUColor.lime)
            }
            Text("Top 12% · femmes 25-34 ans").font(RUFont.sans(11)).foregroundColor(RUColor.text2)

            Canvas { context, size in
                let points: [CGFloat] = [58, 54, 50, 44, 40, 32, 26, 14]
                let stepX = size.width / CGFloat(points.count - 1)
                var line = Path()
                var fill = Path()
                fill.move(to: CGPoint(x: 0, y: size.height))
                for (i, p) in points.enumerated() {
                    let point = CGPoint(x: CGFloat(i) * stepX, y: p / 70 * size.height)
                    if i == 0 { line.move(to: point) } else { line.addLine(to: point) }
                    fill.addLine(to: point)
                }
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(Gradient(colors: [RUColor.rose.opacity(0.35), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                context.stroke(line, with: .color(RUColor.rose), lineWidth: 2.5)
            }
            .frame(height: 70)
            .padding(.top, 6)
        }
        .padding(16)
        .ruCard()
    }

    private var predictionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Prédiction de course", color: RUColor.rose2)
            HStack(spacing: 8) {
                predictionTile("5 KM", "22:40", highlighted: false)
                predictionTile("10 KM", "47:10", highlighted: true)
                predictionTile("SEMI", "1:45", highlighted: false)
            }
            Text("Objectif \(profile.goalDisplay) → ")
                .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                + Text("en avance de 20″").font(RUFont.sans(11, weight: .bold)).foregroundColor(RUColor.lime)
                + Text(" sur ton plan.").font(RUFont.sans(11)).foregroundColor(RUColor.text2)
        }
        .padding(16)
        .ruHeroCard(radius: 20)
    }

    private func predictionTile(_ label: String, _ value: String, highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(RUFont.sans(8, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
            Text(value).displayStyle(22).foregroundColor(highlighted ? RUColor.rose2 : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(highlighted ? RUColor.rose.opacity(0.14) : RUColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(highlighted ? RUColor.rose.opacity(0.3) : RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private var loadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "Charge · 11 sem.")
                Spacer()
                StatChip(text: "Zone optimale", color: RUColor.cyan)
            }
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(loadBars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i >= loadBars.count - 2 ? RUColor.rose : Color.white.opacity(0.14))
                        .frame(height: loadBars[i] / 100 * 70)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70, alignment: .bottom)
            HStack {
                Text("S1").font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                Spacer()
                Text("ratio charge 1.1").font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                Spacer()
                Text("S11").font(RUFont.sans(10)).foregroundColor(RUColor.text3)
            }
        }
        .padding(16)
        .ruCard()
    }
}
