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

@cas_test("« à pied » est une décision valable")
def _(): attendu("let total = runs.onFoot.reduce(0) { $0 + $1.distanceKm }", 0, "onFoot")

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

@cas_test("un filtre posé sur une propriété calculée vaut pour la somme plus bas")
def _(): attendu("    private var aPied: [RunRecord] { runs.onFoot }\n"
                 "    private var total: Double { aPied.reduce(0) { $0 + $1.distanceKm } }", 0,
                 "propriété calculée")

@cas_test("et à travers deux propriétés calculées")
def _(): attendu("    private var velo: [RunRecord] { runs.only(.bike) }\n"
                 "    private var longues: [RunRecord] { velo }\n"
                 "    private var total: Int { longues.reduce(0) { $0 + $1.durationSeconds } }", 0,
                 "deux niveaux")

@cas_test("une propriété calculée SANS filtre ne sauve rien")
def _(): attendu("    private var toutes: [RunRecord] { runs }\n"
                 "    private var x: Double { 0 }\n"
                 "    private var total: Double { toutes.reduce(0) { $0 + $1.distanceKm } }", 1,
                 "sans filtre")

@cas_test("une définition citée dans un commentaire ne définit rien")
def _(): attendu("    // private var aPied: [RunRecord] { runs.onFoot }\n"
                 "    private var x: Double { 0 }\n"
                 "    private var total: Double { aPied.reduce(0) { $0 + $1.distanceKm } }", 1,
                 "définition commentée")

@cas_test("une somme citée dans un commentaire ne compte pas")
def _(): attendu("// Écrire runs.reduce(0) { $0 + $1.distanceKm } était juste avant.", 0, "commentaire")

@cas_test("une somme sur autre chose qu'un relevé n'est pas regardée")
def _(): attendu("let t = paniers.reduce(0) { $0 + $1.prix }", 0, "hors sujet")

# ── Les drapeaux de `Discipline` ──────────────────────────────────────────────────────────────

def drapeaux(src, n, nom):
    t = ck.drapeaux_fautifs(src)
    assert len(t) == n, f"{nom} : {n} attendu(s), {len(t)} trouvé(s) → {t}"

@cas_test("un drapeau écrit `self == .run` est signalé")
def _(): drapeaux("    var wearsShoes: Bool { self == .run }", 1, "égalité")

@cas_test("un drapeau écrit `self != .bike` est signalé aussi")
def _(): drapeaux("    var usesPacePerKm: Bool { self != .bike }", 1, "inégalité")

@cas_test("un `contains(self)` est la même décision implicite")
def _(): drapeaux("    var aPied: Bool { [.run, .trail].contains(self) }", 1, "contains")

@cas_test("un drapeau sur plusieurs lignes est signalé")
def _(): drapeaux("    var wearsShoes: Bool {\n        self == .run\n    }", 1, "multi-lignes")

@cas_test("un `switch` exhaustif passe")
def _(): drapeaux("""    var wearsShoes: Bool {
        switch self {
        case .run, .trail: return true
        case .bike: return false
        }
    }""", 0, "switch")

@cas_test("un drapeau constant passe")
def _(): drapeaux("    var countsTowardStreak: Bool { true }", 0, "constante")

@cas_test("une comparaison citée dans un commentaire ne compte pas")
def _(): drapeaux("    /// Il était écrit `self == .run`, et c'était le défaut.\n    var wearsShoes: Bool {\n        switch self {\n        case .run: return true\n        case .bike: return false\n        }\n    }", 0, "commentaire")

@cas_test("une propriété qui n'est pas un booléen n'est pas regardée")
def _(): drapeaux('    var title: String { self == .run ? "Course" : "Vélo" }', 0, "non booléen")

@cas_test("deux drapeaux fautifs sont signalés tous les deux")
def _(): drapeaux("    var a: Bool { self == .run }\n    var b: Bool { self != .bike }", 2, "deux")

@cas_test("le vrai fichier `Discipline.swift` est propre")
def _():
    src = (ck.RACINE / ck.FICHIER_DISCIPLINE).read_text()
    drapeaux(src, 0, "fichier réel")
    assert len(ck.drapeaux(src)) >= 5, f"5 drapeaux attendus au moins, {len(ck.drapeaux(src))} vus"

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
