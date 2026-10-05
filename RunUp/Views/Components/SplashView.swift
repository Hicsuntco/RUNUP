import SwiftUI

/// Le lancement à froid : la marque se CONSTRUIT, puis le mot apparaît à côté d'elle.
///
/// L'écran de lancement du système (`UILaunchScreen` dans `project.yml`) ne sait afficher qu'une
/// couleur fixe. Celui-ci prend le relais dès que le code tourne, posé au-dessus de
/// `ContentRouterView` le temps de s'effacer.
///
/// # CE QU'IL MONTRAIT, ET POURQUOI ÇA NE SUFFISAIT PLUS
///
/// Le mot « RUNUP » qui grossit de 6 % en fondu. C'est le lancement par défaut de n'importe
/// quelle app, et c'était le seul endroit où RUNUP ne ressemblait pas à RUNUP : son logo — quatre
/// foulées qui montent — n'y apparaissait pas une seule fois.
///
/// Les quatre barres se tracent maintenant du bas vers le haut, en se chevauchant, et le
/// mot-symbole se dévoile par un volet qui s'ouvre DEPUIS la tuile. L'œil suit donc une seule
/// trajectoire, de gauche à droite, à l'inclinaison du logo — au lieu de deux apparitions
/// simultanées sans rapport l'une avec l'autre.
///
/// # LA DURÉE EST UN BUDGET, PAS UN CHOIX ESTHÉTIQUE
///
/// 1,15 s au total, dont 0,75 de tracé. Un lancement est vu plusieurs fois par jour par quelqu'un
/// qui veut partir courir : chaque dixième ajouté ici est un dixième pris à la personne, tous les
/// jours. La séquence tient donc dans le temps qu'il faut de toute façon pour charger l'état de
/// l'app, et elle n'ajoute rien à l'attente — elle l'occupe.
struct SplashView: View {
    var onFinished: () -> Void

    @State private var drawn: Double = 0
    @State private var tile: Double = 0
    @State private var reveal: CGFloat = 0
    @State private var opacity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let markSize: CGFloat = 72

    var body: some View {
        ZStack {
            RUColor.bg.ignoresSafeArea()
            HStack(spacing: 16) {
                AppMarkView(size: markSize, radius: markSize * 0.26, drawn: drawn)
                    // La tuile arrive derrière les barres, pas avec elles : les traits blancs se
                    // posent sur le noir, et le dégradé de marque monte dessous une fois qu'ils
                    // sont lisibles. Dans l'autre ordre, on voit un carré rose avant de voir un logo.
                    .opacity(tile)
                    .scaleEffect(0.88 + 0.12 * tile)

                Text(verbatim: "RUNUP")
                    .font(RUFont.display(34))
                    .tracking(4)
                    .foregroundColor(RUColor.textPrimary)
                    .fixedSize()
                    // Un volet qui s'ouvre depuis la tuile. `scaleEffect` sur un masque plutôt
                    // qu'une largeur animée : la largeur reflowerait le `HStack` à chaque image et
                    // ferait glisser la tuile pendant que le mot se dévoile.
                    .mask(alignment: .leading) {
                        Rectangle().scaleEffect(x: reveal, y: 1, anchor: .leading)
                    }
            }
            .opacity(opacity)
        }
        .onAppear { jouer() }
    }

    private func jouer() {
        guard !reduceMotion else {
            drawn = 1; tile = 1; reveal = 1
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.easeIn(duration: 0.25)) { opacity = 0 }
                try? await Task.sleep(for: .milliseconds(260))
                onFinished()
            }
            return
        }

        withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.75)) { drawn = 1 }
        withAnimation(RUMotion.settle.delay(0.42)) { tile = 1 }
        withAnimation(RUMotion.glide.delay(0.58)) { reveal = 1 }

        Task {
            try? await Task.sleep(for: .milliseconds(1_150))
            withAnimation(.easeIn(duration: 0.28)) { opacity = 0 }
            try? await Task.sleep(for: .milliseconds(290))
            onFinished()
        }
    }
}
