#!/usr/bin/env python3
"""Ce que `check_inscription.py` doit voir — le `PlanRecapView` d'avant correction en tête."""

import pathlib
import shutil
import sys
import tempfile

import check_inscription as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def depot(fichiers: dict) -> list:
    racine = pathlib.Path(tempfile.mkdtemp())
    try:
        dossier = racine / "RunUp/Views/Onboarding"
        dossier.mkdir(parents=True)
        for nom, source in fichiers.items():
            (dossier / nom).write_text(source, encoding="utf-8")
        avant = ck.INSCRIPTION
        ck.INSCRIPTION = dossier
        try:
            return ck.problemes()
        finally:
            ck.INSCRIPTION = avant
    finally:
        shutil.rmtree(racine, ignore_errors=True)


AVANT_CORRECTION = '''struct PlanRecapView: View {
    var body: some View {
        ObScreen {
            Spacer()
            VStack(spacing: 18) { Text("Ton plan") }
            Spacer()
            ObNext(label: "C'EST PARTI", action: onDone)
        }
    }
}
'''


@cas_test("PlanRecapView tel qu'il était")
def _():
    erreurs = depot({"PlanRecapView.swift": AVANT_CORRECTION})
    assert len(erreurs) == 1, erreurs
    assert "PlanRecapView.swift" in erreurs[0]


@cas_test("la correction par ObCorps passe")
def _():
    corrige = AVANT_CORRECTION.replace("Spacer()\n            VStack",
                                       "ObCorps {\n            VStack")
    assert depot({"PlanRecapView.swift": corrige}) == [], depot({"PlanRecapView.swift": corrige})


@cas_test("un écran qui a déjà son propre ScrollView passe")
def _():
    source = '''struct LevelStepView: View {
    var body: some View {
        ObScreen {
            ScrollView { VStack { Text("Niveau") } }
            ObNext(action: onNext)
        }
    }
}
'''
    assert depot({"LevelStepView.swift": source}) == []


@cas_test("un fichier qui n'emploie pas ObScreen n'est pas concerné")
def _():
    assert depot({"A.swift": "struct A: View { var body: some View { Text(\"x\") } }\n",
                  "B.swift": "struct B: View { var body: some View { ObScreen { ObCorps { Text(\"y\") } } } }\n"}) == []


@cas_test("un ObScreen en commentaire ne compte pas comme un écran")
def _():
    erreurs = depot({"A.swift": "// Avant : ObScreen { Spacer() }\nstruct A {}\n"})
    assert len(erreurs) == 1 and "Aucun écran" in erreurs[0], erreurs


@cas_test("un dossier sans écran est signalé")
def _():
    erreurs = depot({})
    assert len(erreurs) == 1 and "Aucun écran" in erreurs[0], erreurs


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
