#!/usr/bin/env python3
"""Le compteur d'usage du Club ne doit compter que des gestes délibérés.

# POURQUOI CE CONTRÔLE EXISTE

`club_action_taken` existe pour répondre à une seule question, celle sur laquelle l'audit a buté :
le Club pèse seize pour cent de l'app, et sa valeur dépend du nombre de gens dedans — y en a-t-il ?
Deux événements mesuraient l'entrée, aucun l'usage.

La mesure a un point de rupture, et il est silencieux. `postClubActivity` part TOUT SEUL après
chaque course validée et à chaque triplé d'objectifs du jour. Le jour où quelqu'un ajoute
`compte(…)` dans `postActivity` « pour être complet », le compteur cesse de mesurer le Club et
mesure l'app : il monte dès que des gens courent, le Club paraît florissant, et la décision qu'on
voulait prendre sur des chiffres se reprend sur une illusion. Rien ne le signalerait — le nombre
monterait, ce qui ressemble exactement à une bonne nouvelle.

Même règle pour l'autre bord : les suppressions et les gestes de sécurité. Un club qu'on quitte,
une sortie qu'on annule, quelqu'un qu'on bloque ou signale — compter ça ferait paraître vivant un
club dont on s'enfuit.

Ce script lit `ClubService.swift`, découpe ses méthodes, et vérifie les deux listes : celles qui
DOIVENT compter, celles qui ne doivent JAMAIS. Il vérifie aussi que chaque geste déclaré sert
exactement une fois — un `Geste` jamais utilisé est une mesure qu'on croit avoir.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
FICHIER = RACINE / "RunUp/Services/ClubService.swift"

DOIVENT_COMPTER = {
    "createChallenge": "defi",
    "createEvent": "sortie",
    "toggleEventRsvp": "jySerai",
    "toggleKudos": "kudos",
    "postComment": "commentaire",
    "publishRoute": "itineraireRendu",
    "setRouteSaved": "itineraireGarde",
    "followUser": "abonnement",
}

# Celles dont le silence est le sens même de la mesure.
NE_DOIVENT_JAMAIS = [
    # La publication automatique : après chaque course, après chaque triplé d'objectifs.
    "postActivity",
    # Les retraits et les annulations.
    "deleteActivity", "deleteEvent", "leaveClub", "unfollowUser", "removeFollower",
    "updateActivity",
    # Les gestes de sécurité.
    "report", "blockUser", "unblockUser",
    # Les lectures : `screen_viewed` dit déjà qu'on est passée, et une lecture n'est pas un geste.
    "fetchBoard", "fetchGlobalWeekly", "fetchFeed", "fetchComments", "fetchRoutesNearby",
    "fetchRoute", "fetchMyRoutes", "fetchFriendsList", "fetchFriendsFeed", "searchUsers",
    "matchContacts",
]


def methodes(src):
    """{nom: corps} — découpé sur les `func`, à l'indentation d'une méthode."""
    debuts = [(m.start(), m.group(1)) for m in re.finditer(r'\n    (?:@discardableResult\n    )?(?:private )?func (\w+)', src)]
    out = {}
    for i, (pos, nom) in enumerate(debuts):
        fin = debuts[i + 1][0] if i + 1 < len(debuts) else len(src)
        out[nom] = src[pos:fin]
    return out


def main():
    src = FICHIER.read_text()
    corps = methodes(src)
    fautes = []

    declares = set(re.findall(r'\n        case (\w+)', src.split("private enum Geste")[1].split("}")[0])) \
        if "private enum Geste" in src else set()

    for nom, geste in DOIVENT_COMPTER.items():
        if nom not in corps:
            fautes.append(f"{nom} a disparu de ClubService — la liste de ce script est à revoir.")
            continue
        if f"compte(.{geste})" not in corps[nom]:
            fautes.append(f"{nom} ne compte plus `.{geste}` : un geste délibéré du Club "
                          f"a cessé d'être mesuré, sans que rien ne baisse visiblement.")

    for nom in NE_DOIVENT_JAMAIS:
        if nom in corps and "compte(" in corps[nom]:
            fautes.append(f"{nom} compte un geste, et ne doit pas. Voir l'en-tête de ce script : "
                          f"la mesure cesse alors de décrire le Club.")

    for geste in sorted(declares):
        utilisations = src.count(f"compte(.{geste})")
        if utilisations != 1:
            fautes.append(f"`Geste.{geste}` est utilisé {utilisations} fois au lieu d'une.")

    if fautes:
        print("Compteur d'usage du Club :\n")
        for f in fautes:
            print(f"  · {f}")
        return 1
    print(f"Club : {len(DOIVENT_COMPTER)} gestes délibérés comptés, "
          f"{len([n for n in NE_DOIVENT_JAMAIS if n in corps])} méthodes vérifiées muettes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
