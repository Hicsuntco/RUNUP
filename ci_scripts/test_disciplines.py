#!/usr/bin/env python3
"""Vérifie `check_disciplines.py` sur des cas écrits exprès.

Ce qui est vérifié ici, c'est surtout ce que l'analyse doit LAISSER PASSER : une barrière qui
refuse du code juste finit contournée, et elle aura coûté plus cher que le défaut qu'elle
cherchait.
"""
import sys
import check_disciplines as ck

cas = []
def cas_test(nom):
    def deco(f):
        cas.append((nom, f)); return f
    return deco

def attendu(src, n, nom):
    t = ck.lignes_fautives(src)
    assert len(t) == n, f"{nom} : {n} attendu(s), {len(t)} trouvé(s) → {t}"

# ── Ce qu'il doit attraper ────────────────────────────────────────────────────────────────────
@cas_test("une somme nue de distance est signalée")
def _(): attendu("let total = runs.reduce(0) { $0 + $1.distanceKm }", 1, "somme nue")

@cas_test("un maximum nu de distance est signalé")
def _(): attendu("let plusLongue = runs.map(\\.distanceKm).max() ?? 0", 1, "max nu")

@cas_test("un max(by:) nu est signalé")
def _(): attendu("let l = runs.max(by: { $0.distanceKm < $1.distanceKm })", 1, "max(by:) nu")

@cas_test("une meilleure allure nue est signalée")
def _(): attendu("let best = runs.compactMap { PaceModel.parseSecPerKm($0.avgPace) }.min()", 1, "allure nue")

@cas_test("une variable filtrée sur AUTRE CHOSE ne suffit pas")
def _():
    attendu("let recentes = runs.filter { $0.date > debut }\nlet t = recentes.reduce(0) { $0 + $1.distanceKm }",
            1, "filtre sans discipline")

# ── Ce qu'il doit laisser passer ──────────────────────────────────────────────────────────────
@cas_test("une somme explicite passe")
def _(): attendu("let total = runs.only(.run).reduce(0) { $0 + $1.distanceKm }", 0, "only sur la ligne")

@cas_test("« toutes disciplines » est une décision valable")
def _(): attendu("let jours = runs.allDisciplines.map(\\.date)\nlet t = runs.allDisciplines.reduce(0) { $0 + $1.durationSeconds }", 0, "allDisciplines")

@cas_test("un filtre posé sur une variable plus haut vaut pour la somme plus bas")
def _():
    attendu("let courses = runs.only(.run)\nlet total = courses.reduce(0) { $0 + $1.distanceKm }", 0, "variable filtrée")

@cas_test("et à travers un deuxième niveau")
def _():
    attendu("let courses = allRuns.only(run.discipline)\n"
            "let proches = courses.filter { $0.distanceKm > 1 }\n"
            "let best = proches.compactMap { PaceModel.parseSecPerKm($0.avgPace) }.min()", 0, "deux niveaux")

@cas_test("un filtre posé sur la ligne du dessus passe")
def _():
    attendu("let total = runs.only(.run)\n    .reduce(0) { $0 + $1.distanceKm }", 0, "chaîne sur deux lignes")

@cas_test("une somme citée dans un commentaire ne compte pas")
def _(): attendu("// Écrire runs.reduce(0) { $0 + $1.distanceKm } était juste avant.", 0, "commentaire")

@cas_test("une somme sur autre chose qu'un relevé n'est pas regardée")
def _(): attendu("let t = paniers.reduce(0) { $0 + $1.prix }", 0, "hors sujet")

def main():
    echecs = 0
    for nom, f in cas:
        try:
            f(); print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1; print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0

if __name__ == "__main__":
    sys.exit(main())
