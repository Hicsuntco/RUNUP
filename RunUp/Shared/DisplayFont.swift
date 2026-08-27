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
    /// 1,16 : la compensation d'Archivo (0,94, dérivée de sa hauteur de capitale, 0,686 em contre
    /// 0,697 pour Poppins) multipliée par le même relèvement de 1,238 que le texte courant.
    ///
    /// Le MÊME multiplicateur des deux côtés, et c'est tout l'enjeu de ce nombre. Ne relever que
    /// le corps aurait inversé la hiérarchie : `display` sert aussi à de petits nombres, jusqu'à
    /// 11 pt de taille dessinée, et à 0,94 ils seraient tombés sous des libellés courants montés
    /// à 1,30. Un titre plus petit que le texte qu'il coiffe. Appliquer le même facteur des deux
    /// côtés laisse intactes toutes les proportions choisies au dessin ; l'app grandit, elle ne
    /// se réorganise pas.
    ///
    /// Les tailles vont de 11 à 40, donc de 12,8 à 46,4 pt à l'écran. La plus grande est le
    /// « RUNUP » de l'écran de lancement, cinq lettres sur une page vide.
    static let sizeFactor: CGFloat = 1.16

    /// La taille de point à demander pour retrouver l'encombrement dessiné à l'origine.
    static func pointSize(for designSize: CGFloat) -> CGFloat { designSize * sizeFactor }

    /// La police à taille fixe, pour le widget et la montre — qui n'ont pas le mécanisme Dynamic
    /// Type plafonné de l'app (`RUFont.scaled`) et n'en veulent pas : un widget est un carré, il
    /// ne peut pas grandir avec le réglage de taille du texte.
    static func font(_ designSize: CGFloat) -> Font {
        .custom(postScriptName, size: pointSize(for: designSize))
    }
}
