import Foundation
import Observation

/// L'ACCORD EN GENRE, PARCE QUE LE FRANÇAIS L'EXIGE.
///
/// # LE PROBLÈME
///
/// RUNUP tutoie, et le tutoiement français s'accorde : « tu es seule », « tu es partie fort »,
/// « Débutante ». Toute l'app était écrite au féminin — c'est sa voix, et c'est délibéré : elle
/// s'adresse d'abord à des coureuses. Mais un homme qui s'inscrit, qui répond « Homme » à la
/// question du profil, et à qui l'app répond « tu es seule dans ce club », n'a pas affaire à une
/// voix : il a affaire à une app qui ne l'a pas écouté.
///
/// L'anglais n'a pas ce problème — les deux formes y sont le même mot — et l'espagnol l'a autant
/// que le français. Les trois langues passent donc par le même mécanisme, et deux d'entre elles
/// donnent simplement deux fois la même traduction.
///
/// # CE QUI EST FAIT, ET CE QUI NE L'EST PAS
///
/// On n'invente pas une forme : on écrit les DEUX phrases, et on choisit. Coller un « e » à la
/// fin d'un mot marche pour « seul(e) » et casse sur « Débutant(e) » au pluriel, sur « vieux /
/// vieille », et sur tout ce qui n'est pas régulier. Deux phrases complètes coûtent une clé de
/// catalogue de plus, et ne peuvent pas produire un mot qui n'existe pas.
///
/// # « JE PRÉFÈRE NE PAS DIRE » GARDE LE FÉMININ, ET C'EST UN CHOIX
///
/// Le français oblige à trancher : il n'a pas de troisième forme. Deux options, et aucune n'est
/// neutre. Mettre le masculin par défaut changerait la voix de l'app pour toutes celles qui ont
/// répondu « je préfère ne pas dire » depuis le début — elles voient le féminin aujourd'hui.
/// Garder le féminin ne change rien pour personne, et le masculin reste ce qu'il est : une
/// adaptation pour qui l'a demandée, pas le défaut d'un produit qui s'adresse d'abord à des
/// coureuses.
enum Genre: String, CaseIterable {
    case feminin
    case masculin

    /// Lu sur la réponse de l'inscription. `nil` et « je préfère ne pas dire » donnent le
    /// féminin : voir l'en-tête.
    static func depuis(sexe: String?) -> Genre {
        sexe == "male" ? .masculin : .feminin
    }
}

/// Le genre en cours, lisible de partout.
///
/// Un singleton en mémoire, exactement comme `ThemeStore` et pour la même raison : ces phrases
/// vivent dans des vues, des services et des modèles, et faire descendre le profil jusqu'à
/// chacune aurait demandé de le passer en paramètre à une trentaine d'endroits dont la plupart
/// n'ont rien d'autre à en faire. Il est rafraîchi au lancement et à chaque fois que le profil
/// change — voir `AppState`.
@Observable
final class AccordStore {
    static let shared = AccordStore()
    var genre: Genre = .feminin
    private init() {}
}

/// Choisit entre deux phrases déjà traduites.
///
/// # POURQUOI LES DEUX ARGUMENTS SONT DES CHAÎNES DÉJÀ RÉSOLUES
///
/// Parce que `check_strings.py` doit les voir. Il cherche `String(localized: "…")` dans le code ;
/// un appel de la forme `Accord.selon(f: String(localized: "…"), m: String(localized: "…"))`
/// lui présente donc deux littéraux qu'il sait réclamer au catalogue. Une signature plus jolie
/// qui prendrait deux `LocalizationValue` lui cacherait les deux, et une phrase sur deux
/// sortirait en français en anglais — exactement le défaut que ce contrôle existe pour empêcher.
///
/// Les deux branches sont évaluées, donc les deux chaînes sont résolues à chaque appel. C'est le
/// prix, et il est nul : une résolution de catalogue est une lecture de dictionnaire, et aucune
/// de ces phrases n'est dans une boucle.
enum Accord {
    static var genre: Genre { AccordStore.shared.genre }

    static func selon(f feminin: String, m masculin: String) -> String {
        genre == .feminin ? feminin : masculin
    }
}
