import SwiftUI

/// Post-program recovery tracker — mirrors `RecoveryView` in screensD.jsx.
struct RecoveryView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    private var total: Int { profile.goalId.recoveryDays }
    private var done: Int { total - profile.recoveryDaysLeft }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HeaderView(eyebrow: "Programme terminé 🏁", title: "Bravo \(profile.name)") {
                    AvatarButton(initial: String(profile.name.prefix(1))) { appState.go(.profile) }
                }

                VStack(spacing: 12) {
                    Text("🌿").font(.system(size: 34))
                    Text("Place à la récupération").displayStyle(22).foregroundColor(.white)
                    Text("Ton corps a fait le plus dur. On souffle \(total) jours avant de repartir — c'est ce qui fait tenir les progrès dans la durée.")
                        .font(RUFont.sans(12.5)).foregroundColor(RUColor.text2).multilineTextAlignment(.center).lineSpacing(3)

                    HStack(spacing: 5) {
                        ForEach(0..<total, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(i < done ? RUColor.lime : Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(i < done ? RUColor.lime : RUColor.line, lineWidth: RUSpacing.hairline))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Text(i < done ? "✓" : "\(i + 1)")
                                        .displayStyle(13)
                                        .foregroundColor(i < done ? Color(hex: 0x0A0A0A) : RUColor.text2)
                                )
                        }
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22).padding(.horizontal, 18)
                .ruHeroCard(radius: 22, borderOpacity: 0.22)

                VStack(alignment: .leading, spacing: 6) {
                    EyebrowLabel(text: "Aujourd'hui", color: RUColor.rose2)
                    Text("Marche, étirements ou repos complet").font(RUFont.sans(14, weight: .semibold)).foregroundColor(.white)
                    Text("Pas de course prévue — hydrate-toi bien et dors un peu plus si tu peux.")
                        .font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(3)
                }
                .padding(16)
                .ruCard()

                Button(profile.recoveryDaysLeft > 1 ? "JOUR SUIVANT →" : "JE SUIS PRÊTE") {
                    AdaptivePlanEngine.tickRecovery(profile)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }
}
