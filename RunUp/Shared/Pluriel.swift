import Foundation

/// Le pluriel ne se fabrique pas de la même façon dans les trois langues de l'app.
///
/// # LE DÉFAUT
///
/// En français, ZÉRO est au singulier : « 0 course », « 0 badge », « 0 jour de suite ». En anglais
/// et en espagnol, il est au PLURIEL : « 0 runs », « 0 badges », « 0 days in a row ».
///
/// Partout dans l'app, la bascule était écrite `n > 1` — la règle française, appliquée aux trois
/// langues. Une anglophone qui s'inscrit lit donc, le jour même, sur trois écrans : « 0 run »,
/// « 0 badge », « 0 day in a row », « 0 follower ». Ce sont précisément les écrans d'un compte
/// neuf, donc exactement les premiers qu'elle voit.
///
/// # POURQUOI PAS `variations.plural` DU CATALOGUE
///
/// Le catalogue de chaînes d'Apple sait choisir la bonne forme par langue, et c'est la bonne
/// réponse QUAND LE NOMBRE EST DANS LA PHRASE : « %lld course importée. » en a besoin, et l'a.
/// Mais la moitié de ces libellés sont des UNITÉS affichées à côté du chiffre et pas avec lui —
/// « 12 » en gros, « jours » en petit, deux `Text` séparés pour que le chiffre porte seul la
/// taille (voir `RUStatTile`). Une variation de pluriel sans spécificateur numérique dans sa
/// valeur est refusée à la compilation du catalogue (« Cannot infer format specifier for string
/// group because no numerical specifiers were found »), et la réponse d'Apple à ce cas est
/// justement : deux chaînes ordinaires et un test sur le nombre.
///
/// D'où cette règle, écrite à la main, pour les trois langues que l'app livre et pas une de plus.
/// `check_pluriel.py` refuse une quatrième langue au projet tant qu'elle n'a pas sa règle ici.
enum Pluriel {

    /// Les langues que l'app livre, et dont la règle est donc écrite ici.
    ///
    /// `check_pluriel.py` compare cette liste au catalogue de chaînes : une quatrième langue
    /// ajoutée au projet sans une ligne de plus dans `estSingulier` fait échouer la CI. C'est le
    /// seul moyen de ne pas découvrir le problème comme on a découvert celui-ci — en lisant
    /// « 0 run » sur une capture d'écran.
    static let languesLivrees = ["fr", "en", "es"]

    /// La langue dans laquelle les textes sortent RÉELLEMENT — celle que le bundle a retenue, pas
    /// celle de la région. Un téléphone réglé en anglais dans une région française affiche
    /// l'anglais : `Locale.current` dirait « fr » et on remettrait la règle française.
    static var langueAffichee: String {
        let brut = Bundle.main.preferredLocalizations.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "fr"
        // « pt-BR », « en-GB », « es-419 » → « pt », « en », « es ».
        return String(brut.prefix(2)).lowercased()
    }

    /// `true` quand ce nombre prend la forme SINGULIÈRE dans la langue affichée.
    ///
    /// Le paramètre `langue` n'existe que pour les tests : il permet de vérifier les trois règles
    /// sans changer la langue du simulateur.
    static func estSingulier(_ nombre: Int, langue: String? = nil) -> Bool {
        let n = abs(nombre)
        switch langue ?? langueAffichee {
        // Le français met zéro au singulier : « 0 course », « 0 jour ».
        case "fr": return n < 2
        // Anglais et espagnol : seul UN est au singulier. Zéro est pluriel.
        // Le `default` leur est volontairement identique : c'est la règle de la très grande
        // majorité des langues, et la moins fausse pour une langue ajoutée sans y penser.
        default: return n == 1
        }
    }

    /// La bonne des deux formes, selon le nombre et la langue affichée.
    ///
    /// Les deux arguments sont PRÊTS À L'EMPLOI, et ce sont les sites d'appel qui décident de ce
    /// que « prêt » veut dire : une clé brute quand le composant qui les reçoit la traduit
    /// lui-même (`RUStatTile.unit`, `MetricColumn.label` enveloppent dans un `LocalizedStringKey`),
    /// une chaîne déjà traduite par `String(localized:)` quand elle est affichée telle quelle.
    static func choisir(_ nombre: Int, _ singulier: String, _ pluriel: String) -> String {
        estSingulier(nombre) ? singulier : pluriel
    }
}
