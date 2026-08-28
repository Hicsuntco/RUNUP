import SwiftUI

/// L'anatomie de carte des références : une icône teintée, un titre en gras, un sous-titre gris.
///
/// L'app coiffait ses cartes d'`EyebrowLabel` — 10 pt, capitales, interlettrage 1,8, gris `text3`.
/// C'est une micro-étiquette, et elle se lit comme du petit texte : les cartes n'avaient pas de
/// titre, elles avaient une mention. Les références en montrent l'inverse — « Your daily balance »,
/// « Steps count », « Heart rate » : un vrai titre, en blanc, en gras, à la taille du texte
/// courant, doublé d'une ligne grise qui dit ce que la carte mesure.
///
/// `EyebrowLabel` reste, et ce n'est pas un oubli : sur les 89 endroits qui l'utilisent, une bonne
/// moitié sont des libellés de CHAMP dans le tunnel d'inscription (« Tu es », « Ta priorité »,
/// « Tes jours de course »). Là, la micro-étiquette est le bon objet — elle annonce une saisie,
/// pas une carte. Un composant par rôle plutôt qu'un composant tordu pour deux.
struct RUCardHeader<Accessory: View>: View {
    var icon: String?
    var tint: Color = RUColor.rose
    var title: String
    var subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 26, height: 26)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(title))
                    .font(RUFont.sans(13.5, weight: .bold))
                    .foregroundColor(RUColor.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(RUFont.sans(10.5))
                        .foregroundColor(RUColor.text3)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 6)
            accessory()
        }
        // Le titre, le sous-titre et l'icône décrivent UNE chose : trois arrêts VoiceOver pour un
        // seul en-tête de carte, c'est trois fois le même contexte relu.
        .accessibilityElement(children: .combine)
    }
}

extension RUCardHeader where Accessory == EmptyView {
    init(icon: String? = nil, tint: Color = RUColor.rose, title: String, subtitle: String? = nil) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Une tuile de la grille : en-tête, un grand chiffre suivi de son unité en petit, et de quoi
/// dire où en est ce chiffre — une note, ou une barre de progression.
///
/// C'est le « Steps count / Workout time » des références : deux tuiles côte à côte plutôt qu'une
/// carte pleine largeur découpée en quatre colonnes par des filets. La différence n'est pas
/// décorative — à quatre colonnes, chaque chiffre reçoit un quart de la largeur de l'écran et se
/// retrouve à devoir rétrécir pour tenir ; à deux, il a la place d'être un titre.
struct RUStatTile: View {
    var icon: String
    var tint: Color
    var title: String
    var value: String
    /// L'unité, en petit, juste après le chiffre — « 3 240 **steps** », « 32 **mins** ». Elle est
    /// séparée du chiffre pour que le chiffre porte seul la taille : « 3240 steps » en un seul
    /// `Text` obligerait l'unité à grandir avec lui.
    var unit: String?
    var footnote: String?
    /// 0...1, ou `nil` quand ce chiffre ne va nulle part (un cumul de km n'a pas d'objectif).
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: icon, tint: tint, title: title)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .displayStyle(22)
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if let unit {
                        Text(LocalizedStringKey(unit))
                            .font(RUFont.sans(10.5, weight: .semibold))
                            .foregroundColor(RUColor.text3)
                    }
                }
                if let progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(RUColor.card2)
                            Capsule().fill(tint)
                                .frame(width: geo.size.width * max(0, min(1, progress)))
                        }
                    }
                    .frame(height: 5)
                } else if let footnote {
                    Text(LocalizedStringKey(footnote))
                        .font(RUFont.sans(10))
                        .foregroundColor(RUColor.text3)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ruCard()
        .accessibilityElement(children: .combine)
        // L'unité repasse par `LocalizedStringKey` comme le reste : `Text(String)` ne consulte pas
        // le catalogue, et VoiceOver aurait lu « 12 sorties » à une utilisatrice anglophone.
        .accessibilityLabel(
            Text(LocalizedStringKey(title)) + Text(", ") + Text(value)
            + (unit.map { Text(" ") + Text(LocalizedStringKey($0)) } ?? Text(""))
        )
    }
}
