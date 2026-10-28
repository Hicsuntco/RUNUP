import SwiftUI

/// UNE COURBE DE QUELQUES POINTS, SOUS UN CHIFFRE.
///
/// # CE QU'ELLE RÉPARE
///
/// Une tuile de statistique disait « 145 km » et rien d'autre. C'est une valeur sans échelle :
/// on ne sait pas si c'est beaucoup, si ça monte, si la semaine dernière valait le double. La
/// carte faisait 96 points de haut dont 38 de blanc, et ce blanc ne disait rien.
///
/// La courbe occupe ce blanc-là. Le chiffre cesse d'être une valeur isolée pour devenir le
/// DERNIER POINT d'une série — ce qui est sa vraie nature, puisqu'il change chaque semaine.
///
/// # CE QU'ELLE NE FAIT PAS, ET POURQUOI
///
/// NI AXE, NI GRILLE, NI ÉTIQUETTE. À vingt-deux points de haut, un axe prend plus de place
/// que la donnée et une valeur par point est illisible. Une sparkline répond à une seule
/// question — « ça monte ou ça descend ? » — et tout ce qui n'y répond pas est du bruit.
///
/// PAS DE TOUCHER PAR POINT. Huit semaines sur la largeur d'une demi-carte font environ neuf
/// points par semaine : une cible tactile de neuf points est sous la moitié du minimum d'Apple.
/// Un point qu'on ne peut pas viser ne doit pas prétendre être tapable.
///
/// # VOICEOVER
///
/// La courbe porte une information que rien d'autre à l'écran ne porte. L'effacer de
/// l'accessibilité — le réflexe pour un « décor » — reviendrait à la réserver à qui voit.
/// Elle annonce donc sa tendance en toutes lettres : ça monte, ça baisse, ou c'est stable.
/// Sans valeurs, parce que leur unité dépend de l'appelant (des km, un compte, des minutes)
/// et qu'une sparkline ne promet pas des valeurs — elle promet un sens.
struct RUSparkline: View {
    var valeurs: [Double]
    var couleur: Color = RUColor.rose
    var hauteur: CGFloat = 22

    /// Le dernier point face à la moyenne de ce qui précède. Le seuil de 8 % évite qu'une
    /// variation de rien s'annonce comme une tendance.
    private enum Tendance { case hausse, baisse, stable }
    private var tendance: Tendance {
        guard valeurs.count >= 2 else { return .stable }
        let precedents = valeurs.dropLast()
        let moyenne = precedents.reduce(0, +) / Double(precedents.count)
        guard moyenne > 0, let dernier = valeurs.last else { return .stable }
        let ecart = (dernier - moyenne) / moyenne
        if ecart > 0.08 { return .hausse }
        if ecart < -0.08 { return .baisse }
        return .stable
    }

    private var annonce: String {
        switch tendance {
        case .hausse: return String(localized: "Tendance en hausse sur les dernières semaines")
        case .baisse: return String(localized: "Tendance en baisse sur les dernières semaines")
        case .stable: return String(localized: "Tendance stable sur les dernières semaines")
        }
    }

    var body: some View {
        // Deux points au moins, et au moins un non nul : une ligne plate au ras du sol ne dit
        // pas « c'est bas », elle dit « il n'y a rien » — et une carte vide vaut mieux qu'un
        // graphique qui ment.
        if valeurs.count >= 2, let plafond = valeurs.max(), plafond > 0 {
            GeometryReader { geo in
                let l = geo.size.width, h = geo.size.height
                let pas = valeurs.count > 1 ? l / CGFloat(valeurs.count - 1) : l
                // Deux points de marge en haut pour que la pointe et son disque ne soient pas
                // coupés par le bord de la vue.
                let points = valeurs.enumerated().map { i, v in
                    CGPoint(x: CGFloat(i) * pas, y: h - 2 - (h - 4) * CGFloat(v / plafond))
                }
                ZStack {
                    // L'aire d'abord, la ligne par-dessus : une aire tracée après mangerait le
                    // trait sur sa moitié basse.
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h))
                        points.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: l, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [couleur.opacity(0.22), couleur.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: points[0])
                        points.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(couleur, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    // Le dernier point marqué : c'est celui que le chiffre au-dessus annonce,
                    // et sans lui l'œil ne sait pas de quel bout la série se lit.
                    if let fin = points.last {
                        Circle().fill(couleur).frame(width: 4, height: 4).position(fin)
                    }
                }
            }
            .frame(height: hauteur)
            .accessibilityElement()
            .accessibilityLabel(annonce)
        }
    }
}
