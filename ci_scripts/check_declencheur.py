#!/usr/bin/env python3
"""Le déclencheur des captures doit couvrir tout ce qui a un visage.

# POURQUOI CE CONTRÔLE EXISTE

`captures.yml` ne part pas à chaque commit : vingt minutes de machine macOS pour des images, ça se
dépense là où l'image EST la vérification. La liste de ses chemins déclencheurs est donc un
jugement — « ce fichier peut changer ce qu'on voit » — écrit à la main, une fois, et jamais
revérifié.

Elle s'est trompée deux fois, et chaque fois de la même façon : par omission silencieuse.

  · `RunUp/AppState.swift`, le routeur de l'app, n'y était pas. Le commentaire du fichier le
    raconte lui-même : « le correctif de la transition d'écran n'a touché que lui : les captures
    ne se sont pas relancées, et je n'ai donc pas pu mesurer ce que le correctif changeait ».
  · `RunUp/RunUpApp.swift`, qui porte `RootView`, n'y était pas non plus. Le commit du rapport de
    panne l'a touché le 8 novembre 2026. Aucune capture ne s'est relancée.

Le défaut n'a aucun symptôme : la chaîne reste verte, puisqu'elle ne tourne pas. On croit avoir
des images à jour, et on en a d'avant la modification.

# CE QUI EST MESURÉ — DEUX RÈGLES

PREMIÈRE RÈGLE. Tout fichier Swift de `RunUp/` qui contient une vue SwiftUI — un `some View` —
doit être couvert par au moins un chemin du déclencheur. Pas « devrait » : une vue est précisément la chose dont le
défaut ne se lit que sur l'image, et c'est la raison d'être de toute la chaîne.

Les `Models` et les `Services` restent dehors par décision écrite dans `captures.yml` : ils n'ont
pas de visage. Ce contrôle ne la conteste pas — il vérifie qu'elle reste vraie. Le jour où
quelqu'un met une vue dans `Services/`, il faudra soit la déplacer, soit ajouter le chemin ; les
deux sont des décisions, et aucune ne doit se prendre par distraction.

SECONDE RÈGLE, d'un cran plus loin et trouvée le même jour. Tout script `check_*.py` ou
`test_*.py` que ce workflow LANCE doit aussi être dans son filtre. Cinq ne l'étaient pas —
`comparer.py` et ses cas, ceux des bascules, et le contrôle du grand texte avec les siens : les
modifier ne relançait pas la chaîne qui les exécute.

`check_cablage.py` ne pouvait pas le voir, et ce n'est pas un oubli de sa part : il vérifie qu'un
script est NOMMÉ par un workflow, pas que ce workflow PARTE quand le script change. Un script
nommé dans une étape d'un workflow qui ne se déclenche jamais pour lui est câblé sur le papier et
débranché en pratique. Le défaut s'est présenté le 8 novembre 2026, en modifiant `comparer.py` :
seule la chaîne TestFlight est partie.

# POURQUOI LE DÉCLENCHEUR EST LU À LA MAIN

Sans PyYAML, comme `check_cablage.py` : la chaîne TestFlight n'installe pas de dépendance Python,
et un contrôle qui ne peut pas tourner ne garde rien.
"""
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
WORKFLOW = RACINE / ".github/workflows/captures.yml"
APP = RACINE / "RunUp"

#: Ce qui fait d'un fichier une vue. `some View` est le seul marqueur fiable : une `struct X: View`
#: sans corps n'existe pas, et un corps de vue SwiftUI s'écrit toujours `-> some View` ou
#: `var body: some View`.
MARQUEUR_DE_VUE = "some View"


def chemins_declencheurs():
    """Les motifs du bloc `paths:` de `on.push`, lus sans PyYAML."""
    texte = WORKFLOW.read_text(encoding="utf-8")
    if "\n    paths:\n" not in texte:
        raise SystemExit(f"aucun bloc `paths:` dans {WORKFLOW.name} — ce script est à revoir.")
    apres = texte.split("\n    paths:\n", 1)[1]
    motifs = []
    for ligne in apres.splitlines():
        nue = ligne.strip()
        if nue.startswith("#") or not nue:
            # Un commentaire ou une ligne vide DANS le bloc : la liste continue en dessous.
            # C'est le cas réel — ce bloc est commenté entrée par entrée.
            continue
        trouve = re.fullmatch(r'-\s+"([^"]+)"', nue)
        if trouve:
            motifs.append(trouve.group(1))
            continue
        # Première ligne qui n'est ni un commentaire, ni vide, ni une entrée : le bloc est fini.
        break
    if not motifs:
        raise SystemExit(f"le bloc `paths:` de {WORKFLOW.name} est vide — ce script est à revoir.")
    return motifs


def couvert(chemin_relatif: str, motifs: list[str]) -> bool:
    """Un chemin du dépôt est-il visé par l'un des motifs ?

    Deux formes suffisent, parce que ce sont les deux seules qu'emploie `captures.yml` : le chemin
    exact, et le préfixe suivi de `/**`. Rien ici ne prétend implémenter la syntaxe complète de
    GitHub — un contrôle qui ferait semblant de la comprendre serait pire qu'absent.
    """
    for motif in motifs:
        if motif.endswith("/**"):
            if chemin_relatif.startswith(motif[:-2]):
                return True
        elif "*" in motif:
            # Une forme qu'on ne sait pas juger. On ne devine pas : on le dit.
            raise SystemExit(
                f"le motif « {motif} » emploie une étoile que ce script ne sait pas interpréter.\n"
                "Ajoute la forme ici plutôt que de laisser le contrôle deviner."
            )
        elif chemin_relatif == motif:
            return True
    return False


#: Ce qui fait d'une ligne de workflow un lancement de script.
#:
#: L'interpréteur n'est PAS toujours `python3` : ce workflow-ci installe Pillow dans un
#: environnement virtuel et lance `"$RUNNER_TEMP/venv/bin/python test_comparer.py"`. Une première
#: version exigeait `python3` et a trouvé ZÉRO script — en rendant vert, évidemment. D'où une
#: expression qui accepte n'importe quel interpréteur, et un garde-fou qui refuse un compte nul.
LANCEMENT = re.compile(r"(?:python3?|[\"'][^\"'\n]*?/python3?[\"'])\s+(?:\S*/)?"
                       r"((?:check|test)_[a-z_]+\.py)")

#: Les entrées du bloc `paths:`, qui nomment les mêmes fichiers sans les lancer.
ENTREE_DE_CHEMIN = re.compile(r'^\s*-\s+"')

#: Un nom de script, où qu'il soit. Sert uniquement au garde-fou ci-dessous.
NOM_DE_SCRIPT = re.compile(r"(?:check|test)_[a-z_]+\.py")


def scripts_lances():
    """Les `check_*.py` / `test_*.py` que ce workflow exécute vraiment.

    Les commentaires et les entrées du filtre `paths:` sont écartés : les uns citent des noms
    dans des phrases, les autres nomment précisément les fichiers qu'on veut comparer — les
    compter comme des lancements rendrait la règle tautologique.

    Rend `(scripts, des_noms_ailleurs)`. Le second dit si un nom de script apparaît dans ce qui
    reste SANS qu'on ait su y lire un lancement : c'est la signature d'une lecture cassée, et
    c'est la seule façon dont ce contrôle peut se taire sans qu'on le voie. Il l'a déjà fait —
    sa première version exigeait `python3` et a trouvé zéro script dans un workflow qui en lance
    quatre avec le python d'un environnement virtuel.
    """
    gardees = []
    for ligne in WORKFLOW.read_text(encoding="utf-8").splitlines():
        if ligne.strip().startswith("#") or ENTREE_DE_CHEMIN.match(ligne):
            continue
        gardees.append(ligne)
    texte = "\n".join(gardees)
    return sorted(set(LANCEMENT.findall(texte))), bool(NOM_DE_SCRIPT.search(texte))


def vues_du_depot():
    for fichier in sorted(APP.rglob("*.swift")):
        if MARQUEUR_DE_VUE in fichier.read_text(encoding="utf-8"):
            yield fichier.relative_to(RACINE).as_posix()


def main():
    motifs = chemins_declencheurs()
    vues = list(vues_du_depot())
    if not vues:
        print(f"Aucune vue trouvée sous {APP.name}/ — l'analyse a échoué, pas le code.")
        return 1

    lances, des_noms_ailleurs = scripts_lances()
    if not lances and des_noms_ailleurs:
        # Des noms de scripts dans les étapes, et aucun lancement lu : ce n'est pas un workflow
        # qui ne lance rien, c'est une lecture cassée. Un workflow qui n'en mentionne aucun est
        # un cas normal, et il passe.
        print(f"{WORKFLOW.name} nomme des scripts dans ses étapes, et aucun lancement n'a pu y")
        print("être lu — l'analyse a échoué, pas le code. L'interpréteur a dû changer de forme.")
        return 1

    debranches = [f"ci_scripts/{n}" for n in lances
                  if not couvert(f"ci_scripts/{n}", motifs)]
    if debranches:
        print("Ce workflow lance des scripts, et les modifier ne le déclenche PAS :\n")
        for script in debranches:
            print(f"  · {script}")
        print("\n    Câblé sur le papier, débranché en pratique : l'étape existe, mais la chaîne")
        print("    ne part pas quand le script change, donc il n'est jamais exécuté par la")
        print(f"    modification qui le concerne. Ajoute le chemin au bloc `paths:` de")
        print(f"    {WORKFLOW.name}.")
        return 1

    orphelines = [v for v in vues if not couvert(v, motifs)]
    if orphelines:
        print("Des vues ne relancent PAS les captures quand on les modifie :\n")
        for vue in orphelines:
            print(f"  · {vue}")
        print("\n    Le défaut n'a aucun symptôme : la chaîne reste verte parce qu'elle ne tourne")
        print("    pas, et les images en ligne datent d'avant la modification. Ajoute le chemin")
        print(f"    au bloc `paths:` de {WORKFLOW.name}, ou déplace le fichier sous RunUp/Views/.")
        return 1

    print(f"Déclencheur des captures : {len(vues)} fichiers de vues et "
          f"{len(lances)} scripts lancés, tous couverts par {len(motifs)} chemins.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
