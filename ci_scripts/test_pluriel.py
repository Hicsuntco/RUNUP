#!/usr/bin/env python3
"""Ce que `check_pluriel.py` doit voir, et ce qu'il ne doit pas inventer.

Les extraits sont FIGÉS : ce sont les lignes réelles de l'app avant correction, et les lignes
réelles qui comparent un nombre à 1 sans que ce soit un pluriel. Un contrôle qui confondrait les
deux serait désactivé dans la semaine.
"""

import re
import sys

import check_pluriel as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def signale(extrait: str) -> bool:
    """L'extrait déclenche-t-il la règle « nombre comparé à 1 pour choisir un texte » ?"""
    source = ck.sans_commentaires(extrait)
    for m in ck.COMPARAISON.finditer(source):
        if ck.branche_est_une_chaine(source, m.end()):
            return True
    return False


# --- Ce qui DOIT être signalé -------------------------------------------------------------------

@cas_test("le libellé d'unité des Stats, tel qu'il était")
def _():
    assert signale('unit: runsOnFoot.count > 1 ? "sorties" : "sortie",')


@cas_test("les deux clés du Profil, sur une seule ligne")
def _():
    assert signale('label: badgeCount > 1 ? String(localized: "badges") : String(localized: "badge")')


@cas_test("la ternaire écrite sur trois lignes")
def _():
    assert signale('Text(active.count > 1\n'
                   '     ? String(localized: "\\(active.count) membres ont couru")\n'
                   '     : String(localized: "\\(active.count) membre a couru"))')


@cas_test("la forme == 1, qui est la règle anglaise appliquée au français")
def _():
    assert signale('Text(count == 1\n'
                   '     ? String(localized: "1 course")\n'
                   '     : String(localized: "\\(count) courses"))')


@cas_test("la comparaison entre parenthèses")
def _():
    assert signale('String(localized: "JOUR\\((profile.daysUntilRace ?? 2) > 1 ? "S" : "")")')


@cas_test("le « s » recollé, dans les deux sens")
def _():
    assert ck.RECOLLE.search('"sortie\\(n > 1 ? "s" : "")"')
    assert ck.RECOLLE.search('"JOUR\\(n > 1 ? "S" : "")"')
    assert ck.RECOLLE.search('"sortie\\(n == 1 ? "" : "s")"')


# --- Ce qui NE DOIT PAS être signalé -------------------------------------------------------------

@cas_test("une ternaire qui ne rend pas un texte")
def _():
    assert not signale('let minutes = nombres.count > 1 ? nombres[1] : 0')


@cas_test("un seuil d'avancement n'est pas un compte")
def _():
    # `>= 1` sur une progression de 0 à 1 : c'est l'objectif atteint, pas « un objectif ».
    extrait = '(snapshot.progress[safe: 0] ?? 0) >= 1 ? "✓" : String(localized: "À faire")'
    assert signale(extrait), "la règle brute le voit…"
    assert ck.est_toleree("RunUpWidgets/DailyGoalsWidget.swift", extrait, extrait.index(">= 1")), \
        "…et la tolérance doit le reconnaître"


@cas_test("la première répétition contre les suivantes n'est pas un pluriel")
def _():
    extrait = '            showCue(n == 1\n                ? "Échauffement terminé."\n                : "Répétition \\(n)/\\(reps)")'
    position = extrait.index("== 1")
    assert ck.est_toleree("RunUp/ViewModels/LiveRunViewModel.swift", extrait, position)


@cas_test("une tolérance ne vaut que pour SON fichier")
def _():
    extrait = 'showCue(n == 1'
    assert not ck.est_toleree("RunUp/Views/Home/HomeView.swift", extrait, extrait.index("== 1"))


@cas_test("un exemple en commentaire ne déclenche rien")
def _():
    assert not signale('// Avant : label: count > 1 ? String(localized: "badges") : "badge"')
    assert not signale('/* count > 1 ? "sorties" : "sortie" */')


@cas_test("une comparaison à un autre nombre que 1 n'est pas concernée")
def _():
    assert not signale('Text(importedCount == 0 ? String(localized: "Rien") : String(localized: "Des"))')
    assert not signale('Text(count > 10 ? String(localized: "Beaucoup") : String(localized: "Peu"))')


# --- Les langues ---------------------------------------------------------------------------------

@cas_test("les langues livrées sont lues depuis Pluriel.swift")
def _():
    m = ck.LANGUES.search(ck.PLURIEL.read_text(encoding="utf-8"))
    assert m, "`languesLivrees` est introuvable"
    assert set(re.findall(r'"([^"]+)"', m.group(1))) == {"fr", "en", "es"}


# --- Le dépôt ------------------------------------------------------------------------------------

@cas_test("le dépôt tel qu'il est passe")
def _():
    assert ck.problemes() == [], ck.problemes()


def main() -> int:
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  FAIL {nom}\n       {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
