#!/usr/bin/env python3
"""Pose les captures de montre qu'Apple exige en plus des six de l'iPhone, et les date.

# CE QUI ÉTAIT FAUX

Les six captures d'iPhone sont FABRIQUÉES : `appstore/raw` → `screenshots.py` → la fiche, à
chaque passage. Celle de la montre vivait dans `appstore/requis/`, faite à la main une fois, et
ni `screenshots.py`, ni `asc.py`, ni aucun des contrôles du dépôt ne la regardait.

Relevé le 9 novembre 2026 sur la fiche publiée de la 3.3 : la montre montrait un bouton PILULE de
386 × 88 px sur 416 de large, mesuré dans l'image, quand le code dessine un CERCLE de 92 pt depuis
le 6 août — et « COURIR » en capitales, que la fonte actuelle ne sait plus produire.

Trois mois de retard sur la seule surface que les gens voient avant d'installer.

# ET L'IMAGE iPAD, QUI N'AURAIT JAMAIS DÛ EXISTER

Ce script composait aussi une image iPad : une mise en page iPhone posée dans un cadre d'iPad.
Elle est partie, et ce n'est pas une simplification — c'était une erreur.

**RUNUP est une app iPhone.** `TARGETED_DEVICE_FAMILY` vaut 1 dans les réglages de base comme
dans ceux du widget ; seule la montre porte 4. Apple ne demande donc AUCUNE image d'iPad, et
`RELEASE.md` l'écrivait déjà noir sur blanc pendant que ce script en fabriquait une.

Ce qui restait sur la fiche était une capture d'août, héritée d'une version précédente — App
Store Connect recopie les captures de la version d'avant, tous formats confondus. Elle ne se
corrige pas, elle se RETIRE : c'est à ça que sert `asc.py prune-screenshots`.

Et la raison de fond est une décision produit, pas une question d'outillage : **on ne court pas
avec son iPad.** Une app iPad de RunUp ne serait pas la même app — elle n'aurait pas d'écran de
séance en cours — donc elle ne se photographie pas en étirant celle de l'iPhone.

# CE QU'IL FAIT

Il copie la capture de montre prise par `.github/workflows/montre.yml` et inscrit dans
`SOURCES.json` de quoi elle est faite : l'empreinte de la capture, ET l'empreinte du code qui a
dessiné l'écran. Rien n'est composé autour — l'écran d'une montre fait 416 × 496, Apple le veut
tel quel, et l'image livrée EST la capture.

Il n'a plus besoin de Pillow : il copie un fichier et lit une en-tête PNG.

    python3 ci_scripts/requis.py fr-FR en-US es-ES
"""
from __future__ import annotations

import hashlib
import json
import struct
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent

#: Le registre de ce dont chaque image livrée est faite — lu par `check_requis.py`.
TABLE = RACINE / "appstore/requis/SOURCES.json"

#: La capture de montre, prise par `montre.yml` sur un simulateur watchOS. Elle n'est PAS
#: composée : l'écran d'une montre fait 416 × 496, et Apple le veut tel quel.
MONTRE_BRUTE = "appstore/raw-montre"
MONTRE_NOM = "1-course-libre.png"


def taille_png(chemin: Path) -> tuple[int, int]:
    """La largeur et la hauteur, lues dans l'en-tête IHDR. Pas besoin de Pillow pour ça."""
    tete = chemin.read_bytes()[:24]
    if tete[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{chemin} n'est pas un PNG")
    return struct.unpack(">II", tete[16:24])


def montre(langue: str):
    """Pose la capture de montre telle quelle, si la chaîne en a pris une."""
    brut = RACINE / MONTRE_BRUTE / langue / MONTRE_NOM
    if not brut.exists():
        print(f"  — {langue} : pas de capture de montre ({MONTRE_BRUTE}/{langue}).")
        return None
    dest = RACINE / "appstore/requis/montre" / langue / MONTRE_NOM
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(brut.read_bytes())
    return dest


def datee(clef: str, source: str, code: str | None = None) -> None:
    """Pose l'empreinte de la capture dont une image livrée vient d'être faite.

    Écrite ICI et pas seulement par `check_requis.py --ecrire` : la commande qui FABRIQUE est la
    seule qui sache de quoi elle a fabriqué. Une empreinte reposée à part, après coup, pourrait
    certifier une image que personne n'a recomposée — c'est exactement le piège que le relevé de
    la fiche de confidentialité refuse, pour la même raison.
    """
    table = json.loads(TABLE.read_text(encoding="utf-8")) if TABLE.exists() else {}
    entree = {
        "source": source,
        "empreinte": hashlib.sha256((RACINE / source).read_bytes()).hexdigest()[:12],
        "composee_par": "ci_scripts/requis.py",
    }
    if code:
        # L'empreinte du CODE QUI DESSINE l'écran, en plus de celle de la capture. Sans ce lien,
        # rien ne rattache l'image livrée à l'app, et c'est ainsi qu'elle a vieilli de trois mois.
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import check_requis as verif  # noqa: PLC0415
        entree["code"] = code
        entree["empreinte_code"] = verif.empreinte_du_code(code)
    table[clef] = entree
    TABLE.write_text(json.dumps(dict(sorted(table.items())), ensure_ascii=False, indent=2) + "\n",
                     encoding="utf-8")


def main() -> int:
    langues = sys.argv[1:] or ["fr-FR"]
    faits = 0
    for langue in langues:
        dest = montre(langue)
        if dest is not None:
            faits += 1
            largeur, hauteur = taille_png(dest)
            print(f"{dest.relative_to(RACINE)} — {largeur} × {hauteur}")
            datee(str(dest.relative_to(RACINE / "appstore/requis")),
                  f"{MONTRE_BRUTE}/{langue}/{MONTRE_NOM}", code="RunUpWatch")
    if faits == 0:
        print("Aucune capture de montre trouvée : rien n'a été posé.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
