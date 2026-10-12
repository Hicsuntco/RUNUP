#!/usr/bin/env python3
"""Toute feuille s'ouvre avec le fond, les coins et la poignée de l'app.

# LE DÉFAUT QUE CE SCRIPT EMPÊCHE DE REVENIR

Neuf feuilles sur trente-trois s'ouvraient avec l'habillage du SYSTÈME : fond clair dans une
app sombre, coins à 10 points au lieu de 26, aucune poignée de glissement. Ajouter une connexion,
une paire de chaussures, une course à la main, ouvrir les réglages ou les commentaires d'une
activité — à chaque fois, une page blanche montait de l'écran.

Rien ne cassait. `runUpSheetStyle` existait, vingt-quatre feuilles l'appliquaient, et personne
n'avait de raison de remarquer les neuf autres une par une. C'est le propre d'un style qu'on
applique à la main : il manque là où personne n'a regardé.

# CE QUE LE SCRIPT VÉRIFIE

Chaque `.sheet(…) { … }` doit poser `runUpSheetStyle` dans sa fermeture de contenu — ou
présenter une vue qui se style elle-même, ce que font `RecapView` et `MoreSettingsView`.

Les `fullScreenCover` sont hors sujet : ils occupent l'écran entier, il n'y a ni coin ni poignée
à accorder.
"""
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
VUES = RACINE / "RunUp"


def sans_commentaires(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def fin_de_parentheses(s: str, debut: int) -> int:
    """L'index de la parenthèse fermante qui referme celle ouverte à `debut`."""
    prof = 0
    for i in range(debut, len(s)):
        if s[i] == "(":
            prof += 1
        elif s[i] == ")":
            prof -= 1
            if prof == 0:
                return i
    return -1


def fin_daccolades(s: str, debut: int) -> int:
    prof = 0
    for i in range(debut, len(s)):
        if s[i] == "{":
            prof += 1
        elif s[i] == "}":
            prof -= 1
            if prof == 0:
                return i
    return -1


def fermetures_de_contenu(source: str):
    """(ligne, corps) de la fermeture de contenu de chaque `.sheet(…)`.

    La fermeture de contenu est celle qui suit la parenthèse FERMANTE de l'appel — pas la
    première accolade rencontrée. Sans cette précision, un `.sheet(isPresented: Binding(get: {
    … }))` ferait lire le corps du `get` à la place du contenu, et cinq feuilles parfaitement
    stylées de `RootTabView` seraient accusées à tort.
    """
    for m in re.finditer(r"\.sheet\(", source):
        fin = fin_de_parentheses(source, m.end() - 1)
        if fin == -1:
            continue
        reste = source[fin + 1:]
        avant = reste[:len(reste) - len(reste.lstrip())]
        if "{" not in reste[:len(avant) + 1]:
            suite = reste.lstrip()
            if not suite.startswith("{"):
                continue
        ouvrante = source.index("{", fin)
        fermante = fin_daccolades(source, ouvrante)
        if fermante == -1:
            continue
        yield source[:m.start()].count("\n") + 1, source[ouvrante:fermante + 1]


def problemes(sources=None):
    if sources is None:
        sources = {str(p.relative_to(RACINE)): p.read_text(encoding="utf-8")
                   for p in sorted(VUES.rglob("*.swift"))}
    propres = sans_commentaires_partout(sources)

    # Les vues qui portent leur style elles-mêmes.
    autonomes = set()
    for source in propres.values():
        if "runUpSheetStyle" in source or "presentationDetents" in source:
            autonomes |= set(re.findall(r"\bstruct\s+([A-Z]\w*)\s*:\s*View\b", source))

    griefs = []
    total = 0
    for nom, source in propres.items():
        for ligne, bloc in fermetures_de_contenu(source):
            total += 1
            if "runUpSheetStyle" in bloc or "presentationDetents" in bloc:
                continue
            vues = set(re.findall(r"\b([A-Z]\w*)\s*\(", bloc))
            if vues & autonomes:
                continue
            presentee = ", ".join(sorted(vues)) or "?"
            griefs.append(
                f"{nom}:{ligne} présente {presentee} sans `runUpSheetStyle`.\n"
                f"      Elle s'ouvrira avec l'habillage du système : fond clair dans une app\n"
                f"      sombre, coins à 10 points, aucune poignée."
            )
    if total == 0:
        return ["Aucune feuille trouvée — le script ne vérifie plus rien."]
    return griefs


def sans_commentaires_partout(sources):
    return {nom: sans_commentaires(s) for nom, s in sources.items()}


def main() -> int:
    griefs = problemes()
    if griefs:
        print(f"{len(griefs)} feuille(s) sans l'habillage de l'app :\n")
        for g in griefs:
            print(f"  • {g}\n")
        print("Voir `runUpSheetStyle` dans RunUp/Views/Components/SheetPresentationModifier.swift.")
        return 1
    print("Feuilles : toutes passent par `runUpSheetStyle`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
