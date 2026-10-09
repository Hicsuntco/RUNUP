#!/usr/bin/env python3
"""Le club de démonstration doit se décoder — avant de découvrir le contraire sur une image.

POURQUOI CETTE RÈGLE EXISTE.

`CaptureSeed.poserLeClub` pose un club inventé sous forme de JSON, que l'app décode dans
`ClubBoard`. Ce JSON ne portait ni `joinedAt`, ni `activitiesCount`, ni `badgeKeys` — trois
champs NON optionnels de `LeaderboardRow`. Le décodage échouait donc entièrement, le cache
restait nil, et l'écran du Club affichait son formulaire « Créer un club » sous une accroche
qui promet « Tu ne cours jamais seule ».

Rien ne l'a dit. Le `try?` avalait l'erreur, l'app ne plantait pas, le workflow passait au vert,
et il a fallu vingt minutes d'exécution plus une relecture de l'image pour s'en apercevoir. Le
`try?` est devenu un `do/catch` bruyant ; ce test, lui, attrape la même faute en une seconde,
sans démarrer de simulateur.

La règle : chaque ligne du classement de démonstration porte tous les champs non optionnels de
`LeaderboardRow`, et chaque badge qu'elle cite existe dans `ClubBadgeCatalog`.

CE QUE CE TEST NE COUVRE PAS. `FeedItem` décode à la main, en tolérant l'absence de presque
tous ses champs (voir son `init(from:)`) : une liste de champs obligatoires n'y voudrait rien
dire, et l'inventer ici ferait échouer le test sur du JSON parfaitement valide.
"""

import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
SERVICE = RACINE / "RunUp" / "Services" / "ClubService.swift"
GRAINE = RACINE / "RunUp" / "Services" / "CaptureSeed.swift"
CATALOGUE = RACINE / "RunUp" / "Models" / "ClubBadgeCatalog.swift"

CHAMP = re.compile(r"^    var (\w+):\s*([^\n/]+?)\s*$", re.M)


def champs_obligatoires(texte, nom):
    """Les champs d'une structure `Decodable` qu'un JSON DOIT porter.

    Un type optionnel (`String?`) ou une valeur par défaut (`= false`) rend le champ facultatif.
    Une structure qui écrit son propre `init(from:)` est rendue vide : ses règles sont du code,
    pas une liste de types, et ce test n'a pas à les deviner.
    """
    m = re.search(rf"^struct {nom}\b[^\n]*\{{$", texte, re.M)
    if m is None:
        raise SystemExit(f"structure {nom} introuvable dans {SERVICE.name}")
    fin = texte.index("\n}\n", m.end())
    corps = texte[m.end():fin]
    if "init(from decoder" in corps:
        return None
    return {nom_champ for nom_champ, type_ in CHAMP.findall(corps)
            if not type_.endswith("?") and "=" not in type_}


def litteral(texte, variable):
    """Le contenu d'un `let <variable> = \"\"\"…\"\"\"`, prêt à être lu comme du JSON.

    Les interpolations Swift (`\\(ilYAJours(214))`) deviennent une date fixe : ce test juge la
    FORME du JSON — quelles clés sont là — pas les valeurs que Swift y mettra.
    """
    m = re.search(rf'let {variable} = """\n(.*?)\n\s*"""', texte, re.S)
    if m is None:
        raise SystemExit(f"littéral `{variable}` introuvable dans {GRAINE.name}")
    brut = re.sub(r"\\\((?:[^()]|\([^()]*\))*\)", "2026-01-01T00:00:00Z", m.group(1))
    return json.loads(brut)


def badges_connus():
    return set(re.findall(r'Definition\(key: "(\w+)"', CATALOGUE.read_text(encoding="utf-8")))


def manques(tableau, obligatoires_club, obligatoires_ligne, badges):
    """[(où, ce qui manque)] — vide quand le club de démonstration est complet."""
    trouves = []
    if obligatoires_club is not None:
        absents = obligatoires_club - set(tableau.get("club") or {})
        if absents:
            trouves.append(("club", f"champs absents : {', '.join(sorted(absents))}"))
    for i, ligne in enumerate(tableau.get("leaderboard", [])):
        qui = ligne.get("name", f"ligne {i + 1}")
        if obligatoires_ligne is not None:
            absents = obligatoires_ligne - set(ligne)
            if absents:
                trouves.append((qui, f"champs absents : {', '.join(sorted(absents))}"))
        inconnus = set(ligne.get("badgeKeys", [])) - badges
        if inconnus:
            trouves.append((qui, f"badges inconnus : {', '.join(sorted(inconnus))}"))
    return trouves


def main():
    service = SERVICE.read_text(encoding="utf-8")
    tableau = litteral(GRAINE.read_text(encoding="utf-8"), "tableau")
    obligatoires_club = champs_obligatoires(service, "ClubInfo")
    obligatoires_ligne = champs_obligatoires(service, "LeaderboardRow")
    badges = badges_connus()

    if fautes := manques(tableau, obligatoires_club, obligatoires_ligne, badges):
        print("Le club de démonstration ne se décodera pas :\n", file=sys.stderr)
        for qui, quoi in fautes:
            print(f"  {qui} — {quoi}", file=sys.stderr)
        print("\nUn champ non optionnel absent fait échouer le décodage du tableau ENTIER,",
              file=sys.stderr)
        print("donc l'écran du Club montre « Créer un club » dans la capture d'écran.",
              file=sys.stderr)
        print(f"Voir `poserLeClub` dans {GRAINE.name}.", file=sys.stderr)
        return 1

    lignes = len(tableau.get("leaderboard", []))
    print(f"Club de démonstration : {lignes} lignes de classement, tous les champs obligatoires")
    print(f"                        de LeaderboardRow présents, {len(badges)} badges au catalogue.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
