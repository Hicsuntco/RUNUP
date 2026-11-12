#!/usr/bin/env python3
"""Lire du Swift sans se faire piéger par ses commentaires et ses chaînes.

# POURQUOI CE FICHIER EXISTE

`check_degrade.py` et `check_verre.py` en portaient chacun une copie, et `check_manifeste.py`
allait en écrire une troisième. Trois copies d'une fonction qui décide ce qu'un contrôle VOIT,
c'est trois façons de diverger sur ce qu'il voit — et la règle 4 du brief dit qu'une valeur
écrite deux fois est un défaut.

# CE QUE ÇA REND, ET POURQUOI C'EST NÉCESSAIRE

La moitié des fichiers de ce dépôt NOMMENT dans un commentaire ce qu'un contrôle refuse :
« c'était un `LinearGradient` et il est parti », « il portait un `.ultraThinMaterial` ». Compter
ces mentions ferait refuser un fichier pour la phrase qui raconte sa correction.

Les chaînes sont effacées pour la même raison, et remplacées par une espace plutôt que
supprimées : un `"texte"` au milieu d'une expression doit laisser quelque chose derrière lui,
sinon deux identifiants se recollent.
"""


def sans_commentaires(source: str) -> str:
    """Le code seul : ni `//`, ni `/* */`, ni le contenu des chaînes."""
    out, i, n = [], 0, len(source)
    while i < n:
        c = source[i]
        if c == "/" and i + 1 < n and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and source[i + 1] == "*":
            i += 2
            while i + 1 < n and not (source[i] == "*" and source[i + 1] == "/"):
                i += 1
            i += 2
        elif c == '"':
            out.append(" ")
            i += 1
            while i < n and source[i] != '"':
                i += 2 if source[i] == "\\" else 1
            i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def sans_commentaires_seuls(source: str) -> str:
    """Le code ET les chaînes, sans les commentaires.

    `sans_commentaires` efface le contenu des chaînes, et c'est ce qu'il faut à un contrôle qui
    cherche un `LinearGradient` : un nom de type cité dans un message d'erreur n'est pas un
    emploi. Mais certaines déclarations PORTENT leur identité dans une chaîne —
    `AccentTheme(id: "rose", …)` — et les effacer revient à ne plus savoir de quel nuancier on
    parle. `couleurs.accents()` a besoin de celle-ci.

    Les commentaires partent dans les deux cas, pour la même raison : ce dépôt nomme dans ses
    commentaires ce que ses contrôles refusent.
    """
    out, i, n = [], 0, len(source)
    while i < n:
        c = source[i]
        if c == "/" and i + 1 < n and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and source[i + 1] == "*":
            i += 2
            while i + 1 < n and not (source[i] == "*" and source[i + 1] == "/"):
                i += 1
            i += 2
        elif c == '"':
            out.append(c)
            i += 1
            while i < n and source[i] != '"':
                if source[i] == "\\" and i + 1 < n:
                    out.append(source[i]); i += 1
                out.append(source[i]); i += 1
            out.append('"')
            i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)
