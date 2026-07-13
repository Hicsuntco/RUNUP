import SwiftUI

/// Race/objective detail — mirrors `RaceScreen` in screensB.jsx. Title/date/pace are dynamic,
/// computed from the real profile state set during onboarding.
struct RaceGoalView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    private let pacingPlan: [(String, String, String)] = [
        ("1-3 km", "Départ contrôlé", "4:52"),
        ("4-8 km", "Rythme cible", "4:45"),
        ("9 km", "Relance", "4:40"),
        ("10 km", "Sprint final", "4:20")
    ]

    private var goalTitle: String {
        profile.goalDisplay.contains("·") ? String(profile.goalDisplay.split(separator: "·").first ?? "").trimmingCharacters(in: .whitespaces) : profile.goalDisplay
    }

    private var goalTarget: String {
        guard let part = profile.goalDisplay.split(separator: "·").last else { return profile.goalDisplay }
        return String(part).trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.profile) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: "Ton objectif", color: RUColor.rose)
                        Text(goalTitle).displayStyle(24).foregroundColor(.white)
                    }
                }
                Text(dateLine).font(RUFont.sans(12)).foregroundColor(RUColor.text2).padding(.leading, 34)

                HStack(spacing: 10) {
                    tile("\(profile.daysUntilRace ?? 63)", "JOURS", highlighted: true)
                    tile(goalTarget, "OBJECTIF", highlighted: false)
                    tile("4:45", "ALLURE", highlighted: false)
                }

                VStack(spacing: 10) {
                    HStack {
                        EyebrowLabel(text: "Préparation")
                        Spacer()
                        StatChip(text: "Dans les temps", color: RUColor.lime)
                    }
                    LinearBar(fraction: 0.68, color: RUColor.rose, height: 8, gradient: LinearGradient(colors: [RUColor.rose, RUColor.lime], startPoint: .leading, endPoint: .trailing))
                    HStack {
                        Text("Base ✓").font(RUFont.sans(10)).foregroundColor(RUColor.text2)
                        Spacer()
                        Text("Spécifique ●").font(RUFont.sans(10)).foregroundColor(RUColor.text2)
                        Spacer()
                        Text("Affûtage").font(RUFont.sans(10)).foregroundColor(RUColor.text2)
                    }
                }
                .padding(14)
                .ruCard()

                EyebrowLabel(text: "Stratégie d'allure · jour J", color: RUColor.text3)
                VStack(spacing: 6) {
                    ForEach(pacingPlan.indices, id: \.self) { i in
                        let isLast = i == pacingPlan.count - 1
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2).fill(isLast ? RUColor.rose : Color.white.opacity(0.2)).frame(width: 3, height: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pacingPlan[i].1).font(RUFont.sans(13, weight: .semibold)).foregroundColor(.white)
                                Text(pacingPlan[i].0).font(RUFont.sans(10)).foregroundColor(RUColor.text2)
                            }
                            Spacer()
                            (Text(pacingPlan[i].2).font(RUFont.bebas(18)).foregroundColor(isLast ? RUColor.rose2 : .white)
                                + Text(" /km").font(RUFont.sans(9)).foregroundColor(RUColor.text2))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private var dateLine: String {
        guard let date = profile.raceDate else { return "Dimanche 16 août · 09:00" }
        return "\(Self.dateFormatter.string(from: date)) · 09:00"
    }

    private func tile(_ value: String, _ label: String, highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value).displayStyle(30).foregroundColor(highlighted ? RUColor.rose2 : .white)
            Text(label).font(RUFont.sans(8, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(highlighted ? RUColor.rose.opacity(0.12) : RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(highlighted ? RUColor.rose.opacity(0.3) : RUColor.line, lineWidth: RUSpacing.hairline))
    }
}
