#!/usr/bin/env python3
"""Vérifie `check_model_defaults.py`, y compris sur la ligne qui a réellement fait planter l'app.

Ce qu'il doit LAISSER PASSER compte plus que le reste : les modèles de cette app sont pleins de
primitives non optionnelles avec défaut, qui fonctionnent. Une barrière qui les refuserait serait
contournée dès le lendemain.
"""
import sys
import check_model_defaults as ck

cas = []
def cas_test(nom):
    def deco(f):
        cas.append((nom, f)); return f
    return deco

MODELE = "@Model\nfinal class RunRecord {\n%s\n}\n"

def attendu(corps, n, nom):
    t = ck.fautives(MODELE % corps)
    assert len(t) == n, f"{nom} : {n} attendu(s), {len(t)} trouvé(s) → {t}"

# ── La ligne qui a planté ─────────────────────────────────────────────────────────────────────
@cas_test("la ligne exacte du build 1177 est refusée")
def _(): attendu("    var discipline: Discipline = Discipline.run", 1, "le crash")

@cas_test("une structure personnalisée non optionnelle aussi")
def _(): attendu("    var layout: WatchRunLayout = WatchRunLayout.standard", 1, "struct")

# ── Ce qu'il doit laisser passer ──────────────────────────────────────────────────────────────
@cas_test("la même, optionnelle, passe")
def _(): attendu("    var sessionKind: SessionKind? = nil", 0, "optionnel")

@cas_test("les primitives non optionnelles passent — les modèles en sont pleins")
def _():
    attendu("    var weatherAlertsEnabled: Bool = true\n"
            "    var averageCycleLengthDays: Int = 28\n"
            "    var weekTier: Int = 1\n"
            "    var title: String = \"\"\n"
            "    var date: Date = Date.now", 0, "primitives")

@cas_test("les collections passent")
def _():
    attendu("    var route: [RoutePoint] = []\n"
            "    var weekSessions: [PlannedDay] = []", 0, "collections")

@cas_test("la sortie recommandée passe : texte brut optionnel + propriété calculée")
def _():
    attendu("    var disciplineRaw: String? = nil\n"
            "    var discipline: Discipline {\n"
            "        get { disciplineRaw.flatMap(Discipline.init(rawValue:)) ?? .legacy }\n"
            "        set { disciplineRaw = newValue.rawValue }\n"
            "    }", 0, "le remède")

@cas_test("une propriété calculée sans défaut n'est pas une propriété stockée")
def _(): attendu("    var isLong: Bool { distanceKm > 15 }", 0, "calculée")

@cas_test("une ligne commentée ne compte pas")
def _(): attendu("    // var discipline: Discipline = Discipline.run", 0, "commentaire")

@cas_test("un fichier sans @Model n'est pas regardé")
def _():
    assert ck.fautives("struct Reglages {\n    var mode: Mode = Mode.auto\n}") == [], "hors modèle"

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
