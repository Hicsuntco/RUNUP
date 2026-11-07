#!/usr/bin/env python3
"""Le réglage de taille du texte a-t-il VRAIMENT pris sur les captures en grand texte ?

# POURQUOI CE CONTRÔLE EXISTE

`RUFont` plafonne la croissance du texte à 2,0 ×, et ce plafond a été relevé de 1,6 × sur la foi
d'un travail de réorganisation : rangées de mesures qui passent en colonne, bande des sept jours
qui laisse tomber le quantième, barre d'onglets qui laisse tomber ses libellés. Tout cela est
écrit, commenté — et n'a jamais été PHOTOGRAPHIÉ. Quatre captures le montrent maintenant.

Reste qu'une capture verte ne prouve que deux choses : l'app n'a pas planté, et un fichier a été
écrit. Elle ne dit rien de ce qu'il y a dessus. Si `-UIPreferredContentSizeCategoryName` cessait
d'être lu — un renommage chez Apple, un drapeau mal orthographié — les quatre images seraient des
copies des captures ordinaires, le harnais resterait vert, et on croirait avoir vu l'app en grand
texte. C'est exactement la forme du défaut qui a laissé passer trois films d'aperçu faux.

# CE QUI EST MESURÉ

L'écart moyen, pixel à pixel en gris, entre chaque capture en grand texte et la MÊME capture en
taille ordinaire. Du texte 1,94 × plus grand déplace une grande partie de l'image ; deux captures
du même écran à la même taille ne diffèrent que par l'heure affichée.

Sans `--plancher`, on mesure et on se tait : c'est l'état voulu tant qu'on n'a pas de relevé.
"""
import argparse
import pathlib
import sys

from PIL import Image, ImageChops, ImageStat

#: capture en grand texte → la même en taille ordinaire, dans le dossier d'une langue.
PAIRES = {
    "diagnostic/grand-texte/accueil.png": "1-accueil.png",
    "diagnostic/grand-texte/stats.png": "6-stats.png",
    "diagnostic/grand-texte/course-en-cours.png": "diagnostic/course-en-cours.png",
    "diagnostic/grand-texte/bilan-hebdo.png": "diagnostic/bilan-hebdo.png",
}


def gris(chemin: pathlib.Path) -> Image.Image:
    with Image.open(chemin) as im:
        return im.convert("L").copy()


def ecart(grand: pathlib.Path, ordinaire: pathlib.Path) -> float:
    a, b = gris(grand), gris(ordinaire)
    if a.size != b.size:
        # Deux tailles d'écran voudraient dire deux simulateurs : ce n'est pas ce qu'on mesure.
        raise SystemExit(f"{grand.name} et {ordinaire.name} n'ont pas la même taille "
                         f"({a.size} contre {b.size}).")
    return ImageStat.Stat(ImageChops.difference(a, b)).mean[0]


def main() -> int:
    a = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--dossier", type=pathlib.Path, required=True,
                   help="Le dossier d'une langue (appstore/raw/<langue>)")
    a.add_argument("--plancher", type=float, default=None,
                   help="Écart moyen en dessous duquel on échoue. Sans lui, on mesure "
                        "et on se tait.")
    options = a.parse_args()

    mesures = []
    manquantes = []
    for grand, ordinaire in PAIRES.items():
        chemin_grand = options.dossier / grand
        chemin_ordinaire = options.dossier / ordinaire
        if not chemin_grand.is_file() or not chemin_ordinaire.is_file():
            manquantes.append(grand if not chemin_grand.is_file() else ordinaire)
            continue
        mesures.append((grand, ecart(chemin_grand, chemin_ordinaire)))

    for nom, valeur in mesures:
        print(f"  {valeur:6.2f}  {nom}")

    if manquantes:
        print(f"\n{len(manquantes)} capture(s) absente(s) — il n'y a rien à comparer :",
              file=sys.stderr)
        for nom in manquantes:
            print(f"  {nom}", file=sys.stderr)
        return 1

    if options.plancher is None:
        print("\n(aucun plancher demandé : on mesure et on se tait)")
        return 0

    plates = [(nom, valeur) for nom, valeur in mesures if valeur < options.plancher]
    if plates:
        print(f"\n{len(plates)} capture(s) en grand texte ressemblent à la capture ORDINAIRE :\n",
              file=sys.stderr)
        for nom, valeur in plates:
            print(f"  {nom} — écart {valeur:.2f}, plancher {options.plancher:.2f}", file=sys.stderr)
        print("\nLe réglage de taille du texte n'a pas pris. Le drapeau est",
              file=sys.stderr)
        print("`-UIPreferredContentSizeCategoryName` dans `CapturesUITests.prendre` ; le lire est",
              file=sys.stderr)
        print("l'affaire de `TextSizeStore`. Les images existent et ne montrent pas ce qu'elles",
              file=sys.stderr)
        print("annoncent, ce qui est pire que de ne pas les avoir.", file=sys.stderr)
        return 1

    print(f"\nLes {len(mesures)} captures en grand texte diffèrent toutes de leur ordinaire "
          f"(plancher {options.plancher:.2f}) ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
