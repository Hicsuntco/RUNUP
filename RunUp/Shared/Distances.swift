import Foundation

/// « 20 km », « 2,5 km », « 42,2 km » — le zéro décimal inutile tombe, la virgule suit la langue.
///
/// POURQUOI UN SEUL ENDROIT. `String(format: "%.1f")` sans argument `locale:` écrit un POINT
/// décimal dans les trois langues, et « 42.2 km » en français est exactement le détail qui fait
/// dire « ça n'a pas été fait ici » (voir ci_scripts/check_decimales.py, qui ferme cette porte).
/// La mise en forme existait déjà en double — une copie dans `Duathlon`, une dans `Triathlon` —
/// et les pages de course en voulaient une troisième. Trois copies finissent toujours par
/// diverger : « 2.5 km » sur un écran, « 2,5 km » sur le suivant.
enum Distances {
    /// LE NOMBRE SEUL, sans « km » collé derrière.
    ///
    /// `km(_:)` rend « 8,1 km » d'un bloc, ce qui est juste dans une phrase ou un titre. Mais un
    /// chiffre posé à côté de son unité en petit — ce que fait `RUChiffre` partout — a besoin
    /// des deux SÉPARÉMENT, sinon l'unité grandit avec le chiffre. Sans cette fonction, chaque
    /// appelant recopiait `String(format:)`, et c'est la copie que `km(_:)` existe pour éviter.
    static func valeur(_ valeur: Double) -> String {
        let arrondi = (valeur * 10).rounded() / 10
        return arrondi == arrondi.rounded()
            ? String(format: "%.0f", locale: Locale.current, arrondi)
            : String(format: "%.1f", locale: Locale.current, arrondi)
    }

    static func km(_ valeur: Double) -> String {
        let arrondi = (valeur * 10).rounded() / 10
        return arrondi == arrondi.rounded()
            ? String(format: "%.0f km", locale: Locale.current, arrondi)
            : String(format: "%.1f km", locale: Locale.current, arrondi)
    }
}
