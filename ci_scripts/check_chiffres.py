#!/usr/bin/env python3
"""Un chiffre et son unité se composent avec `RUChiffre`, et pas une dixième fois à la main.

POURQUOI CETTE RÈGLE EXISTE.

L'app posait un grand nombre suivi de son unité à NEUF endroits, et aucun ne ressemblait aux
autres : quatre tailles d'unité (micro, small, body, emphasis), cinq graisses et trois couleurs,
pour le même objet. Dans un cas l'unité faisait 20 pt à côté d'un chiffre de 48 — elle ne
l'accompagnait pas, elle lui répondait.

Personne n'avait décidé ça. Chaque écran avait été composé séparément, et l'unité avait pris ce
qui tombait sous la main — exactement comme les vingt-six tailles de titrage et les dix-neuf
écarts verticaux. À ceci près que celui-là porte sur l'objet le plus regardé d'une app de course.

CE QUE LE SCRIPT CHERCHE. Un `HStack` aligné sur une ligne de base qui contient à la fois un
`displayStyle` (donc un chiffre) et un `RUFont.sans` (donc son unité, composée à la main). C'est
la forme exacte des neuf, et la seule façon d'en écrire un dixième.

Aucun compilateur ne peut refuser ça : les deux lignes sont parfaitement valides séparément.
"""
import sys, pathlib

RACINE = pathlib.Path(__file__).resolve().parent.parent
FENETRE = 12

# Les exceptions, avec leur raison. Le compte est fixé : en ajouter une demande de modifier ce
# fichier, c'est-à-dire d'écrire pourquoi cet écran ne peut pas prendre le composant partagé.
AUTORISE = {
    "RunUp/Views/Live/LiveRunView.swift":
        (1, "l'écran de course en cours : son chiffre porte un `contentTransition(.numericText())` "
            "et son animation de chiffre, que le composant partagé ne transporte pas, et son "
            "unité vit sur l'encrier `Ink` de cet écran et non sur le thème"),
}

fautes = []
compte = {}

for chemin in sorted(RACINE.rglob("*.swift")):
    rel = str(chemin.relative_to(RACINE))
    if rel == "RunUp/Views/Components/ChiffreView.swift":
        continue
    lignes = chemin.read_text().split("\n")
    for i, ligne in enumerate(lignes):
        if "HStack" not in ligne or "TextBaseline" not in ligne:
            continue
        bloc = lignes[i:i + FENETRE]
        # On s'arrête à la fin du HStack plutôt qu'à la fenêtre entière : sinon un HStack court
        # suivi d'un libellé indépendant se dénoncerait pour rien.
        profondeur, utile = 0, []
        for b in bloc:
            utile.append(b)
            profondeur += b.count("{") - b.count("}")
            if profondeur <= 0 and len(utile) > 1:
                break
        if not any("displayStyle(" in b for b in utile):
            continue
        if not any("RUFont.sans(" in b for b in utile):
            continue
        compte[rel] = compte.get(rel, 0) + 1
        if rel in AUTORISE:
            continue
        fautes.append(f"{rel}:{i+1} : un chiffre et son unité composés à la main.\n"
                      f"    Prends `RUChiffre(valeur:unite:)` — il porte le raisonnement et les\n"
                      f"    neuf traitements qu'il remplace.\n"
                      f"    {ligne.strip()}")

for rel, (attendu, raison) in sorted(AUTORISE.items()):
    n = compte.get(rel, 0)
    if n != attendu:
        fautes.append(f"{rel} : {n} couple(s) composé(s) à la main, {attendu} déclaré(s).\n"
                      f"    Raison inscrite : {raison}")

if fautes:
    print("Un chiffre et son unité composés hors de `RUChiffre` :\n")
    for f in fautes:
        print("  • " + f)
    sys.exit(1)

print(f"Chiffres : {sum(compte.values())} couple(s) à la main, tous déclarés "
      f"({len(AUTORISE)} fichier).")
