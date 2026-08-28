import SwiftUI
import UIKit

/// Lives in `Shared/` (compiles into both the `RunUp` app target and the `RunUpWidgets` extension)
/// rather than alongside `RUColor` in `RunUp/DesignSystem/Colors.swift` — this math is pure and
/// target-agnostic, so one copy here means a future fix to hex parsing or the darkening algorithm
/// reaches both targets automatically instead of needing to be applied twice (which is what
/// `RunUpWidgets/WidgetColor.swift` used to be, a hand-kept second copy of this exact code).
extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Assombrit en MULTIPLIANT les canaux, ce qui conserve la teinte et la saturation.
    ///
    /// Cette fonction SOUSTRAYAIT auparavant une constante à chaque canal, et le résultat n'était
    /// pas une version plus sombre de la couleur : c'était une autre couleur. Le canal le plus
    /// faible est écrasé bien avant les autres — le rose de marque `#FF0F5B` sortait en
    /// `#E60042`, son vert ramené de 14 à 0 et son bleu de 91 à 66, donc une teinte glissée vers
    /// le rouge pur. La maquette, elle, transcrit `#E60E52`.
    ///
    /// Une multiplication rend EXACTEMENT la valeur de la maquette, pour le rose comme pour le
    /// violet (`#7C5CFF` → `#7053E6`) : c'était bien l'opération voulue depuis le début. Le
    /// paramètre garde son sens — 0,10 veut dire « 10 % plus sombre » — donc aucun site d'appel
    /// n'a besoin d'être retouché.
    func darkened(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let factor = CGFloat(max(0, min(1, 1 - amount)))
        return Color(red: r * factor, green: g * factor, blue: b * factor, opacity: a)
    }

    /// La même teinte, poussée vers son maximum d'intensité — plus lumineuse tant qu'il reste de
    /// la marge, puis plus saturée une fois la luminosité au plafond.
    ///
    /// Le pendant de `darkened` pour les dégradés d'accent, et pas son inverse : multiplier les
    /// canaux RVB comme le fait `darkened` fabrique de la boue. `#E60E52` assombri de 28 % donne
    /// `#A60A3B`, un bordeaux terne — la teinte est conservée, mais la couleur ne dit plus rien
    /// du rose de la marque. Travailler en TSV plutôt qu'en RVB garde la teinte ET l'éclat.
    ///
    /// L'ordre compte : monter la saturation d'abord sur une couleur déjà sombre la rendrait
    /// criarde sans la rendre lumineuse. On dépense la marge de luminosité en premier, et le
    /// reliquat seulement ensuite en saturation — ce qui rend l'effet utile aussi en mode sombre,
    /// où les accents sont déjà à luminosité maximale et où seul le gain de saturation reste
    /// disponible.
    func vivid(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        let amt = CGFloat(max(0, amount))
        let newB = min(1, b * (1 + amt))
        let spent = b > 0 ? (newB / b) - 1 : amt
        let newS = min(1, s * (1 + max(0, amt - spent)))
        return Color(hue: Double(h), saturation: Double(newS), brightness: Double(newB), opacity: Double(a))
    }

    /// La même teinte, assombrie juste assez pour atteindre un contraste donné sur du BLANC.
    ///
    /// Le mode clair dérivait ses accents en assombrissant de 10 ou 14 % — un pourcentage fixe,
    /// appliqué à des teintes dont la luminosité de départ varie du simple au double. Sur le rose
    /// ça tombait juste ; sur le lime, l'ambre et le cyan, dont la teinte est intrinsèquement
    /// claire, l'accent restait à 1,9:1 contre du blanc. Illisible, pas « un peu pâle » : à ce
    /// niveau le texte disparaît dans la page.
    ///
    /// Viser un CONTRASTE plutôt qu'un pourcentage règle le problème à la source : chaque teinte
    /// descend de ce qu'il faut, et pas plus. Une couleur qui atteint déjà le seuil n'est pas
    /// touchée du tout.
    ///
    /// Le travail se fait en TSV, comme `vivid` et pour la même raison : multiplier les canaux
    /// RVB désature vers le noir et fabrique de la boue.
    func meetingContrastOnWhite(_ target: Double) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }

        func contrast(_ brightness: CGFloat) -> Double {
            let c = UIColor(hue: h, saturation: s, brightness: brightness, alpha: 1)
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
            c.getRed(&r, green: &g, blue: &bl, alpha: &al)
            func lin(_ v: CGFloat) -> Double {
                let d = Double(v)
                return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
            }
            let l = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(bl)
            return 1.05 / (l + 0.05)
        }

        if contrast(b) >= target { return self }
        // Recherche dichotomique sur la luminosité : la fonction est monotone, donc vingt
        // itérations suffisent largement à la précision d'un canal 8 bits.
        var lo: CGFloat = 0.05, hi = b
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            if contrast(mid) >= target { lo = mid } else { hi = mid }
        }
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(lo), opacity: Double(a))
    }
}
