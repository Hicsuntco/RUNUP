#!/usr/bin/env python3
"""L'état vide s'écrit une fois, dans `RUEmpty`.

# POURQUOI CE CONTRÔLE EXISTE

L'audit du 9 novembre 2026 : « Aucun composant d'état vide partagé. Zéro fichier ne porte un
`RUEmpty`. Chaque écran écrit le sien. » Le composant a été créé, six écrans l'ont adopté — et
seize endroits continuaient d'écrire le leur. Mesuré le 10 novembre :

    graisse du titre    .bold, .semibold, .medium      — trois valeurs
    couleur du message  text3, text2                   — deux valeurs
    corps du texte      .small, .body                  — deux valeurs
    taille de l'icône   .hero (28), .xlarge (22)       — deux valeurs

Deux couleurs et trois graisses pour la même phrase — « il n'y a rien ici » — c'est la définition
d'un système de design qu'on contourne. Et le composant partagé était LUI-MÊME le seul à ne pas
utiliser `RUIconSize.hero`, dont la documentation dit : « l'icône d'un état vide, celle qu'on voit
avant même de lire ». Les écrans écrits à la main, eux, l'utilisaient.

# CE QU'IL REGARDE

1. LE BLOC écrit à la main. Sa signature est fiable : une `Image(systemName:)` en `.hero` ou
   `.xlarge`, teintée `RUColor.text3`, avec un `Text` dans les lignes qui suivent. C'est la
   composition que `RUEmpty(.bloc)` remplace, et rien d'autre dans l'app ne lui ressemble.

2. LE SITE D'APPEL QUI REPREND UNE DÉCISION DU COMPOSANT. Un `RUEmpty` suivi de `.font(`,
   `.foregroundColor(`, `.multilineTextAlignment(` ou `.lineSpacing(` annule ce que le composant
   décide — c'est la divergence qui revient par la porte de service. Un cas existait :
   `FriendsView` recentrait une `.ligne`, alignée à gauche par construction.

3. LE COMPOSANT LUI-MÊME. Il doit garder `RUIconSize.hero` et `RUColor.text3` : s'il dérive, les
   vingt-quatre appels dérivent avec lui, et ce contrôle ne dirait rien.

# CE QU'IL NE REGARDE PAS, ET POURQUOI JE NE L'AI PAS INVENTÉ

LA FORME `.ligne` N'A AUCUNE SIGNATURE DÉTECTABLE. Une phrase posée sous un en-tête de section
ressemble, caractère pour caractère, à n'importe quelle autre phrase secondaire. La règle la plus
large que j'aie essayée — un `Text` teinté `text3` dans une branche qui teste `isEmpty` — a rendu
TRENTE-CINQ endroits dont environ six vrais : des `!x.isEmpty` qui testent une présence, des
`isValid`, des URL, des bios. Une règle à trente dispenses ne décrit pas un défaut, elle le noie,
et on apprend à ignorer son rouge.

Les seize conversions ont donc été faites en LISANT, et c'est assumé. Ce script garde ce qui se
garde, et le dit plutôt que de faire semblant de garder le reste.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from swift import sans_commentaires

COMPOSANT = RACINE / "RunUp/Views/Components/EmptyStateView.swift"
VUES = RACINE / "RunUp/Views"

GROSSE_ICONE = re.compile(r"RUFont\.icone\(\.(hero|xlarge)\b")
STYLE_REPRIS = re.compile(r"\.(font|foregroundColor|foregroundStyle|multilineTextAlignment|lineSpacing)\(")

# LES DISPENSES SONT NOMMÉES, AVEC LEUR RAISON, et la raison doit tenir en une phrase complète.
# Une dispense sans raison est une dispense qu'on reconduit sans la relire.
DISPENSES = {
    ("ClubManagementView.swift", "photo"):
        "Le cadre de la photo de couverture d'un club : un emplacement d'image à remplir, pas une "
        "phrase qui annonce qu'il n'y a rien à montrer. Le bouton d'à côté ouvre la galerie.",
}


def bloc_a_la_main():
    """1. Un bloc d'état vide composé à la main, hors du composant."""
    defauts = []
    for f in sorted(VUES.rglob("*.swift")):
        if f.name == COMPOSANT.name:
            continue
        # DEUX LECTURES DU MÊME FICHIER, ET IL FAUT LES DEUX.
        #
        # `sans_commentaires` efface aussi le CONTENU des chaînes — c'est voulu, et pour une
        # bonne raison : la moitié des fichiers du dépôt nomment dans un commentaire ce qu'un
        # contrôle refuse. Mais le nom du symbole, qui désigne la dispense, est précisément un
        # contenu de chaîne. Le premier jet le cherchait dans la version effacée et ne trouvait
        # jamais rien : la seule dispense du fichier ne s'appliquait pas, et le contrôle refusait
        # un cadre de photo de couverture.
        lignes = sans_commentaires(f.read_text()).splitlines()
        brutes = f.read_text().splitlines()
        for i, l in enumerate(lignes):
            if "Image(systemName:" not in l:
                continue
            fenetre = "\n".join(lignes[i:min(len(lignes), i + 7)])
            if not GROSSE_ICONE.search(fenetre) or "RUColor.text3" not in fenetre:
                continue
            if not re.search(r"\bText\(", fenetre):
                continue
            symbole = re.search(r'Image\(systemName:\s*"([^"]+)"',
                                brutes[i] if i < len(brutes) else "")
            cle = (f.name, symbole.group(1) if symbole else "")
            raison = DISPENSES.get(cle)
            if raison and len(raison) >= 60:
                continue
            defauts.append(
                f"{f.name}:{i + 1} compose un état vide à la main — grande icône teintée "
                f"`text3` au-dessus d'un texte. C'est `RUEmpty(.bloc)`. Si ce n'en est pas un, "
                f"ajoutez-le à `DISPENSES` avec sa raison (au moins 60 caractères).")
    return defauts


def arguments(source, ouvrante):
    """Les arguments d'un appel, parenthèses équilibrées, depuis la `(` donnée."""
    niveau = 0
    for j in range(ouvrante, len(source)):
        if source[j] == "(":
            niveau += 1
        elif source[j] == ")":
            niveau -= 1
            if niveau == 0:
                return j
    return len(source) - 1


def style_repris():
    """2. Un site d'appel qui annule une décision du composant."""
    defauts = []
    for f in sorted(VUES.rglob("*.swift")):
        if f.name == COMPOSANT.name:
            continue
        src = sans_commentaires(f.read_text())
        for m in re.finditer(r"\bRUEmpty\s*\(", src):
            fin = arguments(src, m.end() - 1)
            # Les modificateurs chaînés qui suivent l'appel, tant qu'ils commencent par un point.
            suite = []
            for ligne in src[fin + 1:fin + 400].split("\n")[:5]:
                if ligne.strip().startswith("."):
                    suite.append(ligne)
                elif ligne.strip():
                    break
            if STYLE_REPRIS.search("\n".join(suite)):
                numero = src[:m.start()].count("\n") + 1
                defauts.append(
                    f"{f.name}:{numero} : le site d'appel restyle `RUEmpty` "
                    f"({STYLE_REPRIS.search(chr(10).join(suite)).group(1)}). C'est la divergence "
                    f"qui revient par la porte de service : si la forme ne convient pas, c'est "
                    f"l'autre forme qu'il faut (`.bloc` est centré, `.ligne` est alignée à gauche).")
    return defauts


def composant_fidele():
    """3. Le composant garde le cran d'icône que le système nomme pour lui."""
    if not COMPOSANT.exists():
        return [f"{COMPOSANT.name} est absent : il n'y a plus de composant d'état vide partagé."]
    src = sans_commentaires(COMPOSANT.read_text())
    defauts = []
    if "RUFont.icone(.hero)" not in src:
        defauts.append(
            f"{COMPOSANT.name} n'utilise plus `RUFont.icone(.hero)`. `RUIconSize.hero` vaut 28 et "
            f"sa documentation dit « l'icône d'un état vide, celle qu'on voit avant même de "
            f"lire » : c'est le cran que le système nomme pour ce composant.")
    if "RUColor.text3" not in src:
        defauts.append(f"{COMPOSANT.name} n'utilise plus `RUColor.text3` pour le message.")
    for forme in ("case bloc", "case ligne"):
        if forme not in src:
            defauts.append(f"{COMPOSANT.name} ne déclare plus `{forme}` : ce contrôle parle de "
                           f"deux formes qui n'existent plus.")
    return defauts


def main():
    defauts = bloc_a_la_main() + style_repris() + composant_fidele()
    if defauts:
        for d in defauts:
            print("DÉFAUT", d)
        return 1
    appels = sum(len(re.findall(r"\bRUEmpty\s*\(", sans_commentaires(f.read_text())))
                 for f in VUES.rglob("*.swift") if f.name != COMPOSANT.name)
    fichiers = sum(1 for f in VUES.rglob("*.swift")
                   if f.name != COMPOSANT.name and "RUEmpty(" in f.read_text())
    print(f"États vides : {appels} appels à RUEmpty dans {fichiers} fichiers, "
          f"aucun bloc écrit à la main, aucun site d'appel qui restyle.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
