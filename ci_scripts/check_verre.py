#!/usr/bin/env python3
"""Refuse le verre dépoli dans l'interface. Règle 7, deuxième moitié.

# LA RÈGLE

Le brief dit « pas de glassmorphism ». Un `Material` de SwiftUI est exactement ça : un flou de ce
qu'il y a derrière, plus une teinte.

# CE QUE LE DÉPÔT EN FAISAIT, ET CE QUE LA MESURE A MONTRÉ

Douze emplois dans sept fichiers. Contrairement aux dégradés, AUCUN jeton ne les distribuait :
chaque écran écrivait `.ultraThinMaterial` à la main. C'étaient donc douze décisions, et il a
fallu les lire une par une.

Quatre d'entre elles ne floutaient presque rien. La barre d'onglets empilait un
`.ultraThinMaterial` à 90 % DEVANT une carte à 92 % : le flou ne captait que 8 % de la page. Le
sélecteur de discipline faisait pareil avec une carte à 96 %, deux fois. Une couche de
composition de plus sur l'écran le plus vu de l'app, pour un effet que personne ne peut nommer.

Trois autres étaient posées sur une carte MapKit, et leur contraste dépendait donc de ce qui
défilait dessous. La bulle du coach portait quinze lignes d'arithmétique pour cette raison : il
avait fallu monter son fond à 92 % d'opacité pour que le sourcil « Coach · en direct » tienne
4,5:1 sur une carte claire. Avec un fond opaque, le calcul ne dépend plus de rien et la palette
la plus basse gagne un point entier.

# CE QU'IL VÉRIFIE

Aucun `Material` nulle part. La liste d'exceptions est VIDE, et c'est l'état qu'on veut : elle
existe pour qu'une exception future soit écrite avec sa raison, comme celles de
`check_degrade.py`, plutôt que glissée dans un écran.

Si tu ajoutes une entrée ici, écris POURQUOI un flou fait quelque chose qu'un aplat ne fait pas.
Dans les douze cas de ce dépôt, la réponse était « rien ».

# CE QU'IL NE VOIT PAS

Un flou fabriqué autrement : `UIVisualEffectView` par un pont UIKit, un `.blur(radius:)` sur une
copie du fond. Ce script lit du texte Swift ; ce qui se voit à l'œil se voit sur une capture.
"""
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
CIBLES = ["RunUp", "RunUpWatch", "RunUpWidgets"]

# Les cinq épaisseurs nommées, le type lui-même, et `.bar` — mais `.bar` seulement là où une
# forme ou un fond l'attend, sinon `chart.bar.fill` et `RUSpacing.tabBarHeight` sonneraient.
VERRE = re.compile(
    r"\b(ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial|ultraThickMaterial)\b|"
    r"\bMaterial\s*\.|"
    r"\b(?:background|fill|foregroundStyle|tint)\s*\(\s*\.bar\b")

#: fichier → (nombre de flous autorisés, pourquoi). Vide, et c'est voulu.
PERMIS: dict[str, tuple[int, str]] = {}


def sans_commentaires(source: str) -> str:
    """Le code seul : ni `//`, ni `/* */`, ni le contenu des chaînes.

    Même raison que dans `check_degrade.py` : la moitié des fichiers de ce chantier NOMMENT le
    verre dépoli dans le commentaire qui raconte son départ. Les compter serait refuser un
    fichier pour la phrase qui explique sa correction.
    """
    out, i, n = [], 0, len(source)
    while i < n:
        c = source[i]
        if c == "/" and i + 1 < n and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and source[i + 1] == "*":
            i += 2
            while i + 1 < n and not (source[i] == "*" and source[i + 1] == "/"):
                i += 1
            i += 2
        elif c == '"':
            out.append(" ")
            i += 1
            while i < n and source[i] != '"':
                i += 2 if source[i] == "\\" else 1
            i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def releve(racine=RACINE):
    """fichier (relatif) → nombre de flous dans son code."""
    compte = {}
    for cible in CIBLES:
        dossier = racine / cible
        if not dossier.is_dir():
            continue
        for f in sorted(dossier.rglob("*.swift")):
            n = len(VERRE.findall(sans_commentaires(f.read_text(encoding="utf-8"))))
            if n:
                compte[f.relative_to(racine).as_posix()] = n
    return compte


def verifier(racine=RACINE, permis=None):
    permis = PERMIS if permis is None else permis
    compte = releve(racine)
    plaintes = []
    for fichier, n in sorted(compte.items()):
        if fichier not in permis:
            plaintes.append(
                f"{fichier} : {n} verre(s) dépoli(s). La règle 7 l'interdit — pose une surface "
                f"opaque, ou ajoute ce fichier à `PERMIS` en écrivant ce qu'un flou fait ici "
                f"qu'un aplat ne ferait pas.")
            continue
        attendu, _ = permis[fichier]
        if n != attendu:
            plaintes.append(
                f"{fichier} : {n} verre(s), {attendu} autorisé(s). "
                + ("Un de plus que ce que la raison couvre." if n > attendu
                   else "Un de moins : l'exception a servi, elle ne sert plus. Retire-la."))
    for fichier in sorted(permis):
        if fichier not in compte:
            plaintes.append(
                f"{fichier} : plus aucun verre dépoli, mais le fichier est encore dans `PERMIS`. "
                f"Une exception qui dort finit par servir à autre chose.")
    return plaintes


def main():
    plaintes = verifier()
    for p in plaintes:
        print(f"✗ {p}")
    if plaintes:
        print(f"\n{len(plaintes)} problème(s). La règle et les exceptions sont en tête de "
              f"ci_scripts/check_verre.py.")
        return 1
    if PERMIS:
        total = sum(n for n, _ in PERMIS.values())
        print(f"✓ Aucun verre dépoli hors des {total} autorisés dans {len(PERMIS)} fichiers.")
    else:
        print("✓ Aucun verre dépoli nulle part, et aucune exception.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
