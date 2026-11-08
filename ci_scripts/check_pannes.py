#!/usr/bin/env python3
"""Le client et le serveur doivent connaître les mêmes genres de panne.

# POURQUOI CE CONTRÔLE EXISTE

`Diagnostics.Genre` côté Swift et `KNOWN_KINDS` côté `lib/pannes.js` sont la même liste, écrite
deux fois, dans deux langages, dans deux déploiements séparés. C'est exactement la situation
qu'`Analytics.EventName` et `KNOWN_EVENTS` ont déjà vécue — et dont `check_events.py` raconte
l'issue : ONZE des vingt-quatre événements du client étaient jetés par le serveur, dont
l'entonnoir d'abonnement en entier, pendant des mois, avec un `200 OK` à chaque envoi.

Ici la panne silencieuse coûterait plus cher qu'ailleurs, et c'est tout l'objet de ce fichier.
Un rapport de panne n'arrive que QUAND ÇA VA MAL : il n'y a pas de volume quotidien dont la chute
sauterait aux yeux. Une table de pannes vide ressemble, trait pour trait, à une app qui ne plante
pas. On ne découvrirait le trou qu'en cherchant la cause d'un plantage dont personne ne nous aura
dit qu'il existe.

# LES DEUX SENS COMPTENT

Un genre chez le client absent du serveur, c'est une panne perdue. Un genre chez le serveur absent
du client, c'est au mieux du code mort — au pire une requête qui compte zéro gel et qu'on lit
comme « l'app ne gèle pas ».

# ET UNE TROISIÈME RÈGLE, QUI N'EST PAS DE LA MÊME NATURE

Tant que `Diagnostics.swift` s'abonne à MetricKit, le manifeste de confidentialité DOIT déclarer
`NSPrivacyCollectedDataTypeCrashData` et `NSPrivacyCollectedDataTypePerformanceData`. Ce n'est pas
une symétrie à préserver, c'est une condition d'envoi : une déclaration incomplète est un motif de
rejet à part entière, et App Store Connect refuse le binaire avant toute revue humaine.

Cette règle existe parce que la dérive s'est DÉJÀ produite dans ce dépôt, dans l'autre sens. Le
manifeste affirmait « le tracé GPS n'est jamais transmis — aucune colonne de route n'existe côté
serveur » ; c'était vrai le jour où la phrase a été écrite, et ça a cessé de l'être le jour où
`routes` est apparue. Personne n'est revenu. Son propre en-tête met en garde contre exactement ça,
et ça n'a pas suffi — ce qui est la définition d'un travail de machine.
"""
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
SWIFT = RACINE / "RunUp/Services/Diagnostics.swift"
JS = RACINE / "lib/pannes.js"
MANIFESTE = RACINE / "RunUp/Resources/PrivacyInfo.xcprivacy"

#: Ce que le manifeste doit déclarer tant que le service existe, et ce que chaque entrée couvre.
DECLARATIONS = {
    "NSPrivacyCollectedDataTypeCrashData": "les plantages",
    "NSPrivacyCollectedDataTypePerformanceData":
        "les gels, dépassements de processeur, écritures disque et lancements lents",
}


def genres_du_client():
    src = SWIFT.read_text(encoding="utf-8")
    marqueur = "enum Genre"
    if marqueur not in src:
        raise SystemExit(f"`{marqueur}` introuvable dans {SWIFT.name} — ce script est à revoir.")
    # Jusqu'à la fermeture de l'énumération, à son indentation.
    bloc = src.split(marqueur, 1)[1].split("\n    }", 1)[0]
    return set(re.findall(r'case \w+ = "([a-z_]+)"', bloc))


def genres_du_serveur():
    src = JS.read_text(encoding="utf-8")
    marqueur = "KNOWN_KINDS = new Set(["
    if marqueur not in src:
        raise SystemExit(f"`KNOWN_KINDS` introuvable dans {JS.name} — ce script est à revoir.")
    bloc = src.split(marqueur, 1)[1].split("]);", 1)[0]
    # Les commentaires de ce bloc citent des genres entre guillemets simples dans des phrases : on
    # ne garde que les lignes qui sont vraiment des entrées de la liste. Même piège, même parade
    # que dans `check_events.py`.
    genres = set()
    for ligne in bloc.splitlines():
        nue = ligne.strip()
        if nue.startswith("//"):
            continue
        trouve = re.fullmatch(r"'([a-z_]+)',?", nue)
        if trouve:
            genres.add(trouve.group(1))
    return genres


def manifeste_incomplet():
    """Rend la liste des déclarations manquantes, ou une liste vide."""
    if not SWIFT.exists():
        # Le service a disparu : plus rien à déclarer, et ce n'est pas à ce contrôle de le dire.
        return []
    source = SWIFT.read_text(encoding="utf-8")
    if "MXMetricManager.shared.add" not in source:
        # Plus abonné à MetricKit : plus de rapport de panne envoyé, donc plus d'obligation.
        return []
    manifeste = MANIFESTE.read_text(encoding="utf-8")
    return [clef for clef in DECLARATIONS if clef not in manifeste]


def main():
    client = genres_du_client()
    serveur = genres_du_serveur()
    if not client or not serveur:
        print("Une des deux listes est vide — l'analyse a échoué, pas le code.")
        return 1

    perdus = sorted(client - serveur)
    orphelins = sorted(serveur - client)
    if perdus or orphelins:
        print("Les genres de panne du client et du serveur ne concordent pas :\n")
        for genre in perdus:
            print(f"  · « {genre} » est envoyé par l'app et JETÉ par le serveur.")
            print("    Rien ne le signale : l'app reçoit un 200. Ajoute-le à `KNOWN_KINDS`")
            print("    dans lib/pannes.js, sans quoi cette panne-là n'existera nulle part —")
            print("    et une table de pannes vide ressemble à une app qui ne plante pas.")
        for genre in orphelins:
            print(f"  · « {genre} » est accepté par le serveur mais plus émis par l'app.")
            print("    Une requête dessus rendra zéro pour une raison qui n'a rien à voir avec")
            print("    la solidité de l'app. Retire-le, ou remets son `case`.")
        return 1

    manquantes = manifeste_incomplet()
    if manquantes:
        print("Le manifeste de confidentialité ne déclare pas ce que l'app envoie :\n")
        for clef in manquantes:
            print(f"  · « {clef} » manque dans {MANIFESTE.name}.")
            print(f"    Elle couvre {DECLARATIONS[clef]}.")
        print("\n    Une déclaration incomplète est un motif de rejet à part entière : App Store")
        print("    Connect refuse le binaire à l'ENVOI, avant toute revue humaine. Et la fiche")
        print("    App Store Connect doit dire la même chose que le manifeste.")
        return 1

    print(f"Pannes : {len(client)} genres, le client et le serveur sont d'accord,")
    print(f"         et le manifeste déclare les {len(DECLARATIONS)} familles de diagnostics.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
