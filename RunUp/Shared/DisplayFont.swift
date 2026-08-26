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
    /// Le nom PostScript, pas le nom de famille : c'est celui-là que `Font.custom` attend, et il
    /// diffère du nom de fichier (`BricolageGrotesque-ExtraBold.ttf` → famille « Bricolage
    /// Grotesque ExtraBold »).
    static let postScriptName = "BricolageGrotesque-ExtraBold"

    /// ─── POURQUOI 0,82 ────────────────────────────────────────────────────────────────────────
    ///
    /// Toutes les tailles passées aux fonctions ci-dessous ont été dessinées contre Bebas Neue,
    /// dans une seule maquette, les unes par rapport aux autres. Bebas est une CONDENSÉE : à
    /// taille de point égale, sur les vraies chaînes de l'app, Bricolage ExtraBold est
    /// **1,67 fois plus large** (rapport de largeur mesuré 0,60 sur « SORTIE LONGUE »,
    /// « FONCTIONNEL HYROX · CIRCUIT INTENSE », « DÉMARRER », « ALLURE »).
    ///
    /// Mais sa hauteur de capitale est plus PETITE : 0,660 em contre 0,700. Les deux mesures
    /// tirent donc en sens inverse — compenser la largeur demanderait 0,60 et donnerait un texte
    /// minuscule, compenser la hauteur demanderait 1,06 et ferait déborder chaque titre. Aucun
    /// facteur unique n'est juste ; celui-ci est le compromis, et il se règle ici, en un nombre,
    /// après avoir regardé un vrai écran.
    ///
    /// La vraie réponse, plus tard, est de reprendre les 27 tailles une à une contre la nouvelle
    /// police. Ce facteur est l'étape honnête en attendant, pas un remplacement de ce travail.
    static let sizeFactor: CGFloat = 0.82

    /// La taille de point à demander pour retrouver l'encombrement dessiné contre Bebas.
    static func pointSize(for designSize: CGFloat) -> CGFloat { designSize * sizeFactor }

    /// La police à taille fixe, pour le widget et la montre — qui n'ont pas le mécanisme Dynamic
    /// Type plafonné de l'app (`RUFont.scaled`) et n'en veulent pas : un widget est un carré, il
    /// ne peut pas grandir avec le réglage de taille du texte.
    static func font(_ designSize: CGFloat) -> Font {
        .custom(postScriptName, size: pointSize(for: designSize))
    }
}
