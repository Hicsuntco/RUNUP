#!/usr/bin/env python3
"""Ce que `check_grands_chiffres.py` doit voir, et surtout ce qu'il ne doit PAS refuser.

Les deux faux positifs ci-dessous sont les vrais cas du dépôt, et ils ont corrigé la règle avant
qu'elle ne soit écrite : la première version exigeait une réduction de TOUT grand corps, ce qui
aurait refusé un titre sur trois lignes et un texte autorisé à grandir en hauteur.
"""

import sys

import check_grands_chiffres as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def _fautif(source: str) -> bool:
    """La règle rejouée sur une source fabriquée, sans toucher au dépôt."""
    for _, _, bloc in ck.grands_corps(source):
        if "lineLimit(1)" in bloc and "minimumScaleFactor" not in bloc:
            return True
    return False


# ── 1. le défaut réel du 13 novembre ─────────────────────────────────────────────────────────

@cas_test("un chrono sur une ligne sans réduction est refusé")
def _():
    assert _fautif("""
    Text(duree)
        .displayStyle(horsEchelle: 64)
        .lineLimit(1)
        .monospacedDigit()
    """)


@cas_test("le même avec sa réduction passe")
def _():
    assert not _fautif("""
    Text(duree)
        .displayStyle(horsEchelle: 64)
        .lineLimit(1).minimumScaleFactor(0.5)
        .monospacedDigit()
    """)


# ── 2. les deux faux positifs qui ont corrigé la règle ───────────────────────────────────────

@cas_test("un titre sur plusieurs lignes n'a rien à rétrécir")
def _():
    assert not _fautif("""
    Text("COURS COMME\\nSI TU AVAIS\\nUN COACH")
        .displayStyle(.banner)
        .lineSpacing(-4)
    """)


@cas_test("un texte autorisé à grandir en hauteur non plus")
def _():
    assert not _fautif("""
    Text(titre)
        .displayStyle(.hero)
        .fixedSize(horizontal: false, vertical: true)
    """)


# ── 3. les bornes de ce que « grand » veut dire ──────────────────────────────────────────────

@cas_test("un corps sous le seuil n'est pas concerné")
def _():
    assert not _fautif("""
    Text(valeur)
        .displayStyle(horsEchelle: 28)
        .lineLimit(1)
    """)
    assert ck.SEUIL == 35, "le seuil est la valeur de `hero` ; s'il change, l'échelle a bougé"


@cas_test("les trois écritures d'un grand corps sont reconnues")
def _():
    for ecriture in (".displayStyle(.hero)", ".displayStyle(.banner)",
                     "RUFont.display(.banner)", ".displayStyle(horsEchelle: 44)"):
        src = f"Text(x)\n    {ecriture}\n    .lineLimit(1)\n"
        assert _fautif(src), ecriture


@cas_test("un `horsEchelle:` CALCULÉ est contrôlé, pas ignoré")
def _():
    """Le trou de la première version du garde, et il portait sur son propre cas d'origine.

    `horsEchelle:` suivi d'une expression plutôt que d'un chiffre n'était pas reconnu, donc le
    chronomètre de l'écran de séance — la ligne qui a fait écrire ce contrôle — lui était
    invisible. Il voyait 8 grands corps au lieu de 13.
    """
    calcule = ("Text(duree)\n"
               "    .displayStyle(horsEchelle: hasInstruction ? RUDisplaySize.hero.rawValue : 64)\n"
               "    .lineLimit(1)\n")
    assert _fautif(calcule), "un corps calculé doit être contrôlé dans le doute"
    assert not _fautif(calcule.replace(".lineLimit(1)",
                                       ".lineLimit(1).minimumScaleFactor(0.5)"))


@cas_test("un modificateur hors de portée ne compte pas pour le bon")
def _():
    # `minimumScaleFactor` dix lignes plus bas appartient à une AUTRE vue.
    loin = "Text(x)\n    .displayStyle(.hero)\n    .lineLimit(1)\n" + "\n" * 12 + \
           "    .minimumScaleFactor(0.5)\n"
    assert _fautif(loin)


# ── 4. le dépôt ──────────────────────────────────────────────────────────────────────────────

@cas_test("le dépôt tel qu'il est passe")
def _():
    assert ck.ecarts() == [], ck.ecarts()


@cas_test("l'écran de séance porte bien ses deux réductions")
def _():
    chemin = ck.RACINE / "RunUp/Views/Live/LiveRunView.swift"
    source = chemin.read_text(encoding="utf-8")
    grands = list(ck.grands_corps(source))
    assert len(grands) >= 3, [g[:2] for g in grands]
    for numero, taille, bloc in grands:
        if "lineLimit(1)" in bloc:
            assert "minimumScaleFactor" in bloc, (numero, taille)


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
