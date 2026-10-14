#!/usr/bin/env python3
"""Ce que `check_barre.py` doit voir, et ce qu'il ne doit pas inventer.

Les cas sont des EXTRAITS FIGÉS. Le premier est celui qui compte : la géométrie EXACTE du
build 270, celle qui a fait disparaître le mot « RUN » sans rien signaler.
"""

import sys

import check_barre as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def sources(rond=34, icone=22, point=4, pile=5, bouton=3, hauteur=56, facteur=1.25, micro=8.5):
    barre = f"""
    private static let diametreDuRond: CGFloat = {rond}
    private static let cotesDeLIcone: CGFloat = {icone}
    private static let diametreDuPoint: CGFloat = {point}
    private static let ecartDeLaPile: CGFloat = {pile}
    private static let ecartDuBouton: CGFloat = {bouton}
    """
    espacement = f"    static let tabBarHeight: CGFloat = {hauteur}\n"
    typo = f"""
    private static let bodySizeFactor: CGFloat = {facteur}
    case micro = {micro}
    """
    return (barre, espacement, typo)


@cas_test("la géométrie d'aujourd'hui passe")
def _():
    assert ck.problemes(sources()) == [], ck.problemes(sources())


@cas_test("LA GÉOMÉTRIE DU BUILD 270 EST REFUSÉE")
def _():
    # Rond de 40, icône de 24, barre de 56 : le bouton mesurait 56,8 et le mot « RUN »
    # disparaissait pour tout le monde. C'est le cas que ce script existe pour attraper.
    griefs = ck.problemes(sources(rond=40, icone=24))
    assert len(griefs) == 1, griefs
    assert "bouton central" in griefs[0], griefs[0]


@cas_test("une barre tout juste à la limite est refusée aussi")
def _():
    # Tenir « tout juste » n'est pas tenir : la hauteur de ligne exacte n'est connue de personne.
    assert ck.problemes(sources(rond=38)) != []


@cas_test("un onglet trop haut est signalé comme tel, pas comme le bouton")
def _():
    griefs = ck.problemes(sources(rond=10, icone=40))
    assert len(griefs) == 1 and "un onglet" in griefs[0], griefs


@cas_test("agrandir la barre redonne de la marge")
def _():
    assert ck.problemes(sources(rond=40, icone=24, hauteur=64)) == []


@cas_test("une taille de libellé plus grande resserre le calcul")
def _():
    assert ck.problemes(sources(micro=14)) != []


@cas_test("une constante disparue fait ÉCHOUER au lieu de passer")
def _():
    barre, espacement, typo = sources()
    for manquante, trio in (
        ("diametreDuRond", (barre.replace("diametreDuRond", "autreNom"), espacement, typo)),
        ("tabBarHeight", (barre, "", typo)),
        ("bodySizeFactor", (barre, espacement, "case micro = 8.5")),
    ):
        griefs = ck.problemes(trio)
        assert griefs and "introuvable" in griefs[0], (manquante, griefs)


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
