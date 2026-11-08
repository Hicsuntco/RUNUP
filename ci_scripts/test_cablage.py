#!/usr/bin/env python3
"""Les cas de `check_cablage.py`, sur une arborescence fabriquée.

Ce contrôle a une faiblesse qu'il faut éprouver plutôt que commenter : il se nourrit d'une
liste de dispenses, et une liste de dispenses est précisément ce par quoi un garde-fou meurt.
Trois cas portent là-dessus — un fichier non câblé et non dispensé doit échouer ; une dispense
qui ne correspond plus à aucun fichier doit échouer ; une dispense sur un fichier désormais
câblé doit échouer, pour que la liste ne garde pas une entrée devenue fausse.

Le quatrième cas est celui du contrôle lui-même : il doit regarder les DEUX familles,
`check_*.py` et `test_*.py`. Les trois défauts qu'il existe pour attraper étaient deux tests
et un contrôle.
"""
import pathlib
import shutil
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


def arborescence(tmp: str, fichiers: list[str], nommes: list[str],
                 dispenses: dict[str, str] | None = None) -> pathlib.Path:
    """Un faux dépôt : ci_scripts/ avec `fichiers`, et un workflow qui nomme `nommes`."""
    racine = pathlib.Path(tmp)
    scripts = racine / "ci_scripts"
    workflows = racine / ".github" / "workflows"
    scripts.mkdir(parents=True)
    workflows.mkdir(parents=True)

    for nom in fichiers:
        (scripts / nom).write_text("# vide\n")

    lignes = ["name: faux", "on: [push]", "jobs:", "  j:", "    steps:"]
    for nom in nommes:
        lignes.append(f"      - run: python3 ci_scripts/{nom}")
    (workflows / "faux.yml").write_text("\n".join(lignes) + "\n")

    # LE CONTRÔLE EST COPIÉ, PAS IMPORTÉ : il se repère sur l'emplacement de son propre
    # fichier (`__file__`), donc le faire regarder ailleurs demande de le poser ailleurs.
    #
    # ET LA COPIE NE S'APPELLE PAS `check_*.py`, sinon elle ferait partie des fichiers qu'elle
    # surveille, et chaque cas devrait penser à la câbler. Ce n'est pas ce qu'on éprouve ici :
    # le vrai `check_cablage.py` est, lui, câblé dans `testflight.yml`, et le dernier cas le
    # vérifie en le lançant tel quel.
    copie = scripts / "regarde.py"
    source = (ICI / "check_cablage.py").read_text()
    if dispenses is not None:
        debut = source.index("DISPENSES = {")
        fin = source.index("\n}\n", debut) + 3
        rendu = "DISPENSES = {\n"
        for nom, raison in dispenses.items():
            rendu += f'    "{nom}": "{raison}",\n'
        rendu += "}\n"
        source = source[:debut] + rendu + source[fin:]
    copie.write_text(source)
    return copie


def lancer(copie: pathlib.Path):
    r = subprocess.run([sys.executable, str(copie)], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


@cas_de("tout câblé : vert")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py", "test_a.py"], ["check_a.py", "test_a.py"],
                         dispenses={})
        code, sortie = lancer(c)
        assert code == 0, f"une arborescence saine a échoué :\n{sortie}"
        assert "2 nommé(s)" in sortie, sortie


@cas_de("un CONTRÔLE non câblé fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py", "check_b.py"], ["check_a.py"], dispenses={})
        code, sortie = lancer(c)
        assert code == 1, f"un contrôle non câblé est passé :\n{sortie}"
        assert "check_b.py" in sortie, sortie


@cas_de("un TEST non câblé fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py", "test_b.py"], ["check_a.py"], dispenses={})
        code, sortie = lancer(c)
        assert code == 1, f"un test non câblé est passé :\n{sortie}"
        assert "test_b.py" in sortie, sortie


@cas_de("une dispense couvre, et elle est affichée avec sa raison")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py", "check_b.py"], ["check_a.py"],
                         dispenses={"check_b.py": "il demande un secret de signature."})
        code, sortie = lancer(c)
        assert code == 0, f"une dispense n'a pas couvert :\n{sortie}"
        assert "il demande un secret de signature." in sortie, (
            f"la raison n'est pas affichée : une dispense muette est un silence.\n{sortie}")


@cas_de("une dispense sans fichier fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py"], ["check_a.py"],
                         dispenses={"check_disparu.py": "renommé il y a six mois."})
        code, sortie = lancer(c)
        assert code == 1, f"une dispense périmée est passée :\n{sortie}"
        assert "check_disparu.py" in sortie, sortie
        assert "AUCUN FICHIER" in sortie, sortie


@cas_de("une dispense sur un fichier redevenu câblé fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py"], ["check_a.py"],
                         dispenses={"check_a.py": "il attend un profil décodé."})
        code, sortie = lancer(c)
        assert code == 1, f"une dispense devenue fausse est passée :\n{sortie}"
        assert "DISPENSÉS ET POURTANT CÂBLÉS" in sortie, sortie


@cas_de("sans workflow, le contrôle le dit au lieu de passer au vert")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py"], ["check_a.py"], dispenses={})
        shutil.rmtree(c.parent.parent / ".github")
        code, sortie = lancer(c)
        assert code != 0, f"un dépôt sans workflow a rendu un vert :\n{sortie}"
        assert "introuvable" in sortie, sortie


@cas_de("sans aucun fichier à surveiller, le contrôle le dit")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, [], [], dispenses={})
        code, sortie = lancer(c)
        assert code != 0, f"un ci_scripts vide a rendu un vert :\n{sortie}"
        assert "mauvais endroit" in sortie, sortie


@cas_de("un nom cité dans un COMMENTAIRE ne compte pas comme un câblage")
def _():
    """LE DÉFAUT QU'A EU CE CONTRÔLE LE JOUR DE SON ÉCRITURE.

    L'étape qui le câble explique, en commentaire, que `check_profile.py` ne tourne nulle
    part — et la phrase cite le nom. Le contrôle a compté la mention comme un câblage et a
    déclaré la dispense périmée. Le même piège que `check_cjs.py`, dont le correctif citait
    `require('jose')` dans son propre commentaire.
    """
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py", "check_b.py"], ["check_a.py"],
                         dispenses={"check_b.py": "il demande un secret de signature."})
        # On ajoute le nom dispensé DANS un commentaire du workflow, comme dans le vrai dépôt.
        faux = c.parent.parent / ".github" / "workflows" / "faux.yml"
        faux.write_text(faux.read_text()
                        + "      # check_b.py ne tourne pas : il attend un secret.\n")
        code, sortie = lancer(c)
        assert code == 0, (f"le nom cité en commentaire a été pris pour un câblage :\n{sortie}")

        # Et le même nom hors commentaire doit bien compter, sinon on aurait tout blanchi.
        faux.write_text(faux.read_text() + "      - run: python3 ci_scripts/check_b.py\n")
        code, sortie = lancer(c)
        assert code == 1, f"un vrai câblage n'a pas été vu :\n{sortie}"
        assert "POURTANT CÂBLÉS" in sortie, sortie


@cas_de("un # dans une chaîne ne coupe pas la ligne")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py"], [], dispenses={})
        faux = c.parent.parent / ".github" / "workflows" / "faux.yml"
        faux.write_text(faux.read_text()
                        + '      - run: echo "#RUNUP" && python3 ci_scripts/check_a.py\n')
        code, sortie = lancer(c)
        assert code == 0, (f"la ligne a été coupée sur le # d'une chaîne, et le câblage "
                           f"perdu :\n{sortie}")


@cas_de("le vrai dépôt passe")
def _():
    code, sortie = lancer(ICI / "check_cablage.py")
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
