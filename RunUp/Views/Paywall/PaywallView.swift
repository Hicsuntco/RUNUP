import SwiftUI

/// Premium paywall — free trial + monthly/annual subscription. Mirrors `PaywallScreen` in
/// screensE.jsx. Always skippable via "Plus tard" — the README is explicit that the free tier
/// must never be blocked behind a forced purchase, whether reached post-onboarding or from Profile.
struct PaywallView: View {
    @Environment(AppState.self) private var appState

    private enum Plan { case monthly, annual }

    @State private var plan: Plan = .annual
    @State private var trial = true
    @State private var loading = false

    private let features: [(String, String)] = [
        ("Coach IA sans limite", "Discussions illimitées, à toute heure, avant et après chaque sortie."),
        ("Programme qui s'adapte en continu", "Ajustements automatiques après chaque séance, chaque ressenti."),
        ("Stats avancées", "VO₂max, prédictions de course, analyse de charge sur 12 semaines."),
        ("Connexions illimitées", "Apple Santé, Strava, Garmin synchronisés en temps réel.")
    ]

    var body: some View {
        ZStack {
            RadialGradient(colors: [RUColor.violet.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 420)
            RUColor.bg

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Plus tard") { appState.showPaywall = false }
                            .font(RUFont.sans(13, weight: .semibold))
                            .foregroundColor(RUColor.text3)
                    }
                    .padding(.top, 18)

                    VStack(spacing: 10) {
                        AppMarkView(size: 64, radius: 18)
                        Text("PASSE EN\nPREMIUM").displayStyle(30).multilineTextAlignment(.center).foregroundColor(.white).lineSpacing(-2)
                        Text("Le coach qui s'adapte vraiment à toi, sans limite.")
                            .font(RUFont.sans(13)).foregroundColor(RUColor.text2).multilineTextAlignment(.center).lineSpacing(3)
                    }
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.0) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle().fill(RUColor.violet.opacity(0.18))
                                    Circle().strokeBorder(RUColor.violet.opacity(0.4), lineWidth: RUSpacing.hairline)
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(RUColor.violet)
                                }
                                .frame(width: 22, height: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.0).font(RUFont.sans(13.5, weight: .semibold)).foregroundColor(.white)
                                    Text(feature.1).font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).lineSpacing(2)
                                }
                            }
                        }
                    }
                    .padding(.top, 26)

                    VStack(spacing: 8) {
                        planCard(.annual, title: "Annuel", detail: "49,99 € /an · soit 4,17 €/mois", badge: "-30%")
                        planCard(.monthly, title: "Mensuel", detail: "5,99 € /mois · sans engagement", badge: nil)
                    }
                    .padding(.top, 26)

                    Button(action: { trial.toggle() }) {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(trial ? RUColor.violet : Color.white.opacity(0.25), lineWidth: 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(trial ? RUColor.violet : .clear))
                                .frame(width: 20, height: 20)
                                .overlay(Group { if trial { Image(systemName: "checkmark").font(.system(size: 11)).foregroundColor(.white) } })
                            Text("Commencer par 7 jours d'essai gratuit").font(RUFont.sans(12.5)).foregroundColor(RUColor.text2)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)

                    Button(action: subscribe) {
                        if loading {
                            HStack(spacing: 5) { ForEach(0..<3) { _ in Circle().fill(.white).frame(width: 6, height: 6) } }
                        } else {
                            Text(trial ? "COMMENCER L'ESSAI GRATUIT" : "S'ABONNER · \(plan == .annual ? "49,99 €/an" : "5,99 €/mois")")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle.violetRose)
                    .disabled(loading)
                    .padding(.top, 24)

                    Text(trial ? "Puis \(plan == .annual ? "49,99 €/an" : "5,99 €/mois") — annule à tout moment." : "Résiliable à tout moment depuis ton profil.")
                        .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3).multilineTextAlignment(.center).lineSpacing(3)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 22)
            }
        }
        .ignoresSafeArea()
    }

    private func planCard(_ p: Plan, title: String, detail: String, badge: String?) -> some View {
        Button(action: { plan = p }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(RUFont.sans(14, weight: .bold)).foregroundColor(.white)
                    Text(detail).font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                }
                Spacer()
                if let badge {
                    StatChip(text: badge, color: .white, background: RUColor.violet)
                }
            }
            .padding(14)
            .background(plan == p ? RUColor.violet.opacity(0.14) : RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(plan == p ? RUColor.violet : RUColor.line, lineWidth: plan == p ? 1.5 : RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
    }

    private func subscribe() {
        loading = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run {
                loading = false
                appState.profile.premium = true
                appState.toast(trial ? "Essai gratuit activé · 7 jours" : "Abonnement activé — bienvenue dans Premium")
                appState.showPaywall = false
            }
        }
    }
}
