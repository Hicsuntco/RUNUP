#!/usr/bin/env python3
"""Les cas de `check_fonctions.py`, sur une arborescence fabriquée.

Ce contrôle garde une limite dont le dépassement est invisible du côté où l'on regarde : les
quatre chaînes restent vertes, parce qu'aucune ne déploie. Il faut donc éprouver qu'il refuse
vraiment au treizième — et qu'il ne rend pas vert en ne comptant rien, ce qui est la seule façon
dont un contrôle de ce genre peut échouer sans qu'on le voie.

Le cas le plus important est le DOUZIÈME : un contrôle qui refuserait à douze serait une fausse
alerte permanente, et une fausse alerte permanente finit par être contournée.
"""
import contextlib
import io
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_fonctions as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def lance(chemins: list[str]):
    """Pose une arborescence `api/`, pointe le contrôle dessus, rend (code, sortie)."""
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        api = racine / "api"
        for chemin in chemins:
            f = api / chemin
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text("module.exports = () => {};\n", encoding="utf-8")
        api.mkdir(exist_ok=True)
        avant = (ck.RACINE, ck.API)
        ck.RACINE, ck.API = racine, api
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                code = ck.main()
            return code, tampon.getvalue()
        finally:
            ck.RACINE, ck.API = avant


@cas_de("DOUZE PASSENT — refuser ici serait une fausse alerte permanente")
def _():
    code, sortie = lance([f"r{i}.js" for i in range(12)])
    assert code == 0, sortie
    assert "12 sur 12" in sortie and "aucune place libre" in sortie, sortie


@cas_de("TREIZE REFUSENT, et les treize sont nommées")
def _():
    code, sortie = lance([f"r{i}.js" for i in range(13)])
    assert code == 1, sortie
    assert "13 fonctions" in sortie, sortie
    # Les treize sont nommées une par une : savoir qu'il y en a treize ne dit pas lesquelles
    # regrouper. (On compte les noms, pas les puces — le message en emploie aussi pour les deux
    # sorties de secours, et un contrôle de puces aurait mesuré la mise en forme.)
    for i in range(13):
        assert f"api/r{i}.js" in sortie, f"api/r{i}.js n'est pas nommée : {sortie}"
    # Le message doit porter la phrase de Vercel D'UN SEUL MORCEAU : c'est elle qu'on collera
    # dans un moteur de recherche le jour où le déploiement échouera, et une phrase coupée en
    # deux lignes ne se retrouve pas.
    assert ("No more than 12 Serverless Functions can be added to a Deployment on the Hobby plan."
            in sortie), sortie


@cas_de("la marge est annoncée quand il en reste")
def _():
    code, sortie = lance(["a.js", "b.js"])
    assert code == 0, sortie
    assert "2 sur 12" in sortie and "10 place(s) libre(s)" in sortie, sortie


@cas_de("un routeur `[action].js` compte pour UN, quel que soit le nombre d'actions")
def _():
    # C'est toute la raison d'être de cette forme dans ce serveur. Si le contrôle comptait les
    # actions, il refuserait un dépôt parfaitement déployable.
    code, sortie = lance(["clubs/[action].js", "auth/[action].js", "me.js"])
    assert code == 0, sortie
    assert "3 sur 12" in sortie, sortie


@cas_de("les fichiers sous `lib/` ne comptent pas")
def _():
    # `lib/rapportsEntrants.js` est un gestionnaire d'endpoint complet et ne compte pour rien :
    # c'est la sortie de secours que le message du contrôle propose. Le compter la fermerait.
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        api = racine / "api"
        api.mkdir()
        (api / "events.js").write_text("x\n", encoding="utf-8")
        lib = racine / "lib"
        lib.mkdir()
        for i in range(20):
            (lib / f"m{i}.js").write_text("x\n", encoding="utf-8")
        avant = (ck.RACINE, ck.API)
        ck.RACINE, ck.API = racine, api
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                code = ck.main()
        finally:
            ck.RACINE, ck.API = avant
    assert code == 0, tampon.getvalue()
    assert "1 sur 12" in tampon.getvalue(), tampon.getvalue()


@cas_de("un dossier api/ vide : refus, parce que l'analyse a échoué")
def _():
    code, sortie = lance([])
    assert code == 1, sortie
    assert "Aucune fonction" in sortie, sortie


@cas_de("un dossier api/ absent : refus aussi, et pas un silence")
def _():
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        avant = (ck.RACINE, ck.API)
        ck.RACINE, ck.API = racine, racine / "api"
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                code = ck.main()
        finally:
            ck.RACINE, ck.API = avant
    assert code == 1, tampon.getvalue()
    assert "n'existe pas" in tampon.getvalue(), tampon.getvalue()


@cas_de("le vrai dépôt tient dans le plafond")
def _():
    liste = ck.fonctions()
    assert liste, "aucune fonction lue dans le vrai dépôt"
    assert len(liste) <= ck.PLAFOND, f"{len(liste)} fonctions : {liste}"


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
