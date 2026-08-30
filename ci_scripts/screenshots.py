#!/usr/bin/env python3
"""Compose les captures de l'App Store à partir de captures brutes.

Une capture brute est une capture d'écran : ce que les gens voient sur la fiche App Store est
une image composée — fond de marque, accroche, téléphone qui déborde du cadre. Ce script fait
la seconde à partir de la première, et tourne depuis l'onglet Actions comme le reste, pour ne
pas avoir à ouvrir un terminal.

    Entrée  : appstore/raw/1.png … 6.png   (captures prises sur l'iPhone)
              appstore/captions.json       (les accroches, par langue)
    Sortie  : appstore/out/<langue>/1.png … (1290 × 2796, prêtes pour App Store Connect)

    python3 ci_scripts/screenshots.py fr-FR

Le format 1290 × 2796 est celui de l'iPhone 15/16 Pro Max. C'est la seule taille qu'Apple exige
encore : les autres tailles d'iPhone sont dérivées automatiquement de celle-ci.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "appstore" / "raw"
OUT = ROOT / "appstore" / "out"
CAPTIONS = ROOT / "appstore" / "captions.json"
FONTS = ROOT / "RunUp" / "Resources" / "Fonts"

CANVAS = (1290, 2796)

# La hauteur à laquelle le châssis commence, sur les six images sans exception.
DEVICE_TOP = 600

# Les captures viennent d'un iPhone, où elles s'appellent `IMG_0042.PNG` — extension EN MAJUSCULES.
# Un `glob("*.png")` ne les voit pas sur le runner Linux, qui distingue la casse, et le script
# s'arrête sur « aucune capture » devant un dossier plein.
SUFFIXES = {".png", ".jpg", ".jpeg"}

# La palette de marque, reprise telle quelle de `AccentTheme.swift` (id « rose »). Le dégradé va
# du rose primaire vers le « tail » violet, exactement comme les dégradés de l'app.
ROSE = (0xFF, 0x0F, 0x5B)
VIOLET = (0x7C, 0x5C, 0xFF)
INK = (0x0B, 0x0B, 0x0F)


# --- Le châssis -------------------------------------------------------------------------------
#
# Proportions relevées sur un iPhone 16 Pro Max : dalle de 430 × 932 pt, coins de 55 pt, îlot
# dynamique de 125 × 36 pt posé à 11 pt du bord haut. Tout est exprimé en fraction de la LARGEUR
# de la dalle, pour que le cadre reste juste à n'importe quelle échelle de rendu.
#
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

INK = (10, 10, 14)
ROSE = (0xFF, 0x0F, 0x5B)
VIOLET = (0x7C, 0x5C, 0xFF)


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


def glow(size: tuple, color: tuple, strength: float = 1.0) -> Image.Image:
    """Un halo circulaire, en calque RGBA.

    Construit en 256 px puis agrandi : une centaine d'ellipses concentriques suffisent à un
    dégradé lisse une fois interpolées, et évitent d'en dessiner des milliers à taille réelle.
    """
    s = 256
    field = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(field)
    steps = 120
    for i in range(steps, 0, -1):
        t = i / steps
        r = t * s / 2
        d.ellipse((s / 2 - r, s / 2 - r, s / 2 + r, s / 2 + r), fill=int(255 * strength * (1 - t) ** 2))
    layer = Image.new("RGBA", size, color + (0,))
    layer.putalpha(field.resize(size, Image.BICUBIC))
    return layer


def scene() -> Image.Image:
    """Le fond : le dégradé de marque, éclairé derrière l'épaule de l'appareil.

    Le halo clair ne décore pas — il sépare. Sur un aplat uniforme, un téléphone noir se découpe
    par son ombre seule ; une zone plus claire derrière ses coins hauts lui donne un relief que
    l'ombre ne suffit pas à produire.
    """
    canvas = linear(CANVAS, [(0.0, (255, 26, 100)), (0.55, (222, 30, 120)), (1.0, (110, 82, 255))])
    canvas = canvas.convert("RGBA")
    canvas.alpha_composite(glow((2200, 2200), (255, 140, 190), 0.45), (-455, -300))
    return canvas.convert("RGB")


def wrap(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, width: int) -> list[str]:
    """Coupe l'accroche en lignes qui tiennent dans `width`.

    On mesure le texte réellement rendu plutôt que de compter les caractères : les accroches sont
    traduites, et une ligne qui tient en anglais déborde souvent en français.
    """
    lines: list[str] = []
    line = ""
    for word in text.split():
        candidate = f"{line} {word}".strip()
        if draw.textlength(candidate, font=font) <= width or not line:
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


def compose(shot_path: Path, caption, dest: Path) -> None:
    """Compose une capture sous son accroche.

    L'accroche tient sur deux étages : un titre court et gras, une phrase claire et légère en
    dessous. Sur une seule ligne d'un seul poids, une accroche de dix mots oblige à s'arrêter pour
    la lire — or dans le carrousel de l'App Store on voit deux images et demie d'un coup, en
    diagonale, et ce qui n'est pas saisi d'un balayage n'est pas lu du tout. Le titre porte la
    promesse, le sous-titre l'explique à qui s'arrête.

    Une accroche restée sous forme de chaîne simple est acceptée et rendue sans sous-titre : le
    format a changé, et le composeur n'a pas à casser sur un fichier écrit dans l'ancien.
    """
    title, subtitle = (caption, "") if isinstance(caption, str) else (caption[0], caption[1])

    canvas = scene().convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    font = ImageFont.truetype(str(FONTS / "Inter-Bold.ttf"), 82)
    tracking = -1.8
    margin = 96
    lines = wrap(draw, title, font, CANVAS[0] - margin * 2)

    # L'accroche d'abord : c'est elle qui fixe où commence l'appareil. Une accroche sur trois
    # lignes ne doit pas se retrouver recouverte par la capture.
    leading = 98
    y = 190
    for line in lines:
        w = tracked_width(draw, line, font, tracking)
        tracked(draw, ((CANVAS[0] - w) / 2, y), line, font, (255, 255, 255), tracking)
        y += leading

    # Le second étage, en blanc PLEIN. Il a d'abord été posé à 82 % pour qu'il ne dispute pas le
    # titre — et sur ce rose-là, ça le faisait tomber à 2,88:1, sous le plancher de 3:1 des grands
    # caractères. C'était creuser l'écart par le mauvais levier : la taille et la graisse suffisent
    # à dire « second », l'opacité ne fait que rendre illisible.
    if subtitle:
        sub_font = ImageFont.truetype(str(FONTS / "Inter-Light.ttf"), 48)
        sub_margin = 150
        y += 14
        for line in wrap(draw, subtitle, sub_font, CANVAS[0] - sub_margin * 2):
            w = draw.textlength(line, font=sub_font)
            draw.text(((CANVAS[0] - w) / 2, y), line, font=sub_font, fill=(255, 255, 255, 255))
            y += 62

    body, silhouette, b = device(clean_status_bar(Image.open(shot_path).convert("RGB")), screen_w=1046)
    dw, dh = body.size
    left = (CANVAS[0] - dw) // 2

    # Le châssis démarre TOUJOURS à la même hauteur, quelle que soit la longueur de l'accroche.
    #
    # Il suivait le bas du texte : une accroche dont le sous-titre passait sur deux lignes
    # repoussait l'appareil de soixante pixels. Sur les six images de la fiche, deux avaient donc
    # leur téléphone plus bas que les quatre autres — et dans le carrousel, où l'on fait défiler
    # une image après l'autre au même endroit de l'écran, l'appareil montait et descendait sous
    # l'œil. C'est ce sautillement, plus qu'aucun détail de rendu, qui fait qu'une fiche a l'air
    # montée à la main.
    #
    # La zone de texte est donc réservée, pas mesurée. Une accroche qui la déborderait se ferait
    # recouvrir : le composeur le dit plutôt que de la laisser passer.
    top = DEVICE_TOP
    if y > top - 40:
        print(f"  ⚠ accroche trop longue de {round(y - top + 40)} px — elle touchera l'appareil : "
              f"raccourcis le titre ou le sous-titre.", file=sys.stderr)

    # L'appareil sort par le bas. Le montrer en entier le réduirait à un objet posé au milieu du
    # cadre ; le laisser déborder donne la profondeur qu'ont les fiches qu'on prend pour modèle.
    visible = max(0, CANVAS[1] - top)
    if dh > visible:
        body = body.crop((0, 0, dw, visible))
        silhouette = silhouette.crop((0, 0, dw, visible))
        dh = visible

    # Les boutons, dessinés AVANT l'appareil : ils dépassent du châssis, qui les recouvre à demi.
    # Ils sont du métal, pas de l'ombre : peints sombres, ils se lisaient comme des taches posées
    # derrière le téléphone. Un gris clair les rattache à l'arête vive du châssis.
    tab = max(3, round(b * 0.62))
    full_h = round(1046 / Image.open(shot_path).width * Image.open(shot_path).height) + 2 * b
    buttons = ImageDraw.Draw(canvas)
    for lo, hi in BUTTONS_LEFT:
        y0, y1 = top + full_h * lo, top + full_h * hi
        buttons.rounded_rectangle((left - tab, y0, left + b, y1), radius=tab, fill=(146, 146, 152))
    for lo, hi in BUTTONS_RIGHT:
        y0, y1 = top + full_h * lo, top + full_h * hi
        buttons.rounded_rectangle((left + dw - b, y0, left + dw + tab, y1), radius=tab, fill=(146, 146, 152))

    # L'ombre suit la silhouette, pas un rectangle : c'est ce qui la rend crédible aux coins.
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    tinted = Image.new("RGBA", (dw, dh), (0, 0, 0, 150))
    shadow.paste(tinted, (left, top + 26), silhouette)
    shadow = shadow.filter(ImageFilter.GaussianBlur(42))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)

    canvas.alpha_composite(body, (left, top))

    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(dest, "PNG")


def main() -> int:
    lang = sys.argv[1] if len(sys.argv) > 1 else "fr-FR"

    if not CAPTIONS.exists():
        print(f"Fichier d'accroches introuvable : {CAPTIONS}", file=sys.stderr)
        return 1
    captions = json.loads(CAPTIONS.read_text(encoding="utf-8"))
    if lang not in captions:
        print(f"Langue inconnue : {lang}. Connues : {', '.join(sorted(captions))}", file=sys.stderr)
        return 1

    # Une série de captures par langue : l'app est traduite, et une interface en français sous une
    # accroche en anglais coûte l'installation au moment où la personne fait défiler le carrousel.
    # À défaut de dossier pour la langue demandée, on retombe sur les captures posées à la racine —
    # utile tant qu'une seule série existe.
    folder = RAW / lang
    if not folder.is_dir():
        folder = RAW
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

    texts = captions[lang]

    # Le rang vient du nom du fichier quand il commence par un chiffre — `4-club.png` reçoit la
    # quatrième accroche, où qu'il soit dans le dossier et quoi qu'il manque autour.
    #
    # L'appariement par position seul est un piège : à six accroches et cinq captures, la capture
    # du partage hérite de l'accroche du club, les suivantes décalent, et rien ne le signale. On
    # ne s'en aperçoit qu'en regardant la fiche publiée. Tant que les captures viennent d'un
    # iPhone et s'appellent `IMG_9143.PNG`, le repli positionnel reste le seul choix possible.
    ranked = {}
    for shot in shots:
        digits = ""
        for char in shot.name:
            if not char.isdigit():
                break
            digits += char
        if digits:
            ranked[int(digits)] = shot

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
        compose(shot, caption, dest)
        shown = caption if isinstance(caption, str) else f"{caption[0]} — {caption[1]}"
        print(f"{shot.name} → {dest.relative_to(ROOT)}   « {shown} »")

    print(f"\n{len(pairs)} captures composées dans {dest_dir.relative_to(ROOT)} ({CANVAS[0]}×{CANVAS[1]}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
