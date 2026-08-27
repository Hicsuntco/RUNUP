import SwiftUI

/// La police de RunUp, nommée et dimensionnée en un seul endroit.
///
/// Trois cibles l'utilisent — l'app, le widget, la montre — et chacune écrivait son nom PostScript
/// en dur, vingt fois en tout. Une chaîne `.custom` introuvable ne lève aucune erreur : elle
/// retombe en silence sur la police système. En oublier une, c'était donc livrer un widget dans une
/// autre police que l'app sans le moindre avertissement.
///
/// Ce fichier vit dans `RunUp/Shared`, compilé par les trois cibles. Il ne dépend que de SwiftUI.
enum DisplayFont {
    /// La famille de TOUTE l'app — titrage et texte courant confondus.
    ///
    /// Il n'y a plus de police de titrage. Quatre ont été essayées et refusées — Bebas en
    /// capitales d'affiche, Bricolage ExtraBold, DM Sans en 800 puis en 700 — toutes pour le même
    /// motif : elles étaient lourdes, et une graisse noire dit « performance » là où on veut
    /// « simple et joli ». La hiérarchie repose désormais sur la taille et l'interlettrage négatif,
    /// pas sur la graisse.
    ///
    /// Changer de police, c'est changer cette ligne. Rien d'autre.
    static let family = "Poppins"

    /// Le nom PostScript, pas le nom de famille : c'est celui-là que `Font.custom` attend.
    static let postScriptName = "\(family)-Medium"

    /// Les 27 tailles de l'app ont été dessinées contre Bebas Neue, une condensée. Chaque famille
    /// qui lui a succédé est plus large à taille de point égale, d'où ce facteur de compensation :
    /// sans lui, les titres débordent de leurs gabarits.
    ///
    /// 0,92 pour Poppins, mesuré sur les vraies chaînes de l'app (Poppins vaut 1,082 fois la
    /// largeur de DM Sans, le facteur précédent était 0,98). Les titres retrouvent exactement
    /// l'encombrement qu'ils avaient, et la hauteur d'x plus grande de Poppins fait qu'ils se
    /// lisent un peu plus gros à encombrement égal.
    ///
    /// La vraie réponse, plus tard, est de reprendre les 27 tailles une à une. Ce facteur est
    /// l'étape honnête en attendant, pas un remplacement de ce travail.
    static let sizeFactor: CGFloat = 0.92

    /// La taille de point à demander pour retrouver l'encombrement dessiné à l'origine.
    static func pointSize(for designSize: CGFloat) -> CGFloat { designSize * sizeFactor }

    /// La police à taille fixe, pour le widget et la montre — qui n'ont pas le mécanisme Dynamic
    /// Type plafonné de l'app (`RUFont.scaled`) et n'en veulent pas : un widget est un carré, il
    /// ne peut pas grandir avec le réglage de taille du texte.
    static func font(_ designSize: CGFloat) -> Font {
        .custom(postScriptName, size: pointSize(for: designSize))
    }
}
