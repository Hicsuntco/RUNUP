#!/usr/bin/env python3
"""Ce que `check_entrees.py` doit voir, et ce qu'il ne doit pas inventer.

Les deux premiers cas sont les DÉFAUTS RÉELS, recopiés tels qu'ils étaient dans le dépôt. Un
garde qui ne les rattrape pas ne sert à rien, et c'est la seule façon de le savoir : les écrire
ici figés, plutôt que de relire le dépôt — un test qui relit le dépôt passe tant que la faute y
est et échoue à la seconde où elle est corrigée.
"""

import sys

import check_entrees as ck

MOTEUR = ck.MOTEUR
RESTAURATION = ck.RESTAURATION
AILLEURS = "RunUp/AppState.swift"

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


# ── Les deux défauts réels ───────────────────────────────────────────────────────────────────

@cas_test("l'allègement du jour réécrivant la séance est signalé")
def _():
    # Tel qu'il était dans `applySameDayAdjustmentIfNeeded`.
    source = """
        session.adjustment = reason
        profile.weekSessions[idx].session = session
        profile.todaySession = session
"""
    trouves = ck.ecarts_dans(MOTEUR, source)
    assert len(trouves) == 1, trouves
    assert trouves[0][1].endswith("weekSessions[idx].session"), trouves


@cas_test("le déplacement écrit à la main dans la semaine est signalé")
def _():
    # Tel qu'il était dans `AppState.moveSession`.
    source = """
        guard let moved = SessionMove.apply(to: profile.weekSessions, from: from, to: to) else { return false }
        profile.weekSessions = moved
"""
    trouves = ck.ecarts_dans(AILLEURS, source)
    assert len(trouves) == 1, trouves
    assert trouves[0][1].endswith(".weekSessions"), trouves


# ── Ce qui est permis, et doit le rester ─────────────────────────────────────────────────────

@cas_test("la génération remplace la semaine entière, au moteur")
def _():
    source = "        profile.weekSessions = generateWeekSessions(weekNumber: 1, tier: 1, profile: profile)\n"
    assert ck.ecarts_dans(MOTEUR, source) == []


@cas_test("la même ligne ailleurs qu'au moteur est signalée")
def _():
    source = "        profile.weekSessions = generateWeekSessions(weekNumber: 1, tier: 1, profile: profile)\n"
    assert len(ck.ecarts_dans(AILLEURS, source)) == 1


@cas_test("l'annulation du coach restaure la semaine depuis son instantané")
def _():
    assert ck.ecarts_dans(MOTEUR, "        profile.weekSessions = snapshot.weekSessions\n") == []


@cas_test("la restauration d'une sauvegarde pose la semaine telle quelle")
def _():
    source = "        if let v = p.weekSessions { profil.weekSessions = v }\n"
    assert ck.ecarts_dans(RESTAURATION, source) == []
    assert len(ck.ecarts_dans(AILLEURS, source)) == 1, "mais nulle part ailleurs"


@cas_test("`.completed` marque ce qui a eu lieu, et s'écrit")
def _():
    source = """
        profile.weekSessions[i].completed = true
        profile.weekSessions[idx].completed = false
"""
    assert ck.ecarts_dans(MOTEUR, source) == []


@cas_test("le squelette vide de sept jours sans séance n'est pas un plan")
def _():
    source = "        self.weekSessions = (0..<7).map { PlannedDay(weekday: $0, session: nil) }\n"
    assert ck.ecarts_dans("RunUp/Models/UserProfile.swift", source) == []


@cas_test("une VRAIE séance au même endroit reste un défaut")
def _():
    source = "        self.weekSessions = (0..<7).map { PlannedDay(weekday: $0, session: .reprise) }\n"
    assert len(ck.ecarts_dans("RunUp/Models/UserProfile.swift", source)) == 1


# ── Ce qu'il ne doit pas inventer ────────────────────────────────────────────────────────────

@cas_test("lire la séance du jour dans un `guard let` n'est pas l'écrire")
def _():
    # Le faux positif le plus évident : la ligne porte un `=`, mais à DROITE du nom.
    source = """
        guard let idx = profile.weekSessions.firstIndex(where: { $0.weekday == weekday }),
              let session = profile.weekSessions[idx].session,
              session.durationMinutes > 0, !profile.weekSessions[idx].completed
        else { return false }
"""
    assert ck.ecarts_dans(MOTEUR, source) == []


@cas_test("comparer n'est pas affecter")
def _():
    source = """
        if profile.weekSessions[idx].session == nil { return }
        let pareil = profile.weekSessions[0].completed != profile.weekSessions[1].completed
"""
    assert ck.ecarts_dans(MOTEUR, source) == []


@cas_test("une affectation composée sur un compteur n'est pas une pose de séance")
def _():
    source = "        total += profile.weekSessions[i].session?.durationMinutes ?? 0\n"
    assert ck.ecarts_dans(MOTEUR, source) == []


@cas_test("une ligne commentée ne satisfait pas la règle et ne la viole pas")
def _():
    # La leçon de `check_film.py`, qui lisait sa propre explication et restait vert : le garde
    # ne doit RIEN tirer d'un commentaire, ni une faute ni une excuse.
    source = """
        // profile.weekSessions[0].session = seance
        /* profile.weekSessions = moved */
"""
    assert ck.ecarts_dans(AILLEURS, source) == []


@cas_test("une faute écrite après un commentaire sur la même ligne est vue quand même")
def _():
    source = "        profile.weekSessions[0].session = seance // posée à la main\n"
    assert len(ck.ecarts_dans(AILLEURS, source)) == 1


@cas_test("une faute dans une interpolation de chaîne est vue")
def _():
    # La leçon de `check_prive.py` : un découpage naïf des chaînes efface le contenu des
    # interpolations, c'est-à-dire du vrai code — et c'est exactement là que vivait le défaut
    # qu'il avait d'abord manqué.
    source = '        print("posé \\(poser(&profile.weekSessions[0].session = seance))")\n'
    assert len(ck.ecarts_dans(AILLEURS, source)) == 1


@cas_test("le nom seul, sans point devant, n'est pas la semaine d'un profil")
def _():
    # `Sauvegarde.Profil` a sa propre propriété `weekSessions` : la décoder n'est pas écrire
    # dans la semaine de quelqu'un.
    source = "            weekSessions = c.lireTableau(PlannedDay.self, .weekSessions)\n"
    assert ck.ecarts_dans("RunUp/Services/Sauvegarde.swift", source) == []


# ── Et le dépôt tel qu'il est ────────────────────────────────────────────────────────────────

@cas_test("le dépôt tel qu'il est passe")
def _():
    assert ck.ecarts() == [], ck.ecarts()


def main() -> int:
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  FAIL {nom}\n       {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
