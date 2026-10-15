import SwiftUI

/// LA DIRECTION ARTISTIQUE, CHOISIE DANS L'APP ET RÉVERSIBLE D'UN GESTE.
///
/// # POURQUOI C'EST UN RÉGLAGE ET PAS UN COMMIT
///
/// Une direction artistique ne se juge pas sur une maquette : elle se juge en vivant avec, sur
/// son propre historique, quelques jours. Et le dépôt garde la trace d'une tentative précédente
/// abandonnée en cours de route — le fond « rose pâle → crème → menthe » dont `RUColor.bg` porte
/// encore le récit. Revenir en arrière avait alors coûté un commit, une compilation et un envoi.
///
/// Ici, revenir coûte un appui. C'est la seule façon honnête de proposer un changement d'allure
/// à quelqu'un qui ne peut pas l'essayer avant qu'il soit construit.
///
/// # CE QUE CHAQUE HABILLAGE CHANGE
///
/// Rien de ce qui est écrit ni de ce qui se touche : ni les tailles, ni les cibles de 44 points,
/// ni les contrastes du texte, qui restent tenus par `check_a11y`. Ce qui change est le SOL et la
/// façon dont les surfaces s'en détachent.
///
///   • `classique` — fond presque blanc ou presque noir, cartes séparées par un filet.
///   • `teinte`    — le sol prend une trace de l'accent courant, le filet tombe, et les cartes se
///                   détachent par une ombre qui porte la même teinte. Elles flottent sur quelque
///                   chose au lieu d'être posées sur du blanc.
///
/// L'accent lui-même ne change pas : il reste celui des huit thèmes. Tout ce que `trace` ajoute
/// en dérive, donc les huit continuent de fonctionner sans une ligne de plus.
enum Habillage: String, CaseIterable, Identifiable {
    case classique
    /// LA VALEUR BRUTE RESTE « trace », ET LE NOM SWIFT N'EST PLUS CELUI-LÀ.
    ///
    /// Cet habillage a d'abord porté un tracé GPS en fond d'en-tête, d'où son nom d'origine. Le
    /// tracé a été retiré — il ne rendait pas — mais sa valeur brute, elle, est écrite dans les
    /// profils déjà enregistrés ET dans les fichiers de sauvegarde déjà exportés. La renommer
    /// renverrait silencieusement au classique quiconque avait basculé, et perdrait le réglage
    /// de toute sauvegarde relue ensuite.
    ///
    /// Le nom Swift dit ce que l'habillage EST aujourd'hui ; la valeur brute dit ce qu'il a été
    /// nommé le jour où on a commencé à l'écrire sur un disque. Les deux n'ont aucune raison de
    /// se ressembler, et c'est la seconde qui ne doit jamais bouger.
    case teinte = "trace"

    var id: String { rawValue }

    /// Le repli quand la valeur stockée ne veut rien dire — une version plus ancienne qui relit
    /// un profil écrit par une plus récente. Même règle que `RunRecord.discipline`.
    static let defaut = Habillage.classique

    static func depuis(_ brut: String?) -> Habillage {
        brut.flatMap(Habillage.init(rawValue:)) ?? defaut
    }

    var nom: String {
        switch self {
        case .classique: return String(localized: "Classique")
        case .teinte: return String(localized: "Teinté")
        }
    }

    var explication: String {
        switch self {
        case .classique: return String(localized: "Fond neutre, cartes au filet fin.")
        case .teinte: return String(localized: "Le fond prend ta couleur, les cartes flottent dessus.")
        }
    }
}
