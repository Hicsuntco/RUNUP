#!/usr/bin/env python3
"""Trois langues ne doivent pas rendre la même capture de montre.

# POURQUOI CE CONTRÔLE EXISTE, ET POURQUOI IL A DÉJÀ ÉTÉ FAUX UNE FOIS

L'étape qui photographie la montre vérifie qu'un PNG d'au moins cinq kilo-octets est sorti. Ça dit
qu'un écran a été dessiné. Ça ne dit pas LEQUEL — et deux exécutions ont produit trois fichiers
parfaitement valides, tous les trois en français, sans que rien ne rougisse.

La première parade comparait les empreintes des FICHIERS ENTIERS. Elle est passée au vert sur
trois captures dont deux étaient mot pour mot en français : la barre d'état porte l'heure, elle
avance entre deux captures, et deux images par ailleurs identiques ont donc des octets
différents. Le garde-fou mesurait l'horloge.

Il compare donc l'image SOUS la barre d'état. Dix-huit pour cent du haut écartés : la barre fait
46 points sur 496 chez Apple, le double de marge couvre les variations de modèle sans mordre sur
l'eyebrow « Aujourd'hui », qui commence au cinquième de la hauteur.

    PATH=/tmp/venv/bin:$PATH python3 ci_scripts/check_captures_montre.py appstore/raw-montre
"""
import argparse
import hashlib
import pathlib
import sys

from PIL import Image

#: La part haute écartée. La barre d'état de watchOS fait 46 px sur 496 — 9,3 %. Le double, pour
#: que l'heure n'entre jamais dans la comparaison quel que soit le boîtier.
BANDE_HAUTE = 0.18

NOM = "1-course-libre.png"


def empreinte_du_contenu(chemin: pathlib.Path) -> str:
    """L'empreinte de ce qu'il y a SOUS la barre d'état."""
    image = Image.open(chemin).convert("RGB")
    sous = image.crop((0, int(image.height * BANDE_HAUTE), image.width, image.height))
    return hashlib.sha256(sous.tobytes()).hexdigest()[:12]


def main() -> int:
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("dossier", help="le dossier qui porte un sous-dossier par langue")
    args = options.parse_args()

    racine = pathlib.Path(args.dossier)
    captures = sorted(racine.glob(f"*/{NOM}"))
    if len(captures) < 2:
        # UNE SEULE CAPTURE NE PROUVE RIEN, et rendre vert ici laisserait croire le contraire.
        print(f"{len(captures)} capture(s) dans {racine} : il en faut au moins deux à comparer.")
        return 1

    vues: dict[str, str] = {}
    doublons: list[tuple[str, str]] = []
    for chemin in captures:
        langue = chemin.parent.name
        empreinte = empreinte_du_contenu(chemin)
        print(f"    {langue} : {empreinte}")
        if empreinte in vues:
            doublons.append((vues[empreinte], langue))
        else:
            vues[empreinte] = langue

    if doublons:
        for premiere, seconde in doublons:
            print(f"✗ {premiere} et {seconde} rendent la MÊME image : la langue n'a pas pris.")
        print("\n    L'heure de la barre d'état est écartée de la comparaison, donc deux images")
        print("    déclarées identiques le sont vraiment.")
        return 1

    print(f"{len(captures)} captures de montre, {len(vues)} images distinctes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
