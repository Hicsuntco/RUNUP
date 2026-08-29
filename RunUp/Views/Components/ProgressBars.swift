import SwiftUI

/// Thin segmented progress bar at the top of onboarding (3px tall segments).
struct OnboardingProgressBar: View {
    var step: Int
    var total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? RUColor.rose : RUColor.line)
                    .frame(height: 3)
                    .animation(.easeOut(duration: 0.3), value: step)
            }
        }
    }
}

/// A single thin rounded fill bar — class `.bar`/`i`.
///
/// Correspondance maquette : `.barbg { height: 6px; border-radius: 999px; background:
/// var(--ru-line); overflow: hidden }` + `.barfill { height: 100%; background: var(--ru-gradient);
/// border-radius: 999px }`. Le fond `--ru-line` et la capsule correspondent déjà exactement.
///
/// À noter pour les call sites : la maquette remplit TOUJOURS ses barres de progression avec
/// `--ru-gradient` (= `RUColor.accentGradient()`), jamais d'un aplat uni — c'est aussi l'une des
/// trois surfaces que la v28 garde volontairement pleines (« les jauges de progression (barfill,
/// day-bars) […] sont des indicateurs fonctionnels, pas des surfaces décoratives »). Le paramètre
/// `color` reste néanmoins requis et sans dégradé par défaut : `RingsView` passe des couleurs
/// SÉMANTIQUES (une par objectif, grise pour un jour de repos), que forcer en dégradé de marque
/// effacerait.
struct LinearBar: View {
    var fraction: Double
    var color: Color
    var background: Color = RUColor.line
    /// 6px dans la maquette (`.barbg`), soit ~7,5pt à son échelle ; 5 était nettement en dessous.
    /// 6 est le pas mesuré vers cette valeur qui reste cohérent avec les quatre call sites qui
    /// passent déjà une hauteur explicite (5, 6 et 8) plutôt que de tous les contredire.
    var height: CGFloat = 6
    var gradient: LinearGradient? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(background)
                Group {
                    if let gradient {
                        Capsule().fill(gradient)
                    } else {
                        Capsule().fill(color)
                    }
                }
                .frame(width: geo.size.width * max(0, min(fraction, 1)))
                // `RingView` (the circular counterpart used for the same kind of goal/XP progress)
                // animates its fill; this had none at all, so every screen using `LinearBar`
                // instead — Club's XP bar, challenge progress, RingsView's goal rows, weekly stat
                // tiles — snapped straight to the new value instead of filling in front of you.
                .animation(.easeOut(duration: 0.8), value: fraction)
            }
        }
        .frame(height: height)
    }
}

// `PhaseSegment` et `PhaseProgressBar` vivaient ici. La barre à trois segments Base / Spécifique
// / Affûtage avait deux emplacements : la carte programme de l'accueil et le haut du plan complet.
// L'accueil montre maintenant les kilomètres de la semaine à cet endroit — deux barres de
// progression dans une même carte ne se lisent plus ni l'une ni l'autre — et le plan complet
// dessine la périodisation entière, semaine par semaine, ce que trois segments proportionnels ne
// pouvaient qu'annoncer. Sans appelant, elle est retirée plutôt que laissée à se démoder.

