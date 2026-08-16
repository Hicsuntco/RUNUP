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
        .background(.ultraThinMaterial.opacity(0.9))
        // La barre FLOTTE au-dessus du contenu, donc elle doit se lire comme une surface
        // surélevée — c'est-à-dire `card`, comme toutes les autres surfaces surélevées depuis
        // l'inversion du thème clair. Elle était figée à #EDEDF4, soit la couleur de la page en
        // un peu plus foncé : une barre censée être posée au-dessus se lisait comme un trou.
        .background(RUColor.card.opacity(RUColor.isLight ? 0.92 : 0.72))
        .overlay(Capsule().stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        .clipShape(Capsule())
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
                    .font(RUFont.sans(8, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(PressableStyle())
        // The only persistent navigation chrome in the app, visible on every screen — without
        // this, VoiceOver conveyed the active tab purely through color (the dot + icon/label
        // tint), so a screen-reader user had no way to tell which of Prog/Coach/Stats/Profil was
        // currently selected.
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var runButton: some View {
        Button(action: onStartRun) {
            VStack(spacing: 4) {
                Circle()
                    .fill(LinearGradient(colors: [RUColor.rose2, RUColor.rose], startPoint: .top, endPoint: .bottom))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "play.fill").foregroundColor(RUColor.onRose).font(.system(size: 16)))
                    .shadow(color: RUColor.rose.opacity(RUColor.isLight ? 0 : 0.55), radius: 14, x: 0, y: 6)
                Text("RUN")
                    .font(RUFont.sans(8, weight: .bold))
                    .tracking(1)
                    .foregroundColor(RUColor.rose2)
            }
            .frame(width: 60)
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
                    .font(RUFont.bebas(12))
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
