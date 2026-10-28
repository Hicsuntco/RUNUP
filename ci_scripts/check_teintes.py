#!/usr/bin/env python3
"""La teinte d'un en-tête de carte est l'exception, et elle doit nommer quelque chose.

POURQUOI CETTE RÈGLE EXISTE.

Elle était passée explicitement à 55 endroits, sur huit valeurs, sans aucune règle. Sur la seule
feuille du triathlon : « Où passe la journée » violet, « On ne mange pas dans l'eau » rose,
« Les transitions » vert, « La combinaison » violet. Sur une seule rangée de l'écran Stats :
règle rose, coureur violet, horloge turquoise. Trois tuiles côte à côte, trois teintes.

Trois de ces couleurs — `lime`, `cyan`, `amber` — ne suivent pas le thème choisi : ce sont des
valeurs fixes. Un accent cyan laissait donc des icônes vertes et ambrées éparpillées dans une app
qu'on venait de repeindre.

Et c'est le coût réel : `lime` veut dire MIEUX, `amber` veut dire MOINS BIEN. L'écran Stats s'en
sert correctement pour ses pastilles d'écart, à deux centimètres d'une icône décorative de la même
couleur. Dépenser une couleur sémantique en décoration, c'est vider de son sens le seul endroit
où elle disait quelque chose.

Aucun compilateur ne peut refuser `tint: RUColor.lime` : c'est une couleur valide passée à un
paramètre qui l'accepte.
"""
import re, sys, pathlib

RACINE = pathlib.Path(__file__).resolve().parent.parent

# fichier → { ligne : raison }. La ligne est indicative ; c'est le COMPTE par fichier qui est
# tenu, pour qu'un ajout de code au-dessus ne fasse pas échouer le build pour rien.
AUTORISE = {
    "RunUp/Views/Profile/ProfileView.swift":
        (1, "« Session expirée » en ambre : la couleur nomme un avertissement"),
    "RunUp/Views/Race/RacePageView.swift":
        (1, "« Je prépare cette course » en vert : la couleur nomme un état confirmé"),
    "RunUp/Views/Profile/ShoesView.swift":
        (1, "« Retirées » en gris : volontairement éteint, ce sont des archives"),
    "RunUp/Views/Stats/StatsView.swift":
        (5, "le bloc Vélo, marqué en turquoise d'un bout à l'autre — un repère de discipline, "
            "et non une décoration, parce qu'il est tenu sur toute la section"),
}

APPEL = re.compile(r"(?:RUCardHeader|RUStatTile)\([^\n]*tint:")

fautes = []
compte = {}
for chemin in sorted(RACINE.rglob("*.swift")):
    rel = str(chemin.relative_to(RACINE))
    for num, ligne in enumerate(chemin.read_text().split("\n"), 1):
        if ligne.lstrip().startswith("//") or not APPEL.search(ligne):
            continue
        compte[rel] = compte.get(rel, 0) + 1
        if rel not in AUTORISE:
            fautes.append(f"{rel}:{num} : une teinte posée sur un en-tête de carte.\n"
                          f"    Si elle nomme vraiment quelque chose, inscris le fichier dans\n"
                          f"    AUTORISE de ci_scripts/check_teintes.py avec sa raison. Sinon,\n"
                          f"    retire-la : le défaut est l'accent de l'app.\n"
                          f"    {ligne.strip()}")

for rel, (attendu, raison) in sorted(AUTORISE.items()):
    n = compte.get(rel, 0)
    if n != attendu:
        fautes.append(f"{rel} : {n} teinte(s), {attendu} déclarée(s).\n"
                      f"    Raison inscrite : {raison}")

if fautes:
    print("Des teintes d'en-tête de carte hors de ce qui est déclaré :\n")
    for f in fautes:
        print("  • " + f)
    sys.exit(1)

print(f"Teintes d'en-tête : {sum(compte.values())} déclarée(s) dans {len(AUTORISE)} fichiers, "
      f"tout le reste sur l'accent.")
