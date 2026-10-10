import SwiftUI

/// Le jour J d'un duathlon : où passe le temps, où l'on mange, et le piège de la première
/// course.
///
/// Le plan répond à « que faire cette semaine ». Il ne répond pas à « comment se passe la
/// journée » — et un duathlon se perd sur ses premiers kilomètres, deux heures avant que ça se
/// voie. C'est la seule chose qu'aucune séance n'enseigne, parce qu'elle ne se joue pas aux
/// jambes mais à la tête, une fois, au départ.
///
/// Les fourchettes de ravitaillement viennent d'`UltraRaceDay` par `DuathlonRaceDay` : la
/// physiologie de l'endurance ne change pas parce qu'on change de sport. Ce qui change est la
/// FENÊTRE — ici, un vélo pris en sandwich entre deux courses.
struct DuathlonRaceDaySheet: View {
    var format: DuathlonFormat
    /// Le temps visé, en minutes. Sous trente minutes — donc quand on ne sait pas — les totaux
    /// se taisent plutôt que d'afficher des zéros qui auraient l'air d'une réponse. Même parti
    /// que les deux autres feuilles du jour J.
    var minutesVisees: Int

    private var connu: Bool { minutesVisees >= 30 }
    private var r: DuathlonRaceDay.Repartition {
        DuathlonRaceDay.repartition(format: format, minutesVisees: minutesVisees)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Le jour J").displayStyle(22).foregroundColor(RUColor.textPrimary).padding(.top, 8)
                Text("Un duathlon se décide sur ses premiers kilomètres, et la facture arrive deux heures plus tard. Ce qui suit ne se joue pas aux jambes.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)

                journee
                premiereCourse
                ravitaillement
                transitions
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
                    ligne("figure.run", "Première course", format.premiereCourseKm, r.premiereCourse)
                    ligne("bicycle", "Vélo", format.veloKm, r.velo)
                    ligne("figure.run", "Seconde course", format.secondeCourseKm, r.secondeCourse)
                    ligneTransitions
                }
            }

            Text(phraseDeLaJournee)
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    /// Ce que la répartition dit, et qui n'est pas la même chose selon le format.
    ///
    /// Sur les deux formats courts, la seconde course est plus courte que la première : elle
    /// s'arrache. Sur les deux longs, elle est aussi longue ou bien plus, et tout ce qu'on a
    /// pris d'avance avant compte contre soi.
    private var phraseDeLaJournee: LocalizedStringKey {
        DuathlonRaceDay.secondeCourseAuMoinsAussiLongue(format)
            ? "Le vélo prend plus de la moitié de la journée, mais la seconde course est aussi longue que la première — parfois bien plus. Tout ce que tu auras pris d'avance avant comptera contre toi là."
            : "Le vélo prend près de la moitié de la journée, et la seconde course à peine un sixième. Elle est courte : c'est ce qui donne envie de partir vite sur la première, et c'est l'erreur."
    }

    private func ligne(_ icone: String, _ titre: LocalizedStringKey, _ km: Double,
                       _ minutes: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icone)
                .font(.system(size: 14, weight: .semibold)).foregroundColor(RUColor.rose2)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(titre)
                    .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                // `DuathlonFormat.km` et pas une mise en forme écrite ici : « 2.5 km » sous une
                // carte qui dit « 2,5 km » serait le même écran se contredisant.
                Text(verbatim: DuathlonFormat.km(km))
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
            }
            Spacer(minLength: 0)
            Text(verbatim: TimeFormat.duree(minutes * 60))
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
            Text(verbatim: TimeFormat.duree(r.transitions * 60))
                .font(RUFont.display(18)).foregroundColor(RUColor.textPrimary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    // MARK: Le piège

    private var premiereCourse: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "exclamationmark.triangle", tint: RUColor.rose, title: "La première course")

            Text(phraseDuDepart)
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Aucun chiffre, et c'est délibéré — voir `DuathlonRaceDay.lePiegeEstLaPremiereCourse`.
            // « Pars vingt secondes plus lentement » serait une fausse précision : l'écart juste
            // dépend du format, du niveau et du jour, et personne ne l'a mesuré pour cette app.
            Text("LA FACTURE N'ARRIVE PAS TOUT DE SUITE. Elle arrive à la seconde course, et elle ne se renégocie pas : on ne rattrape pas sur la fin d'un duathlon ce qu'on a dépensé au début. Pars plus doucement que ce qui te semble juste.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("C'est la raison d'être de la répétition générale du bloc d'affûtage : course → vélo → course, une fois, pour sentir ce que ça fait avant que ça compte.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    // MARK: Le vélo est la seule fenêtre

    private var ravitaillement: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "fork.knife", tint: RUColor.rose, title: "Le vélo est la seule fenêtre")

            Text("Rien avant : la première course se fait à vide, et c'est sans conséquence, elle est courte. Rien après non plus — à pied, sur un estomac déjà secoué, presque tout est refusé.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if connu {
                HStack(spacing: 8) {
                    chiffre(glucides, Text("G DE GLUCIDES SUR LE VÉLO"))
                    chiffre(eau, Text("ML À EMBARQUER"))
                }
            }

            Text("Tout ce dont la seconde course aura besoin se prend sur la selle. Pas idéalement : c'est la règle. Et ça se teste à l'entraînement, sur les enchaînements — jamais le jour J.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    private var glucides: String {
        let g = DuathlonRaceDay.glucidesSurLeVelo(r)
        return "\(g.min)–\(g.max)"
    }

    private var eau: String {
        let e = DuathlonRaceDay.eauSurLeVelo(r)
        return "\(e.min)–\(e.max)"
    }

    // MARK: Les transitions

    private var transitions: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "arrow.triangle.swap", tint: RUColor.violet, title: "Les transitions")

            // Pas de « c'est là que ça se gagne » : sur un duathlon, les transitions pèsent
            // entre 1,6 et 3,6 % selon le format — jamais le levier principal. Le dire
            // autrement serait envoyer quelqu'un travailler ce qui ne changera pas sa journée.
            Text("Deux transitions, et aucune combinaison à retirer : elles sont plus courtes qu'en triathlon, et elles ne sont jamais là que ta journée se joue. Deux ou trois pour cent du total, pas davantage.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(phraseDeT1)
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    /// Deux phrases qui parlent À quelqu'un, donc qui s'accordent. Écrites dans les deux
    /// formes et choisies à l'affichage : un homme qui lit « tu seras fraîche » n'a pas affaire
    /// à une voix, il a affaire à une app qui ne l'a pas écouté. Voir `Accord`.
    private var phraseDuDepart: LocalizedStringKey {
        LocalizedStringKey(Accord.selon(
            f: String(localized: "Tu seras fraîche, en groupe, et cinq ou dix kilomètres ne font pas peur quand c'est ta distance d'entraînement. C'est exactement pour ça que presque tout le monde part trop vite."),
            m: String(localized: "Tu seras frais, en groupe, et cinq ou dix kilomètres ne font pas peur quand c'est ta distance d'entraînement. C'est exactement pour ça que presque tout le monde part trop vite.")))
    }

    private var phraseDeT1: LocalizedStringKey {
        LocalizedStringKey(Accord.selon(
            f: String(localized: "Elles méritent quand même d'être répétées une fois — non pour le chrono, mais pour ne pas découvrir en pleine course qu'on a oublié quelque chose. T1 surtout : on y arrive déjà essoufflée, et c'est là qu'on enfile un casque à l'envers."),
            m: String(localized: "Elles méritent quand même d'être répétées une fois — non pour le chrono, mais pour ne pas découvrir en pleine course qu'on a oublié quelque chose. T1 surtout : on y arrive déjà essoufflé, et c'est là qu'on enfile un casque à l'envers.")))
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
