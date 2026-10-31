#!/usr/bin/env python3
"""Compose les captures de l'App Store à partir de captures brutes.

Une capture brute est une capture d'écran : ce que les gens voient sur la fiche App Store est
une image composée — fond de marque, accroche, téléphone qui déborde du cadre. Ce script fait
la seconde à partir de la première, et tourne depuis l'onglet Actions comme le reste, pour ne
pas avoir à ouvrir un terminal.

    Entrée  : appstore/raw/<langue>/1-accueil.png … 6-stats.png
                                           (prises par `RunUpUITests.CapturesUITests`, une
                                           série par langue ; à défaut de dossier de langue,
                                           les fichiers posés à la racine de `raw/`)
              appstore/captions.json       (les accroches, par langue)
    Sortie  : appstore/out/<langue>/1.png … (1290 × 2796, prêtes pour App Store Connect)

    python3 ci_scripts/screenshots.py fr-FR

Le format 1290 × 2796 est celui de l'iPhone 15/16 Pro Max. C'est la seule taille qu'Apple exige
encore : les autres tailles d'iPhone sont dérivées automatiquement de celle-ci.
"""

from __future__ import annotations

import json
import math
import re
import sys
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "appstore" / "raw"
OUT = ROOT / "appstore" / "out"
CAPTIONS = ROOT / "appstore" / "captions.json"
FONTS = ROOT / "RunUp" / "Resources" / "Fonts"

CANVAS = (1290, 2796)

# LA FICHE EST UNE SEULE IMAGE, DÉCOUPÉE EN SIX.
#
# La version précédente composait six images indépendantes sur le même aplat rose : six îlots,
# six téléphones centrés, aucun lien. Or l'App Store les montre à la suite — on en voit deux et
# demie d'un coup — et c'est cette continuité-là qu'une fiche peut utiliser et que celle-ci
# n'utilisait pas.
#
# Tout est donc dessiné sur une bande de six cadres de large, puis découpé. Le fond, la trace et
# le rythme traversent les coupures ; chaque cadre reste lisible seul, parce qu'Apple n'en montre
# souvent qu'un dans les résultats de recherche.
TOTAL = 6
BANDE = (CANVAS[0] * TOTAL, CANVAS[1])

# TROIS ÉLÉMENTS TRAVERSENT LES SIX IMAGES SANS S'INTERROMPRE.
#
# Deux filets horizontaux et une ligne de texte en chasse fixe. Rien d'autre. C'est peu, et c'est
# le point : l'App Store sépare les vignettes par un blanc, et l'œil ne recolle à travers ce
# blanc que des formes qu'il sait reconstruire — un trait, et des LETTRES. Un téléphone coupé,
# non ; une sinusoïde décorative, oui mais elle ne dit rien ; seize tracés de démonstration,
# essayés et retirés — ce sont des cercles perturbés, et à grande échelle ils lisent comme des
# taches plutôt que comme des parcours.
#
# La ligne de texte est le vrai raccord. Elle court d'un bout à l'autre de la bande, se fait
# couper par chaque bord de cadre, et reprend sur le suivant à la lettre près. C'est ce qu'on
# voit en faisant défiler : une seule phrase qui avance sous six images.
FILET_HAUT = 700
FILET_BAS = 2480
FILET = 2
BANDEAU_LIGNE = 2566         # la ligne de chasse fixe qui traverse les six cadres
BANDEAU_TAILLE = 28
BANDEAU_CHASSE = 5.0

# Un cadre sur deux montre l'écran ENTIER ; l'autre montre un morceau de ce même écran, agrandi
# et coupé par les deux bords du cadre. C'est la « capture coupée » au sens le plus clair, et
# c'est ce qui donne son rythme à la fiche — un plan large, un gros plan, un plan large.
#
# La zone agrandie est exprimée en FRACTION de la capture, pas en pixels : une capture d'un autre
# appareil, ou d'une autre hauteur d'écran, continue de viser la même chose. Elle reste à
# revérifier quand l'écran correspondant change de mise en page — le composeur imprime ce qu'il a
# découpé, pour qu'un cadrage devenu faux se voie dans le journal.
# LA CARTE AGRANDIE NE DÉBORDE PAS. ELLE EST ENTIÈRE.
#
# Deux versions ont essayé de la faire déborder, et les deux ont été signalées. Centrée et
# débordant des deux côtés, elle coupait des mots : « ourse 12,4 km », « us rapide 5:06/km », un
# « 5:24 » amputé de son 5 — une carte de l'app a quarante à soixante pixels de marge intérieure,
# cent cinq entament donc le texte. Calée à gauche et ne débordant plus qu'à droite, elle en
# coupait encore la moitié.
#
# Le débordement est abandonné. Un mot coupé, un bouton coupé en deux, un graphique tranché : rien
# de tout cela ne se lit comme une mise en page, tout se lit comme une erreur de cadrage — et sur
# une fiche App Store, c'est ce qui distingue une page faite d'une page bâclée.
#
# La carte tient donc entre les deux marges, en entier, avec ses quatre bords. ET C'EST QUAND MÊME
# UN GROS PLAN : dans les cadres à appareil, l'écran est rendu à 700 px de large sur les 1320 de
# la capture, soit 0,53. Ici la carte est rendue à 1 098 px sur 1 180, soit 0,93 — elle est donc
# 1,75 fois plus grande que la même carte vue dans le téléphone d'à côté. Le rapport entre les
# deux est ce qui fait le gros plan ; le débordement n'y était pour rien.
#
# Le raccord d'une image à l'autre, lui, n'a jamais reposé là-dessus : il est porté par les deux
# filets et la ligne courante, qui traversent les six cadres sans rien couper de lisible.
BANDES = {
    2: (0.053, 0.1423, 0.947, 0.4372),  # le plan : la carte « La forme du plan », entière
    4: (0.053, 0.3996, 0.947, 0.8961),  # le club : la sortie du fil, entière
    6: (0.053, 0.5625, 0.947, 0.8682),  # les stats : la carte « Allure moyenne », entière
}
BANDE_CENTRE = 1600

SCREEN_W = 700
DEVICE_TOP = 790
DEVICE_BOTTOM_MARGIN = 36
# Le texte est CALÉ À GAUCHE, et non centré. Six titres centrés sur six cadres se lisent comme
# six affiches ; calés à gauche sur la même marge, ils se lisent comme une seule page qui avance.
#
# LES TAILLES SONT ÉCRITES ICI ET NULLE PART AILLEURS. Elles l'étaient deux fois — une fois pour
# dessiner, une fois pour vérifier le débordement — et deux copies d'une mesure finissent par
# diverger : le contrôle aurait alors validé des accroches qui débordent, ce qui est pire que pas
# de contrôle du tout.
MARGE = 96
# LA POLICE DE TITRAGE DE LA FICHE, nommée ici et nulle part ailleurs.
#
# L'app, elle, n'en a pas : six familles ont été essayées et refusées parce qu'elles avaient une
# VOIX, et une interface ne doit pas en avoir (voir `DisplayFont`, qui raconte ce refus). Ce refus
# vaut pour l'interface. Une fiche App Store est l'inverse — c'est une page de vente, vue une
# seule fois, avant l'installation : n'y avoir aucune voix est un défaut, pas une qualité.
#
# Bricolage Grotesque, coupe 96 pt Condensed ExtraBold. Sept familles ont été composées sur la
# vraie fiche avant celle-ci. Archivo et Chivo ressemblaient à Inter en plus gras — changer de
# fichier sans changer de page. Fraunces donnait la plus belle page et la plus risquée : un serif
# de titrage sur fond crème est devenu le cliché de l'époque. Anton avait l'impact et deux défauts
# : ses descendantes touchaient le sous-titre, et « Tu n'es pas seule » en Anton se lit comme un
# slogan de salle de sport, ce qui n'est pas la voix de cette app.
#
# La coupe retenue est le croisement des deux dernières : la DENSITÉ d'Anton, obtenue par l'axe de
# largeur de Bricolage poussé à 75, et les lettres de Bricolage. À 152 points, les dix-huit titres
# des trois langues tiennent chacun sur UNE ligne — c'est la condensation qui le permet, et c'est
# ce qui donne au bloc de texte sa densité.
#
# LA GRAISSE EST 600 ET NON 800. À 800, les contreformes de « e », « a » et « é » se referment :
# la ligne devient une masse avant d'être un mot. 600 les rouvre, et la taille passe de 142 à 152
# pour que la présence ne se perde pas en chemin — la place libérée par la graisse plus fine est
# exactement celle que la taille reprend. 500 et 700 sont à une ligne d'ici si l'arbitrage change.
#
# Le fichier vit dans `appstore/`, pas dans `RunUp/Resources/Fonts` : il ne sert qu'à composer des
# images sur la machine, il n'entre pas dans l'app, et il ne doit pas pouvoir être confondu avec
# une police d'interface par `check_fonts.py`. Sa licence SIL OFL est à côté, comme elle l'exige.
TITRE_POLICE = ROOT / "appstore/polices/BricolageGrotesque-96pt-Condensed-SemiBold.ttf"
TITRE_HAUT = 300
TITRE_TAILLE = 152
TITRE_INTERLIGNE = 160
TITRE_LIGNES = 1             # hauteur réservée, pour que le sous-titre ne monte ni ne descende
TITRE_CHASSE = -1.0          # resserrement : la coupe est déjà condensée, il en faut peu
SOUS_TAILLE = 46
SOUS_INTERLIGNE = 60
EYEBROW_TAILLE = 30
EYEBROW_CHASSE = 4.0
TITLE_MARGIN = MARGE
SUB_MARGIN = MARGE

# Les captures viennent d'un iPhone, où elles s'appellent `IMG_0042.PNG` — extension EN MAJUSCULES.
# Un `glob("*.png")` ne les voit pas sur le runner Linux, qui distingue la casse, et le script
# s'arrête sur « aucune capture » devant un dossier plein.
SUFFIXES = {".png", ".jpg", ".jpeg"}

# LA PALETTE DE MARQUE EST LUE, PLUS RECOPIÉE.
#
# Elle ne l'était même pas : ce fichier portait bien un `ROSE` et un `VIOLET`, écrits deux fois
# avec deux valeurs différentes — et ni l'un ni l'autre n'était LU. Le dégradé réellement dessiné
# par le fond était trois littéraux à part, réglés à la main le jour où le châssis est né et
# jamais retouchés depuis. Quand le rose de marque a changé de teinte, les quatre copies Swift ont
# suivi (`check_accent.py` les tient ensemble) ; ce fichier-ci, non — et c'est lui qui fabrique la
# seule surface que les gens voient AVANT d'installer.
#
# Plutôt que d'en faire une cinquième copie à surveiller, on lit la source. Une copie qui n'existe
# pas ne peut pas dériver. L'import marche parce que `check_accent` ne dépend que de la
# bibliothèque standard et que les deux fichiers sont voisins — c'est déjà ainsi que
# `test_accent.py` l'utilise.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_accent as accents  # noqa: E402


def _rgb(hexa: str) -> tuple:
    """« 0xff0a78 » → (255, 10, 120)."""
    v = int(hexa, 16)
    return (v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)


def _sombre(rgb: tuple, facteur: float) -> tuple:
    return tuple(max(0, min(255, round(c * facteur))) for c in rgb)


# Les trois couleurs du nuancier « rose » : le primaire, sa variante claire, et la queue violette
# des dégradés. Exactement ce que l'app affiche.
_PALETTE = accents.nuanciers(accents.SOURCE.read_text(encoding="utf-8"))["rose"]
PRIMAIRE = _rgb(_PALETTE[0])
CLAIR = _rgb(_PALETTE[1])
QUEUE = _rgb(_PALETTE[2])

# L'encre du fond. Pas un accent, donc absente d'`AccentTheme` — et la valeur qui s'appliquait
# vraiment était celle du SECOND bloc de constantes, plus bas, qui écrasait silencieusement le
# premier. Les deux blocs sont fondus en un seul.
INK = (10, 10, 14)


# --- Le châssis -------------------------------------------------------------------------------
# Proportions relevées sur un iPhone 16 Pro Max : dalle de 430 × 932 pt, coins de 55 pt, îlot
# dynamique de 125 × 36 pt posé à 11 pt du bord haut. Tout est exprimé en fraction de la LARGEUR
# de la dalle, pour que le cadre reste juste à n'importe quelle échelle de rendu.
# Le rayon des coins est le détail qui décide de tout : à 5 % de la largeur on obtient une carte
# aux angles adoucis, à 12,8 % on obtient un téléphone.
SCREEN_RADIUS = 55 / 430
BEZEL = 0.030
ISLAND_W = 125 / 430
ISLAND_H = 36 / 430
ISLAND_TOP = 11 / 430

# Le titane noir vu de face : une bande sombre bordée de deux arêtes vives. Ce sont ces deux
# traits clairs, et eux seuls, qui font lire « métal » plutôt que « rectangle gris ».
RAIL = [
    (0.000, (58, 58, 60)),
    (0.012, (150, 150, 156)),
    (0.030, (40, 40, 42)),
    (0.500, (74, 74, 77)),
    (0.970, (40, 40, 42)),
    (0.988, (150, 150, 156)),
    (1.000, (58, 58, 60)),
]

# Les boutons, en fraction de la hauteur du châssis. À gauche le bouton Action puis les deux
# touches de volume ; à droite le bouton latéral, plus long et décalé vers le bas.
BUTTONS_LEFT = [(0.128, 0.165), (0.196, 0.258), (0.272, 0.334)]
BUTTONS_RIGHT = [(0.210, 0.305)]


def natural(name: str) -> list:
    """Trie `IMG_9.PNG` avant `IMG_10.PNG`, et `2.png` avant `10.png`.

    Un tri alphabétique place `10` avant `2`, ce qui suffit à coller la mauvaise accroche sur la
    mauvaise capture — une erreur invisible tant qu'on ne regarde pas les six images une par une.
    """
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", name)]


def ramp(stops: list, t: float) -> tuple:
    """La couleur d'un dégradé à arrêts, à la position `t`."""
    if t <= stops[0][0]:
        return stops[0][1]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t0 <= t <= t1:
            k = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            return tuple(int(c0[i] + (c1[i] - c0[i]) * k) for i in range(3))
    return stops[-1][1]


def linear(size: tuple, stops: list, horizontal: bool = False) -> Image.Image:
    """Un dégradé à arrêts, dessiné sur une seule ligne puis étiré.

    Pillow n'a pas de primitive de dégradé ; peindre pixel par pixel une image de 1290 × 2796 en
    coûterait trois millions. Une ligne suffit, le redimensionnement fait le reste.
    """
    w, h = size
    n = w if horizontal else h
    strip = Image.new("RGB", (n, 1))
    px = strip.load()
    for i in range(n):
        px[i, 0] = ramp(stops, i / max(1, n - 1))
    if not horizontal:
        strip = strip.rotate(-90, expand=True)
    return strip.resize(size, Image.BICUBIC)


# L'ENCRE ET LE PAPIER.
#
# Le fond était le rose de marque, plein cadre, six fois. C'est ce qui faisait du rose l'identité
# de RUNUP avant même qu'on ouvre l'app — et une identité qui tient dans un magenta saturé est
# une identité où tout le monde ne se reconnaît pas.
#
# Le fond est désormais un os très légèrement dégradé, les captures sont prises en thème CLAIR,
# et la typographie est à l'encre. Le rose n'a pas disparu : il est resté là où il veut dire
# quelque chose — dans l'app elle-même, qu'on voit par l'écran, et sur le point d'ARRIVÉE de la
# trace, une seule fois sur les six images. Un accent est un accent quand il est rare.
PAPIER = [(0.00, (246, 243, 236)), (0.45, (234, 230, 221)),
          (0.75, (238, 234, 226)), (1.00, (244, 240, 232))]
ENCRE = (22, 22, 28)
# LE ROSE SE FONCE SUR UN FOND CLAIR, et ce n'est pas un choix de goût : c'est la correction que
# l'app s'applique déjà à elle-même (`AccentTheme.primaryOnLight`, lu par `RUColor.rose` en thème
# clair). Le rose de marque posé tel quel sur l'os descend sous le seuil de lisibilité pour un
# texte de 28 px ; foncé, il reste la même couleur et se lit.
ROSE_SUR_CLAIR = _sombre(PRIMAIRE, 0.86)
ENCRE_TRACE = [(0.00, (38, 42, 50)), (0.55, (58, 62, 74)), (0.86, (112, 86, 172)), (1.00, PRIMAIRE)]


@lru_cache(maxsize=None)
def bande(bandeau: str) -> Image.Image:
    """Le fond, les deux filets et la ligne courante, dessinés une fois sur les six cadres.

    Mis en cache : composer les six cadres redessinerait sinon six fois une image de 7740 px de
    large, dont cinq sixièmes seraient jetés à chaque fois.
    """
    bw, bh = BANDE
    strip = linear(BANDE, PAPIER, horizontal=True).convert("RGBA")
    d = ImageDraw.Draw(strip)

    for y in (FILET_HAUT, FILET_BAS):
        d.rectangle((0, y, bw, y + FILET - 1), fill=ENCRE + (34,))

    # LA LIGNE COURANTE. Répétée jusqu'à couvrir la bande entière : ce qui compte n'est pas de la
    # lire en entier mais qu'elle ne s'arrête jamais, pour qu'aucun cadre ne commence ni ne finisse
    # sur du vide. Le dernier segment visible passe au rose de marque — la seule couleur de toute
    # la fiche en dehors des écrans eux-mêmes, et elle tombe là où l'œil finit sa course.
    if bandeau:
        police = ImageFont.truetype(str(FONTS / "DMMono-Medium.ttf"), BANDEAU_TAILLE)
        motif = bandeau.strip() + "   ·   "
        largeur = tracked_width(d, motif, police, BANDEAU_CHASSE)
        depart = -largeur * 0.35     # décalé, pour qu'aucun cadre ne tombe sur un début de phrase
        positions = []
        x = depart
        while x < bw:
            positions.append(x)
            x += largeur
        for i, x in enumerate(positions):
            dernier = i == len(positions) - 1
            tracked(d, (x, BANDEAU_LIGNE), motif, police,
                    (ROSE_SUR_CLAIR + (255,)) if dernier else ENCRE + (85,), BANDEAU_CHASSE)
    return strip


def cadre(rang: int, bandeau: str) -> Image.Image:
    """La tranche de la bande qui revient à ce rang."""
    x = (rang - 1) * CANVAS[0]
    return bande(bandeau).crop((x, 0, x + CANVAS[0], CANVAS[1])).copy()


def wrap(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, width: int,
         tracking: float = 0.0) -> list[str]:
    """Coupe l'accroche en lignes qui tiennent dans `width`.

    On mesure le texte réellement rendu plutôt que de compter les caractères : les accroches sont
    traduites, et une ligne qui tient en anglais déborde souvent en français.

    Le retour à la ligne fonctionne, et c'est bien le problème : il absorbe silencieusement une
    accroche trop longue. Deux sous-titres débordaient de huit et de quatre-vingt-douze pixels,
    et se retrouvaient sur deux lignes dont la seconde ne portait qu'un mot — « semaine. »,
    « temps. » — au milieu d'un jeu où les autres tenaient sur une ligne. Personne ne l'avait vu
    parce que rien ne le disait : l'image se composait sans broncher.
    """
    # LE RESSERREMENT COMPTE DANS LA MESURE, et il ne comptait pas.
    #
    # Le titre est tracé lettre par lettre avec une chasse négative (voir `tracked`) : il occupe
    # donc MOINS de place que ce que `textlength` annonce. Mesuré sans, un titre de 1 091 px
    # réellement rendus en annonçait 1 113 et passait à la ligne pour vingt-deux pixels qui
    # n'existent pas. Le défaut est muet — la coupure a l'air d'un choix.
    lines: list[str] = []
    line = ""
    for word in text.split():
        candidate = f"{line} {word}".strip()
        if tracked_width(draw, candidate, font, tracking) <= width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def tracked(draw: ImageDraw.ImageDraw, xy: tuple, text: str, font: ImageFont.FreeTypeFont,
            fill: tuple, tracking: float) -> None:
    """Écrit `text` en resserrant les lettres de `tracking` pixels.

    Une police d'interface est espacée pour se lire à 15 px. Aux 76 px d'un titre, ce même
    espacement fait flotter les lettres ; les afficheurs le resserrent toujours un peu. Pillow ne
    sait pas le faire, d'où le tracé caractère par caractère.
    """
    x, y = xy
    for char in text:
        draw.text((x, y), char, font=font, fill=fill)
        x += draw.textlength(char, font=font) + tracking


def tracked_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont,
                  tracking: float) -> float:
    return sum(draw.textlength(c, font=font) for c in text) + tracking * (len(text) - 1)


def device(shot: Image.Image, screen_w: int) -> tuple:
    """Habille une capture d'un châssis d'iPhone.

    Renvoie l'appareil en RGBA, son masque, et l'épaisseur du châssis — le masque sert à poser
    l'ombre exactement sous la silhouette, pas sous un rectangle.
    """
    scale = screen_w / shot.width
    sw, sh = screen_w, round(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS).convert("RGBA")

    b = max(2, round(sw * BEZEL))
    dw, dh = sw + 2 * b, sh + 2 * b
    r_screen = sw * SCREEN_RADIUS
    r_device = r_screen + b

    silhouette = Image.new("L", (dw, dh), 0)
    ImageDraw.Draw(silhouette).rounded_rectangle((0, 0, dw - 1, dh - 1), radius=r_device, fill=255)

    body = Image.new("RGBA", (dw, dh), (0, 0, 0, 0))
    body.paste(linear((dw, dh), RAIL, horizontal=True).convert("RGBA"), (0, 0), silhouette)

    # Le joint noir entre le titane et la dalle. Sans lui l'écran a l'air imprimé sur le métal.
    ImageDraw.Draw(body).rounded_rectangle(
        (b - 3, b - 3, dw - b + 2, dh - b + 2), radius=r_screen + 3, outline=(0, 0, 0, 255), width=3
    )

    screen_mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=r_screen, fill=255)
    body.paste(shot, (b, b), screen_mask)

    # L'îlot dynamique, posé par-dessus : il occupe le creux que la barre d'état laisse au milieu,
    # entre l'heure et les icônes — il ne recouvre donc rien.
    iw, ih = sw * ISLAND_W, sw * ISLAND_H
    ix, iy = b + (sw - iw) / 2, b + sw * ISLAND_TOP
    ImageDraw.Draw(body).rounded_rectangle((ix, iy, ix + iw, iy + ih), radius=ih / 2, fill=(0, 0, 0, 255))

    return body, silhouette, b


# --- La barre d'état -----------------------------------------------------------------------
#
# Une capture prise sur un vrai téléphone porte l'heure qu'il était, le niveau de réseau du
# moment, et surtout les pastilles d'état de son propriétaire — la cloche barrée du mode
# silencieux, une alarme, un enregistrement en cours. C'est le détail qui fait lire « quelqu'un a
# photographié son téléphone » là où la fiche d'à côté dit « photo de produit ». Apple lui-même
# fige 9:41 dans tous ses visuels depuis la première keynote de l'iPhone.
#
# On repeint donc la bande haute avec la couleur de fond de l'app, et on la redessine : l'heure à
# gauche, réseau plein, wifi, batterie pleine à droite. Rien n'est ajouté que la capture n'ait eu ;
# on retire ce qui n'appartient qu'à ce téléphone-là.
STATUS_BAND = 185 / 2868      # fraction de la HAUTEUR de la capture
STATUS_MID = 98 / 2868


def _status_ink(shot: Image.Image) -> tuple:
    """La couleur du fond de la barre, prise sur les toutes premières lignes.

    Les trois premières rangées de pixels sont du fond, quel que soit l'écran : rien de l'app n'y
    monte, pas même l'îlot dynamique, qui commence plus bas.
    """
    w = shot.width
    sample = [shot.getpixel((x, y)) for y in (2, 6, 10) for x in range(4, w - 4, max(1, w // 40))]
    return max(set(sample), key=sample.count)


def clean_status_bar(shot: Image.Image) -> Image.Image:
    shot = shot.copy()
    w, h = shot.size
    band = round(h * STATUS_BAND)
    mid = round(h * STATUS_MID)
    bg = _status_ink(shot)
    ink = (255, 255, 255) if sum(bg) < 384 else (0, 0, 0)

    draw = ImageDraw.Draw(shot)
    draw.rectangle((0, 0, w, band), fill=bg)

    size = round(w * 0.042)
    font = ImageFont.truetype(str(FONTS / "Inter-SemiBold.ttf"), size)
    draw.text((round(w * 0.082), mid), "9:41", font=font, fill=ink, anchor="lm")

    unit = w / 430          # un point de la dalle, en pixels
    right = w - round(unit * 27)

    # La batterie : coque, téton, et le plein à l'intérieur.
    bw, bh = round(unit * 25), round(unit * 12)
    x1, y0 = right, mid - bh // 2
    draw.rounded_rectangle((x1 - bw, y0, x1, y0 + bh), radius=round(unit * 3.5),
                           outline=ink, width=max(1, round(unit * 1.1)))
    draw.rounded_rectangle((x1 - bw + round(unit * 2), y0 + round(unit * 2),
                            x1 - round(unit * 2), y0 + bh - round(unit * 2)),
                           radius=round(unit * 1.6), fill=ink)
    draw.rounded_rectangle((x1 + round(unit * 1.2), mid - round(unit * 2.6),
                            x1 + round(unit * 3), mid + round(unit * 2.6)),
                           radius=round(unit * 1.2), fill=ink)

    # Le wifi : trois arcs et un point, dessinés d'un seul geste angulaire.
    cx = x1 - bw - round(unit * 12)
    cy = mid + round(unit * 5)
    for i, r in enumerate((unit * 10.5, unit * 6.8, unit * 3.1)):
        draw.arc((cx - r, cy - r, cx + r, cy + r), start=218, end=322,
                 fill=ink, width=max(1, round(unit * 1.9)))
    draw.ellipse((cx - unit * 1.1, cy - unit * 1.1, cx + unit * 1.1, cy + unit * 1.1), fill=ink)

    # Le réseau : quatre barres croissantes, toutes pleines.
    bar_w = unit * 3.1
    gap = unit * 1.7
    base = mid + unit * 5.2
    left = cx - unit * 10.5 - gap * 2 - (bar_w + gap) * 4
    for i in range(4):
        height = unit * (3.4 + i * 2.6)
        x = left + i * (bar_w + gap)
        draw.rounded_rectangle((x, base - height, x + bar_w, base),
                               radius=unit * 1.1, fill=ink)
    return shot


def _accroche(canvas: Image.Image, caption, rang: int, total: int) -> None:
    """Le numéro, le titre et le sous-titre, calés à gauche sur la même marge."""
    titre, sous = (caption, "") if isinstance(caption, str) else (caption[0], caption[1])
    draw = ImageDraw.Draw(canvas)

    # « 03 / 06 ». Une numérotation ne se met pas pour décorer : celle-ci dit une chose vraie —
    # ces six images sont une suite, et se lisent dans l'ordre. En chasse fixe, comme tous les
    # chiffres de l'app.
    rang_font = ImageFont.truetype(str(FONTS / "DMMono-Medium.ttf"), EYEBROW_TAILLE)
    tracked(draw, (MARGE, TITRE_HAUT - 62), f"{rang:02d} / {total:02d}", rang_font,
            ENCRE + (105,), EYEBROW_CHASSE)

    # LE BLOC DE TEXTE A UNE HAUTEUR FIXE, et le titre s'y aligne par le BAS.
    #
    # Quatre titres tenaient sur deux lignes, deux sur une : le sous-titre, le filet et tout ce
    # qui suit descendaient donc de 126 px sur deux images. Dans le carrousel, où l'on voit les
    # images l'une après l'autre au même endroit de l'écran, c'est un sautillement — et c'est
    # exactement ce que la même règle corrige déjà pour l'appareil, posé à hauteur fixe.
    titre_font = ImageFont.truetype(str(TITRE_POLICE), TITRE_TAILLE)
    lignes = wrap(draw, titre, titre_font, CANVAS[0] - MARGE * 2, TITRE_CHASSE)
    y = TITRE_HAUT + (TITRE_LIGNES - len(lignes)) * TITRE_INTERLIGNE
    for ligne in lignes:
        tracked(draw, (MARGE, y), ligne, titre_font, ENCRE + (255,), TITRE_CHASSE)
        y += TITRE_INTERLIGNE

    if sous:
        sous_font = ImageFont.truetype(str(FONTS / "Inter-Light.ttf"), SOUS_TAILLE)
        y = TITRE_HAUT + TITRE_LIGNES * TITRE_INTERLIGNE + 18
        for ligne in wrap(draw, sous, sous_font, CANVAS[0] - MARGE * 2):
            draw.text((MARGE, y), ligne, font=sous_font, fill=ENCRE + (155,))
            y += SOUS_INTERLIGNE


def _bande_agrandie(canvas: Image.Image, shot: Image.Image, zone: tuple, rang: int) -> None:
    """Un morceau de l'écran, agrandi et coupé par les deux bords du cadre."""
    w, h = shot.size
    x0, y0, x1, y1 = (round(zone[0] * w), round(zone[1] * h), round(zone[2] * w), round(zone[3] * h))
    morceau = shot.crop((x0, y0, x1, y1))
    largeur = CANVAS[0] - 2 * MARGE
    hauteur = round(largeur * morceau.height / morceau.width)
    morceau = morceau.resize((largeur, hauteur), Image.LANCZOS).convert("RGBA")
    rayon = 30
    masque = Image.new("L", morceau.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle((0, 0, largeur - 1, hauteur - 1), rayon, fill=255)
    morceau.putalpha(masque)

    gauche, haut = MARGE, BANDE_CENTRE - hauteur // 2
    ombre = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    tache = Image.new("RGBA", morceau.size, (0, 0, 0, 0))
    tache.paste((0, 0, 0, 120), (0, 0), masque)
    ombre.alpha_composite(tache, (gauche, haut + 26))
    canvas.alpha_composite(ombre.filter(ImageFilter.GaussianBlur(34)))
    ImageDraw.Draw(morceau).rounded_rectangle((0, 0, largeur - 1, hauteur - 1), rayon,
                                              outline=ENCRE + (40,), width=3)
    canvas.alpha_composite(morceau, (gauche, haut))
    print(f"  bande : {x1 - x0}×{y1 - y0} px de la capture, agrandie ×{largeur / (x1 - x0):.2f}")


def _appareil(canvas: Image.Image, shot: Image.Image) -> None:
    """L'écran entier, dans son châssis, au centre du cadre."""
    body, silhouette, b = device(shot, screen_w=SCREEN_W)
    dw, dh = body.size
    gauche, haut = (CANVAS[0] - dw) // 2, DEVICE_TOP

    visible = max(0, CANVAS[1] - DEVICE_BOTTOM_MARGIN - haut)
    if dh > visible:
        print(f"  ⚠ appareil recadré de {dh - visible} px en bas — capture plus haute que prévu.",
              file=sys.stderr)
        body, silhouette, dh = body.crop((0, 0, dw, visible)), silhouette.crop((0, 0, dw, visible)), visible

    # Les boutons, dessinés AVANT l'appareil : ils dépassent du châssis, qui les recouvre à demi.
    onglet = max(3, round(b * 0.62))
    boutons = ImageDraw.Draw(canvas)
    for cote, bornes in ((0, BUTTONS_LEFT), (1, BUTTONS_RIGHT)):
        for lo, hi in bornes:
            y0, y1 = haut + dh * lo, haut + dh * hi
            if cote == 0:
                boutons.rounded_rectangle((gauche - onglet, y0, gauche + b, y1), radius=onglet,
                                          fill=(146, 146, 152))
            else:
                boutons.rounded_rectangle((gauche + dw - b, y0, gauche + dw + onglet, y1),
                                          radius=onglet, fill=(146, 146, 152))

    ombre = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ombre.paste(Image.new("RGBA", (dw, dh), (0, 0, 0, 120)), (gauche, haut + 26), silhouette)
    canvas.alpha_composite(ombre.filter(ImageFilter.GaussianBlur(40)))
    canvas.alpha_composite(body, (gauche, haut))


def compose(shot_path: Path, caption, dest: Path, rang: int, total: int, bandeau: str = "") -> None:
    """Une image de la fiche : sa tranche de bande, son accroche, et son écran ou son gros plan.

    Deux étages d'accroche. Le titre porte la promesse, le sous-titre l'explique à qui s'arrête :
    dans le carrousel on voit deux images et demie d'un coup, en diagonale, et ce qui n'est pas
    saisi d'un balayage n'est pas lu du tout.

    Une accroche restée sous forme de chaîne simple est acceptée et rendue sans sous-titre : le
    format a changé une fois, et le composeur n'a pas à casser sur un fichier écrit dans l'ancien.
    """
    canvas = cadre(rang, bandeau)
    _accroche(canvas, caption, rang, total)
    shot = clean_status_bar(Image.open(shot_path).convert("RGB"))
    if rang in BANDES:
        _bande_agrandie(canvas, shot, BANDES[rang], rang)
    else:
        _appareil(canvas, shot)
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(dest, "PNG")


def accroches(bloc) -> list:
    """Les six accroches d'une langue.

    Le fichier a porté deux formes : une liste d'accroches, puis un bloc qui porte aussi la ligne
    courante. Les deux se lisent, parce qu'un composeur qui casse sur un fichier écrit dans la
    forme d'avant transforme une évolution de format en panne.
    """
    return bloc["accroches"] if isinstance(bloc, dict) else bloc


def ruban(bloc) -> str:
    """La ligne courante d'une langue, vide quand le fichier est à l'ancienne forme."""
    return bloc.get("bandeau", "") if isinstance(bloc, dict) else ""


def overflowing_captions(captions: dict) -> list[str]:
    """Les accroches qui ne tiennent pas dans la place réservée, toutes langues confondues.

    La mise en page réserve DEUX lignes au titre et UNE au sous-titre. Le contrôle mesure donc
    cela, et pas autre chose : il refusait des titres de deux lignes à l'époque où la place n'en
    réservait qu'une, et il aurait laissé passer un sous-titre de deux depuis.
    """
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    title_font = ImageFont.truetype(str(TITRE_POLICE), TITRE_TAILLE)
    sub_font = ImageFont.truetype(str(FONTS / "Inter-Light.ttf"), SOUS_TAILLE)
    out: list[str] = []
    for locale, bloc in sorted(captions.items()):
        items = accroches(bloc)
        for rank, caption in enumerate(items, start=1):
            title, subtitle = (caption, "") if isinstance(caption, str) else (caption[0], caption[1])
            for label, text, font, width, maxi in (
                ("titre", title, title_font, CANVAS[0] - MARGE * 2, TITRE_LIGNES),
                ("sous-titre", subtitle, sub_font, CANVAS[0] - MARGE * 2, 1),
            ):
                if not text:
                    continue
                lignes = len(wrap(probe, text, font, width,
                                  TITRE_CHASSE if label == "titre" else 0.0))
                if lignes > maxi:
                    out.append(f"{locale} n°{rank} {label} : {lignes} lignes pour {maxi} — « {text} »")
    return out


def main() -> int:
    lang = sys.argv[1] if len(sys.argv) > 1 else "fr-FR"

    if not CAPTIONS.exists():
        print(f"Fichier d'accroches introuvable : {CAPTIONS}", file=sys.stderr)
        return 1
    captions = json.loads(CAPTIONS.read_text(encoding="utf-8"))
    if lang not in captions:
        print(f"Langue inconnue : {lang}. Connues : {', '.join(sorted(captions))}", file=sys.stderr)
        return 1

    # TOUTES les langues sont vérifiées, pas seulement celle qu'on compose.
    #
    # Une accroche trop longue ne casse rien : `wrap` la coupe, et l'image sort. C'est exactement
    # ce qui rendait le défaut invisible — deux sous-titres débordaient de huit et de quatre-vingt-
    # douze pixels, et se retrouvaient sur deux lignes dont la seconde ne portait qu'un mot, au
    # milieu d'un jeu où les autres tenaient sur une ligne. Un titre anglais et un titre espagnol
    # débordaient aussi, sans que personne ne compose jamais ces langues-là pour s'en apercevoir.
    #
    # C'est un avertissement et non une erreur : une accroche sur deux lignes reste parfois le bon
    # choix. Ce qu'on veut, c'est que ce soit une décision et non une surprise.
    if too_long := overflowing_captions(captions):
        print("\nAccroches qui passeront à la ligne :", file=sys.stderr)
        for line in too_long:
            print(f"  {line}", file=sys.stderr)
        print("", file=sys.stderr)

    # Une série de captures par langue : l'app est traduite, et une interface en français sous une
    # accroche en anglais coûte l'installation au moment où la personne fait défiler le carrousel.
    # À défaut de dossier pour la langue demandée, on retombe sur les captures posées à la racine —
    # utile tant qu'une seule série existe.
    # LA FICHE SE COMPOSE SUR LA SÉRIE CLAIRE.
    #
    # Le thème clair n'était photographié qu'en français, après la composition, comme outil de
    # travail. C'est lui qui livre maintenant : le fond os de la fiche appelle des captures
    # claires, et un écran sombre posé dessus ferait six trous noirs. La passe claire est donc
    # devenue la source, pour les trois langues, et passe AVANT la composition.
    #
    # Le repli reste, dans l'ordre : la série claire de la langue, la série sombre de la langue,
    # puis les fichiers posés à la racine. Un repli qui se tait serait pire que l'absence : le
    # composeur dit lequel il a pris.
    for folder in (RAW / lang / "clair", RAW / lang, RAW):
        if folder.is_dir() and any(p.is_file() and p.suffix.lower() in SUFFIXES for p in folder.iterdir()):
            break
    shots = sorted(
        (p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in SUFFIXES),
        key=lambda p: natural(p.name),
    )
    if not shots:
        print(
            f"Aucune capture dans {folder}. Dépose les captures prises en {lang} puis relance.",
            file=sys.stderr,
        )
        return 1
    print(f"Captures lues dans {folder.relative_to(ROOT)}")

    # L'ordre est celui des accroches : le dire à voix haute évite de découvrir l'inversion sur la
    # fiche publiée plutôt qu'ici.
    print(f"Ordre retenu : {', '.join(p.name for p in shots)}\n")

    texts = accroches(captions[lang])
    bandeau = ruban(captions[lang])

    # Le rang vient du nom du fichier quand il commence par un chiffre — `4-club.png` reçoit la
    # quatrième accroche, où qu'il soit dans le dossier et quoi qu'il manque autour.
    #
    # L'appariement par position seul est un piège : à six accroches et cinq captures, la capture
    # du partage hérite de l'accroche du club, les suivantes décalent, et rien ne le signale. On
    # ne s'en aperçoit qu'en regardant la fiche publiée. Tant que les captures viennent d'un
    # iPhone et s'appellent `IMG_9143.PNG`, le repli positionnel reste le seul choix possible.
    ranked: dict[int, Path] = {}
    for shot in shots:
        digits = ""
        for char in shot.name:
            if not char.isdigit():
                break
            digits += char
        if not digits:
            continue
        rank = int(digits)
        # Deux fichiers pour le même rang, et il faut s'arrêter.
        #
        # Le cas n'a rien de théorique : l'iPhone nomme ses captures en `.PNG`, le dossier
        # contenait des `.png`, et `1-accueil.PNG` a cohabité avec `1-accueil.png` — l'ancienne
        # version de l'écran et la nouvelle, côte à côte, revendiquant la même accroche. En
        # écrasant silencieusement, le composeur aurait choisi selon l'ordre de tri, c'est-à-dire
        # au hasard du point de vue de qui dépose les fichiers, et aurait pu publier l'ancienne.
        if rank in ranked:
            print(f"Deux captures pour le rang {rank} : {ranked[rank].name} et {shot.name}. "
                  f"Supprime celle qui n'a plus lieu d'être.", file=sys.stderr)
            return 1
        ranked[rank] = shot

    if ranked and len(ranked) == len(shots):
        unknown = sorted(r for r in ranked if not 1 <= r <= len(texts))
        if unknown:
            print(
                f"Rangs hors des {len(texts)} accroches de {lang} : "
                f"{', '.join(str(r) for r in unknown)}.",
                file=sys.stderr,
            )
            return 1
        pairs = [(ranked[r], texts[r - 1], r) for r in sorted(ranked)]
        manquants = [r for r in range(1, len(texts) + 1) if r not in ranked]
        if manquants:
            print(f"Rangs encore absents : {', '.join(str(r) for r in manquants)}.\n")
    else:
        if len(shots) > len(texts):
            print(
                f"{len(shots)} captures pour {len(texts)} accroches en {lang} : ajoute des "
                f"accroches dans appstore/captions.json, ou retire des captures.",
                file=sys.stderr,
            )
            return 1
        pairs = [(shot, text, i) for i, (shot, text) in enumerate(zip(shots, texts), start=1)]

    dest_dir = OUT / lang
    for shot, caption, index in pairs:
        dest = dest_dir / f"{index}.png"
        compose(shot, caption, dest, index, len(pairs), bandeau)
        shown = caption if isinstance(caption, str) else f"{caption[0]} — {caption[1]}"
        print(f"{shot.name} → {dest.relative_to(ROOT)}   « {shown} »")

    print(f"\n{len(pairs)} captures composées dans {dest_dir.relative_to(ROOT)} ({CANVAS[0]}×{CANVAS[1]}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
