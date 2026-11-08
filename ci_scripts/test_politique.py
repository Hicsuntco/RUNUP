#!/usr/bin/env python3
"""Les cas de `check_politique.py`, sans toucher au réseau.

Le réseau est remplacé par une fonction qui rend ce qu'on veut : un contrôle dont les cas
dépendraient d'une page en ligne échouerait le jour où GitHub Pages hoquette, et on apprendrait
à ignorer son rouge.

Ce qui est éprouvé : le SENS qui compte (une section du dépôt absente de la page publiée), le
sens inverse (moins grave, signalé quand même), la différence entre mesurer et refuser, et les
deux façons dont ce contrôle pourrait rendre vert sans rien avoir lu — une adresse introuvable
sur la fiche, et une page locale sans aucun intertitre.
"""
import contextlib
import io
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_politique as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def page(*sections: str) -> str:
    corps = "\n".join(f"<p><strong>{s}</strong> — du texte.</p>" for s in sections)
    return f"<html><body>\n{corps}\n</body></html>\n"


FICHE = ("## URLs requises\n"
         "- **URL de politique de confidentialité** : `https://exemple.test/privacy.html`\n")


def lance(locale: str, publiee, fiche: str = FICHE, exiger: bool = False):
    """Pose la page locale et la fiche, remplace le réseau, rend (code, sortie)."""
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        (racine / "privacy.html").write_text(locale, encoding="utf-8")
        (racine / "APP_STORE_LISTING.md").write_text(fiche, encoding="utf-8")
        avant = (ck.RACINE, ck.PAGE, ck.FICHE, ck.telecharger, sys.argv)
        ck.RACINE, ck.PAGE = racine, racine / "privacy.html"
        ck.FICHE = racine / "APP_STORE_LISTING.md"
        if isinstance(publiee, Exception):
            def reseau(_url):
                raise publiee
        else:
            def reseau(_url):
                return publiee
        ck.telecharger = reseau
        sys.argv = ["check_politique.py"] + (["--exiger"] if exiger else [])
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                try:
                    code = ck.main()
                except SystemExit as arret:
                    return "arret", str(arret)
            return code, tampon.getvalue()
        finally:
            ck.RACINE, ck.PAGE, ck.FICHE, ck.telecharger, sys.argv = avant


@cas_de("les mêmes sections des deux côtés : d'accord")
def _():
    deux = page("Statistiques d'usage", "Rapports de panne")
    code, sortie = lance(deux, deux)
    assert code == 0, sortie
    assert "2 sections" in sortie, sortie


@cas_de("UNE SECTION DU DÉPÔT ABSENTE DE LA PAGE PUBLIÉE : signalée et nommée")
def _():
    # Le cas réel du 8 novembre 2026, et le seul sens qui soit dangereux : l'app collecte
    # quelque chose que la page liée depuis la fiche App Store ne mentionne pas.
    code, sortie = lance(page("Statistiques d'usage", "Rapports de panne"),
                         page("Statistiques d'usage"))
    assert "Rapports de panne" in sortie, sortie
    assert "PAS sur la page publiée" in sortie, sortie


@cas_de("sans --exiger on mesure et on rend 0 ; avec, on refuse")
def _():
    locale, publiee = page("A", "B"), page("A")
    code, _ = lance(locale, publiee)
    assert code == 0, "sans --exiger, le contrôle ne doit pas faire rougir la chaîne"
    code, _ = lance(locale, publiee, exiger=True)
    assert code == 1, "avec --exiger, le contrôle doit refuser"


@cas_de("une section publiée qui n'est plus dans le dépôt est signalée aussi, à part")
def _():
    code, sortie = lance(page("A"), page("A", "Parrainage"))
    assert "Parrainage" in sortie, sortie
    assert "déclare plus que le dépôt" in sortie, sortie
    assert code == 0, sortie


@cas_de("les deux sens à la fois : le dangereux d'abord, l'autre en dessous")
def _():
    code, sortie = lance(page("A", "Rapports de panne"), page("A", "Parrainage"))
    assert sortie.index("Rapports de panne") < sortie.index("Parrainage"), sortie
    assert "moins grave" in sortie, sortie


@cas_de("une page publiée injoignable fait échouer, elle ne se saute pas")
def _():
    code, sortie = lance(page("A"), OSError("connexion refusée"))
    assert code == 0, "sans --exiger, on mesure"
    assert "n'a pas répondu" in sortie, sortie
    code, sortie = lance(page("A"), OSError("connexion refusée"), exiger=True)
    assert code == 1, sortie


@cas_de("aucune adresse sur la fiche : le contrôle se dénonce, il ne rend pas vert")
def _():
    code, message = lance(page("A"), page("A"), fiche="## URLs requises\n- rien ici\n")
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "URL de politique" in message, message


@cas_de("une page locale sans intertitre : refus, parce que l'analyse a échoué")
def _():
    # Sans ça, un changement de mise en forme de `privacy.html` rendrait le contrôle vert en
    # ne comparant rien du tout — la seule façon dont il peut échouer sans qu'on le voie.
    code, sortie = lance("<html><body><p>Du texte sans intertitre.</p></body></html>", page("A"))
    assert code == 1, sortie
    assert "Aucun intertitre" in sortie, sortie


@cas_de("l'adresse est bien lue sur la vraie fiche")
def _():
    url = ck.adresse_publiee()
    assert url.startswith("https://"), url
    assert "privacy" in url, url


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
