import SwiftUI

/// La carte « Ton niveau dans le club ».
///
/// # SORTIE DE `ClubView`, ET ELLE NE CONNAÎT PLUS QUE SON XP
///
/// Elle y vivait au milieu de 1 425 lignes. Elle en est sortie la première parce qu'elle était la
/// moins chère à sortir : zéro état à faire passer, et une seule donnée en entrée. Elle ne
/// consulte plus `AuthService` — l'appelant lui donne le nombre, donc elle se dessine pour
/// n'importe quelle valeur, y compris dans un aperçu.
///
/// Le calcul du palier est parti dans `NiveauDuClub`, où il se vérifie sans ouvrir l'écran.
///
/// # LE SEUL OBJET SOMBRE D'UNE PAGE CLAIRE, ET IL ÉTAIT EN BAS DE CELLE-CI.
///
/// Ce bloc gardait son dégradé violet nuit DANS LES DEUX THÈMES. En sombre, c'est le héros de la
/// page ; en clair, c'est un pavé noir au pied d'un écran pâle — c'est-à-dire exactement le
/// « gros cadre » qu'on avait retiré du HAUT de cette page, réapparu au bas.
///
/// On le voit à ce que le code avouait déjà : les textes étaient figés en blanc, avec pour raison
/// « cette carte reste sombre dans les deux thèmes, donc `text2` passerait sombre-sur-sombre ».
/// Le symptôme était traité, pas la cause.
///
/// La surface est donc `card` et le contour `cardBorder`, comme toute carte. Les deux encres
/// reprennent leurs jetons : il n'y a plus de fond spécial à compenser.
///
/// CE QUI NE BOUGE PAS : la PASTILLE du niveau reste le point de couleur de la section, en violet
/// plat. Un point, pas un aplat plein cadre. La jauge d'XP le suit, pour la même raison.
struct ClubLevelCard: View {
    let xpTotal: Int

    var body: some View {
        let info = NiveauDuClub.palier(xp: xpTotal)
        HStack(spacing: 14) {
            Text("\(info.niveau)").displayStyle(.title).foregroundColor(.white)
                .contentTransition(.numericText())
                .frame(width: 52, height: 52)
                // La pastille du niveau portait un dégradé violet → rose écrit à la main, le même
                // couple que la jauge d'XP juste en dessous. Les deux sont à plat. Règle 7.
                .background(RUColor.violet, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                // « TON NIVEAU », écrit. Sur une page qui parle du club du début à la fin, un
                // « Niveau 17 » sans sujet se lit comme le niveau DU CLUB — ce qu'il n'est pas :
                // il vient de mon XP à moi.
                //
                // L'XP MONTE SUR LA LIGNE DU SOURCIL, PARCE QUE LE TITRE SE REPLIE.
                //
                // « Niveau 17 · Élite locale » ne tient pas sur une ligne à 23,1 pt dans la
                // largeur qui reste à droite de la pastille. Il passait donc sur deux lignes, et
                // comme le compteur d'XP partageait sa rangée en `lastTextBaseline`, il se
                // retrouvait échoué à droite de « Élite locale » — une forme en escalier, avec la
                // jauge qui démarre sous un bloc de texte en deux morceaux.
                //
                // Les deux lignes du titre ne sont pas le problème : un titre long a le droit de
                // se replier. C'est de lui accrocher un chiffre qui l'était. Le sourcil, lui,
                // tient toujours sur une ligne et a de la place à droite.
                HStack(alignment: .firstTextBaseline) {
                    Text("Ton niveau dans le club")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(RUColor.text3)
                    Spacer(minLength: 8)
                    Text("\(info.xpDansLeNiveau) / \(info.xpParNiveau) XP")
                        .font(RUFont.mono(.small)).foregroundColor(RUColor.text3)
                        .contentTransition(.numericText())
                }
                Text("Niveau \(info.niveau) · \(info.titre)")
                    .font(RUFont.sans(.title, weight: .bold)).foregroundColor(RUColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                LinearBar(fraction: Double(info.xpDansLeNiveau) / Double(info.xpParNiveau),
                          color: RUColor.violet)
            }
        }
        .animation(.easeOut(duration: 0.4), value: info.niveau)
        .animation(.easeOut(duration: 0.4), value: info.xpDansLeNiveau)
        .padding(18)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous)
            .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }
}
