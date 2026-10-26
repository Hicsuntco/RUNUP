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

`FeedItem`, lui, décode à la main : la liste de ses champs ne dit rien de ce qu'il exige. On lit
donc son `init(from:)` — les clés prises par un `decode` strict sont obligatoires, celles prises
par `decodeIfPresent` ne le sont pas — et on contrôle à part la forme du tracé, qui voyage en
paires `[lat, lng]` et NON en objets. Écrit en objets, il faisait tomber le fil entier sur une
erreur de type ; c'est la deuxième faute de ce JSON que la machine a attrapée à ma place.
"""

import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
SERVICE = RACINE / "RunUp" / "Services" / "ClubService.swift"
# Les types des pages de course vivent dans leur propre fichier. Les deux sources sont lues et
# concaténées : `champs_obligatoires` cherche une structure par son nom, peu importe d'où elle
# vient.
MODELE_COURSE = RACINE / "RunUp" / "Models" / "RaceEvent.swift"
MODELE_PROFIL = RACINE / "RunUp" / "Models" / "PublicProfile.swift"
GRAINE = RACINE / "RunUp" / "Services" / "CaptureSeed.swift"
CATALOGUE = RACINE / "RunUp" / "Models" / "ClubBadgeCatalog.swift"

CHAMP = re.compile(r"^    var (\w+):\s*([^\n/]+?)\s*$", re.M)
# `try c.decode(String.self, forKey: .id)` — strict. `decodeIfPresent` ne compte pas.
STRICT = re.compile(r"c\.decode\([^)]*forKey:\s*\.(\w+)\)")


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
            # UNE PROPRIÉTÉ CALCULÉE N'EST PAS UN CHAMP À DÉCODER. `var jour: Date? { … }` ou
            # `var nomComplet: String {` ouvrent un bloc : leur « type » contient une accolade, et
            # aucune ne vient du JSON. Sans ce filtre, le contrôle réclamait `sousTitre`,
            # `joursRestants` et `disciplineSymbole` dans un littéral de démonstration — cinq faux
            # manques sur un type qui n'en avait aucun.
            if "{" not in type_ and not type_.endswith("?") and "=" not in type_}


def champs_stricts(texte, nom):
    """Les clés qu'un `init(from:)` écrit à la main décode SANS tolérance.

    La liste des propriétés ne sert à rien ici : `isPersonalRecord` n'est pas optionnel et
    pourtant son absence est tolérée, `kudosNames` non plus et pourtant elle retombe sur `[]`.
    Seul le corps du décodeur dit la vérité.
    """
    m = re.search(rf"^struct {nom}\b[^\n]*\{{$", texte, re.M)
    if m is None:
        raise SystemExit(f"structure {nom} introuvable dans {SERVICE.name}")
    fin = texte.index("\n}\n", m.end())
    debut = texte.index("init(from decoder", m.end())
    return set(STRICT.findall(texte[debut:fin]))


def manques_du_fil(fil, stricts):
    """[(où, ce qui manque)] pour les activités de démonstration."""
    trouves = []
    for i, item in enumerate(fil):
        qui = item.get("name", f"activité {i + 1}")
        absents = stricts - set(item)
        if absents:
            trouves.append((qui, f"champs absents : {', '.join(sorted(absents))}"))
        trace = item.get("routePreview")
        if trace is None:
            continue
        # `FeedItem.init(from:)` décode un `[[Double]]`, et un objet y lève une erreur de TYPE
        # — qui fait tomber le fil entier, pas seulement le tracé.
        if not all(isinstance(p, list) and len(p) == 2
                   and all(isinstance(c, (int, float)) for c in p) for p in trace):
            trouves.append((qui, "le tracé doit être des paires [lat, lng], pas des objets"))
        elif len(trace) < 2:
            # En dessous de deux points, `init(from:)` le jette en silence : pas une erreur,
            # mais un tracé écrit pour rien, et une carte vide là où on en attendait une.
            trouves.append((qui, f"tracé de {len(trace)} point — il en faut au moins deux"))
    return trouves


def litteral(texte, variable):
    """Le contenu d'un `let <variable> = \"\"\"…\"\"\"`, prêt à être lu comme du JSON.

    Les interpolations Swift (`\\(ilYAJours(214))`) deviennent une date fixe : ce test juge la
    FORME du JSON — quelles clés sont là — pas les valeurs que Swift y mettra.
    """
    m = re.search(rf'let {variable} = """\n(.*?)\n\s*"""', texte, re.S)
    if m is None:
        raise SystemExit(f"littéral `{variable}` introuvable dans {GRAINE.name}")
    return json.loads(sans_interpolations(m.group(1)))


def sans_interpolations(brut):
    """Les `\\(…)` de Swift remplacés par une date fixe, À N'IMPORTE QUELLE PROFONDEUR.

    C'était une expression régulière qui n'acceptait qu'UN niveau de parenthèses imbriquées. Elle
    a tenu tant que les interpolations ressemblaient à `\\(ilYAJours(214))`. La première qui en a
    porté deux —
    `\\(formateur.string(from: maintenant.addingTimeInterval(86_400 * 162)).prefix(10))` — n'a pas
    été remplacée, le `\\(` est resté dans le texte, et `json.loads` s'est arrêté sur « Invalid
    \\escape » en désignant une colonne qui ne veut rien dire pour qui lit du Swift.

    Un compteur de parenthèses n'a pas de profondeur maximale. C'est trois lignes de plus et une
    classe entière de faux diagnostics en moins.
    """
    sortie, i, n = [], 0, len(brut)
    while i < n:
        if brut[i] == "\\" and i + 1 < n and brut[i + 1] == "(":
            profondeur, i = 1, i + 2
            while i < n and profondeur:
                if brut[i] == "(":
                    profondeur += 1
                elif brut[i] == ")":
                    profondeur -= 1
                i += 1
            sortie.append("2026-01-01T00:00:00Z")
            continue
        sortie.append(brut[i])
        i += 1
    return "".join(sortie)


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


# CE QUE CHAQUE JEU DE DÉMONSTRATION DOIT POUVOIR DEVENIR.
#
# `poserLeClub` décode six littéraux JSON, et un seul champ non optionnel manquant fait échouer le
# décodage — ce qui déclenche son `preconditionFailure` et fait PLANTER l'app au lancement sous le
# drapeau des captures. Ce n'est pas une hypothèse : `WallRacePost` a gagné `kudos` et
# `kudoedByMe` le jour où le mur d'une course a pu recevoir des applaudissements, le littéral `mur`
# ne les a pas gagnés, et les dix captures ont planté. Le contrôle ne couvrait alors que deux des
# six littéraux.
#
# Chaque entrée dit : le littéral, le type qu'il doit devenir, et — pour les objets imbriqués — le
# chemin et le type de chacun. Un `[]` dans un chemin veut dire « chaque élément du tableau ».
JEUX = [
    ("amis", "FriendsList", [
        (["following", []], "PublicUser"),
        (["followers", []], "PublicUser"),
        (["incomingRequests", []], "PublicUser"),
    ]),
    ("course", "RaceEvent", []),
    ("murBrut", "WallPage", [
        (["racePosts", []], "WallRacePost"),
        (["racePosts", [], "author"], "PublicUser"),
    ]),
    ("profil", "PublicProfilePage", [
        (["profile"], "PublicProfile"),
    ]),
    ("pageDeCourse", "RacePage", [
        (["race"], "RaceEvent"),
        (["me"], "RaceFollow"),
        (["runners", []], "RaceRunner"),
        (["posts", []], "RacePost"),
        (["posts", [], "author"], "PublicUser"),
    ]),
    ("sortie", "ActivityDetail", []),
]


def manques_de_la_sortie(graine):
    """Ce qu'aucune liste de champs obligatoires ne peut attraper sur la sortie déroulée.

    `ActivityDetail` écrit son propre `init(from:)`, donc le contrôle ci-dessus ne lui réclame
    rien : ses règles sont du code. Or deux d'entre elles ne plantent jamais quand on les enfreint,
    elles se contentent de MENTIR en image :

      • un profil d'altitudes d'une autre longueur que le tracé est abandonné en silence par le
        décodeur — la page sort sans profil, et on croit que la fonctionnalité ne marche pas ;
      • un D+ annoncé qui ne correspond pas à la somme des montées du profil donne une capture où
        « 86 m » surplombe une colline de trente. Rien ne tombe, et c'est faux.

    Les deux sont exactement ce que ces images servent à attraper, donc autant les attraper ici.
    """
    fautes = []
    sortie = litteral(graine, "sortie")
    points = sortie.get("routePreview") or []
    altitudes = sortie.get("routeAltitudes") or []
    if altitudes and len(altitudes) != len(points):
        fautes.append(("sortie → routeAltitudes",
                       f"{len(altitudes)} altitudes pour {len(points)} points — "
                       "le décodeur les abandonnera, et la page sortira sans profil"))
    annonce = sortie.get("elevationGainM")
    if altitudes and isinstance(annonce, (int, float)):
        montee = sum(max(0, b - a) for a, b in zip(altitudes, altitudes[1:])
                     if a is not None and b is not None)
        # Dix mètres de marge : le profil est échantillonné, pas la course entière.
        if abs(montee - annonce) > 10:
            fautes.append(("sortie → elevationGainM",
                           f"{annonce} m annoncés, {montee:.0f} m de montée dans le profil"))
    splits = sortie.get("splits") or []
    distance = sortie.get("distanceKm")
    if splits and isinstance(distance, (int, float)) and abs(len(splits) - distance) > 1.5:
        fautes.append(("sortie → splits",
                       f"{len(splits)} splits pour {distance} km — un split vaut un kilomètre"))
    return fautes


def aux_chemins(valeur, chemin):
    """Toutes les valeurs atteintes par `chemin`. `[]` traverse un tableau."""
    courant = [valeur]
    for pas in chemin:
        suivant = []
        for v in courant:
            if pas == []:
                if isinstance(v, list):
                    suivant.extend(v)
            elif isinstance(v, dict) and pas in v:
                suivant.append(v[pas])
        courant = suivant
    return courant


def manques_des_jeux(graine, sources):
    fautes = []
    for variable, type_racine, imbriques in JEUX:
        valeur = litteral(graine, variable)
        for chemin, nom_type in [([], type_racine)] + imbriques:
            obligatoires = champs_obligatoires(sources, nom_type)
            if obligatoires is None:
                continue
            for objet in aux_chemins(valeur, chemin):
                if not isinstance(objet, dict):
                    continue
                absents = sorted(obligatoires - set(objet))
                if absents:
                    ou = "/".join("[]" if p == [] else str(p) for p in chemin) or "(racine)"
                    fautes.append((f"{variable} → {ou} ({nom_type})",
                                   "champ(s) absent(s) : " + ", ".join(absents)))
    return fautes


def main():
    service = SERVICE.read_text(encoding="utf-8")
    graine = GRAINE.read_text(encoding="utf-8")
    tableau = litteral(graine, "tableau")
    fil = litteral(graine, "fil")
    obligatoires_club = champs_obligatoires(service, "ClubInfo")
    obligatoires_ligne = champs_obligatoires(service, "LeaderboardRow")
    badges = badges_connus()

    sources = "\n".join([
        service,
        MODELE_COURSE.read_text(encoding="utf-8"),
        MODELE_PROFIL.read_text(encoding="utf-8"),
    ])

    fautes = manques(tableau, obligatoires_club, obligatoires_ligne, badges)
    fautes += manques_du_fil(fil, champs_stricts(service, "FeedItem"))
    fautes += manques_des_jeux(graine, sources)
    fautes += manques_de_la_sortie(graine)
    if fautes:
        print("Le club de démonstration ne se décodera pas :\n", file=sys.stderr)
        for qui, quoi in fautes:
            print(f"  {qui} — {quoi}", file=sys.stderr)
        print("\nUn champ non optionnel absent fait échouer le décodage ENTIER, donc le",
              file=sys.stderr)
        print("`preconditionFailure` de `poserLeClub` — l'app PLANTE au lancement sous le",
              file=sys.stderr)
        print("drapeau des captures, et aucune image ne sort.", file=sys.stderr)
        print(f"Voir `poserLeClub` dans {GRAINE.name}.", file=sys.stderr)
        return 1

    lignes = len(tableau.get("leaderboard", []))
    traces = sum(1 for a in fil if a.get("routePreview"))
    print(f"Club de démonstration : {lignes} lignes de classement, tous les champs obligatoires")
    print(f"                        de LeaderboardRow présents, {len(badges)} badges au catalogue.")
    print(f"                        {len(fil)} activités au fil, dont {traces} avec un tracé en paires.")
    sortie = litteral(graine, "sortie")
    print(f"                        {len(JEUX) + 2} jeux de démonstration, tous décodables.")
    print(f"                        Sortie déroulée : {len(sortie.get('splits') or [])} splits, "
          f"{len(sortie.get('routeAltitudes') or [])} altitudes d'accord avec le tracé et le D+.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
