#!/usr/bin/env python3
"""Un nombre à virgule affiché sans `locale:` s'écrit avec un POINT, dans les trois langues.

# LE DÉFAUT

`String(format: "%.1f", km)` n'est pas neutre : sans argument `locale:`, `String(format:)` ne
localise rien et pose le séparateur décimal anglais. « 12.4 km » s'affiche donc tel quel en
français et en espagnol, deux langues qui écrivent « 12,4 ».

Ce n'est pas une faute de goût : un chiffre est ce que cette app affiche de plus souvent, et le
point décimal est le genre de détail qui fait dire « ça n'a pas été fait ici ». Quatorze des seize
appels du dépôt passaient bien `locale: Locale.current` — deux l'avaient oublié : la tuile
« Dernière sortie » de l'écran du coach, et la progression des badges semi-marathon et marathon.
Un contrôle, parce que la bonne version et la mauvaise se ressemblent trop pour se relire.

# CE QUI EST REGARDÉ, ET CE QUI NE L'EST PAS

Seuls les formats à DÉCIMALES (`%.1f`, `%.2f`, `%f`, `%g`) : ce sont les seuls où un séparateur
apparaît. `%.0f` n'en montre aucun, et `%02d`, `%04d`, `%02x` sont des formats TECHNIQUES — un
chrono « 7:05 », une date de fichier, un jeton en hexadécimal. Ceux-là doivent justement rester
sans `locale:` : une virgule décimale dans un `%02x` serait un bug, pas une correction.
"""

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ["RunUp", "RunUpWidgets", "RunUpWatch"]

# `String(format:` suivi, dans la même chaîne de format, d'un marqueur à décimales.
APPEL = re.compile(r'String\(\s*format:\s*"((?:[^"\\]|\\.)*)"([^)]*)')
DECIMALES = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[fgeFGE]")
SANS_DECIMALE = re.compile(r"%[-+ 0#]*\d*\.0[fF]")


def sans_commentaires(source: str) -> str:
    sortie, i, n, bloc = [], 0, len(source), 0
    while i < n:
        if bloc:
            if source.startswith("/*", i):
                bloc += 1; i += 2
            elif source.startswith("*/", i):
                bloc -= 1; i += 2
            else:
                sortie.append("\n" if source[i] == "\n" else " "); i += 1
            continue
        if source.startswith("/*", i):
            bloc = 1; sortie.append("  "); i += 2
        elif source.startswith("//", i):
            while i < n and source[i] != "\n":
                sortie.append(" "); i += 1
        else:
            sortie.append(source[i]); i += 1
    return "".join(sortie)


def problemes() -> list:
    erreurs = []
    for dossier in DOSSIERS:
        base = RACINE / dossier
        if not base.is_dir():
            continue
        for fichier in sorted(base.rglob("*.swift")):
            source = sans_commentaires(fichier.read_text(encoding="utf-8"))
            for m in APPEL.finditer(source):
                format_, suite = m.group(1), m.group(2)
                # `%.0f` ne montre pas de séparateur : il n'a rien à localiser.
                marqueurs = [x for x in DECIMALES.findall(format_)
                             if not SANS_DECIMALE.fullmatch(x)]
                if not marqueurs:
                    continue
                if "locale:" in suite:
                    continue
                ligne = source[:m.start()].count("\n") + 1
                erreurs.append(
                    f"{fichier.relative_to(RACINE).as_posix()}:{ligne} formate "
                    f"« {format_} » sans `locale:` — le séparateur décimal sera un point en "
                    f"français et en espagnol. Ajoute `locale: Locale.current`"
                )
    return erreurs


def main() -> int:
    erreurs = problemes()
    if erreurs:
        print("Des nombres à virgule sont formatés sans locale :\n")
        for e in erreurs:
            print(f"  ✗ {e}")
        print("\n« 12,4 km » en français, « 12.4 km » en anglais — c'est `locale:` qui décide.")
        return 1
    print("Décimales : tous les formats à virgule passent par la locale ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
