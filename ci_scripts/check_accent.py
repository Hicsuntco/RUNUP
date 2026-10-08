#!/usr/bin/env python3
"""La couleur de marque est écrite dans quatre cibles. Elle doit y être écrite pareil.

# POURQUOI CE CONTRÔLE EXISTE

`AccentTheme` est la source : huit nuanciers, trois couleurs chacun. Mais une extension de widget,
une montre et une Live Activity sont des processus séparés qui ne peuvent PAS lire l'objet en
mémoire de l'app — chacune recopie donc les valeurs chez elle. Quatre écritures de la même chose,
dans quatre fichiers.

Le jour où le rose de marque a changé de teinte, il a fallu les retrouver une par une. En oublier
une n'aurait rien cassé : l'app aurait simplement eu un widget d'une autre couleur que l'écran
d'accueil, ou un chrono sur l'écran verrouillé dans l'ancien rose. Personne ne l'aurait signalé
comme un bug — ça ressemble à un choix.

C'est la même duplication que `check_events.py` surveille entre le client et le serveur, et elle
échoue de la même façon : en silence, et en ressemblant à une décision.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
SOURCE = RACINE / "RunUp" / "DesignSystem" / "AccentTheme.swift"
MIROIRS_COMPLETS = [RACINE / "RunUpWidgets" / "WidgetAccentPalette.swift"]
# Les copies qui ne gardent QUE le rose principal, parce qu'elles n'offrent pas le choix du
# nuancier : la montre et le widget d'activité en direct affichent la couleur de la marque.
MIROIRS_DU_ROSE = {
    RACINE / "RunUpWatch" / "WatchViews.swift": r"static let rose = Color\(hex: (0x[0-9A-Fa-f]{6})\)",
    RACINE / "RunUpWidgets" / "RunActivityWidget.swift":
        r"private static let accent = Color\(hex: (0x[0-9A-Fa-f]{6})\)",
}

_SOURCE = re.compile(
    r'AccentTheme\(id:\s*"(\w+)",\s*name:\s*"[^"]*",\s*'
    r'primary:\s*Color\(hex:\s*(0x[0-9A-Fa-f]{6})\),\s*'
    r'light:\s*Color\(hex:\s*(0x[0-9A-Fa-f]{6})\),\s*'
    r'tail:\s*Color\(hex:\s*(0x[0-9A-Fa-f]{6})\)\)')
_MIROIR = re.compile(r'"(\w+)":\s*\((0x[0-9A-Fa-f]{6}),\s*(0x[0-9A-Fa-f]{6}),\s*(0x[0-9A-Fa-f]{6})\)')


def _normalise(trouvees):
    return {nom: tuple(c.lower() for c in couleurs) for nom, *couleurs
            in ((t[0], t[1], t[2], t[3]) for t in trouvees)}


def nuanciers(source):
    """Les nuanciers déclarés par `AccentTheme`."""
    return _normalise(_SOURCE.findall(source))


def miroir(source):
    """Les nuanciers recopiés par une cible secondaire."""
    return _normalise(_MIROIR.findall(source))


def ecarts(reference, copie, nom_du_fichier):
    """Ce qui diffère entre la source et une copie, dans les deux sens."""
    problemes = []
    for cle in sorted(set(reference) - set(copie)):
        problemes.append(f"{nom_du_fichier} ne connaît pas le nuancier « {cle} » : "
                         f"qui le choisira verra la couleur d'un autre.")
    for cle in sorted(set(copie) - set(reference)):
        problemes.append(f"{nom_du_fichier} déclare « {cle} », que `AccentTheme` ne connaît plus.")
    for cle in sorted(set(reference) & set(copie)):
        if reference[cle] != copie[cle]:
            problemes.append(f"{nom_du_fichier} : « {cle} » vaut {', '.join(copie[cle])} "
                             f"au lieu de {', '.join(reference[cle])}.")
    return problemes


def main():
    source = SOURCE.read_text(encoding="utf-8")
    reference = nuanciers(source)
    if not reference:
        print("::error::Aucun nuancier lu dans AccentTheme.swift : ce contrôle ne surveille "
              "plus rien, corrige-le ou retire-le.", file=sys.stderr)
        return 1

    problemes = []
    for chemin in MIROIRS_COMPLETS:
        problemes += ecarts(reference, miroir(chemin.read_text(encoding="utf-8")),
                            chemin.relative_to(RACINE).as_posix())

    rose = reference.get("rose", (None,))[0]
    for chemin, motif in MIROIRS_DU_ROSE.items():
        nom = chemin.relative_to(RACINE).as_posix()
        trouve = re.search(motif, chemin.read_text(encoding="utf-8"))
        if not trouve:
            problemes.append(f"{nom} : la copie du rose de marque est introuvable — "
                             f"elle a été renommée, et plus personne ne la surveille.")
        elif trouve.group(1).lower() != rose:
            problemes.append(f"{nom} : le rose vaut {trouve.group(1).lower()} au lieu de {rose}.")

    if problemes:
        for p in problemes:
            print(f"::error::{p}", file=sys.stderr)
        print("::error::La source est RunUp/DesignSystem/AccentTheme.swift. Les autres cibles "
              "sont des processus séparés qui ne peuvent pas la lire : elles la recopient, et "
              "c'est à ce contrôle de tenir les copies d'accord.", file=sys.stderr)
        return 1

    print(f"Accents : {len(reference)} nuanciers, "
          f"{len(MIROIRS_COMPLETS) + len(MIROIRS_DU_ROSE)} copies d'accord avec la source.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
