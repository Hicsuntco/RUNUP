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

# CE QUI EST MESURÉ

Tout fichier Swift de `RunUp/` qui contient une vue SwiftUI — un `some View` — doit être couvert
par au moins un chemin du déclencheur. Pas « devrait » : une vue est précisément la chose dont le
défaut ne se lit que sur l'image, et c'est la raison d'être de toute la chaîne.

Les `Models` et les `Services` restent dehors par décision écrite dans `captures.yml` : ils n'ont
pas de visage. Ce contrôle ne la conteste pas — il vérifie qu'elle reste vraie. Le jour où
quelqu'un met une vue dans `Services/`, il faudra soit la déplacer, soit ajouter le chemin ; les
deux sont des décisions, et aucune ne doit se prendre par distraction.

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

    orphelines = [v for v in vues if not couvert(v, motifs)]
    if orphelines:
        print("Des vues ne relancent PAS les captures quand on les modifie :\n")
        for vue in orphelines:
            print(f"  · {vue}")
        print("\n    Le défaut n'a aucun symptôme : la chaîne reste verte parce qu'elle ne tourne")
        print("    pas, et les images en ligne datent d'avant la modification. Ajoute le chemin")
        print(f"    au bloc `paths:` de {WORKFLOW.name}, ou déplace le fichier sous RunUp/Views/.")
        return 1

    print(f"Déclencheur des captures : {len(vues)} fichiers de vues, tous couverts "
          f"par {len(motifs)} chemins.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
