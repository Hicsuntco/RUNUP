#!/usr/bin/env python3
"""Deux jeux de captures, le même écran : qu'est-ce qui a bougé entre les deux ?

# POURQUOI CE CONTRÔLE EXISTE

`ClubView.swift` fait 2721 lignes et porte 30 états. Le découper est le chantier 13, et un
découpage est par définition un changement qui ne doit RIEN changer à l'écran. Rien ne le
vérifie aujourd'hui : les quatre captures du Club — le mur, l'aperçu, le bas de l'aperçu, le
classement — passent au vert si l'app n'a pas planté et qu'un fichier a été écrit. Elles ne
disent pas que l'image est la même qu'avant. Un bloc oublié dans le déplacement, une carte
qui perd son `padding`, une liste qui perd son tri : harnais vert, écran faux.

Le même manque se représentera à chaque réorganisation d'un écran photographié. D'où un outil
et non un contrôle de plus : on lui donne les captures d'avant et celles d'après, il dit ce qui
a bougé, et il garde l'image de la différence pour qu'on puisse la regarder.

# CE QUI EST MESURÉ

L'écart pixel à pixel en gris, image par image, entre deux dossiers de même forme.

LA BARRE D'ÉTAT EST MASQUÉE, parce qu'elle porte l'heure : deux prises du même écran à deux
minutes d'intervalle n'ont jamais exactement la même image, et une comparaison qui compte ce
pixel-là ne peut rien dire. Le masque vaut 6,5 % de la hauteur — 181 px sur les 2796 de
l'iPhone 15 Pro Max, pour une barre qui en fait 162. Ce qui est masqué n'est pas mesuré : si
un défaut ne vit QUE sous l'heure, cet outil ne le verra pas, et il n'y a pas de place à
RUNUP pour un écran dont le haut n'est que la barre d'état.

Pour chaque image, trois nombres : l'écart MOYEN sur toute la surface mesurée, le nombre de
pixels qui diffèrent de plus de `--bruit`, et le cadre qui les contient. Le cadre est ce qui
sert : « 0,02 de moyenne » ne dit pas où, « un rectangle de 40 px de haut à 1200 px du bord »
désigne un bloc.

Sans `--plafond`, on mesure et on se tait. Avec, on échoue au-delà — c'est la forme voulue
pour un découpage, où le plafond est zéro à la tolérance de bruit près.

# LE RELEVÉ QUI DIT POURQUOI LA MOYENNE NE SUFFIT PAS

Mesuré sur les captures réelles du Club, en comparant le FRANÇAIS à l'ESPAGNOL — c'est-à-dire
tout le texte de l'écran changé, le pire cas qu'un découpage puisse produire :

    écran                  moyenne   pixels au-delà du bruit
    4-club                   3,41        104 877
    club-apercu              5,55        152 484
    club-apercu-bas          3,43         90 973
    club-classement          4,10        130 152
    (et les quatre mêmes en thème clair : 3,77 à 5,99)

Tout le texte d'un écran remplacé déplace la moyenne de QUATRE POINTS sur 255. Un plafond posé
pour « tolérer le rendu d'un dégradé » — disons 5 — laisserait donc passer la moitié de ces
cas-là. Le compte de pixels, lui, passe de 0 à cent mille.

Et le même dossier comparé à lui-même rend 0,000 et zéro pixel : il n'y a pas de bruit de fond
à soustraire entre deux captures du même état, une fois l'heure masquée.
"""
import argparse
import pathlib
import sys

from PIL import Image, ImageChops, ImageStat

#: Hauteur masquée, en fraction de la hauteur de l'image. Voir l'en-tête : la barre d'état
#: porte l'heure, et l'heure change entre deux prises.
HAUT_MASQUE = 0.065


def gris(chemin: pathlib.Path, haut: float) -> Image.Image:
    """L'image en gris, barre d'état coupée."""
    with Image.open(chemin) as im:
        plan = im.convert("L")
        debut = int(round(plan.height * haut))
        return plan.crop((0, debut, plan.width, plan.height)).copy()


def differences(avant: pathlib.Path, apres: pathlib.Path, haut: float, bruit: int):
    """(écart moyen, pixels différents, cadre qui les contient, image de la différence)."""
    a, b = gris(avant, haut), gris(apres, haut)
    if a.size != b.size:
        # Deux tailles voudraient dire deux simulateurs : ce n'est pas ce qu'on compare.
        raise SystemExit(f"{avant.name} : {a.size} avant, {b.size} après. "
                         f"Deux tailles d'écran ne se comparent pas.")
    ecart = ImageChops.difference(a, b)
    moyenne = ImageStat.Stat(ecart).mean[0]
    # `point` rend un masque : au-dessus du bruit, blanc ; en dessous, noir. `getbbox` sur ce
    # masque donne le cadre des pixels qui comptent, et non celui du moindre frémissement JPEG.
    marque = ecart.point(lambda v: 255 if v > bruit else 0)
    comptes = marque.histogram()
    return moyenne, comptes[255], marque.getbbox(), ecart


def images(dossier: pathlib.Path) -> dict[str, pathlib.Path]:
    return {str(p.relative_to(dossier)): p for p in sorted(dossier.rglob("*.png"))}


def main() -> int:
    a = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--avant", type=pathlib.Path, required=True,
                   help="Le dossier des captures d'avant le changement")
    a.add_argument("--apres", type=pathlib.Path, required=True,
                   help="Le dossier des captures d'après, de même forme")
    a.add_argument("--seulement", action="append", default=None,
                   help="Ne comparer que les images dont le chemin contient ce texte. "
                        "Répétable : --seulement club --seulement profil")
    a.add_argument("--bruit", type=int, default=8,
                   help="Un pixel ne compte comme différent qu'au-delà de cet écart de gris "
                        "(0-255). 8 par défaut : le rendu d'un dégradé n'est pas au pixel près "
                        "d'une prise à l'autre, et on ne veut pas compter ce frémissement.")
    a.add_argument("--plafond", type=float, default=None,
                   help="Écart moyen au-delà duquel on échoue. Sans lui, on mesure et on se "
                        "tait. Pour un découpage qui ne doit rien changer : --plafond 0.5")
    a.add_argument("--pixels", type=int, default=None,
                   help="Nombre de pixels différents au-delà duquel on échoue. Complète "
                        "--plafond : une moyenne reste basse quand un petit bloc change du "
                        "tout au tout, et c'est ce cas-là qui compte pour un découpage.")
    a.add_argument("--haut", type=float, default=HAUT_MASQUE,
                   help=f"Fraction de la hauteur masquée en haut (barre d'état). "
                        f"{HAUT_MASQUE} par défaut.")
    a.add_argument("--sortie", type=pathlib.Path, default=None,
                   help="Dossier où garder l'image de la différence, pour les seules images "
                        "qui diffèrent. Sans lui, on ne garde rien.")
    options = a.parse_args()

    for dossier in (options.avant, options.apres):
        if not dossier.is_dir():
            raise SystemExit(f"{dossier} n'est pas un dossier.")

    gauche, droite = images(options.avant), images(options.apres)
    if options.seulement:
        def garde(nom: str) -> bool:
            return any(motif in nom for motif in options.seulement)
        gauche = {n: p for n, p in gauche.items() if garde(n)}
        droite = {n: p for n, p in droite.items() if garde(n)}

    if not gauche:
        raise SystemExit(f"Aucune image à comparer dans {options.avant}"
                         + (f" pour {options.seulement}." if options.seulement else "."))

    # UNE IMAGE QUI DISPARAÎT EST UN DÉFAUT, pas un silence. Un écran qui ne se photographie
    # plus — parce que le test ne le trouve plus après le découpage — laisserait une
    # comparaison vide et verte si on ne regardait que l'intersection.
    manquantes = sorted(set(gauche) - set(droite))
    nouvelles = sorted(set(droite) - set(gauche))

    print(f"{len(gauche)} image(s) d'avant, {len(droite)} d'après, "
          f"barre d'état masquée sur {options.haut:.1%} de la hauteur, "
          f"bruit toléré {options.bruit}/255")
    print()

    pire_moyenne, pire_pixels, fautives = 0.0, 0, []
    for nom in sorted(set(gauche) & set(droite)):
        moyenne, pixels, cadre, ecart = differences(gauche[nom], droite[nom],
                                                    options.haut, options.bruit)
        pire_moyenne = max(pire_moyenne, moyenne)
        pire_pixels = max(pire_pixels, pixels)
        if pixels == 0:
            print(f"  = {nom}")
            continue
        fautives.append(nom)
        ou = (f"cadre x {cadre[0]}–{cadre[2]}, y {cadre[1]}–{cadre[3]} "
              f"(hors barre d'état)") if cadre else "aucun cadre"
        print(f"  ≠ {nom} : moyenne {moyenne:.3f}, {pixels} pixel(s) au-delà du bruit, {ou}")
        if options.sortie:
            options.sortie.mkdir(parents=True, exist_ok=True)
            cible = options.sortie / nom.replace("/", "-")
            ecart.save(cible)
            print(f"      différence gardée : {cible}")

    for nom in manquantes:
        print(f"  ✗ {nom} : photographiée avant, absente après.")
    for nom in nouvelles:
        print(f"  + {nom} : absente avant, photographiée après.")

    print()
    print(f"ÉCART MAXIMAL={pire_moyenne:.3f} PIXELS={pire_pixels} "
          f"IMAGES_DIFFERENTES={len(fautives)} MANQUANTES={len(manquantes)}")

    if manquantes:
        print("\nUne image photographiée avant et absente après : le test ne trouve plus "
              "l'écran. C'est un défaut, pas une amélioration.", file=sys.stderr)
        return 1
    if options.plafond is not None and pire_moyenne > options.plafond:
        print(f"\nÉcart moyen {pire_moyenne:.3f} au-delà du plafond {options.plafond}.",
              file=sys.stderr)
        return 1
    if options.pixels is not None and pire_pixels > options.pixels:
        print(f"\n{pire_pixels} pixels différents, au-delà des {options.pixels} admis.",
              file=sys.stderr)
        return 1
    if options.plafond is None and options.pixels is None:
        print("Aucun plafond demandé : on a mesuré, on ne juge pas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
