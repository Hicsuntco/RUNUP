#!/usr/bin/env python3
"""Monte l'aperçu App Store : la fiche, mais animée.

    Entrée  : un enregistrement du simulateur, et une liste de plans
    Sortie  : un .mp4 de 886 × 1920, 30 i/s, H.264, prêt pour App Store Connect

    python3 ci_scripts/montage.py --entree brut.mov --sortie apercu.mp4 --plans plans.json

# POURQUOI UN MONTAGE, ET PAS LA CAPTATION

La première version envoyait l'enregistrement brut, conformé au format d'Apple. Verdict :
« niveau débutant ». Il était juste. Un enregistrement d'écran n'est pas un film — c'est
quelqu'un qui tapote des onglets. Pas de rythme, pas de cadrage, pas d'emphase, et surtout rien
de la fiche : ni le fond os, ni la typographie, ni les filets. Les captures et la vidéo
racontaient deux produits différents.

Ce script fait de la vidéo ce que `screenshots.py` fait des captures, et avec les MÊMES pièces :
le même fond, le même châssis d'appareil, la même police de titrage, les mêmes filets, la même
ligne courante. Une fiche qu'on fait défiler, et une vidéo qui se joue, doivent se reconnaître.

# COMMENT

Chaque plan est un morceau de l'enregistrement, posé dans l'écran du châssis, sur un fond
composé par Pillow — exactement l'image d'une capture, mais avec de la vidéo dans l'écran. Les
plans s'enchaînent par des coupes franches : un fondu entre deux plans de trois secondes mange
un cinquième du film pour ne rien dire.

Le titre de chaque plan entre par un glissement court. Le reste ne bouge pas : ce qui doit bouger
dans un aperçu d'app, c'est l'app.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import screenshots as S  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

RACINE = pathlib.Path(__file__).resolve().parent.parent
LARGEUR, HAUTEUR = 886, 1920
IPS = 30
DEBIT = "11M"
SECONDES_MIN, SECONDES_MAX = 15, 30

# Le châssis, calculé une fois depuis les constantes de la fiche : les deux images doivent poser
# l'appareil au même endroit, à la même taille, sinon on voit qu'elles ont été faites séparément.
BEZEL = round(S.SCREEN_W * S.BEZEL)
CHASSIS = (S.SCREEN_W + 2 * BEZEL, round(S.SCREEN_W * 2868 / 1320) + 2 * BEZEL)
CHASSIS_X = (S.CANVAS[0] - CHASSIS[0]) // 2
ECRAN_XY = (CHASSIS_X + BEZEL, S.DEVICE_TOP + BEZEL)
ECRAN_WH = (S.SCREEN_W, CHASSIS[1] - 2 * BEZEL)


def fond(rang: int, bandeau: str) -> Image.Image:
    """Le décor d'un plan, SANS son titre : le fond, les filets, la ligne courante.

    Le cadre est pris dans la bande des six : chaque plan hérite donc d'un morceau DIFFÉRENT du
    fond et de la ligne courante, et celle-ci avance d'un plan à l'autre comme elle avance d'une
    capture à l'autre. Au-delà du sixième, on reboucle plutôt que de sortir de la bande.
    """
    return S.cadre((rang - 1) % S.TOTAL + 1, bandeau).convert("RGB")


def titre_calque(titre: str, sous: str, rang: int, total: int) -> Image.Image:
    """Le titre seul, sur du transparent, pour pouvoir le faire ENTRER.

    Il était cuit dans le fond, donc il apparaissait d'un bloc avec le reste : sept mises en page
    fixes qui se succèdent. Séparé, il peut monter de quarante pixels en un tiers de seconde,
    ce qui suffit à faire d'une coupe un début de plan.

    C'est le SEUL mouvement ajouté. Dans l'aperçu d'une app, ce qui doit bouger est l'app ; tout
    le reste qui s'agite lui vole l'attention qu'on a trois secondes pour lui donner.
    """
    calque = Image.new("RGBA", S.CANVAS, (0, 0, 0, 0))
    S._accroche(calque, (titre, sous), rang, total, numero=False)
    return calque


def chassis() -> Image.Image:
    """Le châssis seul, écran TRANSPARENT, pour se poser par-dessus la vidéo.

    `S.device` exige une capture : on lui en donne une noire, puis on perce l'écran. Reprendre
    son dessin à la main donnerait un deuxième châssis à maintenir, et les deux divergeraient —
    c'est le défaut que `screenshots.py` a déjà corrigé trois fois sur d'autres valeurs.
    """
    noir = Image.new("RGB", (1320, 2868), (0, 0, 0))
    corps, _, b = S.device(noir, screen_w=S.SCREEN_W)
    trou = Image.new("L", ECRAN_WH, 255)
    rayon = S.SCREEN_W * S.SCREEN_RADIUS
    masque = Image.new("L", ECRAN_WH, 0)
    ImageDraw.Draw(masque).rounded_rectangle((0, 0, ECRAN_WH[0] - 1, ECRAN_WH[1] - 1),
                                             radius=rayon, fill=255)
    vide = Image.new("RGBA", ECRAN_WH, (0, 0, 0, 0))
    corps.paste(vide, (b, b), masque)
    return corps


def plaque(titre: str, sous: str, rang: int, total: int, bandeau: str,
           dossier: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path, pathlib.Path]:
    """Les trois calques d'un plan : le décor (avec l'ombre portée), le châssis percé, le titre."""
    dossier.mkdir(parents=True, exist_ok=True)
    f = dossier / f"fond-{rang}.png"
    if not f.exists():
        img = fond(rang, bandeau).convert("RGBA")
        # L'ombre de l'appareil appartient au FOND : posée avec le châssis, elle s'appliquerait
        # par-dessus la vidéo et noircirait le bas de l'écran.
        silhouette = Image.new("L", CHASSIS, 0)
        ImageDraw.Draw(silhouette).rounded_rectangle(
            (0, 0, CHASSIS[0] - 1, CHASSIS[1] - 1),
            radius=S.SCREEN_W * S.SCREEN_RADIUS + BEZEL, fill=255)
        ombre = Image.new("RGBA", S.CANVAS, (0, 0, 0, 0))
        ombre.paste(Image.new("RGBA", CHASSIS, (0, 0, 0, 120)), (CHASSIS_X, S.DEVICE_TOP + 26),
                    silhouette)
        img.alpha_composite(ombre.filter(ImageFilter.GaussianBlur(40)))
        img.convert("RGB").save(f)
    c = dossier / "chassis.png"
    if not c.exists():
        chassis().save(c)
    tt = dossier / f"titre-{rang}.png"
    if not tt.exists():
        titre_calque(titre, sous, rang, total).save(tt)
    return f, c, tt


def carte_titre(dossier: pathlib.Path, bandeau: str, mot: str, sous: str) -> pathlib.Path:
    """L'image d'ouverture ou de fin : le fond de la fiche, et le nom au centre.

    Deux secondes à l'entrée, une et demie à la sortie, sur vingt-quatre : Apple demande qu'un
    aperçu soit d'abord du contenu capturé dans l'app, et c'est aussi ce qu'on veut — une carte
    de titre longue est une publicité, pas une démonstration.
    """
    f = dossier / f"carte-{mot[:6].lower().strip()}.png"
    if f.exists():
        return f
    img = S.cadre(1, bandeau).convert("RGBA")
    d = ImageDraw.Draw(img)
    from PIL import ImageFont
    police = ImageFont.truetype(str(S.TITRE_POLICE), 220)
    largeur = S.tracked_width(d, mot, police, -4.0)
    y = S.CANVAS[1] // 2 - 190
    S.tracked(d, ((S.CANVAS[0] - largeur) / 2, y), mot, police, S.ENCRE + (255,), -4.0)
    petite = ImageFont.truetype(str(S.FONTS / "Inter-Light.ttf"), 54)
    w = d.textlength(sous, font=petite)
    d.text(((S.CANVAS[0] - w) / 2, y + 250), sous, font=petite, fill=S.ENCRE + (160,))
    img.convert("RGB").save(f)
    return f


# L'ENTRÉE DU TITRE. Quarante pixels de montée, un tiers de seconde, et une opacité qui suit.
ENTREE_DUREE = 0.34
ENTREE_MONTEE = 40


def plan_video(entree: pathlib.Path, debut: float, duree: float,
               fond_png: pathlib.Path, chassis_png: pathlib.Path, titre_png: pathlib.Path,
               sortie: pathlib.Path) -> None:
    """Un plan : l'enregistrement dans l'écran, entre le décor et le châssis, titre par-dessus."""
    d, h = ENTREE_DUREE, ENTREE_MONTEE
    filtre = (
        f"[0:v]trim=start={debut}:duration={duree},setpts=PTS-STARTPTS,"
        f"scale={ECRAN_WH[0]}:{ECRAN_WH[1]}[ecran];"
        f"[1:v]loop=loop=-1:size=1:start=0,setpts=N/{IPS}/TB[bg];"
        f"[bg][ecran]overlay={ECRAN_XY[0]}:{ECRAN_XY[1]}:shortest=1[pose];"
        f"[2:v]loop=loop=-1:size=1:start=0,setpts=N/{IPS}/TB[ch];"
        f"[pose][ch]overlay={CHASSIS_X}:{S.DEVICE_TOP}:shortest=1[avecapp];"
        # Le titre monte et se révèle. `fade` agit sur l'alpha du calque, pas sur l'image dessous.
        f"[3:v]loop=loop=-1:size=1:start=0,setpts=N/{IPS}/TB,"
        f"format=rgba,fade=t=in:st=0:d={d}:alpha=1[titre];"
        f"[avecapp][titre]overlay=0:'if(lt(t,{d}), {h}*(1-t/{d}), 0)':shortest=1,"
        f"fps={IPS}[v]"
    )
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error",
         "-i", str(entree), "-i", str(fond_png), "-i", str(chassis_png), "-i", str(titre_png),
         "-filter_complex", filtre, "-map", "[v]",
         "-t", f"{duree}", "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p",
         str(sortie)], check=True)


def plan_fixe(image: pathlib.Path, duree: float, sortie: pathlib.Path) -> None:
    """Une carte de titre, tenue le temps voulu."""
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-loop", "1", "-i", str(image),
         "-t", f"{duree}", "-r", str(IPS), "-c:v", "libx264", "-crf", "16",
         "-pix_fmt", "yuv420p", str(sortie)], check=True)


def assembler(morceaux: list[pathlib.Path], sortie: pathlib.Path, fond_hex: str) -> None:
    """Les plans bout à bout, puis une seule passe au format d'Apple.

    Coupes FRANCHES. Un fondu d'une demi-seconde entre deux plans de trois mange un sixième du
    film pour ne rien dire de plus, et brouille précisément l'instant où le plan change — qui est
    la seule chose qui donne du rythme.
    """
    liste = sortie.parent / "plans.txt"
    liste.write_text("".join(f"file '{m.resolve()}'\n" for m in morceaux), encoding="utf-8")
    filtre = (f"scale={LARGEUR}:{HAUTEUR}:force_original_aspect_ratio=decrease,"
              f"pad={LARGEUR}:{HAUTEUR}:(ow-iw)/2:(oh-ih)/2:color={fond_hex},fps={IPS}")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(liste),
         "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
         "-vf", filtre, "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
         "-b:v", DEBIT, "-maxrate", DEBIT, "-bufsize", "22M",
         "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2",
         "-movflags", "+faststart", "-shortest", str(sortie)], check=True)


def main() -> int:
    a = argparse.ArgumentParser(description="Monte l'aperçu App Store.")
    a.add_argument("--entree", type=pathlib.Path, required=True)
    a.add_argument("--sortie", type=pathlib.Path, required=True)
    a.add_argument("--plans", type=pathlib.Path, default=None,
                   help="JSON : { ouverture, fin, bandeau, plans: [{debut, duree, titre, sous, rang}] }")
    # LE DÉCOUPAGE ET LES TEXTES VIENNENT DE DEUX ENDROITS DIFFÉRENTS, ET C'EST VOULU.
    #
    # Le découpage est une mesure : le test le relève pendant qu'il tourne, parce qu'un
    # glissement lent dure ce qu'il dure. Les textes sont du contenu : ils se relisent, se
    # traduisent et se corrigent sans rien refilmer. Les mêler dans un seul fichier obligerait à
    # refaire une prise pour changer une virgule.
    a.add_argument("--temps", type=pathlib.Path, default=None,
                   help="Le découpage relevé par le test (temps.json)")
    a.add_argument("--textes", type=pathlib.Path, default=None,
                   help="Les titres, par langue (appstore/apercu.json)")
    a.add_argument("--langue", default="fr-FR")
    a.add_argument("--bandeau", default="")
    # Le décalage entre le début de l'ENREGISTREMENT et le début de la PRISE. La caméra tourne
    # pendant l'installation et le lancement de l'app ; les temps relevés par le test, eux,
    # comptent depuis l'instant où la prise commence. Sans ce décalage, le montage irait chercher
    # ses plans dans l'écran d'accueil du simulateur.
    a.add_argument("--decalage", type=float, default=0.0)
    a.add_argument("--travail", type=pathlib.Path, default=None)
    a.add_argument("--fond", default="0xF4F3F8")
    options = a.parse_args()

    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        raise SystemExit("ffmpeg et ffprobe sont nécessaires.")
    if not options.entree.is_file():
        raise SystemExit(f"Enregistrement introuvable : {options.entree}")

    if options.plans:
        script = json.loads(options.plans.read_text(encoding="utf-8"))
    else:
        if not (options.temps and options.textes):
            raise SystemExit("Donne --plans, ou bien --temps et --textes.")
        bornes = json.loads(options.temps.read_text(encoding="utf-8"))
        textes = json.loads(options.textes.read_text(encoding="utf-8"))
        if options.langue not in textes:
            raise SystemExit(f"Langue absente de {options.textes.name} : {options.langue}")
        bloc = textes[options.langue]
        manquants = [b["nom"] for b in bornes if b["nom"] not in bloc["plans"]]
        if manquants:
            raise SystemExit(
                f"Le test a filmé des plans sans texte en {options.langue} : "
                f"{', '.join(manquants)}. Ajoute-les à {options.textes.name}.")
        script = {
            "bandeau": options.bandeau,
            "ouverture": bloc.get("ouverture"),
            "fin": bloc.get("fin"),
            "plans": [{"debut": b["debut"] + options.decalage, "duree": b["fin"] - b["debut"],
                       "rang": i, "titre": bloc["plans"][b["nom"]][0],
                       "sous": bloc["plans"][b["nom"]][1]}
                      for i, b in enumerate(bornes, start=1)],
        }
    travail = options.travail or options.sortie.parent / "montage"
    travail.mkdir(parents=True, exist_ok=True)
    bandeau = script.get("bandeau", "")

    morceaux: list[pathlib.Path] = []
    duree_totale = 0.0

    ouverture = script.get("ouverture")
    if ouverture:
        img = carte_titre(travail, bandeau, ouverture["mot"], ouverture.get("sous", ""))
        m = travail / "00-ouverture.mp4"
        plan_fixe(img, ouverture["duree"], m)
        morceaux.append(m); duree_totale += ouverture["duree"]

    for i, p in enumerate(script["plans"], start=1):
        f, c, tt = plaque(p["titre"], p.get("sous", ""), p.get("rang", i),
                          len(script["plans"]), bandeau, travail)
        m = travail / f"{i:02d}-plan.mp4"
        plan_video(options.entree, p["debut"], p["duree"], f, c, tt, m)
        morceaux.append(m); duree_totale += p["duree"]
        print(f"  plan {i} : {p['debut']:.1f} → {p['debut'] + p['duree']:.1f} s  « {p['titre']} »")

    fin = script.get("fin")
    if fin:
        img = carte_titre(travail, bandeau, fin["mot"], fin.get("sous", ""))
        m = travail / "99-fin.mp4"
        plan_fixe(img, fin["duree"], m)
        morceaux.append(m); duree_totale += fin["duree"]

    # Les deux bornes d'Apple se vérifient ICI, avant l'encodage final : un aperçu refusé ne dit
    # pas laquelle des cinq contraintes a sauté, et celle-ci est la plus facile à rater.
    if not SECONDES_MIN <= duree_totale <= SECONDES_MAX:
        raise SystemExit(
            f"Le montage fait {duree_totale:.1f} s, et Apple en veut entre {SECONDES_MIN} et "
            f"{SECONDES_MAX}. Ajoute ou retire un plan, ou change leur durée.")

    options.sortie.parent.mkdir(parents=True, exist_ok=True)
    assembler(morceaux, options.sortie, options.fond)
    poids = options.sortie.stat().st_size / 1_000_000
    print(f"\n{options.sortie} — {duree_totale:.1f} s, {poids:.1f} Mo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
