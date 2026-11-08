#!/usr/bin/env python3
"""Les cas de `check_declencheur.py`, sur un dépôt fabriqué.

Ce contrôle garde une liste dont l'erreur est SILENCIEUSE : un chemin manquant ne fait pas rougir
la chaîne des captures, il l'empêche de partir. Il faut donc éprouver qu'il attrape vraiment
l'omission — et surtout qu'il ne rend pas vert en ne lisant rien, ce qui est la seule façon dont
un contrôle de ce genre peut échouer sans qu'on le voie.

Trois pièges visés :

  · le bloc `paths:` du vrai `captures.yml` est commenté ENTRÉE PAR ENTRÉE. Un lecteur qui
    s'arrête au premier commentaire lit deux chemins sur quinze, et déclare orphelines cent vues
    qui ne le sont pas ;
  · le bloc doit s'arrêter là où la liste s'arrête, sans ramasser la clé suivante ;
  · un motif à étoile que le script ne sait pas juger doit le faire S'ARRÊTER, pas deviner. Un
    contrôle qui fait semblant de comprendre la syntaxe de GitHub est pire qu'absent.
"""
import contextlib
import io
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_declencheur as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


#: Des étapes qui ne lancent aucun script : le défaut par défaut des cas existants.
SANS_SCRIPT = "      - name: Photographier\n        run: xcodebuild test\n"


def workflow(entrees: str, etapes: str = SANS_SCRIPT) -> str:
    return (
        "on:\n"
        "  push:\n"
        "    branches:\n"
        '      - "**"\n'
        "    paths:\n"
        f"{entrees}"
        "  workflow_dispatch:\n"
        "    inputs:\n"
        "      langues:\n"
        '        description: "Langues"\n'
        "jobs:\n"
        "  captures:\n"
        "    steps:\n"
        f"{etapes}"
    )


UNE_VUE = "struct Truc: View {\n    var body: some View { Text(\"x\") }\n}\n"


def lance(entrees: str, fichiers: dict[str, str], etapes: str = SANS_SCRIPT):
    """Pose un dépôt, pointe le contrôle dessus, rend (code de sortie, sortie)."""
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        wf = racine / ".github/workflows/captures.yml"
        wf.parent.mkdir(parents=True)
        wf.write_text(workflow(entrees, etapes), encoding="utf-8")
        app = racine / "RunUp"
        for chemin, contenu in fichiers.items():
            f = app / chemin
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(contenu, encoding="utf-8")
        avant = (ck.RACINE, ck.WORKFLOW, ck.APP)
        ck.RACINE, ck.WORKFLOW, ck.APP = racine, wf, app
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                try:
                    code = ck.main()
                except SystemExit as arret:
                    return "arret", str(arret)
            return code, tampon.getvalue()
        finally:
            ck.RACINE, ck.WORKFLOW, ck.APP = avant


@cas_de("une vue sous un chemin couvert : d'accord")
def _():
    code, sortie = lance('      - "RunUp/Views/**"\n', {"Views/Ecran.swift": UNE_VUE})
    assert code == 0, sortie
    assert "1 fichiers de vues" in sortie, sortie


@cas_de("UNE VUE HORS DES CHEMINS : REFUS, ET ELLE EST NOMMÉE")
def _():
    # La régression exacte du 8 novembre 2026 : `RunUpApp.swift` portait `RootView` et ne
    # figurait pas dans le déclencheur.
    code, sortie = lance('      - "RunUp/Views/**"\n', {"RunUpApp.swift": UNE_VUE})
    assert code == 1, sortie
    assert "RunUp/RunUpApp.swift" in sortie, sortie


@cas_de("un fichier sans vue n'est pas réclamé")
def _():
    # Les `Services` et les `Models` restent dehors par décision : le contrôle ne la conteste pas.
    code, sortie = lance('      - "RunUp/Views/**"\n', {
        "Views/Ecran.swift": UNE_VUE,
        "Services/Reseau.swift": "final class Reseau { func charger() {} }\n",
        "Models/Profil.swift": "struct Profil { var nom = \"\" }\n",
    })
    assert code == 0, sortie
    assert "1 fichiers de vues" in sortie, sortie


@cas_de("LE BLOC COMMENTÉ ENTRÉE PAR ENTRÉE EST LU EN ENTIER")
def _():
    # La forme du vrai fichier. Un lecteur qui s'arrête au premier commentaire déclarerait
    # orpheline la vue couverte par le dernier chemin.
    entrees = (
        "      # Ce qui se juge à l'œil.\n"
        '      - "RunUp/Views/**"\n'
        "\n"
        "      # ET LE FICHIER QUI PORTE LA VUE RACINE.\n"
        "      #\n"
        "      # Deux lignes de commentaire d'affilée, et une ligne vide avant.\n"
        '      - "RunUp/RunUpApp.swift"\n'
    )
    code, sortie = lance(entrees, {"Views/Ecran.swift": UNE_VUE, "RunUpApp.swift": UNE_VUE})
    assert code == 0, sortie
    assert "2 fichiers de vues" in sortie and "2 chemins" in sortie, sortie


@cas_de("le bloc s'arrête à la clé suivante")
def _():
    # `workflow_dispatch:` et ses entrées ne sont pas des chemins. S'ils étaient ramassés, le
    # nombre de chemins mentirait — et un `description: "..."` pourrait même couvrir une vue.
    code, sortie = lance('      - "RunUp/Views/**"\n', {"Views/Ecran.swift": UNE_VUE})
    assert code == 0, sortie
    assert "1 chemins" in sortie, sortie


@cas_de("un motif à étoile inconnue fait s'arrêter le contrôle, il ne devine pas")
def _():
    code, message = lance('      - "RunUp/*/Ecran.swift"\n', {"Views/Ecran.swift": UNE_VUE})
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "étoile" in message, message


@cas_de("bloc `paths:` absent : le contrôle se dénonce")
def _():
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        wf = racine / "captures.yml"
        wf.write_text("on:\n  push:\n    branches:\n      - \"**\"\n", encoding="utf-8")
        avant = ck.WORKFLOW
        ck.WORKFLOW = wf
        try:
            ck.chemins_declencheurs()
            raise AssertionError("un workflow sans bloc `paths:` aurait dû arrêter le contrôle")
        except SystemExit as arret:
            assert "paths" in str(arret), str(arret)
        finally:
            ck.WORKFLOW = avant


@cas_de("bloc `paths:` vide : le contrôle se dénonce aussi")
def _():
    code, message = lance("", {"Views/Ecran.swift": UNE_VUE})
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "vide" in message, message


@cas_de("aucune vue trouvée : refus, parce que l'analyse a échoué")
def _():
    # Un `RunUp/` renommé, un `rglob` sur un chemin absent : ça ne rend rien et ne dit rien.
    # C'est exactement le défaut qui a fait relire un dossier inexistant en silence le
    # 7 novembre 2026.
    code, sortie = lance('      - "RunUp/Views/**"\n', {})
    assert code == 1, sortie
    assert "Aucune vue" in sortie, sortie


@cas_de("le vrai dépôt : toutes les vues relancent les captures")
def _():
    motifs = ck.chemins_declencheurs()
    vues = list(ck.vues_du_depot())
    assert vues, "aucune vue lue dans le vrai dépôt"
    orphelines = [v for v in vues if not ck.couvert(v, motifs)]
    assert not orphelines, f"non couvertes : {orphelines}"


@cas_de("les deux fichiers dont l'omission a coûté quelque chose sont bien couverts")
def _():
    motifs = ck.chemins_declencheurs()
    for vue in ("RunUp/AppState.swift", "RunUp/RunUpApp.swift"):
        assert ck.couvert(vue, motifs), f"{vue} ne relance pas les captures"


# --- La seconde règle : un script lancé doit déclencher la chaîne qui le lance ----------------

COUVRE_TOUT = ('      - "RunUp/Views/**"\n'
               '      - "ci_scripts/test_truc.py"\n')


@cas_de("UN SCRIPT LANCÉ MAIS HORS DU FILTRE : refus, et il est nommé")
def _():
    # Le défaut réel du 8 novembre 2026 : quatre scripts étaient lancés par `captures.yml` sans
    # être dans son filtre. Les modifier ne relançait pas la chaîne qui les exécute.
    etapes = ("      - name: Éprouver la comparaison\n"
              "        run: cd ci_scripts && python3 test_comparer.py\n")
    code, sortie = lance('      - "RunUp/Views/**"\n', {"Views/E.swift": UNE_VUE}, etapes=etapes)
    assert code == 1, sortie
    assert "ci_scripts/test_comparer.py" in sortie, sortie
    assert "débranché" in sortie, sortie


@cas_de("un interpréteur autre que python3 compte quand même")
def _():
    # Le piège exact qui a fait rendre ZÉRO script à la première version : ce workflow lance ses
    # scripts avec le python d'un environnement virtuel, pas avec `python3`.
    etapes = ('      - name: Éprouver\n'
              '        run: cd ci_scripts && "$RUNNER_TEMP/venv/bin/python" test_comparer.py\n')
    code, sortie = lance('      - "RunUp/Views/**"\n', {"Views/E.swift": UNE_VUE}, etapes=etapes)
    assert code == 1, f"le script lancé par un venv n'a pas été vu :\n{sortie}"
    assert "test_comparer.py" in sortie, sortie


@cas_de("un script seulement CITÉ dans un commentaire ne compte pas")
def _():
    etapes = ("      # On a envisagé python3 test_comparer.py ici, et on ne l'a pas fait.\n"
              "      - name: Éprouver\n"
              "        run: cd ci_scripts && python3 test_truc.py\n")
    code, sortie = lance(COUVRE_TOUT, {"Views/E.swift": UNE_VUE}, etapes=etapes)
    assert code == 0, f"un commentaire a été compté comme un lancement :\n{sortie}"
    assert "1 scripts lancés" in sortie, sortie


@cas_de("une entrée du filtre ne compte pas pour un lancement")
def _():
    # Sinon la règle serait tautologique : tout ce qui est dans le filtre serait « lancé », et
    # elle ne pourrait jamais rien attraper.
    entrees = ('      - "RunUp/Views/**"\n'
               '      - "ci_scripts/test_comparer.py"\n'
               '      - "ci_scripts/test_truc.py"\n')
    code, sortie = lance(entrees, {"Views/E.swift": UNE_VUE})
    assert code == 0, sortie
    assert "0 scripts lancés" in sortie, f"le filtre a été compté comme un lancement :\n{sortie}"


@cas_de("UN NOM DE SCRIPT SANS LANCEMENT LISIBLE : refus, la lecture a échoué")
def _():
    # La signature d'une expression cassée : le workflow parle bien de ces fichiers, mais la
    # forme du lancement a changé et on n'y lit plus rien. C'est exactement ce qui est arrivé à
    # la première version de cette règle, qui a rendu VERT en trouvant zéro script.
    etapes = ("      - name: Éprouver\n"
              "        run: cd ci_scripts && sh lancer_tout.sh test_comparer.py\n")
    code, sortie = lance(COUVRE_TOUT, {"Views/E.swift": UNE_VUE}, etapes=etapes)
    assert code == 1, f"un compte nul a rendu vert :\n{sortie}"
    assert "analyse a échoué" in sortie, sortie


@cas_de("un workflow qui ne lance aucun script est un cas normal, pas une panne")
def _():
    code, sortie = lance('      - "RunUp/Views/**"\n', {"Views/E.swift": UNE_VUE})
    assert code == 0, f"un workflow sans script a été pris pour une lecture cassée :\n{sortie}"
    assert "0 scripts lancés" in sortie, sortie


@cas_de("le vrai dépôt : les scripts lancés par les captures sont tous dans son filtre")
def _():
    motifs = ck.chemins_declencheurs()
    lances, _ = ck.scripts_lances()
    assert lances, "aucun script lancé lu dans le vrai workflow"
    debranches = [n for n in lances if not ck.couvert(f"ci_scripts/{n}", motifs)]
    assert not debranches, f"lancés mais hors du filtre : {debranches}"


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
