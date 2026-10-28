#!/usr/bin/env python3
"""Refuse un build où un écart ou une marge sort de la grille d'espacement.

Il y avait dix-neuf écarts verticaux distincts, continus de 0 à 22 sans un trou, et trente-trois
valeurs de marge. 8 employé 100 fois et 9 huit fois ; 10 cent trente-trois fois et 11 deux fois.
Une valeur à un point d'une valeur dominante n'est pas une décision — c'est un écran réglé
séparément, puis recopié.

Aucun compilateur ne peut refuser ça : `spacing: 9` est un nombre parfaitement valide, et c'est
exactement pour cette raison que les dix-neuf étaient arrivées, une par une, sans que personne
ait à les défendre. Ce script est donc le seul endroit qui le remarque.

La grille n'est PAS écrite ici : elle est lue dans `RUSpacing.grille`, qui est sa déclaration.
Ajouter une valeur demande de la poser là-bas, dans le système de design, pas dans un script de
vérification — c'est-à-dire d'assumer de la rendre légale pour toute l'app.

Au dessus de 24, le script ne dit rien : ce ne sont plus des écarts de rythme mais des hauteurs
réservées (les 130 points qu'un défilement garde sous la barre d'onglets, les encarts de feuille),
et une grille de rythme n'a rien à leur dire.
"""
import re, sys, pathlib

RACINE = pathlib.Path(__file__).resolve().parent.parent
SPACING = RACINE / "RunUp/DesignSystem/Spacing.swift"
PLAFOND = 24

texte = SPACING.read_text()
m = re.search(r"static let grille: \[CGFloat\] = \[([^\]]+)\]", texte)
if not m:
    print("RUSpacing.grille est introuvable — c'est elle qui déclare la grille.")
    sys.exit(1)
GRILLE = {float(x.strip()) for x in m.group(1).split(",") if x.strip()}

ESPACE = re.compile(r"\bspacing: (\d+(?:\.\d+)?)\b")
MARGE = re.compile(r"\.padding\((?:\.(?:top|bottom|leading|trailing|horizontal|vertical), )?(\d+(?:\.\d+)?)\)")

fautes = []
for chemin in sorted(RACINE.rglob("*.swift")):
    rel = str(chemin.relative_to(RACINE))
    for num, ligne in enumerate(chemin.read_text().split("\n"), 1):
        if ligne.lstrip().startswith("//"):
            continue
        for motif, quoi in ((ESPACE, "écart"), (MARGE, "marge")):
            for brut in motif.findall(ligne):
                v = float(brut)
                if v > PLAFOND or v in GRILLE:
                    continue
                voisine = min(GRILLE, key=lambda g: (abs(g - v), g))
                fautes.append(f"{rel}:{num} : {quoi} de {brut} — hors grille, la voisine est "
                              f"{voisine:g}.\n    {ligne.strip()}")

if fautes:
    print(f"La grille d'espacement s'est rouverte ({len(fautes)} appels) :\n")
    for f in fautes[:40]:
        print("  • " + f)
    if len(fautes) > 40:
        print(f"\n  … et {len(fautes) - 40} autres.")
    print(f"\n  La grille déclarée : {sorted(int(g) for g in GRILLE)}")
    print("  Pour en ajouter une, c'est RUSpacing.grille qu'il faut modifier.")
    sys.exit(1)

print(f"Grille d'espacement : {sorted(int(g) for g in GRILLE)}, respectée jusqu'à {PLAFOND}.")
