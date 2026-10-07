#!/usr/bin/env python3
"""Une propriété de type personnalisé ajoutée à un modèle SwiftData doit être OPTIONNELLE.

# POURQUOI CE CONTRÔLE EXISTE

Le build 1177 a planté au lancement chez tout le monde, sur une ligne qui compilait et dont les
tests passaient :

    var discipline: Discipline = Discipline.run

Le mécanisme est traître sur trois points, et aucune relecture ne l'attrape.

La migration légère RÉUSSIT — elle ajoute bien la colonne. Mais elle l'ajoute à NULL sur toutes
les lignes existantes : une valeur par défaut écrite en Swift ne remplit pas le magasin, elle ne
vaut que pour les objets créés par l'initialiseur.

Le filet de sécurité de `PersistenceController` ne voit rien : il attrape l'échec d'OUVERTURE du
magasin, et l'ouverture s'est bien passée. Il est conçu pour une migration qui échoue, pas pour
une qui réussit en laissant des trous.

Et le crash tombe au premier accès, donc au lancement, puisque l'accueil lit les courses tout de
suite. Pas d'écran, pas de message, pas de chemin dégradé.

# POURQUOI LA RÈGLE NE VISE QUE LES TYPES PERSONNALISÉS

Les primitives passent sans problème, et les modèles en sont pleins : `var weatherAlertsEnabled:
Bool = true`, `var averageCycleLengthDays: Int = 28`, `var weekTier: Int = 1`. Pour celles-là,
SwiftData pose un vrai défaut au niveau du magasin, et la colonne n'est jamais NULL. Les
collections aussi (`var route: [RoutePoint] = []`). Ce qui casse, c'est un type qui se range en
données encodées — une énumération, une structure — pour lequel aucun défaut de magasin n'existe.

Les six propriétés ajoutées à `RunRecord` au fil des années sont toutes optionnelles. Ce n'était
pas un hasard de style ; c'était cette règle, jamais écrite.

# LA SORTIE

Stocker le type brut (`String?`) et exposer une propriété CALCULÉE non optionnelle qui retombe
sur une valeur par défaut. L'absence et la valeur illisible se traitent alors au même endroit, et
aucun appelant ne manipule d'optionnel. Voir `RunRecord.disciplineRaw` / `RunRecord.discipline`.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ["RunUp/Models"]

# Ce que SwiftData sait doter d'un vrai défaut en base.
PRIMITIVES = {
    "Bool", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "Double", "Float",
    "String", "Date", "UUID", "Data", "URL", "Decimal",
}
# `var nom: Type = valeur` — une propriété STOCKÉE avec un défaut. Une calculée s'écrit avec
# `{`, pas avec `=`, et n'est donc pas vue ici : c'est exactement la forme qu'on recommande.
PROPRIETE = re.compile(r'^\s*(?:@\w+\s+)*var\s+(\w+)\s*:\s*([^=\n]+?)\s*=\s*(.+)$')


def fautives(source):
    """(ligne, nom, type) des propriétés stockées non optionnelles d'un type personnalisé."""
    if "@Model" not in source:
        return []
    out = []
    for i, ligne in enumerate(source.splitlines()):
        nue = ligne.strip()
        if nue.startswith("//"):
            continue
        m = PROPRIETE.match(ligne)
        if not m:
            continue
        nom, type_, _ = m.group(1), m.group(2).strip(), m.group(3)
        if type_.endswith("?") or type_.startswith("["):      # optionnel, ou collection
            continue
        if type_ in PRIMITIVES:
            continue
        out.append((i + 1, nom, type_))
    return out


def main():
    fautifs, lus = [], 0
    for dossier in DOSSIERS:
        for f in sorted((RACINE / dossier).rglob("*.swift")):
            source = f.read_text()
            if "@Model" not in source:
                continue
            lus += 1
            for ligne, nom, type_ in fautives(source):
                fautifs.append((f.relative_to(RACINE), ligne, nom, type_))
    if fautifs:
        print(f"{len(fautifs)} propriété(s) de modèle feraient planter l'app au lancement :\n")
        for chemin, ligne, nom, type_ in fautifs:
            print(f"  {chemin}:{ligne}")
            print(f"    var {nom}: {type_} = …  — non optionnelle, type personnalisé.")
        print("\nLa migration ajoutera la colonne à NULL sur les lignes existantes, et décoder")
        print("NULL dans ce type est fatal au premier accès — c'est-à-dire au lancement.")
        print("Stocke le type brut en `String?` et expose une propriété CALCULÉE non optionnelle")
        print("qui retombe sur un défaut. Voir `RunRecord.disciplineRaw` / `.discipline`.")
        return 1
    print(f"Modèles : {lus} fichiers @Model lus, aucune propriété stockée à risque.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
