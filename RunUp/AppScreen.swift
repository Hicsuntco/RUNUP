import Foundation

/// Every navigable top-level screen (mirrors the `screen` string in app.jsx's `SCREENS` map).
enum AppScreen: String, Hashable {
    case home = "prog"
    case plan
    case rings
    case live
    case recap
    case coach
    case stats
    case club
    /// Le fil — un écran à part entière, pas un mode du hub social.
    ///
    /// Il n'a pas d'onglet : la quatrième place de la barre est aux Stats (voir `TabBarView`).
    /// Il s'ouvre par sa carte en tête de la section Communauté du Profil, et compte comme une
    /// racine parce qu'il partage l'onglet du Profil.
    ///
    /// Il n'a pas de clé « mur » ni « wall » : `--ecran=fil` est aussi le drapeau que le harnais
    /// de captures passe, et la valeur brute de ce cas EST ce drapeau (voir
    /// `CaptureSeed.ecranDemande`). Un nom technique ici deviendrait un nom technique là-bas.
    case fil
    case race
    case profile
    case history
    case weeklyRecap
    case shoes
    case heatmap

    /// Cet écran est-il une DESTINATION D'ONGLET, ou une page ouverte depuis une autre ?
    ///
    /// C'est ce qui donne sa DIRECTION à la transition. Sans cette distinction, tous les
    /// changements d'écran se ressemblent — et comme l'ancienne transition était symétrique
    /// (les deux écrans partaient vers la droite), l'écran sortant et l'écran entrant se
    /// croisaient sur la moitié droite pendant que la gauche restait vide. Ce n'est pas une
    /// navigation, c'est un enchevêtrement.
    ///
    /// Le Club et le Fil partagent l'onglet du Profil (voir `RootTabView.tabSelection`), donc
    /// tous deux comptent comme des racines : passer de l'un à l'autre est un mouvement latéral,
    /// pas une descente.
    var estRacineDOnglet: Bool {
        switch self {
        case .home, .coach, .stats, .fil, .profile, .club: return true
        case .plan, .rings, .live, .recap, .race, .history, .weeklyRecap, .shoes, .heatmap:
            return false
        }
    }
}
