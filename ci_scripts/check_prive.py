#!/usr/bin/env python3
"""Une `private func` appelée depuis un autre fichier ne compile pas.

# POURQUOI CE CONTRÔLE EXISTE

Le 10 novembre 2026, la découpe de `ClubView` a sorti la carte du défi dans son propre fichier.
La carte appelait `daysLeft(until:)`, une `private func` restée dans `ClubView`. En Swift,
`private` au niveau d'un membre porte sur la déclaration englobante et ses extensions DANS LE
MÊME FICHIER : l'appel depuis le nouveau fichier ne se résout pas, et le projet ne compile plus.

Toute la chaîne était verte. Aucun des contrôles ne résout un symbole Swift, et il n'y en aura
pas un qui le fasse — ça demanderait un compilateur. Mais ce défaut-là, précis, se constate sans
rien compiler : un nom déclaré `private` dans un seul fichier, appelé nu depuis un autre, ne peut
pas se résoudre. Ce n'est pas une suspicion, c'est une erreur de compilation certaine.

Mesuré sur les 225 fichiers Swift de `RunUp/` après correction : **zéro**. Le contrôle part donc
d'un arbre propre, et le seul cas qu'il ait jamais eu à signaler est celui qui l'a fait écrire.

# CE QU'IL REGARDE, ET POURQUOI SI ÉTROIT

Seulement les `func`, et seulement les appels de la forme `nom(`.

La première version regardait aussi les `var`, `let` et les types, sur une référence nue au nom.
Elle a rendu **112 signalements, tous faux**. La raison est que, en Swift, un identifiant nu
n'est pas forcément une référence : `RoundedRectangle(cornerRadius: 12)` contient `cornerRadius`
nu, et c'est une ÉTIQUETTE D'ARGUMENT, pas la propriété privée du même nom déclarée dans
`AppMarkView.swift`. Même chose pour `opacity`, `filter`, `columns`, `password`. Un contrôle qui
signale 112 fois quand il y a zéro défaut n'est pas prudent, il est inutilisable : on apprend à
ne plus le lire.

Exiger la parenthèse ouvrante écarte les étiquettes, et exiger que rien ne précède le nom écarte
les appels de membre (`objet.daysLeft(…)`, qui se résout sur le type de `objet`, pas ici).

# CE QU'IL NE VOIT PAS, ET IL FAUT LE SAVOIR

· les propriétés et types privés : ci-dessus, le coût en faux positifs est prohibitif ;
· un nom déclaré DEUX FOIS dans la cible : l'appel pourrait se résoudre sur l'autre, le script
  passe son tour plutôt que d'accuser à tort ;
· une fermeture locale de même nom (`let calcul = { … }` puis `calcul(x)`) : elle fait partie des
  déclarations comptées, donc le nom est vu comme déclaré ailleurs et le cas est écarté ;
· tout le reste de ce que fait un compilateur. Ce script constate UNE impossibilité, pas la
  compilabilité d'un fichier.

Les cibles sont comparées séparément (`RunUp`, `RunUpWatch`, les tests) : ce sont des modules
distincts, où n'importe quel appel entre fichiers échoue pour une autre raison que `private`.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
CIBLES = ["RunUp", "RunUpWatch", "RunUpTests", "RunUpUITests"]
DECLARATION = r"(?:func|var|let|struct|enum|class|typealias|actor|protocol|case)"


def sans_commentaires(source):
    """Le code seul : sans commentaires, sans texte de chaîne — MAIS avec les interpolations.

    Vider les chaînes à la `re.sub` effacerait `\\(daysLeft(until: …))` avec le texte qui
    l'entoure, et c'est justement là que vivait le défaut qui a fait écrire ce script :
    `String(localized: "J-\\(daysLeft(until: challenge.endDate))")`. Le code d'une interpolation
    est du code, il s'exécute, il se résout — il doit rester.
    """
    source = re.sub(r"//[^\n]*", "", source)
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    sortie, i, n = [], 0, len(source)
    while i < n:
        if source.startswith('"""', i):
            i = _fin_de_chaine(source, i + 3, '"""', sortie)
        elif source[i] == '"':
            i = _fin_de_chaine(source, i + 1, '"', sortie)
        else:
            sortie.append(source[i])
            i += 1
    return "".join(sortie)


def _fin_de_chaine(source, i, cloture, sortie):
    """Avance jusqu'après `cloture`, en recopiant le code des interpolations rencontrées."""
    n = len(source)
    while i < n:
        if source.startswith(cloture, i):
            return i + len(cloture)
        if source[i] == "\\":
            if source.startswith("\\(", i):
                i = _fin_dinterpolation(source, i + 2, sortie)
            else:
                i += 2  # une échappée ordinaire : \n, \", \\
            continue
        i += 1
    return n


def _fin_dinterpolation(source, i, sortie):
    """Recopie le code jusqu'à la parenthèse qui ferme l'interpolation, imbrications comprises."""
    profondeur, n = 1, len(source)
    sortie.append(" ")
    while i < n:
        caractere = source[i]
        if caractere == '"':
            # Une chaîne DANS une interpolation : son texte ne compte pas, ses
            # interpolations si. Même traitement, un cran plus bas.
            i = _fin_de_chaine(source, i + 1, '"', sortie)
            continue
        if caractere == "(":
            profondeur += 1
        elif caractere == ")":
            profondeur -= 1
            if profondeur == 0:
                sortie.append(" ")
                return i + 1
        sortie.append(caractere)
        i += 1
    return n


def fonctions_privees(code):
    """Les noms déclarés `private func` ou `fileprivate func` dans ce code."""
    return set(re.findall(r"\b(?:private|fileprivate)\s+(?:static\s+)?func\s+(\w+)", code))


def noms_declares(code):
    """Tous les noms que ce code déclare, quelle que soit la sorte de déclaration."""
    return set(re.findall(rf"\b{DECLARATION}\s+(\w+)", code))


def appelle_nu(code, nom):
    """Ce code appelle-t-il `nom(` sans rien devant — ni point, ni autre lettre ?"""
    return re.search(rf"(?<![.\w]){re.escape(nom)}\s*\(", code) is not None


def defauts(textes):
    """Les appels impossibles, dans un dictionnaire {chemin: code} d'UNE SEULE cible."""
    privees, compte = {}, {}
    for chemin, code in textes.items():
        for nom in fonctions_privees(code):
            privees.setdefault(nom, set()).add(chemin)
        for nom in noms_declares(code):
            compte[nom] = compte.get(nom, 0) + 1
    trouves = []
    for nom, proprietaires in sorted(privees.items()):
        # Déclaré deux fois : l'appel pourrait se résoudre sur l'autre. On passe.
        if len(proprietaires) > 1 or compte.get(nom, 0) > 1:
            continue
        proprietaire = next(iter(proprietaires))
        for chemin, code in sorted(textes.items()):
            if chemin != proprietaire and appelle_nu(code, nom):
                trouves.append((nom, proprietaire, chemin))
    return trouves


def lire(cible):
    """Les fichiers d'une cible, lus depuis la racine du dépôt — pas depuis le dossier courant.

    Les cas de `test_prive.py` tournent depuis `ci_scripts/`, où `RunUp/` n'existe pas en
    relatif : le contrôle y rendait « aucun fichier Swift trouvé » et passait pour vert.
    """
    dossier = RACINE / cible
    if not dossier.is_dir():
        return {}
    return {str(f.relative_to(RACINE)): sans_commentaires(f.read_text())
            for f in sorted(dossier.rglob("*.swift"))}


def main():
    tous, fichiers = [], 0
    for cible in CIBLES:
        textes = lire(cible)
        fichiers += len(textes)
        tous += defauts(textes)
    if not fichiers:
        print("check_prive : aucun fichier Swift trouvé — le contrôle ne vérifie rien.")
        return 1
    for nom, proprietaire, appelant in tous:
        print(f"{appelant}: appelle `{nom}(`, déclarée `private` dans {proprietaire}.")
        print("  → `private` ne franchit pas le fichier : déplace la fonction chez son appelante,")
        print("    ou retire `private` si elle est vraiment partagée.")
    if tous:
        print(f"\ncheck_prive : {len(tous)} appel(s) impossible(s) sur {fichiers} fichiers.")
        return 1
    print(f"check_prive : {fichiers} fichiers Swift, aucun appel d'une `private func` hors de son fichier.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
