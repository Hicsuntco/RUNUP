#!/usr/bin/env python3
"""`RunUp/Shared/` est compilé dans l'extension widget : ce dossier n'a pas droit aux types de l'app.

# LA PANNE, DEUX FOIS

`RunUp/Shared/` n'est pas une bibliothèque que la cible iOS prêterait au widget : le dossier
ENTIER est listé dans les sources de `RunUpWidgets`, qui ne compile rien d'autre de `RunUp/`.
Un fichier posé là voit donc `RunUpWidgets/` et les autres fichiers de `Shared/` — et RIEN de
`RunUp/Models`, `RunUp/DesignSystem`, `RunUp/ViewModels`, `RunUp/Services`.

Le piège est qu'en écrivant du code pour l'app, tout compile sous les yeux : la cible iOS, elle,
voit bien tout. L'erreur ne tombe que dans la passe du widget, donc après le push, donc un quart
d'heure plus tard, et elle annule le build entier :

    build 250 : PlanRecap.swift     → cannot find type 'OnboardingViewModel' in scope
    build 278 : DailyGoalsSnapshot  → cannot find 'AccentTheme' in scope

Deux fois la même cause, à des semaines d'écart. Ce script la rend visible en une seconde, en
local, avant le push.

# CE QUE LE SCRIPT FAIT

1. Il lit `project.yml` pour savoir quels fichiers de `Shared/` chaque cible compile réellement
   (le dossier moins ses `excludes` pour le widget ; des fichiers nommés un par un pour la
   montre). Il ne devine pas : si le `project.yml` change, le périmètre change avec lui.
2. Il relève les types déclarés dans `RunUp/` HORS `Shared/` — ceux qui n'existent pas dans ces
   cibles — et les types déclarés dans `Shared/` et dans les dossiers propres aux cibles.
3. Dans chaque fichier partagé, commentaires et chaînes retirés, il cherche les références aux
   premiers. Chacune est une erreur de compilation garantie dans cette cible.

# LES DEUX ISSUES, QUAND ÇA SONNE

Ou le fichier n'a rien à faire dans `Shared/` (cas de `PlanRecap`, déplacé dans `ViewModels/`),
ou la référence doit sauter (cas d'`AccentTheme.defaultID`, recopié en littéral `"rose"` avec le
commentaire qui dit pourquoi). Ce qu'il ne faut PAS faire, c'est tirer le modèle de données de
l'app dans une extension pour satisfaire une seule ligne.
"""

import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent

# Les dossiers de `RunUp/` qui ne sont PAS compilés dans les cibles secondaires.
APP_SEULEMENT = "RunUp"
PARTAGE = "RunUp/Shared"

DECLARATION = re.compile(
    r"^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+|final\s+|@\w+\s+)*"
    r"(?:class|struct|enum|protocol|actor|typealias)\s+([A-Z]\w*)",
    re.MULTILINE,
)
# Une extension de type n'est pas une déclaration, mais elle prouve que le type est visible
# dans la cible où le fichier compile — inutile de la relever ici, la déclaration suffit.

REFERENCE = re.compile(r"(?<![\w.])([A-Z]\w*)")


def sans_commentaires_ni_chaines(source: str) -> str:
    """Retire les chaînes, les commentaires de ligne et les blocs `/* */` (imbriqués compris)."""
    sortie = []
    i = 0
    n = len(source)
    profondeur_bloc = 0
    while i < n:
        if profondeur_bloc:
            if source.startswith("/*", i):
                profondeur_bloc += 1
                i += 2
            elif source.startswith("*/", i):
                profondeur_bloc -= 1
                i += 2
            else:
                if source[i] == "\n":
                    sortie.append("\n")
                i += 1
            continue
        if source.startswith("/*", i):
            profondeur_bloc = 1
            i += 2
        elif source.startswith("//", i):
            while i < n and source[i] != "\n":
                i += 1
        elif source.startswith('"""', i):
            i += 3
            while i < n and not source.startswith('"""', i):
                if source[i] == "\n":
                    sortie.append("\n")
                i += 1
            i += 3
        elif source[i] == '"':
            i += 1
            while i < n and source[i] != '"':
                if source[i] == "\\":
                    i += 1
                i += 1
            i += 1
            sortie.append('""')
        else:
            sortie.append(source[i])
            i += 1
    return "".join(sortie)


def fichiers_partages_par_cible(project_yml: str) -> dict:
    """Quels fichiers de `RunUp/Shared` chaque cible secondaire compile, d'après `project.yml`.

    Deux formes dans le fichier : `- path: RunUp/Shared` (le dossier, avec d'éventuels
    `excludes:`) et `- path: RunUp/Shared/X.swift` (un fichier nommé).
    """
    cibles = {}
    cible = None
    dans_sources = False
    attend_excludes = False
    lignes = project_yml.splitlines()
    for ligne in lignes:
        entete = re.match(r"^  (\w+):\s*$", ligne)
        if entete:
            cible = entete.group(1)
            dans_sources = False
            attend_excludes = False
            continue
        if cible is None:
            continue
        if re.match(r"^    sources:\s*$", ligne):
            dans_sources = True
            continue
        if re.match(r"^    \w+:", ligne):
            dans_sources = False
            attend_excludes = False
            continue
        if not dans_sources:
            continue
        chemin = re.match(r"^      - path:\s*(\S+)", ligne)
        if chemin:
            attend_excludes = False
            valeur = chemin.group(1)
            if valeur == PARTAGE:
                tous = sorted(p.name for p in (RACINE / PARTAGE).glob("*.swift"))
                cibles.setdefault(cible, {"fichiers": set(), "dossier": True})
                cibles[cible]["fichiers"].update(tous)
                attend_excludes = True
            elif valeur.startswith(PARTAGE + "/"):
                cibles.setdefault(cible, {"fichiers": set(), "dossier": False})
                cibles[cible]["fichiers"].add(Path(valeur).name)
            continue
        if attend_excludes:
            exclu = re.match(r'^\s+- "([^"]+)"\s*$', ligne)
            if exclu:
                cibles[cible]["fichiers"].discard(exclu.group(1))
    return cibles


def types_declares(dossier: Path, recursif: bool = True) -> dict:
    """Nom de type → chemin du fichier qui le déclare."""
    trouves = {}
    motif = "**/*.swift" if recursif else "*.swift"
    for fichier in sorted(dossier.glob(motif)):
        source = sans_commentaires_ni_chaines(fichier.read_text(encoding="utf-8"))
        for nom in DECLARATION.findall(source):
            trouves.setdefault(nom, fichier)
    return trouves


def verifier() -> list:
    project_yml = (RACINE / "project.yml").read_text(encoding="utf-8")
    cibles = fichiers_partages_par_cible(project_yml)
    cibles.pop("RunUp", None)  # La cible iOS voit tout : elle n'est pas concernée.
    if not cibles:
        return ["project.yml : aucune cible secondaire ne compile RunUp/Shared — "
                "le script ne vérifie plus rien, ce n'est sûrement pas voulu"]

    partages = types_declares(RACINE / PARTAGE, recursif=False)
    app = types_declares(RACINE / APP_SEULEMENT)
    # Un type déclaré dans `Shared/` l'emporte : il est visible partout.
    app_seulement = {nom: chemin for nom, chemin in app.items() if nom not in partages}

    erreurs = []
    for cible, infos in sorted(cibles.items()):
        propres = types_declares(RACINE / cible) if (RACINE / cible).is_dir() else {}
        # Un fichier partagé non compilé dans cette cible n'y rend pas ses types visibles :
        # c'est la nuance qui fait tomber `RouteGeometry`, exclu du widget.
        visibles = set(propres) | {nom for nom, chemin in partages.items()
                                   if chemin.name in infos["fichiers"]}
        for nom_fichier in sorted(infos["fichiers"]):
            fichier = RACINE / PARTAGE / nom_fichier
            if not fichier.exists():
                continue
            source = sans_commentaires_ni_chaines(fichier.read_text(encoding="utf-8"))
            for numero, ligne in enumerate(source.splitlines(), start=1):
                for nom in REFERENCE.findall(ligne):
                    if nom in visibles:
                        continue
                    if nom not in app_seulement:
                        continue
                    ou = app_seulement[nom].relative_to(RACINE)
                    erreurs.append(
                        f"RunUp/Shared/{nom_fichier}:{numero} référence « {nom} », "
                        f"déclaré dans {ou} — ce dossier est compilé dans {cible}, "
                        f"qui ne voit pas ce fichier : erreur de compilation garantie"
                    )
    return erreurs


def main() -> int:
    erreurs = verifier()
    if erreurs:
        print("RunUp/Shared : des types absents des cibles secondaires sont référencés\n")
        for erreur in erreurs:
            print(f"  ✗ {erreur}")
        print("\nOu le fichier n'a rien à faire dans Shared/, ou la référence doit sauter.")
        return 1
    print("RunUp/Shared : aucun type de l'app référencé depuis les cibles secondaires ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
