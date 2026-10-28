#!/usr/bin/env python3
"""Refuse un build qui réouvre l'échelle de titrage.

`RUDisplaySize` a sept crans. Avant, il y avait vingt-six tailles écrites à la main sur 103
appels, dont sept dans six points — et personne ne les avait décidées : chaque écran avait été
réglé à l'œil, séparément, puis recopié.

Le compilateur tient l'essentiel : il n'existe plus de surcharge muette prenant un nombre, donc
`displayStyle(26)` ne compile pas. Ce qu'il ne peut pas tenir, c'est la porte de service :
`displayStyle(horsEchelle: 26)` compile très bien, et il suffit de l'écrire une fois pour que la
suivante paraisse normale. C'est comme ça que les vingt-six étaient arrivées.

Ce script fixe donc la liste des sorties d'échelle, fichier par fichier, avec son compte. Ajouter
une sortie demande de modifier CE fichier — c'est-à-dire d'écrire noir sur blanc pourquoi cet
écran-là ne peut pas tenir sur les sept crans de l'app.
"""
import re, sys, pathlib

RACINE = pathlib.Path(__file__).resolve().parent.parent
TYPO = "RunUp/DesignSystem/Typography.swift"

# fichier → (nombre de sorties attendu, la raison)
AUTORISE = {
    "RunUp/Views/Live/RunShareCardView.swift":
        (2, "carte d'export : géométrie de pixels fixe pour une image partagée"),
    "RunUp/Views/Live/RunVideoFrameView.swift":
        (3, "image de la vidéo d'export : même raison"),
    "RunUp/Views/Club/BadgeShareCardView.swift":
        (2, "carte d'export d'un badge : même raison"),
    "RunUp/Views/Components/AvatarView.swift":
        (3, "initiales à 0,4 × le diamètre de l'avatar : une suite continue, pas un cran"),
    "RunUp/Views/Live/LiveRunView.swift":
        (2, "le chronomètre de la course en cours : 96 pt au décompte, 52/64 au temps écoulé"),
}

MOTIF_NOMBRE = re.compile(r"(?:\.displayStyle|RUFont\.display)\(\s*\d")
MOTIF_SORTIE = re.compile(r"(?:displayStyle|RUFont\.display)\(horsEchelle:")

fautes = []
compte = {}

for chemin in sorted(RACINE.rglob("*.swift")):
    rel = str(chemin.relative_to(RACINE))
    if rel == TYPO:
        continue
    for num, ligne in enumerate(chemin.read_text().split("\n"), 1):
        nue = ligne.lstrip()
        if nue.startswith("//"):
            continue
        if MOTIF_NOMBRE.search(ligne):
            fautes.append(f"{rel}:{num} : une taille écrite à la main — prends un cran de "
                          f"RUDisplaySize.\n    {nue}")
        n = len(MOTIF_SORTIE.findall(ligne))
        if n:
            compte[rel] = compte.get(rel, 0) + n

for rel, n in sorted(compte.items()):
    if rel not in AUTORISE:
        fautes.append(f"{rel} : {n} sortie(s) d'échelle dans un fichier qui n'en déclare aucune.\n"
                      f"    Si cet écran ne peut vraiment pas tenir sur les sept crans, inscris-le\n"
                      f"    dans AUTORISE de ci_scripts/check_echelle.py avec sa raison.")
    elif n != AUTORISE[rel][0]:
        attendu, raison = AUTORISE[rel]
        fautes.append(f"{rel} : {n} sortie(s) d'échelle, {attendu} déclarée(s).\n"
                      f"    Raison inscrite : {raison}")

for rel, (attendu, raison) in sorted(AUTORISE.items()):
    if compte.get(rel, 0) == 0:
        fautes.append(f"{rel} : plus aucune sortie d'échelle — retire-le de AUTORISE.\n"
                      f"    Raison inscrite : {raison}")

if fautes:
    print("L'échelle de titrage s'est réouverte :\n")
    for f in fautes:
        print("  • " + f)
    sys.exit(1)

total = sum(compte.values())
print(f"Échelle de titrage : 7 crans, {total} sorties déclarées dans {len(compte)} fichiers.")
