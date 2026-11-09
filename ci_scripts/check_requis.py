#!/usr/bin/env python3
"""Les captures exigées par Apple doivent montrer l'app D'AUJOURD'HUI.

# POURQUOI CE CONTRÔLE EXISTE

Les six captures d'iPhone sont fabriquées à chaque passage : `appstore/raw` → `screenshots.py` →
la fiche. Elles ne peuvent donc pas vieillir sans qu'on le voie.

Les deux autres — l'iPad et la montre, qu'Apple EXIGE dès que la build embarque une app watchOS —
vivaient dans `appstore/requis/`, faites à la main une fois, et ni `screenshots.py`, ni `asc.py`,
ni aucun des contrôles du dépôt ne les regardait. Relevé le 9 novembre 2026 sur la fiche publiée
de la 3.3 : les deux montraient l'app du mois d'AOÛT. Trois mois de retard sur la seule surface
que les gens voient avant d'installer.

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


def empreinte(chemin: pathlib.Path) -> str:
    """Les douze premiers caractères du SHA-256. Assez pour qu'un changement se voie."""
    return hashlib.sha256(chemin.read_bytes()).hexdigest()[:12]


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

    perimees, orphelines, sans_source = [], [], []
    for image in images:
        clef = str(image.relative_to(REQUIS))
        entree = table.get(clef)
        if entree is None:
            orphelines.append(clef)
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
