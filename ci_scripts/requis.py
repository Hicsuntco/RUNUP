#!/usr/bin/env python3
"""Les captures qu'Apple EXIGE en plus des six de l'iPhone, et que rien ne fabriquait.

# CE QUI ÉTAIT FAUX

Les six captures d'iPhone sont FABRIQUÉES : `appstore/raw` → `screenshots.py` → la fiche, à
chaque passage. Les deux autres — l'iPad et la montre — vivaient dans `appstore/requis/`, faites
à la main une fois, et ni `screenshots.py`, ni `asc.py`, ni aucun des contrôles du dépôt ne les
regardait.

Relevé le 9 novembre 2026, sur la fiche publiée de la 3.3 :

  · l'iPad montrait l'app du **5 août**. Le titrage en Bebas Neue — la fonte que l'app a
    abandonnée — donc « SALUT CHARLOTTE » en capitales, un prénom en capitales, le défaut même
    qui avait fait retirer cette fonte. L'écran portait « OBJECTIF · PROGRESSER », « SÉANCE
    CLÉ », et une barre d'onglets finissant par « Club » quand l'app finit par « Profil » ;
  · la montre montrait un bouton PILULE de 386 × 88 px sur 416 de large, mesuré dans l'image,
    quand le code dessine un CERCLE de 92 pt depuis le 6 août — et « COURIR » en capitales, que
    la fonte actuelle ne sait plus produire.

Trois mois de retard sur la seule surface que les gens voient avant d'installer.

# CE QUE CE SCRIPT FAIT, ET CE QU'IL NE PEUT PAS FAIRE

Il compose l'image iPad à partir de la capture COURANTE, dans la charte courante — la même que
les six de l'iPhone, dont il emprunte la palette, la police de titrage et les accroches. Une
seule image, donc pas de bande découpée en six : le raccord d'un cadre à l'autre n'a pas de sens
quand il n'y a qu'un cadre.

Il ne peut PAS fabriquer celle de la montre. Une capture de montre se prend sur un simulateur
watchOS, donc sur une machine macOS ; il n'y a pas de cible de test d'interface pour watchOS dans
ce projet. Ce qui est à sa portée est de dire que l'image livrée ne montre pas l'app — c'est le
travail de `check_requis.py`.

    PATH=/tmp/venv/bin:$PATH python3 ci_scripts/requis.py fr-FR
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import screenshots as s  # noqa: E402

#: iPad Pro 12,9" 3e génération — la taille sous laquelle App Store Connect range l'image (voir
#: `TYPES_PAR_TAILLE` dans `asc.py`). Changer ce couple change la case où elle atterrit.
IPAD = (2048, 2732)

#: Le registre de ce dont chaque image livrée est faite — lu par `check_requis.py`.
TABLE = Path(s.ROOT) / "appstore/requis/SOURCES.json"

#: La capture dont l'image iPad est faite. La première des six, celle de l'accueil : c'est
#: l'écran que l'app ouvre, et le seul dont on soit sûr qu'il existe dans toutes les langues.
SOURCE = "1-accueil.png"

#: La capture de montre, prise par `captures.yml` sur un simulateur watchOS — voir son étape
#: « Photographier la montre ». Elle n'est PAS composée : l'écran d'une montre fait 416 × 496, et
#: Apple le veut tel quel. Il n'y a donc rien à poser autour, et l'image livrée est la capture.
MONTRE_BRUTE = "appstore/raw-montre"
MONTRE_NOM = "1-course-libre.png"

MARGE = 150
TITRE_HAUT = 300
TITRE_TAILLE = 196
TITRE_INTERLIGNE = 210
SOUS_TAILLE = 62
SOUS_INTERLIGNE = 82
EYEBROW_TAILLE = 40
#: L'appareil : 36 % de la largeur. Le réglage n'est pas esthétique, il est contraint — c'est la
#: largeur maximale à laquelle le téléphone tient ENTIER entre son bord haut et le filet du bas.
#: À 42 %, il traversait le filet et sortait du cadre : sur une bande de six, un appareil coupé
#: par le bord est une mise en page ; sur une image seule, c'est une erreur de cadrage.
APPAREIL_LARGEUR = 0.36
APPAREIL_HAUT = 880
FILET_HAUT, FILET_BAS = 760, 2620


def fond() -> Image.Image:
    """Le même papier et les mêmes deux filets que les six cadres, à la largeur de l'iPad.

    PAS DE LIGNE COURANTE. Sur la bande de six, elle est le raccord : une seule phrase qui avance
    sous six images, coupée par chaque bord et reprise à la lettre près sur le cadre suivant. Ici
    il n'y a pas de cadre suivant — elle ne serait plus qu'une phrase tronquée aux deux bouts,
    c'est-à-dire la chose même qu'elle sert à éviter ailleurs.
    """
    toile = s.linear(IPAD, s.PAPIER, horizontal=True).convert("RGBA")
    d = ImageDraw.Draw(toile)
    for y in (FILET_HAUT, FILET_BAS):
        d.rectangle((0, y, IPAD[0], y + s.FILET - 1), fill=s.ENCRE + (34,))
    return toile


def accroche(toile: Image.Image, titre: str, sous: str) -> None:
    """Le bloc de texte, calé à gauche sur la même marge que l'appareil est centré.

    PAS DE NUMÉROTATION « 01 / 06 » ici : elle a un sens sur une bande de six, où elle dit où
    l'on en est. Sur une image seule, elle annoncerait cinq images qui n'existent pas.
    """
    d = ImageDraw.Draw(toile)
    eyebrow = ImageFont.truetype(str(s.FONTS / "DMMono-Medium.ttf"), EYEBROW_TAILLE)
    s.tracked(d, (MARGE, TITRE_HAUT - 90), "RUNUP", eyebrow,
              s.ROSE_SUR_CLAIR + (255,), s.EYEBROW_CHASSE)

    titre_police = ImageFont.truetype(str(s.TITRE_POLICE), TITRE_TAILLE)
    y = TITRE_HAUT
    for ligne in s.wrap(d, titre, titre_police, IPAD[0] - MARGE * 2, s.TITRE_CHASSE):
        s.tracked(d, (MARGE, y), ligne, titre_police, s.ENCRE + (255,), s.TITRE_CHASSE)
        y += TITRE_INTERLIGNE

    sous_police = ImageFont.truetype(str(s.FONTS / "Inter-Medium.ttf"), SOUS_TAILLE)
    y += 28
    for ligne in s.wrap(d, sous, sous_police, IPAD[0] - MARGE * 2):
        d.text((MARGE, y), ligne, font=sous_police, fill=s.ENCRE + (190,))
        y += SOUS_INTERLIGNE


def appareil(toile: Image.Image, capture: Image.Image) -> None:
    corps, silhouette, _ = s.device(capture, screen_w=round(IPAD[0] * APPAREIL_LARGEUR))
    dw, dh = corps.size
    gauche, haut = (IPAD[0] - dw) // 2, APPAREIL_HAUT
    # L'APPAREIL DOIT TENIR ENTIER. Le recadrage silencieux est ce qui a laissé passer la version
    # précédente : elle sortait du cadre, et personne ne regardait. Ici on ARRÊTE, en disant de
    # combien et quel réglage le corrige.
    if haut + dh > FILET_BAS:
        sys.exit(f"L'appareil dépasse le filet du bas de {haut + dh - FILET_BAS} px.\n"
                 f"Baisse APPAREIL_LARGEUR (actuellement {APPAREIL_LARGEUR}) ou APPAREIL_HAUT "
                 f"(actuellement {APPAREIL_HAUT}).")
    ombre = Image.new("RGBA", IPAD, (0, 0, 0, 0))
    ombre.paste(Image.new("RGBA", (dw, dh), (0, 0, 0, 120)), (gauche, haut + 30), silhouette)
    toile.alpha_composite(ombre.filter(ImageFilter.GaussianBlur(46)))
    toile.alpha_composite(corps, (gauche, haut))


def composer(langue: str):
    """Rend le chemin écrit, ou None quand la langue n'a pas de capture d'accueil.

    Aucune capture n'est une situation NORMALE et non une panne : seul le français est versionné
    dans `appstore/raw`, les deux autres langues sont prises par la chaîne au moment où elle
    tourne. Sauter en le disant vaut mieux qu'échouer : sinon la seule langue qu'on peut composer
    ne se compose plus dès qu'on en demande trois.
    """
    brut = s.RAW / langue / SOURCE
    if not brut.exists():
        print(f"  — {langue} : pas de capture d'accueil, rien à composer.")
        return None
    bloc = s.json.loads(s.CAPTIONS.read_text(encoding="utf-8"))[langue]
    titre, sous = s.accroches(bloc)[0]
    toile = fond()
    accroche(toile, titre, sous)
    appareil(toile, s.clean_status_bar(Image.open(brut).convert("RGB")))
    dest = s.ROOT / "appstore/requis/ipad" / langue / "1-accueil.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    toile.convert("RGB").save(dest, "PNG")
    return dest


def montre(langue: str):
    """Pose la capture de montre telle quelle, si la chaîne en a pris une.

    Rien n'est composé autour : l'écran d'une montre fait 416 × 496 et Apple le veut ainsi.
    L'image livrée EST la capture — c'est pour ça qu'elle vaut mieux que celle qu'on remplace,
    qui était dessinée à la main et montrait un écran qui n'existait plus.
    """
    brut = s.ROOT / MONTRE_BRUTE / langue / MONTRE_NOM
    if not brut.exists():
        print(f"  — {langue} : pas de capture de montre ({MONTRE_BRUTE}/{langue}).")
        return None
    dest = s.ROOT / "appstore/requis/montre" / langue / MONTRE_NOM
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
        "empreinte": hashlib.sha256((s.ROOT / source).read_bytes()).hexdigest()[:12],
        "composee_par": "ci_scripts/requis.py",
    }
    if code:
        # L'empreinte du CODE QUI DESSINE l'écran, en plus de celle de la capture. Pour la montre
        # il n'y a pas de capture intermédiaire versionnée : sans ce lien, rien ne rattache
        # l'image livrée à l'app, et c'est ainsi qu'elle a vieilli de trois mois.
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
        dest = composer(langue)
        if dest is not None:
            faits += 1
            largeur, hauteur = Image.open(dest).size
            print(f"{dest.relative_to(s.ROOT)} — {largeur} × {hauteur}")
            datee(str(dest.relative_to(s.ROOT / "appstore/requis")),
                  f"appstore/raw/{langue}/{SOURCE}")
    for langue in langues:
        dest = montre(langue)
        if dest is not None:
            faits += 1
            largeur, hauteur = Image.open(dest).size
            print(f"{dest.relative_to(s.ROOT)} — {largeur} × {hauteur}")
            datee(str(dest.relative_to(s.ROOT / "appstore/requis")),
                  f"{MONTRE_BRUTE}/{langue}/{MONTRE_NOM}", code="RunUpWatch")
    if faits == 0:
        print("Aucune capture trouvée : rien n'a été posé.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
