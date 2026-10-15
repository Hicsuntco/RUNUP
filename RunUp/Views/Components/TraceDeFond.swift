import SwiftUI

/// SON PROPRE PARCOURS, EN FOND D'EN-TÊTE.
///
/// # CE QUE C'EST, ET CE QUE CE N'EST PAS
///
/// Ce n'est pas une carte : ni rue, ni relief, ni étiquette. C'est le TRAIT, seul, agrandi
/// jusqu'à sortir du cadre. Une carte au fond d'un en-tête serait du bruit derrière du texte ;
/// un trait est une forme, et une forme qui vient d'elle — son parcours de la semaine, différent
/// chez chaque personne et différent chaque semaine.
///
/// C'est la seule chose de cette app qu'aucune autre ne peut avoir, et elle dormait : les tracés
/// sont enregistrés, dessinés, et n'apparaissaient que dans l'écran de fin et la carte de
/// partage.
///
/// # IL NE S'AFFICHE QUE DANS L'HABILLAGE TEINTÉ
///
/// Comme tout le reste de cette direction artistique — voir `Habillage`. Un seul interrupteur
/// défait l'ensemble, c'était la condition posée.
///
/// # LE CAS SANS TRACÉ EST LE PREMIER, PAS LE DERNIER
///
/// La première semaine, après une réinstallation, ou pour qui saisit ses courses à la main, il
/// n'y a aucun parcours. La vue rend alors RIEN du tout, et l'en-tête se présente exactement
/// comme en habillage classique. Un fond qui aurait besoin d'un tracé pour ne pas paraître vide
/// serait un fond raté.
struct TraceDeFond: View {
    var route: [RunRecord.RoutePoint]
    /// De combien le tracé déborde du cadre. 1 le ferait tenir tout juste dedans, ce qui donne
    /// une vignette posée derrière du texte ; au-delà il sort des deux côtés et redevient une
    /// matière de fond.
    var debordement: CGFloat = 1.45

    var body: some View {
        // `normalized` rend un carré aspect-corrigé et EXIGE d'être dessiné dans un carré : on
        // met donc à l'échelle par le plus grand côté, jamais par les deux. Étirer pour remplir
        // referait exactement l'erreur que cette fonction corrige — une boucle est-ouest 52 %
        // trop large.
        let points = RouteGeometry.decimated(RouteGeometry.normalized(route), keeping: 160)
        if points.count > 1 {
            Canvas { contexte, taille in
                let cote = max(taille.width, taille.height) * debordement
                let dx = (taille.width - cote) / 2
                let dy = (taille.height - cote) / 2
                var chemin = Path()
                chemin.move(to: CGPoint(x: dx + points[0].x * cote, y: dy + points[0].y * cote))
                for p in points.dropFirst() {
                    chemin.addLine(to: CGPoint(x: dx + p.x * cote, y: dy + p.y * cote))
                }
                // Deux passes : une large et très pâle qui pose la masse, une fine qui donne le
                // dessin. C'est ce qui fait lire un trait comme une matière plutôt que comme un
                // trait oublié là.
                contexte.stroke(chemin, with: .color(RUColor.rose.opacity(RUColor.isLight ? 0.10 : 0.13)),
                                style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
                contexte.stroke(chemin, with: .color(RUColor.rose.opacity(RUColor.isLight ? 0.26 : 0.30)),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
            // Décoratif de bout en bout : il n'y a rien à annoncer, et surtout rien à toucher.
            // Un `Canvas` est une forme pleine — sans ça il avalerait les appuis de ce qu'il
            // habille, exactement comme le voile de l'écran de fin l'a fait.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Pose le tracé DERRIÈRE l'en-tête, et seulement dans l'habillage teinté.
    ///
    /// Un `background` plutôt qu'un `ZStack` chez chaque appelant : l'en-tête garde sa taille
    /// naturelle, le tracé prend celle qu'on lui donne et déborde en largeur sans jamais pousser
    /// quoi que ce soit.
    func traceEnFond(_ route: [RunRecord.RoutePoint], hauteur: CGFloat = 150) -> some View {
        background(alignment: .top) {
            if RUColor.habillage == .trace, !route.isEmpty {
                TraceDeFond(route: route)
                    .frame(height: hauteur)
                    // Il sort LARGEMENT du cadre, pas de l'écran : la marge latérale de l'écran
                    // est de 18 points, donc -40 le fait mordre sur les deux bords sans jamais
                    // atteindre une zone où quelque chose d'autre est dessiné.
                    .padding(.horizontal, -40)
                    .offset(y: -34)
            }
        }
    }
}
