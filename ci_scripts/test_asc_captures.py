#!/usr/bin/env python3
"""Ce que `asc.py push-screenshots` décide SANS parler à Apple.

Le reste de la commande est du réseau et ne se teste pas ici. Mais trois décisions se prennent
avant le premier appel, et chacune se trompe en silence :

  — la TAILLE lue dans l'image, qui décide du type d'appareil sous lequel la capture est rangée ;
  — l'ORDRE des fichiers, qui décide de quelle accroche se retrouve sur quelle image ;
  — le refus d'une taille inconnue, qui doit arrêter la commande au lieu de deviner.

Une image rangée sous le mauvais appareil n'échoue pas : elle apparaît au mauvais endroit dans
la fiche, et on le découvre en la regardant.
"""

import pathlib
import sys
import tempfile

import asc

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f)); return f
    return prendre


def png(largeur, hauteur) -> bytes:
    """Un en-tête PNG valide. `taille_png` ne lit que les 24 premiers octets."""
    return (b"\x89PNG\r\n\x1a\n" + (13).to_bytes(4, "big") + b"IHDR"
            + largeur.to_bytes(4, "big") + hauteur.to_bytes(4, "big"))


@cas_test("la taille se lit dans l'en-tête, sans Pillow")
def _():
    with tempfile.TemporaryDirectory() as d:
        f = pathlib.Path(d) / "1.png"
        f.write_bytes(png(1290, 2796))
        assert asc.taille_png(f) == (1290, 2796), asc.taille_png(f)


@cas_test("ce que produit screenshots.py est un iPhone 6,7 pouces")
def _():
    # 1290 × 2796 est la taille que `screenshots.py` compose. Si elle cessait d'être connue
    # d'Apple, la commande s'arrêterait — et ce test le dirait avant.
    assert asc.TYPES_PAR_TAILLE[(1290, 2796)] == "APP_IPHONE_67"


@cas_test("la taille brute du simulateur est un 6,9 pouces, et pas la même")
def _():
    # Les captures BRUTES font 1320 × 2868. Les envoyer telles quelles les rangerait sous un
    # autre appareil que les composées — deux séries, deux catégories, dans la même fiche.
    assert asc.TYPES_PAR_TAILLE[(1320, 2868)] == "APP_IPHONE_69"
    assert asc.TYPES_PAR_TAILLE[(1320, 2868)] != asc.TYPES_PAR_TAILLE[(1290, 2796)]


@cas_test("une taille inconnue n'est pas devinée")
def _():
    assert (1000, 1000) not in asc.TYPES_PAR_TAILLE


@cas_test("un fichier qui n'est pas un PNG arrête la commande")
def _():
    with tempfile.TemporaryDirectory() as d:
        f = pathlib.Path(d) / "pas-une-image.png"
        f.write_bytes(b"GIF89a" + b"\x00" * 40)
        try:
            asc.taille_png(f)
        except SystemExit:
            return
        raise AssertionError("un GIF déguisé en .png est passé")


@cas_test("2 passe avant 10, et 1 reste premier")
def _():
    noms = ["10.png", "2.png", "1.png", "6.png"]
    assert sorted(noms, key=asc.ordre_naturel) == ["1.png", "2.png", "6.png", "10.png"]


@cas_test("l'ordre tient aussi sur les noms des brutes")
def _():
    noms = ["6-stats.png", "1-accueil.png", "2-plan.png"]
    assert sorted(noms, key=asc.ordre_naturel)[0] == "1-accueil.png"


@cas_test("toutes les tailles connues sont des entiers positifs vers un type Apple")
def _():
    for (l, h), type_ in asc.TYPES_PAR_TAILLE.items():
        assert l > 0 and h > 0, (l, h)
        assert type_.startswith("APP_IPHONE_") or type_.startswith("APP_IPAD_"), type_


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f(); print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1; print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
