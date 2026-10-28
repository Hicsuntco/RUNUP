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
    /// LA TEINTE EST L'EXCEPTION, ET ELLE DOIT VOULOIR DIRE QUELQUE CHOSE.
    ///
    /// Elle était passée explicitement à 55 endroits, sur HUIT valeurs : rose 17, rose2 10,
    /// violet 9, cyan 11, lime 2, amber 2, text3 1, amberText 1. Et elle ne suivait aucune règle.
    /// Sur la seule feuille du triathlon : « Où passe la journée » violet, « On ne mange pas dans
    /// l'eau » rose, « Les transitions » vert, « La combinaison » violet. Sur une seule rangée de
    /// l'écran Stats : règle rose, coureur violet, horloge turquoise.
    ///
    /// Trois de ces teintes — `lime`, `cyan`, `amber` — ne suivent même pas le thème choisi par
    /// l'utilisatrice : ce sont des valeurs fixes. Un accent cyan laissait donc des icônes vertes
    /// et ambrées éparpillées dans une app qu'on venait de repeindre.
    ///
    /// Et c'est le coût réel : `lime` veut dire MIEUX et `amber` veut dire MOINS BIEN — l'écran
    /// Stats s'en sert correctement, à deux centimètres de là, pour ses pastilles d'écart
    /// (« ▲ 18″/km » en vert, « ▼ 19,6 km » en ambre). Les dépenser en décoration sur un glyphe
    /// de 15 points, c'est vider de son sens le seul endroit où la couleur disait quelque chose.
    ///
    /// Quarante-sept appels ont donc rendu leur teinte. Les huit qui restent la gardent parce
    /// qu'elle NOMME quelque chose, et le garde-fou `ci_scripts/check_teintes.py` les inscrit une
    /// par une avec leur raison : un avertissement de session expirée, une course qu'on a
    /// confirmé préparer, des chaussures retirées volontairement éteintes, et le bloc Vélo de
    /// l'écran Stats — marqué d'un bout à l'autre, ce qui est la différence entre un repère et
    /// une décoration.
    var tint: Color = RUColor.rose
    var title: String
    var subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let icon {
                // La pastille teintée derrière l'icône est partie.
                //
                // Un carré arrondi de 26 points, rempli d'un accent à 12 %, à gauche de CHAQUE
                // titre de section : sur un écran qui en empile trois ou quatre, ça fait une
                // colonne de petits carrés colorés — un des motifs les plus datés qui soient, et
                // il était répété dans toute l'app puisque ce composant est partagé.
                //
                // L'icône reste, seule et à même le fond. Elle porte exactement la même
                // information ; c'est son emballage qui n'en portait aucune.
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                // UN TITRE DE SECTION QUI PESAIT AUTANT QUE LA PAGE ET PLUS QUE SES CHIFFRES.
                //
                // Rendu, sur la page d'un club, le barème était celui-ci :
                //
                //     26,2 pt  le nom du club          `displayStyle(24)`  → × 1,09
                //     20,7 pt  « 22,4 km »             `displayStyle(19)`  → × 1,09
                //     20,0 pt  « Les records du club »  `.emphasis` gras   → × 1,25
                //     15,0 pt  le texte courant         `.body`
                //
                // Quatre niveaux dans six points. Un écran où le titre de la page, ses
                // intertitres et ses données ont la même taille n'a pas de hiérarchie : tout
                // parle fort, donc rien ne ressort, et la page se lit comme une liste de lignes
                // sans rapport les unes avec les autres. Et le plus faux des trois écarts est le
                // dernier : dans une app de course, l'étiquette passait DEVANT le chiffre.
                //
                // `.label` plutôt que `.emphasis` met le titre à 17,5 — sous les 20,7 des
                // mesures, nettement sous les 26,2 du titre de page, et toujours à 2,5 points
                // au-dessus du texte courant. Ici plutôt qu'aux 72 appels : c'est le barème de
                // l'app entière, pas le réglage d'un écran.
                //
                // Depuis, l'échelle de titrage a été ramenée à sept crans (voir `RUDisplaySize`),
                // et les trois valeurs citées plus haut ont bougé : le nom du club rend 24,0
                // (`.title`) et les mesures 19,6 (`.subtitle`). L'écart que cette note défendait
                // s'est donc élargi, pas réduit — 17,5 pour l'intertitre reste au bon endroit,
                // entre le texte courant et les chiffres.
                Text(LocalizedStringKey(title))
                    .font(RUFont.sans(.label, weight: .bold))
                    .foregroundColor(RUColor.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(RUFont.sans(.small))
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
    /// Le défaut, comme pour `RUCardHeader` : passer une teinte est l'exception, et elle doit
    /// vouloir dire quelque chose. Voir la note sur `RUCardHeader.tint`.
    var tint: Color = RUColor.rose
    var title: String
    var value: String
    /// L'unité, en petit, juste après le chiffre — « 3 240 **steps** », « 32 **mins** ». Elle est
    /// séparée du chiffre pour que le chiffre porte seul la taille : « 3240 steps » en un seul
    /// `Text` obligerait l'unité à grandir avec lui.
    var unit: String?
    var footnote: String?
    /// 0...1, ou `nil` quand ce chiffre ne va nulle part (un cumul de km n'a pas d'objectif).
    var progress: Double?
    /// LES VALEURS DONT CE CHIFFRE EST LE DERNIER POINT.
    ///
    /// Une tuile disait « 145 km » et rien d'autre — une valeur sans échelle. La courbe occupe
    /// le blanc qui était déjà là, en bas de la tuile, et le chiffre cesse d'être isolé.
    ///
    /// Exclusive de `progress`, et dans cet ordre : une tuile qui a un OBJECTIF montre d'abord
    /// où elle en est par rapport à lui. Les deux ensemble donneraient deux lectures du même
    /// chiffre à deux centimètres l'une de l'autre.
    var serie: [Double]?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ── LE LIBELLÉ S'EFFACE, LE CHIFFRE DEVIENT L'OBJET ─────────────────────────────
            //
            // La tuile coiffait son chiffre d'un `RUCardHeader` — titre en gras, encre pleine,
            // 17,5 points. Le chiffre, lui, était à 26,2 en graisse moyenne. Résultat sur
            // l'écran Stats : « Distance totale » pesait autant que « 145 », et la tuile se
            // lisait comme une ligne de liste dont le chiffre serait la suite.
            //
            // C'est l'inverse de ce que fait n'importe quelle app de sport, et pour une raison
            // qui n'est pas de goût : dans une tuile, le libellé est connu d'avance — on sait
            // qu'on regarde des distances. C'est le chiffre qu'on vient chercher. Un libellé qui
            // pèse autant que lui oblige à le lire pour arriver à ce qu'on voulait.
            //
            // Le libellé passe donc en micro-étiquette (`.small` moyenne, `text3`, comme toute
            // micro-étiquette du système) et le chiffre monte d'un cran, à `.figure` — qui est
            // aussi le premier cran en gras. L'en-tête de carte partagé ne convient plus : il
            // porte un titre de CARTE, et une tuile n'en a pas.
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tint)
                Text(LocalizedStringKey(title))
                    .font(RUFont.sans(.small, weight: .medium))
                    .foregroundColor(RUColor.text3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            VStack(alignment: .leading, spacing: 6) {
                RUChiffre(valeur: value, unite: unit)
                if let progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(RUColor.card2)
                            Capsule().fill(tint)
                                .frame(width: geo.size.width * max(0, min(1, progress)))
                        }
                    }
                    .frame(height: 5)
                } else if let serie {
                    RUSparkline(valeurs: serie, couleur: tint)
                }
                // LA NOTE N'EST PLUS L'ALTERNATIVE DE LA BARRE, elle vient dessous.
                //
                // Les trois branches s'excluaient : une tuile qui passait une progression ET une
                // note n'affichait que la barre, en silence. Aucun appelant ne le faisait, donc
                // rien ne l'avait signalé — jusqu'à la tuile « Série », dont la barre dit où on
                // en est et dont la note dit vers QUOI. L'une sans l'autre ne veut rien dire :
                // une barre aux deux tiers sans son palier est un pourcentage de rien.
                if let footnote {
                    Text(LocalizedStringKey(footnote))
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .padding(RUSpacing.cardPadding)
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
