#!/usr/bin/env python3
"""Ce que `check_lancement.py` doit voir.

Le premier cas est le DÉFAUT RÉEL : `glide` à 800 ms faisait finir le dévoilement à 1,38 s quand
le fondu commençait à 1,15. Il a vécu sans que rien ne puisse le dire, parce qu'aucune des deux
valeurs n'était fausse toute seule.
"""

import sys

import check_lancement as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def _retards(mouvements, fondu):
    return [nom for nom, depart, duree in mouvements if depart + duree > fondu - ck.MARGE]


@cas_test("le défaut du 13 novembre est refusé : glide à 800 ms")
def _():
    t = ck.tempo()
    mouvements = [("le dévoilement", t["revealDepart"], 0.80)]
    assert _retards(mouvements, t["fondu"]) == ["le dévoilement"]


@cas_test("la chorégraphie actuelle tient, avec sa marge")
def _():
    mouvements, fondu = ck.chorégraphie()
    assert fondu, "le fondu ne se lit pas"
    assert _retards(mouvements, fondu) == [], _retards(mouvements, fondu)


@cas_test("un mouvement qui finit PILE au fondu est refusé — la marge sert à ça")
def _():
    mouvements, fondu = ck.chorégraphie()
    assert _retards([("pile", fondu - 0.01, 0.01)], fondu) == ["pile"]


@cas_test("les trois mouvements sont lus, avec leurs durées réelles")
def _():
    mouvements, _ = ck.chorégraphie()
    assert len(mouvements) == 3, mouvements
    durees = ck.durees_du_systeme()
    noms = {nom: duree for nom, _, duree in mouvements}
    assert any("settle" in n for n in noms), noms
    for nom, duree in noms.items():
        if "settle" in nom:
            assert duree == durees["settle"], (duree, durees["settle"])
        if "glide" in nom:
            assert duree == durees["glide"], (duree, durees["glide"])


@cas_test("les durées viennent de Motion.swift, pas d'une copie")
def _():
    d = ck.durees_du_systeme()
    for jeton in ("settle", "glide", "draw", "ecran", "digit"):
        assert jeton in d, (jeton, sorted(d))
    # La fourchette du brief pour une TRANSITION de consultation.
    assert 0.20 <= d["ecran"] <= 0.30, d["ecran"]
    assert 0.20 <= d["settle"] <= 0.30, d["settle"]


@cas_test("une énumération Tempo disparue fait crier le garde")
def _():
    vrai = ck.SPLASH
    import pathlib, tempfile
    faux = pathlib.Path(tempfile.gettempdir()) / "faux_splash.swift"
    faux.write_text("struct SplashView { }\n", encoding="utf-8")
    try:
        ck.SPLASH = faux
        problemes = ck.ecarts()
    finally:
        ck.SPLASH = vrai
        faux.unlink(missing_ok=True)
    assert problemes and "ne se lit plus" in problemes[0][2], problemes


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
