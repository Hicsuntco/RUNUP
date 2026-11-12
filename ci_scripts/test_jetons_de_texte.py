#!/usr/bin/env python3
"""Ce que `check_jetons_de_texte.py` doit voir, et ce qu'il ne doit pas inventer.

Les trois premiers cas sont des DÉFAUTS RÉELS, recopiés tels qu'ils étaient :

  • l'opacité, l'état du dépôt avant ce chantier ;
  • le gris neutre, ce que cette opacité rendait — la raison visible du chantier ;
  • `#4A4552`, la valeur que MA PROPRE première résolution avait posée en sombre. Elle tenait le
    minimum global et perdait 0,17 de contraste sur `card2` en particulier. Le garde l'a attrapée
    avant la CI ; sans ce cas, rien ne retiendrait la prochaine résolution de refaire la même
    erreur, qui est exactement celle qu'on ne voit pas à l'œil.
"""

import pathlib
import re
import sys
import tempfile

import check_jetons_de_texte as ck
import couleurs

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


def _jetons(declarations: str) -> dict:
    """Les jetons lus dans une source fabriquée, sans toucher au disque."""
    return ck.jetons(ck.sans_commentaires(declarations))


def _ecarts_sur(declarations: str, nom_du_jeton: str, theme: str) -> list:
    """Les problèmes que le garde relèverait sur UN jeton d'une source fabriquée.

    Le garde lit le fichier du dépôt ; on rejoue donc sa logique sur la valeur fournie plutôt que
    d'écrire un faux `Colors.swift` sur le disque — c'est la même arithmétique, et un test qui
    écrit dans `RunUp/` serait un test qui peut casser le dépôt.
    """
    valeur = _jetons(declarations)[nom_du_jeton][theme]
    problemes = []
    if not isinstance(valeur, int):
        return ["pas opaque"]
    if (nom_du_jeton, theme) not in ck.HORS_FAMILLE:
        penchant_du_fond = sum(couleurs.famille(f)[0] for f in couleurs.fonds(theme).values())
        if penchant_du_fond * couleurs.famille(valeur)[0] <= 0:
            problemes.append("hors famille")
    if nom_du_jeton != "textPrimary":
        base = 0x000000 if theme == "clair" else 0xFFFFFF
        alpha = ck.OPACITES[theme][nom_du_jeton]
        for ou, fond in couleurs.fonds(theme).items():
            avant = ck.contraste(ck.melange(base, fond, alpha), fond)
            if ck.contraste(valeur, fond) + 0.005 < avant:
                problemes.append(f"perd sur {ou}")
    return problemes


# ── 1. les trois défauts réels ───────────────────────────────────────────────────────────────

@cas_test("l'opacité d'origine est refusée (l'état d'avant le chantier)")
def _():
    src = "static var text3: Color { isLight ? Color.black.opacity(0.62) : Color.white.opacity(0.52) }"
    assert _ecarts_sur(src, "text3", "clair") == ["pas opaque"]


@cas_test("le gris neutre qu'elle rendait est refusé (hors famille)")
def _():
    src = "static var text3: Color { isLight ? Color(hex: 0x616161) : Color(hex: 0x8F8F93) }"
    assert "hors famille" in _ecarts_sur(src, "text3", "clair")


@cas_test("un texte de L'AUTRE famille est refusé, dans les deux sens")
def _():
    """La règle n'est ni « violet » ni « chaud » : c'est « la famille du fond ».

    Les fonds clairs sont chauds, les fonds sombres froids. Un jeton violet en clair et un jeton
    chaud en sombre doivent donc être refusés tous les deux — c'est le seul cas qui distingue une
    règle relative d'une règle qui aurait simplement changé de camp le 12 novembre.
    """
    froid, chaud = 0x5B5563, 0x5B5651
    assert "hors famille" in _ecarts_sur(
        f"static var text3: Color {{ isLight ? Color(hex: 0x{froid:06X}) : Color(hex: 0x9893A0) }}",
        "text3", "clair")
    assert "hors famille" in _ecarts_sur(
        f"static var text3: Color {{ isLight ? Color(hex: 0x5B5651) : Color(hex: 0x{chaud:06X}) }}",
        "text3", "sombre")


@cas_test("ma première résolution sombre de text4 est refusée : elle perdait sur card2 seul")
def _():
    src = "static var text4: Color { isLight ? Color(hex: 0xB7B1BF) : Color(hex: 0x4A4552) }"
    problemes = _ecarts_sur(src, "text4", "sombre")
    assert any("card2" in p for p in problemes), problemes
    # Et la preuve que le minimum global, lui, était respecté — donc qu'un garde calé sur le
    # minimum aurait laissé passer la régression.
    sols = couleurs.fonds("sombre")
    planchers = [ck.contraste(ck.melange(0xFFFFFF, f, 0.20), f) for f in sols.values()]
    mesures = [ck.contraste(0x4A4552, f) for f in sols.values()]
    assert min(mesures) >= min(planchers) - 0.005, (min(mesures), min(planchers))


# ── 2. l'arithmétique ────────────────────────────────────────────────────────────────────────

@cas_test("le contraste noir sur blanc vaut 21:1")
def _():
    assert round(ck.contraste(0x000000, 0xFFFFFF), 2) == 21.0


@cas_test("une couleur avec elle-même vaut 1:1")
def _():
    for c in (0x000000, 0xFFFFFF, 0x5B5563, 0xF4F3F8):
        assert round(ck.contraste(c, c), 4) == 1.0, hex(c)


@cas_test("le contraste est symétrique")
def _():
    assert ck.contraste(0x5B5563, 0xFFFFFF) == ck.contraste(0xFFFFFF, 0x5B5563)


@cas_test("`melange` reproduit la formule de RUColor.melange")
def _():
    # 0 % et 100 % sont les deux bornes, et 50 % de noir sur blanc donne le gris moyen.
    assert ck.melange(0x000000, 0xFFFFFF, 0.0) == 0xFFFFFF
    assert ck.melange(0x000000, 0xFFFFFF, 1.0) == 0x000000
    assert ck.melange(0x000000, 0xFFFFFF, 0.5) == 0x808080
    # Et par composantes, pas par luminance : le rouge pur à 50 % sur du blanc garde R à 255.
    assert ck.melange(0xFF0000, 0xFFFFFF, 0.5) == 0xFF8080


# ── 3. la borne du fond teinté est vraiment un pire cas ──────────────────────────────────────

@cas_test("aucun accent ne peut donner un fond teinté pire que la borne")
def _():
    """La borne remplace l'accent par du noir pur en clair, du blanc pur en sombre.

    On le vérifie sur les huit `primary` d'`AccentTheme.swift` ET sur leurs variantes claires
    possibles, en prenant simplement TOUTES les couleurs sur 4 bits par voie — 4 096 teintes, ce
    qui englobe largement les huit nuanciers et ce que la recherche dichotomique peut en faire.
    """
    for theme in ("clair", "sombre"):
        neutre = couleurs.fond_neutre(theme)
        part = couleurs.PART_TEINTE[theme]
        borne = couleurs.fonds(theme)["bg teinté (borne)"]
        # Le jeton réel du thème, lu dans la source : ce cas doit survivre au jour où
        # la valeur change, et elle a changé deux fois en une journée.
        texte = couleurs.declarations()["text3"][theme]
        pire = ck.contraste(texte, borne)
        for r in range(0, 256, 17):
            for v in range(0, 256, 17):
                for b in range(0, 256, 17):
                    accent = (r << 16) | (v << 8) | b
                    fond = ck.melange(accent, neutre, part)
                    assert ck.contraste(texte, fond) + 0.005 >= pire, (
                        theme, hex(accent), ck.contraste(texte, fond), pire)


# ── 4. la lecture de la source ───────────────────────────────────────────────────────────────

@cas_test("un hex cité dans un commentaire ne passe pas pour une déclaration")
def _():
    src = """
    // text3 sortait à #616161 sur une carte blanche.
    /// Le brief demande Color(hex: 0x6B6473), qu'on n'a pas pris.
    static var text3: Color { isLight ? Color(hex: 0x5B5563) : Color(hex: 0x9893A0) }
    """
    assert _jetons(src)["text3"] == {"clair": 0x5B5563, "sombre": 0x9893A0}


@cas_test("`Color.white` et `Color.black` sont lues comme des couleurs")
def _():
    src = "static var textPrimary: Color { isLight ? Color(hex: 0x15151C) : Color.white }"
    assert _jetons(src)["textPrimary"] == {"clair": 0x15151C, "sombre": 0xFFFFFF}


@cas_test("un jeton renommé fait échouer le garde au lieu de n'être pas mesuré")
def _():
    """Un garde qui ne trouve plus ce qu'il mesure doit crier, pas réussir en silence.

    C'est le mode de défaillance le plus sournois d'un script qui lit du source : on renomme un
    jeton, l'expression régulière ne trouve rien, le script imprime « tout va bien » et ne mesure
    plus rien du tout. On le vérifie en le faisant lire un faux fichier.
    """
    faux = pathlib.Path(tempfile.gettempdir()) / "faux_colors_jetons.swift"
    faux.write_text(
        "    static var texteDeBase: Color { isLight ? Color(hex: 0x15151C) : Color.white }\n",
        encoding="utf-8")
    vrai = ck.COULEURS
    try:
        ck.COULEURS = faux
        problemes = ck.ecarts()
    finally:
        ck.COULEURS = vrai
        faux.unlink(missing_ok=True)
    assert len(problemes) == 1, problemes
    assert "introuvable" in problemes[0][2], problemes
    for nom in ("text2", "text3", "text4", "textPrimary"):
        assert nom in problemes[0][0], problemes


# ── 5. les quatre jetons du dépôt, dans les deux thèmes ──────────────────────────────────────

@cas_test("chaque jeton secondaire penche du même côté que ses fonds")
def _():
    for nom in ("textPrimary", "text2", "text3", "text4"):
        for theme in ("clair", "sombre"):
            if (nom, theme) in ck.HORS_FAMILLE:
                continue
            valeur = couleurs.declarations()[nom][theme]
            fond = sum(couleurs.famille(f)[0] for f in couleurs.fonds(theme).values())
            assert fond * couleurs.famille(valeur)[0] > 0, (nom, theme, hex(valeur), fond)


@cas_test("textPrimary reste le blanc pur en sombre, et c'est écrit")
def _():
    source = ck.sans_commentaires(ck.COULEURS.read_text(encoding="utf-8"))
    assert ck.jetons(source)["textPrimary"]["sombre"] == 0xFFFFFF
    assert ("textPrimary", "sombre") in ck.HORS_FAMILLE
    # La prose est cherchée APRÈS normalisation : une raison écrite se replie sur deux lignes au
    # premier remaniement du commentaire, et un cas qui lit le fichier brut casserait alors sans
    # qu'aucune raison n'ait disparu. C'est arrivé le 12 novembre.
    brut = ck.COULEURS.read_text(encoding="utf-8")
    prose = " ".join(brut.replace("///", " ").replace("//", " ").split())
    assert "le primaire sombre est le seul jeton dont on veut le maximum" in prose


@cas_test("aucun jeton de texte n'est resté une opacité")
def _():
    source = ck.sans_commentaires(ck.COULEURS.read_text(encoding="utf-8"))
    for nom, branches in ck.jetons(source).items():
        for theme, valeur in branches.items():
            assert isinstance(valeur, int), (nom, theme, valeur)


@cas_test("le dépôt tel qu'il est passe")
def _():
    assert ck.ecarts() == [], ck.ecarts()


@cas_test("le garde imprime un tableau, il ne le recopie pas")
def _():
    # Le commentaire de `Colors.swift` ne doit plus contenir de colonne de contrastes : elle
    # serait fausse au premier réglage. Un seul endroit produit ces chiffres, et c'est le garde.
    brut = ck.COULEURS.read_text(encoding="utf-8")
    bloc = brut.split("LES QUATRE JETONS DE TEXTE")[1].split("static var textPrimary")[0]
    recopies = re.findall(r"\d,\d\d \d,\d\d \d,\d\d", bloc)
    assert not recopies, recopies
    assert "check_jetons_de_texte.py" in bloc
    # Et le tableau existe bien à la sortie du garde.
    assert "text3" in ck.tableau() and "clair" in ck.tableau()


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
