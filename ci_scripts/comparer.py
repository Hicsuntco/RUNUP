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
l'iPhone 15 Pro Max, pour une barre qui en fait 162. Ce qui est masqué n'est pas mesuré.

ET SUR UNE CAPTURE DÉFILÉE, CETTE BANDE N'EST PAS QUE LA BARRE D'ÉTAT. iOS dessine l'heure
PAR-DESSUS l'app : sur `profil-bas.png`, pris au milieu d'un défilement, les 186 px du haut
portent la carte « Amis · N sorties aujourd'hui », avec l'heure posée dessus. Le 11 novembre
2026, ce nombre est passé de 2 à 3 entre deux campagnes, et cet outil a répondu « identique ».
Le défaut était réel, il a été vu À L'ŒIL en ouvrant les deux images.

Donc : un « = » de cet outil veut dire « identique SOUS les 186 premiers pixels », pas
« identique ». Sur un écran défilé, il faut regarder le haut soi-même. Le masque ne peut pas
être retiré — il existe pour l'heure, qui change à chaque prise — et c'est le genre de limite
qui doit être écrite ici plutôt que redécouverte.

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

# DEUX ÉCRANS NE SE REPRODUISENT PAS D'UNE EXÉCUTION À L'AUTRE, ET IL FAUT LE SAVOIR

Relevé en comparant deux exécutions séparées de trois heures, SANS aucun changement de code
entre les deux sur ces écrans-là :

- `diagnostic/course-en-cours` : une carte dont les tuiles n'arrivent pas au même moment, un
  chronomètre qui tourne, des calories. 752 à 42 400 pixels d'écart selon la langue.
- `diagnostic/profil` : la tuile « Amis » dit « 3 abonnements » à une heure et « 1 sortie
  aujourd'hui » à une autre. Les données de démonstration sont datées RELATIVEMENT à l'heure
  courante, et une sortie plantée « il y a trois heures » tombe hier ou aujourd'hui selon
  l'heure à laquelle la chaîne tourne. ~3 000 pixels, toujours la même bande de 40 points.

ET ÇA NE SE CORRIGE PAS À PEU DE FRAIS. `CaptureSeed` prend déjà un `maintenant:` en
paramètre, donc on pourrait le figer — mais à quelle valeur ? Les données plantées doivent être
DANS LE PASSÉ de l'horloge de l'appareil, sinon « il y a trois heures » devient « dans
quatorze heures », et elles doivent tomber AUJOURD'HUI pour que la fiche ne vieillisse pas.
Aucune heure fixe de la journée ne tient les deux : la chaîne a tourné à 01 h 18 et à 04 h 37,
et 18 h 00 est dans leur futur à toutes les deux. La vraie réponse serait de figer l'horloge du
simulateur, ce que `simctl` ne fait pas pour l'app. On note donc, et on ne corrige pas.

- `diagnostic/club-apercu-bas` : TROISIÈME écran non reproductible, relevé le 8 novembre 2026, et
  d'une autre nature que les deux précédents — le contenu est identique, c'est le DÉFILEMENT qui
  ne retombe pas au même endroit. Le harnais donne un nombre de glissements, pas une destination,
  et la distance parcourue dépend de l'inertie au moment où la capture est prise.

  Mesuré : moyenne 16,3 et 813 202 pixels d'écart entre deux exécutions — cinq fois la moyenne et
  neuf fois le compte de pixels d'un CHANGEMENT DE LANGUE COMPLET sur ce même écran (3,43 et
  90 973 dans le tableau ci-dessus). C'est le plus gros chiffre que cet outil ait rendu, et il ne
  vient pas du code. En décalant l'image d'après de 105 pixels vers le haut, la moyenne tombe de
  20,1 à 1,03 — un minimum unique et net, donc un défilement et rien d'autre. D'où `--decalage`.

  Pas corrigé, et la raison se chiffre : `sortie-bas` et `profil-bas`, qui défilent aussi, sont
  revenus IDENTIQUES à la même exécution. Changer la stratégie de défilement — aller jusqu'au bas
  plutôt que glisser N fois — recadrerait ces trois captures de diagnostic pour un défaut qui
  n'apparaît que de temps en temps sur l'une d'elles.

ET J'AI DIT TROP VITE QUE LES SIX IMAGES LIVRÉES À APPLE ÉTAIENT REPRODUCTIBLES. Elles
l'étaient entre les deux exécutions que j'avais comparées — 01 h 18 et 04 h 37, toutes deux
après minuit. Une troisième à 07 h 00 a fait bouger `3-coach` dans les trois langues et les
deux thèmes : le séparateur de jour au-dessus de la conversation passait de « HIER » à
« AUJOURD'HUI », parce que le message était planté cinq heures en arrière. Deux exécutions qui
s'accordent ne font pas une reproductibilité.

Ce message est depuis borné au jour courant (`CaptureSeed.conversation`), ce qui rend `3-coach`
stable et dit par la même occasion ce qu'on veut montrer : un coach qui a répondu ce matin. Les
cinq autres images livrées n'ont pas bougé sur les trois exécutions.

Pour juger un découpage, nommer les écrans avec `--seulement` plutôt que tout comparer : les
trois ci-dessus noieraient le verdict sous un bruit qui ne vient pas du code.

# `--decalage` : « ça a bougé » ou « ça a juste défilé » ?

La question s'est posée le 8 novembre et a coûté une demi-heure à trancher à la main. Avec
`--decalage`, chaque image qui diffère est aussi comparée à elle-même DÉCALÉE verticalement, de
−200 à +200 pixels, et l'outil dit le décalage qui minimise l'écart et ce qu'il en reste.

Un minimum net loin de zéro veut dire « même contenu, autre position » — donc un défilement, pas
une régression. Un minimum à zéro, ou un creux mou, veut dire que la différence est dans le
contenu et qu'il faut regarder l'image. L'option est volontairement facultative : la recherche
coûte quatre cents comparaisons par image, et on ne la paye que quand on a une question.
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


#: Amplitude de la recherche de décalage, en pixels, de part et d'autre de zéro. Deux cents
#: couvrent largement un glissement de plus ou de moins ; au-delà, deux écrans qui se
#: ressemblent par hasard commenceraient à se trouver un faux minimum.
AMPLITUDE = 200


def meilleur_decalage(avant: pathlib.Path, apres: pathlib.Path, haut: float):
    """Le décalage vertical qui rapproche le plus les deux images, et ce qu'il en reste.

    Rend `(décalage, moyenne à ce décalage, moyenne sans décalage)`. Un minimum net loin de zéro
    veut dire « même contenu, autre position » — un défilement, pas une régression.

    La comparaison se fait sur une BANDE CENTRALE, pas sur l'image entière : le haut porte un
    en-tête qui ne défile pas et le bas une barre d'onglets qui ne défile pas non plus. Les
    inclure ferait croire à un contenu identique là où rien ne bouge, et tirerait le minimum
    vers zéro.
    """
    a, b = gris(avant, haut), gris(apres, haut)
    if a.size != b.size:
        return None, None, None
    largeur, hauteur = a.size
    debut, fin = int(hauteur * 0.06), int(hauteur * 0.88)
    bande = fin - debut
    resultats = []
    for dy in range(-AMPLITUDE, AMPLITUDE + 1):
        # ON COMPARE CE QUI SE RECOUVRE, on ne saute pas le décalage.
        #
        # La première version refusait tout décalage qui faisait sortir la bande de l'image. Sur
        # une capture de 2868 pixels la marge est de 160 et ça ne se voyait pas ; sur une image
        # plus courte — un gabarit de test de 600 — la marge tombe à 33 et la recherche ne
        # pouvait tout simplement PAS trouver un décalage de 48. Elle rendait alors le meilleur
        # des petits décalages, avec un reste énorme, et un message qui disait le contraire de
        # la vérité. Trouvé en éprouvant l'option, pas en la relisant.
        y0 = max(debut, -dy)
        y1 = min(fin, hauteur - dy)
        # Sous les deux tiers de recouvrement, la moyenne porte sur un ruban : elle baisserait
        # pour de mauvaises raisons, et un faux minimum vaut moins que pas de réponse.
        if y1 - y0 < bande * 2 // 3:
            continue
        reference = a.crop((0, y0, largeur, y1))
        candidat = b.crop((0, y0 + dy, largeur, y1 + dy))
        resultats.append((dy, ImageStat.Stat(ImageChops.difference(reference, candidat)).mean[0]))
    if not resultats:
        return None, None, None
    sans = dict(resultats).get(0)
    dy, moyenne = min(resultats, key=lambda r: r[1])
    return dy, moyenne, sans


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
    a.add_argument("--decalage", action="store_true",
                   help="pour chaque image qui diffère, chercher si un décalage vertical "
                        "l'explique — autrement dit : est-ce que ça a bougé, ou défilé ?")
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
        if options.decalage:
            dy, apres_decalage, sans = meilleur_decalage(gauche[nom], droite[nom], options.haut)
            if dy is None:
                print("      décalage : deux tailles d'image, rien à chercher.")
            elif not sans:
                # La bande centrale est identique telle quelle : ce qui diffère est en dehors
                # d'elle. Dire « le décalage n'explique pas » serait trompeur — il n'y a rien à
                # expliquer là où l'on a regardé. (Relevé en éprouvant l'option : un gabarit au
                # motif périodique retombait sur lui-même, et le message d'alors mentait.)
                print("      décalage : la bande centrale est identique sans décalage. "
                      "Ce qui diffère est au-dessus ou en dessous d'elle.")
            elif dy == 0:
                print(f"      décalage : aucun ne fait mieux que zéro ({sans:.3f}). "
                      "La différence est dans le CONTENU — regarde l'image.")
            else:
                # `dy` est le décalage appliqué à la fenêtre de l'image d'après : positif veut
                # dire que son contenu est plus BAS, donc qu'elle a défilé MOINS loin. Donner le
                # signe nu obligerait à refaire ce raisonnement à chaque lecture.
                sens = "plus bas (défilement moins loin)" if dy > 0 else "plus haut (défilement plus loin)"
                print(f"      décalage : le contenu d'après est {abs(dy)} px {sens} ; "
                      f"la moyenne passe de {sans:.3f} à {apres_decalage:.3f}.")
                # Un facteur quatre est net : sur les mesures du 8 novembre, un vrai défilement
                # divisait l'écart par vingt. En deçà, le décalage n'explique pas grand-chose et
                # dire « c'est juste un défilement » serait trop commode.
                if sans and apres_decalage * 4 <= sans:
                    print("      → même contenu à une autre position : un défilement, "
                          "pas une régression.")
                else:
                    print("      → le décalage n'explique pas l'écart. Regarde l'image.")
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
