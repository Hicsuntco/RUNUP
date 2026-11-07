#!/usr/bin/env python3
"""Un attribut doit toucher la déclaration qu'il gouverne.

# LE DÉFAUT, ET IL EST ARRIVÉ DEUX FOIS

Swift accepte un commentaire de documentation ENTRE un attribut et la déclaration qu'il
gouverne. L'attribut, lui, continue de s'appliquer à la déclaration qui suit — c'est-à-dire,
après une insertion, à la fonction qu'on vient d'écrire et pas à celle qu'on croit.

Ça s'écrit tout seul : on extrait une fonction d'une autre et on la pose juste au-dessus, avec sa
documentation, sans voir que les deux lignes d'attributs qui précèdent appartenaient à la
suivante.

  · `AdaptivePlanEngine.swift` — un `@discardableResult` resté douze fonctions plus haut s'est
    recollé sur `markSessionDone`, qui ne rend rien : « '@discardableResult' declared on a
    function returning Void has no effect ». Un avertissement, donc, pas une erreur ; il est
    resté.
  · `CaptureSeed.swift` — `@MainActor` et `@discardableResult` se sont recollés sur
    `viderLeStock`, et `poser` a perdu son isolation. Celle-ci casse la construction, mais
    QUARANTE MINUTES plus tard, sur la machine, parce qu'ici il n'y a pas de compilateur.

Les deux sont invisibles à la lecture : la documentation est au bon endroit, la fonction est au
bon endroit, et c'est l'attribut qui a changé de propriétaire.

# CE QUI EST REGARDÉ

Une ligne qui ne contient QU'UN ATTRIBUT — `@MainActor`, `@discardableResult`,
`@available(iOS 17, *)` — suivie, après d'éventuels autres attributs seuls et lignes vides, d'un
commentaire de documentation `///`.

Une ligne où l'attribut et la déclaration tiennent ensemble (`@State private var ouvert = false`)
n'est jamais signalée : l'attribut y touche déjà ce qu'il gouverne, et le `///` de la ligne
suivante documente le membre d'après. C'est la forme la plus courante du dépôt, et la confondre
avec le défaut rendrait ce contrôle inutilisable.

Un commentaire ordinaire `//` ne compte pas : il n'annonce pas une déclaration, et il est d'usage
d'expliquer un attribut juste en dessous de lui.
"""
import pathlib, re, sys

#: Une ligne qui ne porte qu'un attribut, ses parenthèses éventuelles comprises.
SEUL = re.compile(r"^\s*@[A-Za-z_][A-Za-z0-9_]*\s*(\([^()]*\))?\s*$")

#: Les dossiers relus. Tout le Swift du dépôt : le défaut n'a pas de couche de prédilection.
#:
#: LE NOM EXACT COMPTE, ET LE PREMIER JET L'AVAIT FAUX. « RunUpWidget » au singulier n'existe
#: pas — le dossier est `RunUpWidgets` — et `rglob` sur un chemin absent ne rend rien, sans rien
#: dire. Le contrôle couvrait donc le widget en apparence et pas du tout en fait. `main` exige
#: maintenant que chaque dossier existe.
DOSSIERS = ("RunUp", "RunUpTests", "RunUpUITests", "RunUpWidgets", "RunUpWatch")


def egares(source: str) -> list[tuple[int, str]]:
    """Les attributs séparés de leur déclaration par une documentation, et leur ligne."""
    lignes = source.splitlines()
    trouves: list[tuple[int, str]] = []
    for i, ligne in enumerate(lignes):
        if not SEUL.match(ligne):
            continue
        # L'attribut précédent est déjà signalé s'il y a lieu : on ne compte qu'une fois par
        # grappe, celle du dernier attribut, le plus proche de la documentation égarée.
        if i + 1 < len(lignes) and SEUL.match(lignes[i + 1]):
            continue
        for suivante in lignes[i + 1:]:
            if not suivante.strip():
                continue
            if suivante.lstrip().startswith("///"):
                trouves.append((i + 1, ligne.strip()))
            break
    return trouves


def main() -> int:
    racine = pathlib.Path(__file__).resolve().parent.parent
    fautes: list[str] = []
    lus = 0
    for dossier in DOSSIERS:
        if not (racine / dossier).is_dir():
            print(f"Le dossier « {dossier} » n'existe pas : ce contrôle ne relit pas ce qu'il "
                  f"annonce. Corriger DOSSIERS.")
            return 1
        for chemin in sorted((racine / dossier).rglob("*.swift")):
            lus += 1
            for numero, attribut in egares(chemin.read_text(encoding="utf-8")):
                fautes.append(f"{chemin.relative_to(racine)}:{numero} — "
                              f"`{attribut}` est séparé de sa déclaration par une documentation ; "
                              f"il s'applique donc à la déclaration qui suit celle-ci.")
    if fautes:
        print(f"{len(fautes)} attribut(s) égaré(s) :")
        for faute in fautes:
            print(f"  · {faute}")
        print("\nRemettre l'attribut juste au-dessus de sa déclaration, sous sa documentation.")
        return 1
    print(f"{lus} fichiers Swift relus : aucun attribut séparé de sa déclaration.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
