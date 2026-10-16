#!/usr/bin/env python3
"""Ce que `check_decimales.py` doit voir, et ce qu'il ne doit surtout pas signaler.

Les deux premiers cas sont les deux appels réels qui l'avaient oublié ; les suivants sont les
formats TECHNIQUES du dépôt, qui doivent rester sans locale.
"""

import re
import sys

import check_decimales as ck


cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def signale(extrait: str) -> bool:
    source = ck.sans_commentaires(extrait)
    for m in ck.APPEL.finditer(source):
        marqueurs = [x for x in ck.DECIMALES.findall(m.group(1))
                     if not ck.SANS_DECIMALE.fullmatch(x)]
        if marqueurs and "locale:" not in m.group(2):
            return True
    return False


# --- Les deux appels réels qui manquaient ------------------------------------------------------

@cas_test("la tuile « Dernière sortie » du coach")
def _():
    assert signale('valeur: String(format: "%.1f km", derniere.distanceKm)')


@cas_test("la progression du badge semi-marathon")
def _():
    assert signale('"\\(String(format: "%.1f", min(longestRun, 21)))/21 km"')


@cas_test("deux décimales, et %f tout court")
def _():
    assert signale('Text(String(format: "%.2f", vm.distanceKm))')
    assert signale('Text(String(format: "%f", x))')


# --- Ce qui est déjà correct --------------------------------------------------------------------

@cas_test("l'appel corrigé passe")
def _():
    assert not signale('String(format: "%.1f km", locale: Locale.current, derniere.distanceKm)')


@cas_test("l'appel où la locale vient en premier passe aussi")
def _():
    assert not signale('String(format: "%.2f", locale: Locale.current, vm?.distanceKm ?? 0)')


# --- Les formats techniques, qui doivent rester sans locale ------------------------------------

@cas_test("%.0f ne montre aucun séparateur")
def _():
    assert not signale('statCell(value: String(format: "%.0f", totalKm), label: "km")')


@cas_test("un chrono, une date de fichier, un jeton hexadécimal")
def _():
    assert not signale('"\\(total / 60):\\(String(format: "%02d", total % 60))"')
    assert not signale('String(format: "RUNUP-sauvegarde-%04d-%02d-%02d", a, m, j)')
    assert not signale('data.map { String(format: "%02x", $0) }.joined()')


@cas_test("un exemple en commentaire ne déclenche rien")
def _():
    assert not signale('// Avant : String(format: "%.1f km", derniere.distanceKm)')


# --- Le dépôt ------------------------------------------------------------------------------------

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
