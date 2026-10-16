#!/usr/bin/env python3
"""Ce que `check_cibles.py` doit voir, et ce qu'il ne doit pas inventer.

Les deux premiers cas sont les deux pannes réelles, rejouées telles quelles : `PlanRecap` du
build 250 et `DailyGoalsSnapshot` du build 278. Un contrôle qui ne les rattrape pas ne sert à rien.
"""

import shutil
import sys
import tempfile
from pathlib import Path

import check_cibles as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


PROJECT_YML_TYPE = """\
name: RunUp
targets:
  RunUp:
    sources:
      - path: RunUp
  RunUpWidgets:
    type: app-extension
    sources:
      - path: RunUpWidgets
      - path: RunUp/Shared
        excludes:
          - "RouteGeometry.swift"
    resources:
      - path: RunUp/Resources/Fonts
  RunUpWatch:
    sources:
      - path: RunUpWatch
      - path: RunUp/Shared/ColorHex.swift
"""


def depot(partage: dict, app: dict, widgets: dict = None, montre: dict = None,
          project_yml: str = PROJECT_YML_TYPE):
    """Monte un faux dépôt sur disque et y pointe `check_cibles`. Rend les erreurs relevées."""
    racine = Path(tempfile.mkdtemp())
    try:
        (racine / "project.yml").write_text(project_yml, encoding="utf-8")
        for dossier, fichiers in (
            ("RunUp/Shared", partage),
            ("RunUp/DesignSystem", app),
            ("RunUpWidgets", widgets or {}),
            ("RunUpWatch", montre or {}),
        ):
            (racine / dossier).mkdir(parents=True, exist_ok=True)
            for nom, source in fichiers.items():
                (racine / dossier / nom).write_text(source, encoding="utf-8")
        avant = ck.RACINE
        ck.RACINE = racine
        try:
            return ck.verifier()
        finally:
            ck.RACINE = avant
    finally:
        shutil.rmtree(racine, ignore_errors=True)


@cas_test("build 250 : PlanRecap référençait OnboardingViewModel depuis Shared/")
def _():
    erreurs = depot(
        partage={"PlanRecap.swift": "struct PlanRecap {\n    let vm: OnboardingViewModel\n}\n"},
        app={"OnboardingViewModel.swift": "final class OnboardingViewModel {}\n"},
    )
    assert len(erreurs) == 1, erreurs
    assert "OnboardingViewModel" in erreurs[0]
    assert "PlanRecap.swift:2" in erreurs[0], erreurs[0]
    assert "RunUpWidgets" in erreurs[0]


@cas_test("build 278 : AccentTheme.defaultID comme valeur par défaut d'un décodage")
def _():
    erreurs = depot(
        partage={"DailyGoalsSnapshot.swift":
                 'struct S {\n    var id = c.decode() ?? AccentTheme.defaultID\n}\n'},
        app={"AccentTheme.swift": 'struct AccentTheme {\n    static let defaultID = "rose"\n}\n'},
    )
    assert len(erreurs) == 1, erreurs
    assert "AccentTheme" in erreurs[0]


@cas_test("le littéral recopié passe — c'est la correction retenue")
def _():
    erreurs = depot(
        partage={"DailyGoalsSnapshot.swift":
                 'struct S {\n    var id = c.decode() ?? "rose"\n}\n'},
        app={"AccentTheme.swift": 'struct AccentTheme {\n    static let defaultID = "rose"\n}\n'},
    )
    assert erreurs == [], erreurs


@cas_test("un type du widget lui-même est visible")
def _():
    erreurs = depot(
        partage={"A.swift": "struct A {\n    let v: VueDuWidget\n}\n"},
        app={},
        widgets={"VueDuWidget.swift": "struct VueDuWidget {}\n"},
    )
    assert erreurs == [], erreurs


@cas_test("un type déclaré ailleurs dans Shared/ est visible")
def _():
    erreurs = depot(
        partage={"A.swift": "struct A {\n    let d: Discipline\n}\n",
                 "Discipline.swift": "enum Discipline { case course }\n"},
        app={},
    )
    assert erreurs == [], erreurs


@cas_test("un fichier EXCLU de la cible n'y rend pas ses types visibles")
def _():
    # C'est la nuance du vrai `project.yml` : `RouteGeometry.swift` est exclu du widget. Un autre
    # fichier partagé qui s'appuierait sur lui compilerait dans l'app et pas dans l'extension.
    erreurs = depot(
        partage={"A.swift": "struct A {\n    let g: RouteGeometry\n}\n",
                 "RouteGeometry.swift": "struct RouteGeometry {}\n"},
        app={},
    )
    assert erreurs == [], erreurs  # RouteGeometry est déclaré dans Shared/, pas dans l'app


@cas_test("le fichier exclu peut, lui, référencer l'app sans que ça compte pour le widget")
def _():
    erreurs = depot(
        partage={"RouteGeometry.swift": "struct RouteGeometry {\n    let r: RunRecord\n}\n"},
        app={"RunRecord.swift": "final class RunRecord {}\n"},
    )
    assert erreurs == [], erreurs


@cas_test("la montre ne prend qu'un fichier nommé : les autres ne la concernent pas")
def _():
    erreurs = depot(
        partage={"ColorHex.swift": "struct ColorHex {\n    let t: TypeDeLApp\n}\n"},
        app={"TypeDeLApp.swift": "struct TypeDeLApp {}\n"},
    )
    cibles = sorted({"RunUpWatch" in e for e in erreurs})
    assert len(erreurs) == 2, erreurs  # widget ET montre compilent ColorHex.swift
    assert cibles == [False, True], erreurs


@cas_test("un nom en commentaire ou en chaîne ne déclenche rien")
def _():
    erreurs = depot(
        partage={"A.swift": 'struct A {\n'
                            '    // AccentTheme.defaultID vaut "rose"\n'
                            '    /* AccentTheme */\n'
                            '    let nom = "AccentTheme"\n'
                            '}\n'},
        app={"AccentTheme.swift": "struct AccentTheme {}\n"},
    )
    assert erreurs == [], erreurs


@cas_test("un project.yml où plus aucune cible ne compile Shared/ est signalé")
def _():
    erreurs = depot(
        partage={"A.swift": "struct A {}\n"},
        app={},
        project_yml="name: RunUp\ntargets:\n  RunUp:\n    sources:\n      - path: RunUp\n",
    )
    assert len(erreurs) == 1 and "aucune cible" in erreurs[0], erreurs


@cas_test("le dépôt tel qu'il est passe")
def _():
    assert ck.verifier() == [], ck.verifier()


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
