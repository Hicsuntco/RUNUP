#!/usr/bin/env python3
"""Met un enregistrement d'écran au format que l'App Store accepte.

    Entrée  : appstore/apercu/<un fichier .mov ou .mp4>   (enregistré sur l'iPhone)
    Sortie  : appstore/apercu/out/apercu.mp4               (886 × 1920, prêt à envoyer)

    python3 ci_scripts/apercu.py [--debut SECONDES]

# POURQUOI UN SCRIPT PLUTÔT QU'UN EXPORT À LA MAIN

App Store Connect refuse un aperçu dont les dimensions ne tombent pas EXACTEMENT sur ce qu'il
attend, et le message qu'il rend ne dit pas laquelle des cinq contraintes a sauté. Les cinq, telles
qu'Apple les publie (« App preview specifications ») :

  — 886 × 1920 en portrait pour les grands iPhone ;
  — entre 15 et 30 secondes, bornes incluses ;
  — 30 images par seconde au maximum ;
  — H.264 dans un `.mov`, `.m4v` ou `.mp4` ;
  — 500 Mo au plus.

Un enregistrement d'iPhone 16 Pro Max sort en 1320 × 2868 à 60 images par seconde : il ne respecte
ni la taille, ni la cadence. Ce script fait les cinq d'un coup.

# CE QU'IL NE FAIT PAS : RECADRER

Le rapport de forme de l'enregistrement (1320/2868 = 0,4603) n'est pas tout à fait celui qu'Apple
demande (886/1920 = 0,4615). L'écart est de trois millièmes — invisible — mais l'étirer serait
quand même déformer l'app. On met donc l'image À L'INTÉRIEUR du cadre et on complète avec l'encre
du fond : au pire six pixels de bande, que personne ne verra, et aucune déformation.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import subprocess
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
ENTREE = RACINE / "appstore" / "apercu"
SORTIE = ENTREE / "out" / "apercu.mp4"

LARGEUR, HAUTEUR = 886, 1920
SECONDES_MIN, SECONDES_MAX = 15, 30
IMAGES_PAR_SECONDE = 30
# Apple vise 10 à 12 Mbit/s pour le H.264 d'un aperçu. Onze, au milieu.
DEBIT = "11M"
# L'encre du fond de l'app, pour que la bande de complément ne se voie pas si elle existe.
ENCRE = "0x0B0B12"
SUFFIXES = {".mov", ".mp4", ".m4v"}


def source() -> pathlib.Path:
    """Le seul fichier vidéo du dossier d'entrée.

    DEUX FICHIERS SONT UNE ERREUR, pas une invitation à choisir : la fiche ne porte qu'un aperçu
    par langue, et deviner lequel est le bon est le genre de supposition qui se découvre publiée.
    """
    if not ENTREE.exists():
        raise SystemExit(f"Dossier absent : {ENTREE.relative_to(RACINE)}")
    trouves = sorted(f for f in ENTREE.iterdir()
                     if f.is_file() and f.suffix.lower() in SUFFIXES)
    if not trouves:
        raise SystemExit(
            f"Aucun enregistrement dans {ENTREE.relative_to(RACINE)} "
            f"(attendu : {', '.join(sorted(SUFFIXES))})")
    if len(trouves) > 1:
        noms = ", ".join(f.name for f in trouves)
        raise SystemExit(f"Deux enregistrements ou plus — lequel ? {noms}")
    return trouves[0]


def sonde(chemin: pathlib.Path) -> dict:
    """La durée et la présence d'une piste son, par `ffprobe`."""
    brut = subprocess.run(
        ["ffprobe", "-v", "error", "-print_format", "json",
         "-show_format", "-show_streams", str(chemin)],
        capture_output=True, text=True, check=True).stdout
    data = json.loads(brut)
    pistes = data.get("streams", [])
    return {
        "secondes": float(data.get("format", {}).get("duration", 0)),
        "a_du_son": any(p.get("codec_type") == "audio" for p in pistes),
    }


def decoupe(secondes: float, debut: float) -> tuple[float, float]:
    """Le début et la durée à garder, ou une erreur parlante.

    Le plancher de quinze secondes d'Apple est le piège le plus courant : on filme ce qu'on veut
    montrer, ça fait douze secondes, et le refus arrive après l'envoi. Mieux vaut le dire ici.
    """
    if debut < 0:
        raise SystemExit("Le début ne peut pas être négatif.")
    restant = secondes - debut
    if restant < SECONDES_MIN:
        raise SystemExit(
            f"Il reste {restant:.1f} s à partir de {debut:.0f} s, et Apple en exige "
            f"{SECONDES_MIN} au minimum. Filme plus long, ou avance moins le début.")
    return debut, min(restant, float(SECONDES_MAX))


def filtre() -> str:
    """La chaîne de filtres : mise à l'échelle SANS déformation, puis complément centré."""
    return (f"scale={LARGEUR}:{HAUTEUR}:force_original_aspect_ratio=decrease,"
            f"pad={LARGEUR}:{HAUTEUR}:(ow-iw)/2:(oh-ih)/2:color={ENCRE},"
            f"fps={IMAGES_PAR_SECONDE}")


def arguments(entree: pathlib.Path, sortie: pathlib.Path,
              debut: float, duree: float, a_du_son: bool) -> list[str]:
    """La commande complète.

    `-ss` AVANT `-i` : ffmpeg saute alors directement au bon endroit du fichier au lieu de le
    décoder depuis le début, ce qui change une minute d'attente en une seconde.
    """
    args = ["ffmpeg", "-y", "-ss", f"{debut}", "-i", str(entree)]
    if not a_du_son:
        # Une piste muette plutôt qu'aucune : Apple décrit le son attendu (AAC stéréo), et un
        # fichier sans piste audio du tout est refusé par certains outils d'envoi.
        args += ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000"]
    args += [
        "-t", f"{duree}",
        "-vf", filtre(),
        "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
        "-b:v", DEBIT, "-maxrate", DEBIT, "-bufsize", "22M",
        "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2",
        "-movflags", "+faststart", "-shortest",
        str(sortie),
    ]
    return args


def main() -> int:
    analyse = argparse.ArgumentParser(description="Fabrique l'aperçu App Store.")
    analyse.add_argument("--debut", type=float, default=0,
                         help="Secondes à sauter au début de l'enregistrement")
    options = analyse.parse_args()

    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        raise SystemExit("ffmpeg et ffprobe sont nécessaires.")

    entree = source()
    infos = sonde(entree)
    debut, duree = decoupe(infos["secondes"], options.debut)

    SORTIE.parent.mkdir(parents=True, exist_ok=True)
    print(f"Enregistrement : {entree.name} — {infos['secondes']:.1f} s, "
          f"{'avec' if infos['a_du_son'] else 'sans'} son")
    print(f"Gardé : de {debut:.0f} s à {debut + duree:.0f} s ({duree:.0f} s)")
    print(f"Sortie : {LARGEUR} × {HAUTEUR}, {IMAGES_PAR_SECONDE} i/s, H.264 {DEBIT}\n")

    subprocess.run(arguments(entree, SORTIE, debut, duree, infos["a_du_son"]), check=True)

    poids = SORTIE.stat().st_size / 1_000_000
    print(f"\n{SORTIE.relative_to(RACINE)} — {poids:.1f} Mo")
    if poids > 500:
        raise SystemExit("Au-delà des 500 Mo qu'Apple accepte. Raccourcis, ou baisse le débit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
