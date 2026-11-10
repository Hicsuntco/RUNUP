#!/usr/bin/env python3
"""Les cas de `check_delais.py`.

CE QU'ILS EMPÊCHENT DE REVENIR. Douze requêtes sans délai déclaré, donc soixante secondes de roue
qui tourne chez quelqu'un dans un train — et invisible en développement, où un aller-retour sur
notre API prend un demi-seconde.
"""
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_delais as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def depot(contenu, nom="RunUp/Services/X.swift"):
    racine = pathlib.Path(tempfile.mkdtemp())
    f = racine / nom
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(contenu, encoding="utf-8")
    return racine


@cas_de("une requête sans délai sonne")
def _():
    g = ck.problemes(depot('var request = URLRequest(url: u)\nrequest.httpMethod = "POST"\n'))
    assert any("sans `timeoutInterval`" in x for x in g), g


@cas_de("la même, avec un délai pris dans Delais, ne sonne pas")
def _():
    g = ck.problemes(depot("var request = URLRequest(url: u)\n"
                           "request.timeoutInterval = Delais.interactif\n"))
    assert g == [], g


@cas_de("UN DÉLAI ÉCRIT EN DUR SONNE AUSSI")
def _():
    # Douze requêtes, douze occasions de diverger. La valeur se décide à un seul endroit.
    g = ck.problemes(depot("var request = URLRequest(url: u)\nrequest.timeoutInterval = 15\n"))
    assert any("en dur" in x for x in g), g


@cas_de("un délai posé trop loin de la requête sonne")
def _():
    # On le lit là où on lit l'appel. Sept lignes plus bas, personne ne le voit.
    corps = "var request = URLRequest(url: u)\n" + "x()\n" * 8 + "request.timeoutInterval = Delais.interactif\n"
    g = ck.problemes(depot(corps))
    assert any("sans `timeoutInterval`" in x for x in g), g


@cas_de("`Delais.swift` lui-même n'est pas regardé")
def _():
    g = ck.problemes(depot("let x = URLRequest(url: u)\n", nom="RunUp/Services/Delais.swift"))
    assert g == [], g


@cas_de("une requête nommée dans un commentaire ne compte pas")
def _():
    g = ck.problemes(depot("// on construisait une URLRequest( sans délai, et c'était le défaut\n"))
    assert g == [], g


@cas_de("le vrai dépôt : chaque requête a son délai")
def _():
    g = ck.problemes()
    assert g == [], "\n".join(g)


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
