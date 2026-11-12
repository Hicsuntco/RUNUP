#!/usr/bin/env python3
"""Les copies d'une couleur du système de design disent-elles encore la même chose que l'originale ?

# LE DÉFAUT

Le 12 novembre, le fond clair de l'app est passé du gris-lavande au blanc cassé chaud, et toutes
les encres ont suivi. Toutes celles que `RUColor` déclare, du moins. Deux autres sont restées
froides, et aucune barrière ne pouvait le dire :

  • `DailyGoalsWidget.textPrimary` — le widget a sa PROPRE copie, parce que sa cible ne compile
    pas `RunUp/DesignSystem` (la raison est en tête de `WidgetAccentPalette`). Il aurait porté
    l'ancienne encre violette sur l'écran d'accueil du téléphone, à côté d'une app chaude.
  • `RUColor.onAccent` — l'encre posée sur un aplat d'accent, écrite en dur parce qu'elle ne peut
    PAS lire `textPrimary` : ce jeton suit le thème, alors qu'un bouton rose vif porte la même
    encre dans les deux apparences.

# POURQUOI UNE LISTE, ET PAS UNE INTERDICTION

On ne peut pas interdire ces copies : l'une traverse une frontière de cible, l'autre répond à une
question différente. Ce qui se refuse, c'est une copie SANS correspondance déclarée. Chaque entrée
ci-dessous dit quelle valeur locale doit égaler quel jeton de `RUColor`, et pourquoi elle ne peut
pas simplement l'appeler. Une copie de plus, sans entrée, n'est pas vue par ce script — mais elle
ne peut pas non plus se réclamer d'une règle : la liste est la règle.
"""

import pathlib
import re
import sys

import couleurs

RACINE = couleurs.RACINE

# (fichier, motif de la valeur locale, jeton de RUColor, thème, raison de la copie)
CORRESPONDANCES = [
    (
        "RunUpWidgets/DailyGoalsWidget.swift",
        r"private var textPrimary: Color \{ isLight \? Color\(hex: (0x[0-9A-Fa-f]{6})\)",
        "textPrimary", "clair",
        "La cible du widget ne compile pas RunUp/DesignSystem — frontière de processus, voir "
        "WidgetAccentPalette.",
    ),
    (
        "RunUp/DesignSystem/Colors.swift",
        r"return luminance > 0\.6 \? Color\(hex: (0x[0-9A-Fa-f]{6})\) : \.white",
        "textPrimary", "clair",
        "`onAccent` ne peut pas lire `textPrimary`, qui suit le thème : l'encre sur un aplat "
        "d'accent dépend de l'aplat, pas de l'apparence de l'app.",
    ),
]


def ecarts() -> list:
    jetons = couleurs.declarations()
    problemes = []
    for relatif, motif, jeton, theme, raison in CORRESPONDANCES:
        chemin = RACINE / relatif
        if not chemin.is_file():
            problemes.append((relatif, jeton,
                              "Fichier introuvable — la correspondance ne mesure plus rien."))
            continue
        source = couleurs.sans_commentaires(chemin.read_text(encoding="utf-8"))
        trouve = re.search(motif, source)
        if not trouve:
            problemes.append((
                relatif, jeton,
                "La valeur locale ne se lit plus : soit elle a été renommée, soit elle appelle "
                "maintenant le jeton directement. Dans le premier cas, corrigez le motif ici ; "
                "dans le second, retirez l'entrée — une correspondance qui ne trouve rien est un "
                "garde qui dort."))
            continue
        locale = int(trouve.group(1), 16)
        attendu = jetons.get(jeton, {}).get(theme)
        if not isinstance(attendu, int):
            problemes.append((relatif, jeton,
                              f"`RUColor.{jeton}` ({theme}) n'est pas une valeur littérale."))
        elif locale != attendu:
            problemes.append((
                relatif, f"{jeton} ({theme})",
                f"La copie dit #{locale:06X}, `RUColor.{jeton}` dit #{attendu:06X}. "
                f"La copie existe parce que : {raison} Elle doit suivre."))
    return problemes


def main() -> int:
    problemes = ecarts()
    if problemes:
        print(f"{len(problemes)} encre(s) recopiée(s) en désaccord avec le système de design :\n")
        for ou, quoi, raison in problemes:
            print(f"  • {ou} — {quoi}")
            print(f"      {raison}\n")
        return 1
    print(f"Les {len(CORRESPONDANCES)} encres recopiées s'accordent avec RUColor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
