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

# ── LES QUATRE FORMES QUI LUI ÉCHAPPAIENT ─────────────────────────────────────────────────────
#
# Le garde-fou exigeait `var nom: Type = valeur` d'un seul tenant. Quatre écritures ordinaires
# passaient donc sous son nez, et la première est la plus probable qu'on écrive : on déclare la
# propriété et on l'initialise dans `init`. C'est la faute du build 1177, sous un autre habit.
@cas_test("sans valeur en ligne — initialisée dans `init`")
def _(): attendu("    var discipline: Discipline", 1, "pas de =")

@cas_test("type inféré de la valeur")
def _(): attendu("    var discipline = Discipline.run", 1, "pas de :")

@cas_test("derrière un `@Attribute(...)` à parenthèses")
def _(): attendu("    @Attribute(.externalStorage) var layout: WatchRunLayout = .standard", 1, "@Attribute")

@cas_test("derrière un modificateur d'accès")
def _(): attendu("    private var discipline: Discipline = .run", 1, "private")

@cas_test("un type inféré SANS préfixe ne déclenche rien — on se tait plutôt que d'accuser au hasard")
def _(): attendu("    var discipline = .run", 0, "indécidable")

# ── Ce que le script ne doit PLUS lire ────────────────────────────────────────────────────────
@cas_test("une structure imbriquée dans le modèle n'apporte pas ses champs")
def _():
    attendu("    struct Point: Codable {\n"
            "        var discipline: Discipline = .run\n"
            "    }\n"
            "    var titre: String = \"\"", 0, "imbriquée")

@cas_test("un corps de fonction non plus")
def _():
    attendu("    func refaire() {\n"
            "        var discipline: Discipline = .run\n"
            "    }", 0, "fonction")

@cas_test("une propriété calculée non plus")
def _(): attendu("    var discipline: Discipline {\n        .run\n    }", 0, "calculée")

@cas_test("`@Model` cité dans un commentaire ne fait pas relire le fichier")
def _():
    source = "// Une classe @Model ne doit pas faire ça.\n" + (MODELE % "    var d: Discipline = .run")
    t = ck.fautives(source)
    assert len(t) == 1, f"attendu 1 signalement, trouvé {len(t)} → {t}"

@cas_test("hors d'une classe @Model, rien n'est lu")
def _():
    source = "struct Reponse: Decodable {\n    var route: SharedRoute\n}\n" + (MODELE % "    var t: String = \"\"")
    assert ck.fautives(source) == [], ck.fautives(source)

# ── La liste close ────────────────────────────────────────────────────────────────────────────
@cas_test("les cinq propriétés d'origine sont nommées, et elles seulement")
def _():
    assert len(ck.TOLEREES) == 5, ck.TOLEREES
    assert ("UserProfile.swift", "goalId") in ck.TOLEREES

@cas_test("le dépôt tel qu'il est passe")
def _():
    import subprocess, sys as s2
    r = subprocess.run([s2.executable, "check_model_defaults.py"], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr

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
