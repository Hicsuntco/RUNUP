#!/usr/bin/env python3
"""Vérifie `check_accent.py` sur des cas écrits exprès.

Ce qui est vérifié ici, c'est surtout ce que l'analyse doit LAISSER PASSER : une barrière qui
refuse du code juste finit contournée, et elle aura coûté plus cher que le défaut qu'elle
cherchait.
"""
import sys
import check_accent as ck

cas = []
def cas_test(nom):
    def deco(f):
        cas.append((nom, f)); return f
    return deco

SOURCE = '''
        AccentTheme(id: "rose", name: "Rose", primary: Color(hex: 0xFF0A78), light: Color(hex: 0xFF4D9E), tail: Color(hex: 0x7C5CFF)),
        AccentTheme(id: "bleu", name: "Bleu", primary: Color(hex: 0x3D8BFF), light: Color(hex: 0x8AB8FF), tail: Color(hex: 0x7C5CFF))
'''

@cas_test("les nuanciers de la source sont lus")
def _():
    n = ck.nuanciers(SOURCE)
    assert set(n) == {"rose", "bleu"}, n
    assert n["rose"] == ("0xff0a78", "0xff4d9e", "0x7c5cff"), n["rose"]

@cas_test("un miroir identique ne pose aucun problème")
def _():
    copie = ck.miroir('"rose": (0xFF0A78, 0xFF4D9E, 0x7C5CFF),\n"bleu": (0x3D8BFF, 0x8AB8FF, 0x7C5CFF)')
    assert ck.ecarts(ck.nuanciers(SOURCE), copie, "f.swift") == []

@cas_test("la casse de l'écriture hexadécimale n'est pas une divergence")
def _():
    copie = ck.miroir('"rose": (0xff0a78, 0xff4d9e, 0x7c5cff),\n"bleu": (0x3d8bff, 0x8ab8ff, 0x7c5cff)')
    assert ck.ecarts(ck.nuanciers(SOURCE), copie, "f.swift") == []

@cas_test("une couleur qui diffère d'un seul chiffre est signalée")
def _():
    copie = ck.miroir('"rose": (0xFF0A79, 0xFF4D9E, 0x7C5CFF),\n"bleu": (0x3D8BFF, 0x8AB8FF, 0x7C5CFF)')
    p = ck.ecarts(ck.nuanciers(SOURCE), copie, "f.swift")
    assert len(p) == 1 and "rose" in p[0], p

@cas_test("un nuancier oublié dans le miroir est signalé")
def _():
    copie = ck.miroir('"rose": (0xFF0A78, 0xFF4D9E, 0x7C5CFF)')
    p = ck.ecarts(ck.nuanciers(SOURCE), copie, "f.swift")
    assert len(p) == 1 and "bleu" in p[0], p

@cas_test("un nuancier en trop dans le miroir est signalé aussi")
def _():
    copie = ck.miroir('"rose": (0xFF0A78, 0xFF4D9E, 0x7C5CFF),\n'
                      '"bleu": (0x3D8BFF, 0x8AB8FF, 0x7C5CFF),\n'
                      '"ocre": (0x111111, 0x222222, 0x333333)')
    p = ck.ecarts(ck.nuanciers(SOURCE), copie, "f.swift")
    assert len(p) == 1 and "ocre" in p[0], p

@cas_test("les vrais fichiers du dépôt sont d'accord")
def _():
    assert ck.main() == 0

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
