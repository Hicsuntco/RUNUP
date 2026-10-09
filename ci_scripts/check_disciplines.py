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
import json, pathlib, re, sys

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
# Les trois façons de DIRE de quoi un total parle. `.onFoot` est arrivé avec le trail : « de la
# course » et « pas du vélo » ont cessé de désigner le même ensemble, et les quinze agrégations qui
# disaient `.only(.run)` se sont mises à exclure le trail sans que personne ne l'ait décidé.
DECIDE = re.compile(r'\.only\(|\.onFoot\b|\.allDisciplines\b')


# `let courses = runs.only(.run)` — le filtre vit souvent sur une variable, pas sur la ligne
# de la somme. Sans ça le contrôle refuserait du code juste, ce qui est la pire chose qu'une
# barrière puisse faire : on finit par la contourner.
DEFINITION = re.compile(r'\b(?:let|var)\s+(\w+)\s*(?::[^=]+)?=\s*(.+)$')

# `private var runsOnFoot: [RunRecord] { runs.onFoot }` — la même idée, écrite en propriété
# calculée plutôt qu'en variable locale. La première version ne la voyait pas, faute de `=`, et
# refusait donc une grille de statistiques parfaitement explicite : le filtre était sur la ligne
# du dessus, pas sur celle de la somme.
#
# Le `}` ancré en fin de ligne est ce qui borne la lecture à une propriété d'UNE seule ligne. Une
# propriété sur plusieurs lignes reste non résolue, donc refusée — c'est le sens prudent : mieux
# vaut réclamer un filtre explicite que de croire en avoir trouvé un.
DEFINITION_CALCULEE = re.compile(r'\b(?:let|var)\s+(\w+)\s*:[^={]+\{\s*(.+?)\s*\}\s*$')
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
        nue = ligne.strip()
        if nue.startswith("//"):
            continue
        m = DEFINITION.search(nue) or DEFINITION_CALCULEE.search(nue)
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


# ── Les drapeaux de `Discipline` : un `switch`, jamais un `==` ─────────────────────────────────

FICHIER_DISCIPLINE = "RunUp/Shared/Discipline.swift"

# `var nomDuDrapeau: Bool {` — seules les propriétés booléennes calculées sont regardées.
_DRAPEAU = re.compile(r"^\s*var\s+(\w+)\s*:\s*Bool\s*\{")
# `self == .run`, `self != .bike`, `[.run, .trail].contains(self)` : trois façons d'écrire la même
# décision implicite, trois façons de la rendre fausse en silence à la discipline suivante.
_COMPARAISON = re.compile(r"self\s*[!=]=\s*\.|\bcontains\(self\)")


def _sans_commentaires(source):
    """Les `//` et les `///` deviennent du vide — un drapeau CITÉ dans une explication n'est pas
    un drapeau écrit. C'est le défaut qu'avait `check_a11y.py` à sa première version."""
    return re.sub(r"//[^\n]*", "", source)


def _corps(lignes, depart):
    """Le corps de la propriété qui commence à `lignes[depart]`, accolades équilibrées."""
    niveau, corps = 0, []
    for ligne in lignes[depart:]:
        niveau += ligne.count("{") - ligne.count("}")
        corps.append(ligne)
        if niveau <= 0:
            break
    return "\n".join(corps)


def drapeaux(source):
    """Tous les drapeaux booléens de `Discipline` : `(ligne, nom, corps)`."""
    lignes = _sans_commentaires(source).split("\n")
    trouves = []
    for i, ligne in enumerate(lignes):
        m = _DRAPEAU.match(ligne)
        if m:
            trouves.append((i + 1, m.group(1), _corps(lignes, i)))
    return trouves


def drapeaux_fautifs(source):
    """Les drapeaux de `Discipline` qui décident par comparaison au lieu d'un `switch`.

    `var wearsShoes: Bool { self == .run }` est juste tant qu'il n'y a que la course et le vélo, et
    devient faux SANS QUE RIEN NE COMPILE EN ROUGE à la troisième discipline : le trail serait
    arrivé avec `wearsShoes` à faux, `completesRunningPlan` à faux et `usesPacePerKm` à faux — une
    discipline à pied qui n'use pas de chaussures, ne coche aucune séance et s'affiche en km/h.
    Aucune erreur, aucune alerte, juste un mode qui ne marche pas.

    Un `switch` sans `default` déplace la décision au seul endroit qui la prend correctement : le
    compilateur. C'est ce que cette règle rend obligatoire.
    """
    return [(ligne, nom, " ".join(corps.split())[:108])
            for ligne, nom, corps in drapeaux(source)
            if "switch" not in corps and _COMPARAISON.search(corps)]


# ── Les `switch` sur une discipline : tous les cas, ou aucun `default` ─────────────────────────
#
# Cette règle ne cherche pas un défaut de logique : elle cherche une erreur de COMPILATION, avant
# que l'intégration continue ne la trouve. Elle existe parce que trois constructions de suite sont
# mortes là-dessus — `Calories`, `AutoPause`, `TabBarView`, puis `LiveRunView` — chacune pour un
# `switch` que l'ajout d'une discipline avait rendu non exhaustif, et chacune au prix d'un
# aller-retour de quinze minutes pour une ligne.
#
# Le compilateur fait ce travail mieux que ce script. Il le fait seulement beaucoup plus tard, et
# un seul fichier à la fois : il s'arrête au premier et ne dit rien des quatre suivants. Ici on
# les voit tous d'un coup, en une seconde, sur la machine où on écrit.
#
# Rien ici n'autorise un `default` : un `switch` sur une discipline qui en a un passe ce contrôle
# et reste le défaut que `drapeaux_fautifs` décrit — faux en silence à la discipline suivante.
# Cette règle ne regarde que l'exhaustivité, et laisse l'autre dire ce qu'elle a à dire.

DOSSIERS_SWITCH = ["RunUp", "RunUpWidgets", "RunUpWatch"]
_CAS_ENUM = re.compile(r"^\s*case\s+(\w+)\s*=", re.M)


def cas_de_discipline(source):
    """Les noms de cas déclarés par l'énumération `Discipline`, lus à la source."""
    return set(_CAS_ENUM.findall(source))


def _blocs_switch(source):
    """`(ligne, cas cités au premier niveau, le bloc a-t-il un `default`)` pour chaque `switch`.

    Les motifs sont relevés au seul premier niveau d'accolades du bloc : un `switch` imbriqué sur
    une AUTRE énumération, à l'intérieur, ne doit pas verser ses cas dans ceux du bloc extérieur.
    """
    texte = _sans_commentaires(source)
    out = []
    for m in re.finditer(r"\bswitch\b[^\n{]*\{", texte):
        depart = texte.index("{", m.start())
        niveau, fin = 0, len(texte)
        for j in range(depart, len(texte)):
            if texte[j] == "{":
                niveau += 1
            elif texte[j] == "}":
                niveau -= 1
                if niveau == 0:
                    fin = j
                    break
        cas, defaut = set(), False
        niveau = 0
        for c in re.finditer(r"[{}]|\bcase\s+((?:\.\w+\s*,\s*)*\.\w+)|\bdefault\s*:", texte[depart:fin]):
            jeton = c.group(0)
            if jeton == "{":
                niveau += 1
            elif jeton == "}":
                niveau -= 1
            elif niveau != 1:
                continue
            elif jeton.startswith("default"):
                defaut = True
            else:
                cas.update(n.strip().lstrip(".") for n in c.group(1).split(","))
        out.append((texte[:m.start()].count("\n") + 1, cas, defaut))
    return out


def switchs_non_exhaustifs(source, cas_connus):
    """Les `switch` sur une discipline auxquels il manque un cas.

    Un bloc n'est retenu que si TOUS ses motifs sont des cas de `Discipline` : c'est ce qui
    distingue un `switch` sur une discipline d'un `switch` sur une énumération qui aurait, par
    hasard, un cas du même nom. Un motif étranger suffit à écarter le bloc — le sens prudent,
    puisque se tromper ici reviendrait à refuser du code juste.

    # LA LIMITE DE CETTE HEURISTIQUE, ET POURQUOI ELLE TIENT ICI

    Elle ne lit pas le TYPE sur lequel porte le `switch` : elle compare des noms de cas. Un
    `switch` sur une autre énumération dont les cas seraient un sous-ensemble strict de ceux de
    `Discipline` serait donc réclamé à tort.

    Ça n'arrive pas pour `Discipline`, parce que `run`, `bike`, `trail` et `swim` sont des noms
    distinctifs : rien d'autre dans ce dépôt ne s'appelle comme ça. Mais la même règle appliquée
    à une énumération aux noms banals se tromperait aussitôt — essayée sur `TrainingBlock`
    (`base`, `specifique`, `affutage`, `deload`), elle a réclamé quatre `switch` qui portaient
    en réalité sur `UltraTrail.Bloc`, une énumération de trois cas aux trois mêmes noms.

    Donc : si quelqu'un étend ce contrôle à une autre énumération, il lui faudra lire le type et
    pas seulement les noms. Pour `Discipline`, les noms suffisent — et le laisser plus simple
    qu'il n'a besoin de l'être est préférable à un analyseur de types approximatif.
    """
    manques = []
    for ligne, cas, defaut in _blocs_switch(source):
        if defaut or not cas or not cas <= cas_connus:
            continue
        absents = cas_connus - cas
        if absents:
            manques.append((ligne, sorted(absents)))
    return manques


# ── Les types de séance proposés à la saisie doivent être traduits ─────────────────────────────
#
# `check_strings.py` ne peut PAS voir ceux-là, et ce n'est pas un défaut de sa part : il lit des
# littéraux posés dans un `Text(...)` ou un `LocalizedStringKey("...")`. Ici les chaînes vivent
# dans un tableau, et c'est une VARIABLE qui est passée au catalogue —
# `Button(LocalizedStringKey(t))`. Aucune analyse de littéraux ne peut relier les deux.
#
# Sans ce contrôle, ajouter une discipline avec sa liste de types de séance ne déclenche rien, et
# la liste sort en français dans les deux autres langues — un menu « Sortie vélo / Home trainer »
# au milieu d'une app en anglais. C'est le défaut exact que `check_strings` existe pour empêcher,
# qui passe par la seule porte qu'il ne peut pas garder.

CATALOGUE = "RunUp/Resources/Localizable.xcstrings"
LANGUES = ("en", "es")
# `var typesDeSeanceSaisis: [String] { ... }` — le tableau est pris en entier, puis ses chaînes.
_LISTE_TYPES = re.compile(r"var\s+typesDeSeanceSaisis\s*:\s*\[String\]\s*\{(.+?)\n    \}", re.S)
_CHAINE = re.compile(r'"([^"\\]*)"')


def types_de_seance(source):
    """Toutes les chaînes des listes de types de séance de `Discipline`."""
    m = _LISTE_TYPES.search(_sans_commentaires(source))
    if not m:
        return []
    return _CHAINE.findall(m.group(1))


def types_non_traduits(source, catalogue):
    """Ceux qui manquent au catalogue, ou qui y sont sans l'une des deux traductions."""
    absents = []
    for chaine in types_de_seance(source):
        entree = catalogue.get(chaine)
        if entree is None:
            absents.append((chaine, "absent du catalogue"))
            continue
        loc = entree.get("localizations", {})
        manque = [l for l in LANGUES
                  if not loc.get(l, {}).get("stringUnit", {}).get("value")]
        if manque:
            absents.append((chaine, "sans " + " ni ".join(manque)))
    return absents


def main():
    fautifs, lus = [], 0
    source_discipline = (RACINE / FICHIER_DISCIPLINE).read_text()
    fautifs_drapeaux = drapeaux_fautifs(source_discipline)
    nb_drapeaux = len(drapeaux(source_discipline))
    cas_connus = cas_de_discipline(source_discipline)
    catalogue = json.loads((RACINE / CATALOGUE).read_text())["strings"]
    non_traduits = types_non_traduits(source_discipline, catalogue)
    nb_types = len(types_de_seance(source_discipline))
    troues, lus_switch = [], 0
    for dossier in DOSSIERS_SWITCH:
        racine = RACINE / dossier
        if not racine.exists():
            continue
        for f in sorted(racine.rglob("*.swift")):
            if f.name in EXEMPTS:
                continue
            lus_switch += 1
            for ligne, absents in switchs_non_exhaustifs(f.read_text(), cas_connus):
                troues.append((f.relative_to(RACINE), ligne, absents))
    for dossier in DOSSIERS:
        for f in sorted((RACINE / dossier).rglob("*.swift")):
            if f.name in EXEMPTS:
                continue
            lus += 1
            for ligne, extrait in lignes_fautives(f.read_text()):
                fautifs.append((f.relative_to(RACINE), ligne, extrait))
    if non_traduits:
        print(f"{len(non_traduits)} type(s) de séance proposé(s) à la saisie ne sont pas traduits :\n")
        for chaine, pourquoi in non_traduits:
            print(f"  « {chaine} » — {pourquoi}")
        print(f"\nAjoute-les à {CATALOGUE} avec leurs deux traductions. `check_strings.py` ne")
        print("peut pas les voir : ils sont passés au catalogue par une variable, pas écrits en")
        print("littéral. Sans ça le menu sort en français en anglais et en espagnol.")
        return 1
    if troues:
        print(f"{len(troues)} `switch` sur une discipline ne sont pas exhaustifs :\n")
        for chemin, ligne, absents in troues:
            print(f"  {chemin}:{ligne}")
            print(f"    il manque : {', '.join('.' + c for c in absents)}")
        print("\nLe compilateur dirait la même chose, dans quinze minutes et un fichier à la")
        print("fois. Réponds pour chaque cas manquant — pas avec un `default`, qui rendrait la")
        print("réponse fausse en silence à la discipline suivante. Voir `Discipline`.")
        return 1
    if fautifs:
        print(f"{len(fautifs)} agrégation(s) ne disent pas de quelle discipline elles parlent :\n")
        for chemin, ligne, extrait in fautifs:
            print(f"  {chemin}:{ligne}")
            print(f"    {extrait}")
        print("\nAjoute `.only(.run)` — ou `.allDisciplines` si le total porte vraiment sur tout,")
        print("ce qui est une décision à écrire et pas un défaut. Voir `Discipline`.")
        return 1
    if fautifs_drapeaux:
        print(f"{len(fautifs_drapeaux)} drapeau(x) de `Discipline` décident par comparaison :\n")
        for ligne, nom, extrait in fautifs_drapeaux:
            print(f"  {FICHIER_DISCIPLINE}:{ligne}  `{nom}`")
            print(f"    {extrait}")
        print("\nÉcris-les en `switch` sans `default`. Un `self == .run` est juste aujourd'hui et")
        print("devient faux en silence à la discipline suivante — sans une seule erreur de")
        print("compilation. Un `switch` exhaustif fait échouer la construction jusqu'à ce que")
        print("quelqu'un ait répondu pour la nouvelle discipline. Voir `Discipline`.")
        return 1
    print(f"Disciplines : {lus} fichiers lus, toutes les agrégations de relevés sont explicites.")
    print(f"              {nb_drapeaux} drapeaux de `Discipline` décident par `switch`.")
    print(f"              {lus_switch} fichiers balayés, aucun `switch` sur une discipline troué")
    print(f"              ({len(cas_connus)} disciplines : {', '.join('.' + c for c in sorted(cas_connus))}).")
    print(f"              {nb_types} types de séance proposés à la saisie, tous traduits.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
