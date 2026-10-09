#!/usr/bin/env python3
"""Ce que `check_captures_seed.py` doit attraper, et ce qu'il ne doit pas inventer.

Les cas sont des extraits FIGÉS. Le premier est le JSON tel qu'il était vraiment le jour du
défaut — relire le dépôt rendrait ce test vert aujourd'hui et rouge dès la correction.
"""

import json
import sys

import check_captures_seed as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f)); return f
    return prendre


OBLIGATOIRES_LIGNE = {"id", "name", "xp", "rank", "isMe", "joinedAt", "activitiesCount",
                      "badgeKeys"}
OBLIGATOIRES_CLUB = {"id", "name", "inviteCode", "memberCount"}
BADGES = {"firstRun", "tenRuns", "streak7", "distance50"}

# Le tableau tel qu'il était le jour où l'écran du Club a montré « Créer un club ».
AVANT = {
    "club": {"id": "demo", "name": "Les Foulées du Canal", "inviteCode": "CANAL",
             "memberCount": 18},
    "leaderboard": [
        {"id": "1", "name": "Charlotte", "xp": 4180, "rank": 1, "isMe": True,
         "bio": "Objectif 10 km sous 47:30"},
        {"id": "2", "name": "Inès", "xp": 3940, "rank": 2, "isMe": False},
    ],
}

APRES = {
    "club": {"id": "demo", "name": "Les Foulées du Canal", "inviteCode": "CANAL",
             "memberCount": 18},
    "leaderboard": [
        {"id": "1", "name": "Charlotte", "xp": 4180, "rank": 1, "isMe": True,
         "bio": "Objectif 10 km sous 47:30", "joinedAt": "2026-01-01T00:00:00Z",
         "activitiesCount": 16, "badgeKeys": ["firstRun", "tenRuns"]},
    ],
}


@cas_test("le JSON d'avant est refusé, et les trois champs sont nommés")
def _():
    fautes = ck.manques(AVANT, OBLIGATOIRES_CLUB, OBLIGATOIRES_LIGNE, BADGES)
    assert len(fautes) == 2, fautes
    texte = " ".join(quoi for _, quoi in fautes)
    for champ in ("joinedAt", "activitiesCount", "badgeKeys"):
        assert champ in texte, f"{champ} non signalé : {texte}"


@cas_test("le JSON complet passe")
def _():
    assert ck.manques(APRES, OBLIGATOIRES_CLUB, OBLIGATOIRES_LIGNE, BADGES) == []


@cas_test("un badge inventé est refusé")
def _():
    faux = {"club": APRES["club"],
            "leaderboard": [dict(APRES["leaderboard"][0], badgeKeys=["firstRun", "licorne"])]}
    fautes = ck.manques(faux, OBLIGATOIRES_CLUB, OBLIGATOIRES_LIGNE, BADGES)
    assert len(fautes) == 1 and "licorne" in fautes[0][1], fautes


@cas_test("un champ FACULTATIF absent ne déclenche rien")
def _():
    # `bio` est `String?` : l'absence est le cas normal, pas une faute.
    sans_bio = {"club": APRES["club"],
                "leaderboard": [{k: v for k, v in APRES["leaderboard"][0].items() if k != "bio"}]}
    assert ck.manques(sans_bio, OBLIGATOIRES_CLUB, OBLIGATOIRES_LIGNE, BADGES) == []


@cas_test("les champs obligatoires sont lus dans le vrai ClubService")
def _():
    service = ck.SERVICE.read_text(encoding="utf-8")
    ligne = ck.champs_obligatoires(service, "LeaderboardRow")
    assert ligne is not None, "LeaderboardRow décode-t-elle à la main maintenant ?"
    assert {"joinedAt", "activitiesCount", "badgeKeys"} <= ligne, ligne
    # `bio`, `avatarUrl`, `avatarBase64` sont optionnels et ne doivent pas y être.
    assert "bio" not in ligne and "avatarUrl" not in ligne, ligne


@cas_test("une structure qui décode à la main est exclue, pas devinée")
def _():
    service = ck.SERVICE.read_text(encoding="utf-8")
    assert ck.champs_obligatoires(service, "FeedItem") is None, \
        "FeedItem décode à la main : ce test n'a pas à lui imposer une liste"


@cas_test("le littéral Swift se lit, interpolations comprises")
def _():
    tableau = ck.litteral(ck.GRAINE.read_text(encoding="utf-8"), "tableau")
    assert tableau["club"]["name"] == "Les Foulées du Canal", tableau["club"]
    assert len(tableau["leaderboard"]) == 5, len(tableau["leaderboard"])
    # L'interpolation `\(ilYAJours(214))` doit avoir été remplacée, pas recopiée.
    assert "\\(" not in json.dumps(tableau), tableau["leaderboard"][0]


@cas_test("le vrai club de démonstration passe")
def _():
    assert ck.main() == 0, "check_captures_seed.py refuse le dépôt"


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f(); print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1; print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
