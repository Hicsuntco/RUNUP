#!/usr/bin/env python3
"""Ce que `check_feuilles.py` doit voir, et ce qu'il ne doit pas inventer.

Extraits figés : un test qui relirait le dépôt passerait tant que la faute y est, et échouerait
à la seconde où elle est corrigée.
"""
import sys

import check_feuilles as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


STYLEE = '''
struct Ecran: View {
    var body: some View {
        Text("x")
            .sheet(isPresented: $ouverte) {
                MaFeuille()
                    .runUpSheetStyle(detents: [.large])
            }
    }
}
'''

NUE = '''
struct Autre: View {
    var body: some View {
        Text("x")
            .sheet(isPresented: $ouverte) { MaFeuille() }
    }
}
'''


def griefs(**fichiers):
    return ck.problemes(sources=fichiers)


@cas_test("une feuille stylée ne produit aucun grief")
def _():
    assert griefs(a=STYLEE) == [], griefs(a=STYLEE)


@cas_test("UNE FEUILLE NUE EST SIGNALÉE")
def _():
    g = griefs(a=STYLEE, b=NUE)
    assert len(g) == 1 and "présente MaFeuille" in g[0], g


@cas_test("UNE FERMETURE `Binding(get:)` N'EST PAS PRISE POUR LE CONTENU")
def _():
    # Cinq feuilles parfaitement stylées de `RootTabView` étaient accusées à tort : la première
    # accolade après `.sheet(` appartient au `get` du Binding, pas au contenu.
    piege = '''
struct Racine: View {
    var body: some View {
        Text("x")
            .sheet(isPresented: Binding(get: { etat.ouverte }, set: { etat.ouverte = $0 })) {
                MaFeuille()
                    .runUpSheetStyle()
            }
    }
}
'''
    assert griefs(a=piege) == [], griefs(a=piege)

    nue = piege.replace("                    .runUpSheetStyle()\n", "")
    assert len(griefs(a=nue)) == 1, griefs(a=nue)


@cas_test("une vue qui se style elle-même dispense son appelant")
def _():
    autonome = '''
struct MaFeuille: View {
    var body: some View { Text("x").presentationDetents([.large]) }
}
'''
    assert griefs(a=NUE, b=autonome) == [], griefs(a=NUE, b=autonome)


@cas_test("un `fullScreenCover` est hors sujet")
def _():
    plein = '''
struct Ecran: View {
    var body: some View {
        Text("x").fullScreenCover(isPresented: $ouverte) { MaFeuille() }
    }
}
'''
    assert griefs(a=STYLEE, b=plein) == [], griefs(a=STYLEE, b=plein)


@cas_test("un `.sheet` cité dans un commentaire n'est pas une feuille")
def _():
    commente = STYLEE.replace("    var body: some View {",
                              "    // surtout pas de .sheet(isPresented: $x) { Nue() } ici\n    var body: some View {")
    assert griefs(a=commente) == [], griefs(a=commente)


@cas_test("l'absence de toute feuille est elle-même un grief")
def _():
    g = griefs(a="struct Rien: View { var body: some View { Text(\"x\") } }")
    assert len(g) == 1 and "Aucune feuille" in g[0], g


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
