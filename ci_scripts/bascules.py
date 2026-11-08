#!/usr/bin/env python3
"""COMBIEN D'IMAGES VIDES À CHAQUE CHANGEMENT D'ONGLET.

# LE DÉFAUT QU'ON MESURE ICI

En passant sur le Coach, l'app montrait du fond nu : la barre d'onglets en place, le contenu pas
encore. Compté image par image sur un enregistrement du simulateur : TROIS IMAGES, 0,10 s, puis
une trentaine de centièmes de mise en place. C'est l'écran le plus lourd de l'app — une
conversation, ses longs textes, deux requêtes SwiftData — et il était inséré dans la même image
que celle où l'ancien écran disparaissait.

La correction est dans `RUMotion.ecran` : le changement d'écran est animé, donc les deux écrans
coexistent le temps d'un fondu de 0,22 s, et l'ancien couvre la construction du nouveau.

# POURQUOI UN SCRIPT ET PAS UN COUP D'ŒIL

Parce que je l'ai compté à la main une fois, et qu'une main ne recompte pas à chaque commit. Le
trou se reformera le jour où quelqu'un changera d'écran sans animer la mutation — c'est
exactement ce qui était arrivé : la transition était écrite, commentée, et ne jouait pas.

Le test de l'aperçu touche quatre onglets et relève l'heure de chaque bascule. L'enregistrement
brut les contient tous. Il n'y a donc rien à filmer en plus : juste à compter dans ce qui est
déjà là.

# CE QUE « VIDE » VEUT DIRE, ET CE QUE ÇA NE VEUT PAS DIRE

Une image VIDE est une image PLATE : hors de la barre d'onglets, l'écart-type des gris y est
quasi nul. Du fond, et rien d'autre. C'est le défaut.

Une image de TRANSITION n'est pas plate mais diffère de l'écran posé : c'est le fondu, et le
fondu est voulu. 0,22 s à trente images par seconde en fait une petite dizaine, et les compter
comme un défaut serait compter la correction elle-même.

Ce script rend donc deux nombres par bascule, et le seul qui accuse est le premier.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageStat

#: Les images par seconde auxquelles on relit l'enregistrement. Celles du montage : un défaut
#: qu'on ne verrait pas à cette cadence ne part pas dans la vidéo.
IPS = 30

#: La fenêtre relue AVANT le début du plan. Le test laisse 0,6 s entre l'appui sur l'onglet et le
#: début de la prise ; 0,9 s couvre donc l'appui, le fondu et un peu de marge.
FENETRE = 0.9

#: Où regarder. La barre d'onglets flotte dans la bande 0,894 → 0,949 et reste à l'écran pendant
#: toute la bascule : la garder dans le cadre rendrait AUCUNE image plate, et le défaut
#: invisible. On s'arrête donc au-dessus d'elle.
HAUT_UTILE = 0.88

#: Au-dessous de cet écart-type, l'image est du fond nu. Mesuré sur les captures de l'app : un
#: écran posé, même sobre, tient entre 25 et 60 ; un fond uni tient sous 2. Quatre laisse passer
#: un dégradé de fond sans laisser passer un écran.
PLAT = 4.0

#: Où le changement d'écran DOIT tomber : le test appuie sur l'onglet, attend 0,6 s, puis
#: déclare le plan.
ATTENDU_AVANT = 0.6

#: De combien l'instant moyen peut s'en écarter avant qu'on parle d'un défaut d'alignement. Le
#: fondu dure 0,22 s et la détection travaille à un trentième de seconde près ; une demi-seconde
#: laisse passer ce bruit-là et attrape le décalage de trois secondes qui a sorti trois films
#: faux.
TOLERANCE_ALIGNEMENT = 0.5

#: Au-dessus de cet écart moyen avec l'écran posé, l'image montre encore autre chose. Six gris
#: sur 255 : plus que le bruit de l'encodeur, moins qu'un élément qui manque.
DIFFERENT = 6.0


def ffmpeg(*args: str) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def _gris(chemin: pathlib.Path) -> Image.Image:
    with Image.open(chemin) as im:
        return im.convert("L").copy()


def images(entree: pathlib.Path, depart: float, duree: float,
           travail: pathlib.Path, prefixe: str) -> list[pathlib.Path]:
    """Les images de la fenêtre, en gris, rognées au-dessus de la barre d'onglets."""
    travail.mkdir(parents=True, exist_ok=True)
    # `-ss` AVANT `-i` : la recherche part de l'image-clé précédente et décode jusqu'au point
    # demandé, ce qui est à la fois rapide et juste. Le rognage et la réduction se font dans
    # ffmpeg plutôt qu'en Python : c'est le même calcul, fait une fois, du bon côté.
    ffmpeg("-ss", f"{max(0.0, depart):.3f}", "-i", str(entree), "-t", f"{duree:.3f}",
           "-vf", f"fps={IPS},crop=in_w:in_h*{HAUT_UTILE}:0:0,scale=258:-2,format=gray",
           str(travail / f"{prefixe}-%04d.png"))
    return sorted(travail.glob(f"{prefixe}-*.png"))


def posee(entree: pathlib.Path, instant: float, travail: pathlib.Path,
          prefixe: str) -> Image.Image:
    """L'écran posé, pris bien à l'intérieur de la pose : la référence à laquelle on compare.

    UNE IMAGE DEMANDÉE COMME UNE IMAGE, et non comme une fenêtre d'un trentième de seconde.
    Le premier jet réclamait `-t 0.033` avec le filtre de cadence : sur un enregistrement à
    cadence variable, cette fenêtre tombe régulièrement ENTRE deux images et ffmpeg n'en rend
    aucune. La mesure échouait alors en annonçant « l'enregistrement est plus court que le
    découpage » sur un fichier qui durait quarante secondes de plus.
    """
    travail.mkdir(parents=True, exist_ok=True)
    chemin = travail / f"{prefixe}.png"
    chemin.unlink(missing_ok=True)
    ffmpeg("-ss", f"{max(0.0, instant):.3f}", "-i", str(entree), "-frames:v", "1",
           "-vf", f"crop=in_w:in_h*{HAUT_UTILE}:0:0,scale=258:-2,format=gray", str(chemin))
    if not chemin.exists():
        raise SystemExit(f"Aucune image à {instant:.2f} s : l'enregistrement est plus court "
                         f"que le découpage.")
    return _gris(chemin)


def preuve(entree: pathlib.Path, instant: float, dossier: pathlib.Path, nom: str) -> pathlib.Path:
    """L'image que la mesure a jugée, gardée en entier et en couleurs.

    # POURQUOI CETTE FONCTION EXISTE

    Le garde-fou disait « ce plan montre le mauvais écran » et jetait l'image sur laquelle il
    s'était prononcé : le dossier de travail est temporaire, l'enregistrement brut n'est plus
    publié, et la comparaison porte sur un gris réduit à 258 pixels de large. Restait un verdict
    sans pièce — et une seule langue sur trois concernée, donc rien à reproduire ailleurs.

    Ce qui part dans l'artefact est donc l'image À L'INSTANT JUGÉ, pleine taille, non rognée : de
    quoi reconnaître l'écran d'un coup d'œil au lieu de le déduire. Seulement quand la mesure
    échoue — quatre plans par langue en pleine résolution pèseraient plus que les captures.
    """
    dossier.mkdir(parents=True, exist_ok=True)
    chemin = dossier / f"{nom}.png"
    chemin.unlink(missing_ok=True)
    ffmpeg("-ss", f"{max(0.0, instant):.3f}", "-i", str(entree), "-frames:v", "1", str(chemin))
    return chemin


def _ecart(im: Image.Image, reference: Image.Image) -> float:
    if im.size != reference.size:
        im = im.resize(reference.size)
    return ImageStat.Stat(ImageChops.difference(im, reference)).mean[0]


def classer(suite: list[pathlib.Path], posee: Image.Image,
            avant: Image.Image | None = None) -> list[str]:
    """Pour chaque image : « avant », « vide », « transition » ou « posée ».

    DEUX RÉFÉRENCES ET NON UNE, et le premier jet s'y était trompé. Avec la seule référence de
    l'écran posé, l'écran D'AVANT — qui occupe le début de la fenêtre, puisqu'elle commence
    avant l'appui — tombait dans « transition » : la mesure donnait dix-neuf images de mise en
    place là où il y en avait neuf, et le nombre grandissait avec la fenêtre au lieu de dire
    quelque chose sur l'app.

    L'écran d'avant est donc reconnu pour ce qu'il est, et il ne reste dans « transition » que
    ce qui n'est NI l'un NI l'autre : le fondu, et un écran à moitié construit.
    """
    sortie = []
    for chemin in suite:
        im = _gris(chemin)
        if ImageStat.Stat(im if im.size == posee.size else im.resize(posee.size)).stddev[0] < PLAT:
            sortie.append("vide")
            continue
        if _ecart(im, posee) <= DIFFERENT:
            sortie.append("posée")
        elif avant is not None and _ecart(im, avant) <= DIFFERENT:
            sortie.append("avant")
        else:
            sortie.append("transition")
    return sortie


SYMBOLE = {"avant": "<", "vide": "_", "transition": "~", "posée": "="}


def mise_en_place(classes: list[str]) -> tuple[int, int]:
    """Les images qu'il a fallu pour que l'écran se pose, et combien étaient vides.

    La fenêtre relue commence avant l'appui sur l'onglet : elle contient donc l'écran d'avant, et
    compter toutes les images non posées de la fenêtre ne dirait rien — le nombre dépendrait de
    la longueur de la fenêtre, pas de l'app.

    Ce qui se mesure est la TRAVERSÉE : ce qui se passe entre la dernière image de l'écran
    d'avant et la première du nouvel écran posé. C'est le nombre comparable d'une exécution à
    l'autre, et c'est celui du relevé à la main — « trois images vides, neuf de mise en place ».
    """
    if not classes:
        return 0, 0
    # Où le nouvel écran s'est posé pour de bon : le début du dernier bloc d'images posées.
    pose = len(classes)
    while pose > 0 and classes[pose - 1] == "posée":
        pose -= 1
    if classes[-1] != "posée":
        # L'écran n'était pas encore là quand le plan a commencé. On ne rend pas un zéro
        # rassurant : on rend tout ce qui n'était pas l'écran d'avant.
        pose = len(classes)
    # Où l'écran d'avant a disparu.
    depart = 0
    for i in range(pose - 1, -1, -1):
        if classes[i] == "avant":
            depart = i + 1
            break
    return pose - depart, classes[depart:pose].count("vide")


#: À quel écran photographié chaque bascule doit ressembler. Les noms de gauche sont ceux des
#: plans du test — « première-coach » comme « coach » visent le même écran, et « retour » revient
#: à l'accueil.
TEMOINS = {
    "accueil": "1-accueil.png",
    "coach": "3-coach.png",
    "stats": "6-stats.png",
    "profil": "diagnostic/profil.png",
}


def ecran_vise(nom: str) -> str:
    return {"retour": "accueil"}.get(nom.removeprefix("première-"), nom.removeprefix("première-"))


def temoins(dossier: pathlib.Path, gabarit: Image.Image) -> dict[str, Image.Image]:
    """Les écrans photographiés par la passe claire, prêts à être comparés.

    # POURQUOI COMPARER DES IMAGES ET PAS DES HORLOGES

    Un découpage décalé de trois secondes met chaque plan sur l'écran SUIVANT. Vu des durées,
    tout va bien — un plan de deux secondes dure deux secondes où qu'on le coupe. Vu des
    horloges, tout va bien aussi : les plans se suivent à trois secondes d'intervalle, donc un
    décalage de trois secondes se confond avec le plan d'à côté. C'est exactement ce qui a laissé
    passer trois films faux.

    Ce qui ne se confond pas, c'est l'écran lui-même. La passe claire vient de photographier les
    quatre onglets : il suffit de demander auquel l'image ressemble le plus. Mesuré sur une
    prise réelle, l'écart au bon écran vaut 4,8 et au plus proche des autres 24 — il n'y a pas de
    seuil à régler, le plus proche gagne de cinq longueurs.
    """
    trouves = {}
    for nom, fichier in TEMOINS.items():
        chemin = dossier / fichier
        if not chemin.is_file():
            continue
        with Image.open(chemin) as im:
            gris = im.convert("L")
            gris = gris.crop((0, 0, gris.width, int(gris.height * HAUT_UTILE)))
            trouves[nom] = gris.resize(gabarit.size)
    return trouves


def le_plus_proche(image: Image.Image,
                   references: dict[str, Image.Image]) -> list[tuple[str, float]]:
    """Les écrans photographiés, du plus ressemblant au moins."""
    return sorted(((nom, _ecart(image, ref)) for nom, ref in references.items()),
                  key=lambda c: c[1])


def instant_du_changement(classes: list[str], fenetre: float) -> float | None:
    """Combien de secondes AVANT le début du plan l'écran a changé. `None` si on ne l'a pas vu.

    # CE QUE CE NOMBRE SURVEILLE

    L'alignement entre l'horloge du test et celle de l'enregistrement. Le test appuie sur
    l'onglet, attend 0,6 s, puis déclare le plan : le changement doit donc tomber à 0,6 s avant
    le début du plan, à la durée du fondu près.

    S'il tombe ailleurs, les repères ne désignent pas ce qu'on croit — et c'est arrivé : pendant
    plusieurs exécutions le film a été coupé trois secondes trop tard, parce que la caméra met
    trois secondes à démarrer et que personne ne les comptait. Aucune durée ne pouvait le dire,
    et c'est ce nombre-ci qui l'aurait dit.
    """
    for i, c in enumerate(classes):
        if c != "avant":
            return fenetre - i / IPS
    return None


def alignement(entree: pathlib.Path, bascules: list, references: dict, decalage: float,
               travail: pathlib.Path, fenetre: float = 4.0, pas: float = 0.25) -> tuple:
    """Le décalage qui met TOUS les plans sur l'écran qu'ils visent, et ce qu'il coûte.

    # POURQUOI CHERCHER, PLUTÔT QUE CROIRE L'HORLOGE

    Le découpage part de deux heures : celle que le test écrit quand l'app paraît, et celle que
    le workflow relève quand `simctl` annonce « Recording started ». Leur différence est le
    décalage. Elle est juste la plupart du temps — et parfois non : les 7 et 8 novembre 2026, le
    garde-fou a refusé deux films, une fois en espagnol et une fois en anglais, et les images
    gardées montrent le même symptôme — chaque plan tombe sur l'écran du plan SUIVANT, soit un
    retard d'environ trois secondes. `simctl` annonce qu'il tourne avant d'écrire sa première
    image, et le reste de l'écart varie avec la charge de la machine.

    Une horloge qu'on ne peut pas vérifier n'est pas une mesure. Les quatre écrans visés, eux,
    sont photographiés par la passe claire : on peut donc essayer des décalages et garder celui
    qui met les quatre plans sur leurs écrans. C'est le contenu qui aligne le film, plus une
    annonce de la caméra.

    # CE QUE ÇA COÛTE

    Une image par plan et par candidat — 4 × 33 extractions d'une image pour ±4 s au quart de
    seconde, quelques dizaines de secondes. À comparer aux quarante minutes de harnais qu'un film
    refusé fait recommencer.

    Rend `(decalage_trouve, ecart_moyen, parfait)` : `parfait` dit si chaque plan tombe sur son
    écran, et non seulement « au mieux qu'on ait trouvé ».
    """
    candidats = []
    n = int(round(fenetre / pas))
    for k in range(-n, n + 1):
        essai = decalage + k * pas
        if essai < 0:
            continue
        total, bons = 0.0, 0
        for i, b in enumerate(bascules, start=1):
            vise = ecran_vise(b["nom"])
            if vise not in references:
                continue
            try:
                image = posee(entree, essai + b["debut"] + 0.5, travail, f"a{i}")
            except SystemExit:
                total = float("inf")
                break
            classement = le_plus_proche(image, references)
            total += dict(classement)[vise]
            if classement[0][0] == vise:
                bons += 1
        candidats.append((total, -bons, essai))
    if not candidats:
        return decalage, float("inf"), False
    total, moins_bons, trouve = min(candidats)
    vises = sum(1 for b in bascules if ecran_vise(b["nom"]) in references)
    return trouve, total / max(vises, 1), (-moins_bons) == vises


def main() -> int:
    a = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--entree", type=pathlib.Path, required=True,
                   help="L'enregistrement brut du simulateur (brut.mov)")
    a.add_argument("--temps", type=pathlib.Path, required=True,
                   help="Le découpage relevé par le test (temps.json)")
    a.add_argument("--decalage", type=float, default=0.0,
                   help="Secondes entre le début de l'enregistrement et celui de la prise")
    a.add_argument("--fenetre", type=float, default=FENETRE,
                   help=f"Secondes relues avant chaque plan (défaut {FENETRE})")
    a.add_argument("--plafond", type=int, default=None,
                   help="Nombre d'images vides au-delà duquel on échoue. Sans lui, on mesure "
                        "et on se tait : c'est l'état voulu tant qu'on n'a pas de relevé.")
    a.add_argument("--temoins", type=pathlib.Path, default=None,
                   help="Le dossier des captures claires (appstore/raw/<langue>/clair) : chaque "
                        "bascule doit tomber sur l'écran qu'elle vise, et non sur son voisin")
    a.add_argument("--aligner", action="store_true",
                   help="Chercher le décalage qui met chaque plan sur l'écran qu'il vise, au "
                        "lieu de croire l'horloge. Écrit le décalage trouvé sur la sortie "
                        "standard, en dernière ligne, préfixé de « DÉCALAGE= ».")
    a.add_argument("--preuves", type=pathlib.Path, default=None,
                   help="Où garder l'image jugée quand un plan tombe sur le mauvais écran. "
                        "Sans lui, le verdict part sans sa pièce.")
    a.add_argument("--travail", type=pathlib.Path, default=None,
                   help="Dossier de travail (sinon un dossier temporaire)")
    options = a.parse_args()

    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg est introuvable.")

    bornes = json.loads(options.temps.read_text(encoding="utf-8"))
    # `bascule` dit si le plan a été précédé d'un appui sur un onglet. Les plans qui défilent
    # n'en ont pas : relire la seconde qui les précède ne mesurerait que la fin du plan d'avant.
    bascules = [b for b in bornes if b.get("bascule")]
    if not bascules:
        print("Aucune bascule d'onglet dans ce découpage — rien à mesurer.")
        return 0

    temporaire = None
    if options.travail is None:
        temporaire = tempfile.TemporaryDirectory()
        travail = pathlib.Path(temporaire.name)
    else:
        travail = options.travail

    try:
        # TOUT CE QUI EST EN SECONDES DE MONTRE PASSE PAR LÀ, et rien d'autre : un seul endroit
        # où le zéro de l'enregistrement est posé, donc un seul endroit à corriger le jour où il
        # bouge.
        decalage = options.decalage

        # LES TÉMOINS SONT CHARGÉS D'ABORD, parce que l'alignement en a besoin avant la mesure.
        # Le gabarit vient d'une image du film : les témoins sont ramenés à sa taille une fois
        # pour toutes, et c'est la seule raison pour laquelle cette première extraction existe.
        references: dict[str, Image.Image] = {}
        if options.temoins:
            gabarit = posee(options.entree, decalage + bascules[0]["debut"] + 0.5, travail, "g")
            references = temoins(options.temoins, gabarit)
            if not references:
                raise SystemExit(f"Aucune capture claire dans {options.temoins} : "
                                 f"la bascule ne peut pas être reconnue.")

        # L'ALIGNEMENT PAR LE CONTENU, quand on le demande. Voir `alignement`.
        if options.aligner and references:
            trouve, ecart, parfait = alignement(options.entree, bascules, references,
                                                decalage, travail)
            glissement = trouve - decalage
            print(f"  alignement : {glissement:+.2f} s "
                  f"(écart moyen {ecart:.1f} au meilleur décalage, "
                  f"{'chaque plan sur son écran' if parfait else 'IL EN RESTE UN DE TRAVERS'})")
            if abs(glissement) >= 0.5:
                print(f"  → l'heure annoncée par la caméra était fausse de {glissement:+.2f} s. "
                      f"Le découpage suit le contenu, pas l'horloge.")
            decalage = trouve

        def vers_fichier(seconde: float) -> float:
            return seconde + decalage

        total_vides = 0
        changements: list[float | None] = []
        egares: list[str] = []
        for i, b in enumerate(bascules, start=1):
            # La référence est prise un demi-seconde APRÈS le début du plan : l'écran y est
            # posé, et c'est à lui qu'on compare ce qui précède.
            reference = posee(options.entree, vers_fichier(b["debut"] + 0.5), travail, f"ref{i}")
            suite = images(options.entree, vers_fichier(b["debut"] - options.fenetre),
                           options.fenetre, travail, f"f{i}")
            # L'ÉCRAN D'AVANT, pris sur la PREMIÈRE image de la fenêtre. Le test laisse 0,6 s
            # entre l'appui sur l'onglet et le début du plan, et la fenêtre fait 0,9 s : son
            # premier tiers est donc encore l'écran précédent. Si ce n'est plus vrai — fenêtre
            # raccourcie, machine plus lente — la ligne de symboles le montre, elle ne
            # commencera pas par des « < ».
            classes = classer(suite, reference, _gris(suite[0]) if suite else None)
            vides = classes.count("vide")
            traversee, vides_traversee = mise_en_place(classes)
            total_vides += vides
            # L'ÉCRAN EST-IL LE BON ? La question que les durées ne savent pas poser.
            if references:
                classement = le_plus_proche(reference, references)
                vise = ecran_vise(b["nom"])
                proche, ecart = classement[0]
                suivant = classement[1] if len(classement) > 1 else (proche, ecart)
                if vise not in references:
                    print(f"  {'':<10} (pas de capture pour « {vise} » — rien à confronter)")
                elif proche != vise:
                    egares.append(f"{b['nom']} montre « {proche} »")
                    print(f"  {'':<10} ÉCRAN : ce plan vise « {vise} » et montre « {proche} » "
                          f"(écart {ecart:.1f} contre {dict(classement)[vise]:.1f}).")
                    # LE CLASSEMENT ENTIER, parce que deux nombres ne disent pas si l'image
                    # ressemble à UN écran ou à aucun. Une image à moitié construite est loin de
                    # tous : ça se lit sur quatre écarts, pas sur deux.
                    print(f"  {'':<10} écarts : "
                          + ", ".join(f"{n} {e:.1f}" for n, e in classement))
                    if options.preuves:
                        garde = preuve(options.entree, vers_fichier(b["debut"] + 0.5),
                                       options.preuves, f"{b['nom']}-montre-{proche}")
                        print(f"  {'':<10} image jugée gardée : {garde}")
                else:
                    print(f"  {'':<10} écran « {vise} » reconnu (écart {ecart:.1f}, "
                          f"le suivant à {suivant[1]:.1f})")

            quand = instant_du_changement(classes, options.fenetre)
            changements.append(quand)
            print(f"  {b['nom']:<10} {''.join(SYMBOLE[c] for c in classes)}")
            print(f"  {'':<10} {len(classes)} images sur {options.fenetre:.2f} s — "
                  f"mise en place : {traversee} images ({traversee / IPS:.2f} s), "
                  f"dont {vides_traversee} vide(s) ; {vides} vide(s) dans toute la fenêtre")
            print(f"  {'':<10} changement d'écran à "
                  + (f"{quand:.2f} s avant le plan (attendu {ATTENDU_AVANT:.2f})"
                     if quand is not None
                     else "un instant qu'on n'a pas vu : la fenêtre ne commence pas sur "
                          "l'écran d'avant"))

        if egares:
            print(f"  DÉCOUPAGE : {len(egares)} bascule(s) tombent sur le mauvais écran — "
                  f"{', '.join(egares)}. Le film est coupé au mauvais endroit de "
                  f"l'enregistrement ; ce n'est pas une question de durée.")
            return 1

        vus = [c for c in changements if c is not None]
        if vus:
            moyen = sum(vus) / len(vus)
            print(f"  → changement d'écran à {moyen:.2f} s du plan en moyenne "
                  f"(attendu {ATTENDU_AVANT:.2f}, étendue {min(vus):.2f} → {max(vus):.2f}).")
            if abs(moyen - ATTENDU_AVANT) > TOLERANCE_ALIGNEMENT:
                print(f"  ALIGNEMENT : les repères sont décalés d'environ "
                      f"{ATTENDU_AVANT - moyen:+.2f} s par rapport à l'enregistrement. "
                      f"Le film est coupé au mauvais endroit — ce n'est pas une question de "
                      f"durée, c'est l'image qui ne correspond pas au titre.")
                return 1
        else:
            print("  → aucun changement d'écran repéré : la fenêtre ne commence jamais sur "
                  "l'écran d'avant, donc l'alignement ne se vérifie pas.")
            return 1

        print(f"  → {total_vides} image(s) vide(s) en tout sur {len(bascules)} bascule(s). "
              f"Le fondu de 0,22 s fait attendre une mise en place d'une petite dizaine "
              f"d'images ; des vides, aucune.")
        print("    < écran d'avant   _ fond nu, rien dessus   ~ en train d'arriver   = posé")
        if options.aligner:
            # La dernière ligne sert au workflow : le montage coupe sur CE décalage-là.
            print(f"DÉCALAGE={decalage:.3f}")
        if options.plafond is not None and total_vides > options.plafond:
            print(f"  ÉCHEC : {total_vides} images vides pour un plafond de {options.plafond}.")
            return 1
        return 0
    finally:
        if temporaire is not None:
            temporaire.cleanup()


if __name__ == "__main__":
    sys.exit(main())
