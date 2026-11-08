#!/usr/bin/env python3
"""Une bannière du système s'est-elle posée sur une capture ?

# POURQUOI CE CONTRÔLE EXISTE

Le 8 novembre 2026, une notification d'iOS — « Ready for Apple Intelligence », émise par Réglages
— est apparue en travers du haut de `1-accueil.png` en français. C'est UNE DES SIX IMAGES LIVRÉES
À APPLE. Sur l'image, on ne voit ni le prénom, ni la date, ni la série : on voit une bannière
grise qui parle d'autre chose, par-dessus l'app.

Rien ne pouvait l'attraper. Le test de capture était vert — l'app n'a pas planté et un fichier a
été écrit, c'est tout ce qu'il dit. Aucun contrôle ne regarde ces six images. Elle n'a été vue
qu'en comparant deux exécutions à la main, et par accident : je cherchais si un refactorisage
avait bougé un pixel.

Une capture d'écran qui montre l'interface du système est d'ailleurs un motif de refus chez Apple
avant même la question du goût. Et ici le harnais n'en publie rien tout seul — `appstore.yml` ne
part qu'au bouton — donc rien n'a été envoyé. La prochaine fois, c'est une question de minutage.

# CE QUI EST MESURÉ

La part de pixels CLAIRS dans la bande où iOS pose ses bannières : sous la barre d'état, sur
environ 13 % de la hauteur. En thème sombre, cette bande est noire ; une bannière est un bloc
gris clair qui barre toute la largeur.

Seules les captures SOMBRES sont regardées. Celles du dossier `clair/` sont claires par
construction, et la même mesure n'y voudrait rien dire.

# LE RELEVÉ, ET LE PLAFOND QUI EN SORT

Quatre-vingt-quatre captures sombres d'une exécution complète — les six livrées et tout le
dossier `diagnostic/`, dans les trois langues :

    état                                   part de pixels clairs
    les quatre-vingt-quatre saines             1,3 % à 8,0 %
    celle qui portait la bannière                   59,7 %

Les plus claires des saines sont les écrans en GRAND TEXTE : des titres blancs deux fois plus
gros occupent légitimement le haut. La plus sombre est la journée en espagnol.

Rien entre 8,0 % et 59,7 % à départager. `captures.yml` pose `--plafond 25` : trois fois la plus
claire observée, et moins de la moitié de la bannière. Il n'y a rien à régler finement, et c'est
une raison de plus de ne pas serrer le plafond — le bas de la distribution bougera le jour où un
écran gagnera un titre.

Sans `--plafond`, on mesure et on se tait — même forme que `check_grand_texte.py`.

# CE QU'IL NE FAIT PAS

Il n'empêche pas la bannière, il la voit.

Et il faut dire cette limite honnêtement : je n'ai PAS trouvé comment l'empêcher. La recherche
n'a rien rendu sur une option de `simctl` qui musellerait les notifications du système — ce qui
ne prouve pas qu'elle n'existe pas, seulement que je ne l'ai pas trouvée. Ce qui est documenté et
voisin : `simctl push` en ENVOIE, `simctl status_bar override` fige la barre d'état,
`simctl spawn log config` calme les journaux. Aucun des trois ne touche aux bannières.

Ce qu'on peut faire sans rien supposer, et qui est fait : refuser de livrer l'image. Relancer la
chaîne suffit, puisque c'est une affaire de minutage. Le jour où quelqu'un trouve la bonne
incantation, elle remplace ce paragraphe.
"""
import argparse
import pathlib
import sys

from PIL import Image

#: La bande où iOS pose ses bannières, en fractions de la hauteur : juste sous la barre d'état.
BANDE_HAUT, BANDE_BAS = 0.065, 0.19
#: Les bords sont ignorés : une bannière ne va pas jusqu'au pixel du bord, et un dégradé de
#: fond peut y traîner.
MARGE = 0.02
#: Au-dessus de ce niveau de gris, un pixel est « clair ». En thème sombre, le fond de l'app est
#: sous 40 et son texte blanc est ponctuel ; une bannière est un aplat autour de 190.
CLAIR = 140


def part_de_clair(chemin: pathlib.Path) -> float:
    with Image.open(chemin) as im:
        plan = im.convert("L")
        largeur, hauteur = plan.size
        bande = plan.crop((int(largeur * MARGE), int(hauteur * BANDE_HAUT),
                           int(largeur * (1 - MARGE)), int(hauteur * BANDE_BAS)))
        histo = bande.histogram()
        return sum(histo[CLAIR:]) / (bande.width * bande.height)


def sombres(dossier: pathlib.Path):
    """Les captures du thème sombre, celles qu'on livre et celles du diagnostic."""
    for p in sorted(dossier.rglob("*.png")):
        if "clair" in p.relative_to(dossier).parts:
            continue
        yield p


def main() -> int:
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("--dossier", type=pathlib.Path, required=True,
                         help="la racine des captures d'une exécution")
    options.add_argument("--plafond", type=float, default=None,
                         help="part de pixels clairs au-delà de laquelle on refuse, en %%")
    args = options.parse_args()

    if not args.dossier.is_dir():
        raise SystemExit(f"{args.dossier} n'est pas un dossier.")

    images = list(sombres(args.dossier))
    if not images:
        print(f"Aucune capture sombre sous {args.dossier} — l'analyse a échoué, pas le code.")
        return 1

    fautives = []
    pire = 0.0
    for p in images:
        part = part_de_clair(p)
        pire = max(pire, part)
        if args.plafond is not None and part * 100 > args.plafond:
            fautives.append((p.relative_to(args.dossier), part))

    if fautives:
        print("Une bannière du système s'est posée sur ces captures :\n")
        for nom, part in fautives:
            print(f"  · {nom} : {part:.1%} de pixels clairs en haut (plafond {args.plafond:.0f} %)")
        print("\n    Regarde l'image : c'est presque toujours une notification d'iOS en travers")
        print("    du haut de l'écran. Une capture qui montre l'interface du système est un")
        print("    motif de refus chez Apple, et celle-ci ne montre de toute façon pas l'app.")
        print("    Relancer la chaîne suffit : la bannière est une affaire de minutage.")
        return 1

    print(f"Bannières : {len(images)} captures sombres regardées, "
          f"au plus {pire:.1%} de pixels clairs en haut"
          + (f" (plafond {args.plafond:.0f} %)." if args.plafond is not None
             else " — aucun plafond demandé, on mesure."))
    return 0


if __name__ == "__main__":
    sys.exit(main())
