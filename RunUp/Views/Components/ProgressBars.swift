import SwiftUI

/// Thin segmented progress bar at the top of onboarding (3px tall segments).
struct OnboardingProgressBar: View {
    var step: Int
    var total: Int

    var body: some View {
        HStack(spacing: 6) {
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
/// LE PARAMÈTRE `gradient` A DISPARU, ET AVEC LUI SES TROIS APPELANTS.
///
/// La maquette remplissait toujours ses jauges avec `--ru-gradient`, et trois écrans suivaient :
/// le résumé hebdomadaire, la jauge d'XP du club, la jauge d'avancement du programme. Les autres
/// passaient déjà une couleur SÉMANTIQUE — une par phase, grise pour un jour de repos — que le
/// dégradé de marque aurait effacée. La règle 7 range tout le monde du même côté : une jauge est
/// un indicateur, elle porte UNE couleur, et c'est l'appelant qui dit laquelle.
struct LinearBar: View {
    var fraction: Double
    var color: Color
    var background: Color = RUColor.line
    /// 6px dans la maquette (`.barbg`), soit ~7,5pt à son échelle ; 5 était nettement en dessous.
    /// 6 est le pas mesuré vers cette valeur qui reste cohérent avec les quatre call sites qui
    /// passent déjà une hauteur explicite (5, 6 et 8) plutôt que de tous les contredire.
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(background)
                Capsule().fill(color)
                    .frame(width: geo.size.width * max(0, min(fraction, 1)))
                    // `RingView` (the circular counterpart used for the same kind of goal/XP
                    // progress) animates its fill; this had none at all, so every screen using
                    // `LinearBar` instead — Club's XP bar, challenge progress, RingsView's goal
                    // rows, weekly stat tiles — snapped straight to the new value instead of
                    // filling in front of you.
                    .animation(.easeOut(duration: 0.8), value: fraction)
            }
        }
        .frame(height: height)
    }
}

/// One phase segment: label, done/total sessions, proportional width, own fill color.
struct PhaseSegment: Identifiable {
    let id = UUID()
    var name: String
    var done: Int
    var total: Int
    var color: Color
}

/// The 3-segment Base/Spécifique/Affûtage phase bar, segment widths proportional to `total`
/// (mirrors CSS `flex: t` in the prototype).
struct PhaseProgressBar: View {
    var phases: [PhaseSegment]
    var showLabels: Bool = true

    private var weightSum: Double { max(1, phases.reduce(0) { $0 + $1.total }.doubleValue) }
    private let gap: CGFloat = 4

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let available = geo.size.width - gap * CGFloat(max(0, phases.count - 1))
                HStack(spacing: gap) {
                    ForEach(phases) { phase in
                        LinearBar(fraction: phase.total == 0 ? 0 : Double(phase.done) / Double(phase.total), color: phase.color)
                            .frame(width: available * (phase.total.doubleValue / weightSum))
                    }
                }
            }
            .frame(height: 5)
            if showLabels {
                HStack(spacing: gap) {
                    ForEach(phases) { phase in
                        // Même écueil que `EyebrowLabel` : un `String` passé à `Text` ne traverse
                        // jamais le catalogue, donc « Base / Spécifique / Affûtage » restaient en
                        // français alors que les trois clés y sont déjà.
                        Text(LocalizedStringKey(phase.name))
                            .font(RUFont.sans(.micro, weight: .bold))
                            .tracking(0.2)
                            .foregroundColor(RUColor.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private extension Int {
    var doubleValue: Double { Double(self) }
}
