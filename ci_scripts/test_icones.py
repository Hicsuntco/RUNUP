#!/usr/bin/env python3
"""Les cas de `check_icones.py`, sans Xcode.

Une barrière d'intégration continue qui se trompe coûte plus cher que le défaut qu'elle cherche.
Ce qui est éprouvé ici est donc surtout ce qu'elle doit laisser passer — et le fait qu'une
exception périmée se signale, parce qu'une liste d'exceptions qui ne se nettoie pas finit par
autoriser tout le fichier.
"""
import pathlib
import sys

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_icones as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


LISTE = {"a.swift": (2, "deux chevrons typographiques"), "b.swift": (1, "une coche")}


@cas_de("un fichier non listé est signalé")
def _():
    f = ck.ecarts({"c.swift": 1}, LISTE)
    assert len(f) == 3, f  # c.swift non listé, a.swift et b.swift absents
    assert any("c.swift" in x and "écrite" in x for x in f), f


@cas_de("les comptes justes passent")
def _():
    assert ck.ecarts({"a.swift": 2, "b.swift": 1}, LISTE) == []


@cas_de("un appel de plus dans un fichier listé est signalé")
def _():
    f = ck.ecarts({"a.swift": 3, "b.swift": 1}, LISTE)
    assert len(f) == 1 and "3 appel(s) pour 2" in f[0], f


@cas_de("une exception périmée se signale")
def _():
    f = ck.ecarts({"a.swift": 2}, LISTE)
    assert len(f) == 1 and "n'a plus lieu d'être" in f[0], f


@cas_de("le dépôt tel qu'il est : quatre appels, tous justifiés")
def _():
    trouves = ck.comptes()
    assert ck.ecarts(trouves) == [], ck.ecarts(trouves)
    assert sum(trouves.values()) == 4, trouves
    # Et l'extraction lit vraiment quelque chose : un motif cassé rendrait zéro en silence.
    assert trouves, "aucun appel trouvé — le motif ne lit plus rien"


@cas_de("les sept crans existent et sont ordonnés")
def _():
    typo = (ICI.parent / "RunUp/DesignSystem/Typography.swift").read_text(encoding="utf-8")
    import re
    crans = [float(x) for x in re.findall(r"case \w+ = ([0-9.]+)",
                                          typo.split("enum RUIconSize")[1].split("}")[0])]
    assert len(crans) == 7, crans
    assert crans == sorted(crans), crans
    # Les deux tailles les plus employées du dépôt d'origine sont des crans : 65 appels sur 170
    # ne bougent donc pas d'un point.
    assert 13 in crans and 15 in crans, crans


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
