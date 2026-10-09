#!/usr/bin/env python3
"""Une phrase qui s'accorde en genre doit exister dans les deux formes.

# POURQUOI CE CONTRÔLE EXISTE

RUNUP tutoie, et le tutoiement français s'accorde. Toute l'app était écrite au féminin — c'est sa
voix, et c'est délibéré. Mais un homme qui répond « Homme » à la question du profil, et à qui
l'app répond « tu es seule dans ce club », n'a pas affaire à une voix : il a affaire à une app
qui ne l'a pas écouté.

Quinze phrases ont été appariées. Le risque n'est pas celles-là : c'est la SEIZIÈME, écrite dans
six mois au féminin seul, sans que rien ne le signale. Une phrase mal accordée ne casse rien, ne
lève aucune alerte, et ne se voit que par la personne à qui elle s'adresse mal.

# LES DEUX RÈGLES

1. UN MARQUEUR DE FÉMININ NE S'ÉCRIT QUE DANS UN `Accord.selon`. La liste est courte et ne
   contient que des accords qui portent sur LA PERSONNE — pas « activité supprimée », qui
   s'accorde avec l'activité et n'a rien à voir avec qui la lit.

2. LES DEUX FORMES PORTENT LE MÊME ANGLAIS. L'anglais ne s'accorde pas : « you're on your own »
   est la traduction des deux. Deux anglais différents pour une seule phrase anglaise veut dire
   qu'on a traduit deux fois au lieu de recopier — et les deux versions divergeront.
"""
import glob
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE = RACINE / "RunUp/Resources/Localizable.xcstrings"
DOSSIERS = ["RunUp"]
# Le fichier qui DÉFINIT la règle en parle forcément, et ses commentaires citent les deux formes.
EXEMPTS = {"Accord.swift"}

# Les accords qui portent sur la personne à qui l'app parle. Volontairement COURTE : chaque mot
# ajouté ici doit être un mot qui ne peut décrire que « tu ». « première » n'y est pas — « ta
# première sortie » s'accorde avec la sortie, et le faux positif coûterait plus cher que l'oubli.
MARQUEURS = [
    "fatiguée", "prête", "seule dans", "régulière", "Débutante", "Confirmée",
    "Connectée en tant que", "tu es partie", "tu es rentrée", "minutes assise",
    "sois la première", "tu seras la première", "récupérée →",
]

# LES ACCORDS QUI NE PORTENT PAS SUR LA PERSONNE, ÉCRITS UN PAR UN.
#
# « Ta semaine est prête » s'accorde avec la semaine, « une allure régulière » avec l'allure. Un
# marqueur ne dit pas de QUOI il parle, donc la liste ci-dessus les attrape aussi — cinq fois sur
# treize à l'écriture de ce contrôle.
#
# Ils sont inscrits ici plutôt que retirés des marqueurs, et c'est tout l'intérêt : « prête » et
# « régulière » restent surveillés, donc une SEIZIÈME phrase qui les emploierait pour parler de
# la personne serait réclamée. Chaque ligne de cette liste est une décision écrite — « celui-ci
# s'accorde avec un nom » — et pas un trou dans la règle.
AUTORISES = [
    # La semaine, pas la coureuse.
    "Semaine \\(profile.weekNumber) prête",
    "Ta semaine est prête",
    # La routine, la sortie, l'allure.
    "Une routine régulière qui tient dans ta semaine",
    "longue, régulière, sans forcer",
    "Allure plutôt régulière du début à la fin",
]

APPEL = re.compile(
    r'Accord\.selon\(\s*f:\s*String\(localized:\s*"((?:[^"\\]|\\.)*)"\)\s*,\s*'
    r'm:\s*String\(localized:\s*"((?:[^"\\]|\\.)*)"\)\s*\)',
    re.S,
)


def fichiers():
    for dossier in DOSSIERS:
        for f in sorted((RACINE / dossier).rglob("*.swift")):
            if f.name not in EXEMPTS:
                yield f


def paires(source: str):
    """Les couples (féminin, masculin) écrits dans ce fichier."""
    return APPEL.findall(source)


def _sans_commentaires(source: str) -> str:
    return re.sub(r"//[^\n]*", "", source)


def marqueurs_hors_accord(source: str):
    """Les lignes qui portent un accord féminin SANS passer par `Accord.selon`.

    On retire d'abord tous les appels `Accord.selon(…)` du texte : ce qui reste et qui porte
    encore un marqueur est une phrase accordée qui n'a pas de jumelle.
    """
    texte = APPEL.sub(" ", _sans_commentaires(source))
    trouves = []
    for n, ligne in enumerate(texte.split("\n"), 1):
        if any(permis in ligne for permis in AUTORISES):
            continue
        for mot in MARQUEURS:
            if mot in ligne:
                trouves.append((n, mot, " ".join(ligne.split())[:96]))
                break
    return trouves


def cle_du_litteral(brut: str) -> str:
    """Le littéral Swift tel que le catalogue le nomme : une interpolation devient un substituant.

    `\\(club.name)` → `%@`, une interpolation ENTIÈRE → `%lld`.

    Reconnaître l'entier est ce qui demande de l'attention : le compilateur le sait par le type,
    ce script par le NOM. `Int(x)`, un compteur, une constante comme
    `UltraRaceDay.minutesEntreDeuxPrises` — tous donnent `%lld`, et s'y tromper fait chercher une
    clé qui n'existe pas, donc croire qu'une traduction manque alors qu'elle est là. La liste est
    explicite et se complète au besoin : mieux vaut une reconnaissance incomplète qui se signale
    qu'une devinette qui passe.
    """
    s = brut.replace('\\"', '"').replace("\\\\", "\\")
    entiers = ("Int(", "minutes", "Metres", "metres", "count", "Count", "number", "Number",
               "weekNumber", "readiness", "lld")
    return re.sub(
        r"\\\((?:[^()]|\([^()]*\))*\)",
        lambda m: "%lld" if any(mot in m.group(0) for mot in entiers) else "%@",
        s,
    )


def anglais_divergents(toutes, catalogue):
    """Les couples dont les deux formes portent deux anglais différents."""
    out = []
    for fem, masc in toutes:
        kf, km = cle_du_litteral(fem), cle_du_litteral(masc)
        ef = catalogue.get(kf, {}).get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value")
        em = catalogue.get(km, {}).get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value")
        if ef is None or em is None:
            out.append((kf, km, "absente du catalogue"))
        elif ef != em:
            out.append((kf, km, f"« {ef} » ≠ « {em} »"))
    return out


def main() -> int:
    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))["strings"]
    toutes, fautifs = [], []
    lus = 0
    for f in fichiers():
        lus += 1
        source = f.read_text(encoding="utf-8")
        toutes += paires(source)
        for ligne, mot, extrait in marqueurs_hors_accord(source):
            fautifs.append((f.relative_to(RACINE), ligne, mot, extrait))

    if fautifs:
        print(f"{len(fautifs)} phrase(s) s'accordent au féminin sans jumelle masculine :\n",
              file=sys.stderr)
        for chemin, ligne, mot, extrait in fautifs:
            print(f"  {chemin}:{ligne}  « {mot} »", file=sys.stderr)
            print(f"    {extrait}", file=sys.stderr)
        print("\nÉcris les DEUX formes et choisis entre elles :", file=sys.stderr)
        print('  Accord.selon(f: String(localized: "…"), m: String(localized: "…"))',
              file=sys.stderr)
        print("Un homme qui a répondu « Homme » au profil lira l'autre. Voir `Accord`.",
              file=sys.stderr)
        return 1

    if divergents := anglais_divergents(toutes, catalogue):
        print(f"{len(divergents)} couple(s) portent deux anglais différents :\n", file=sys.stderr)
        for kf, km, pourquoi in divergents:
            print(f"  « {kf[:60]} »\n  « {km[:60]} »\n    {pourquoi}", file=sys.stderr)
        print("\nL'anglais ne s'accorde pas : les deux formes ont la MÊME traduction anglaise.",
              file=sys.stderr)
        print("Deux anglais différents veut dire qu'on a traduit deux fois au lieu de recopier,",
              file=sys.stderr)
        print("et les deux versions finiront par diverger.", file=sys.stderr)
        return 1

    print(f"Accord : {lus} fichiers lus, {len(toutes)} phrases écrites dans les deux formes,")
    print("         aucun accord féminin isolé, anglais identique dans chaque couple.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
