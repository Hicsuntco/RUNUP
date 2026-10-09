import SwiftUI

/// Les trois choses qui décident d'un ultra et dont aucune n'est l'entraînement.
///
/// Le plan répond à « que courir cette semaine ». Il ne répond ni au ravitaillement, ni au
/// matériel, ni à la nuit — et c'est là que se perdent les ultras : au ventre, au contrôle du sac
/// et à trois heures du matin, bien plus souvent qu'aux jambes.
///
/// Les fourchettes viennent de `UltraRaceDay`, qui dit aussi pourquoi ce sont des fourchettes.
/// Ici, elles sont ramenées à LA course visée : un total de glucides, un nombre de prises, des
/// litres. « 60 à 90 g par heure » est juste et abstrait ; « 1 300 g, soit 29 prises » fait
/// comprendre qu'un ultra se prépare aussi en faisant les courses.
struct UltraRaceDaySheet: View {
    /// Le temps d'effort estimé de la course, en secondes. Sous une heure — donc quand on ne sait
    /// pas — l'écran garde les fourchettes horaires et tait les totaux, plutôt que d'afficher des
    /// zéros qui auraient l'air d'une réponse.
    var tempsDeffortSecondes: Double

    private var heures: Double { UltraRaceDay.heures(tempsDeffortSecondes) }
    private var connu: Bool { heures >= 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Le jour J").displayStyle(22).foregroundColor(RUColor.textPrimary).padding(.top, 8)
                Text("Trois choses décident d'un ultra, et aucune n'est ton entraînement. Elles se préparent — et elles se testent sur tes sorties longues, jamais le jour J.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)

                ravitaillement
                materiel
                nuit
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    // MARK: Le ravitaillement

    private var ravitaillement: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "fork.knife", tint: RUColor.rose, title: "Le ravitaillement")

            HStack(spacing: 8) {
                chiffre(glucidesParHeure, Text("G DE GLUCIDES / H"))
                chiffre(eauParHeure, Text("ML DE BOISSON / H"))
                chiffre(sodiumParHeure, Text("MG DE SEL / H"))
            }

            if connu {
                // Deux phrases et non une, et ce n'est pas un choix de style : six interpolations
                // dans une seule chaîne suffisent à faire abandonner le vérificateur de types de
                // Swift (« unable to type-check this expression in reasonable time »), qui
                // abandonne à la compilation. Trois et trois passent.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sur une estimation de **\(heuresArrondies) h d'effort**, il te faudra **\(glucidesBas) à \(glucidesHaut) g de glucides**.")
                    Text("Soit à peu près **\(prises) prises**, et **\(litresBas) à \(litresHaut) litres** de boisson.")
                }
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
            }

            puces([
                Accord.selon(
                    f: String(localized: "Une prise toutes les \(UltraRaceDay.minutesEntreDeuxPrises) minutes, à la montre. « Manger régulièrement » ne se fait pas : une consigne sans horloge ne tient pas quand on est fatiguée."),
                    m: String(localized: "Une prise toutes les \(UltraRaceDay.minutesEntreDeuxPrises) minutes, à la montre. « Manger régulièrement » ne se fait pas : une consigne sans horloge ne tient pas quand on est fatigué.")),
                String(localized: "Du salé dès la première heure. Six heures de sucré, personne ne les tient — et c'est le dégoût, pas la faim, qui fait arrêter de manger."),
                String(localized: "Bois par petites gorgées, souvent. Un demi-litre avalé d'un coup au ravitaillement ressort au premier raidillon."),
                String(localized: "Rien de nouveau le jour J. Ce que tu mangeras en course, tu l'as déjà mangé en sortie longue — c'est aussi à ça qu'elles servent.")
            ])
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    // MARK: Le matériel

    private var materiel: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "backpack", tint: RUColor.violet, title: "Le matériel")

            // L'AVERTISSEMENT EN PREMIER, ET PAS EN NOTE DE BAS DE CARTE. Un sac non conforme est
            // un refus au départ : si une seule phrase de cette carte doit être lue, c'est
            // celle-là, et elle dit que cette liste n'est pas celle qui sera contrôlée.
            Text("La liste qui compte est celle de **ta** course : l'organisation la publie, et la contrôle au départ. Celle-ci est le socle commun des grands trails — pars de là, puis relis la leur.")
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)

            puces([
                String(localized: "Une veste imperméable à capuche — une membrane, pas un coupe-vent. C'est le point le plus souvent recalé au contrôle."),
                String(localized: "Deux frontales, et des piles de rechange pour chacune."),
                String(localized: "Un litre d'eau au minimum, en contenance embarquée."),
                String(localized: "Un gobelet pliable : il n'y en a plus sur les ravitaillements."),
                String(localized: "Couverture de survie et sifflet."),
                String(localized: "Une bande adhésive élastique — elle répare une cheville, une chaussure et un bâton."),
                String(localized: "Téléphone chargé, en mode économie d'énergie, avec les numéros de l'organisation."),
                String(localized: "Une réserve alimentaire que tu ne touches pas : elle est là pour l'heure où tout le reste est fini."),
                String(localized: "Bonnet et gants dès que la nuit est possible. On a froid à l'arrêt, pas en mouvement."),
                String(localized: "Des bâtons si tu t'en sers — et seulement si tu t'en es servi à l'entraînement.")
            ])
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    // MARK: La nuit

    private var nuit: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "moon.stars.fill", tint: RUColor.cyan, title: "La nuit")
            verdictDeLaNuit
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)

            puces([
                String(localized: "Deux frontales, parce qu'une frontale qui s'éteint en descente technique arrête la course — et parce que la plupart des grands trails les exigent au contrôle du sac."),
                String(localized: "Le creux de trois à cinq heures du matin est physiologique, pas un mauvais jour. Mange chaud, marche, remets-toi en mouvement : ça passe."),
                Accord.selon(
                    f: String(localized: "La veste s'enfile AVANT d'entrer au ravitaillement, pas après. Dix minutes assise sans se couvrir coûtent une heure à se réchauffer."),
                    m: String(localized: "La veste s'enfile AVANT d'entrer au ravitaillement, pas après. Dix minutes assis sans se couvrir coûtent une heure à se réchauffer.")),
                String(localized: "Le faisceau écrase le relief : tu verras moins bien tes pieds, donc tu iras moins vite. C'est normal, et ça ne dit rien de ta forme."),
                String(localized: "Ta sortie de nuit du bloc spécifique existe pour que rien de tout ça ne soit une découverte.")
            ])
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    /// Pas de `@ViewBuilder` ici, et c'est volontaire : un `switch` sous `@ViewBuilder` rend un
    /// `_ConditionalContent`, pas un `Text`. Avec des `return`, le type reste `Text` — donc
    /// `.font()` et `.foregroundColor()` restent les surcharges de `Text`, qui se composent.
    private var verdictDeLaNuit: Text {
        switch UltraRaceDay.nuit(tempsDeffortSecondes: tempsDeffortSecondes) {
        case .certaine:
            return Text("À cette durée d'effort, aucun départ en matinée ne te fait finir avant la nuit : **tu courras de nuit**, c'est acquis.")
        case .possible:
            return Text("Selon l'heure du départ, **tu peux finir de nuit**. Et une frontale qu'on n'a jamais sortie est exactement le matériel qui manque.")
        case .aucune:
            return Text("Ta course devrait tenir dans le jour — emporte une frontale quand même : un départ matinal, un sous-bois ou deux heures de plus que prévu suffisent.")
        }
    }

    // MARK: Les nombres, sortis des vues

    // Chaque valeur dans son propre `let` plutôt qu'en ligne dans l'interpolation : le
    // vérificateur de types de Swift abandonne (« unable to type-check in reasonable time »)
    // quand une seule chaîne mêle cinq calculs, et il abandonne à la compilation, pas à l'écran.
    private var glucidesParHeure: String { "\(UltraRaceDay.glucidesParHeureMin)-\(UltraRaceDay.glucidesParHeureMax)" }
    private var eauParHeure: String { "\(UltraRaceDay.eauParHeureMinML)-\(UltraRaceDay.eauParHeureMaxML)" }
    private var sodiumParHeure: String { "\(UltraRaceDay.sodiumParHeureMinMG)-\(UltraRaceDay.sodiumParHeureMaxMG)" }
    private var heuresArrondies: Int { Int(heures.rounded()) }
    private var prises: Int { UltraRaceDay.nombreDePrises(tempsDeffortSecondes: tempsDeffortSecondes) }
    private var glucidesBas: Int { UltraRaceDay.glucidesTotaux(tempsDeffortSecondes: tempsDeffortSecondes).bas }
    private var glucidesHaut: Int { UltraRaceDay.glucidesTotaux(tempsDeffortSecondes: tempsDeffortSecondes).haut }
    private var litresBas: String { litres(UltraRaceDay.litresTotaux(tempsDeffortSecondes: tempsDeffortSecondes).bas) }
    private var litresHaut: String { litres(UltraRaceDay.litresTotaux(tempsDeffortSecondes: tempsDeffortSecondes).haut) }

    /// « 1,5 » et non « 1.5 » en français : un litre et demi s'écrit avec une virgule, et le
    /// formateur de la langue courante est la seule façon de ne pas avoir à le savoir.
    private func litres(_ valeur: Double) -> String {
        let decimales = valeur == valeur.rounded() ? 0 : 1
        return valeur.formatted(.number.precision(.fractionLength(decimales)))
    }

    // MARK: Les deux briques d'affichage

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

    /// `Text(verbatim:)` et non `Text(_:)` : les lignes arrivent DÉJÀ traduites, résolues par
    /// `String(localized:)` au-dessus. Les repasser dans le catalogue chercherait une clé qui est
    /// la traduction anglaise ou espagnole, ne la trouverait pas, et afficherait… le bon texte,
    /// par accident. Un accident qui tient jusqu'au jour où une clé existe par coïncidence.
    private func puces(_ lignes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lignes, id: \.self) { ligne in
                HStack(alignment: .top, spacing: 9) {
                    Circle().fill(RUColor.text4).frame(width: 5, height: 5).padding(.top, 7)
                    Text(verbatim: ligne)
                        .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
