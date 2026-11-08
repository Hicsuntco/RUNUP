#!/usr/bin/env python3
"""La fiche App Store Connect doit déclarer ce que le manifeste déclare.

# POURQUOI CE CONTRÔLE EXISTE

Trois endroits disent ce que RUNUP collecte, et ils doivent dire la même chose :

  1. `RunUp/Resources/PrivacyInfo.xcprivacy` — le manifeste, livré DANS le binaire ;
  2. la politique publiée — gardée par `check_politique.py` depuis le 8 novembre 2026 ;
  3. la fiche « App Privacy » d'App Store Connect, remplie à la main dans un navigateur.

Une divergence entre le manifeste et la fiche est un motif de rejet à part entière. Et la
troisième est la seule que rien ne pouvait tenir : **l'API d'App Store Connect ne sait pas la
lire ni l'écrire**. Vérifié plutôt que supposé — la spécification OpenAPI officielle d'Apple
(v4.6, novembre 2026) compte 1 027 chemins et AUCUN ne contient « dataUsage » ni « privacy ».
Elle sait poser la classification d'âge, pas l'étiquette de confidentialité.

# CE QU'IL FAIT, FAUTE DE POUVOIR PARLER À APPLE

Il DÉRIVE du manifeste le tableau exact à saisir dans le formulaire — catégorie, type de donnée,
« lié à l'utilisatrice », « suivi », finalités — et vérifie que ce tableau est bien celui écrit
dans `APP_STORE_LISTING.md`, entre ses deux marqueurs.

La fiche se remplit donc en recopiant un tableau qu'une machine tient à jour, au lieu de
retraduire le manifeste de tête à chaque version. Et le jour où le manifeste gagne une ligne —
comme Crash Data et Performance Data le 8 novembre 2026 — ce contrôle rougit, affiche le tableau
corrigé, et il n'y a qu'à le coller.

Ce qu'il ne fait PAS : vérifier ce qui est RÉELLEMENT saisi chez Apple. Personne ne peut le lire.
Il garantit que la consigne est juste, pas qu'elle a été suivie.

# LE RELEVÉ, PARCE QUE « LA CONSIGNE EST JUSTE » NE SUFFISAIT PAS

Le 8 novembre 2026, la consigne était juste depuis le matin et la fiche d'Apple était fausse
depuis un mois : cinq types manquants, trois catégories déclarées non liées, et une finalité à
côté (Product Interaction porté sur « App Functionality » quand le manifeste dit « Analytics »).
Ce contrôle était VERT tout du long, et il avait raison de l'être : il comparait deux fichiers du
dépôt, et les deux étaient d'accord. Le troisième endroit, celui qui compte, n'était dans aucune
comparaison.

Il ne peut toujours pas lire la fiche. Mais il peut savoir qu'elle est PEUT-ÊTRE en retard : la
fiche porte la date de son dernier relevé à la main, et l'empreinte du tableau qui était vrai ce
jour-là. Le manifeste change, l'empreinte ne correspond plus, le contrôle rougit — non pas pour
dire « la fiche est fausse », qu'il ne sait pas, mais « la fiche a été relevée contre un autre
tableau que celui-ci ». `--releve` la repose, APRÈS la saisie chez Apple et pas avant.

# LES LIBELLÉS VIENNENT D'APPLE, PAS DE MA MÉMOIRE

Les catégories, les types et les finalités ci-dessous sont relevés sur
developer.apple.com/app-store/app-privacy-details/ — seize catégories, six finalités. Un type du
manifeste qui n'y figure pas fait ARRÊTER ce script : il vaut mieux qu'il se taise que
qu'il invente une ligne de formulaire.
"""
import argparse
import datetime
import hashlib
import pathlib
import plistlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
MANIFESTE = RACINE / "RunUp/Resources/PrivacyInfo.xcprivacy"
FICHE = RACINE / "APP_STORE_LISTING.md"

DEBUT = "<!-- confidentialité: début (tableau dérivé du manifeste par check_confidentialite.py) -->"
FIN = "<!-- confidentialité: fin -->"

#: Le relevé à la main de la fiche d'Apple : quand, et contre quel tableau.
RELEVE = re.compile(
    r"<!-- confidentialité: relevé (\d{4}-\d{2}-\d{2}) empreinte=([0-9a-f]{12}) -->")

#: Clé du manifeste → (catégorie du formulaire, libellé du type). Relevé sur la page d'Apple.
TYPES = {
    "NSPrivacyCollectedDataTypeName": ("Contact Info", "Name"),
    "NSPrivacyCollectedDataTypeEmailAddress": ("Contact Info", "Email Address"),
    "NSPrivacyCollectedDataTypeHealth": ("Health & Fitness", "Health"),
    "NSPrivacyCollectedDataTypeFitness": ("Health & Fitness", "Fitness"),
    "NSPrivacyCollectedDataTypePreciseLocation": ("Location", "Precise Location"),
    "NSPrivacyCollectedDataTypeCoarseLocation": ("Location", "Coarse Location"),
    "NSPrivacyCollectedDataTypeContacts": ("Contacts", "Contacts"),
    "NSPrivacyCollectedDataTypePhotosorVideos": ("User Content", "Photos or Videos"),
    "NSPrivacyCollectedDataTypeOtherUserContent": ("User Content", "Other User Content"),
    "NSPrivacyCollectedDataTypeUserID": ("Identifiers", "User ID"),
    "NSPrivacyCollectedDataTypeDeviceID": ("Identifiers", "Device ID"),
    "NSPrivacyCollectedDataTypeProductInteraction": ("Usage Data", "Product Interaction"),
    "NSPrivacyCollectedDataTypeCrashData": ("Diagnostics", "Crash Data"),
    "NSPrivacyCollectedDataTypePerformanceData": ("Diagnostics", "Performance Data"),
    "NSPrivacyCollectedDataTypeOtherDiagnosticData": ("Diagnostics", "Other Diagnostic Data"),
}

#: Finalité du manifeste → libellé du formulaire. Six, et pas une de plus.
FINALITES = {
    "NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising": "Third-Party Advertising",
    "NSPrivacyCollectedDataTypePurposeDeveloperAdvertising": "Developer's Advertising or Marketing",
    "NSPrivacyCollectedDataTypePurposeAnalytics": "Analytics",
    "NSPrivacyCollectedDataTypePurposeProductPersonalization": "Product Personalization",
    "NSPrivacyCollectedDataTypePurposeAppFunctionality": "App Functionality",
    "NSPrivacyCollectedDataTypePurposeOther": "Other Purposes",
}

#: L'ordre des catégories dans le formulaire d'Apple. Saisir dans cet ordre évite de chercher.
ORDRE = ["Contact Info", "Health & Fitness", "Financial Info", "Location", "Sensitive Info",
         "Contacts", "User Content", "Browsing History", "Search History", "Identifiers",
         "Purchases", "Usage Data", "Diagnostics", "Surroundings", "Body", "Other Data"]


def lignes_attendues():
    """Le tableau à saisir, dérivé du manifeste."""
    plist = plistlib.loads(MANIFESTE.read_bytes())
    collectees = plist.get("NSPrivacyCollectedDataTypes")
    if not collectees:
        raise SystemExit(f"{MANIFESTE.name} ne déclare aucune donnée collectée — "
                         "l'analyse a échoué, pas le code.")

    lignes = []
    for entree in collectees:
        clef = entree["NSPrivacyCollectedDataType"]
        if clef not in TYPES:
            raise SystemExit(
                f"« {clef} » n'est pas dans la table de ce script.\n"
                "Ajoute sa catégorie et son libellé d'après "
                "developer.apple.com/app-store/app-privacy-details/ — on ne devine pas une "
                "ligne de formulaire que quelqu'un va recopier chez Apple.")
        categorie, libelle = TYPES[clef]
        finalites = []
        for p in entree.get("NSPrivacyCollectedDataTypePurposes", []):
            if p not in FINALITES:
                raise SystemExit(f"« {p} » n'est pas une finalité connue de ce script.")
            finalites.append(FINALITES[p])
        lignes.append({
            "categorie": categorie,
            "libelle": libelle,
            "lie": "Oui" if entree.get("NSPrivacyCollectedDataTypeLinked") else "Non",
            "suivi": "Oui" if entree.get("NSPrivacyCollectedDataTypeTracking") else "Non",
            "finalites": ", ".join(finalites) or "—",
        })
    lignes.sort(key=lambda l: (ORDRE.index(l["categorie"]), l["libelle"]))
    return lignes


def tableau(lignes) -> str:
    out = ["| Catégorie | Type de donnée | Lié à l'utilisatrice | Suivi | Finalités |",
           "| --- | --- | --- | --- | --- |"]
    for l in lignes:
        out.append(f"| {l['categorie']} | **{l['libelle']}** | {l['lie']} | {l['suivi']} "
                   f"| {l['finalites']} |")
    return "\n".join(out)


def bloc_de_la_fiche() -> str:
    texte = FICHE.read_text(encoding="utf-8")
    if DEBUT not in texte or FIN not in texte:
        raise SystemExit(
            f"Les marqueurs du tableau sont absents de {FICHE.name}.\n"
            f"Pose-les autour du tableau :\n  {DEBUT}\n  …\n  {FIN}")
    return texte.split(DEBUT, 1)[1].split(FIN, 1)[0].strip()


def empreinte(tableau_texte: str) -> str:
    """L'identité du tableau, en douze caractères. Il change, elle change."""
    return hashlib.sha256(tableau_texte.encode("utf-8")).hexdigest()[:12]


def releve_de_la_fiche():
    """(date, empreinte) du dernier relevé à la main, ou None si la fiche n'en porte pas."""
    trouve = RELEVE.search(FICHE.read_text(encoding="utf-8"))
    return (trouve.group(1), trouve.group(2)) if trouve else None


def poser_le_releve(attendu: str, aujourdhui: str) -> None:
    """Écrit — ou remplace — la ligne de relevé juste après la fin du tableau."""
    texte = FICHE.read_text(encoding="utf-8")
    ligne = f"<!-- confidentialité: relevé {aujourdhui} empreinte={empreinte(attendu)} -->"
    if RELEVE.search(texte):
        texte = RELEVE.sub(lambda _: ligne, texte, count=1)
    else:
        texte = texte.replace(FIN, f"{FIN}\n{ligne}", 1)
    FICHE.write_text(texte, encoding="utf-8")


def main() -> int:
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("--ecrire", action="store_true",
                         help="réécrire le tableau dans la fiche au lieu de refuser")
    options.add_argument("--releve", action="store_true",
                         help="dater le relevé de la fiche d'Apple — APRÈS l'avoir saisie")
    args = options.parse_args()

    attendu = tableau(lignes_attendues())
    trouve = bloc_de_la_fiche()

    if args.releve:
        if trouve != attendu:
            print("Le tableau de la fiche ne correspond pas encore au manifeste :")
            print("dater le relevé maintenant daterait le mauvais tableau.")
            print("    `python3 ci_scripts/check_confidentialite.py --ecrire` d'abord.")
            return 1
        aujourdhui = datetime.date.today().isoformat()
        poser_le_releve(attendu, aujourdhui)
        print(f"Fiche App Store Connect relevée le {aujourdhui}, "
              f"empreinte {empreinte(attendu)}.")
        return 0

    if trouve == attendu:
        n = len(attendu.splitlines()) - 2
        releve = releve_de_la_fiche()
        if releve is None:
            print(f"{FICHE.name} ne dit pas quand la fiche d'Apple a été relevée.\n")
            print("Le manifeste et la consigne sont d'accord — mais rien ici ne dit que la fiche")
            print("d'App Store Connect a jamais été mise en face. Va la lire, corrige-la s'il le")
            print("faut, puis :")
            print("    `python3 ci_scripts/check_confidentialite.py --releve`")
            return 1
        date, vue = releve
        if vue != empreinte(attendu):
            print(f"La fiche d'Apple a été relevée le {date}, contre un AUTRE tableau "
                  f"que celui-ci.\n")
            print(f"    relevé ce jour-là : {vue}")
            print(f"    tableau d'aujourd'hui : {empreinte(attendu)}\n")
            print("Le manifeste a bougé depuis. Ce contrôle ne sait pas lire la fiche d'Apple —")
            print("il sait seulement qu'elle n'a pas été revue depuis ce changement. Voici ce")
            print("qu'elle doit dire :\n")
            print(attendu)
            print("\nUne fois saisi dans App Store Connect → Confidentialité de l'app :")
            print("    `python3 ci_scripts/check_confidentialite.py --releve`")
            return 1
        print(f"Confidentialité : {n} types de données, la fiche et le manifeste sont d'accord "
              f"(fiche Apple relevée le {date}).")
        return 0

    if args.ecrire:
        texte = FICHE.read_text(encoding="utf-8")
        avant, reste = texte.split(DEBUT, 1)
        _, apres = reste.split(FIN, 1)
        FICHE.write_text(f"{avant}{DEBUT}\n\n{attendu}\n\n{FIN}{apres}", encoding="utf-8")
        print(f"Tableau réécrit dans {FICHE.name}.")
        print("Le relevé de la fiche d'Apple est maintenant périmé : saisis-la, puis `--releve`.")
        return 0

    print(f"Le tableau de {FICHE.name} ne correspond plus au manifeste.\n")
    print("Voici celui qu'il faut — c'est aussi ce qu'il faut saisir chez Apple :\n")
    print(attendu)
    print("\n    `python3 ci_scripts/check_confidentialite.py --ecrire` le pose pour toi.")
    print("    Et il faut le reporter dans App Store Connect → Confidentialité de l'app :")
    print("    l'API d'Apple ne sait pas l'écrire, c'est à la main ou rien.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
