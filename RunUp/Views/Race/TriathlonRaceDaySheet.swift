import SwiftUI

/// Le jour J d'un triathlon : où passe le temps, où l'on mange, ce qui se perd en transition.
///
/// Le plan répond à « que faire cette semaine ». Il ne répond pas à « comment se passe la
/// journée », et un triathlon se perd au ventre et en transition bien plus souvent qu'aux
/// jambes. Les trois sections de cet écran sont les trois choses qu'aucune séance n'enseigne.
///
/// Les fourchettes viennent d'`UltraRaceDay` par `TriathlonRaceDay` : la physiologie de
/// l'endurance ne change pas parce qu'on change de sport. Ce qui change est la RÉPARTITION, et
/// c'est tout l'objet de cet écran — la même somme horaire, concentrée sur une fenêtre qui
/// exclut la natation et se referme dès le début de la course.
struct TriathlonRaceDaySheet: View {
    var format: TriathlonFormat
    /// Le temps visé, en minutes. Zéro — donc quand on ne sait pas — fait taire les totaux
    /// plutôt que d'afficher des zéros qui auraient l'air d'une réponse. Même parti que
    /// `UltraRaceDaySheet`.
    var minutesVisees: Int

    private var connu: Bool { minutesVisees >= 30 }
    private var r: TriathlonRaceDay.Repartition {
        TriathlonRaceDay.repartition(format: format, minutesVisees: minutesVisees)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Le jour J").displayStyle(22).foregroundColor(RUColor.textPrimary).padding(.top, 8)
                Text("Trois choses décident d'un triathlon, et aucune n'est ton entraînement. Elles se préparent — et elles se testent à l'entraînement, jamais le jour J.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)

                journee
                ravitaillement
                transitions
                combinaison
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    // MARK: Où passe le temps

    private var journee: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "clock", tint: RUColor.violet, title: "Où passe la journée")

            if connu {
                VStack(spacing: 6) {
                    ligne("figure.pool.swim", "Natation", format.nageMetres, "m", r.nage)
                    ligne("bicycle", "Vélo", Int(format.veloKm.rounded()), "km", r.velo)
                    ligne("figure.run", "Course", Int(format.courseKm.rounded()), "km", r.course)
                    ligneTransitions
                }
            }

            Text("Le vélo prend à peu près la moitié de la journée — plus que les deux autres réunies sur un format long. C'est lui qui décide de ce que tu auras dans les jambes en descendant de selle.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    private func ligne(_ icone: String, _ titre: LocalizedStringKey, _ distance: Int,
                       _ unite: LocalizedStringKey, _ minutes: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icone)
                .font(.system(size: 14, weight: .semibold)).foregroundColor(RUColor.rose2)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(titre)
                    .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                (Text(verbatim: "\(distance) ") + Text(unite))
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
            }
            Spacer(minLength: 0)
            Text(verbatim: TimeFormat.compacte(minutes * 60))
                .font(RUFont.display(18)).foregroundColor(RUColor.textPrimary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    private var ligneTransitions: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 14, weight: .semibold)).foregroundColor(RUColor.rose2)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Transitions")
                    .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                Text("T1 et T2")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
            }
            Spacer(minLength: 0)
            Text(verbatim: TimeFormat.compacte(r.transitions * 60))
                .font(RUFont.display(18)).foregroundColor(RUColor.textPrimary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    // MARK: On ne mange pas dans l'eau

    private var ravitaillement: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "fork.knife", tint: RUColor.rose, title: "On ne mange pas dans l'eau")

            Text("La natation ne permet aucun ravitaillement, et la combinaison comprime l'estomac. Ta nutrition commence à la sortie de l'eau — alors qu'une partie de l'effort est déjà faite.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if connu {
                HStack(spacing: 8) {
                    chiffre(glucides, Text("G DE GLUCIDES SUR LE VÉLO"))
                    chiffre(eau, Text("ML À EMBARQUER"))
                }
            }

            Text("TOUT CE QUI SERA NÉCESSAIRE POUR LA COURSE SE PREND SUR LE VÉLO. Pas idéalement : c'est la règle. À pied, après des heures de selle, l'estomac refuse presque tout — et c'est pour ça qu'on peut bien nager, bien rouler, et s'arrêter de courir.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    private var glucides: String {
        let g = TriathlonRaceDay.glucidesSurLeVelo(r)
        return "\(g.min)–\(g.max)"
    }

    private var eau: String {
        let e = TriathlonRaceDay.eauSurLeVelo(r)
        return "\(e.min)–\(e.max)"
    }

    // MARK: Les transitions

    private var transitions: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "arrow.triangle.swap", tint: RUColor.lime, title: "Les transitions")

            Text(phraseDesTransitions)
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Deux minutes gagnées là, c'est deux minutes de chrono sans un battement de cœur de plus. Pose ton matériel dans l'ordre où tu le prendras, répète-le une fois, et tu ne chercheras rien le jour J.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    /// La phrase change avec le format, parce que le conseil n'est pas le même.
    ///
    /// Les transitions pèsent sept pour cent d'un sprint et moins de deux d'une longue distance.
    /// Dire « un triathlon se gagne en transition » à quelqu'un qui prépare un Ironman serait
    /// l'envoyer travailler la seule chose qui ne changera rien à sa journée.
    private var phraseDesTransitions: LocalizedStringKey {
        TriathlonRaceDay.transitionsDecisives(format)
            ? "Sur un format court, les transitions pèsent près d'un dixième de la journée. C'est là que ce format se gagne, et c'est la seule partie qui ne coûte aucune condition physique."
            : "Sur un format long, les transitions pèsent peu : le temps est ailleurs. Elles méritent quand même d'être répétées une fois — non pour le chrono, mais pour ne pas découvrir fatiguée qu'on a oublié quelque chose."
    }

    // MARK: La combinaison

    private var combinaison: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "drop", tint: RUColor.violet, title: "La combinaison")

            Text("Elle est obligatoire en dessous d'une certaine température d'eau, et INTERDITE au-dessus d'une autre. Les deux seuils dépendent de la fédération, du format et de l'année : ils se lisent au briefing, et nulle part ailleurs.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Aucun chiffre, et c'est délibéré — voir
            // `TriathlonRaceDay.combinaisonEstUneRegleDeCourse`. Un seuil faux ici n'est pas une
            // approximation : c'est quelqu'un qui arrive au départ avec une combinaison qu'on va
            // lui refuser, ou sans celle qu'on va lui réclamer.
            Text("Ce qui se prépare, en revanche : nager dedans avant le jour J. Elle serre, elle gêne la respiration, et elle change la position dans l'eau. Et l'enlever vite s'apprend — c'est la moitié de T1.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    private func chiffre(_ valeur: String, _ etiquette: Text) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: valeur).displayStyle(22).foregroundColor(RUColor.rose2)
                .lineLimit(1).minimumScaleFactor(0.5)
            etiquette
                .font(RUFont.sans(.micro, weight: .bold))
                .foregroundColor(RUColor.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }
}
