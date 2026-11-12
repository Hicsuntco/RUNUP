#!/usr/bin/env python3
"""Les quatre jetons de texte sont opaques, dans la famille du fond, et ne perdent pas de contraste.

# LE DÉFAUT

`text2`, `text3` et `text4` étaient des opacités — noir à 72 / 62 / 22 % en clair, blanc à
68 / 52 / 20 % en sombre. Deux conséquences, dont une seule se voyait.

Une opacité se mélange à ce qui passe dessous : le même jeton ne rendait donc pas la même couleur
selon la surface. `text3` sortait à #616161 sur une carte blanche et à #5A595D sur la sous-surface
lavande. Quatre points d'écart sur une seule voie — l'œil ne le relève pas, mais c'est une couleur
du système de design que le système de design ne décidait pas.

Et surtout : les quatre fonds de l'app penchent tous vers le violet de l'accent, pendant que le
texte sortait en gris neutre pur. Le commentaire de `RUColor.bg` énonce pourtant la règle — « un
gris pur à côté d'un rose vif prend l'air sale, un gris qui partage sa famille non ». Elle était
appliquée aux fonds et pas aux 835 emplois de texte posés dessus.

# POURQUOI UN SCRIPT, ET PAS SEULEMENT DES VALEURS

Les rapports de contraste de ces jetons vivaient dans un commentaire. Un commentaire ne retient
personne : la valeur peut être retouchée pour une raison esthétique, et les chiffres d'à côté
continuent d'affirmer l'ancien contraste. C'est exactement ce qui était arrivé à `text3`, dont une
passe précédente n'avait relevé qu'une branche sur deux.

Ce script ne range donc AUCUNE valeur attendue. Il lit les jetons dans `Colors.swift`, reconstruit
ce que les anciennes opacités rendaient, et vérifie trois choses :

  1. aucun jeton de texte n'est une opacité ;
  2. chaque jeton secondaire est dans la famille du fond (bleu au-dessus du rouge, vert en
     dessous) — les deux exceptions de `textPrimary` sont écrites et bornées ci-dessous ;
  3. sur CHAQUE fond, aucun jeton ne rend un contraste plus faible que celui que son opacité
     d'origine rendait. Le plancher est donc calculé, jamais recopié.

# LE FOND TEINTÉ, SANS REJOUER LA RECHERCHE D'ACCENT

`RUColor.bg` mélange 3,5 % de l'accent dans le neutre en clair, 10 % en sombre, et l'accent clair
est le résultat d'une recherche dichotomique dans `AccentTheme`. Rejouer cette recherche ici
reviendrait à écrire sa règle une deuxième fois — le défaut que ce dépôt passe son temps à retirer.

On la borne à la place. Mélanger 3,5 % de n'importe quelle couleur dans le neutre ne peut pas
l'assombrir plus que 3,5 % de NOIR PUR, et c'est le pire cas pour du texte sombre posé dessus.
En sombre, symétriquement, 10 % de BLANC PUR donne le fond le plus clair possible, donc le pire cas
pour du texte clair. Les deux bornes sont vraies pour les huit nuanciers sans en lire aucun.
"""

import pathlib
import re
import sys

# L'arithmétique du contraste et la lecture de `Colors.swift` vivent dans `couleurs.py`, que
# `check_design.py` lit aussi. Deux copies pourraient diverger sur ce qu'un garde VOIT, et un
# garde qui se trompe sur ce qu'il lit est pire qu'aucun garde.
from couleurs import contraste, famille, fonds, melange, sans_commentaires  # noqa: F401

RACINE = pathlib.Path(__file__).resolve().parent.parent
COULEURS = RACINE / "RunUp/DesignSystem/Colors.swift"

# Les opacités d'origine, par thème. Ce sont des FAITS SUR LE PASSÉ, pas des valeurs attendues :
# elles servent uniquement à recalculer le contraste que le jeton rendait avant d'être opaque, donc
# le plancher que la nouvelle valeur doit tenir.
OPACITES = {
    "clair": {"text2": 0.72, "text3": 0.62, "text4": 0.22},
    "sombre": {"text2": 0.68, "text3": 0.52, "text4": 0.20},
}


# `textPrimary` ne suit pas la règle de famille, et les deux raisons sont écrites dans
# `Colors.swift` juste au-dessus de sa déclaration : en clair `#15151C` y est DÉJÀ (bleu +7), en
# sombre c'est le blanc pur, volontairement hors famille parce qu'on veut son maximum de lisibilité.
HORS_FAMILLE = {("textPrimary", "sombre")}


DECLARATION = re.compile(
    r"static var (textPrimary|text2|text3|text4): Color \{([^}]*)\}"
)


def jetons(source: str) -> dict:
    """Les deux branches de chaque jeton : `{nom: {"clair": ..., "sombre": ...}}`.

    Une branche est soit un hex, soit `Color.white` / `Color.black`, soit autre chose — et
    « autre chose » est précisément ce que le point 1 doit attraper, donc la valeur reste la
    chaîne brute et le contrôle de famille la signale.
    """
    def valeur(texte: str):
        texte = texte.strip()
        if (m := re.fullmatch(r"Color\(hex: (0x[0-9A-Fa-f]{6})\)", texte)):
            return int(m.group(1), 16)
        if texte == "Color.white":
            return 0xFFFFFF
        if texte == "Color.black":
            return 0x000000
        return texte

    trouves = {}
    for nom, corps in DECLARATION.findall(source):
        m = re.fullmatch(r"\s*isLight \? (.+?) : (.+?)\s*", corps.strip())
        if not m:
            trouves[nom] = {"clair": corps.strip(), "sombre": corps.strip()}
            continue
        trouves[nom] = {"clair": valeur(m.group(1)), "sombre": valeur(m.group(2))}
    return trouves


def ecarts() -> list:
    source = sans_commentaires(COULEURS.read_text(encoding="utf-8"))
    trouves = jetons(source)
    problemes = []

    manquants = {"textPrimary", "text2", "text3", "text4"} - set(trouves)
    if manquants:
        return [(", ".join(sorted(manquants)), "",
                 "Jeton de texte introuvable dans Colors.swift — le script ne sait plus quoi "
                 "mesurer. Si un jeton a été renommé, renommez-le aussi ici.")]

    for nom, branches in sorted(trouves.items()):
        for theme, valeur in branches.items():
            # 1 — opaque.
            if not isinstance(valeur, int):
                problemes.append((f"{nom} ({theme})", str(valeur),
                                  "N'est pas une couleur opaque. Un jeton de texte ne peut pas "
                                  "être une opacité : il se mélangerait au fond, et sa couleur "
                                  "serait décidée par la surface et non par le système de design."))
                continue

            # 2 — dans la famille du fond, QUELLE QU'ELLE SOIT.
            #
            # Le garde ne nomme aucune couleur : il lit les fonds et prend le signe de leur
            # penchant. Quand les fonds clairs étaient lavande, il exigeait du texte violet ;
            # depuis qu'ils sont chauds, il exige du texte chaud, sans qu'une ligne change ici.
            # C'était l'épreuve de la règle, et elle l'a passée.
            if (nom, theme) not in HORS_FAMILLE:
                penchant_du_fond = sum(famille(f)[0] for f in fonds(theme).values())
                penchant_du_texte = famille(valeur)[0]
                if penchant_du_fond * penchant_du_texte <= 0:
                    sens = "chaud (bleu SOUS le rouge)" if penchant_du_fond < 0 else \
                           "froid (bleu AU-DESSUS du rouge)"
                    problemes.append((
                        f"{nom} ({theme})", f"#{valeur:06X}",
                        f"Hors de la famille du fond. Les fonds de ce thème sont {sens} ; ce "
                        f"jeton penche de {penchant_du_texte:+d}. Un gris neutre, ou pire un gris "
                        "de l'autre famille, prend l'air sale sur eux — et une couleur de texte "
                        "doit être décidée par le système de design, pas subie."))

            # 3 — aucun fond ne perd de contraste.
            if nom == "textPrimary":
                continue
            base = 0x000000 if theme == "clair" else 0xFFFFFF
            alpha = OPACITES[theme][nom]
            for ou, fond in fonds(theme).items():
                avant = contraste(melange(base, fond, alpha), fond)
                apres = contraste(valeur, fond)
                if apres + 0.005 < avant:
                    problemes.append((
                        f"{nom} ({theme})", f"#{valeur:06X}",
                        f"Perd du contraste sur `{ou}` : {apres:.2f}:1 contre {avant:.2f}:1 que "
                        f"rendait l'opacité {alpha:g}. Un gris violet se détache moins d'un fond "
                        "lavande qu'un gris neutre — la valeur doit être calée sur le pire des "
                        "fonds, pas sur le plus fréquent."))
    return problemes


def tableau() -> str:
    source = sans_commentaires(COULEURS.read_text(encoding="utf-8"))
    trouves = jetons(source)
    lignes = []
    for theme in ("clair", "sombre"):
        noms = list(fonds(theme))
        lignes.append(f"  {theme} — " + " / ".join(noms))
        for nom in ("textPrimary", "text2", "text3", "text4"):
            valeur = trouves.get(nom, {}).get(theme)
            if not isinstance(valeur, int):
                continue
            mesures = " ".join(f"{contraste(valeur, f):5.2f}" for f in fonds(theme).values())
            lignes.append(f"      {nom:<12} #{valeur:06X}  {mesures}")
    return "\n".join(lignes)


def main() -> int:
    problemes = ecarts()
    if problemes:
        print(f"{len(problemes)} problème(s) sur les jetons de texte :\n")
        for quoi, valeur, raison in problemes:
            print(f"  • {quoi}" + (f" — {valeur}" if valeur else ""))
            print(f"      {raison}\n")
        print("Voir l'en-tête de ce script et le bloc « LES QUATRE JETONS DE TEXTE » "
              "dans RunUp/DesignSystem/Colors.swift.")
        return 1
    print("Jetons de texte : opaques, dans la famille du fond, aucun contraste perdu.")
    print(tableau())
    return 0


if __name__ == "__main__":
    sys.exit(main())
