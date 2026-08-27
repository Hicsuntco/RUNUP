import SwiftUI

/// La police de titrage de RunUp, nommée et dimensionnée en un seul endroit.
///
/// Trois cibles l'utilisent — l'app, le widget, la montre — et jusqu'ici chacune écrivait son nom
/// PostScript en dur, neuf fois rien que dans le widget. Changer de police demandait donc de
/// retrouver toutes ces chaînes, et il suffisait d'en oublier une pour que l'app affiche deux
/// polices différentes sans que rien ne le signale : une chaîne `.custom` introuvable ne lève
/// aucune erreur, elle retombe silencieusement sur la police système.
///
/// Ce fichier vit dans `RunUp/Shared`, compilé par les trois cibles. Il ne dépend que de SwiftUI :
/// aucun modèle, rien qui puisse le rendre inéligible à l'une d'elles.
enum DisplayFont {
    /// Le nom PostScript, pas le nom de famille : c'est celui-là que `Font.custom` attend.
    ///
    /// C'est DM Sans en Bold — la MÊME famille que le texte courant, une graisse plus haut.
    /// Autrement dit : plus de police de titrage du tout.
    ///
    /// Bold et non ExtraBold : à 800, les titres avaient l'épaisseur d'un titre d'affiche ; à 700
    /// ils gardent leur autorité sans peser. La largeur ne change pas — Bold mesure 0,994 fois
    /// ExtraBold sur les vraies chaînes de l'app — donc le facteur ci-dessous reste valable tel
    /// quel, et aucune mise en page ne bouge.
    ///
    /// Ce n'est pas un renoncement, c'est le registre visé. Bebas était une condensée d'affiche,
    /// Bricolage une grotesque à caractère ; toutes deux ont une voix, et c'est cette voix qui
    /// gênait. Les apps de course qui lisent « premium » n'ont pas de police de titrage : elles
    /// ont une seule famille neutre, et laissent la hiérarchie se faire par la graisse et la
    /// taille. Une famille au lieu de deux, c'est aussi une police de moins à charger et plus
    /// rien qui puisse mal vieillir séparément du reste.
    static let postScriptName = "DMSans-Bold"

    /// ─── POURQUOI 0,82 ────────────────────────────────────────────────────────────────────────
    ///
    /// Toutes les tailles passées aux fonctions ci-dessous ont été dessinées contre Bebas Neue,
    /// dans une seule maquette, les unes par rapport aux autres. Bebas est une CONDENSÉE : à
    /// taille de point égale, sur les vraies chaînes de l'app, DM Sans Bold est
    /// **1,7 fois plus large**. Un remplacement à taille identique ferait déborder chaque titre.
    ///
    /// Compenser la largeur exactement demanderait 0,58 et donnerait un texte minuscule. 0,82 est
    /// le compromis : il tient dans les gabarits sans raboter la présence des grands chiffres.
    ///
    /// Mesuré au passage, et c'est ce qui a rendu ce changement indolore : DM Sans ExtraBold est à
    /// 1 % près de la largeur de Bricolage, avec une hauteur de capitale PLUS GRANDE (0,700 contre
    /// 0,660 — exactement celle de Bebas). Même encombrement, un peu plus de présence, même
    /// facteur.
    ///
    /// La vraie réponse, plus tard, est de reprendre les 27 tailles une à une contre la nouvelle
    /// police. Ce facteur est l'étape honnête en attendant, pas un remplacement de ce travail.
    ///
    /// Relevé de 0,82 à 0,94 : à 0,82 les titres et les grands chiffres étaient jugés trop petits,
    /// et c'est cohérent avec la mesure — 0,82 compensait la largeur au détriment de la hauteur de
    /// capitale, qui tombait à 0,57 em quand Bebas en occupait 0,70. À 0,94 elle remonte à 0,66,
    /// soit presque celle d'origine, au prix d'une largeur qui reste supérieure à celle de Bebas.
    /// C'est le sens du compromis, pas sa disparition.
    static let sizeFactor: CGFloat = 0.94

    /// La taille de point à demander pour retrouver l'encombrement dessiné contre Bebas.
    static func pointSize(for designSize: CGFloat) -> CGFloat { designSize * sizeFactor }

    /// La police à taille fixe, pour le widget et la montre — qui n'ont pas le mécanisme Dynamic
    /// Type plafonné de l'app (`RUFont.scaled`) et n'en veulent pas : un widget est un carré, il
    /// ne peut pas grandir avec le réglage de taille du texte.
    static func font(_ designSize: CGFloat) -> Font {
        .custom(postScriptName, size: pointSize(for: designSize))
    }
}
