#!/usr/bin/env python3
"""Les cas de `check_deploiement` — sans toucher au réseau."""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_deploiement as c  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


@cas_de("l'URL de production est LUE dans l'app, pas recopiée ici")
def _():
    base = c.base_de_production()
    assert base.startswith("https://"), base
    assert not base.endswith("/"), "une barre finale doublerait le séparateur"


@cas_de("les adresses viennent du vrai code, et les pages de course en font partie")
def _():
    liste = c.adresses()
    assert len(liste) > 40, f"seulement {len(liste)} adresses : l'extraction a cassé"
    assert "api/races/page" in liste, "la fonctionnalité contrôlée n'est pas dans la liste"
    assert "api/clubs/search" in liste
    # L'appel par URL entière, qui n'est pas un `path:`.
    assert any(a.startswith("https://") and a.endswith("/api/coach") for a in liste), \
        "le proxy du coach est appelé par une URL entière et doit être couvert"


@cas_de("chaque adresse n'est demandée qu'une fois")
def _():
    liste = c.adresses()
    assert len(liste) == len(set(liste))
    assert liste == sorted(liste), "un ordre stable, sinon la sortie change à chaque exécution"


@cas_de("aucune adresse ne porte de barre en tête")
def _():
    # `f"{base}/{chemin}"` doublerait la barre, et Vercel rendrait 404 sur une route existante —
    # le contrôle accuserait alors un déploiement parfaitement sain.
    for adresse in c.adresses():
        if not adresse.startswith("http"):
            assert not adresse.startswith("/"), adresse


@cas_de("SEUL 404 compte comme absent")
def _():
    # 401 (protégée), 405 (mauvaise méthode), 500 (déployée mais en panne) prouvent tous qu'une
    # fonction est là. Confondre 500 avec 404 ferait accuser le déploiement d'un bug de code.
    faux = [("a", 401), ("b", 405), ("c", 500), ("d", 200), ("e", 0)]
    assert [x for x, s in faux if s == 404] == []
    assert [x for x, s in faux + [("f", 404)] if s == 404] == ["f"]


@cas_de("un 5xx n'est pas une absence, et n'est pas une santé non plus")
def _():
    # La phrase d'à côté reste vraie : 500 ne veut pas dire « rien n'est déployé ». Elle était
    # juste et insuffisante — ce contrôle est le seul endroit du dépôt qui regarde la production,
    # et une fonction qui n'arrive pas à charger ses dépendances répond exactement ça.
    assert c.en_erreur(500) and c.en_erreur(502) and c.en_erreur(599)
    assert not c.en_erreur(404), "404 a sa propre classe, avec son propre message"
    assert not c.en_erreur(401) and not c.en_erreur(405) and not c.en_erreur(400)
    # 0 est « pas de réponse du tout » — réseau, pas déploiement. Le confondre avec un 5xx
    # ferait échouer le workflow sur une coupure de la machine GitHub.
    assert not c.en_erreur(0)


@cas_de("le deuxième tour reprend les absentes ET les tombées")
def _():
    resultats = [("a", 401), ("b", 404), ("c", 500), ("d", 405), ("e", 0)]
    assert c.a_revoir(resultats) == ["b", "c"]
    # Rien à revoir sur un relevé sain : c'est celui du 7 novembre 2026, 69 × 401, 13 × 405,
    # 1 × 400, zéro 5xx. C'est ce relevé qui autorise à refuser un 5xx.
    assert c.a_revoir([("a", 401)] * 69 + [("b", 405)] * 13 + [("c", 400)]) == []


@cas_de("une panne de réseau ne s'écrit pas 404")
def _():
    # `code()` rend 0 pour une exception non HTTP : un runner sans réseau ne doit pas faire croire
    # à neuf routes disparues.
    assert c.code("https://adresse.qui.n.existe.pas.invalid/api/x") == 0


def main() -> int:
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as erreur:
            echecs += 1
            print(f"  ÉCHEC {nom}\n        {erreur}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
