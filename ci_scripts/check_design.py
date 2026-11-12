#!/usr/bin/env python3
"""`DESIGN.md` décrit-il l'app telle qu'elle est ?

# POURQUOI CE GARDE EXISTE

`DESIGN.md` porte la direction artistique pour qu'elle ne dépende plus d'une conversation. Un tel
document a un mode de défaillance propre, et c'est le pire de tous : **il dérive sans bruit.**
Quelqu'un règle une valeur dans `Colors.swift`, le document continue d'annoncer l'ancienne, et on
le lit en croyant savoir. Un commentaire qui mentait sur le contraste de `text3` a déjà coûté une
passe à cette app.

Le document cite donc le code, et ce script vérifie la citation. Il ne range AUCUNE valeur
attendue : il lit les deux côtés et les compare.

# CE QU'IL REGARDE

  1. chaque ligne de tableau qui nomme un jeton de couleur et donne ses valeurs ;
  2. les trois valeurs des huit nuanciers d'accent ;
  3. la teinte de chaque famille de séance ;
  4. les deux échelles de typographie et les sept crans d'icône ;
  5. les durées de mouvement ;
  6. que les trois questions et le test final sont toujours là ;
  7. que chaque garde cité existe vraiment dans `ci_scripts/`.

# CE QU'IL NE REGARDE PAS

La prose. Les raisons écrites dans `DESIGN.md` ne sont pas vérifiables par un script, et c'est
normal : ce sont des décisions, pas des faits sur le code. Le script tient les NOMBRES, qui sont
les seuls à pouvoir dériver en silence.
"""

import pathlib
import re
import sys

import couleurs

RACINE = couleurs.RACINE
DESIGN = RACINE / "DESIGN.md"
TYPO = RACINE / "RunUp/DesignSystem/Typography.swift"
MOTION = RACINE / "RunUp/DesignSystem/Motion.swift"

# Les noms français des nuanciers, tels que `DESIGN.md` les présente, vers leur `id` Swift.
NUANCIERS = {
    "Rose": "rose", "Violet": "violet", "Bleu": "bleu", "Cyan": "cyan",
    "Lime": "lime", "Ambre": "amber", "Corail": "corail", "Magenta": "magenta",
}

# Les noms français des familles de séance vers leur `case` Swift.
FAMILLES = {
    "Repos": "rest", "Récupération": "recovery", "Endurance": "endurance",
    "Sortie longue": "longRun", "Tempo": "tempo", "Fractionné": "intervals",
    "Fonctionnel": "functional",
}

# Les phrases qui ne doivent pas disparaître du document. Un garde ne peut pas juger la DA, mais il
# peut refuser qu'on la vide : ce sont les trois questions et le test final, réduits à ce qui les
# identifie sans dépendre de leur ponctuation.
ANCRES = [
    "s'y sent à sa place",
    "le trouve sérieux",
    "qu'il a été généré",
    "reconnaissable comme RunUp",
]

MOTS_POUR_BLANC = {"blanc pur": 0xFFFFFF, "noir pur": 0x000000}


def _hex(cellule: str):
    """La valeur d'une cellule : un hex, « blanc pur », ou None si ce n'en est pas une."""
    cellule = cellule.strip()
    if (m := re.fullmatch(r"`#([0-9A-Fa-f]{6})`", cellule)):
        return int(m.group(1), 16)
    return MOTS_POUR_BLANC.get(cellule.lower())


def _cellules(ligne: str) -> list:
    if not ligne.lstrip().startswith("|"):
        return []
    return [c.strip() for c in ligne.strip().strip("|").split("|")]


def _jeton(cellule: str):
    if (m := re.fullmatch(r"`([a-zA-Z][a-zA-Z0-9]*)`", cellule.strip())):
        return m.group(1)
    return None


def _nombre(cellule: str):
    """« 8,5 » ou « 11 » → 8.5 / 11.0. La virgule est française dans le document."""
    t = cellule.strip().strip("`").replace(",", ".").replace(" ", "").replace(" ", "")
    try:
        return float(t)
    except ValueError:
        return None


def teintes_des_familles() -> dict:
    """`SessionFamily.tint` : `{case: nom du jeton}`, lu dans `Colors.swift`."""
    src = couleurs.sans_commentaires(couleurs.COULEURS.read_text(encoding="utf-8"))
    bloc = src.split("var tint: Color {", 1)
    if len(bloc) < 2:
        return {}
    corps = bloc[1].split("}", 1)[0]
    return dict(re.findall(r"case \.([a-zA-Z]+): return RUColor\.([a-zA-Z0-9]+)", corps))


def echelle(nom: str) -> dict:
    """Les crans d'une énumération de taille : `{cran: valeur}`."""
    src = couleurs.sans_commentaires(TYPO.read_text(encoding="utf-8"))
    bloc = src.split(f"enum {nom}: CGFloat {{", 1)
    if len(bloc) < 2:
        return {}
    corps = bloc[1].split("\n}", 1)[0]
    return {c: float(v) for c, v in re.findall(r"case ([a-zA-Z]+) = ([0-9.]+)", corps)}


def durees() -> dict:
    """Les durées de `RUMotion`, en millisecondes : `{jeton: ms}`."""
    src = couleurs.sans_commentaires(MOTION.read_text(encoding="utf-8"))
    sortie = {}
    for nom, duree in re.findall(r"static let ([a-zA-Z]+) = Animation\.[^\n]*?duration: ([0-9.]+)", src):
        sortie[nom] = round(float(duree) * 1000)
    return sortie


def ecarts() -> list:
    if not DESIGN.is_file():
        return [("DESIGN.md", "", "Le fichier n'existe pas. La DA ne doit pas redevenir orale.")]

    texte = DESIGN.read_text(encoding="utf-8")
    jetons = couleurs.declarations()
    accents = couleurs.accents()
    tints = teintes_des_familles()
    textes = echelle("RUTextSize")
    affichage = echelle("RUDisplaySize")
    icones = echelle("RUIconSize")
    mouvement = durees()
    problemes = []
    vus = {"jetons": 0, "accents": 0, "familles": 0, "crans": 0, "durees": 0}

    # `title` vaut 18,5 dans `RUTextSize` et 22 dans `RUDisplaySize` : le nom d'un cran ne dit pas
    # à quelle échelle il appartient. On suit donc le tableau dans lequel on est, en retenant la
    # dernière échelle nommée par la prose. Sans ça le garde comparait un cran d'affichage à son
    # homonyme de texte courant et criait au faux écart — ce qu'il a fait.
    echelle_courante = None
    ECHELLES = {"RUTextSize": textes, "RUDisplaySize": affichage, "RUIconSize": icones}

    for numero, ligne in enumerate(texte.splitlines(), start=1):
        for quoi in ECHELLES:
            if quoi in ligne:
                echelle_courante = quoi
        cs = _cellules(ligne)
        if len(cs) < 2:
            continue

        # 2 — un nuancier d'accent et ses trois valeurs.
        if cs[0] in NUANCIERS and len(cs) >= 4:
            ident = NUANCIERS[cs[0]]
            attendus = accents.get(ident)
            donnes = tuple(_hex(c) for c in cs[1:4])
            if attendus is None:
                problemes.append((f"DESIGN.md:{numero}", cs[0],
                                  f"Nuancier « {cs[0]} » absent d'AccentTheme.swift."))
            elif None not in donnes:
                vus["accents"] += 1
                for role, donne, attendu in zip(("primary", "light", "tail"), donnes, attendus):
                    if donne != attendu:
                        problemes.append((
                            f"DESIGN.md:{numero}", f"{cs[0]} {role}",
                            f"Le document dit #{donne:06X}, AccentTheme.swift dit #{attendu:06X}."))
            continue

        # 3 — une famille de séance et sa teinte.
        if cs[0] in FAMILLES:
            attendu = tints.get(FAMILLES[cs[0]])
            donne = _jeton(cs[1])
            if donne and attendu and donne != attendu:
                problemes.append((
                    f"DESIGN.md:{numero}", cs[0],
                    f"Le document donne la teinte `{donne}`, SessionFamily.tint donne "
                    f"`{attendu}`. Une famille de séance est une information : sa couleur ne "
                    "peut pas différer selon où on la lit."))
            elif donne and attendu:
                vus["familles"] += 1
            continue

        nom = _jeton(cs[0])
        if not nom:
            continue

        # 1 — un jeton de couleur et ses deux valeurs.
        if nom in jetons:
            clair = _hex(cs[1])
            if clair is None:
                continue
            sombre = clair if (len(cs) > 2 and cs[2].strip().lower() in
                               ("les deux", "*les deux*")) else (_hex(cs[2]) if len(cs) > 2 else None)
            vus["jetons"] += 1
            for theme, donne in (("clair", clair), ("sombre", sombre)):
                if donne is None:
                    continue
                attendu = jetons[nom][theme]
                if not isinstance(attendu, int):
                    problemes.append((
                        f"DESIGN.md:{numero}", f"{nom} ({theme})",
                        f"Le document annonce #{donne:06X}, mais le jeton n'est pas une valeur "
                        f"littérale dans Colors.swift : il vaut `{attendu}`. Le document ne peut "
                        "pas figer ce que le code calcule."))
                elif donne != attendu:
                    problemes.append((
                        f"DESIGN.md:{numero}", f"{nom} ({theme})",
                        f"Le document dit #{donne:06X}, Colors.swift dit #{attendu:06X}."))
            continue

        # 4 — un cran de typographie ou d'icône, dans l'échelle du tableau courant.
        table = ECHELLES.get(echelle_courante, {})
        if nom in table:
            donne = _nombre(cs[1])
            if donne is not None:
                vus["crans"] += 1
                if abs(donne - table[nom]) > 0.001:
                    problemes.append((
                        f"DESIGN.md:{numero}", f"{echelle_courante}.{nom}",
                        f"Le document dit {donne:g}, Typography.swift dit {table[nom]:g}."))
        else:
            # 5 — une durée de mouvement.
            if nom in mouvement:
                donne = _nombre(cs[1].replace("ms", ""))
                if donne is not None:
                    vus["durees"] += 1
                    if abs(donne - mouvement[nom]) > 0.5:
                        problemes.append((
                            f"DESIGN.md:{numero}", f"RUMotion.{nom}",
                            f"Le document dit {donne:g} ms, Motion.swift dit "
                            f"{mouvement[nom]} ms."))

    # 6 — les trois questions sont-elles encore là ?
    for ancre in ANCRES:
        if ancre not in texte:
            problemes.append((
                "DESIGN.md", ancre,
                "Cette phrase a disparu. Les trois questions et le test final sont la raison "
                "d'être du fichier : un document de DA sans elles est une liste de valeurs."))

    # 7 — chaque garde cité existe-t-il ?
    for cite in sorted(set(re.findall(r"`(check_[a-z_0-9]+\.py)`", texte))):
        if not (RACINE / "ci_scripts" / cite).is_file():
            problemes.append((
                "DESIGN.md", cite,
                "Garde cité qui n'existe pas dans ci_scripts/. Le document promettrait une "
                "barrière que personne ne tient."))

    # Un document vidé de ses tableaux passerait tous les contrôles ci-dessus en silence.
    minimums = {"jetons": 12, "accents": 8, "familles": 7, "crans": 13, "durees": 6}
    for quoi, seuil in minimums.items():
        if vus[quoi] < seuil:
            problemes.append((
                "DESIGN.md", quoi,
                f"Seulement {vus[quoi]} ligne(s) de « {quoi} » vérifiée(s), au moins {seuil} "
                "attendue(s). Soit le tableau a été retiré, soit son format a changé et le garde "
                "ne le lit plus — dans les deux cas il ne garde plus rien."))

    return problemes


def main() -> int:
    problemes = ecarts()
    if problemes:
        print(f"{len(problemes)} écart(s) entre DESIGN.md et l'app :\n")
        for ou, quoi, raison in problemes:
            print(f"  • {ou} — {quoi}")
            print(f"      {raison}\n")
        print("DESIGN.md cite le code ; il ne le recopie pas. Corrigez le document, ou le code.")
        return 1
    print("DESIGN.md décrit l'app telle qu'elle est : palette, nuanciers, familles, échelles, "
          "durées, et les trois questions sont là.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
