#!/usr/bin/env python3
"""Ce que `check_nuit.py` doit voir, et ce qu'il ne doit PAS refuser.

Le premier cas est le défaut réel : l'anneau de départ du tracé, peint en `textPrimary`, donc en
presque-noir sur presque-noir dès que le thème est clair. Il a été trouvé en LISANT le fichier,
pas en le mesurant — et confirmé en recadrant la capture de l'accueil, où il se voit comme un trou.

Les cas négatifs comptent autant : un garde qui refuse du code juste est pire qu'aucun garde,
c'est la leçon de `check_entrees`.
"""

import pathlib
import sys
import tempfile

import check_nuit as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def _dans_une_vue(source: str) -> list:
    """Les écarts quand une vue ORDINAIRE du dépôt contient `source`."""
    dossier = pathlib.Path(tempfile.mkdtemp())
    faux = dossier / "RunUp" / "Views" / "Essai.swift"
    faux.parent.mkdir(parents=True, exist_ok=True)
    faux.write_text(source, encoding="utf-8")
    vraie = ck.RACINE
    try:
        ck.RACINE = dossier
        # Les fichiers de nuit sont alors introuvables : on ne garde que ce qui vient de la vue.
        return [p for p in ck.ecarts() if p[0].endswith("Essai.swift")]
    finally:
        ck.RACINE = vraie


def _dans_un_fichier_de_nuit(source: str) -> list:
    dossier = pathlib.Path(tempfile.mkdtemp())
    relatif = ck.FICHIERS_DE_NUIT[0]
    faux = dossier / relatif
    faux.parent.mkdir(parents=True, exist_ok=True)
    faux.write_text(source, encoding="utf-8")
    vraie = ck.RACINE
    try:
        ck.RACINE = dossier
        return [p for p in ck.ecarts() if p[0] == relatif]
    finally:
        ck.RACINE = vraie


# ── LE DÉFAUT RÉEL ───────────────────────────────────────────────────────────────────────────

@cas_test("l'anneau de départ en textPrimary est refusé (le défaut du tracé)")
def _():
    src = "context.stroke(anneau, with: .color(RUColor.textPrimary.opacity(0.85)), lineWidth: 2)"
    ecarts = _dans_un_fichier_de_nuit(src)
    assert len(ecarts) == 1, ecarts
    assert "textPrimary" in ecarts[0][2]


@cas_test("l'accent corrigé pour le blanc est refusé sur la nuit")
def _():
    src = "var colors: [Color] = [RUColor.rose2, RUColor.rose, RUColor.violet]"
    assert len(_dans_un_fichier_de_nuit(src)) == 3


@cas_test("UN JETON DE PAGE DANS LE CORPS D'UNE CarteDeNuit est refusé")
def _():
    src = """
    var body: some View {
        CarteDeNuit(hauteur: 200) {
            Cercle().fill(RUColor.text3)
        } legende: {
            EmptyView()
        }
    }
    """
    ecarts = _dans_une_vue(src)
    assert len(ecarts) == 1, ecarts
    assert "text3" in ecarts[0][2]


@cas_test("la DEUXIÈME fermeture est lue, pas seulement la première")
def _():
    src = """
        CarteDeNuit(hauteur: 200) {
            Courbe()
        } legende: {
            Text("x").foregroundColor(RUColor.text2)
        }
    """
    ecarts = _dans_une_vue(src)
    assert len(ecarts) == 1, ("la légende n'est pas lue", ecarts)


@cas_test("la ligne signalée est celle du jeton, pas celle de l'appel")
def _():
    src = "\n" * 9 + """CarteDeNuit(hauteur: 200) {
    Cercle().fill(RUColor.card)
} legende: { EmptyView() }
"""
    ecarts = _dans_une_vue(src)
    assert len(ecarts) == 1 and ecarts[0][1] == 11, ecarts


# ── CE QUI DOIT PASSER ───────────────────────────────────────────────────────────────────────

@cas_test("les jetons de la nuit passent")
def _():
    src = """
        CarteDeNuit(hauteur: 200) {
            Courbe().stroke(RUColor.accentDeLaNuit)
        } legende: {
            Text("x").foregroundColor(RUColor.surLaNuit2)
        }
    """
    assert _dans_une_vue(src) == []


@cas_test("surLaNuit n'est PAS pris pour le jeton `line` qu'il contient")
def _():
    # `line`, `card` et `rose` sont des sous-chaînes faciles à attraper par erreur.
    src = """
        CarteDeNuit(hauteur: 200) {
            Trait().stroke(RUColor.surLaNuit3)
        } legende: { EmptyView() }
    """
    assert _dans_une_vue(src) == []


@cas_test("un jeton de page HORS d'une carte de nuit passe")
def _():
    src = """
        var autreCarte: some View {
            VStack { Text("x").foregroundColor(RUColor.text3) }.ruCard()
        }
        var nuit: some View {
            CarteDeNuit(hauteur: 200) { Courbe() } legende: { EmptyView() }
        }
    """
    assert _dans_une_vue(src) == []


@cas_test("une carte de nuit APRÈS une autre est lue aussi")
def _():
    src = """
        CarteDeNuit(hauteur: 1) { A() } legende: { EmptyView() }
        CarteDeNuit(hauteur: 2) { B().fill(RUColor.rose) } legende: { EmptyView() }
    """
    ecarts = _dans_une_vue(src)
    assert len(ecarts) == 1, ecarts


@cas_test("un commentaire qui NOMME un jeton interdit ne compte pas")
def _():
    src = """
        CarteDeNuit(hauteur: 200) {
            // `RUColor.textPrimary` y serait du noir sur du noir.
            Courbe().stroke(RUColor.accentDeLaNuit)
        } legende: { EmptyView() }
    """
    assert _dans_une_vue(src) == []


@cas_test("un fichier de nuit inscrit mais absent est signalé")
def _():
    dossier = pathlib.Path(tempfile.mkdtemp())
    vraie = ck.RACINE
    try:
        ck.RACINE = dossier
        ecarts = ck.ecarts()
    finally:
        ck.RACINE = vraie
    assert len(ecarts) == len(ck.FICHIERS_DE_NUIT), ecarts
    assert "introuvable" in ecarts[0][2]


@cas_test("chaque fichier de nuit inscrit existe vraiment")
def _():
    for relatif in ck.FICHIERS_DE_NUIT:
        assert (ck.RACINE / relatif).is_file(), relatif


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
