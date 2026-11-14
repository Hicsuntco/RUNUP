import SwiftUI

/// # LA SEMAINE, DESSINÉE — SEPT JOURS, LEUR FAMILLE, LEUR DURÉE
///
/// Le même langage que `La forme du plan`, à l'autre échelle. Le plan montre seize semaines de
/// volume en barres de phase ; ce ruban montre les sept jours d'UNE semaine en barres de famille.
/// Ce n'est pas une répétition, c'est une grammaire : la forme d'un entraînement se lit en
/// hauteurs côte à côte, qu'on regarde un bloc ou une semaine.
///
/// IL VIT SUR LES DEUX FONDS. Né sur la carte de nuit du Coach — voir `CarteDeNuit` pour la
/// règle —, il est devenu le 14 novembre la semaine de l'accueil aussi, sur carte blanche. Ses
/// encres suivent donc `surLaNuit`, et non le thème.
///
/// # UNE SEULE SEMAINE DANS L'APP
///
/// L'accueil avait sa propre bande : sept lettres, sept quantièmes, une pastille rose cochée pour
/// les séances faites. Elle disait QUEL JOUR on est et CE QUI EST FAIT — un calendrier. Le ruban
/// dit en plus QUOI et COMBIEN DE TEMPS, par la couleur et la hauteur.
///
/// Deux objets « semaine » dans la même app, dessinés dans deux langages, c'est la divergence que
/// `traceBackground` décrit depuis septembre, et celle-ci était de moi : j'ai ajouté le ruban au
/// Coach le 13 novembre sans voir que l'accueil en avait déjà un. Le ruban reprend donc les
/// quantièmes, et la bande disparaît.
///
/// CE QUI EST PERDU, et c'est dit plutôt que caché : la pastille cochée. Une séance faite recule
/// maintenant à 0,3 d'opacité, comme les semaines faites du graphique du Plan. C'est le geste que
/// l'app emploie déjà partout ailleurs pour dire « c'est derrière toi » ; une coche de plus en
/// aurait fait un deuxième.
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
    /// Sur une carte de nuit, ou sur une carte blanche ?
    ///
    /// Le ruban est né sur la nuit du Coach, et l'accueil le pose sur du blanc depuis qu'il a
    /// remplacé sa bande de semaine. Un booléen plutôt que des couleurs passées à la main :
    /// l'appelant ne choisit pas une palette, il dit sur quel fond il est. Même règle que
    /// `DailyGoalsBarsView` et que `RUColor.surLaNuit`.
    var surLaNuit: Bool = true
    /// Afficher le quantième sous l'initiale.
    ///
    /// L'accueil s'en sert, le Coach non. C'est ce que la bande de l'accueil faisait de plus que
    /// le ruban : elle doublait d'un calendrier, et on y lit « aujourd'hui, c'est le 14 ». Sur le
    /// Coach, la question est « qu'est-ce que je fais cette semaine », et une rangée de chiffres
    /// n'y répond pas.
    var quantiemes: Bool = false

    /// L'encre pleine : blanche sur la nuit, celle du thème sur une carte.
    private var encre: Color { surLaNuit ? RUColor.surLaNuit : RUColor.textPrimary }
    /// L'encre seconde, pour les jours qui ne sont pas aujourd'hui.
    private var encre2: Color { surLaNuit ? RUColor.surLaNuit2 : RUColor.text3 }

    /// Le lundi de la semaine en cours, pour les quantièmes.
    ///
    /// Déduit plutôt que passé : le ruban reçoit déjà `aujourdHui`, et un appelant qui devrait
    /// fournir À LA FOIS l'index du jour et la date du lundi aurait deux occasions de se
    /// contredire.
    private var lundi: Date? {
        let cal = Calendar.current
        let jour = (cal.component(.weekday, from: .now) + 5) % 7
        return cal.date(byAdding: .day, value: -jour, to: cal.startOfDay(for: .now))
    }

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
                    // UN ÉLÉMENT PAR JOUR, ET NON UN RÉSUMÉ POUR TOUT LE RUBAN.
                    //
                    // La bande de l'accueil, que ce ruban remplace, en exposait déjà un par jour
                    // avec son libellé — « mardi 14, séance faite ». La remplacer par un seul
                    // élément résumé aurait été une régression d'accessibilité sur l'écran le
                    // plus ouvert de l'app, échangée contre rien.
                    //
                    // Le Coach y gagne aussi : sa semaine se parcourt jour par jour au lieu de
                    // se lire d'un bloc.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(libelle(jour))
            }
        }
    }

    private func colonne(_ jour: PlannedDay) -> some View {
        let famille = jour.session?.family ?? .rest
        let minutes = jour.session?.durationMinutes ?? 0
        let hauteur = minutes == 0 ? Self.hauteurDuRepos
            : max(22, CGFloat(minutes) / CGFloat(plusLongue) * 76)
        return VStack(spacing: 6) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: RUSpacing.radiusBar, style: .continuous)
                .fill(surLaNuit ? famille.tintSurLaNuit : famille.tint)
                .frame(width: Self.largeurDeLaMarque)
                // Une séance faite recule sans disparaître — la même règle que les semaines
                // passées du graphique du plan, et la même valeur.
                .opacity(jour.completed ? 0.3 : 1)
                .frame(height: hauteur)
            VStack(spacing: 2) {
                Text(verbatim: initiales[min(max(0, jour.weekday), 6)])
                    .font(RUFont.sans(.micro, weight: .bold))
                    .foregroundColor(jour.weekday == aujourdHui ? encre : encre2)
                    .lineLimit(1)
                if quantiemes, let quantieme = quantieme(de: jour.weekday) {
                    Text(verbatim: quantieme)
                        .font(RUFont.sans(.micro, weight: jour.weekday == aujourdHui ? .bold : .regular))
                        .foregroundColor(jour.weekday == aujourdHui ? encre : encre2)
                        .lineLimit(1)
                }
            }
            // Le repère du jour, identique à celui de la semaine en cours sur le graphique du
            // plan : même objet, même forme, même taille.
            Circle()
                .fill(jour.weekday == aujourdHui ? encre : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    /// Le quantième du jour `index` de la semaine en cours, ou `nil` si le calendrier n'a pas su.
    private func quantieme(de index: Int) -> String? {
        guard let lundi,
              let date = Calendar.current.date(byAdding: .day, value: index, to: lundi)
        else { return nil }
        return String(Calendar.current.component(.day, from: date))
    }

    /// Ce que VoiceOver lit sur un jour.
    ///
    /// Les quatre tournures sont celles que la bande de l'accueil employait déjà, mot pour mot :
    /// elles sont au catalogue, traduites, et éprouvées. Les reprendre plutôt que d'en écrire de
    /// nouvelles garde à VoiceOver exactement ce qu'il disait avant le remplacement.
    private func libelle(_ jour: PlannedDay) -> String {
        let index = min(max(0, jour.weekday), 6)
        let nom = quantieme(de: index).map { "\(DayStatus.fullNames[index]) \($0)" }
            ?? DayStatus.fullNames[index]
        if jour.completed { return String(localized: "\(nom), séance faite") }
        if (jour.session?.durationMinutes ?? 0) == 0 { return String(localized: "\(nom), repos") }
        if jour.weekday == aujourdHui { return String(localized: "\(nom), aujourd'hui") }
        return String(localized: "\(nom), à venir")
    }
}
