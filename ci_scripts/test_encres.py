#!/usr/bin/env python3
"""Ce que `check_encres.py` doit voir.

Le premier cas est le DÉFAUT RÉEL du 12 novembre : le widget est resté à `#15151C` quand l'app est
passée au chaud. Il n'a été trouvé qu'en cherchant l'ancienne valeur dans tout le dépôt, à la main,
après coup — c'est-à-dire par chance.
"""

import pathlib
import re
import sys
import tempfile

import check_encres as ck
import couleurs

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def _avec(relatif: str, source: str) -> list:
    """Les écarts quand un des fichiers surveillés contient `source`."""
    dossier = pathlib.Path(tempfile.mkdtemp())
    faux = dossier / relatif          # le chemin COMPLET : le garde résout `RACINE / relatif`
    faux.parent.mkdir(parents=True, exist_ok=True)
    faux.write_text(source, encoding="utf-8")
    vraie = ck.RACINE
    try:
        # On redirige la racine vers un dossier où seul le fichier fabriqué existe, pour que les
        # autres correspondances signalent « introuvable » et que seule celle-ci soit lue.
        ck.RACINE = dossier
        return [p for p in ck.ecarts() if pathlib.Path(relatif).name in p[0]]
    finally:
        ck.RACINE = vraie


@cas_test("le widget resté à l'ancienne encre est refusé (le défaut du 12 novembre)")
def _():
    src = "private var textPrimary: Color { isLight ? Color(hex: 0x15151C) : .white }"
    problemes = _avec("RunUpWidgets/DailyGoalsWidget.swift", src)
    assert problemes, "le garde n'a rien vu"
    assert "15151C" in problemes[0][2], problemes


@cas_test("le widget à la bonne encre passe")
def _():
    attendu = couleurs.declarations()["textPrimary"]["clair"]
    src = f"private var textPrimary: Color {{ isLight ? Color(hex: 0x{attendu:06X}) : .white }}"
    assert _avec("RunUpWidgets/DailyGoalsWidget.swift", src) == []


@cas_test("une correspondance qui ne trouve plus sa valeur crie au lieu de dormir")
def _():
    problemes = _avec("RunUpWidgets/DailyGoalsWidget.swift", "// plus aucune encre ici\n")
    assert problemes, "un garde qui ne trouve rien doit le dire"
    assert "ne se lit plus" in problemes[0][2], problemes


@cas_test("une encre citée dans un COMMENTAIRE ne compte pas pour la vraie")
def _():
    attendu = couleurs.declarations()["textPrimary"]["clair"]
    src = ("// Elle valait Color(hex: 0x15151C) avant le 12 novembre.\n"
           f"private var textPrimary: Color {{ isLight ? Color(hex: 0x{attendu:06X}) : .white }}")
    assert _avec("RunUpWidgets/DailyGoalsWidget.swift", src) == []


@cas_test("chaque fichier surveillé existe vraiment")
def _():
    for relatif, _, _, _, _ in ck.CORRESPONDANCES:
        assert (couleurs.RACINE / relatif).is_file(), relatif


@cas_test("chaque correspondance nomme un jeton réel de RUColor")
def _():
    jetons = couleurs.declarations()
    for _, _, jeton, theme, _ in ck.CORRESPONDANCES:
        assert isinstance(jetons.get(jeton, {}).get(theme), int), (jeton, theme)


@cas_test("chaque correspondance porte une raison écrite")
def _():
    for relatif, _, _, _, raison in ck.CORRESPONDANCES:
        assert len(raison) > 40, (relatif, raison)


@cas_test("le dépôt tel qu'il est passe")
def _():
    assert ck.ecarts() == [], ck.ecarts()


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
