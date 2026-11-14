#!/usr/bin/env python3
"""Ce qui est peint sur une carte de nuit suit-il le fond, ou le thème ?

# LE DÉFAUT

`RUColor.traceBackground` vaut `#14131E` dans les DEUX thèmes — un tracé lumineux ne s'éclaircit
pas parce que la page est claire, pas plus qu'une photo. Mais ce qu'on peint dessus était pris
dans les jetons de la PAGE :

  • l'anneau de départ du tracé GPS était en `RUColor.textPrimary`, soit `#181511` en thème
    clair : du presque-noir à 85 % sur du presque-noir. Sur la capture de l'accueil du
    12 novembre, il ne se lit pas comme un repère mais comme un TROU percé dans la lueur. Le
    thème clair est le thème par défaut depuis la décision D2 : c'était le cas NORMAL.
  • la trace fantôme, à 7 % de la même encre, disparaissait tout court.
  • le tracé lui-même lisait `RUColor.rose`, qui rend `primaryOnLight` en thème clair — une
    valeur descendue par `meetingContrastOnWhite` pour rester lisible SUR DU BLANC. Mesuré sur
    les huit nuanciers contre `#14131E` : lime perdait 58 % de son éclat, cyan 49 %, ambre 48 %.

Aucun de ces trois n'avait de symptôme technique. Le nuancier par défaut ne perd que 6 %, ce qui
explique que personne ne l'ait vu pendant deux mois.

# LA RÈGLE

Dans le corps d'un appel à `CarteDeNuit`, et dans les fichiers qui n'existent que pour dessiner
sur la nuit, aucun jeton qui suit le thème. L'encre est `RUColor.surLaNuit*`, les accents
`accentsDeLaNuit` / `AccentTheme.current.*`, les couleurs sémantiques leurs variantes `*Sombre`.

# CE QUE LE GARDE NE VOIT PAS

Une vue tierce appelée depuis une carte de nuit : son corps est écrit ailleurs. C'est pourquoi
`FICHIERS_DE_NUIT` existe — un composant qui ne vit que sur la nuit y est inscrit, et tout son
fichier est tenu à la règle. Un composant qui vit sur les DEUX fonds ne s'y inscrit pas : il
reçoit un paramètre (`surLaNuit`) et choisit, comme `DailyGoalsBarsView` et `RubanDeSemaine`.
"""

import pathlib
import re
import sys

import couleurs

RACINE = couleurs.RACINE

# Les jetons qui suivent le thème de la PAGE, et n'ont donc rien à faire sur la nuit.
INTERDITS = [
    "textPrimary", "text2", "text3", "text4",
    "card", "card2", "bg2", "line", "cardBorder", "pageBackground",
    "rose", "rose2", "violet",
    "lime", "cyan", "amber", "amberText", "ember", "azure", "grape",
]

# Les fichiers dont TOUT le contenu est dessiné sur la nuit.
FICHIERS_DE_NUIT = [
    "RunUp/Views/Components/DrawnRoute.swift",
]

# `RubanDeSemaine` y a figuré du 13 au 14 novembre. Il en est sorti le jour où l'accueil a
# remplacé sa bande de semaine par lui : il vit maintenant sur les deux fonds, donc il reçoit
# `surLaNuit` et choisit — c'est le cas que la note ci-dessus prévoit, et le garde l'a signalé
# de lui-même à la première exécution qui a suivi le changement.

MOTIF_JETON = re.compile(r"RUColor\.(" + "|".join(INTERDITS) + r")\b")


def _corps_des_cartes(source: str):
    """Les tranches de texte comprises entre `CarteDeNuit(` et la fin de ses fermetures.

    On compte les accolades depuis la première qui suit l'appel. `} legende: {` ramène le
    compte à zéro puis le relance : on ne s'arrête donc qu'à une fermeture qui n'est PAS
    suivie d'un second bloc.
    """
    for appel in re.finditer(r"\bCarteDeNuit\(", source):
        i = source.find("{", appel.end())
        if i < 0:
            continue
        profondeur, debut, j = 0, i, i
        while j < len(source):
            if source[j] == "{":
                profondeur += 1
            elif source[j] == "}":
                profondeur -= 1
                if profondeur == 0:
                    suite = source[j + 1:j + 40]
                    # Une deuxième fermeture nommée : la carte continue.
                    if re.match(r"\s*\w+\s*:\s*\{", suite):
                        k = source.find("{", j + 1)
                        if k >= 0:
                            j = k
                            continue
                    yield source[debut:j + 1], source.count("\n", 0, debut) + 1
                    break
            j += 1


def ecarts() -> list:
    problemes = []

    for relatif in FICHIERS_DE_NUIT:
        chemin = RACINE / relatif
        if not chemin.is_file():
            problemes.append((relatif, 0,
                              "Fichier introuvable — l'entrée de FICHIERS_DE_NUIT ne mesure "
                              "plus rien."))
            continue
        source = couleurs.sans_commentaires(chemin.read_text(encoding="utf-8"))
        for trouve in MOTIF_JETON.finditer(source):
            problemes.append((relatif, source.count("\n", 0, trouve.start()) + 1,
                              f"`RUColor.{trouve.group(1)}` suit le thème de la page, et ce "
                              f"fichier ne dessine que sur la nuit."))

    for chemin in sorted((RACINE / "RunUp").rglob("*.swift")):
        relatif = str(chemin.relative_to(RACINE))
        if relatif in FICHIERS_DE_NUIT:
            continue
        source = couleurs.sans_commentaires(chemin.read_text(encoding="utf-8"))
        for corps, ligne in _corps_des_cartes(source):
            for trouve in MOTIF_JETON.finditer(corps):
                problemes.append((relatif, ligne + corps.count("\n", 0, trouve.start()),
                                  f"`RUColor.{trouve.group(1)}` est posé dans une carte de "
                                  f"nuit, et il suit le thème de la page."))
    return problemes


def main() -> int:
    problemes = ecarts()
    if problemes:
        print(f"{len(problemes)} jeton(s) de page posé(s) sur la nuit :\n")
        for ou, ligne, raison in problemes:
            print(f"  • {ou}:{ligne}")
            print(f"      {raison}")
            print("      Sur la nuit : surLaNuit / surLaNuit2 / surLaNuit3 pour l'encre, "
                  "accentsDeLaNuit\n        ou AccentTheme.current.* pour l'accent, "
                  "limeSombre / cyanSombre / … pour le sens.\n")
        return 1
    print(f"Rien de la page n'est peint sur la nuit ({len(FICHIERS_DE_NUIT)} fichiers de nuit).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
