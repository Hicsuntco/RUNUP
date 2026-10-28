import SwiftUI

/// LES KILOMÈTRES UN PAR UN.
///
/// Extrait de `RecapView`, où il vivait en deux méthodes privées, parce qu'il a maintenant DEUX
/// lecteurs : l'écran de fin de course, et la page d'une sortie ouverte depuis le fil — la
/// sienne ou celle de quelqu'un d'autre. Deux copies auraient divergé, et c'est exactement le
/// genre d'écart qu'on ne voit pas : des barres calculées autrement d'un écran à l'autre ne
/// plantent rien, elles mentent doucement.
///
/// La longueur d'une barre est relative aux PROPRES splits de cette sortie — son plus rapide
/// contre son plus lent — et non à une échelle absolue : courir ses dix kilomètres entre 5:10 et
/// 5:20 doit se lire comme une sortie régulière, pas comme dix barres identiques.
struct SplitsView: View {
    var splits: [String]
    /// Les barres se remplissent l'une après l'autre quand il passe à vrai. L'écran qui le porte
    /// décide quand : à l'apparition, après un chargement réseau.
    var revealed: Bool
    var reduceMotion: Bool

    var body: some View {
        VStack(spacing: 5) {
            let fractions = Self.fractions(splits)
            ForEach(splits.indices, id: \.self) { i in
                ligne(index: i, time: splits[i], fraction: fractions[i], isLast: i == splits.count - 1)
            }
        }
    }

    private func ligne(index: Int, time: String, fraction: Double, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            // 16 POINTS NE TIENNENT PAS DEUX CHIFFRES, ET LA CAPTURE L'A MONTRÉ.
            //
            // Les splits 10, 11 et 12 se repliaient sur DEUX LIGNES — « 1 » au-dessus de « 0 » —
            // donc toute sortie de plus de neuf kilomètres affichait une colonne de numéros
            // cassés. Sur l'écran de fin de course comme sur la page d'une sortie, c'est-à-dire
            // exactement là où une sortie longue se regarde.
            //
            // `lineLimit(1)` en plus de la largeur : un numéro ne se replie jamais, même si une
            // taille de texte d'accessibilité le fait déborder — il rétrécit.
            Text("\(index + 1)")
                .font(RUFont.mono(11))
                .foregroundColor(RUColor.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 22, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: RUSpacing.radiusMicro).fill(RUColor.card)
                    RoundedRectangle(cornerRadius: RUSpacing.radiusMicro)
                        .fill(isLast ? RUColor.rose : RUColor.text4)
                        // Les barres balaient l'une après l'autre (40 ms d'écart par ligne) au
                        // lieu d'apparaître toutes dessinées — la même lecture « révélé, pas
                        // déversé » que l'anneau de l'accueil qui se remplit à l'apparition.
                        .frame(width: geo.size.width * fraction * (revealed ? 1 : 0))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(Double(index) * 0.04), value: revealed)
                }
            }
            .frame(height: 22)
            .accessibilityHidden(true)
            // minWidth, pas une largeur fixe — un « m:ss » tient dans 38 points à la taille de
            // texte par défaut, mais les tailles d'accessibilité ont besoin que la ligne grandisse
            // plutôt que de tronquer le temps.
            Text(time).displayStyle(.label).foregroundColor(isLast ? RUColor.rose2 : RUColor.textPrimary).frame(minWidth: 38, alignment: .trailing)
        }
        // La barre ne porte aucune valeur VoiceOver, et « dernier split » n'existait qu'en
        // couleur — combinés en un seul élément avec un libellé et une valeur explicites.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLast
            ? String(localized: "Split \(index + 1), dernier")
            : String(localized: "Split \(index + 1)"))
        .accessibilityValue(time)
    }

    /// La longueur d'une barre, relative au plus rapide et au plus lent split de CETTE sortie —
    /// c'était `0,45 + index × 0,07`, une forme qui grandissait avec la position du split dans la
    /// liste, que la coureuse ait accéléré ou ralenti.
    static func fractions(_ splits: [String]) -> [Double] {
        let seconds = splits.map { PaceModel.parseSecPerKm($0) }
        let known = seconds.compactMap { $0 }
        guard let minSec = known.min(), let maxSec = known.max(), maxSec > minSec else {
            return splits.map { _ in 0.6 }
        }
        return seconds.map { sec in
            guard let sec else { return 0.6 }
            let t = (sec - minSec) / (maxSec - minSec) // 0 = le plus rapide … 1 = le plus lent
            return 0.35 + (1 - t) * 0.6
        }
    }
}
