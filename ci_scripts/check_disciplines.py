#!/usr/bin/env python3
"""Une somme sur des relevés doit dire de quelle discipline elle parle.

# POURQUOI CE CONTRÔLE EXISTE

L'app n'a longtemps su faire qu'une chose : courir. Aucune agrégation n'avait donc à préciser ce
qu'elle comptait — il n'y avait rien d'autre. Treize sommaient `distanceKm`, d'autres cherchaient
la plus longue sortie, la meilleure allure, le dénivelé total, le kilométrage d'une paire de
chaussures.

Le jour où une deuxième discipline arrive, toutes deviennent fausses **sans que rien ne le
signale**. Quarante kilomètres de vélo entrent dans la distance courue du mois. La meilleure
allure devient une vitesse que personne ne battra jamais à pied, et le record est perdu pour
toujours. Les chaussures vieillissent sans avoir touché le sol. La séance de course du jour se
coche parce qu'on a roulé.

Rien ne casse, rien ne s'affiche en rouge. Les chiffres deviennent simplement faux, et on s'en
aperçoit des semaines plus tard, quand plus personne ne sait ce qui était vrai. C'est la panne la
plus coûteuse qu'une app de mesure puisse avoir : elle ne se voit pas.

# LA RÈGLE

Toute ligne qui agrège un champ de `RunRecord` doit passer par `.only(<discipline>)` ou par
`.allDisciplines` — ce dernier étant une décision écrite (« ce total porte bien sur tout »), pas
l'absence de décision. Voir `Discipline` pour le raisonnement complet.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ["RunUp/Views", "RunUp/Services", "RunUp/Models", "RunUp/ViewModels", "RunUp/Shared"]
# Le fichier qui DÉFINIT la règle en parle forcément.
EXEMPTS = {"Discipline.swift"}

# Les formes qui agrègent un champ de relevé. Volontairement peu nombreuses et précises : une
# barrière d'intégration continue qui se trompe coûte plus cher que le défaut qu'elle cherche.
AGREGATIONS = [
    re.compile(r'\.reduce\(0\)\s*\{\s*\$0\s*\+\s*\$1\.(distanceKm|durationSeconds|elevationGainM|kcal)\b'),
    re.compile(r'\.map\(\\\.(distanceKm|durationSeconds|elevationGainM|kcal)\)\s*\.(max|min)\('),
    re.compile(r'\.(max|min)\(by:\s*\{\s*\$0\.(distanceKm|durationSeconds|elevationGainM|kcal)\b'),
    re.compile(r'\.compactMap\s*[({].*parseSecPerKm\(\$0\.avgPace\)'),
]
DECIDE = re.compile(r'\.only\(|\.allDisciplines\b')


# `let courses = runs.only(.run)` — le filtre vit souvent sur une variable, pas sur la ligne
# de la somme. Sans ça le contrôle refuserait du code juste, ce qui est la pire chose qu'une
# barrière puisse faire : on finit par la contourner.
DEFINITION = re.compile(r'\b(?:let|var)\s+(\w+)\s*(?::[^=]+)?=\s*(.+)$')
RECEVEUR = re.compile(r'\b(\w+)\s*$')


def _source_decide(nom, definitions, vus=None, profondeur=0):
    """La variable `nom` vient-elle, directement ou de proche en proche, d'un tableau filtré ?

    Deux niveaux suffisent en pratique (`similarRuns` ← `priorRuns` ← `only(...)`) et bornent la
    recherche : une chaîne plus longue que ça mérite d'être écrite explicitement.
    """
    if profondeur > 2 or nom not in definitions:
        return False
    vus = vus or set()
    if nom in vus:
        return False
    vus.add(nom)
    expr = definitions[nom]
    if DECIDE.search(expr):
        return True
    parent = re.match(r'\s*(\w+)\b', expr)
    return bool(parent) and _source_decide(parent.group(1), definitions, vus, profondeur + 1)


def lignes_fautives(source):
    """(numéro, texte) des lignes qui agrègent sans dire de quoi elles parlent."""
    lignes = source.splitlines()
    definitions = {}
    for ligne in lignes:
        m = DEFINITION.search(ligne.strip())
        if m:
            definitions.setdefault(m.group(1), m.group(2))

    out = []
    for i, ligne in enumerate(lignes):
        nue = ligne.strip()
        if nue.startswith("//"):
            continue
        trouve = next((m.search(ligne) for m in AGREGATIONS if m.search(ligne)), None)
        if not trouve:
            continue
        # La ligne précédente compte aussi : une chaîne d'appels peut poser le filtre au-dessus.
        if DECIDE.search(ligne + (lignes[i - 1] if i else "")):
            continue
        # Sinon, le receveur est peut-être une variable déjà filtrée.
        avant = ligne[:trouve.start()]
        nom = RECEVEUR.search(avant)
        if nom and _source_decide(nom.group(1), definitions):
            continue
        out.append((i + 1, " ".join(nue.split())[:108]))
    return out


def main():
    fautifs, lus = [], 0
    for dossier in DOSSIERS:
        for f in sorted((RACINE / dossier).rglob("*.swift")):
            if f.name in EXEMPTS:
                continue
            lus += 1
            for ligne, extrait in lignes_fautives(f.read_text()):
                fautifs.append((f.relative_to(RACINE), ligne, extrait))
    if fautifs:
        print(f"{len(fautifs)} agrégation(s) ne disent pas de quelle discipline elles parlent :\n")
        for chemin, ligne, extrait in fautifs:
            print(f"  {chemin}:{ligne}")
            print(f"    {extrait}")
        print("\nAjoute `.only(.run)` — ou `.allDisciplines` si le total porte vraiment sur tout,")
        print("ce qui est une décision à écrire et pas un défaut. Voir `Discipline`.")
        return 1
    print(f"Disciplines : {lus} fichiers lus, toutes les agrégations de relevés sont explicites.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
