#!/usr/bin/env python3
"""Lire la palette dans `Colors.swift`, et calculer un contraste. Un seul lecteur pour tous.

Le retrait des commentaires vient de `swift.py`, qui le faisait déjà et le fait mieux — il tient
aussi les chaînes. Une première version de ce fichier en avait écrit sa propre copie : exactement
la règle-écrite-deux-fois que ce dépôt passe son temps à retirer, commise dans le fichier dont le
rôle est de n'en avoir qu'une.

Deux gardes ont besoin de ces deux choses : `check_jetons_de_texte.py`, qui vérifie que les jetons
de texte sont opaques et ne perdent pas de contraste, et `check_design.py`, qui vérifie que
`DESIGN.md` décrit l'app telle qu'elle est. Écrire le lecteur deux fois reviendrait à ce que les
deux gardes puissent lire la MÊME déclaration différemment — et un garde qui se trompe sur ce
qu'il lit est pire qu'aucun garde.

Ce module ne s'exécute pas seul : `check_cablage.py` le compte comme « lancé par un import ».
"""

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from swift import sans_commentaires, sans_commentaires_seuls  # noqa: E402,F401

RACINE = pathlib.Path(__file__).resolve().parent.parent
COULEURS = RACINE / "RunUp/DesignSystem/Colors.swift"

# `melange(rose, sur: neutre, part:)` dans `RUColor.fond(pour:)` — une trace, pas un aplat.
PART_TEINTE = {"clair": 0.035, "sombre": 0.10}


# ── LA SOURCE ────────────────────────────────────────────────────────────────────────────────

_VAR = re.compile(r"static var ([a-zA-Z][a-zA-Z0-9]*): Color \{([^{}]*)\}")
_LET = re.compile(r"static let ([a-zA-Z][a-zA-Z0-9]*) = Color\(hex: (0x[0-9A-Fa-f]{6})\)")
_HEX = re.compile(r"Color\(hex: (0x[0-9A-Fa-f]{6})\)")


def valeur(texte: str):
    """Un hex, `Color.white`/`Color.black`, ou la chaîne brute si c'est autre chose.

    Rendre la chaîne brute plutôt que `None` est volontaire : « autre chose » est une information
    — une opacité, un appel à `AccentTheme`, un mélange — et c'est au garde appelant de décider si
    elle est légitime à cet endroit.
    """
    texte = texte.strip()
    if (m := re.fullmatch(r"Color\(hex: (0x[0-9A-Fa-f]{6})\)", texte)):
        return int(m.group(1), 16)
    if texte == "Color.white":
        return 0xFFFFFF
    if texte == "Color.black":
        return 0x000000
    return texte


def declarations(source: str = None) -> dict:
    """`{nom: {"clair": valeur, "sombre": valeur}}` pour chaque jeton de couleur déclaré.

    Un `static let` n'a qu'une valeur et vaut donc dans les deux thèmes — ce n'est pas un
    raccourci : les deux surfaces de l'écran de séance sont FIXES exprès, parce qu'on court
    dehors, et `Colors.swift` l'explique à l'endroit où elles sont déclarées.
    """
    if source is None:
        source = sans_commentaires(COULEURS.read_text(encoding="utf-8"))
    trouves = {}
    for nom, corps in _VAR.findall(source):
        corps = corps.strip()
        if (m := re.fullmatch(r"isLight \? (.+?) : (.+?)", corps)):
            trouves[nom] = {"clair": valeur(m.group(1)), "sombre": valeur(m.group(2))}
        else:
            # Pas de branche `isLight` : une seule valeur, qui vaut donc dans les deux thèmes.
            # `valeur()` la décode si c'est un hex (`traceBackground`), et la rend brute sinon
            # (`bg`, qui passe par `fond(pour:)`, ou `rose`, qui passe par `AccentTheme`).
            une = valeur(corps)
            trouves[nom] = {"clair": une, "sombre": une}
    for nom, hexa in _LET.findall(source):
        trouves[nom] = {"clair": int(hexa, 16), "sombre": int(hexa, 16)}

    # ── UN JETON PEUT NOMMER UN AUTRE JETON ──────────────────────────────────────────────────
    #
    # `lime` valait `isLight ? Color(hex: 0x6B9E00) : Color(hex: 0xC8FF3D)`. La carte de nuit a
    # eu besoin de la variante sombre SANS la branche de thème — une couleur sémantique posée sur
    # `#14131E` doit être celle du mode sombre, quel que soit le thème de la page. Plutôt que de
    # recopier la valeur, `Colors.swift` l'a nommée : `static let limeSombre`, que `lime` lit.
    #
    # Sans cette résolution, `declarations()` rendait la CHAÎNE « limeSombre » pour la branche
    # sombre de six jetons, et `check_design.py` a refusé la table de DESIGN.md — à juste titre :
    # il ne pouvait plus vérifier ce que le document annonçait. Une seule indirection suffit, et
    # c'est volontaire : au-delà, une couleur se lit par chaînage et ce fichier redevient un
    # interpréteur.
    for nom, branches in trouves.items():
        for theme, v in branches.items():
            if isinstance(v, str) and isinstance(trouves.get(v, {}).get(theme), int):
                branches[theme] = trouves[v][theme]
    return trouves


def fond_neutre(theme: str) -> int:
    """Le neutre de `RUColor.fond(pour:)`, lu dans la source.

    `bg` n'est pas une constante : c'est ce neutre, sur lequel l'habillage « teinté » mélange une
    part de l'accent. Trois gardes et un script de montage en portaient chacun une copie en dur,
    et le jour où le fond clair est passé du froid au chaud, les quatre auraient continué à
    décrire l'ancien.
    """
    src = sans_commentaires(COULEURS.read_text(encoding="utf-8"))
    m = re.search(r"let neutre = isLight \? Color\(hex: (0x[0-9A-Fa-f]{6})\) : "
                  r"Color\(hex: (0x[0-9A-Fa-f]{6})\)", src)
    if not m:
        raise SystemExit("couleurs.fond_neutre : `fond(pour:)` ne se lit plus dans Colors.swift.")
    return int(m.group(1 if theme == "clair" else 2), 16)


def fonds(theme: str) -> dict:
    """Les cinq fonds d'un thème : les quatre surfaces, plus une borne du fond teinté.

    La borne évite de rejouer la recherche dichotomique d'`AccentTheme` — ce serait écrire sa
    règle une deuxième fois. Mélanger une part de n'importe quelle couleur dans le neutre ne peut
    pas l'assombrir plus que la même part de NOIR PUR, et c'est le pire cas pour du texte sombre ;
    en sombre, du BLANC PUR donne le fond le plus clair, donc le pire cas pour du texte clair.
    """
    jetons = declarations()
    sortie = {"bg": fond_neutre(theme)}
    for nom in ("bg2", "card", "card2"):
        valeur = jetons[nom][theme]
        if isinstance(valeur, int):
            sortie[nom] = valeur
    pire = 0x000000 if theme == "clair" else 0xFFFFFF
    sortie["bg teinté (borne)"] = melange(pire, sortie["bg"], PART_TEINTE[theme])
    return sortie


def accents(chemin: pathlib.Path = None) -> dict:
    """Les nuanciers d'`AccentTheme.swift` : `{id: (primary, light, tail)}`, en sombre.

    Les valeurs CLAIRES ne sont pas lues : elles sortent d'une recherche dichotomique
    (`meetingContrastOnWhite`), et les rejouer ici serait écrire sa règle une deuxième fois. Les
    gardes qui ont besoin du fond clair teinté en prennent une BORNE — voir
    `check_jetons_de_texte.py`.
    """
    chemin = chemin or (RACINE / "RunUp/DesignSystem/AccentTheme.swift")
    # `sans_commentaires_seuls` et non `sans_commentaires` : l'identité d'un nuancier est dans une
    # chaîne (`id: "rose"`), et la variante stricte l'efface — le lecteur ne saurait plus de quel
    # nuancier il lit les trois valeurs.
    src = sans_commentaires_seuls(chemin.read_text(encoding="utf-8"))
    sortie = {}
    for ligne in src.splitlines():
        m = re.search(r'AccentTheme\(id: "([a-z]+)", name: "[^"]*", (.*)\)', ligne)
        if not m:
            continue
        hexs = [int(h, 16) for h in _HEX.findall(m.group(2))]
        if len(hexs) == 3:
            sortie[m.group(1)] = tuple(hexs)
    return sortie


# ── LE CONTRASTE ─────────────────────────────────────────────────────────────────────────────

def _srgb(c: int) -> float:
    v = c / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(couleur: int) -> float:
    r, v, b = (couleur >> 16) & 255, (couleur >> 8) & 255, couleur & 255
    return 0.2126 * _srgb(r) + 0.7152 * _srgb(v) + 0.0722 * _srgb(b)


def contraste(a: int, b: int) -> float:
    la, lb = luminance(a), luminance(b)
    haut, bas = max(la, lb), min(la, lb)
    return (haut + 0.05) / (bas + 0.05)


def melange(couleur: int, sur: int, part: float) -> int:
    """`part` de `couleur` sur `sur`, PAR LES COMPOSANTES — la formule de `RUColor.melange`."""
    sortie = 0
    for decalage in (16, 8, 0):
        a, b = (couleur >> decalage) & 255, (sur >> decalage) & 255
        sortie |= round(a * part + b * (1 - part)) << decalage
    return sortie


def famille(couleur: int) -> tuple:
    """`(bleu − rouge, vert − rouge)` : la signature de famille d'une couleur.

    Les fonds de l'app penchent vers le violet de l'accent. Un gris neutre posé dessus prend l'air
    sale — la règle est écrite au-dessus de `RUColor.bg`. Cette fonction donne de quoi la
    vérifier.
    """
    r, v, b = (couleur >> 16) & 255, (couleur >> 8) & 255, couleur & 255
    return (b - r, v - r)
