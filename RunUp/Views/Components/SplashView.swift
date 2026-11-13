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
            HStack(spacing: 18) {
                AppMarkView(size: markSize, radius: markSize * 0.26, drawn: drawn)
                    // La tuile arrive derrière les barres, pas avec elles : les traits blancs se
                    // posent sur le noir, et le dégradé de marque monte dessous une fois qu'ils
                    // sont lisibles. Dans l'autre ordre, on voit un carré rose avant de voir un logo.
                    .opacity(tile)
                    .scaleEffect(0.88 + 0.12 * tile)

                Text(verbatim: "RUNUP")
                    .font(RUFont.display(.hero))
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
        }
        // LE FONDU PORTE L'ÉCRAN ENTIER, FOND COMPRIS — et c'était là le sursaut.
        //
        // Il ne portait que le logo. Le fond, lui, restait opaque jusqu'à ce que `onFinished`
        // retire la vue : le mot s'effaçait sur un fond plein, puis l'app apparaissait d'un
        // coup, en une image. Un fondu suivi d'une coupe.
        //
        // Posé sur le `ZStack`, le même fondu découvre progressivement `ContentRouterView`, qui
        // est déjà dessiné dessous — l'ouverture devient un fondu enchaîné et ne coûte pas une
        // milliseconde de plus.
        .opacity(opacity)
        // Rien à toucher ici, et pendant les trois dixièmes du fondu l'écran d'ouverture
        // avalait les gestes destinés à l'app qui apparaît dessous.
        .allowsHitTesting(false)
        .onAppear { jouer() }
    }

    /// LA CHORÉGRAPHIE D'OUVERTURE, EN CLAIR.
    ///
    /// Ces six nombres étaient écrits à même les appels, et personne ne les avait jamais
    /// additionnés. Le dévoilement démarrait à 0,58 s pour 0,80 s, donc il finissait à 1,38 s —
    /// quand le fondu commençait à 1,15. **29 % du mouvement d'ouverture de l'app se jouait
    /// pendant que l'écran disparaissait déjà.** Chaque valeur était raisonnable toute seule ;
    /// le défaut ne vivait que dans leur somme.
    ///
    /// Nommés ici pour deux raisons. On les lit maintenant les uns à côté des autres, ce qui rend
    /// l'addition évidente. Et `check_lancement.py` les lit aussi : il refait la somme à chaque
    /// CI, avec les durées réelles de `RUMotion`, donc raccourcir ou rallonger un jeton du
    /// système de mouvement ne peut plus désaccorder l'ouverture en silence.
    private enum Tempo {
        /// Le tracé se dessine, dès la première image.
        static let traceDuree = 0.75
        /// La tuile arrive — durée empruntée à `RUMotion.settle`.
        static let tuileDepart = 0.42
        /// Le nom se dévoile — durée empruntée à `RUMotion.glide`.
        static let revealDepart = 0.58
        /// Quand l'écran commence à s'effacer. TOUT doit être fini avant.
        static let fondu = 1.150
        static let fonduDuree = 0.28
        /// Ce qu'on laisse au fondu avant de rendre la main.
        static let apresFondu = 0.290

        /// La version sans animation : on montre l'image finie, on la tient, on s'efface.
        static let replatTenue = 0.650
        static let replatFondu = 0.25
        static let replatApres = 0.260
    }

    private func jouer() {
        guard !reduceMotion else {
            drawn = 1; tile = 1; reveal = 1
            Task {
                try? await Task.sleep(for: .seconds(Tempo.replatTenue))
                withAnimation(.easeIn(duration: Tempo.replatFondu)) { opacity = 0 }
                try? await Task.sleep(for: .seconds(Tempo.replatApres))
                onFinished()
            }
            return
        }

        withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: Tempo.traceDuree)) { drawn = 1 }
        withAnimation(RUMotion.settle.delay(Tempo.tuileDepart)) { tile = 1 }
        withAnimation(RUMotion.glide.delay(Tempo.revealDepart)) { reveal = 1 }

        Task {
            try? await Task.sleep(for: .seconds(Tempo.fondu))
            withAnimation(.easeIn(duration: Tempo.fonduDuree)) { opacity = 0 }
            try? await Task.sleep(for: .seconds(Tempo.apresFondu))
            onFinished()
        }
    }
}
