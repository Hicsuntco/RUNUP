#!/usr/bin/env python3
"""Tout symbole SF nommé dans le code doit être nommé aussi dans le test qui l'éprouve.

# POURQUOI CE CONTRÔLE EXISTE

`Image(systemName: "mountain.2.fill")` sur un nom qui n'existe pas ne lève rien, ne journalise
rien, et ne dessine RIEN. Un `Image` vide de la bonne taille : la mise en page ne bouge pas, la
construction est verte, les tests passent. Le défaut ne se voit qu'en regardant l'écran concerné,
dans la bonne version d'iOS — autant dire jamais pour un écran qu'on ne photographie pas.

Le risque est arrivé d'un coup : les neuf objectifs de l'inscription portaient un emoji, et les
remplacer par des symboles demandait huit noms que ce dépôt n'avait jamais utilisés. Huit
occasions d'écrire une icône invisible sur le premier écran que voit quelqu'un.

# COMMENT ON S'EN ASSURE, PUISQU'ON NE PEUT PAS LE FAIRE ICI

Un script Python n'a aucun moyen de savoir si « mountain.2.fill » existe : le catalogue des
symboles appartient au système, pas au dépôt. La vérification se fait donc là où le système est
présent — dans `RunUpTests/SymbolesTests.swift`, qui demande à `UIImage(systemName:)` de résoudre
chaque nom, et qui tourne à chaque construction.

Ce script-ci est le PONT : il garantit que la liste éprouvée par le test est exactement celle que
le code emploie. Sans lui, le test resterait vert en ignorant le symbole ajouté la veille, et on
aurait une barrière qui ne regarde pas ce qu'elle garde.

# CE QU'IL NE COUVRE PAS

Un symbole introduit dans une version d'iOS PLUS RÉCENTE que la cible de déploiement passe le
test — le simulateur de l'intégration continue est à jour — et reste vide sur un téléphone plus
ancien. La parade n'est pas mécanique : elle est de préférer des noms anciens.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ["RunUp", "RunUpWidgets", "RunUpWatch"]
TEST = RACINE / "RunUpTests/SymbolesTests.swift"

# ── CE QUI EST LU, ET POURQUOI PAS SEULEMENT `systemName: "…"` ────────────────────────────────
#
# Le premier jet ne cherchait que le littéral collé à `systemName:`. Il a rapporté soixante-six
# noms et en a MANQUÉ au moins neuf, qui sont exactement ceux qu'on ne relit jamais :
#
#   · `Image(systemName: family.symbol)` — les sept familles de séance, dont « dumbbell.fill »
#     et « moon.zzz.fill », nommées dans `SessionFamily.symbol` et jamais éprouvées ;
#   · `Image(systemName: p.kudoedByMe ? "hands.clap.fill" : "hands.clap")` — la seconde branche
#     du ternaire, la main qui n'applaudit pas encore ;
#   · `rowIcon("bell")` — un paramètre que la vue transmet elle-même à `systemName:`.
#
# La même zone aveugle que `check_strings.py` a dû fermer trois fois. On ne devine donc rien par
# le NOM d'un membre : c'est le SITE D'APPEL qui désigne ce qu'il faut suivre. On lit l'argument
# de `systemName:`, et tout ce qui n'y est pas un littéral est un nom à résoudre — un membre, ou
# un paramètre d'une fonction qui le réexpédie.
_ARG = re.compile(r'systemName:\s*([^,)]+)')
_LITTERAL = re.compile(r'"([^"]+)"')
_IDENT = re.compile(r'\b([A-Za-z_]\w*)\s*(?:\?|$|\s)')
# La liste du test, écrite comme un tableau de littéraux.
_EPROUVE = re.compile(r'static let tous: \[String\] = \[(.*?)\]', re.S)


def _sources():
    return [f.read_text(encoding="utf-8") for d in DOSSIERS for f in (RACINE / d).rglob("*.swift")]


def _arguments(source: str, ouvrante: int) -> str:
    """Les arguments d'un appel, parenthèses équilibrées, depuis la `(` à l'index donné.

    Pas une expression régulière : un appel d'initialiseur tient sur plusieurs lignes et porte
    des parenthèses internes — `RUEmpty(icone: "bell.slash", message: String(localized: "…"))`.
    Un motif naïf s'arrête à la première `)` fermante, c'est-à-dire au milieu.
    """
    niveau = 0
    for j in range(ouvrante, len(source)):
        if source[j] == "(":
            niveau += 1
        elif source[j] == ")":
            niveau -= 1
            if niveau == 0:
                return source[ouvrante + 1:j]
    return source[ouvrante + 1:]


def _corps(source: str, depart: int) -> str:
    """Le corps accoladé qui commence à la première `{` après `depart`."""
    i = source.find("{", depart)
    if i < 0:
        return ""
    niveau = 0
    for j in range(i, len(source)):
        if source[j] == "{":
            niveau += 1
        elif source[j] == "}":
            niveau -= 1
            if niveau == 0:
                return source[i:j]
    return source[i:]


def _litteraux_rendus(corps: str):
    """Les littéraux qu'un corps RETOURNE, et non ceux qu'il compare."""
    rendus = set()
    for m in re.finditer(r"\breturn\b([^\n]*)", corps):
        rendus.update(_LITTERAL.findall(m.group(1)))
    return rendus


def symboles_utilises():
    """Les noms de symboles que l'app emploie, littéraux et noms résolus."""
    sources = [re.sub(r"//[^\n]*", "", s) for s in _sources()]
    noms, a_resoudre = set(), set()
    for src in sources:
        for m in _ARG.finditer(src):
            arg = m.group(1)
            litteraux = _LITTERAL.findall(arg)
            noms.update(litteraux)
            if litteraux:
                continue
            # Pas de littéral : l'argument désigne un membre ou un paramètre. On garde le
            # dernier segment — `badge.symbole` donne `symbole`, `symbol` donne `symbol`.
            for ident in _IDENT.findall(arg.strip()):
                a_resoudre.add(ident.split(".")[-1])
    # DEUX PRÉCAUTIONS CONTRE LA COLLISION DE NOMS, qui sont la seule source de faux positifs
    # qu'ait eue ce script — et la même erreur que j'avais faite en inventoriant les emojis.
    #
    #   · d'un membre, on ne retient que les littéraux RENDUS. `case "trail": return
    #     "mountain.2.fill"` porte les deux côtés de la correspondance, et « trail » n'est pas un
    #     symbole : c'est la clé d'entrée. Quatre disciplines étaient réclamées pour cette raison.
    #   · la résolution d'un PARAMÈTRE reste dans son fichier. Deux vues ont chacune une
    #     `ligne(_:_:)`, et celle de l'écran d'administration passe « Serveur » et « Version » à
    #     un paramètre qui, chez la voisine, finit dans `systemName:`.
    for cible in sorted(a_resoudre):
        for src in sources:
            # Un membre : `var symbole: String { … }`, `var icon: String? { … }`.
            for m in re.finditer(r"\bvar\s+" + re.escape(cible) + r"\s*:\s*String\??\s*\{", src):
                noms.update(_litteraux_rendus(_corps(src, m.start())))
            # Une fonction : `func statusIcon(_ e: Etat) -> String { … }`.
            for m in re.finditer(r"\bfunc\s+" + re.escape(cible) + r"\s*\([^)]*\)\s*->\s*String\??\s*\{", src):
                noms.update(_litteraux_rendus(_corps(src, m.start())))
            # Un PARAMÈTRE qu'une fonction réexpédie : on remonte à ses appels.
            for m in re.finditer(r"\bfunc\s+(\w+)\s*\(([^)]*\b" + re.escape(cible)
                                 + r"\s*:\s*String\??[^)]*)\)", src):
                fonction, params = m.group(1), m.group(2)
                if ("systemName: " + cible) not in _corps(src, m.end()):
                    continue
                # L'étiquette vue à l'appel : `_ nom: String` s'appelle sans étiquette.
                sans_etiquette = re.search(r"_\s+" + re.escape(cible) + r"\s*:", params)
                for src2 in [src]:
                    for appel in re.finditer(r"\b" + re.escape(fonction) + r"\s*\(([^)]*)\)", src2):
                        args = appel.group(1)
                        if sans_etiquette:
                            premier = args.split(",")[0]
                            noms.update(_LITTERAL.findall(premier))
                        else:
                            e = re.search(re.escape(cible) + r'\s*:\s*("(?:[^"\\]|\\.)*")', args)
                            if e:
                                noms.update(_LITTERAL.findall(e.group(1)))
            # UNE PROPRIÉTÉ STOCKÉE DE STRUCTURE, résolue depuis les appels de son initialiseur.
            #
            # La troisième forme de réexpédition, et celle qui a manqué. `RUEmpty` porte
            # `var icone: String?` et l'envoie à `systemName:` — mais une propriété STOCKÉE n'a
            # pas de corps accoladé, donc la résolution de membre ci-dessus ne la voyait pas, et
            # celle de paramètre ne regarde que les `func`.
            #
            # Ce que ça coûtait : au moment où les écrans ont adopté `RUEmpty`, leurs icônes sont
            # devenues INVISIBLES à ce contrôle. Deux symboles — « bell.slash » et
            # « square.stack.3d.up » — sont passés de « employés » à « plus employés » sans que
            # rien ne change à l'écran. Et le sens qui compte est l'autre : un symbole inexistant
            # passé à `RUEmpty(icone:)` ne serait plus éprouvé par personne, et un nom de symbole
            # faux ne lève rien — il ne dessine rien.
            for m in re.finditer(r"\bstruct\s+(\w+)\s*:[^{]*\{", src):
                nom_struct = m.group(1)
                corps = _corps(src, m.start())
                if not re.search(r"\bvar\s+" + re.escape(cible) + r"\s*:\s*String\??", corps):
                    continue
                if ("systemName: " + cible) not in corps:
                    continue
                for src2 in sources:
                    for appel in re.finditer(r"\b" + re.escape(nom_struct) + r"\s*\(", src2):
                        args = _arguments(src2, appel.end() - 1)
                        e = re.search(re.escape(cible) + r'\s*:\s*("(?:[^"\\]|\\.)*")', args)
                        if e:
                            noms.update(_LITTERAL.findall(e.group(1)))
    # Un nom de symbole ne contient ni espace ni accent : ce qui en porte vient d'un faux positif
    # de lecture (une phrase passée au même paramètre ailleurs), et le signaler noierait le reste.
    # Un nom de symbole SF est en minuscules, sans espace ni accent : « Classique » et « Nom »
    # viennent d'une lecture de travers, et les réclamer noierait les vrais manques.
    return {n for n in noms if n and re.fullmatch(r"[a-z0-9.]+", n)}


def symboles_eprouves():
    if not TEST.exists():
        return None
    m = _EPROUVE.search(TEST.read_text(encoding="utf-8"))
    if not m:
        return None
    return set(re.findall(r'"([^"]+)"', m.group(1)))


def main() -> int:
    utilises = symboles_utilises()
    eprouves = symboles_eprouves()
    if eprouves is None:
        print("RunUpTests/SymbolesTests.swift ne porte pas de `static let tous: [String] = [...]`.",
              file=sys.stderr)
        return 1
    manquants = sorted(utilises - eprouves)
    en_trop = sorted(eprouves - utilises)
    if manquants:
        print(f"{len(manquants)} symbole(s) employé(s) mais non éprouvé(s) :\n", file=sys.stderr)
        for n in manquants:
            print(f"  « {n} »", file=sys.stderr)
        print("\nUn nom de symbole faux ne dessine RIEN, sans erreur ni journal. Ajoute-les à",
              file=sys.stderr)
        print("`SymbolesTests.tous` : c'est le simulateur qui dira s'ils existent.", file=sys.stderr)
        return 1
    if en_trop:
        print(f"{len(en_trop)} symbole(s) éprouvé(s) mais plus employé(s) :\n", file=sys.stderr)
        for n in en_trop:
            print(f"  « {n} »", file=sys.stderr)
        print("\nRetire-les de `SymbolesTests.tous` : une liste qui déborde finit par ne plus",
              file=sys.stderr)
        print("décrire l'app, et c'est ce qui fait qu'on cesse de la croire.", file=sys.stderr)
        return 1
    print(f"Symboles : {len(utilises)} noms employés, tous éprouvés par SymbolesTests.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
