import SwiftUI

/// Font tokens — see README § Typography.
/// - Display/numerals ("Bebas Neue", class `.b`): big numbers, headlines, buttons.
/// - Body ("DM Sans", 300–700 + italic): body copy, labels.
/// - Monospace ("DM Mono", class `.m`): timestamps, XP counters, precise numeric readouts.
/// - Eyebrow (class `.eye`): 9px, 3px tracking, uppercase, weight 700, used above section titles.
enum RUFont {
    static func bebas(_ size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size)
    }

    static func mono(_ size: CGFloat, weight: DMWeight = .regular) -> Font {
        switch weight {
        case .medium: return .custom("DMMono-Medium", size: size)
        default: return .custom("DMMono-Regular", size: size)
        }
    }

    static func sans(_ size: CGFloat, weight: DMWeight = .regular) -> Font {
        switch weight {
        case .light: return .custom("DMSans-Light", size: size)
        case .regular: return .custom("DMSans-Regular", size: size)
        case .medium: return .custom("DMSans-Medium", size: size)
        case .semibold: return .custom("DMSans-SemiBold", size: size)
        case .bold: return .custom("DMSans-Bold", size: size)
        }
    }

    static func sansItalic(_ size: CGFloat) -> Font {
        .custom("DMSans-Italic", size: size)
    }

    enum DMWeight {
        case light, regular, medium, semibold, bold
    }
}

extension Text {
    /// Class `.b` in the prototype — Bebas Neue display type, tight tracking.
    func displayStyle(_ size: CGFloat) -> Text {
        self.font(RUFont.bebas(size)).tracking(0.5)
    }

    /// Class `.eye` — eyebrow label above section/card titles.
    func eyebrowStyle(color: Color = RUColor.text2) -> Text {
        self.font(RUFont.sans(9, weight: .bold)).tracking(3).textCase(.uppercase).foregroundColor(color)
    }

    /// Class `.m` — DM Mono numeric readouts.
    func monoStyle(_ size: CGFloat, weight: RUFont.DMWeight = .regular, color: Color = RUColor.textPrimary) -> Text {
        self.font(RUFont.mono(size, weight: weight)).foregroundColor(color)
    }
}

struct EyebrowLabel: View {
    var text: String
    var color: Color = RUColor.text2

    var body: some View {
        Text(text).eyebrowStyle(color: color)
    }
}
