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

# Les captures viennent d'un iPhone, où elles s'appellent `IMG_0042.PNG` — extension EN MAJUSCULES.
# Un `glob("*.png")` ne les voit pas sur le runner Linux, qui distingue la casse, et le script
# s'arrête sur « aucune capture » devant un dossier plein.
SUFFIXES = {".png", ".jpg", ".jpeg"}

# La palette de marque, reprise telle quelle de `AccentTheme.swift` (id « rose »). Le dégradé va
# du rose primaire vers le « tail » violet, exactement comme les dégradés de l'app.
ROSE = (0xFF, 0x0F, 0x5B)
VIOLET = (0x7C, 0x5C, 0xFF)
INK = (0x0B, 0x0B, 0x0F)


def natural(name: str) -> list:
    """Trie `IMG_9.PNG` avant `IMG_10.PNG`, et `2.png` avant `10.png`.

    Un tri alphabétique place `10` avant `2`, ce qui suffit à coller la mauvaise accroche sur la
    mauvaise capture — une erreur invisible tant qu'on ne regarde pas les six images une par une.
    """
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", name)]


def gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """Un dégradé vertical. Dessiné en 1 px de large puis étiré : Pillow n'a pas de primitive."""
    w, h = size
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return strip.resize(size, Image.BICUBIC)


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


def compose(shot_path: Path, caption: str, dest: Path) -> None:
    canvas = gradient(CANVAS, ROSE, VIOLET)
    draw = ImageDraw.Draw(canvas)

    font = ImageFont.truetype(str(FONTS / "Inter-Bold.ttf"), 76)
    margin = 96
    lines = wrap(draw, caption, font, CANVAS[0] - margin * 2)

    # L'accroche d'abord : c'est elle qui fixe où commence le téléphone. Une accroche sur trois
    # lignes ne doit pas se retrouver recouverte par la capture.
    leading = 92
    y = 190
    for line in lines:
        w = draw.textlength(line, font=font)
        draw.text(((CANVAS[0] - w) / 2, y), line, font=font, fill=(255, 255, 255))
        y += leading

    shot = Image.open(shot_path).convert("RGB")

    # La largeur commande : une capture mise à l'échelle sur sa hauteur donne un timbre-poste au
    # milieu d'un aplat rose. Le téléphone occupe donc toute la largeur utile et déborde en bas
    # du cadre — c'est ce que font les fiches qu'on regarde comme référence.
    scale = (CANVAS[0] - margin * 2) / shot.width
    size = (int(shot.width * scale), int(shot.height * scale))
    shot = shot.resize(size, Image.LANCZOS)

    top = y + 120
    visible = max(0, CANVAS[1] - top)
    if size[1] > visible:
        shot = shot.crop((0, 0, size[0], visible))
        size = (size[0], visible)

    left = (CANVAS[0] - size[0]) // 2
    radius = 56

    # Le téléphone déborde par le bas : ses coins inférieurs sont hors cadre, et les arrondir sur
    # la ligne de coupe donnerait une carte posée au ras du bord plutôt qu'un appareil qui sort de
    # l'image. On dessine donc le rectangle plus haut que la découpe, pour que le bas tombe dehors.
    bleeds = size[1] >= visible
    bottom = size[1] - 1 + (radius * 2 if bleeds else 0)

    # Le masque arrondi sert deux fois : à détourer la capture, et à dessiner l'ombre portée.
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, bottom), radius=radius, fill=255)

    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, top + 18, left + size[0] - 1, top + bottom + 18), radius=radius, fill=(0, 0, 0, 110)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB")

    canvas.paste(shot, (left, top), mask)

    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest, "PNG")


def main() -> int:
    lang = sys.argv[1] if len(sys.argv) > 1 else "fr-FR"

    if not CAPTIONS.exists():
        print(f"Fichier d'accroches introuvable : {CAPTIONS}", file=sys.stderr)
        return 1
    captions = json.loads(CAPTIONS.read_text(encoding="utf-8"))
    if lang not in captions:
        print(f"Langue inconnue : {lang}. Connues : {', '.join(sorted(captions))}", file=sys.stderr)
        return 1

    shots = sorted(
        (p for p in RAW.iterdir() if p.is_file() and p.suffix.lower() in SUFFIXES),
        key=lambda p: natural(p.name),
    )
    if not shots:
        print(
            f"Aucune capture dans {RAW}. Dépose tes captures brutes puis relance.",
            file=sys.stderr,
        )
        return 1

    # L'ordre est celui des accroches : le dire à voix haute évite de découvrir l'inversion sur la
    # fiche publiée plutôt qu'ici.
    print(f"Ordre retenu : {', '.join(p.name for p in shots)}\n")

    texts = captions[lang]
    if len(shots) > len(texts):
        print(
            f"{len(shots)} captures pour {len(texts)} accroches en {lang} : ajoute des accroches "
            f"dans appstore/captions.json, ou retire des captures.",
            file=sys.stderr,
        )
        return 1

    dest_dir = OUT / lang
    for index, (shot, caption) in enumerate(zip(shots, texts), start=1):
        dest = dest_dir / f"{index}.png"
        compose(shot, caption, dest)
        print(f"{shot.name} → {dest.relative_to(ROOT)}   « {caption} »")

    print(f"\n{len(shots)} captures composées dans {dest_dir.relative_to(ROOT)} ({CANVAS[0]}×{CANVAS[1]}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
