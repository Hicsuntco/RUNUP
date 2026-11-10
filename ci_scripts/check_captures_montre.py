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

#: La bande basse qui doit rester VIERGE. Deux pour cent de 496 font dix pixels, soit cinq points
#: — une marge minuscule, et c'est voulu : on ne juge pas une mise en page, on constate qu'elle
#: n'est pas TRANCHÉE par le bord.
BANDE_BASSE = 0.02

#: Au-dessus de quelle valeur un pixel compte comme encré. Le fond de la montre est noir ; 40 sur
#: 255 laisse passer le bruit de compression et attrape tout texte, même gris.
SEUIL_ENCRE = 40

NOM = "1-course-libre.png"


def empreinte_du_contenu(chemin: pathlib.Path) -> str:
    """L'empreinte de ce qu'il y a SOUS la barre d'état."""
    image = Image.open(chemin).convert("RGB")
    sous = image.crop((0, int(image.height * BANDE_HAUTE), image.width, image.height))
    return hashlib.sha256(sous.tobytes()).hexdigest()[:12]


def lignes_encrees_au_bord(chemin: pathlib.Path) -> int:
    """Combien de lignes de pixels portent de l'encre dans la bande basse.

    # POURQUOI CETTE RÈGLE EXISTE

    Ce contrôle savait dire que trois langues rendaient la même image. Il ne savait pas dire que
    les trois étaient COUPÉES — et elles l'étaient. Mesuré le 10 novembre 2026 sur la capture
    exigée par l'App Store : les onze dernières lignes de pixels portaient de l'encre, jusqu'à la
    toute dernière, dans les trois langues. « Cours à ta sensation — ta séance arrive de
    l'iPhone. » était tranchée en deux par le bord bas de l'écran.

    L'anneau décoratif du bouton occupait 118 points sur les 248 de la montre, et poussait dehors
    la seule phrase de l'écran. L'écran est dans un `ScrollView`, donc la phrase était
    atteignable en faisant défiler — sur une montre, sous un bouton géant. Autant dire jamais.

    # CE QU'ELLE NE DIT PAS

    Elle ne juge aucune mise en page : du texte peut légitimement s'approcher du bord. Elle
    constate seulement qu'au REPOS — et une capture est prise au repos — rien n'est tranché par
    l'arête. C'est une question à laquelle une image répond sans ambiguïté, contrairement à
    « est-ce joli ».
    """
    image = Image.open(chemin).convert("RGB")
    debut = image.height - max(1, int(image.height * BANDE_BASSE))
    pixels = image.load()
    encrees = 0
    for y in range(debut, image.height):
        if any(max(pixels[x, y]) > SEUIL_ENCRE for x in range(image.width)):
            encrees += 1
    return encrees


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
    coupees: list[tuple[str, int]] = []
    for chemin in captures:
        langue = chemin.parent.name
        empreinte = empreinte_du_contenu(chemin)
        bord = lignes_encrees_au_bord(chemin)
        print(f"    {langue} : {empreinte}" + (f"  ⟵ {bord} ligne(s) encrées au bord" if bord else ""))
        if bord:
            coupees.append((langue, bord))
        if empreinte in vues:
            doublons.append((vues[empreinte], langue))
        else:
            vues[empreinte] = langue

    if coupees:
        for langue, bord in coupees:
            print(f"✗ {langue} : {bord} ligne(s) de pixels encrées jusqu'au bord bas — "
                  f"quelque chose est TRANCHÉ par l'arête de l'écran.")
        print("\n    Une capture est prise au repos. Ce qui touche le bord au repos est coupé,")
        print("    et sur la montre c'est la seule phrase de l'écran qui l'était — dans les")
        print("    trois langues, et sur l'image qu'Apple publie.")
        return 1

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
