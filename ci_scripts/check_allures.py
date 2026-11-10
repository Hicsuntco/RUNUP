#!/usr/bin/env python3
"""Aucune allure d'entraînement ne se décide par un coefficient écrit à la main.

# POURQUOI CE CONTRÔLE EXISTE

Les quatre allures du plan étaient quatre multiplications :

    easy:      paceText(thresholdSecPerKm * 1.20),
    marathon:  paceText(thresholdSecPerKm * 1.08),
    threshold: paceText(thresholdSecPerKm * 1.0),
    interval:  paceText(thresholdSecPerKm * 0.87),

Confrontés à la table publiée de Jack Daniels, trois des quatre étaient faux. Le footing, le plus
coûteux, était 18 à 25 s/km trop rapide à TOUS les niveaux — sur l'allure qui porte 70 à 80 % du
volume d'une semaine. La VMA n'était pas une allure d'intervalle mais l'allure du MILE, prescrite
pour des répétitions de trois à cinq minutes. Et aucun coefficient fixe ne pouvait être juste :
les rapports de Daniels varient avec le niveau.

Le plus instructif n'est pas le défaut, c'est ce qui le gardait. Un test exigeait un écart
seuil→VMA de 11 à 20 %, sur la foi d'un commentaire qui affirmait sans source que « real vVO2max
sits ~12-18% faster ». La valeur juste est 7,7 à 8,2 %. Le test était vert, et il INTERDISAIT la
bonne réponse — le code l'avait eue, puis l'a perdue pour satisfaire ce test.

Un chiffre d'entraînement sans source n'est pas une approximation, c'est une invention. Et une
invention sous test devient une invention protégée.

# LES TROIS RÈGLES

1. `PaceModel.zones(for:)` ne contient AUCUNE arithmétique sur un littéral décimal. C'est la forme
   exacte du défaut, et la seule forme qu'il puisse reprendre.

2. Les quatre allures passent par `Vdot` : les trois fractions nommées, et `allureDeCourse` pour
   le marathon — qui, chez Daniels, est l'allure du marathon prédit et non une fraction fixe.

3. Chaque fraction déclarée dans `Vdot.Fraction` est nommée dans `RunUpTests/VdotTests.swift`, et
   ce fichier porte la table de Daniels — au moins sept lignes — et cite sa source. Sans la table,
   les cas ne vérifieraient plus que la cohérence du code avec lui-même, ce qui est exactement
   l'état d'où l'on vient.

# CE QUE CE CONTRÔLE NE SAIT PAS FAIRE

Il ne juge pas une fraction. Si quelqu'un écrit 75 % pour le seuil, ce script ne dira rien — c'est
`VdotTests` qui parle, en comparant à la table. Les deux sont nécessaires : l'un garde la forme,
l'autre les nombres.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
PACE = RACINE / "RunUp/Services/PaceModel.swift"
VDOT = RACINE / "RunUp/Models/Vdot.swift"
CAS = RACINE / "RunUpTests/VdotTests.swift"

# Les quatre allures, et par quoi chacune doit passer dans le corps de `zones`.
PASSAGES = {
    "footing": "Vdot.Fraction.footing",
    "seuil": "Vdot.Fraction.seuil",
    "intervalle": "Vdot.Fraction.intervalle",
    "marathon": "Vdot.allureDeCourse(",
}

# Une multiplication ou une division par un littéral décimal : `x * 1.20`, `x / 1.20`, `* 0.87`.
# Les entiers sont tolérés — 60, 1000, 42 y sont des conversions d'unité, pas des coefficients
# d'entraînement — mais un décimal dans ce corps-là est toujours un coefficient.
LITTERAL = re.compile(r"[*/]\s*\d+\.\d+|\d+\.\d+\s*[*/]")


def sans_commentaires(src):
    from swift import sans_commentaires as sc
    return sc(src)


def corps(src, debut):
    """Le corps dont l'accolade ouvrante est à `debut`, accolades équilibrées."""
    niveau = 0
    for i in range(debut, len(src)):
        if src[i] == "{":
            niveau += 1
        elif src[i] == "}":
            niveau -= 1
            if niveau == 0:
                return src[debut + 1:i]
    return src[debut:]


def corps_de_zones():
    src = sans_commentaires(PACE.read_text())
    m = re.search(r"static func zones\(for [^)]*\)\s*->\s*Zones\s*\{", src)
    if not m:
        return None
    return corps(src, m.end() - 1)


def regle_aucun_coefficient():
    """1. Aucune arithmétique sur un littéral décimal dans `zones`."""
    body = corps_de_zones()
    if body is None:
        return [f"{PACE.name} : `static func zones(for:) -> Zones` est introuvable. Ce contrôle ne "
                f"regarde plus ce qu'il croit regarder — il passerait vert sur n'importe quoi."]
    trouves = LITTERAL.findall(body)
    if trouves:
        return [f"{PACE.name} : `zones(for:)` contient un coefficient écrit à la main — "
                f"{', '.join(sorted(set(t.strip() for t in trouves)))}. C'est la forme exacte du "
                f"défaut : × 1,20 pour le footing était 18 à 25 s/km trop rapide à tous les "
                f"niveaux. Une allure d'entraînement passe par une fraction nommée de `Vdot`."]
    return []


def regle_les_quatre_passent_par_vdot():
    """2. Les quatre allures passent par `Vdot`."""
    body = corps_de_zones()
    if body is None:
        return []  # Déjà signalé par la règle 1.
    return [f"{PACE.name} : l'allure « {nom} » ne passe pas par `{attendu}` dans `zones(for:)`."
            for nom, attendu in PASSAGES.items() if attendu not in body]


def fractions_declarees():
    src = sans_commentaires(VDOT.read_text())
    m = re.search(r"enum Fraction\s*\{", src)
    if not m:
        return None
    return re.findall(r"static let (\w+)\s*=", corps(src, m.end() - 1))


def regle_chaque_fraction_est_eprouvee():
    """3. Chaque fraction est nommée dans les cas, qui portent la table et citent sa source."""
    defauts = []
    noms = fractions_declarees()
    if noms is None:
        return [f"{VDOT.name} : `enum Fraction` est introuvable."]
    if not noms:
        return [f"{VDOT.name} : aucune fraction lue dans `enum Fraction`. La forme du fichier a "
                f"changé et ce contrôle ne voit plus rien."]
    if not CAS.exists():
        return [f"RunUpTests/{CAS.name} est absent : les fractions ne sont comparées à rien."]
    texte = CAS.read_text()
    for n in noms:
        if f"Fraction.{n}" not in texte:
            defauts.append(f"`Vdot.Fraction.{n}` n'apparaît dans aucun cas de {CAS.name} : une "
                           f"fraction que rien ne compare à la table.")
    lignes = len(re.findall(r"Ligne\(vdot:", texte))
    if lignes < 7:
        defauts.append(f"{CAS.name} ne porte que {lignes} ligne(s) de la table de Daniels, il en "
                       f"faut au moins 7. Sans la table, ces cas ne vérifient plus que la "
                       f"cohérence du code avec lui-même — l'état exact d'où l'on vient.")
    if "Daniels" not in texte:
        defauts.append(f"{CAS.name} ne cite plus sa source. Un chiffre d'entraînement sans source "
                       f"est une invention, et une invention sous test est une invention protégée.")
    return defauts


def main():
    defauts = (regle_aucun_coefficient() + regle_les_quatre_passent_par_vdot()
               + regle_chaque_fraction_est_eprouvee())
    if defauts:
        for d in defauts:
            print("DÉFAUT", d)
        return 1
    noms = fractions_declarees() or []
    lignes = len(re.findall(r"Ligne\(vdot:", CAS.read_text()))
    print(f"Allures : les 4 allures du plan passent par Vdot, {len(noms)} fractions nommées, "
          f"{lignes} lignes de la table de Daniels.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
