import SwiftUI

/// Pre-onboarding pitch screen — no progress bar, not counted as a step. See README § 1.
struct WelcomeView: View {
    var onStart: () -> Void

    // Composés en `String` (un tuple, pas un `Text` littéral) : SwiftUI ne les localiserait pas
    // tout seul, d'où le `String(localized:)` explicite sur chaque libellé.
    private let valueProps: [(icon: String, title: String, desc: String)] = [
        ("bolt.fill", String(localized: "Un plan qui vit avec toi"), String(localized: "Pas un PDF figé — il s'ajuste chaque semaine selon ta forme et ton ressenti, jamais séance par séance : tu peux toujours anticiper ce qui t'attend.")),
        ("circle.circle", String(localized: "Tes objectifs du jour, en un coup d'œil"), String(localized: "Ta séance, tes calories actives, tes pas — trois objectifs simples à boucler chaque jour.")),
        ("bubble.left.fill", String(localized: "Un vrai coach, disponible à tout moment"), String(localized: "Il connaît ton objectif, ton historique, et te répond comme un humain le ferait."))
    ]

    var body: some View {
        ZStack {
            RadialGradient(colors: [RUColor.rose.opacity(RUColor.isLight ? 0 : 0.22), .clear], center: .top, startRadius: 0, endRadius: 420)
            RUColor.bg.opacity(0.001)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 60)
                        AppMarkView(size: 88, radius: 26)
                            .shadow(color: RUColor.rose.opacity(RUColor.isLight ? 0 : 0.4), radius: 30, x: 0, y: 16)

                        Text("COURS COMME\nSI TU AVAIS\nUN COACH")
                            .displayStyle(42)
                            .foregroundColor(RUColor.textPrimary)
                            .lineSpacing(-4)
                            .padding(.top, 24)

                        Text("RUNUP construit ton programme, l'ajuste chaque semaine selon ta forme, et te pousse juste ce qu'il faut — jamais plus, jamais moins.")
                            .font(RUFont.sans(.emphasis))
                            .foregroundColor(RUColor.text2)
                            .lineSpacing(6)
                            .padding(.top, 14)

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(valueProps, id: \.title) { prop in
                                HStack(alignment: .top, spacing: 14) {
                                    RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous)
                                        .fill(RUColor.card)
                                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                                        .frame(width: 38, height: 38)
                                        .overlay(Image(systemName: prop.icon).foregroundColor(RUColor.rose2).font(.system(size: 15)))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(prop.title).font(RUFont.sans(.emphasis, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                        Text(prop.desc).font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
                                    }
                                }
                            }
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 26)
                }
                VStack(spacing: 0) {
                    // LE SEUL ENDROIT OÙ LA RESTAURATION EST ATTEIGNABLE QUAND ELLE SERT.
                    //
                    // Une base vide renvoie à l'inscription : les réglages, où ce bouton a sa
                    // place logique, sont donc inatteignables précisément le jour où l'on vient
                    // chercher sa sauvegarde — après une réinstallation, un téléphone neuf, ou un
                    // magasin perdu. Discret par construction : c'est le geste de quelques
                    // personnes, pas le chemin normal, et il n'a pas à concurrencer « COMMENCER ».
                    //
                    // AU-DESSUS du bouton principal, et pas en dessous : `ObNext` consomme la
                    // marge basse de l'écran (`safeAreaPadding(.bottom, 24)`), donc tout ce qui
                    // le suit dans une pile atterrit sous la barre d'accueil.
                    BoutonDeRestauration {
                        Text("J'ai déjà une sauvegarde RUNUP")
                            .font(RUFont.sans(.body, weight: .medium))
                            .foregroundColor(RUColor.text3)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    ObNext(label: "COMMENCER", action: onStart)
                }
                .padding(.horizontal, 22)
            }
        }
    }
}
