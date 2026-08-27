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
    /// Il n'y a plus de police de titrage. Cinq familles ont été essayées et refusées — Bebas en
    /// capitales d'affiche, Bricolage ExtraBold, DM Sans en 800 puis en 700, Poppins — et la
    /// leçon n'était pas dans la famille : c'était la GRAISSE. L'app posait ses libellés en
    /// SemiBold, une géométrique ronde en SemiBold à 12 pt donne un rendu épais, et changer de
    /// famille sans changer ça reposait chaque fois la même question.
    ///
    /// Archivo est une grotesque, plus sèche et 9 % plus étroite qu'une géométrique ; les
    /// libellés courants sont passés en Medium. La hiérarchie repose sur la taille et
    /// l'interlettrage négatif, pas sur la graisse.
    ///
    /// Changer de police, c'est changer cette ligne. Rien d'autre.
    static let family = "Archivo"

    /// Le nom PostScript, pas le nom de famille : c'est celui-là que `Font.custom` attend.
    static let postScriptName = "\(family)-Medium"

    /// Les 27 tailles de l'app ont été dessinées contre Bebas Neue, une condensée. Chaque famille
    /// qui lui a succédé est plus large à taille de point égale, d'où ce facteur de compensation :
    /// sans lui, les titres débordent de leurs gabarits.
    ///
    /// 0,94 pour Archivo. Le facteur ne se dérive pas de la largeur mais de la HAUTEUR DE
    /// CAPITALE, parce que c'est elle qui décide de la taille perçue d'un titre ou d'un grand
    /// chiffre : Archivo est à 0,686 em contre 0,697 pour Poppins, soit 1,6 % de moins, d'où
    /// 0,92 × 1,016 ≈ 0,94. À ce facteur les titres ont exactement la présence qu'ils avaient.
    ///
    /// Vérifié dans l'autre sens : Archivo est aussi 9 % plus étroite que Poppins, donc à 0,94
    /// les titres occupent 8 % de moins en largeur qu'avant. Le risque du changement était le
    /// débordement, il va dans le bon sens.
    ///
    /// La vraie réponse, plus tard, est de reprendre les 27 tailles une à une. Ce facteur est
    /// l'étape honnête en attendant, pas un remplacement de ce travail.
    static let sizeFactor: CGFloat = 0.94

    /// La taille de point à demander pour retrouver l'encombrement dessiné à l'origine.
    static func pointSize(for designSize: CGFloat) -> CGFloat { designSize * sizeFactor }

    /// La police à taille fixe, pour le widget et la montre — qui n'ont pas le mécanisme Dynamic
    /// Type plafonné de l'app (`RUFont.scaled`) et n'en veulent pas : un widget est un carré, il
    /// ne peut pas grandir avec le réglage de taille du texte.
    static func font(_ designSize: CGFloat) -> Font {
        .custom(postScriptName, size: pointSize(for: designSize))
    }
}
