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

# ── L'exhaustivité des `switch` ───────────────────────────────────────────────────────────────
#
# Les quatre cas « réels » reproduisent les quatre constructions mortes sur ce défaut. Les cas de
# tolérance comptent davantage : cette règle balaie 174 fichiers, et si elle refusait un `switch`
# juste, elle serait désactivée dans la semaine.

QUATRE = {"run", "bike", "trail", "swim"}

def troue(src, attendu, nom, cas=QUATRE):
    t = ck.switchs_non_exhaustifs(src, cas)
    manques = sorted(m for _, absents in t for m in absents)
    assert manques == sorted(attendu), f"{nom} : {sorted(attendu)} attendu, {manques} trouvé → {t}"

@cas_test("un `switch` sur une discipline à qui il manque un cas est signalé")
def _(): troue("switch d {\ncase .run: return 1\ncase .bike: return 2\ncase .trail: return 3\n}",
               ["swim"], "un manque")

@cas_test("deux cas manquants sont tous les deux nommés")
def _(): troue("switch d {\ncase .run: return 1\ncase .bike: return 2\n}",
               ["swim", "trail"], "deux manques")

@cas_test("des cas groupés sur une même ligne comptent chacun")
def _(): troue("switch d {\ncase .run, .trail: return 1\ncase .bike: return 2\n}",
               ["swim"], "groupés")

@cas_test("un `switch` exhaustif passe")
def _(): troue("switch d {\ncase .run: return 1\ncase .bike: return 2\n"
               "case .trail: return 3\ncase .swim: return 4\n}", [], "exhaustif")

@cas_test("un `switch` avec `default` n'est pas de son ressort")
def _(): troue("switch d {\ncase .run: return 1\ndefault: return 0\n}", [], "default")

@cas_test("un `switch` sur une autre énumération est laissé tranquille")
def _(): troue("switch kind {\ncase .run: return 1\ncase .walk: return 2\n}", [], "autre énumération")

@cas_test("un `switch` imbriqué ne verse pas ses cas dans celui du dessus")
def _(): troue("switch d {\ncase .run:\n  switch effort {\n  case .facile: return 1\n"
               "  case .dur: return 2\n  }\ncase .bike: return 3\ncase .trail: return 4\n"
               "case .swim: return 5\n}", [], "imbriqué")

@cas_test("un `switch` cité dans un commentaire n'en est pas un")
def _(): troue("// switch d { case .run: return 1 }\n/// case .bike: return 2", [], "commentaire")

@cas_test("un `switch` sur un tuple de disciplines n'est pas lu comme une discipline")
def _(): troue("switch (a, b) {\ncase (.run, .bike): return 1\ndefault: return 0\n}", [], "tuple")

@cas_test("les cas de `Discipline` sont lus à la source, pas écrits en dur")
def _():
    src = (ck.RACINE / ck.FICHIER_DISCIPLINE).read_text()
    lus = ck.cas_de_discipline(src)
    assert "swim" in lus and "run" in lus, f"cas lus : {sorted(lus)}"
    assert len(lus) >= 4, f"au moins 4 disciplines attendues, {len(lus)} lues"

# Les quatre `switch` qui ont réellement tué une construction, recopiés tels qu'ils étaient.
#
# Figés en littéral et PAS relus dans l'historique git. La première version de ce test faisait
# `git show HEAD~2:…`, ce qui a deux défauts : un clone peu profond n'a pas cet objet, et surtout
# la position du commit change à chaque commit — le test est passé en local, puis a échoué dans la
# minute où la correction a été commitée, parce que `HEAD` désignait désormais le code corrigé.
# Un cas de test ne doit pas dépendre d'où l'on se trouve dans l'histoire.
MORTS = [
    ("LiveRunView 292", """    private var libelleEtat: LocalizedStringKey {
        switch vm?.discipline ?? .run {
        case .run: return "EN DIRECT"
        case .bike: return "VÉLO · EN DIRECT"
        case .trail: return "TRAIL · EN DIRECT"
        }
    }"""),
    ("Calories 43", """    static func estimate(_ discipline: Discipline, distanceKm: Double, durationMinutes: Int) -> Double {
        switch discipline {
        case .run:  return estimate(distanceKm: distanceKm, durationMinutes: durationMinutes)
        case .bike: return Double(durationMinutes) * perCyclingMinute
        case .trail: return estimate(distanceKm: distanceKm, durationMinutes: durationMinutes)
        }
    }"""),
    ("AutoPause 61", """        static func pour(_ discipline: Discipline) -> Seuils {
            switch discipline {
            case .run: return Seuils(pause: 0.6, reprise: 1.2, eloignement: 12)
            case .bike: return Seuils(pause: 1.2, reprise: 2.4, eloignement: 25)
            case .trail: return Seuils(pause: 0.4, reprise: 0.9, eloignement: 18)
            }
        }"""),
    ("TabBarView 163", """    private var libelle: String {
        switch discipline {
        case .run: return "Démarrer une course"
        case .bike: return "Démarrer une sortie vélo"
        case .trail: return "Démarrer une sortie trail"
        }
    }"""),
]

@cas_test("les quatre constructions mortes sur ce défaut auraient été attrapées ici")
def _():
    for nom, source in MORTS:
        t = ck.switchs_non_exhaustifs(source, QUATRE)
        assert [absents for _, absents in t] == [["swim"]], f"{nom} non attrapé → {t}"

@cas_test("les quatre, une fois corrigées, passent")
def _():
    for nom, source in MORTS:
        corrige = source.replace("case .trail:", 'case .swim: return nil\n        case .trail:')
        t = ck.switchs_non_exhaustifs(corrige, QUATRE)
        assert t == [], f"{nom} refusé alors qu'il est corrigé → {t}"

@cas_test("le vrai code est exhaustif partout")
def _():
    cas = ck.cas_de_discipline((ck.RACINE / ck.FICHIER_DISCIPLINE).read_text())
    troues = []
    for dossier in ck.DOSSIERS_SWITCH:
        racine = ck.RACINE / dossier
        if not racine.exists():
            continue
        for f in sorted(racine.rglob("*.swift")):
            if f.name in ck.EXEMPTS:
                continue
            for ligne, absents in ck.switchs_non_exhaustifs(f.read_text(), cas):
                troues.append(f"{f.relative_to(ck.RACINE)}:{ligne} {absents}")
    assert not troues, f"{len(troues)} `switch` troué(s) : {troues[:5]}"


# ── Les types de séance, et leurs traductions ─────────────────────────────────────────────────

SOURCE_TYPES = """
    var typesDeSeanceSaisis: [String] {
        switch self {
        case .run: return ["Footing", "Autre"]
        // « Côtes » cité ici n'est pas une entrée de la liste.
        case .bike: return ["Sortie vélo"]
        case .trail: return ["Sortie trail"]
        case .swim: return ["Nage"]
        }
    }
"""

@cas_test("les types de séance sont lus dans les quatre listes")
def _():
    lus = ck.types_de_seance(SOURCE_TYPES)
    assert lus == ["Footing", "Autre", "Sortie vélo", "Sortie trail", "Nage"], lus

def _traduit(mot):
    return {"localizations": {l: {"stringUnit": {"value": mot}} for l in ck.LANGUES}}

@cas_test("un type absent du catalogue est signalé, et lui seul")
def _():
    catalogue = {c: _traduit(c) for c in ["Footing", "Autre", "Sortie vélo", "Sortie trail"]}
    t = ck.types_non_traduits(SOURCE_TYPES, catalogue)
    assert [c for c, _ in t] == ["Nage"], t

@cas_test("un type présent mais sans traduction anglaise est signalé")
def _():
    entree = {"localizations": {"es": {"stringUnit": {"value": "Natación"}}}}
    t = ck.types_non_traduits('var typesDeSeanceSaisis: [String] {\ncase .swim: return ["Nage"]\n    }',
                              {"Nage": entree})
    assert len(t) == 1 and "en" in t[0][1], t

@cas_test("un type traduit dans les deux langues passe")
def _():
    entree = {"localizations": {"en": {"stringUnit": {"value": "Swim"}},
                                "es": {"stringUnit": {"value": "Natación"}}}}
    t = ck.types_non_traduits('var typesDeSeanceSaisis: [String] {\ncase .swim: return ["Nage"]\n    }',
                              {"Nage": entree})
    assert t == [], t

@cas_test("le vrai `Discipline.swift` a ses types tous traduits, un par discipline au moins")
def _():
    import json
    src = (ck.RACINE / ck.FICHIER_DISCIPLINE).read_text()
    catalogue = json.loads((ck.RACINE / ck.CATALOGUE).read_text())["strings"]
    t = ck.types_non_traduits(src, catalogue)
    assert t == [], f"non traduits : {t}"
    assert len(ck.types_de_seance(src)) >= len(ck.cas_de_discipline(src)), "une liste est vide"


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
