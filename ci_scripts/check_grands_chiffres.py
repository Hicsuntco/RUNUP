#!/usr/bin/env python3
"""Un grand corps tenu sur une seule ligne doit pouvoir rétrécir.

# LE DÉFAUT

`lineLimit(1)` sans `minimumScaleFactor`, c'est une TRONCATURE. Sur une phrase elle se voit — les
points de suspension disent qu'il manque quelque chose. Sur un NOMBRE elle ment : « 1:23:45 »
devient « 1:23… », et rien à l'écran ne dit que ce n'est pas l'heure complète. La personne lit un
chiffre faux sans aucun signe que c'en est un.

Trouvé le 13 novembre sur l'écran de séance, en mesurant autre chose. Ni le chronomètre ni l'allure
cible ne portaient de réduction, et la ligne « CIBLE 10:30/km » — un coureur lent pendant son
échauffement — débordait des 284 points utiles de l'iPhone le plus étroit dès que la taille de
texte du système montait à 1,31×. L'app autorise 2,00×.

# CE QUE LE SCRIPT REGARDE

Les grands corps seulement : `.hero`, `.banner`, et tout `horsEchelle:` à partir de 35. C'est là
que la largeur manque en premier, et c'est là que vivent les chiffres.

UN `horsEchelle:` CALCULÉ EST TRAITÉ COMME GRAND, faute de pouvoir le lire. La première version de
ce script n'attendait que des chiffres, et elle ne voyait donc PAS le chronomètre de l'écran de
séance — `horsEchelle: hasInstruction ? RUDisplaySize.hero.rawValue : 64` — c'est-à-dire la ligne
même qui a fait écrire ce garde. Un contrôle aveugle à son propre cas d'origine ne vaut rien. Dans
le doute, on contrôle : exiger une réduction d'un corps finalement petit ne coûte rien, la manquer
sur un grand coûte un chiffre faux à l'écran.

Et seulement ceux qui portent `lineLimit(1)`. Un texte qui a le droit de passer à la ligne n'a
besoin de rien : `WelcomeView` pose un titre sur trois lignes avec des `\\n` explicites dans un
`ScrollView`, `PaywallView` écrit `fixedSize(horizontal: false, vertical: true)` pour grandir en
hauteur. Ce sont les deux réponses légitimes, et exiger une réduction d'eux serait un faux positif
— c'est d'ailleurs la première version de cette règle, corrigée avant d'être écrite.
"""

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ["RunUp", "RunUpWidgets", "RunUpWatch"]

# `displayStyle(.hero)`, `RUFont.display(.banner)`, `displayStyle(horsEchelle: 52)`.
GRAND = re.compile(
    r"displayStyle\(\s*\.(hero|banner)\b"
    r"|display\(\s*\.(hero|banner)\s*\)"
    r"|displayStyle\(\s*horsEchelle:\s*(\d+|[^)\n]+)"
)
# Le plus petit cran considéré comme « grand » : `hero` vaut 35.
SEUIL = 35
# Combien de lignes après la déclaration on cherche ses modificateurs. Une chaîne de modificateurs
# SwiftUI tient largement là-dedans ; au-delà, on est dans une autre vue.
PORTEE = 8


def grands_corps(source: str):
    """(numéro de ligne, taille lue, bloc de modificateurs) pour chaque grand corps."""
    lignes = source.splitlines()
    for i, ligne in enumerate(lignes):
        m = GRAND.search(ligne)
        if not m:
            continue
        horsEchelle = m.group(3)
        if horsEchelle is not None and horsEchelle.strip().isdigit():
            if int(horsEchelle) < SEUIL:
                continue
        taille = (horsEchelle or m.group(1) or m.group(2)).strip()
        yield i + 1, taille, "\n".join(lignes[i:i + PORTEE])


def ecarts() -> list:
    problemes = []
    for dossier in DOSSIERS:
        for fichier in sorted((RACINE / dossier).rglob("*.swift")):
            source = fichier.read_text(encoding="utf-8")
            for numero, taille, bloc in grands_corps(source):
                if "lineLimit(1)" not in bloc:
                    continue
                if "minimumScaleFactor" in bloc:
                    continue
                problemes.append((
                    f"{fichier.relative_to(RACINE)}:{numero}", str(taille),
                    "Grand corps tenu sur une seule ligne, sans `minimumScaleFactor`. Il se "
                    "tronquera au lieu de rétrécir — et un nombre tronqué ne dit pas qu'il l'est. "
                    "Ajoutez une réduction, ou laissez-le passer à la ligne."))
    return problemes


def main() -> int:
    problemes = ecarts()
    if problemes:
        print(f"{len(problemes)} grand(s) corps qui peuvent se tronquer :\n")
        for ou, taille, raison in problemes:
            print(f"  • {ou} — {taille}")
            print(f"      {raison}\n")
        return 1
    total = sum(1 for d in DOSSIERS for f in (RACINE / d).rglob("*.swift")
                for _ in grands_corps(f.read_text(encoding="utf-8")))
    print(f"Les {total} grands corps de l'app peuvent tous rétrécir ou passer à la ligne.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
