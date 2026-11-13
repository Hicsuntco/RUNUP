import SwiftUI

/// # LA SEMAINE, DESSINÉE — SEPT JOURS, LEUR FAMILLE, LEUR DURÉE
///
/// Le même langage que `La forme du plan`, à l'autre échelle. Le plan montre seize semaines de
/// volume en barres de phase ; ce ruban montre les sept jours d'UNE semaine en barres de famille.
/// Ce n'est pas une répétition, c'est une grammaire : la forme d'un entraînement se lit en
/// hauteurs côte à côte, qu'on regarde un bloc ou une semaine.
///
/// Il vit sur une carte de nuit — voir `CarteDeNuit` pour la règle — donc toutes ses encres sont
/// celles de la nuit et non celles du thème.
///
/// ## POURQUOI LA HAUTEUR DIT LA DURÉE
///
/// Sept pastilles de même taille auraient été une décoration : on aurait su quels jours portent
/// une séance, ce que le plan dit déjà ailleurs. La hauteur en fait une INFORMATION — une sortie
/// longue domine sa semaine, un footing de trente minutes ne prétend pas le contraire, et un
/// bloc de fractionné court se voit pour ce qu'il est : bref et intense, donc petit et vif.
struct RubanDeSemaine: View {
    /// Les sept jours, lundi en premier. Les jours sans séance sont passés aussi : un creux fait
    /// partie de la forme d'une semaine.
    var jours: [PlannedDay]
    /// 0 = lundi. Hors de 0...6, aucun jour n'est marqué.
    var aujourdHui: Int

    /// ## POURQUOI UNE MARQUE ÉTROITE ET NON UNE COLONNE PLEINE
    ///
    /// La première version laissait la barre occuper toute sa colonne. Sur la capture du
    /// 13 novembre, sept colonnes dans la largeur d'un téléphone donnaient des barres AUSSI LARGES
    /// QUE HAUTES : quatre blocs de couleur et trois tirets gris, c'est-à-dire un jouet, pas une
    /// mesure. Le graphique du Plan n'a pas ce défaut parce qu'il a seize barres dans la même
    /// largeur — la finesse y vient du nombre.
    ///
    /// À sept, la finesse se décide. Quatorze points de large, centrés dans leur colonne : la
    /// hauteur redevient ce qu'on lit, et l'air entre les marques fait le rythme de la semaine.
    static let largeurDeLaMarque: CGFloat = 14

    /// Un jour sans séance garde un trait. Un creux fait partie de la forme d'une semaine ; une
    /// colonne vide en ferait un trou.
    static let hauteurDuRepos: CGFloat = 14

    /// La plus longue séance de la semaine donne l'échelle. `max(1, …)` : une semaine entièrement
    /// au repos ne doit pas diviser par zéro, elle doit dessiner sept creux.
    private var plusLongue: Int {
        max(1, jours.compactMap { $0.session?.durationMinutes }.max() ?? 1)
    }

    /// Les initiales des jours, lundi en premier, dans la langue de l'appareil.
    ///
    /// `veryShortStandaloneWeekdaySymbols` commence au dimanche en français comme en anglais —
    /// d'où le décalage de 1. L'écrire à la main aurait donné « L M M J V S D » en espagnol,
    /// où ce sont « L M X J V S D ».
    private var initiales: [String] {
        let symboles = Calendar.current.veryShortStandaloneWeekdaySymbols
        guard symboles.count == 7 else { return Array(repeating: "", count: 7) }
        return (0..<7).map { symboles[($0 + 1) % 7] }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(jours) { jour in
                colonne(jour)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("La semaine que ton coach regarde")
        .accessibilityValue(resume)
    }

    private func colonne(_ jour: PlannedDay) -> some View {
        let famille = jour.session?.family ?? .rest
        let minutes = jour.session?.durationMinutes ?? 0
        let hauteur = minutes == 0 ? Self.hauteurDuRepos
            : max(22, CGFloat(minutes) / CGFloat(plusLongue) * 76)
        return VStack(spacing: 6) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: RUSpacing.radiusBar, style: .continuous)
                .fill(famille.tintSurLaNuit)
                .frame(width: Self.largeurDeLaMarque)
                // Une séance faite recule sans disparaître — la même règle que les semaines
                // passées du graphique du plan, et la même valeur.
                .opacity(jour.completed ? 0.3 : 1)
                .frame(height: hauteur)
            Text(verbatim: initiales[min(max(0, jour.weekday), 6)])
                .font(RUFont.sans(.micro, weight: .bold))
                .foregroundColor(jour.weekday == aujourdHui ? RUColor.surLaNuit : RUColor.surLaNuit2)
                .lineLimit(1)
            // Le repère du jour, identique à celui de la semaine en cours sur le graphique du
            // plan : même objet, même forme, même taille.
            Circle()
                .fill(jour.weekday == aujourdHui ? RUColor.surLaNuit : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    /// Ce que VoiceOver lit à la place du dessin : combien de séances sont faites, sur combien.
    ///
    /// L'accord se règle sur `faites`, pas sur le total : c'est lui qui gouverne « séance faite ».
    /// « 0 séance faite sur 4 » et « 1 séance faite sur 4 » sont justes, « 0 séances faites » ne
    /// l'est pas — et le zéro est le cas du lundi matin, donc le plus fréquent des deux.
    private var resume: String {
        let prevues = jours.filter { ($0.session?.durationMinutes ?? 0) > 0 }
        let faites = prevues.filter(\.completed).count
        return Pluriel.choisir(faites,
            String(localized: "\(faites) séance faite sur \(prevues.count)"),
            String(localized: "\(faites) séances faites sur \(prevues.count)"))
    }
}
