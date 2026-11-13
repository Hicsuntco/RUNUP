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


def _fausse(avant: str, apres: str) -> str:
    """Le document avec une substitution qui a VRAIMENT eu lieu.

    Un cas de ce fichier a déjà passé en ne testant rien : il remplaçait `#5B5563` par une valeur
    fausse, la valeur du dépôt est devenue `#5B5651` quelques heures plus tard, la substitution
    est devenue sans effet, et le cas a continué d'afficher « ok » en ne vérifiant plus rien. Un
    test qui ne teste plus rien est pire qu'un test absent : il rassure.
    """
    document = _vrai_document()
    assert avant in document, (
        f"« {avant} » n'est plus dans DESIGN.md — ce cas ne teste plus rien. "
        "Reprenez-le sur la valeur actuelle au lieu de le laisser passer.")
    return document.replace(avant, apres)


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
    actuel = couleurs.declarations()["text3"]["clair"]
    doc = _fausse(f"| `text3` | `#{actuel:06X}` |", "| `text3` | `#616161` |")
    assert any("text3" in quoi for _, quoi, _ in _sur(doc))


@cas_test("une valeur de nuancier fausse est attrapée")
def _():
    primaire = couleurs.accents()["rose"][0]
    doc = _fausse(f"| Rose | `#{primaire:06X}` |", "| Rose | `#F0225F` |")
    assert any("Rose" in quoi for _, quoi, _ in _sur(doc))


@cas_test("une teinte de famille fausse est attrapée")
def _():
    doc = _fausse("| Fractionné | `ember` |", "| Fractionné | `azure` |")
    problemes = _sur(doc)
    assert any("Fractionné" in quoi for _, quoi, _ in problemes), problemes


@cas_test("un cran de typographie faux est attrapé")
def _():
    doc = _fausse(f"| `figure` | {ck.echelle('RUDisplaySize')['figure']:g} |",
                  "| `figure` | 30 |")
    assert any("figure" in quoi for _, quoi, _ in _sur(doc))


@cas_test("une durée de mouvement fausse est attrapée")
def _():
    # La durée est lue dans Motion.swift, pas recopiée : elle est passée de 1 450 à 700 ms le
    # 13 novembre, et ce cas a cessé de tester quoi que ce soit — `_fausse` l'a dit.
    ms = ck.durees()["draw"]
    espace = "\u202f" if ms >= 1000 else ""
    ecrit = f"{ms // 1000}{espace}{ms % 1000:03d}" if ms >= 1000 else str(ms)
    doc = _fausse(f"| `draw` | {ecrit} ms |", "| `draw` | 1 ms |")
    problemes = _sur(doc)
    assert any("draw" in quoi for _, quoi, _ in problemes), problemes


@cas_test("une des trois questions retirée est attrapée")
def _():
    doc = _fausse("s'y sent à sa place", "s'y sent bien")
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


@cas_test("UN JETON QUI EN NOMME UN AUTRE EST RÉSOLU, une fois et une seule")
def _():
    # `lime` lit `limeSombre` pour sa branche sombre depuis que la carte de nuit a eu besoin de
    # la variante sombre sans la branche de thème. Sans résolution, `declarations()` rendait la
    # chaîne « limeSombre » et ce garde refusait la table de DESIGN.md — à juste titre, puisqu'il
    # ne pouvait plus vérifier ce qu'elle annonce.
    source = """
    static let limeSombre = Color(hex: 0xC8FF3D)
    static var lime: Color { isLight ? Color(hex: 0x6B9E00) : limeSombre }
    static var inconnue: Color { isLight ? Color(hex: 0x111111) : pasUnJeton }
    """
    lus = couleurs.declarations(source)
    assert lus["lime"]["sombre"] == 0xC8FF3D, lus["lime"]
    assert lus["lime"]["clair"] == 0x6B9E00, lus["lime"]
    # Ce qui ne nomme rien de connu reste brut : c'est une information, pas une erreur.
    assert lus["inconnue"]["sombre"] == "pasUnJeton", lus["inconnue"]


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
