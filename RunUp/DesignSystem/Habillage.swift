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
///   • `trace`     — le sol prend une trace de l'accent courant, le filet tombe, et les cartes se
///                   détachent par une ombre qui porte la même teinte. Elles flottent sur quelque
///                   chose au lieu d'être posées sur du blanc.
///
/// L'accent lui-même ne change pas : il reste celui des huit thèmes. Tout ce que `trace` ajoute
/// en dérive, donc les huit continuent de fonctionner sans une ligne de plus.
enum Habillage: String, CaseIterable, Identifiable {
    case classique
    case trace

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
        case .trace: return String(localized: "Teinté")
        }
    }

    var explication: String {
        switch self {
        case .classique: return String(localized: "Fond neutre, cartes au filet fin.")
        case .trace: return String(localized: "Le fond prend ta couleur, les cartes flottent dessus.")
        }
    }
}
