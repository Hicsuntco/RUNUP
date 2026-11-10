#!/usr/bin/env python3
"""Aucune requête réseau ne part sans dire au bout de combien de temps elle renonce.

# LE DÉFAUT

Les douze requêtes du dépôt partaient sur `URLSession.shared` sans délai déclaré, donc avec celui
d'Apple : **soixante secondes**. Soixante secondes de roue qui tourne, c'est une app cassée — on
ferme, on rouvre, et au mauvais moment on désinstalle. `PanneReseau` sait pourtant écrire la bonne
phrase ; elle arrivait une minute après que la personne avait compris toute seule.

Et ça ne se voit jamais en développement : sur une bonne connexion, un aller-retour sur notre API
prend 0,17 à 0,51 seconde (mesuré le 10 novembre 2026). Le défaut n'existe que chez quelqu'un dans
un train.

# CE QUI EST EXIGÉ

Tout `URLRequest(` doit être suivi, dans les lignes qui suivent, d'un `timeoutInterval` pris dans
`Delais` — et pas d'un nombre écrit là. Un délai en dur est un nombre recopié : douze requêtes,
douze occasions de diverger, et aucune relecture pour s'en apercevoir.

`Delais` porte quatre valeurs et la raison de chacune. Les choisir est une décision de produit —
« combien de temps est-il acceptable de faire attendre quelqu'un » — et elle se prend à un seul
endroit.

# CE QU'IL NE VOIT PAS

Une requête fabriquée autrement : une `URLRequest` passée de main en main, une session configurée
avec son propre `timeoutIntervalForRequest`. Ce script lit du texte Swift, et il lit la forme que
ce dépôt emploie partout.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from swift import sans_commentaires  # noqa: E402

RACINE = pathlib.Path(__file__).resolve().parent.parent
CIBLES = ["RunUp", "RunUpWidgets", "RunUpWatch"]

REQUETE = re.compile(r"\bURLRequest\s*\(")
#: Le délai doit être posé juste après la construction, pas trois écrans plus loin : c'est là
#: qu'on le lit quand on relit l'appel.
LIGNES_SUIVANTES = 6
DELAI = re.compile(r"\btimeoutInterval\s*=\s*Delais\.\w+")
DELAI_EN_DUR = re.compile(r"\btimeoutInterval\s*=\s*[0-9]")


def problemes(racine=RACINE):
    griefs = []
    for cible in CIBLES:
        dossier = racine / cible
        if not dossier.is_dir():
            continue
        for f in sorted(dossier.rglob("*.swift")):
            if f.name == "Delais.swift":
                continue
            lignes = sans_commentaires(f.read_text(encoding="utf-8")).split("\n")
            for i, ligne in enumerate(lignes):
                if not REQUETE.search(ligne):
                    continue
                suite = "\n".join(lignes[i:i + LIGNES_SUIVANTES + 1])
                ou = f"{f.relative_to(racine)}:{i + 1}"
                if DELAI_EN_DUR.search(suite):
                    griefs.append(
                        f"{ou} : délai écrit en dur. Les quatre valeurs et leurs raisons vivent "
                        f"dans `Delais` — un nombre recopié ici est un nombre que personne ne "
                        f"relira.")
                elif not DELAI.search(suite):
                    griefs.append(
                        f"{ou} : requête sans `timeoutInterval`. Elle part donc avec les "
                        f"soixante secondes d'Apple, et la personne regarde tourner une roue "
                        f"pendant une minute. Choisis dans `Delais`.")
    return griefs


def main():
    griefs = problemes()
    for g in griefs:
        print(f"✗ {g}")
    if griefs:
        return 1
    total = sum(len(REQUETE.findall(sans_commentaires(f.read_text(encoding="utf-8"))))
                for c in CIBLES if (RACINE / c).is_dir()
                for f in (RACINE / c).rglob("*.swift") if f.name != "Delais.swift")
    print(f"Délais : {total} requêtes, toutes avec le leur, pris dans `Delais`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
