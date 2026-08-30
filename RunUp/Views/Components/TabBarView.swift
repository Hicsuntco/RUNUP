import SwiftUI

/// Floating frosted-glass tab bar with a raised center "Run" button. See README § Global Chrome.
struct TabBarView: View {
    var selected: AppScreen
    var onSelect: (AppScreen) -> Void
    var onStartRun: () -> Void

    /// Le 5e onglet est PROFIL, pas Club — c'est ce que porte la maquette (`#i-profile` /
    /// « Profil » dans son `.tabbar`), et c'est ce qui défait le dédoublement qu'on avait :
    /// depuis que le Profil est un hub social (cartes Running Club et Amis), l'onglet Club menait
    /// au MÊME couple de destinations par un second chemin. Deux hubs vers deux écrans
    /// identiques, dont le plus soigné n'était pas celui qui avait l'onglet.
    ///
    /// Rien n'est retiré : Club et Amis restent atteignables par les deux cartes du Profil, qui
    /// ouvrent `SocialView` sur le bon segment. Un seul chemin y mène désormais.
    private let items: [(AppScreen, String, String)] = [
        (.home, "Prog", "list.bullet"),
        (.coach, "Coach", "bubble.left.and.bubble.right"),
        (.stats, "Stats", "chart.bar"),
        (.profile, "Profil", "person.crop.circle")
    ]

    var body: some View {
        HStack(spacing: 0) {
            tabButton(items[0])
            tabButton(items[1])
            runButton
            tabButton(items[2])
            tabButton(items[3])
        }
        .padding(.horizontal, 6)
        .frame(height: RUSpacing.tabBarHeight)
        // `in: Capsule()` sur chaque fond, et SURTOUT plus de `.clipShape(Capsule())` en aval.
        //
        // Le bouton RUN est censé DÉPASSER de la barre — c'est tout son principe. Un `clipShape`
        // posé sur la pile entière rognait donc précisément ce qui devait dépasser, et le rond
        // apparaissait coupé net par le haut. Le défaut était masqué tant que le bouton mesurait
        // exactement la hauteur de la barre ; agrandir les libellés d'onglet l'a rendu visible.
        //
        // Un fond dessiné DANS une forme habille la barre sans toucher au contenu.
        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
        // La barre FLOTTE au-dessus du contenu, donc elle doit se lire comme une surface
        // surélevée — c'est-à-dire `card`, comme toutes les autres surfaces surélevées depuis
        // l'inversion du thème clair. Elle était figée à #EDEDF4, soit la couleur de la page en
        // un peu plus foncé : une barre censée être posée au-dessus se lisait comme un trou.
        .background(RUColor.card.opacity(RUColor.isLight ? 0.92 : 0.72), in: Capsule())
        .overlay(Capsule().stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        // Et la barre elle-même arrête les touches, y compris dans les marges au-dessus et en
        // dessous des libellés : elle est posée SUR le contenu, elle doit se comporter comme
        // telle. Un fond dessiné `in: Capsule()` habille sans rien intercepter.
        .contentShape(Capsule())
        // Une barre flottante a droit à plus d'élévation qu'une carte — mais pas à quatre fois
        // plus. C'était 30 % d'encre là où les cartes sont passées à 4 et 8 %, reliquat de
        // l'ancien langage d'ombre que le portage de la maquette a justement corrigé ailleurs.
        .shadow(color: .black.opacity(RUColor.isLight ? 0.10 : 0.5), radius: 18, x: 0, y: 8)
    }

    private func tabButton(_ item: (AppScreen, String, String)) -> some View {
        let (screen, label, icon) = item
        let on = selected == screen
        // Les onglets inactifs passaient par une valeur codée en dur — noir à 32 % sur des
        // libellés de 8 pt, soit 2,21:1. `text3` a précisément été recalibré pour ce cas, et
        // contourner le jeton revenait à refaire l'erreur qu'il corrige.
        let color = on ? RUColor.rose2 : RUColor.text3
        return Button(action: {
            Haptics.selection()
            onSelect(screen)
        }) {
            VStack(spacing: 5) {
                Circle()
                    .fill(RUColor.rose)
                    .frame(width: 4, height: 4)
                    .opacity(on ? 1 : 0)
                    .scaleEffect(on ? 1 : 0.3)
                    // Snapped on/off before this — RootTabView already animates the screen swap
                    // itself (`.animation(.easeInOut(duration: 0.25), value: appState.screen)`),
                    // but the selection dot one layer down didn't match that with its own.
                    .animation(.easeOut(duration: 0.2), value: on)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: on ? .semibold : .regular))
                    .foregroundColor(color)
                Text(LocalizedStringKey(label))
                    .font(RUFont.sans(.micro, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            // Sans forme de contact, un `Button` dont le libellé est une pile d'un point, d'une
            // icône et d'un mot n'est touchable QUE sur ces trois formes — les creux entre elles
            // ne répondent pas, et le doigt les traverse. Sur l'accueil, ce qui se trouve juste
            // dessous est « Refaire un programme », en pleine largeur : viser Profil déclenchait
            // la remise à zéro du programme. Le reste de l'app pose déjà ce `contentShape`
            // partout ; la seule chrome permanente de l'app était la seule à ne pas l'avoir.
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        // The only persistent navigation chrome in the app, visible on every screen — without
        // this, VoiceOver conveyed the active tab purely through color (the dot + icon/label
        // tint), so a screen-reader user had no way to tell which of Prog/Coach/Stats/Profil was
        // currently selected.
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Le bouton central, CONTENU dans la barre.
    ///
    /// Il a été essayé en débordement — rond agrandi, remonté au-dessus du bord — pour réparer un
    /// rognage. Sur un vrai téléphone ça ne donnait pas un bouton surélevé mais une pastille
    /// collée par-dessus la barre, sans rapport avec elle. Le rognage n'était que le symptôme ; la
    /// cause était un bouton dimensionné exactement à la hauteur de sa barre.
    ///
    /// 40 + 3 + le libellé ≈ 54 dans une barre de 56 : il rentre, avec sa marge, et il ne peut
    /// plus être coupé — ni flotter. Le `clipShape` reste retiré du `body` malgré tout : il
    /// rognait par principe ce qui dépassait, et ce piège n'a aucune raison d'être remis en place.
    private var runButton: some View {
        Button(action: onStartRun) {
            VStack(spacing: 3) {
                Circle()
                    .fill(LinearGradient(colors: [RUColor.rose2, RUColor.rose], startPoint: .top, endPoint: .bottom))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "play.fill").foregroundColor(RUColor.onRose).font(.system(size: 14)))
                    .shadow(color: RUColor.rose.opacity(RUColor.isLight ? 0 : 0.55), radius: 14, x: 0, y: 6)
                Text("RUN")
                    .font(RUFont.sans(.micro, weight: .bold))
                    .tracking(1)
                    .foregroundColor(RUColor.rose2)
            }
            // Même défaut que les onglets, sur le bouton le plus utilisé de l'app : le rond fait
            // 40 pt, le creux qui le sépare de « RUN » ne répondait pas, et l'ensemble n'atteignait
            // la hauteur réglementaire par aucun côté. La cible monte à 44 sans que le rond grossisse.
            .frame(width: 60, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Floating pill shown above the tab bar when a run is active but the user navigated away.
struct RunInProgressPill: View {
    var elapsed: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(RUColor.onRose).frame(width: 7, height: 7)
                Text("RUN EN COURS · \(elapsed)")
                    .font(RUFont.display(12))
                    .tracking(1)
                    .foregroundColor(RUColor.onRose)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
            .background(RUColor.rose, in: Capsule())
            .shadow(color: RUColor.rose.opacity(RUColor.isLight ? 0 : 0.5), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(PressableStyle())
    }
}
