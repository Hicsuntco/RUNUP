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
# UNE PROPRIÉTÉ STOCKÉE, SOUS SES QUATRE FORMES — ET PAS SEULEMENT `var nom: Type = valeur`.
#
# # L'ANGLE MORT, ET POURQUOI IL ÉTAIT LE PIRE POSSIBLE
#
# La version précédente exigeait les trois à la fois : un `:`, un type écrit, et un `=`. Quatre
# écritures parfaitement ordinaires lui échappaient donc, et la PREMIÈRE est la plus probable de
# toutes :
#
#     var a: Discipline                            ← initialisée dans `init`, pas de `=`
#     var b = Discipline.run                       ← type inféré, pas de `:`
#     @Attribute(.externalStorage) var c: D = .run ← `@\w+` ne mangeait pas les parenthèses
#     private var d: Discipline = .run             ← modificateur d'accès devant `var`
#
# Autrement dit, le garde-fou écrit pour empêcher le plantage au lancement du build 1177 laissait
# passer quatre formes sur cinq de cette faute exacte. Un garde-fou qui ne voit pas la faute la
# plus courante est pire qu'aucun : il donne la paix.
#
# Le type est déduit du membre quand il n'est pas écrit (`= Discipline.run` → `Discipline`,
# `= .run` → inconnu, donc ignoré : sans type écrit NI préfixe de type, on ne peut rien conclure
# et accuser au hasard ferait fuir le script).
PROPRIETE = re.compile(
    r'^\s*(?:(?:private|fileprivate|internal|public|open)\s+)?'   # modificateur d'accès
    r'(?:(?:@\w+(?:\([^)]*\))?)\s+)*'                           # @Attribute(.externalStorage)
    r'(?:(?:private|fileprivate|internal|public|open)\s+)?'        # ... ou après l'attribut
    r'var\s+(\w+)\s*'                                            # le nom
    r'(?::\s*([^=\n{]+?)\s*)?'                                   # le type, s'il est écrit
    r'(?:=\s*(.+))?$'                                             # la valeur, si elle est là
)

# `= Discipline.run` → `Discipline`. Sert quand le type n'est pas écrit.
TYPE_DEDUIT = re.compile(r'^([A-Z]\w*)\s*[.(]')

# LES CINQ PROPRIÉTÉS D'ORIGINE, ET RIEN D'AUTRE NE PEUT ENTRER ICI.
#
# Elles enfreignent la règle — type personnalisé, non optionnel — et elles ne plantent pas, pour
# une raison qui ne vaut QUE pour elles : elles sont dans le schéma depuis la toute première
# version. Leur colonne n'a jamais été ajoutée par une migration, donc elle n'a jamais été NULL
# nulle part, donc le décodage fatal ne peut pas se produire.
#
# Les corriger coûterait exactement ce que la règle existe pour éviter : changer le stockage de
# cinq propriétés de `UserProfile` et `ChatMessage` est une migration de schéma sur les données
# de tout le monde, pour supprimer un risque qui n'existe pas chez elles.
#
# Toute propriété AJOUTÉE à partir d'aujourd'hui, elle, arrive par migration légère et sa colonne
# EST NULL sur les lignes existantes. C'est pourquoi cette liste est close : y ajouter une ligne
# serait exactement le geste qui a fait planter le build 1177.
TOLEREES = {
    ("ChatMessage.swift", "role"),
    ("UserProfile.swift", "goalId"),
    ("UserProfile.swift", "level"),
    ("UserProfile.swift", "programPhase"),
    ("UserProfile.swift", "todaySession"),
}


def sans_commentaires(source):
    """Les commentaires blanchis, LIGNES CONSERVÉES.

    `@Model` est cité dans plusieurs commentaires du dépôt — dont celui qui explique cette règle.
    Les lire comme du code faisait scanner `UserProfile` quatre fois et rendait les signalements
    en double. Les numéros de ligne doivent rester justes, d'où le blanchiment plutôt que la
    suppression.
    """
    source = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def corps(source, depart):
    """Le texte entre l'accolade ouvrante à `depart` et sa fermante."""
    profondeur = 0
    for i in range(depart, len(source)):
        if source[i] == "{":
            profondeur += 1
        elif source[i] == "}":
            profondeur -= 1
            if profondeur == 0:
                return source[depart + 1:i]
    return source[depart:]


def zones_modele(source):
    """(décalage de ligne, corps) de chaque classe `@Model`, sans ses blocs imbriqués.

    Avant, le script lisait le FICHIER ENTIER dès qu'il contenait `@Model` quelque part. Il
    accusait donc des structures qui ne sont pas enregistrées du tout — `SharedRouteResponse`,
    qui est une réponse d'API — et aurait manqué l'inverse : une propriété de `@Model` écrite
    dans un fichier sans `@Model` ne peut pas exister, mais une structure imbriquée DANS le
    modèle, elle, apportait ses propres champs. On ne regarde donc que l'intérieur des classes,
    et pas l'intérieur de ce qu'elles contiennent.
    """
    zones = []
    for m in re.finditer(r"@Model\b", source):
        ouvrante = source.find("{", m.end())
        if ouvrante == -1:
            continue
        interieur = corps(source, ouvrante)
        decalage = source[:ouvrante].count("\n")
        # Les blocs imbriqués (structures, énumérations, corps de fonction, propriétés
        # calculées) sont vidés mais leurs lignes conservées, pour que les numéros restent justes.
        aplati, profondeur = [], 0
        for ch in interieur:
            if ch == "{":
                profondeur += 1
                aplati.append("{")
            elif ch == "}":
                profondeur -= 1
                aplati.append("}")
            elif profondeur == 0 or ch == "\n":
                aplati.append(ch)
        zones.append((decalage, "".join(aplati)))
    return zones


def fautives(source):
    """(ligne, nom, type) des propriétés stockées non optionnelles d'un type personnalisé."""
    out = []
    for decalage, zone in zones_modele(sans_commentaires(source)):
        out.extend(_dans(zone, decalage))
    return out


def _dans(source, decalage):
    out = []
    for i, ligne in enumerate(source.splitlines()):
        nue = ligne.strip()
        if nue.startswith("//"):
            continue
        m = PROPRIETE.match(ligne)
        if not m:
            continue
        nom, type_, valeur = m.group(1), (m.group(2) or "").strip(), (m.group(3) or "").strip()
        # Une propriété CALCULÉE s'ouvre sur `{` sans `=` : elle n'est pas sur le disque, donc
        # elle n'a rien à faire ici. Le `{` est déjà exclu du type par la regex ; reste à écarter
        # la ligne qui n'a ni type ni valeur, qui est forcément le début d'une calculée.
        if not type_ and not valeur:
            continue
        if not type_:
            deduit = TYPE_DEDUIT.match(valeur)
            # `= .run` ne dit rien du type. Se taire plutôt qu'accuser au hasard : un garde-fou
            # qui crie faux finit désactivé, et il vaut mieux rater ce cas-là que les cinq autres.
            if not deduit:
                continue
            type_ = deduit.group(1)
        if type_.endswith("?") or type_.startswith("["):      # optionnel, ou collection
            continue
        if type_ in PRIMITIVES:
            continue
        out.append((i + 1 + decalage, nom, type_))
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
                if (f.name, nom) in TOLEREES:
                    continue
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
    print(f"Modèles : {lus} fichiers @Model lus, aucune propriété stockée à risque "
          f"({len(TOLEREES)} d'origine tolérées, liste close).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
