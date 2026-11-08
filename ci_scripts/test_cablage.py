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
import re
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


def source_du_controle(dispenses: dict[str, str] | None) -> str:
    """Le contrôle, sa liste de dispenses remplacée par celle qu'on veut éprouver.

    La déclaration est retrouvée par expression régulière et non par sa forme exacte : elle a
    déjà changé une fois — de `DISPENSES = {…}` à `DISPENSES: dict[str, str] = {}` le jour où
    la dernière dispense a disparu — et les cas sont tombés d'un coup.
    """
    source = (ICI / "check_cablage.py").read_text()
    if dispenses is None:
        return source
    # Les deux formes que la déclaration a prises : le dictionnaire vide sur une ligne, et le
    # bloc qui se ferme sur une accolade en colonne zéro.
    motif = re.compile(r"^DISPENSES(?::[^=]*)? = \{(?:\}\n|.*?^\}\n)", re.S | re.M)
    rendu = "DISPENSES = {\n"
    for nom, raison in dispenses.items():
        rendu += f'    "{nom}": "{raison}",\n'
    rendu += "}\n"
    source, n = motif.subn(rendu, source, count=1)
    assert n == 1, "la déclaration DISPENSES n'a pas été retrouvée dans check_cablage.py"
    return source


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
    copie.write_text(source_du_controle(dispenses))
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


@cas_de("un fichier IMPORTÉ par un fichier câblé tourne aussi")
def _():
    """`check_profile.py` n'est nommé par aucun workflow, et sa règle tourne à chaque build :
    `profils.py` est appelé et l'importe. Le contrôle ne regardait que les noms écrits dans
    les workflows, et l'a donc inscrit en dispense avec la mention « ne tourne nulle part » —
    fausse, et partie telle quelle dans RELEASE.md avant d'être rattrapée."""
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp,
                         ["check_outil.py", "check_appelant.py"],
                         ["check_appelant.py"], dispenses={})
        (c.parent / "check_appelant.py").write_text("import check_outil\n")
        code, sortie = lancer(c)
        assert code == 0, f"un fichier lancé par un import a été déclaré orphelin :\n{sortie}"
        assert "par import : check_outil.py" in sortie, sortie


@cas_de("une chaîne d'imports compte sur toute sa longueur")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp,
                         ["check_a.py", "check_b.py", "check_c.py"],
                         ["check_c.py"], dispenses={})
        (c.parent / "check_c.py").write_text("import check_b\n")
        (c.parent / "check_b.py").write_text("import check_a\n")
        code, sortie = lancer(c)
        assert code == 0, f"la chaîne d'imports n'a pas été suivie :\n{sortie}"
        assert "check_a.py" in sortie and "check_b.py" in sortie, sortie


@cas_de("deux fichiers qui s'importent l'un l'autre ne tournent pas pour autant")
def _():
    """Sans mémo, la boucle rendrait « oui » à tout le monde : A tourne parce que B l'importe,
    et B tourne parce que A l'importe. Aucun des deux n'est appelé par un workflow."""
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_a.py", "check_b.py", "check_vrai.py"],
                         ["check_vrai.py"], dispenses={})
        (c.parent / "check_a.py").write_text("import check_b\n")
        (c.parent / "check_b.py").write_text("import check_a\n")
        code, sortie = lancer(c)
        assert code == 1, f"une boucle d'imports a suffi à se déclarer câblée :\n{sortie}"
        assert "check_a.py" in sortie and "check_b.py" in sortie, sortie


@cas_de("une dispense sur un fichier lancé par un import fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = arborescence(tmp, ["check_outil.py", "check_appelant.py"], ["check_appelant.py"],
                         dispenses={"check_outil.py": "il ne tourne nulle part."})
        (c.parent / "check_appelant.py").write_text("import check_outil\n")
        code, sortie = lancer(c)
        assert code == 1, f"une dispense devenue fausse est passée :\n{sortie}"
        assert "DISPENSÉS ET POURTANT CÂBLÉS" in sortie, sortie


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


# --- LA SECONDE QUESTION : CE QUI TOURNE A-T-IL DE QUOI TOURNER ? --------------------------------

def avec_workflow(tmp: str, fichiers: dict[str, str], workflow: str) -> pathlib.Path:
    """Un faux dépôt dont on écrit le workflow à la main, jobs et étapes compris."""
    racine = pathlib.Path(tmp)
    scripts = racine / "ci_scripts"
    workflows = racine / ".github" / "workflows"
    scripts.mkdir(parents=True)
    workflows.mkdir(parents=True)
    for nom, contenu in fichiers.items():
        (scripts / nom).write_text(contenu)
    (workflows / "faux.yml").write_text(workflow)
    copie = scripts / "regarde.py"
    copie.write_text(source_du_controle({}))
    return copie


SANS_VENV = """name: faux
on:
  push:
    paths:
      - "ci_scripts/test_image.py"
jobs:
  j:
    steps:
      - run: cd ci_scripts && python3 test_image.py
"""

AVEC_VENV = """name: faux
on: [push]
jobs:
  j:
    steps:
      - run: python3 -m venv "$RUNNER_TEMP/venv" && "$RUNNER_TEMP/venv/bin/python" -m pip install Pillow
      - run: cd ci_scripts && "$RUNNER_TEMP/venv/bin/python" test_image.py
"""


@cas_de("un script qui lit des images, dans un job sans Pillow, fait échouer")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = avec_workflow(tmp, {"test_image.py": "from PIL import Image\n"}, SANS_VENV)
        code, sortie = lancer(c)
        assert code == 1, f"le script sans Pillow est passé :\n{sortie}"
        assert "test_image.py" in sortie and "SANS PILLOW" in sortie, sortie


@cas_de("le même script avec le python du venv passe")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = avec_workflow(tmp, {"test_image.py": "from PIL import Image\n"}, AVEC_VENV)
        code, sortie = lancer(c)
        assert code == 0, f"un job qui fournit Pillow a été accusé :\n{sortie}"


@cas_de("un venv poussé en tête du PATH compte aussi")
def _():
    """`appstore.yml` fait ainsi, et ses `python3` nus sont alors le python du venv."""
    wf = """name: faux
on: [push]
jobs:
  j:
    steps:
      - run: |
          python3 -m venv "$RUNNER_TEMP/venv"
          echo "$RUNNER_TEMP/venv/bin" >> "$GITHUB_PATH"
      - run: python3 ci_scripts/test_image.py
"""
    with tempfile.TemporaryDirectory() as tmp:
        c = avec_workflow(tmp, {"test_image.py": "from PIL import Image\n"}, wf)
        code, sortie = lancer(c)
        assert code == 0, f"un venv mis en tête du PATH n'a pas compté :\n{sortie}"


@cas_de("un script qui importe un VOISIN lisant des images est vu aussi")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        c = avec_workflow(tmp, {
            "lecteur.py": "from PIL import Image\n",
            "test_image.py": "import lecteur\n",
        }, SANS_VENV)
        code, sortie = lancer(c)
        assert code == 1, f"l'import indirect n'a pas été vu :\n{sortie}"


@cas_de("un filtre `paths:` ne compte pas comme un lancement")
def _():
    """SANS_VENV nomme `test_image.py` dans ses `paths:`. Si le contrôle lisait le fichier
    entier au lieu des étapes, un script surveillé mais jamais lancé serait accusé."""
    wf = """name: faux
on:
  push:
    paths:
      - "ci_scripts/test_image.py"
jobs:
  j:
    steps:
      - run: echo rien
"""
    with tempfile.TemporaryDirectory() as tmp:
        c = avec_workflow(tmp, {"test_image.py": "from PIL import Image\n"}, wf)
        code, sortie = lancer(c)
        assert "SANS PILLOW" not in sortie, (
            f"un `paths:` a été pris pour un lancement :\n{sortie}")


@cas_de("un script qui PARLE de PIL sans l'importer n'est pas accusé")
def _():
    """LE DÉFAUT QUE CE CONTRÔLE A EU, LE JOUR DE SON ÉCRITURE.

    Il cherchait `"from PIL" in texte`, et sa propre ligne de recherche contenait ces mots :
    il s'est accusé lui-même. Les imports se lisent dans l'arbre syntaxique depuis.
    """
    with tempfile.TemporaryDirectory() as tmp:
        c = avec_workflow(tmp, {
            "test_image.py": '# on cherchait "from PIL" dans le texte\nMOTIF = "import PIL"\n',
        }, SANS_VENV)
        code, sortie = lancer(c)
        assert "SANS PILLOW" not in sortie, (
            f"le contrôle a lu une chaîne comme un import :\n{sortie}")


@cas_de("un workflow à deux jobs est refusé plutôt que deviné")
def _():
    """Le contrôle lit chaque workflow comme un seul job — les six du dépôt en portent un.

    À deux, un job qui installe Pillow et un autre qui lance le script seraient confondus, et
    le verdict serait « tout va bien » à tort. Un contrôle qui dit « je ne sais pas » vaut
    mieux qu'un contrôle qui se trompe en silence.
    """
    wf = """name: faux
on: [push]
jobs:
  preparer:
    steps:
      - run: python3 -m venv "$RUNNER_TEMP/venv"
  lancer:
    steps:
      - run: python3 ci_scripts/test_image.py
"""
    with tempfile.TemporaryDirectory() as tmp:
        c = avec_workflow(tmp, {"test_image.py": "from PIL import Image\n"}, wf)
        code, sortie = lancer(c)
        assert code != 0, f"un workflow à deux jobs est passé sans un mot :\n{sortie}"
        assert "2 jobs" in sortie, sortie


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
