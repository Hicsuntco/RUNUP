#!/usr/bin/env python3
"""Les captures exigées par Apple doivent montrer l'app D'AUJOURD'HUI.

# POURQUOI CE CONTRÔLE EXISTE

Les six captures d'iPhone sont fabriquées à chaque passage : `appstore/raw` → `screenshots.py` →
la fiche. Elles ne peuvent donc pas vieillir sans qu'on le voie.

Celle de la montre, qu'Apple EXIGE dès que la build embarque une app watchOS, vivait dans
`appstore/requis/`, faite à la main une fois, et ni `screenshots.py`, ni `asc.py`, ni aucun des
contrôles du dépôt ne la regardait. Relevé le 9 novembre 2026 sur la fiche publiée de la 3.3 :
elle montrait l'app du mois d'AOÛT. Trois mois de retard sur la seule surface que les gens voient
avant d'installer.

IL Y AVAIT AUSSI UNE IMAGE D'iPAD, et elle n'aurait jamais dû exister. `TARGETED_DEVICE_FAMILY`
vaut 1 : RUNUP est une app iPhone, et Apple n'en demande aucune. Ce qui restait sur la fiche était
une mise en page iPhone étirée dans un cadre d'iPad, héritée d'une version précédente — App Store
Connect recopie les captures de la version d'avant, tous formats confondus. Elle ne se corrige
pas, elle se RETIRE : `asc.py prune-screenshots <version> --retirer APP_IPAD_PRO_3GEN_129`.

Ce n'est pas qu'une question de soin. Apple demande qu'une capture montre l'app telle qu'elle est.

# CE QU'IL VÉRIFIE

Chaque image livrée porte, dans `appstore/requis/SOURCES.json`, l'empreinte de la capture brute
dont elle a été composée. La capture change, l'empreinte ne correspond plus, le contrôle rougit
en nommant la commande qui recompose. C'est le même mécanisme que le relevé de la fiche de
confidentialité, et pour la même raison : on ne peut pas comparer deux images, on peut comparer
ce dont elles sont faites.

# CE QU'IL NE PEUT PAS FAIRE, ET POURQUOI IL NE ROUGIT PAS POUR AUTANT

La capture de la montre ne se compose pas ici. Elle se prend sur un simulateur watchOS, donc sur
une machine macOS, et ce projet n'a pas de cible de test d'interface pour watchOS. Une entrée
sans source est donc SIGNALÉE à chaque passage, avec ce qu'on sait d'elle, et ne fait PAS échouer
— un rouge que personne ne peut éteindre s'apprend à être ignoré, et il emporterait avec lui les
rouges qu'on peut éteindre. C'est la même forme que `--plancher` dans `check_grand_texte.py` et
que `--exiger` dans `check_politique.py`.
"""
import argparse
import hashlib
import json
import pathlib
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
REQUIS = RACINE / "appstore/requis"
SOURCES = REQUIS / "SOURCES.json"

# LA TABLE DES TAILLES EST LUE CHEZ `asc.py`, PAS RECOPIÉE.
#
# C'est lui qui envoie les images à Apple, et il s'ARRÊTE devant une taille qu'il ne connaît pas
# — « rien n'a été envoyé ». Une copie ici finirait par diverger de la sienne, et le contrôle
# validerait alors des images que l'envoi refuse. Une copie qui n'existe pas ne peut pas dériver,
# même raison que la palette de marque dans `screenshots.py`.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import asc  # noqa: E402


def empreinte(chemin: pathlib.Path) -> str:
    """Les douze premiers caractères du SHA-256. Assez pour qu'un changement se voie."""
    return hashlib.sha256(chemin.read_bytes()).hexdigest()[:12]


def empreinte_du_code(dossier: str) -> str:
    """L'empreinte du CODE QUI DESSINE l'écran photographié.

    UNE CAPTURE NE VIEILLIT PAS TOUTE SEULE : c'est l'app qui bouge sous elle. Pour la montre, il
    n'y a pas de capture intermédiaire versionnée : la chaîne photographie et l'image livrée EST
    la photo. Rien, alors, ne relie l'image au code — et c'est très exactement ainsi que le bouton
    est passé de la pilule au cercle le 6 août 2026 sans que l'image livrée bouge pendant trois
    mois.

    Le chemin ET le contenu de chaque fichier entrent dans l'empreinte : un fichier renommé change
    ce qui est dessiné autant qu'un fichier modifié.
    """
    racine = RACINE / dossier
    if not racine.is_dir():
        raise SystemExit(f"{dossier} n'est pas un dossier de ce dépôt — l'entrée est à revoir.")
    h = hashlib.sha256()
    for fichier in sorted(racine.rglob("*.swift")):
        h.update(str(fichier.relative_to(RACINE)).encode("utf-8"))
        h.update(fichier.read_bytes())
    return h.hexdigest()[:12]


def entrees() -> dict:
    if not SOURCES.exists():
        raise SystemExit(
            f"{SOURCES.relative_to(RACINE)} n'existe pas.\n"
            "C'est lui qui dit de quelle capture chaque image livrée est faite ; sans lui, rien\n"
            "ne peut constater qu'une image a vieilli.")
    return json.loads(SOURCES.read_text(encoding="utf-8"))


def livrees() -> list:
    return sorted(p for p in REQUIS.rglob("*.png"))


def main() -> int:
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("--ecrire", action="store_true",
                         help="reposer les empreintes APRÈS avoir recomposé les images")
    args = options.parse_args()

    table = entrees()
    images = livrees()

    if args.ecrire:
        touchees = 0
        for clef, entree in table.items():
            if entree.get("code"):
                entree["empreinte_code"] = empreinte_du_code(entree["code"])
                touchees += 1
            source = entree.get("source")
            if not source:
                continue
            brut = RACINE / source
            if not brut.exists():
                print(f"{source} n'existe pas — {clef} n'a pas été redatée.")
                continue
            neuve = empreinte(brut)
            if entree.get("empreinte") != neuve:
                entree["empreinte"] = neuve
                touchees += 1
        SOURCES.write_text(json.dumps(table, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
        print(f"{touchees} empreinte(s) reposée(s) dans {SOURCES.relative_to(RACINE)}.")
        return 0
    if not images:
        print(f"Aucune image dans {REQUIS.relative_to(RACINE)} — Apple en exige.")
        return 1

    perimees, orphelines, sans_source, mauvaise_taille = [], [], [], []
    for image in images:
        clef = str(image.relative_to(REQUIS))
        entree = table.get(clef)
        if entree is None:
            orphelines.append(clef)
            continue

        # LA TAILLE D'ABORD : une image parfaitement à jour que `asc.py` refuse d'envoyer ne sert
        # à rien. La première capture de montre faisait 374 × 446 — le simulateur de 42 mm au lieu
        # de celui de 46 — et l'envoi se serait arrêté sur « taille inconnue », après une chaîne
        # entièrement verte.
        taille = asc.taille_png(image)
        if taille not in asc.TYPES_PAR_TAILLE:
            mauvaise_taille.append((clef, taille))
            continue
        # LE CODE D'ABORD : une image peut être faite de la bonne capture et montrer malgré tout
        # un écran que l'app ne dessine plus, si la capture elle-même date d'avant un changement.
        code = entree.get("code")
        if code:
            vue = empreinte_du_code(code)
            if vue != entree.get("empreinte_code"):
                perimees.append((clef, code,
                                 f"le code a changé : {entree.get('empreinte_code')} → {vue}"))
                continue

        source = entree.get("source")
        if not source:
            sans_source.append((clef, entree.get("constat", "")))
            continue
        brut = RACINE / source
        if not brut.exists():
            perimees.append((clef, source, "la capture source a disparu"))
            continue
        vue = empreinte(brut)
        if vue != entree.get("empreinte"):
            perimees.append((clef, source, f"empreinte {entree.get('empreinte')} → {vue}"))

    for clef, constat in sans_source:
        print(f"⚠ {clef} n'est faite d'aucune capture de ce dépôt.")
        if constat:
            print(f"    {constat}")

    if mauvaise_taille:
        print(f"\n{len(mauvaise_taille)} image(s) d'une taille qu'Apple ne connaît pas :\n")
        for clef, (largeur, hauteur) in mauvaise_taille:
            print(f"  · {clef} : {largeur} × {hauteur}")
        print("\n    `asc.py push-screenshots` s'arrête devant une taille absente de sa table —")
        print("    donc l'image ne partirait pas, quelle que soit sa fraîcheur. Les tailles")
        print("    acceptées sont dans `TYPES_PAR_TAILLE` (`ci_scripts/asc.py`).")
        return 1

    if orphelines:
        print(f"\n{len(orphelines)} image(s) livrée(s) qu'aucune entrée ne décrit :\n")
        for clef in orphelines:
            print(f"  · {clef}")
        print(f"\n    Ajoute-les à {SOURCES.relative_to(RACINE)} — une image livrée à Apple que")
        print("    rien ne décrit est exactement ce qui a laissé vieillir les deux précédentes.")
        return 1

    if perimees:
        print(f"\n{len(perimees)} image(s) ne montre(nt) plus l'app d'aujourd'hui :\n")
        for clef, source, pourquoi in perimees:
            print(f"  · {clef}  ({pourquoi})")
            print(f"      faite de {source}")
        print("\n    `PATH=/tmp/venv/bin:$PATH python3 ci_scripts/requis.py fr-FR` recompose,")
        print("    puis `--ecrire` ci-dessous repose les empreintes.")
        return 1

    composees = len(images) - len(sans_source)
    print(f"Captures exigées : {composees} composée(s) de la capture courante, "
          f"{len(sans_source)} à reprendre à la main.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
