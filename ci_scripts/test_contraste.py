#!/usr/bin/env python3
"""Ce que `check_contraste.py` doit voir, et ce qu'il ne doit pas signaler.

Le premier cas est la ligne réelle trouvée par l'audit.
"""

import sys

import check_contraste as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def signale(relatif: str, extrait: str) -> bool:
    for ligne in ck.sans_commentaires(extrait).splitlines():
        if ck.EMPLOI.search(ligne) and not ck.est_tolere(relatif, ligne):
            return True
    return False


@cas_test("la ligne d'indice des Stats, telle qu'elle était")
def _():
    assert signale("RunUp/Views/Stats/StatsView.swift",
                   '.font(RUFont.sans(.small)).foregroundColor(RUColor.text4)')


@cas_test("la même ligne corrigée en text3 passe")
def _():
    assert not signale("RunUp/Views/Stats/StatsView.swift",
                       '.font(RUFont.sans(.small)).foregroundColor(RUColor.text3)')


@cas_test("un remplissage de forme n'est pas un contraste de texte")
def _():
    assert not signale("RunUp/Views/Live/RecapView.swift",
                       'Circle().fill(RUColor.text4).frame(width: 5, height: 5)')
    assert not signale("RunUp/Views/Race/RaceGoalView.swift",
                       'RoundedRectangle(cornerRadius: 2).fill(isLast ? RUColor.rose : RUColor.text4)')


@cas_test("les trois emplois justifiés passent")
def _():
    assert not signale("RunUp/Views/Club/FriendsView.swift",
                       'Text("·").font(RUFont.sans(.body)).foregroundColor(RUColor.text4)')
    assert not signale("RunUp/Views/Paywall/PaywallView.swift",
                       'Text(verbatim: "·").foregroundColor(RUColor.text4)')
    assert not signale("RunUp/Views/Home/PlanView.swift",
                       '.foregroundColor(enabled ? RUColor.textPrimary : RUColor.text4)')


@cas_test("une tolérance ne vaut que pour SON fichier")
def _():
    # Le même point médian ailleurs doit redemander sa justification : rien ne garantit qu'il
    # soit décoratif dans un écran qu'on n'a pas regardé.
    assert signale("RunUp/Views/Home/HomeView.swift",
                   'Text("·").font(RUFont.sans(.body)).foregroundColor(RUColor.text4)')


@cas_test("un exemple en commentaire ne déclenche rien")
def _():
    assert not signale("RunUp/Views/Stats/StatsView.swift",
                       '// Avant : .foregroundColor(RUColor.text4)')


@cas_test("le dépôt tel qu'il est passe")
def _():
    assert ck.problemes() == [], ck.problemes()


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
