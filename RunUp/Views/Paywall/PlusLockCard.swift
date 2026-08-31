import SwiftUI

/// Ce qu'on voit à la place d'une fonctionnalité Plus quand on n'est pas abonnée.
///
/// # Montrer, pas masquer
///
/// Un verrou qui cache est un cul-de-sac : on tombe sur un vide, on ne sait pas ce qu'on rate, on
/// s'en va. Celui-ci nomme la fonctionnalité et dit ce qu'elle apporte — pas ce qu'elle fait. La
/// personne qui le lit vient d'essayer d'ouvrir cette porte précise ; c'est le seul instant où
/// elle est vraiment disposée à entendre ce qu'il y a derrière, et le pire moment pour lui servir
/// un argumentaire générique sur l'abonnement.
///
/// Il ne se présente jamais seul : chaque appelant le pose SOUS un aperçu réel de la
/// fonctionnalité — un vrai graphique estompé, une vraie réponse du coach tronquée. Voir ce qu'on
/// n'a pas vaut tous les arguments.
struct PlusLockCard: View {
    @Environment(AppState.self) private var appState
    let feature: PlusFeature
    /// Version courte, pour une section verrouillée au milieu d'un écran qui, lui, fonctionne.
    /// La version longue est pour un écran entier.
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                Text("RUNUP PLUS")
                    .font(RUFont.sans(.micro, weight: .bold))
                    .tracking(1.6)
            }
            .foregroundColor(RUColor.rose)

            Text(feature.title)
                .font(compact ? RUFont.sans(.emphasis, weight: .semibold) : RUFont.display(22))
                .foregroundColor(RUColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(feature.pitch)
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)

            Button("Découvrir RUNUP Plus") { appState.plusPrompt = feature }
                .buttonStyle(compact ? AnyButtonStyleBox(SecondaryButtonStyle())
                                     : AnyButtonStyleBox(PrimaryButtonStyle()))
                .padding(.top, 2)

            Text("Le suivi de tes courses, ton historique et le Club restent gratuits.")
                .font(RUFont.sans(.micro))
                .foregroundColor(RUColor.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 16 : 20)
        .ruCard()
    }
}

/// `buttonStyle` veut un type concret, et les deux branches d'un ternaire doivent avoir le même —
/// or `PrimaryButtonStyle` et `SecondaryButtonStyle` sont deux types distincts. Cette boîte les
/// ramène à un seul, sans dupliquer tout le bouton dans un `if`.
struct AnyButtonStyleBox: ButtonStyle {
    private let render: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        render = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View { render(configuration) }
}

extension View {
    /// Estompe et neutralise un aperçu réel placé au-dessus d'un `PlusLockCard`.
    ///
    /// Le contenu reste à l'écran — c'est tout l'intérêt — mais il ne doit plus être lisible en
    /// entier ni utilisable : sinon le verrou n'en est pas un. `allowsHitTesting(false)` coupe
    /// l'interaction, `accessibilityHidden` évite que VoiceOver lise à voix haute ce que l'écran
    /// est justement en train de ne pas donner.
    @ViewBuilder
    func plusTeaser(_ locked: Bool) -> some View {
        if locked {
            self.blur(radius: 5)
                .opacity(0.45)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            self
        }
    }
}

/// Une section d'écran réservée à RUNUP Plus.
///
/// Elle rend son contenu tel quel à une abonnée, et sinon un aperçu estompé surmontant le verrou.
/// L'aperçu est bridé en hauteur : il doit donner le goût, pas livrer la moitié du plat — et une
/// carte d'analyse de six cents points de haut, floutée, occuperait tout l'écran pour ne rien
/// apprendre.
struct PlusSection<Content: View>: View {
    @Environment(SubscriptionService.self) private var subscriptions
    let feature: PlusFeature
    /// Hauteur de l'aperçu estompé. Assez pour reconnaître un graphique, pas assez pour le lire.
    var teaserHeight: CGFloat = 150
    @ViewBuilder var content: () -> Content

    var body: some View {
        if subscriptions.unlocks(feature) {
            content()
        } else {
            VStack(spacing: 10) {
                content()
                    .plusTeaser(true)
                    .frame(maxHeight: teaserHeight, alignment: .top)
                    .clipped()
                PlusLockCard(feature: feature, compact: true)
            }
        }
    }
}
