import SwiftUI

/// « 5,0 / 32 km cette semaine », dessiné UNE fois.
///
/// La même semaine était racontée à deux endroits, dans deux langues. L'accueil affichait
/// « 5,0/32 km sem. » avec une phrase de comparaison ; les Stats affichaient « 5,0 km » à côté de
/// « 1/4 séances prévues » avec une pastille d'écart. Mêmes courses, mêmes dates, deux
/// dénominateurs — des kilomètres d'un côté, des séances de l'autre — et deux mises en forme.
/// Rien n'était faux ; c'est la lecture qui devenait un travail, parce qu'il fallait retraduire
/// d'un écran à l'autre pour comprendre qu'on parlait de la même chose.
///
/// Le dénominateur retenu est le kilomètre. C'est celui du plan (`plannedWeeklyKm`, la somme
/// réelle des séances de la semaine), celui que le classement du club sait déjà comparer entre
/// niveaux, et celui qui bouge à chaque sortie — un compteur de séances ne se déplace que quatre
/// fois par semaine, par paliers, et ne dit rien d'une sortie écourtée.
struct WeekKmSummary: View {
    var doneKm: Double
    /// 0 en course libre : il n'y a alors pas de plan hebdomadaire, donc pas de dénominateur à
    /// inventer — le chiffre reste seul, sans barre.
    var plannedKm: Double
    var lastWeekKm: Double
    /// Vrai quand le plan prévoit LUI-MÊME moins de volume cette semaine — décharge ou affûtage.
    /// Voir `couleurDeLEcart`. Faux par défaut : un appelant qui ne sait pas répondre garde le
    /// comportement d'avant plutôt qu'une affirmation inventée.
    var baisseProgrammee: Bool = false
    /// Une ligne grise sous la barre, quand l'écran a de quoi la remplir. Les séances restent
    /// dites, mais comme une précision — pas comme un second dénominateur en concurrence.
    var footnote: String?

    private var fraction: Double {
        guard plannedKm > 0 else { return 0 }
        return min(1, doneKm / plannedKm)
    }

    private var delta: Double { doneKm - lastWeekKm }

    /// UNE BAISSE PROGRAMMÉE N'EST PAS UNE ALERTE.
    ///
    /// L'écart négatif s'affichait en `amber`, que le système réserve à l'attention. Or le plan
    /// PROGRAMME des semaines où le volume baisse : le fil des phases les annonce lui-même — « en
    /// gris, les semaines de décharge : le volume baisse exprès, c'est là que les progrès se
    /// fixent ». L'app prescrivait donc une baisse, puis la peignait comme une faute.
    ///
    /// L'affûtage compte pour la même raison, et ce n'est pas une extension de confort : son
    /// commentaire dans `trainingBlock` dit qu'il « déleste par construction ». Une semaine
    /// d'affûtage où l'on court moins fait exactement ce qu'on lui demande.
    ///
    /// La baisse reste AFFICHÉE — c'est une information, et la masquer rendrait l'app moins
    /// honnête, pas plus douce. Elle cesse seulement d'être criée.
    private var couleurDeLEcart: Color {
        if delta >= 0 { return RUColor.lime }
        return baisseProgrammee ? RUColor.text3 : RUColor.amber
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                // Le dénominateur reste petit et gris : c'est une précision sur le chiffre, pas
                // une seconde valeur. Un rapport de 1,5 les faisait lire comme deux nombres.
                RUChiffre(valeur: String(format: "%.1f", locale: Locale.current, doneKm),
                          unite: plannedKm > 0
                                 ? "/ \(Int(plannedKm.rounded())) km"
                                 : String(localized: "km"))
                Spacer(minLength: 8)
                // L'écart ne s'affiche que s'il compare quelque chose : une semaine passée à zéro
                // ne produit pas une pastille « +5,0 », qui ferait passer un début pour un progrès.
                if lastWeekKm > 0 {
                    StatChip(
                        text: delta >= 0
                            ? "▲ +\(String(format: "%.1f", locale: Locale.current, delta)) km"
                            : "▼ \(String(format: "%.1f", locale: Locale.current, -delta)) km",
                        color: couleurDeLEcart
                    )
                }
            }
            if plannedKm > 0 {
                LinearBar(fraction: fraction, color: RUColor.rose)
            }
            if let footnote {
                Text(footnote)
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(plannedKm > 0
            ? String(localized: "Cette semaine, \(String(format: "%.1f", locale: Locale.current, doneKm)) kilomètres sur \(Int(plannedKm.rounded())) prévus")
            : String(localized: "Cette semaine, \(String(format: "%.1f", locale: Locale.current, doneKm)) kilomètres"))
    }
}
