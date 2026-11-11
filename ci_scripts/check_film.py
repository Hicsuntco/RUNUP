#!/usr/bin/env python3
"""Le film se déclare, les photos non — et chacun garde ce qu'il lui faut.

# POURQUOI CE CONTRÔLE EXISTE

La campagne 166 a photographié `4-club.png` — une des six images livrées à Apple — PENDANT que le
tracé de la sortie se dessinait. La tête lumineuse de l'animation était figée au milieu du trait,
et la ligne s'arrêtait avant sa fin. La campagne 165, à six heures d'écart, l'avait eu fini.
Personne ne choisit : c'est le minutage qui décide de ce qu'Apple reçoit.

L'app fige donc ses animations en mode démonstration — sauf quand elle est FILMÉE, parce qu'un
film d'aperçu n'a d'intérêt que par son mouvement. La distinction tient à un seul argument de
lancement, `--film`, posé par `ApercuUITests` et par lui seul.

# POURQUOI LE DRAPEAU EST SUR LE FILM ET PAS SUR LES PHOTOS

Parce que les deux oublis ne coûtent pas la même chose.

Oublier de déclarer une photo laisserait les animations jouer : le défaut revient EN SILENCE, et
ne se voit qu'en comparant deux campagnes prises à des heures différentes — c'est-à-dire presque
jamais, et c'est exactement ainsi qu'il est arrivé.

Oublier de déclarer le film donne un film sans mouvement : ça se voit en le regardant. Mais
personne ne regarde le film à chaque campagne, d'où ce contrôle.

# CE QU'IL VÉRIFIE, ET CE QU'IL NE PEUT PAS VÉRIFIER

Trois faits, lisibles dans le code :

  1. `ApercuUITests` lance l'app avec `--film` ;
  2. `CapturesUITests` ne le fait PAS ;
  3. l'app lit ce drapeau et ne fige que si elle ne filme pas.

Ce qu'il ne sait pas faire : dire si l'image est effectivement posée. Aucun script ne lit une
animation. La preuve, elle, est la comparaison de deux campagnes prises à des heures différentes.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DRAPEAU = "--film"

FICHIERS = {
    "film": RACINE / "RunUpUITests/ApercuUITests.swift",
    "photos": RACINE / "RunUpUITests/CapturesUITests.swift",
    "app": RACINE / "RunUp/RunUpApp.swift",
    "mode": RACINE / "RunUp/Shared/Demonstration.swift",
    "lecture": RACINE / "RunUp/Services/CaptureSeed.swift",
}


def code_nu(source):
    """Le code seul, sans les commentaires.

    SANS CECI, CE CONTRÔLE NE VOIT RIEN. Sa première version cherchait `--film` dans le fichier
    entier — or le commentaire qui explique le drapeau contient le drapeau, et celui qui explique
    la `transaction` contient `animationsFigees`. Retirer le vrai code laissait donc le contrôle
    vert, parce qu'il relisait sa propre explication. Deux des cas du banc tiennent cette
    correction, et c'est le même piège que `check_vides` avait rencontré.
    """
    source = re.sub(r"//[^\n]*", "", source)
    return re.sub(r"/\*.*?\*/", "", source, flags=re.S)


def lire(cle):
    chemin = FICHIERS[cle]
    if not chemin.is_file():
        return None
    return code_nu(chemin.read_text())


def controler():
    """Les plaintes, en clair. Liste vide = tout va bien."""
    plaintes = []
    sources = {cle: lire(cle) for cle in FICHIERS}
    for cle, texte in sources.items():
        if texte is None:
            plaintes.append(f"{FICHIERS[cle].relative_to(RACINE)} est introuvable : "
                            f"le contrôle ne peut rien vérifier.")
    if plaintes:
        return plaintes

    if DRAPEAU not in sources["film"]:
        plaintes.append(
            f"ApercuUITests ne lance plus l'app avec `{DRAPEAU}` : le film d'aperçu sera figé, "
            f"et un film sans mouvement ne se voit qu'en le regardant.")

    if DRAPEAU in sources["photos"]:
        plaintes.append(
            f"CapturesUITests pose `{DRAPEAU}` : les animations joueront pendant les photos, et "
            f"une capture prise en plein vol part chez Apple.")

    if "Demonstration.filmer()" not in sources["app"]:
        plaintes.append(
            "RunUpApp n'allume plus le mode film : le drapeau est posé mais personne ne l'écoute.")

    if "filmDemande" not in sources["lecture"]:
        plaintes.append("CaptureSeed ne lit plus `--film`.")

    # La règle elle-même : figer quand on photographie, pas quand on filme.
    regle = re.search(r"animationsFigees:\s*Bool\s*\{([^}]*)\}", sources["mode"])
    if not regle:
        plaintes.append("`Demonstration.animationsFigees` n'existe plus.")
    elif "enCours" not in regle.group(1) or "!filme" not in regle.group(1):
        plaintes.append(
            "`animationsFigees` ne dit plus « en démonstration ET pas en train de filmer » : "
            f"elle vaut « {regle.group(1).strip()} ».")

    if ".transaction" not in sources["app"] or "animationsFigees" not in sources["app"]:
        plaintes.append(
            "La racine des vues ne fige plus rien : c'est la `transaction` qui vide l'animation "
            "de tout ce qui passe en dessous, et sans elle chaque vue retrouve la sienne.")

    return plaintes


def main():
    plaintes = controler()
    for p in plaintes:
        print(f"  · {p}")
    if plaintes:
        print(f"\ncheck_film : {len(plaintes)} problème(s).")
        return 1
    print("check_film : le film se déclare, les photos sont figées, et la racine applique la règle.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
