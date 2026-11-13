import SwiftUI

/// # LA CARTE DE NUIT — LA SIGNATURE DE RUNUP, RENDUE RÉUTILISABLE
///
/// L'app avait UNE chose qui ne ressemblait à rien d'autre : le bandeau de la dernière sortie,
/// un presque-noir plein cadre où le tracé GPS se dessine en lumière, la date et les deux
/// chiffres posés dessus. Mesurée sur les captures du 12 novembre, part d'image sombre en thème
/// CLAIR — donc là où le sombre est un choix et non le thème : Club 30,1 %, Accueil 15,0 %,
/// Coach 2,6 %, Stats 1,9 %, Journée 1,6 %, Plan 1,3 %. Deux écrans sur six la portaient.
///
/// Charlotte a demandé le 13 novembre de l'étendre aux quatre autres. L'étendre suppose de dire
/// ce qu'elle EST — sinon on peint des fonds sombres, et un fond sombre n'est pas une signature,
/// c'est un goût. Quatre choses ensemble, et il faut les quatre :
///
/// 1. **CE QUI EST MESURÉ DEVIENT LE DESSIN.** Pas une illustration de la donnée : la donnée
///    elle-même, tracée. Le tracé EST la sortie. Les barres SONT le plan. La courbe EST l'allure.
///    Un écran qui n'a rien à dessiner n'a pas de carte de nuit.
/// 2. **LE DESSIN OCCUPE LE CADRE**, bord à bord à la marge près. Il n'est pas une vignette posée
///    dans une carte : c'est le cadre qui lui est donné.
/// 3. **LA NUIT, ET RIEN D'AUTRE D'ALLUMÉ.** `RUColor.traceBackground` dans les deux thèmes, et
///    l'accent y est à pleine force — ce qu'il n'est nulle part ailleurs dans la page claire.
/// 4. **LES CHIFFRES SE POSENT DESSUS.** Pas dessous, pas à côté : sur le dessin, sous un voile
///    qui garantit la lecture quelle que soit la forme. Ils légendent une image, ils n'étiquettent
///    pas un graphique.
///
/// Et une cinquième, négative : **une seule par écran.** Deux points de fixation n'en font aucun.
///
/// ## POURQUOI UN COMPOSANT ET PAS QUATRE CARTES
///
/// Le jeton `traceBackground` porte déjà l'histoire : il vivait en privé dans `ActivityFeedRow`,
/// une deuxième copie est apparue, et « une deuxième copie aurait divergé au premier réglage ».
/// Elle a divergé — en nuance, pas en fond : le Club peignait le tracé en deux teintes et
/// l'accueil en trois, pour la même course. Quatre écrans de plus, c'est quatre occasions de
/// recommencer. Ici, le voile, la marge, le rayon, la bordure et l'encre sont décidés une fois.
struct CarteDeNuit<Dessin: View, Legende: View>: View {

    /// Où la légende se pose, et de quel côté le voile protège sa lecture.
    enum Pose {
        /// Les chiffres en bas — le cas du tracé, qui occupe le haut du cadre.
        case basGauche
        /// Les chiffres en haut — le cas d'un graphique en barres ou en colonnes, dont le dessin
        /// est COLLÉ AU BAS du cadre : un voile par le bas éteindrait précisément ce qu'on
        /// regarde.
        case hautGauche
    }

    var hauteur: CGFloat
    var pose: Pose = .basGauche
    /// La marge du dessin. 14 par défaut, la valeur du bandeau de l'accueil.
    var marge: CGFloat = RUSpacing.cardPadding
    /// Le voile sous les chiffres. Une carte SANS légende n'en a pas besoin, et il assombrirait
    /// alors le bas du dessin sans que rien ne soit posé dessus — la Journée, dont le compte est
    /// au moyeu de l'anneau et non en bas à gauche, est ce cas-là.
    var voile: Bool = true
    @ViewBuilder var dessin: () -> Dessin
    @ViewBuilder var legende: () -> Legende

    var body: some View {
        ZStack(alignment: pose == .basGauche ? .bottomLeading : .topLeading) {
            RUColor.traceBackground
            dessin().padding(marge)
            if voile { voileDeLecture }
            legende().padding(RUSpacing.cardPadding)
        }
        .frame(height: hauteur)
        // `.background(RUColor.card)` sous la nuit : le coin arrondi laisse voir la carte de la
        // page derrière, et sans lui ce serait le fond de la page qui apparaîtrait, un ton plus
        // foncé que les cartes voisines.
        .background(RUColor.card)
        .clipShape(RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous)
            .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    /// Le voile qui garantit la lecture des chiffres.
    ///
    /// Il est dégradé, et la règle 7 interdit les dégradés DANS L'INTERFACE — un bouton dégradé,
    /// une carte dégradée. Celui-ci n'habille rien : il fait le travail qu'un voile fait sur une
    /// photo, rendre un texte lisible par-dessus une image dont on ne connaît pas la forme. Un
    /// voile uni assez opaque pour tenir le pire cas éteindrait le dessin dans tous les autres.
    ///
    /// 0,62 est la valeur mesurée sur le bandeau de l'accueil depuis septembre.
    ///
    /// IL PART DU MILIEU, DES DEUX CÔTÉS. La version posée en haut partait du BAS de la carte :
    /// le dégradé couvrait donc toute la hauteur, et à mi-chemin il valait encore un tiers de
    /// noir. Sur la capture du 13 novembre, les barres du Plan et les marques du Coach en
    /// portaient la trace — chacune s'assombrissait vers son sommet, ce qu'on prend pour un
    /// dégradé décoratif, c'est-à-dire pour la chose même que la règle 7 interdit. Il n'avait
    /// rien à faire sur la moitié du cadre où aucun texte n'est posé.
    private var voileDeLecture: some View {
        LinearGradient(colors: [.black.opacity(0), .black.opacity(0.62)],
                       startPoint: .center,
                       endPoint: pose == .basGauche ? .bottom : .top)
    }
}

// MARK: Ce qu'on écrit sur la nuit

/// Le surtitre d'une carte de nuit : ce que le dessin montre, en petit, au-dessus des chiffres.
///
/// Il remplace le `RUCardHeader` des cartes blanches, et il est VOLONTAIREMENT plus discret :
/// sur une carte de nuit, le titre n'est pas ce qu'on regarde en premier, le dessin l'est. Un
/// en-tête à icône et sous-titre rendrait la carte bavarde là où elle doit être muette.
/// Un chiffre de carte de nuit : la valeur, son unité, l'encre de la nuit.
///
/// IL EXISTE POUR UNE RAISON DE TRADUCTION, pas seulement de rangement. `LegendeDeNuit` recevait
/// ses chiffres dans un tableau de TUPLES — `[(valeur: String, unite: String)]`. Le contrôle des
/// chaînes suit une étiquette d'un type à l'autre quand c'est un `String` déclaré ; un champ de
/// tuple n'en est pas un, et le suivre demanderait d'interpréter l'accès à un élément de
/// collection, ce que `check_strings.py` refuse de faire par principe.
///
/// Ce qui est sorti par ce trou : « km au plus fort », sur la carte de nuit du Plan, en FRANÇAIS
/// dans la version espagnole, à côté d'un « 7 semanas » correctement traduit. C'est la campagne
/// en trois langues qui l'a montré, pas le garde.
///
/// Avec un type nommé, `unite` redevient une étiquette ordinaire : le relais la voit, et un
/// littéral absent du catalogue est refusé avant la campagne.
struct ChiffreDeNuit: View {
    var valeur: String
    var unite: String

    var body: some View {
        RUChiffre(valeur: valeur, unite: unite, cran: .subtitle,
                  couleur: RUColor.surLaNuit, couleurDeLUnite: RUColor.surLaNuit2)
    }
}

struct LegendeDeNuit: View {
    /// Un `Text` et non une clé : l'accueil y met une DATE déjà formatée, que le catalogue ne
    /// contient pas et ne doit pas contenir, tandis que le Plan et le Coach y mettent une vraie
    /// clé traduite. C'est l'appelant qui sait laquelle des deux il tient — `RUChiffre` fait le
    /// même partage entre sa `valeur` en `verbatim` et son `unite` en clé.
    var surtitre: Text?
    var chiffres: [ChiffreDeNuit]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let surtitre {
                surtitre
                    .font(RUFont.sans(.small, weight: .medium))
                    .foregroundColor(RUColor.surLaNuit2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                ForEach(chiffres.indices, id: \.self) { i in
                    chiffres[i]
                }
            }
        }
    }
}
