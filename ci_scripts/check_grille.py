#!/usr/bin/env python3
"""Refuse un build où un écart, une marge ou un rayon sort de la géométrie déclarée.

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

# LES RAYONS, MÊME HISTOIRE

Il y avait eu dix jetons de rayon, dont trois faisaient le même travail à quatre points d'écart et
deux portaient la même valeur sous deux noms. Ils sont cinq (`RUSpacing.rayons`), et un rayon
écrit à la main est la façon dont le onzième reviendra — c'est comme ça que les dix étaient nés.

Les huit littéraux qui restent sont inscrits ci-dessous avec leur raison : ce sont des formes
DESSINÉES — l'aperçu d'habillage qui miniaturise un téléphone, l'infobulle d'un graphique, les
marques d'une frise de programme. Un rayon de 3 points sur une marque de 6 points de large ne
répond pas à l'échelle des cartes de l'app, et l'y forcer serait de la comptabilité, pas du
design.
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

mr = re.search(r"static let rayons: \[CGFloat\] = \[([^\]]+)\]", texte)
if not mr:
    print("RUSpacing.rayons est introuvable — c'est elle qui déclare l'échelle des rayons.")
    sys.exit(1)
# `rayons` renvoie aux autres jetons par leur nom ; on relit donc leurs valeurs.
NOMS = dict(re.findall(r"static let (radius\w+): CGFloat = (\d+(?:\.\d+)?)", texte))
RAYONS = {float(NOMS[n.strip()]) for n in mr.group(1).split(",") if n.strip() in NOMS}
if len(RAYONS) != len([n for n in mr.group(1).split(",") if n.strip()]):
    print("RUSpacing.rayons cite un jeton dont la valeur n'a pas pu être relue.")
    sys.exit(1)

# Les rayons écrits à la main, fichier par fichier, avec leur raison.
FORMES_DESSINEES = {
    "RunUp/Views/Profile/SettingsView.swift":
        (4, "l'aperçu d'habillage miniaturise un téléphone : coque 9, écran 5"),
    "RunUp/Views/Stats/StatsView.swift":
        (1, "l'infobulle du graphique, tracée dans un Canvas"),
    "RunUp/Views/Home/PlanView.swift":
        (3, "les marques de la frise de programme : 2, 3 et 4 points de large"),
}

ESPACE = re.compile(r"\bspacing: (\d+(?:\.\d+)?)\b")
# `ruCard(radius:)` et `ruHeroCard(radius:)` comptent aussi : c'est par là que huit cartes
# avaient gardé un rayon à la main (14, 16, 18, 20) que le seul mot « cornerRadius » ne
# voyait pas — la façon dont les dix valeurs d'avant avaient survécu au premier rangement.
RAYON = re.compile(r"(?:cornerRadius:? ?\(?|ruHeroCard\(radius: |ruCard\(radius: )(\d+(?:\.\d+)?)")
MARGE = re.compile(r"\.padding\((?:\.(?:top|bottom|leading|trailing|horizontal|vertical), )?(\d+(?:\.\d+)?)\)")

fautes = []
dessines = {}
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
        for brut in RAYON.findall(ligne):
            v = float(brut)
            if rel in FORMES_DESSINEES:
                dessines[rel] = dessines.get(rel, 0) + 1
                continue
            voisine = min(RAYONS, key=lambda g: (abs(g - v), g))
            fautes.append(f"{rel}:{num} : rayon de {brut} écrit à la main — le jeton le plus "
                          f"proche vaut {voisine:g}.\n    {ligne.strip()}")

for rel, (attendu, raison) in sorted(FORMES_DESSINEES.items()):
    n = dessines.get(rel, 0)
    if n != attendu:
        fautes.append(f"{rel} : {n} rayon(s) écrit(s) à la main, {attendu} déclaré(s).\n"
                      f"    Raison inscrite : {raison}")

if fautes:
    print(f"La grille d'espacement s'est rouverte ({len(fautes)} appels) :\n")
    for f in fautes[:40]:
        print("  • " + f)
    if len(fautes) > 40:
        print(f"\n  … et {len(fautes) - 40} autres.")
    print(f"\n  Grille déclarée : {sorted(int(g) for g in GRILLE)}")
    print(f"  Rayons déclarés : {sorted(int(r) for r in RAYONS)}")
    print("  Pour en ajouter un, c'est RUSpacing.grille ou RUSpacing.rayons qu'il faut modifier,")
    print("  pas ce script : la géométrie se déclare dans le système de design.")
    sys.exit(1)

print(f"Grille d'espacement : {sorted(int(g) for g in GRILLE)}, respectée jusqu'à {PLAFOND}.")
print(f"Rayons : {sorted(int(r) for r in RAYONS)}, plus {sum(dessines.values())} littéraux "
      f"déclarés dans {len(dessines)} formes dessinées.")
