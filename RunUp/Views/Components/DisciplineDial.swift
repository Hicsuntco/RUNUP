import SwiftUI

/// Le cadran de disciplines : trois ronds en éventail au-dessus du bouton RUN, choisis au doigt.
///
/// # LE GESTE, EN UN SEUL MOUVEMENT
///
/// On maintient le bouton, les trois ronds s'ouvrent, on fait glisser le doigt vers celui qu'on
/// veut, on relâche. Le doigt ne quitte jamais l'écran : maintenir, viser et valider sont le même
/// geste continu, là où l'ancien panneau demandait maintenir, relâcher, puis viser et toucher.
///
/// La géométrie vit ici, séparée de la vue, parce que c'est elle qui décide : un déplacement de
/// doigt entre et une discipline sort. C'est une fonction de deux nombres vers trois valeurs, donc
/// quelque chose qu'on peut prouver sans appareil — et le reste de ce fichier, qui dessine, ne
/// peut l'être d'aucune façon.
enum DisciplineDial {

    /// La distance du centre du bouton à celui de chaque rond.
    static let rayon: CGFloat = 86
    static let tailleRond: CGFloat = 54

    /// En dessous, on considère que le doigt n'a pas bougé.
    ///
    /// C'est ce qui rend le cadran utilisable des deux façons : un relâchement DANS la zone morte
    /// ne choisit rien et laisse le cadran ouvert, donc les ronds restent touchables un par un.
    /// Quelqu'un qui maintient, découvre les trois ronds et relâche pour réfléchir ne se retrouve
    /// pas avec une discipline choisie au hasard — ni avec un cadran qui se referme sous ses yeux.
    static let zoneMorte: CGFloat = 26

    /// Au-delà, le doigt est tellement loin qu'il ne vise plus rien. Sans cette borne, un geste
    /// large vers le haut de l'écran choisirait quand même, alors qu'il ressemble à tout sauf à
    /// un choix.
    static let porteeMaximale: CGFloat = 240

    /// L'angle de chaque rond, en degrés, zéro à droite et quatre-vingt-dix en haut.
    ///
    /// 145, 90 et 35 : course à gauche, vélo en haut, trail à droite — l'ordre de lecture, et
    /// l'ordre de `Discipline.allCases`. Fixes, et c'est le point : la course est TOUJOURS à
    /// gauche, donc le geste s'apprend et finit par se faire sans regarder. Un ordre qui dépendrait
    /// de la discipline courante — l'active au centre, par exemple — rendrait chaque geste
    /// différent du précédent.
    static func angle(_ discipline: Discipline) -> Double {
        switch discipline {
        case .run: return 145
        case .bike: return 90
        case .trail: return 35
        }
    }

    /// La taille du cadre qui contient le cadran, libellé compris.
    ///
    /// Un cadre RÉEL et non un point d'ancrage de 1 × 1 : les ronds sont posés par `offset`, qui
    /// ne change pas la mise en page, et un cadre d'un point sur un ne contiendrait aucun d'eux.
    /// Or on ne touche pas de façon fiable ce qui dépasse du cadre de son parent — et ces ronds
    /// doivent rester touchables, c'est par là que VoiceOver les atteint.
    ///
    /// Dérivées du rayon et de la taille des ronds, jamais écrites en dur : les trois nombres ne
    /// peuvent donc pas se désaccorder le jour où le cadran s'agrandit.
    static var hauteurCadran: CGFloat { 2 * (rayon + tailleRond / 2 + 46) }
    static var largeurCadran: CGFloat { 2 * (rayon + tailleRond / 2 + 10) }

    /// Où dessiner un rond, relativement au CENTRE du cadran — qui est aussi celui du bouton RUN.
    /// L'ordonnée est négative vers le haut, comme partout en SwiftUI.
    static func position(_ discipline: Discipline) -> CGPoint {
        let radians = angle(discipline) * .pi / 180
        // Converti explicitement : `rayon` est un `CGFloat` et `cos` rend un `Double`. Swift sait
        // les mêler, mais une inférence qui marche « en général » n'a pas sa place dans du code
        // qu'on ne peut essayer qu'après un quart d'heure de compilation.
        return CGPoint(x: rayon * CGFloat(cos(radians)), y: -rayon * CGFloat(sin(radians)))
    }

    /// La discipline visée par ce déplacement de doigt, ou `nil` pour « rien choisi ».
    ///
    /// Trois façons de ne rien choisir, et chacune correspond à un geste réel :
    ///
    /// - **Le doigt n'a pas bougé** (`zoneMorte`) : on regarde, on ne choisit pas.
    /// - **Le doigt est parti vers le BAS** : c'est l'annulation. Le cadran s'ouvre vers le haut,
    ///   donc tirer vers le bas est le mouvement opposé au choix — il n'a pas besoin d'être
    ///   expliqué pour être compris.
    /// - **Le doigt est parti trop loin** (`porteeMaximale`) : à vingt-quatre centimètres du
    ///   bouton on ne vise plus un rond de cinquante-quatre points.
    ///
    /// Sinon, c'est le rond le plus proche en angle qui gagne. Pas de tolérance en plus : les
    /// trois se partagent tout le demi-cercle supérieur, avec des frontières à 117,5° et 62,5°.
    /// Une tolérance créerait des trous — des directions où le doigt vise clairement quelque chose
    /// et où il ne se passe rien, ce qui est la pire réponse possible à un geste franc.
    static func option(pour translation: CGSize) -> Discipline? {
        let distance = hypot(translation.width, translation.height)
        guard distance >= zoneMorte, distance <= porteeMaximale else { return nil }
        // `-height` parce que l'ordonnée de SwiftUI descend : vers le haut doit donner un angle
        // positif, sinon tout le demi-cercle est à l'envers.
        let degres = Double(atan2(-translation.height, translation.width)) * 180 / .pi
        guard degres >= 0 else { return nil }
        return Discipline.allCases.min {
            abs(angle($0) - degres) < abs(angle($1) - degres)
        }
    }
}

/// Les trois ronds. Dessinés dans la pile de `RootTabView`, centrés sur le bouton RUN.
///
/// Elle ne reçoit AUCUN geste : c'est le bouton RUN qui tient le doigt du début à la fin, et qui
/// rapporte où il en est. Deux vues qui se disputeraient le même doigt est exactement le défaut
/// qu'on a déjà payé une fois ici, quand un `Button` et un `.onLongPressGesture` se battaient pour
/// le même appui.
///
/// Les ronds restent néanmoins des `Button` : après un relâchement dans la zone morte le cadran
/// demeure ouvert, et il faut pouvoir en toucher un. Un contrôle visible doit répondre au doigt.
struct DisciplineDialView: View {
    var selection: Discipline
    /// La discipline actuellement visée par le doigt, ou `nil` quand il ne vise rien.
    var visee: Discipline?
    var onSelect: (Discipline) -> Void

    /// Ce qui est mis en avant : ce que le doigt vise, à défaut ce qui est déjà choisi.
    private var vedette: Discipline { visee ?? selection }

    var body: some View {
        ZStack {
            arc
            ForEach(Discipline.allCases, id: \.self) { discipline in
                rond(discipline)
            }
            libelle
                .offset(y: -DisciplineDial.rayon - DisciplineDial.tailleRond / 2 - 22)
        }
        // Un cadre fixe, et pas un qui s'adapte au contenu : son CENTRE est l'origine de toute la
        // géométrie ci-dessus, et c'est aussi celui du bouton RUN. Laisser le contenu dimensionner
        // la pile déplacerait ce centre, donc ferait viser les ronds de travers.
        .frame(width: DisciplineDial.largeurCadran, height: DisciplineDial.hauteurCadran)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choisir la discipline")
    }

    /// Le fil qui relie les trois ronds. C'est lui qui en fait UN objet plutôt que trois pastilles
    /// posées là — et c'est aussi ce qui montre qu'il y a un demi-cercle à parcourir au doigt.
    private var arc: some View {
        Circle()
            .trim(from: 0.5, to: 1.0)
            .stroke(RUColor.cardBorder, style: StrokeStyle(lineWidth: RUSpacing.hairline,
                                                           lineCap: .round, dash: [2, 5]))
            // `trim(from: 0.5, to: 1)` : le tracé d'un `Circle` part de trois heures et tourne
            // dans le sens des aiguilles, donc la moitié 0,5 → 1 va de neuf heures à trois heures
            // en passant par midi. C'est exactement le demi-cercle supérieur, celui que les trois
            // ronds occupent.
            .frame(width: DisciplineDial.rayon * 2, height: DisciplineDial.rayon * 2)
    }

    /// Le nom de la discipline visée, en un seul mot au-dessus du cadran.
    ///
    /// Un libellé qui CHANGE plutôt que trois libellés fixes : les ronds restent des icônes nettes,
    /// et la lecture se fait à un seul endroit, celui que l'œil surveille déjà en déplaçant le
    /// doigt. Trois mots sous trois ronds de cinquante-quatre points auraient été trois fois plus
    /// d'encre pour la même information.
    private var libelle: some View {
        Text(vedette.tabLabel)
            .font(RUFont.sans(.micro, weight: .bold))
            .tracking(1.5)
            .foregroundColor(visee == nil ? RUColor.text3 : RUColor.rose2)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
            .background(RUColor.card.opacity(RUColor.isLight ? 0.96 : 0.82), in: Capsule())
            .contentTransition(.opacity)
            .animation(RUMotion.snap, value: vedette)
            .accessibilityHidden(true)
    }

    private func rond(_ discipline: Discipline) -> some View {
        let actif = discipline == vedette
        return Button {
            Haptics.selection()
            onSelect(discipline)
        } label: {
            Image(systemName: discipline.sfSymbol)
                .font(.system(size: 20, weight: actif ? .semibold : .regular))
                .foregroundColor(actif ? RUColor.onRose : RUColor.text2)
                .frame(width: DisciplineDial.tailleRond, height: DisciplineDial.tailleRond)
                .background {
                    if actif {
                        Circle().fill(LinearGradient(colors: [RUColor.rose2, RUColor.rose],
                                                     startPoint: .top, endPoint: .bottom))
                    } else {
                        Circle().fill(.ultraThinMaterial.opacity(0.9))
                        Circle().fill(RUColor.card.opacity(RUColor.isLight ? 0.96 : 0.82))
                    }
                }
                .overlay(Circle().stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                // Le rond visé grossit : c'est le retour qui dit « celui-là partira si tu
                // relâches », et il doit se voir alors que le doigt le recouvre à moitié.
                .scaleEffect(actif ? 1.12 : 1)
                .shadow(color: .black.opacity(RUColor.isLight ? 0.10 : 0.5), radius: 14, x: 0, y: 6)
                .animation(RUMotion.snap, value: actif)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        // Le décalage est posé ICI et non sur l'appel : il appartient au rond, pas à la boucle qui
        // les énumère, et le calculer une fois évite de demander deux fois la même position.
        .offset(x: DisciplineDial.position(discipline).x,
                y: DisciplineDial.position(discipline).y)
        .accessibilityLabel(discipline == selection ? discipline.title : discipline.switchToLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(discipline == selection ? .isSelected : [])
    }
}
