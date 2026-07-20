import SwiftUI

/// Pre-onboarding pitch screen — no progress bar, not counted as a step. See README § 1.
struct WelcomeView: View {
    var onStart: () -> Void

    private let valueProps: [(icon: String, title: String, desc: String)] = [
        ("bolt.fill", "Un plan qui vit avec toi", "Pas un PDF figé — il s'ajuste chaque semaine selon ta forme et ton ressenti, jamais séance par séance : tu peux toujours anticiper ce qui t'attend."),
        ("circle.circle", "Tes objectifs du jour, en un coup d'œil", "Bouger, rester actif, courir — trois objectifs simples à boucler chaque jour."),
        ("bubble.left.fill", "Un vrai coach, disponible à tout moment", "Il connaît ton objectif, ton historique, et te répond comme un humain le ferait.")
    ]

    var body: some View {
        ZStack {
            RadialGradient(colors: [RUColor.rose.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 420)
            RUColor.bg.opacity(0.001)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 60)
                        AppMarkView(size: 88, radius: 26)
                            .shadow(color: RUColor.rose.opacity(0.4), radius: 30, x: 0, y: 16)

                        Text("COURS COMME\nSI TU AVAIS\nUN COACH")
                            .displayStyle(42)
                            .foregroundColor(RUColor.textPrimary)
                            .lineSpacing(-4)
                            .padding(.top, 24)

                        Text("RUNUP construit ton programme, l'ajuste chaque semaine selon ta forme, et te pousse juste ce qu'il faut — jamais plus, jamais moins.")
                            .font(RUFont.sans(14))
                            .foregroundColor(RUColor.text2)
                            .lineSpacing(6)
                            .padding(.top, 14)

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(valueProps, id: \.title) { prop in
                                HStack(alignment: .top, spacing: 14) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(RUColor.card)
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                                        .frame(width: 38, height: 38)
                                        .overlay(Image(systemName: prop.icon).foregroundColor(RUColor.rose2).font(.system(size: 15)))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(prop.title).font(RUFont.sans(14, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                        Text(prop.desc).font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(3)
                                    }
                                }
                            }
                        }
                        .padding(.top, 30)

                        HStack(spacing: 8) {
                            Text("★★★★★").foregroundColor(RUColor.lime)
                            Text("Rejoins des milliers de coureurs qui progressent chaque semaine")
                                .foregroundColor(RUColor.text3)
                        }
                        .font(RUFont.sans(11.5))
                        .padding(.top, 28)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 26)
                }
                ObNext(label: "COMMENCER", action: onStart)
                    .padding(.horizontal, 22)
            }
        }
    }
}
