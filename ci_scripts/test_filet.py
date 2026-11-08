#!/usr/bin/env python3
"""Les cas de `check_filet.py`, sur une arborescence fabriquée.

Ce qui est éprouvé ici, c'est que le contrôle REFUSE les deux formes qu'il existe pour
refuser, qu'il ne refuse PAS les contours — qui emploient la même constante et ne sont pas des
filets — et qu'il ne se laisse pas attendrir par ses propres commentaires. Ce dernier piège
s'est présenté deux fois dans ce dépôt (`check_cjs.py`, `check_cablage.py`), chaque fois le
jour où le contrôle a été écrit.

Et deux cas sur ce qui rendrait le contrôle vert pour de mauvaises raisons : un dépôt où
`RUFilet` a disparu, et un dépôt où plus personne ne l'emploie.
"""
import pathlib
import subprocess
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


COMPOSANT = """import SwiftUI

/// Cite les deux formes refusées : Divider().background(RUColor.line) et
/// Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
struct RUFilet: View {
    var body: some View { Rectangle().fill(RUColor.line) }
}
"""


def arborescence(tmp: str, vues: dict[str, str], composant: str | None = COMPOSANT):
    """Un faux dépôt : RunUp/Views/… avec `vues`, et le composant à la place qu'il occupe."""
    racine = pathlib.Path(tmp)
    (racine / "RunUp" / "Views" / "Components").mkdir(parents=True)
    if composant is not None:
        (racine / "RunUp" / "Views" / "Components" / "FiletView.swift").write_text(composant)
    for nom, contenu in vues.items():
        cible = racine / "RunUp" / "Views" / nom
        cible.parent.mkdir(parents=True, exist_ok=True)
        cible.write_text(contenu)
    # Le contrôle se repère sur son propre fichier : on le pose dans un `ci_scripts` du faux dépôt.
    scripts = racine / "ci_scripts"
    scripts.mkdir()
    copie = scripts / "check_filet.py"
    copie.write_text((ICI / "check_filet.py").read_text())
    return copie


def lancer(copie: pathlib.Path):
    r = subprocess.run([sys.executable, str(copie)], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


@cas_de("un dépôt propre passe")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {"A.swift": "struct A: View { var body: some View { RUFilet() } }\n"})
        code, sortie = lancer(c)
        assert code == 0, f"un dépôt propre a échoué :\n{sortie}"
        assert "1 emploi(s)" in sortie, sortie


@cas_de("Divider() est refusé")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {
            "A.swift": "struct A: View { var body: some View { RUFilet() } }\n",
            "B.swift": "struct B: View { var body: some View { Divider().background(RUColor.line) } }\n",
        })
        code, sortie = lancer(c)
        assert code == 1, f"`Divider()` est passé :\n{sortie}"
        assert "B.swift:1" in sortie, sortie
        assert "RUFilet()" in sortie, "le message ne dit pas quoi employer à la place"


@cas_de("un filet horizontal dessiné à la main est refusé")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {
            "A.swift": "struct A: View { var body: some View { RUFilet() } }\n",
            "B.swift": "let f = Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)\n",
        })
        code, sortie = lancer(c)
        assert code == 1, f"un filet à la main est passé :\n{sortie}"
        assert "horizontal" in sortie, sortie


@cas_de("un filet vertical dessiné à la main est refusé, et nommé comme tel")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {
            "A.swift": "struct A: View { var body: some View { RUFilet() } }\n",
            "B.swift": "let f = Rectangle().fill(RUColor.line).frame(width: RUSpacing.hairline)\n",
        })
        code, sortie = lancer(c)
        assert code == 1, f"un filet vertical à la main est passé :\n{sortie}"
        assert "RUFilet(.vertical)" in sortie, sortie


@cas_de("un CONTOUR à la même épaisseur n'est pas un filet")
def _():
    """La constante est la même, le rôle n'est pas le même.

    `stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline)` est une bordure de carte : il y
    en a des dizaines dans l'app, elles n'ont jamais eu de second idiome, et les refuser ici
    ferait du contrôle un obstacle qu'on contourne.
    """
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {
            "A.swift": "struct A: View { var body: some View { RUFilet() } }\n",
            "B.swift": ".overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))\n",
        })
        code, sortie = lancer(c)
        assert code == 0, f"un contour a été pris pour un filet :\n{sortie}"


@cas_de("la forme refusée CITÉE DANS UN COMMENTAIRE ne compte pas")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {
            "A.swift": "struct A: View { var body: some View { RUFilet() } }\n",
            "B.swift": "// Avant : Divider().background(RUColor.line)\n"
                       "/// et aussi .frame(height: RUSpacing.hairline)\n",
        })
        code, sortie = lancer(c)
        assert code == 0, (f"un commentaire a été lu comme du code — le défaut qui s'est "
                           f"présenté deux fois dans ce dépôt :\n{sortie}")


@cas_de("un // DANS UNE CHAÎNE n'ouvre pas de commentaire")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {
            "A.swift": "struct A: View { var body: some View { RUFilet() } }\n",
            "B.swift": 'let u = "https://runup.app"; let f = Divider()\n',
        })
        code, sortie = lancer(c)
        assert code == 1, (f"la ligne a été coupée sur le // d'une URL, et le Divider qui "
                           f"suivait n'a pas été vu :\n{sortie}")


@cas_de("le composant disparu fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {"A.swift": "struct A {}\n"}, composant=None)
        code, sortie = lancer(c)
        assert code != 0, f"un dépôt sans composant a rendu un vert :\n{sortie}"
        assert "introuvable" in sortie, sortie


@cas_de("un composant qui ne déclare plus RUFilet fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {"A.swift": "struct A {}\n"},
                         composant="import SwiftUI\nstruct Autre: View {}\n")
        code, sortie = lancer(c)
        assert code != 0, f"un composant vidé a rendu un vert :\n{sortie}"
        assert "ne déclare plus" in sortie, sortie


@cas_de("RUFilet employé nulle part fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {"A.swift": "struct A: View { var body: some View { Text(\"a\") } }\n"},
                         composant="import SwiftUI\nstruct RUFilet: View { var body: some View { Rectangle() } }\n")
        code, sortie = lancer(c)
        assert code == 1, f"un dépôt sans aucun filet a rendu un vert :\n{sortie}"
        assert "employé nulle part" in sortie, sortie


@cas_de("sans dossier RunUp, le contrôle le dit")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, {})
        import shutil
        shutil.rmtree(c.parent.parent / "RunUp")
        code, sortie = lancer(c)
        assert code != 0, f"un dépôt sans RunUp a rendu un vert :\n{sortie}"
        assert "mauvais endroit" in sortie, sortie


@cas_de("le vrai dépôt passe")
def _():
    code, sortie = lancer(ICI / "check_filet.py")
    assert code == 0, f"le dépôt tel qu'il est ne passe pas :\n{sortie}"


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
