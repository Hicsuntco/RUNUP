#!/usr/bin/env python3
"""Ce que `check_design.py` doit voir, et ce qu'il ne doit pas inventer.

Trois des cas ci-dessous sont des DÉFAUTS RÉELS, commis en écrivant `DESIGN.md` le 12 novembre :

  • trois gardes CITÉS QUI N'EXISTAIENT PAS — `check_degrades.py` au pluriel, `check_polices.py`
    qui s'appelle `check_fonts.py`, et un contrôle des emojis qui n'existe pas du tout. Le
    document promettait trois barrières dont une n'a jamais été écrite ;
  • `title` COMPARÉ À LA MAUVAISE ÉCHELLE : le cran existe dans `RUTextSize` à 18,5 et dans
    `RUDisplaySize` à 22, et la première version du garde criait un écart qui n'en était pas un ;
  • le document VIDÉ de ses tableaux, qui passait tous les contrôles en silence.
"""

import pathlib
import sys
import tempfile

import check_design as ck
import couleurs
import swift

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def _sur(document: str) -> list:
    """Les écarts que le garde relève sur un faux `DESIGN.md`, sans toucher au vrai."""
    faux = pathlib.Path(tempfile.gettempdir()) / "faux_design.md"
    faux.write_text(document, encoding="utf-8")
    vrai = ck.DESIGN
    try:
        ck.DESIGN = faux
        return ck.ecarts()
    finally:
        ck.DESIGN = vrai
        faux.unlink(missing_ok=True)


def _vrai_document() -> str:
    return (couleurs.RACINE / "DESIGN.md").read_text(encoding="utf-8")


# ── 1. les défauts réels ─────────────────────────────────────────────────────────────────────

@cas_test("un garde cité qui n'existe pas est refusé (le défaut du 12 novembre)")
def _():
    doc = _vrai_document() + "\n\nUn contrôle imaginaire : `check_degrades.py`.\n"
    assert any("check_degrades.py" in quoi for _, quoi, _ in _sur(doc))


@cas_test("les trois noms réellement cités existent tous")
def _():
    import re
    for cite in set(re.findall(r"`(check_[a-z_0-9]+\.py)`", _vrai_document())):
        assert (couleurs.RACINE / "ci_scripts" / cite).is_file(), cite


@cas_test("`title` est comparé à l'échelle de son tableau, pas à son homonyme")
def _():
    textes, affichage = ck.echelle("RUTextSize"), ck.echelle("RUDisplaySize")
    # La prémisse du défaut : le même nom, deux valeurs.
    assert textes["title"] == 18.5 and affichage["title"] == 22.0
    # Et le document, tel qu'il est, passe — donc les deux tableaux sont lus chacun dans sa règle.
    assert ck.ecarts() == [], ck.ecarts()


@cas_test("un document vidé de ses tableaux est refusé")
def _():
    doc = "\n".join(l for l in _vrai_document().splitlines()
                    if not l.lstrip().startswith("|"))
    problemes = _sur(doc)
    quoi = {q for _, q, _ in problemes}
    for attendu in ("jetons", "accents", "familles", "crans", "durees"):
        assert attendu in quoi, (attendu, quoi)


# ── 2. chaque famille de valeurs est bien tenue ──────────────────────────────────────────────

@cas_test("un jeton de couleur faux est attrapé")
def _():
    doc = _vrai_document().replace("| `text3` | `#5B5563` |", "| `text3` | `#616161` |")
    assert any("text3" in quoi for _, quoi, _ in _sur(doc))


@cas_test("une valeur de nuancier fausse est attrapée")
def _():
    doc = _vrai_document().replace("| Rose | `#FF0A78` |", "| Rose | `#F0225F` |")
    assert any("Rose" in quoi for _, quoi, _ in _sur(doc))


@cas_test("une teinte de famille fausse est attrapée")
def _():
    doc = _vrai_document().replace("| Fractionné | `ember` |", "| Fractionné | `azure` |")
    problemes = _sur(doc)
    assert any("Fractionné" in quoi for _, quoi, _ in problemes), problemes


@cas_test("un cran de typographie faux est attrapé")
def _():
    doc = _vrai_document().replace("| `figure` | 28 |", "| `figure` | 30 |")
    assert any("figure" in quoi for _, quoi, _ in _sur(doc))


@cas_test("une durée de mouvement fausse est attrapée")
def _():
    doc = _vrai_document().replace("| `draw` | 1 450 ms |", "| `draw` | 1 200 ms |")
    problemes = _sur(doc)
    assert any("draw" in quoi for _, quoi, _ in problemes), problemes


@cas_test("une des trois questions retirée est attrapée")
def _():
    doc = _vrai_document().replace("s'y sent à sa place", "s'y sent bien")
    problemes = _sur(doc)
    assert any("s'y sent à sa place" in quoi for _, quoi, _ in problemes), problemes


# ── 3. les lecteurs partagés ─────────────────────────────────────────────────────────────────

@cas_test("`sans_commentaires_seuls` garde les chaînes, `sans_commentaires` les efface")
def _():
    src = 'let x = AccentTheme(id: "rose") // un commentaire\n'
    assert '"rose"' in swift.sans_commentaires_seuls(src)
    assert "rose" not in swift.sans_commentaires(src)
    for fonction in (swift.sans_commentaires, swift.sans_commentaires_seuls):
        assert "commentaire" not in fonction(src)


@cas_test("les huit nuanciers se lisent, avec leurs trois valeurs")
def _():
    a = couleurs.accents()
    assert len(a) == 8, sorted(a)
    for ident, valeurs in a.items():
        assert len(valeurs) == 3, (ident, valeurs)
        assert all(0 <= v <= 0xFFFFFF for v in valeurs), (ident, valeurs)


@cas_test("les sept familles de séance ont chacune leur teinte")
def _():
    t = ck.teintes_des_familles()
    assert set(t) == set(ck.FAMILLES.values()), (sorted(t), sorted(ck.FAMILLES.values()))
    # Une famille est une information : deux familles ne peuvent pas partager une teinte.
    assert len(set(t.values())) == len(t), t


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
