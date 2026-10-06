#!/usr/bin/env python3
"""Le client et le serveur doivent connaître les mêmes événements.

# POURQUOI CE CONTRÔLE EXISTE

`Analytics.EventName` côté Swift et `KNOWN_EVENTS` côté `api/events.js` sont la même liste, écrite
deux fois, dans deux langages, dans deux déploiements séparés. Rien ne les tenait ensemble — et
quand elles ont divergé, la panne a été parfaitement silencieuse des deux côtés :

  · le client envoie son événement et reçoit un `200 OK` ;
  · le serveur le compte dans un champ `rejected` que personne ne lit ;
  · la table n'en garde aucune trace, donc la requête du tableau de bord rend zéro — ce qui
    ressemble exactement à « cette fonctionnalité n'est pas utilisée ».

Au moment où ce script est écrit, ONZE des vingt-quatre événements du client étaient jetés, dont
l'entonnoir d'abonnement en entier : huit événements ajoutés précisément pour distinguer « personne
n'atteint le mur de paiement », « on le voit et on repart » et « l'achat casse ». Trois maladies,
trois remèdes opposés, et des mois de données perdues sans que rien ne clignote.

C'est la forme la plus coûteuse de la duplication : pas une divergence de valeur qu'on finit par
voir à l'écran, mais une absence de données qu'on prend pour une réponse.

# LES DEUX SENS COMPTENT

Un nom chez le client absent du serveur, c'est une mesure perdue. Un nom chez le serveur absent du
client, c'est au mieux du code mort, au pire une requête de tableau de bord qui compte un
événement que plus rien n'émet — et qui rend zéro pour une raison qui n'a rien à voir avec les
gens.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
SWIFT = RACINE / "RunUp/Services/Analytics.swift"
JS = RACINE / "api/events.js"


def noms_du_client():
    src = SWIFT.read_text()
    marqueur = "enum EventName"
    if marqueur not in src:
        raise SystemExit(f"`{marqueur}` introuvable dans {SWIFT.name} — ce script est à revoir.")
    # Jusqu'à la fermeture de l'énumération, à son indentation.
    bloc = src.split(marqueur, 1)[1].split("\n    }", 1)[0]
    return set(re.findall(r'case \w+ = "([a-z_]+)"', bloc))


def noms_du_serveur():
    src = JS.read_text()
    marqueur = "KNOWN_EVENTS = new Set(["
    if marqueur not in src:
        raise SystemExit(f"`KNOWN_EVENTS` introuvable dans {JS.name} — ce script est à revoir.")
    bloc = src.split(marqueur, 1)[1].split("]);", 1)[0]
    # Les commentaires de ce bloc citent des noms d'événements entre guillemets simples dans des
    # phrases : on ne garde que les lignes qui sont vraiment des entrées de la liste.
    noms = set()
    for ligne in bloc.splitlines():
        nue = ligne.strip()
        if nue.startswith("//"):
            continue
        trouve = re.fullmatch(r"'([a-z_]+)',?", nue)
        if trouve:
            noms.add(trouve.group(1))
    return noms


def main():
    client = noms_du_client()
    serveur = noms_du_serveur()
    if not client or not serveur:
        print("Une des deux listes est vide — l'analyse a échoué, pas le code.")
        return 1

    perdus = sorted(client - serveur)
    orphelins = sorted(serveur - client)
    if perdus or orphelins:
        print("Les événements du client et du serveur ne concordent pas :\n")
        for nom in perdus:
            print(f"  · « {nom} » est envoyé par l'app et JETÉ par le serveur.")
            print(f"    Rien ne le signale : l'app reçoit un 200. Ajoute-le à `KNOWN_EVENTS`")
            print(f"    dans api/events.js, sans quoi la mesure rendra zéro comme si la")
            print(f"    fonctionnalité n'était pas utilisée.")
        for nom in orphelins:
            print(f"  · « {nom} » est accepté par le serveur mais plus émis par l'app.")
            print(f"    Une requête de tableau de bord dessus rendra zéro pour une raison qui")
            print(f"    n'a rien à voir avec les gens. Retire-le, ou remets son `case`.")
        return 1

    print(f"Analytique : {len(client)} événements, le client et le serveur sont d'accord.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
