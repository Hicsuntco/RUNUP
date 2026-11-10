#!/usr/bin/env python3
"""Une cible qui appelle une API « à motif obligatoire » doit embarquer son manifeste.

# LA QUESTION QUI A FAIT ÉCRIRE CE SCRIPT

`RunUpWatch` n'embarque aucun `PrivacyInfo.xcprivacy`, là où l'app et le widget ont le leur. Je
l'ai relevé le 9 novembre 2026 et j'ai REFUSÉ de trancher : je n'avais pas de source Apple disant
si un paquet de montre embarqué doit porter le sien, et deviner sur un motif de rejet à l'envoi
n'est pas une option.

# LA RÉPONSE, MESURÉE PLUTÔT QUE DEVINÉE

La documentation d'Apple ne traite pas le cas d'un paquet watchOS imbriqué, et les sources
publiques se contredisent. Mais la validation d'Apple, elle, répond — c'est elle qui émet
ITMS-91053. Journal d'archive du 10 novembre 2026, Xcode 26.6 :

    ValidateEmbeddedBinary …/RunUp.app/Watch/RunUpWatch.app
    "com.hicsuntco.runup.watchkitapp" => "RunUp CI montre"
    No errors uploading archive at '…/RunUp.ipa'.
    UPLOAD SUCCEEDED with no errors

Un paquet contenant la montre SANS manifeste passe donc la validation sans une erreur. Et c'est
cohérent avec ce que la règle dit : ITMS-91053 s'appelle « Missing API declaration » et se
déclenche sur l'USAGE d'une API à motif obligatoire sans motif déclaré. `RunUpWatch` n'en appelle
aucune — ni `UserDefaults`, ni date de fichier, ni espace disque, ni heure de démarrage, ni
claviers actifs. Il n'y a rien à déclarer, donc rien à refuser.

# CE QUI RENDRAIT CETTE RÉPONSE FAUSSE, ET QUE CE SCRIPT SURVEILLE

Une seule ligne : le jour où quelqu'un écrit `UserDefaults` dans la montre pour y garder un
réglage. C'est la chose la plus naturelle du monde à écrire, elle compile, les tests passent, et
le refus tombe À L'ENVOI — après quinze minutes d'archive sur une machine macOS.

Ce contrôle lit une seconde de Python : pour chaque cible qui AFFICHE quelque chose, il compare
les API à motif obligatoire qu'elle appelle et le manifeste qu'elle embarque. L'une sans l'autre
est refusée.

# CE QU'IL NE VOIT PAS

Une API atteinte par un chemin qu'un `grep` ne reconnaît pas — une chaîne construite, un pont
Objective-C, une dépendance tierce (il n'y en a aucune ici). Et il ne vérifie pas le CONTENU d'un
manifeste : qu'une catégorie déclarée porte le bon motif se lit à la main, dans le fichier.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_spec as spec  # noqa: E402
from swift import sans_commentaires  # noqa: E402

RACINE = pathlib.Path(__file__).resolve().parent.parent

#: Les cibles dont le binaire est envoyé à Apple. Une cible de test ne part pas.
CIBLES_LIVREES = {"application", "app-extension"}

#: Les cinq familles d'API « à motif obligatoire » d'Apple, et ce qui les trahit dans du Swift.
#: La clé est la catégorie à écrire dans `NSPrivacyAccessedAPIType`.
REQUISES = {
    "NSPrivacyAccessedAPICategoryUserDefaults": (
        re.compile(r"\b(?:NS)?UserDefaults\b"),
        "les préférences de l'app"),
    "NSPrivacyAccessedAPICategoryFileTimestamp": (
        re.compile(r"\b(?:contentModificationDate|creationDate|fileModificationDate"
                   r"|fileCreationDate|attributesOfItem|getattrlist)\b|\b[lf]?stat\s*\("),
        "la date d'un fichier"),
    "NSPrivacyAccessedAPICategorySystemBootTime": (
        re.compile(r"\b(?:systemUptime|mach_absolute_time|mach_continuous_time)\b"),
        "l'heure de démarrage du système"),
    "NSPrivacyAccessedAPICategoryDiskSpace": (
        re.compile(r"\b(?:volumeAvailableCapacity\w*|systemFreeSize)\b|\bstat[fv]?fs\s*\("),
        "l'espace disque libre"),
    "NSPrivacyAccessedAPICategoryActiveKeyboards": (
        re.compile(r"\bactiveInputModes\b"),
        "la liste des claviers actifs"),
}


def appels(fichiers):
    """catégorie → le premier fichier qui l'appelle. Commentaires et chaînes écartés."""
    trouves = {}
    for f in fichiers:
        if f.suffix != ".swift":
            continue
        code = sans_commentaires(f.read_text(encoding="utf-8"))
        for categorie, (motif, _) in REQUISES.items():
            if categorie not in trouves and motif.search(code):
                trouves[categorie] = f
    return trouves


def verifier(racine=RACINE, projet=None):
    if projet is None:
        projet = spec.lire((racine / "project.yml").read_text(encoding="utf-8"))
    plaintes = []
    for nom, cible in (projet.get("targets") or {}).items():
        if cible.get("type") not in CIBLES_LIVREES:
            continue
        embarques = spec.fichiers_embarques(cible, racine)
        manifeste = [f for f in embarques if f.suffix == ".xcprivacy"]
        trouves = appels(embarques)
        if trouves and not manifeste:
            for categorie, fichier in sorted(trouves.items()):
                _, quoi = REQUISES[categorie]
                plaintes.append(
                    f"{nom} appelle {quoi} ({fichier.relative_to(racine)}) et n'embarque aucun "
                    f"PrivacyInfo.xcprivacy. Apple refuse le binaire À L'ENVOI (ITMS-91053) — "
                    f"déclare « {categorie} » avec son motif, ou retire l'appel.")
    return plaintes


def main():
    plaintes = verifier()
    for p in plaintes:
        print(f"✗ {p}")
    if plaintes:
        return 1
    projet = spec.lire((RACINE / "project.yml").read_text(encoding="utf-8"))
    livrees = [n for n, c in (projet.get("targets") or {}).items()
               if c.get("type") in CIBLES_LIVREES]
    print(f"✓ {len(livrees)} cible(s) livrée(s) : chacune déclare les API à motif obligatoire "
          f"qu'elle appelle, ou n'en appelle aucune.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
