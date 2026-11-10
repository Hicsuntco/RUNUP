#!/usr/bin/env python3
"""Une liste sans borne, dans un défilement, se construit paresseusement.

# POURQUOI CE CONTRÔLE EXISTE, ET POURQUOI L'ITEM D'ORIGINE ÉTAIT MAL POSÉ

`PHASE2.md` disait : « 63 fichiers utilisent `ForEach`, 11 seulement une liste paresseuse. » Ce
comptage ne mesure rien. Un `ForEach` sur les sept jours de la semaine n'a aucun besoin d'être
paresseux, et un fichier qui en porte trois ne compte pas pour trois défauts.

Le critère qui compte est la position : un `ForEach` **sous un `ScrollView`**, sans `LazyVStack`,
`LazyHStack`, `LazyVGrid` ni `List` entre les deux, construit TOUTES ses lignes à l'ouverture de
l'écran — y compris celles qu'on ne verra jamais.

Mesuré le 10 novembre 2026 : 133 `ForEach` dans 63 fichiers, et **dix** dans cette position. Dont
sept qui parcourent `allCases` ou `0..<7`.

Et les deux écrans que l'item nommait — le fil du club et l'historique — étaient déjà réglés
depuis longtemps : `LazyVStack` pour le premier, avec son commentaire sur les cinquante activités
que le serveur renvoie, une `List` pour le second. Il restait DEUX listes réellement sans borne,
et chacune portait un avatar à décoder par ligne.

# CE QUI COMPTE COMME BORNÉ

Une source dont la taille se lit DANS LE CODE : `X.allCases` — une énumération a le nombre de cas
qu'elle déclare — ou un intervalle littéral comme `0..<7`. Rendre ces listes paresseuses ne
gagnerait rien et compliquerait des mises en page qui marchent.

Tout le reste est supposé sans borne, parce qu'on ne peut pas prouver le contraire en lisant une
ligne. Une collection bornée par une règle de produit — « un club peut proposer huit créneaux »,
« le catalogue compte une trentaine de badges » — n'est pas lisible ici : elle passe par une
DISPENSE nommée, avec sa raison écrite.

# CE QU'IL NE REGARDE PAS

Le coût réel d'une ligne. Dix lignes de texte nu ne valent pas dix lignes à avatar, et ce script
ne sait pas la différence. Il ne prétend pas mesurer une performance : il constate qu'une liste
sans borne est construite d'un bloc, ce qui est une décision, et demande qu'elle soit prise
exprès.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from swift import sans_commentaires

DOSSIERS = ["RunUp", "RunUpWidgets", "RunUpWatch"]

OUVRE_DEFILEMENT = re.compile(r"\bScrollView\s*[({]")
OUVRE_PARESSEUX = re.compile(r"\bLazy[HV](Stack|Grid)\b")
OUVRE_LISTE = re.compile(r"\bList\s*[({]")
FOREACH = re.compile(r"\bForEach\s*[({]")

#: Une source dont la taille se lit dans le code.
BORNEE = re.compile(r"\.allCases\b|\b\d+\s*\.\.<\s*\d+|\b\d+\s*\.\.\.\s*\d+")

#: Les collections bornées par une règle de produit, que la syntaxe ne peut pas montrer.
#: Chaque dispense porte sa raison, et la raison doit tenir en une phrase complète.
DISPENSES = {
    ("ClubEventsSection.swift", "groupes"):
        "Les groupes d'allure d'une sortie de club : le produit en propose huit au plus, et le "
        "commentaire de la vue le dit. C'est une bande horizontale de pastilles, pas une liste.",
    ("ClubManagementView.swift", "badges"):
        "Le catalogue de badges, borné par `ClubBadgeCatalog.all` — une trentaine d'entrées, en "
        "bande horizontale à tuiles de largeur fixe. Rien n'y croît avec l'usage.",
    ("PublicProfileView.swift", "gagnes"):
        "Les badges gagnés par quelqu'un : un sous-ensemble du catalogue, donc borné par lui. "
        "Même bande horizontale, mêmes tuiles de largeur fixe.",
}


def source_du_foreach(ligne: str) -> str:
    """Le premier argument d'un `ForEach`, tel qu'il est écrit."""
    m = re.search(r"\bForEach\s*\(", ligne)
    if not m:
        return ""
    reste = ligne[m.end():]
    niveau, out = 1, []
    for c in reste:
        if c == "(":
            niveau += 1
        elif c == ")":
            niveau -= 1
            if niveau == 0:
                break
        elif c == "," and niveau == 1:
            break
        out.append(c)
    return "".join(out).strip()


def premier_nom(source: str) -> str:
    """Le nom qui désigne la collection, pour la clé de dispense."""
    m = re.search(r"[A-Za-z_]\w*", source)
    return m.group(0) if m else ""


def controler():
    defauts, regardes = [], 0
    for dossier in DOSSIERS:
        for f in sorted((RACINE / dossier).rglob("*.swift")):
            lignes = sans_commentaires(f.read_text()).splitlines()
            pile: list[tuple[int, str]] = []
            for i, ligne in enumerate(lignes):
                indentation = len(ligne) - len(ligne.lstrip())
                while pile and indentation <= pile[-1][0]:
                    pile.pop()
                if OUVRE_DEFILEMENT.search(ligne):
                    pile.append((indentation, "defilement"))
                elif OUVRE_PARESSEUX.search(ligne):
                    pile.append((indentation, "paresseux"))
                elif OUVRE_LISTE.search(ligne):
                    pile.append((indentation, "liste"))
                elif FOREACH.search(ligne):
                    genres = [g for _, g in pile]
                    if "defilement" not in genres or "paresseux" in genres or "liste" in genres:
                        continue
                    regardes += 1
                    source = source_du_foreach(ligne)
                    if BORNEE.search(source):
                        continue
                    raison = DISPENSES.get((f.name, premier_nom(source)))
                    if raison and len(raison) >= 60:
                        continue
                    defauts.append(
                        f"{f.name}:{i + 1} : `ForEach({source})` est sous un `ScrollView` sans "
                        f"conteneur paresseux. Toutes ses lignes se construisent à l'ouverture de "
                        f"l'écran, y compris celles qu'on ne verra pas. Si la collection est "
                        f"bornée par une règle de produit, ajoutez-la à `DISPENSES` avec sa "
                        f"raison (au moins 60 caractères).")
    if regardes == 0:
        defauts.append(
            "Aucun `ForEach` sous un `ScrollView` n'a été trouvé. Soit il n'y en a plus, soit la "
            "lecture de l'imbrication a cessé de fonctionner — et ce contrôle ne regarde plus "
            "rien, ce qui ressemble trait pour trait à un dépôt sain.")
    return defauts, regardes


def main():
    defauts, regardes = controler()
    if defauts:
        for d in defauts:
            print("DÉFAUT", d)
        return 1
    print(f"Listes : {regardes} ForEach sous un défilement, tous bornés dans le code "
          f"ou dispensés avec leur raison ({len(DISPENSES)} dispenses).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
