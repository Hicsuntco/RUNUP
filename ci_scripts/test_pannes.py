#!/usr/bin/env python3
"""Les cas de `check_pannes.py`, sur des fichiers fabriqués.

Ce contrôle garde une liste qui, si elle divergeait, ne se signalerait par AUCUN symptôme : une
table de pannes vide ressemble à une app qui ne plante pas. Il est donc lui-même la seule chose
qui veille — ce qui en fait exactement le genre de script qu'il faut éprouver, et pas seulement
écrire.

Quatre pièges sont visés en particulier :

  · le commentaire qui cite un genre entre guillemets simples dans une phrase, et que le lecteur
    naïf du bloc JS compterait comme une entrée de la liste (ce piège s'est refermé trois fois
    dans ce dépôt : `check_cjs.py`, `check_filet.py`, `check_cablage.py`) ;
  · l'énumération Swift qui ne s'arrête pas où il faut, et ramasse des `case` d'ailleurs dans le
    fichier ;
  · le marqueur introuvable — un renommage, et un contrôle qui rendrait vert en ne lisant RIEN ;
  · les deux sens de la divergence, parce qu'un genre orphelin côté serveur rend zéro gel et se
    lit comme « l'app ne gèle pas ».
"""
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_pannes as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def swift(genres: str) -> str:
    return (
        "final class Diagnostics: NSObject {\n"
        "    enum Genre: String {\n"
        f"{genres}"
        "    }\n"
        "\n"
        "    func demarrer() {\n"
        f"{ABONNEMENT}"
        "    }\n"
        "\n"
        "    // Hors de l'énumération, et ne doit donc PAS être ramassé.\n"
        '    case ailleurs = "pas_un_genre"\n'
        "}\n"
    )


def js(entrees: str) -> str:
    return (
        "const KNOWN_KINDS = new Set([\n"
        f"{entrees}"
        "]);\n"
        "// Après la liste : 'pas_un_genre' ne doit pas être ramassé.\n"
    )


MANIFESTE_COMPLET = (
    "<plist><dict>\n"
    "  <string>NSPrivacyCollectedDataTypeCrashData</string>\n"
    "  <string>NSPrivacyCollectedDataTypePerformanceData</string>\n"
    "</dict></plist>\n"
)

# Ce que `check_pannes.manifeste_incomplet` cherche dans le Swift pour savoir si l'app envoie.
ABONNEMENT = "        MXMetricManager.shared.add(self)\n"


def lance(code_swift: str, code_js: str, manifeste: str = MANIFESTE_COMPLET):
    """Pose les trois fichiers, pointe le contrôle dessus, rend (code de sortie, sortie)."""
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        fs, fj = dossier / "Diagnostics.swift", dossier / "pannes.js"
        fm = dossier / "PrivacyInfo.xcprivacy"
        fs.write_text(code_swift, encoding="utf-8")
        fj.write_text(code_js, encoding="utf-8")
        fm.write_text(manifeste, encoding="utf-8")
        avant = (ck.SWIFT, ck.JS, ck.MANIFESTE)
        ck.SWIFT, ck.JS, ck.MANIFESTE = fs, fj, fm
        try:
            import contextlib
            import io
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                try:
                    code = ck.main()
                except SystemExit as arret:
                    return "arret", str(arret)
            return code, tampon.getvalue()
        finally:
            ck.SWIFT, ck.JS, ck.MANIFESTE = avant


LES_CINQ_SWIFT = (
    '        case plantage = "crash"\n'
    '        case gel = "hang"\n'
)
LES_CINQ_JS = (
    "  'crash',\n"
    "  'hang',\n"
)


@cas_de("deux listes identiques : d'accord")
def _():
    code, sortie = lance(swift(LES_CINQ_SWIFT), js(LES_CINQ_JS))
    assert code == 0, sortie
    assert "2 genres" in sortie, sortie


@cas_de("un genre que le serveur ne connaît pas : refus, et il est nommé")
def _():
    code, sortie = lance(swift(LES_CINQ_SWIFT), js("  'crash',\n"))
    assert code == 1, sortie
    assert "hang" in sortie and "JET" in sortie.upper(), sortie


@cas_de("un genre que le client n'émet plus : refus aussi")
def _():
    code, sortie = lance(swift('        case plantage = "crash"\n'), js(LES_CINQ_JS))
    assert code == 1, sortie
    assert "hang" in sortie and "plus émis" in sortie, sortie


@cas_de("un commentaire qui cite un genre ne compte pas pour une entrée")
def _():
    # Le serveur n'accepte QUE 'crash' ; le commentaire parle de 'hang' dans une phrase.
    menteur = (
        "const KNOWN_KINDS = new Set([\n"
        "  // Le gel ('hang') a été envisagé ici et n'y est pas.\n"
        "  'crash',\n"
        "]);\n"
    )
    code, sortie = lance(swift(LES_CINQ_SWIFT), menteur)
    assert code == 1, "le commentaire a été compté comme une entrée : " + sortie
    assert "hang" in sortie, sortie


@cas_de("l'énumération Swift s'arrête à sa fermeture")
def _():
    # `swift()` pose un `case ailleurs = "pas_un_genre"` APRÈS la fermeture. S'il était ramassé,
    # le serveur ne le connaîtrait pas et le contrôle refuserait.
    code, sortie = lance(swift(LES_CINQ_SWIFT), js(LES_CINQ_JS))
    assert code == 0, "un `case` hors de l'énumération a été ramassé : " + sortie
    assert "pas_un_genre" not in sortie, sortie


@cas_de("marqueur Swift introuvable : le contrôle se dénonce, il ne rend pas vert")
def _():
    code, message = lance("final class Diagnostics {}\n", js(LES_CINQ_JS))
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "enum Genre" in message, message


@cas_de("marqueur JS introuvable : le contrôle se dénonce aussi")
def _():
    code, message = lance(swift(LES_CINQ_SWIFT), "const AUTRE = new Set([]);\n")
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "KNOWN_KINDS" in message, message


@cas_de("deux listes vides : refus, parce que l'analyse a échoué")
def _():
    code, sortie = lance(swift(""), js(""))
    assert code == 1, sortie
    assert "vide" in sortie, sortie


@cas_de("le vrai dépôt : les deux listes concordent")
def _():
    client = ck.genres_du_client()
    serveur = ck.genres_du_serveur()
    assert client, "aucun genre lu côté client"
    assert client == serveur, f"client {sorted(client)} ≠ serveur {sorted(serveur)}"
    # Le contrôle ne vaut que si le serveur refuse vraiment ce qui n'est pas dans la liste :
    # c'est la ligne d'`api/crashes.js` qui donne son sens à tout ce fichier.
    source = ck.JS.read_text(encoding="utf-8")
    assert "KNOWN_KINDS.has(brut.kind)" in source, \
        "lib/pannes.js ne filtre plus sur `KNOWN_KINDS` — ce contrôle garde une liste inutile."
    # Et l'endpoint doit vraiment passer par ce filtre : la liste pourrait être juste des deux
    # côtés et n'être appelée par personne.
    route = (ck.RACINE / "api/crashes.js").read_text(encoding="utf-8")
    assert "nettoyerRapport" in route, \
        "api/crashes.js n'appelle plus `nettoyerRapport` — le vocabulaire ne filtre plus rien."


@cas_de("les cinq genres de MetricKit sont bien les cinq attendus")
def _():
    # Pas un détail de forme : ces cinq noms sont les cinq listes d'un `MXDiagnosticPayload`.
    # En perdre un, c'est perdre en silence toute une famille de pannes — et les quatre qui ne
    # sont pas « crash » sont justement celles où l'app ne meurt pas, elle devient mauvaise.
    attendus = {"crash", "hang", "cpu_exception", "disk_write_exception", "app_launch"}
    assert ck.genres_du_client() == attendus, sorted(ck.genres_du_client())


@cas_de("un manifeste qui ne déclare pas les plantages : refus")
def _():
    nu = "<plist><dict></dict></plist>\n"
    code, sortie = lance(swift(LES_CINQ_SWIFT), js(LES_CINQ_JS), manifeste=nu)
    assert code == 1, sortie
    assert "NSPrivacyCollectedDataTypeCrashData" in sortie, sortie
    assert "NSPrivacyCollectedDataTypePerformanceData" in sortie, sortie


@cas_de("les plantages déclarés mais pas les gels : refus quand même")
def _():
    # Le piège exact : déclarer « Crash Data » et croire que c'est fini, alors que quatre des cinq
    # genres de MetricKit ne sont pas des plantages.
    partiel = "<plist><string>NSPrivacyCollectedDataTypeCrashData</string></plist>\n"
    code, sortie = lance(swift(LES_CINQ_SWIFT), js(LES_CINQ_JS), manifeste=partiel)
    assert code == 1, sortie
    assert "NSPrivacyCollectedDataTypePerformanceData" in sortie, sortie
    assert "NSPrivacyCollectedDataTypeCrashData" not in sortie, \
        "celle qui est déclarée ne doit pas être réclamée : " + sortie


@cas_de("une app qui ne s'abonne plus à MetricKit n'a plus rien à déclarer")
def _():
    # La règle doit se mettre en veille, pas exiger une déclaration pour des données qui ne
    # partent plus. Un manifeste trop large n'est pas un motif de rejet, mais réclamer une
    # déclaration inutile apprendrait à contourner le contrôle.
    sans_abonnement = swift(LES_CINQ_SWIFT).replace(ABONNEMENT, "")
    nu = "<plist><dict></dict></plist>\n"
    code, sortie = lance(sans_abonnement, js(LES_CINQ_JS), manifeste=nu)
    assert code == 0, sortie


@cas_de("le vrai manifeste déclare bien les deux familles")
def _():
    manquantes = ck.manifeste_incomplet()
    assert not manquantes, f"manque au manifeste : {manquantes}"


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
