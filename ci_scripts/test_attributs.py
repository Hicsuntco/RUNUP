#!/usr/bin/env python3
"""Vérifie `check_attributs.py` sur des cas écrits exprès, sans Xcode.

Les deux premiers cas sont les deux défauts réels, recopiés du dépôt : un contrôle qui ne
rattraperait pas ce qui l'a fait naître ne garde rien.

Le reste est ce qu'il doit LAISSER PASSER, et c'est la majeure partie du dépôt — `@State private
var ouvert = false` suivi de la documentation du membre d'après est la forme la plus courante de
toutes les vues. La confondre avec le défaut rendrait ce contrôle inutilisable au premier commit.
"""
import sys
import check_attributs as ck

cas = []


def cas_test(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def attendu(src, nombre, nom):
    trouves = ck.egares(src)
    assert len(trouves) == nombre, f"{nom} : {nombre} attendu(s), {len(trouves)} trouvé(s) → {trouves}"


# ── Les deux défauts réels ────────────────────────────────────────────────────────────────────

@cas_test("CaptureSeed : deux attributs restés sur la fonction d'à côté")
def _():
    attendu('''
    /// Pose l'état, dans un contexte neuf, et rend le profil.
    @MainActor
    @discardableResult
    /// VIDER SANS POSER, ET C'EST LE DRAPEAU `--inscription` QUI EN A BESOIN.
    static func viderLeStock(dans contexte: ModelContext) {
        vider(UserProfile.self, dans: contexte)
    }

    static func poser(dans contexte: ModelContext) -> UserProfile {
        viderLeStock(dans: contexte)
    }
    ''', 1, "deux attributs, une seule grappe")


@cas_test("AdaptivePlanEngine : un @discardableResult sur une fonction qui ne rend rien")
def _():
    attendu('''
    @discardableResult
    /// Marque la séance faite.
    func markSessionDone(_ id: UUID) {
    }
    ''', 1, "attribut seul")


# ── Ce qu'il doit laisser passer ──────────────────────────────────────────────────────────────

@cas_test("un attribut qui tient sur la même ligne que sa déclaration")
def _():
    attendu('''
    @State private var ouvert = false
    /// Faux tant que le serveur n'a pas répondu.
    @State private var charge = false
    ''', 0, "propriété et documentation du membre suivant")


@cas_test("un attribut juste au-dessus de sa déclaration")
def _():
    attendu('''
    /// Pose l'état et rend le profil.
    @MainActor
    @discardableResult
    static func poser(dans contexte: ModelContext) -> UserProfile {
    }
    ''', 0, "documentation au-dessus, comme il faut")


@cas_test("un commentaire ordinaire sous l'attribut n'est pas une documentation")
def _():
    attendu('''
    @MainActor
    // `status` est lu par la vue et écrit par un rappel de CoreLocation.
    final class LocationService: NSObject {
    }
    ''', 0, "// et non ///")


@cas_test("un attribut à paramètres")
def _():
    attendu('''
    @available(iOS 17, *)
    /// Le widget interactif.
    struct Bouton: Widget {
    }
    ''', 1, "les parenthèses ne changent rien")


@cas_test("une déclaration suivie d'une documentation, sans attribut nulle part")
def _():
    attendu('''
    func a() {}
    /// Documentation de b.
    func b() {}
    ''', 0, "rien à signaler")


@cas_test("un @ dans une chaîne ne fait pas un attribut")
def _():
    attendu('''
    let adresse = "@MainActor"
    /// Documentation.
    func a() {}
    ''', 0, "la ligne porte autre chose que l'attribut")


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
