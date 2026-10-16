#!/usr/bin/env python3
"""Le pluriel ne se décide pas avec `n > 1`, et pas deux fois de deux façons.

# LE DÉFAUT

En français, ZÉRO est au singulier : « 0 course », « 0 badge », « 0 jour de suite ». En anglais et
en espagnol, il est au PLURIEL : « 0 runs », « 0 badges », « 0 days in a row ».

Vingt-six sites de l'app écrivaient la bascule `n > 1` — la règle française, appliquée aux trois
langues. Une anglophone qui s'inscrit lit donc, le jour même : « 0 run » dans les Stats, « 0 badge »
et « 0 day in a row » sur son Profil, « 0 follower » dans le Club, « 0 run » dans l'Historique. Ce
sont les écrans d'un compte neuf, donc exactement les premiers qu'elle voit.

# L'AUTRE DÉFAUT, PLUS SILENCIEUX

Quatre de ces sites recollaient le « s » DANS la chaîne :

    String(localized: "\\(runs.count) sortie\\(runs.count > 1 ? "s" : "")")

La clé cherchée au catalogue était donc fabriquée à l'exécution : « %lld sortie » OU
« %lld sorties », et le catalogue ne contenait ni l'une ni l'autre. Ces quatre libellés sortaient
en français pour tout le monde, et `check_strings.py` ne pouvait pas le voir — il cherche les clés
par motif, interpolations remplacées par des jokers, et « %lld sortie%@ » ressemble à tout.
L'eyebrow de l'Historique, la tuile « JOURS » de l'écran course et le compte-rendu d'import Strava
étaient dans ce cas.

# CE QUE LE SCRIPT REFUSE

1. Une ternaire comparant un nombre à 1 dont une branche est une chaîne ou un `String(localized:)`.
   C'est la règle française écrite à la main : elle doit passer par `Pluriel.choisir`.
2. Un « s » recollé par interpolation (`? "s" : ""`, `? "S" : ""`, et leurs inverses).
3. Une langue au catalogue que `Pluriel.languesLivrees` ne connaît pas — sans quoi la règle
   française ou anglaise s'appliquerait en silence à une langue qui en a une autre.
"""

import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE = RACINE / "RunUp/Resources/Localizable.xcstrings"
PLURIEL = RACINE / "RunUp/Shared/Pluriel.swift"
DOSSIERS = ["RunUp", "RunUpWidgets", "RunUpWatch"]

# `Pluriel` lui-même compare bien un nombre à 1 : c'est sa raison d'être.
HORS_PERIMETRE = {"RunUp/Shared/Pluriel.swift"}

# Comparer un nombre à 1 n'est pas toujours un pluriel. Ensemble FERMÉ, une raison par ligne : une
# tolérance sans raison est une tolérance qu'on ne saura pas relire.
TOLEREES = {
    # « Première répétition » puis « Répétition 3/5 » : ce n'est pas un singulier contre un
    # pluriel, c'est la première répétition contre les suivantes. La phrase change entièrement.
    ("RunUp/ViewModels/LiveRunViewModel.swift", "showCue(n == 1"),
    # `progress >= 1` est un SEUIL d'avancement (l'objectif est atteint), pas un compte : « ✓ »
    # contre « À faire ».
    ("RunUpWidgets/DailyGoalsWidget.swift", "(snapshot.progress[safe: 0] ?? 0) >= 1 ?"),
}


def est_toleree(relatif: str, source: str, debut: int) -> bool:
    """La tolérance est reconnue sur le TEXTE de la ligne, pas sur son numéro : une ligne ajoutée
    ailleurs dans le fichier ne doit pas déplacer une exception."""
    debut_de_ligne = source.rfind("\n", 0, debut) + 1
    fin_de_ligne = source.find("\n", debut)
    ligne = source[debut_de_ligne:fin_de_ligne if fin_de_ligne != -1 else len(source)]
    return any(f == relatif and extrait in ligne for f, extrait in TOLEREES)

COMPARAISON = re.compile(r"(?:>=|<=|==|!=|>|<)\s*1\s*\)?\s*(?:\n\s*)?\?")
RECOLLE = re.compile(r'\?\s*"[sSxX]?"\s*:\s*"[sSxX]?"')
LANGUES = re.compile(r'static let languesLivrees = \[([^\]]*)\]')


def sans_commentaires(source: str) -> str:
    """Neutralise les commentaires en gardant les positions de ligne (un exemple en commentaire
    dans ce dépôt — il y en a — ne doit pas être signalé comme du code)."""
    sortie = []
    i, n, bloc = 0, len(source), 0
    while i < n:
        if bloc:
            if source.startswith("/*", i):
                bloc += 1; i += 2
            elif source.startswith("*/", i):
                bloc -= 1; i += 2
            else:
                sortie.append("\n" if source[i] == "\n" else " "); i += 1
            continue
        if source.startswith("/*", i):
            bloc = 1; sortie.append("  "); i += 2
        elif source.startswith("//", i):
            while i < n and source[i] != "\n":
                sortie.append(" "); i += 1
        else:
            sortie.append(source[i]); i += 1
    return "".join(sortie)


def branche_est_une_chaine(source: str, apres: int) -> bool:
    """Ce qui suit le `?` est-il un texte affiché ?

    On ne regarde que le PREMIER jeton de la branche : `nombres.count > 1 ? nombres[1] : 0` ne doit
    pas être signalé, et le lire jusqu'au `:` de la ternaire demanderait de compter les niveaux de
    parenthèses pour une question à laquelle le premier jeton répond déjà.
    """
    reste = source[apres:apres + 120].lstrip()
    return reste.startswith('"') or reste.startswith("String(localized:")


def problemes() -> list:
    erreurs = []

    for dossier in DOSSIERS:
        base = RACINE / dossier
        if not base.is_dir():
            continue
        for fichier in sorted(base.rglob("*.swift")):
            relatif = fichier.relative_to(RACINE).as_posix()
            if relatif in HORS_PERIMETRE:
                continue
            source = sans_commentaires(fichier.read_text(encoding="utf-8"))
            for m in COMPARAISON.finditer(source):
                if not branche_est_une_chaine(source, m.end()):
                    continue
                if est_toleree(relatif, source, m.start()):
                    continue
                ligne = source[:m.start()].count("\n") + 1
                erreurs.append(
                    f"{relatif}:{ligne} choisit un texte en comparant un nombre à 1 — "
                    f"c'est la règle française. Passe par `Pluriel.choisir(n, singulier, pluriel)`"
                )
            for m in RECOLLE.finditer(source):
                ligne = source[:m.start()].count("\n") + 1
                erreurs.append(
                    f"{relatif}:{ligne} recolle un « s » dans la chaîne — la clé est alors "
                    f"fabriquée à l'exécution et le catalogue ne la contient pas. Deux clés entières"
                )

    # --- Les langues livrées sont-elles toutes connues de `Pluriel` ? -----------------------------
    if not PLURIEL.exists():
        erreurs.append("RunUp/Shared/Pluriel.swift a disparu — plus rien ne porte la règle")
        return erreurs

    m = LANGUES.search(PLURIEL.read_text(encoding="utf-8"))
    if not m:
        erreurs.append("Pluriel.swift : `languesLivrees` est introuvable, le contrôle des langues "
                       "ne vérifie plus rien")
        return erreurs
    connues = set(re.findall(r'"([^"]+)"', m.group(1)))

    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    livrees = {catalogue.get("sourceLanguage", "fr")}
    for entree in catalogue.get("strings", {}).values():
        livrees |= set(entree.get("localizations", {}))

    for langue in sorted(livrees - connues):
        erreurs.append(
            f"« {langue} » est au catalogue mais absente de `Pluriel.languesLivrees` : "
            f"la règle du `default` (seul UN au singulier) lui serait appliquée sans l'avoir "
            f"vérifiée. Ajoute-la, après avoir regardé ce qu'elle fait de zéro"
        )
    for langue in sorted(connues - livrees):
        erreurs.append(
            f"« {langue} » est déclarée dans `Pluriel.languesLivrees` mais le catalogue ne la "
            f"contient pas — ou la langue a été retirée, ou le catalogue est incomplet"
        )
    return erreurs


def main() -> int:
    erreurs = problemes()
    if erreurs:
        print("Le pluriel est décidé à la main quelque part :\n")
        for erreur in erreurs:
            print(f"  ✗ {erreur}")
        print("\nZéro est singulier en français, pluriel en anglais et en espagnol.")
        return 1
    print("Pluriel : aucune règle française appliquée aux trois langues ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
