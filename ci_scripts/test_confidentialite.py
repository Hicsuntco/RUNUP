#!/usr/bin/env python3
"""Les cas de `check_confidentialite.py`, sur un manifeste et une fiche fabriqués.

Ce contrôle produit une consigne que QUELQU'UN VA RECOPIER CHEZ APPLE, à la main, dans un
formulaire qu'aucune machine ne peut relire ensuite. Une ligne fausse ne se rattrape donc pas :
elle part en déclaration officielle et elle y reste. C'est la raison pour laquelle ce script
s'ARRÊTE devant un type qu'il ne connaît pas au lieu de l'approximer, et la raison pour laquelle
ce fichier éprouve cet arrêt-là en premier.
"""
import contextlib
import io
import pathlib
import plistlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_confidentialite as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def manifeste(*entrees) -> bytes:
    """Un manifeste minimal : (type, lié, suivi, [finalités])."""
    return plistlib.dumps({
        "NSPrivacyTracking": False,
        "NSPrivacyCollectedDataTypes": [
            {"NSPrivacyCollectedDataType": t,
             "NSPrivacyCollectedDataTypeLinked": lie,
             "NSPrivacyCollectedDataTypeTracking": suivi,
             "NSPrivacyCollectedDataTypePurposes": list(finalites)}
            for t, lie, suivi, finalites in entrees
        ],
    })


FONCTIONNALITE = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
ANALYTIQUE = "NSPrivacyCollectedDataTypePurposeAnalytics"


def lance(octets: bytes, corps_du_tableau: str, ecrire: bool = False, marqueurs: bool = True,
          releve=None, poser_releve: bool = False):
    """`releve` : None, ou (date, empreinte) — empreinte "auto" = celle du tableau donné."""
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        m = racine / "PrivacyInfo.xcprivacy"
        m.write_bytes(octets)
        f = racine / "APP_STORE_LISTING.md"
        if marqueurs:
            ligne = ""
            if releve is not None:
                date, emp = releve
                if emp == "auto":
                    emp = ck.empreinte(corps_du_tableau)
                ligne = f"\n<!-- confidentialité: relevé {date} empreinte={emp} -->"
            f.write_text(f"# Fiche\n\n{ck.DEBUT}\n\n{corps_du_tableau}\n\n{ck.FIN}"
                         f"{ligne}\n\nSuite.\n", encoding="utf-8")
        else:
            f.write_text("# Fiche\n\nPas de marqueurs ici.\n", encoding="utf-8")
        avant = (ck.MANIFESTE, ck.FICHE, sys.argv)
        ck.MANIFESTE, ck.FICHE = m, f
        sys.argv = (["check_confidentialite.py"] + (["--ecrire"] if ecrire else [])
                    + (["--releve"] if poser_releve else []))
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                try:
                    code = ck.main()
                except SystemExit as arret:
                    return "arret", str(arret), None
            return code, tampon.getvalue(), f.read_text(encoding="utf-8")
        finally:
            ck.MANIFESTE, ck.FICHE, sys.argv = avant


UN_TYPE = ("NSPrivacyCollectedDataTypeCrashData", True, False, [FONCTIONNALITE])
SON_TABLEAU = ("| Catégorie | Type de donnée | Lié à l'utilisatrice | Suivi | Finalités |\n"
               "| --- | --- | --- | --- | --- |\n"
               "| Diagnostics | **Crash Data** | Oui | Non | App Functionality |")


@cas_de("manifeste, fiche et relevé d'accord : rien à signaler")
def _():
    code, sortie, _ = lance(manifeste(UN_TYPE), SON_TABLEAU, releve=("2026-11-08", "auto"))
    assert code == 0, sortie
    assert "1 types" in sortie, sortie
    assert "2026-11-08" in sortie, "la date du relevé n'est pas dite : " + sortie


@cas_de("UN TYPE AJOUTÉ AU MANIFESTE : refus, et le bon tableau est affiché")
def _():
    # Le cas réel du 8 novembre 2026 : Crash Data et Performance Data entrent dans le manifeste,
    # et la fiche App Store Connect doit suivre sous peine de rejet.
    deux = manifeste(UN_TYPE,
                     ("NSPrivacyCollectedDataTypePerformanceData", True, False, [FONCTIONNALITE]))
    code, sortie, _ = lance(deux, SON_TABLEAU)
    assert code == 1, sortie
    assert "Performance Data" in sortie, sortie
    assert "App Store Connect" in sortie, "le message ne dit pas où reporter : " + sortie


@cas_de("--ecrire pose le tableau au lieu de refuser")
def _():
    deux = manifeste(UN_TYPE,
                     ("NSPrivacyCollectedDataTypePerformanceData", True, False, [FONCTIONNALITE]))
    code, sortie, fiche = lance(deux, SON_TABLEAU, ecrire=True)
    assert code == 0, sortie
    assert "Performance Data" in fiche, fiche
    assert "Suite." in fiche, "le reste de la fiche a été perdu :\n" + fiche
    assert "périmé" in sortie, "--ecrire ne dit pas que le relevé est à refaire : " + sortie
    # Et une seconde passe, relevé reposé, doit maintenant passer.
    corps = fiche.split(ck.DEBUT, 1)[1].split(ck.FIN, 1)[0].strip()
    code, sortie, _ = lance(deux, corps, releve=("2026-11-08", "auto"))
    assert code == 0, sortie


@cas_de("UN TYPE INCONNU FAIT S'ARRÊTER LE SCRIPT, il ne devine pas")
def _():
    # La ligne produite ici serait recopiée à la main dans une déclaration officielle. Inventer
    # une catégorie plausible est le pire comportement possible.
    inconnu = manifeste(("NSPrivacyCollectedDataTypeGameplayContent", True, False, [FONCTIONNALITE]))
    code, message, _ = lance(inconnu, SON_TABLEAU)
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "GameplayContent" in message and "app-privacy-details" in message, message


@cas_de("une finalité inconnue fait s'arrêter aussi")
def _():
    bizarre = manifeste(("NSPrivacyCollectedDataTypeCrashData", True, False,
                         ["NSPrivacyCollectedDataTypePurposeTelepathy"]))
    code, message, _ = lance(bizarre, SON_TABLEAU)
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "Telepathy" in message, message


@cas_de("les marqueurs absents : le contrôle dit lesquels poser")
def _():
    code, message, _ = lance(manifeste(UN_TYPE), SON_TABLEAU, marqueurs=False)
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert ck.DEBUT in message and ck.FIN in message, message


@cas_de("un manifeste sans donnée collectée : refus, l'analyse a échoué")
def _():
    vide = plistlib.dumps({"NSPrivacyTracking": False})
    code, message, _ = lance(vide, SON_TABLEAU)
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "aucune donnée" in message, message


@cas_de("les catégories sortent DANS L'ORDRE DU FORMULAIRE")
def _():
    # Saisir dans l'ordre d'Apple évite de chercher chaque catégorie à travers seize sections.
    plusieurs = manifeste(
        ("NSPrivacyCollectedDataTypeCrashData", True, False, [FONCTIONNALITE]),
        ("NSPrivacyCollectedDataTypeName", True, False, [FONCTIONNALITE]),
        ("NSPrivacyCollectedDataTypeProductInteraction", True, False, [ANALYTIQUE]),
    )
    code, sortie, _ = lance(plusieurs, SON_TABLEAU)
    assert code == 1, sortie
    i_contact = sortie.index("Contact Info")
    i_usage = sortie.index("Usage Data")
    i_diag = sortie.index("Diagnostics")
    assert i_contact < i_usage < i_diag, "l'ordre du formulaire n'est pas respecté :\n" + sortie


@cas_de("plusieurs finalités se lisent séparées par une virgule")
def _():
    deux_fins = manifeste(("NSPrivacyCollectedDataTypeDeviceID", True, False,
                           [FONCTIONNALITE, ANALYTIQUE]))
    code, sortie, _ = lance(deux_fins, SON_TABLEAU)
    assert "App Functionality, Analytics" in sortie, sortie


@cas_de("LE DÉFAUT DU 8 NOVEMBRE : le dépôt est d'accord avec lui-même, la fiche d'Apple non")
def _():
    # Ce jour-là, cinq types manquaient chez Apple, trois catégories y étaient déclarées non
    # liées, et Product Interaction portait la mauvaise finalité — pendant que ce contrôle
    # était vert, parce qu'il ne comparait que deux fichiers du dépôt. Le relevé est la seule
    # chose qui pouvait rougir : il dit « cette fiche a été vue contre un AUTRE tableau ».
    deux = manifeste(UN_TYPE,
                     ("NSPrivacyCollectedDataTypePerformanceData", True, False, [FONCTIONNALITE]))
    son_tableau = ("| Catégorie | Type de donnée | Lié à l'utilisatrice | Suivi | Finalités |\n"
                   "| --- | --- | --- | --- | --- |\n"
                   "| Diagnostics | **Crash Data** | Oui | Non | App Functionality |\n"
                   "| Diagnostics | **Performance Data** | Oui | Non | App Functionality |")
    # La fiche du dépôt A SUIVI le manifeste ; seul le relevé date d'avant.
    code, sortie, _ = lance(deux, son_tableau,
                            releve=("2026-10-08", ck.empreinte(SON_TABLEAU)))
    assert code == 1, "le contrôle est vert alors que la fiche d'Apple n'a pas été revue :\n" + sortie
    assert "2026-10-08" in sortie, sortie
    assert "Performance Data" in sortie, "le tableau à saisir n'est pas affiché :\n" + sortie
    assert "App Store Connect" in sortie, sortie


@cas_de("aucun relevé : le contrôle refuse plutôt que de supposer que quelqu'un a regardé")
def _():
    code, sortie, _ = lance(manifeste(UN_TYPE), SON_TABLEAU)
    assert code == 1, sortie
    assert "--releve" in sortie, sortie


@cas_de("--releve date la fiche, et la passe suivante est verte")
def _():
    code, sortie, fiche = lance(manifeste(UN_TYPE), SON_TABLEAU, poser_releve=True)
    assert code == 0, sortie
    trouve = ck.RELEVE.search(fiche)
    assert trouve, "aucune ligne de relevé posée :\n" + fiche
    assert trouve.group(2) == ck.empreinte(SON_TABLEAU), fiche
    assert "Suite." in fiche, "le reste de la fiche a été perdu :\n" + fiche
    code, sortie, _ = lance(manifeste(UN_TYPE), SON_TABLEAU,
                            releve=(trouve.group(1), trouve.group(2)))
    assert code == 0, sortie


@cas_de("--releve REFUSE de dater un tableau qui ne correspond pas encore au manifeste")
def _():
    # Sinon le relevé certifierait une fiche contre un tableau que personne n'a jamais saisi :
    # le contrôle redeviendrait vert en ayant perdu la seule chose qu'il savait.
    deux = manifeste(UN_TYPE,
                     ("NSPrivacyCollectedDataTypePerformanceData", True, False, [FONCTIONNALITE]))
    code, sortie, fiche = lance(deux, SON_TABLEAU, poser_releve=True)
    assert code == 1, sortie
    assert ck.RELEVE.search(fiche) is None, "un relevé a été posé quand même :\n" + fiche
    assert "--ecrire" in sortie, sortie


@cas_de("--releve REMPLACE le relevé d'avant, il n'en empile pas un second")
def _():
    _, _, fiche = lance(manifeste(UN_TYPE), SON_TABLEAU, poser_releve=True,
                        releve=("2020-01-01", "aaaaaaaaaaaa"))
    assert len(ck.RELEVE.findall(fiche)) == 1, "deux lignes de relevé :\n" + fiche
    assert "2020-01-01" not in fiche, fiche


@cas_de("une ligne de relevé mal formée compte pour pas de relevé")
def _():
    # Mieux vaut refuser que lire « empreinte=» comme une empreinte qui correspond.
    code, sortie, _ = lance(manifeste(UN_TYPE), SON_TABLEAU, releve=("8-11-26", "auto"))
    assert code == 1, sortie
    assert "--releve" in sortie, sortie


@cas_de("le vrai dépôt : la fiche et le manifeste sont d'accord")
def _():
    lignes = ck.lignes_attendues()
    assert lignes, "aucune ligne dérivée du vrai manifeste"
    assert ck.tableau(lignes) == ck.bloc_de_la_fiche(), \
        "APP_STORE_LISTING.md a divergé du manifeste"


@cas_de("les deux familles de diagnostics du 8 novembre sont bien dedans")
def _():
    libelles = {l["libelle"] for l in ck.lignes_attendues()}
    for attendu in ("Crash Data", "Performance Data"):
        assert attendu in libelles, f"{attendu} manque : {sorted(libelles)}"


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
