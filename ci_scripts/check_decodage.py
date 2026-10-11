#!/usr/bin/env python3
"""Toute structure ENREGISTRÉE décode avec `decodeIfPresent`, jamais avec `decode`.

# LA PANNE QUE CE SCRIPT EMPÊCHE DE REVENIR

L'app est morte 0,2 seconde après son lancement, sur toutes les versions installables, chez
quelqu'un dont le programme enregistré contenait une séance que le décodeur ne savait plus
relire. L'accueil demande les séances de la semaine, SwiftData les relit, une clé manque, le
processus tombe. Et comme la donnée est sur le disque, réinstaller une version antérieure n'y
change rien : un plantage qu'aucune mise à jour ne répare.

Le décodeur de SwiftData ne se comporte pas comme `JSONDecoder` :

  • `decodeIfPresent(_:forKey:)` pour une clé absente rend `nil`, paisiblement ;
  • `decode(_:forKey:)` pour une clé absente ARRÊTE LE PROCESSUS — un `EXC_BREAKPOINT` sous
    l'appel, que nul `try?` n'intercepte, parce que rien n'est levé.

Or Swift synthétise `decode` pour toute propriété non optionnelle, Y COMPRIS quand elle porte
une valeur par défaut écrite sur place : `var completed: Bool = false` se lit comme une
tolérance et n'en est pas une. Le défaut sert au constructeur, jamais au décodage.

# CE QUE LE SCRIPT VÉRIFIE

Il part des classes `@Model` — ce qui est réellement sur le disque — et suit les types de leurs
propriétés, puis les types des propriétés de ceux-là, aussi loin qu'il faut. Toute structure
`Codable` atteinte par ce chemin doit écrire son `init(from:)` à la main et n'y appeler que
`decodeIfPresent`.

Partir des modèles plutôt que d'une liste écrite à la main est le fond de l'affaire : la
prochaine structure enregistrée sera ajoutée par quelqu'un qui n'aura pas lu ce fichier, et
c'est précisément celle-là qu'il faut attraper.
"""
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
SOURCES = RACINE / "RunUp"

# Les types que Swift décode lui-même, et qui n'ont donc pas d'`init(from:)` à nous.
PRIMITIFS = {
    "String", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "Double", "Float", "Bool",
    "Date", "Data", "UUID", "URL", "TimeInterval", "CGFloat", "Decimal",
}


def fichiers_swift(racine: Path):
    return sorted(p for p in racine.rglob("*.swift"))


def corps(source: str, depart: int) -> str:
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


def sans_commentaires(source: str) -> str:
    """Un `decode(` cité dans un commentaire n'est pas un appel.

    Ce fichier en contient lui-même plusieurs, et les en-têtes qui expliquent la règle en
    citent la forme interdite — les lire comme du code rendrait le script faux là où il est le
    plus utile.
    """
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def declarations(source: str, mot: str):
    """(nom, en-tête, corps) de chaque `struct`/`class` nommée du fichier."""
    for m in re.finditer(r"\b" + mot + r"\s+([A-Z]\w*)\b([^{\n]*)\{", source):
        yield m.group(1), m.group(2), corps(source, m.end() - 1)


def est_codable(entete: str) -> bool:
    return bool(re.search(r"\b(Codable|Decodable)\b", entete))


def types_cites(corps_struct: str):
    """Les noms de types des propriétés STOCKÉES d'une structure.

    Une propriété calculée (`var x: Int { … }`) ne se décode pas — elle n'a aucune clé — donc
    elle n'amène aucun type dans le périmètre.
    """
    vus = []
    for ligne in corps_struct.split("\n"):
        m = re.match(r"\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:var|let)\s+\w+\s*:\s*(.+)$", ligne)
        if not m:
            continue
        reste = m.group(1)
        avant_accolade = reste.split("{")[0]
        # Une accolade qui n'est précédée d'aucun `=` ouvre un corps calculé, que la ligne
        # tienne en entier (`var repKm: Double { … }`) ou s'ouvre ici pour se fermer plus bas.
        if "{" in reste and "=" not in avant_accolade:
            continue
        for nom in re.findall(r"[A-Z]\w*", avant_accolade.split("=")[0]):
            if nom not in PRIMITIFS:
                vus.append(nom)
    return vus


def analyser(sources=None):
    """`sources` : une suite de textes Swift. Par défaut, ceux du dépôt.

    Le paramètre existe pour les tests : un garde-fou qui ne se vérifie qu'en relisant le dépôt
    passe tant que la faute y est, et échoue à la seconde où elle est corrigée.
    """
    if sources is None:
        sources = [f.read_text(encoding="utf-8") for f in fichiers_swift(SOURCES)]

    structures = {}   # nom -> corps
    enums = set()
    modeles = []      # corps des classes @Model

    for brut in sources:
        source = sans_commentaires(brut)
        # SEULES LES STRUCTURES `Codable` ENTRENT. Une structure qui ne l'est pas ne peut pas
        # être un attribut enregistré — et sans ce filtre, trois `struct State: Equatable`
        # sans rapport (`PaceWindow`, `Streak`, `AutoPause`) prenaient la place, par simple
        # homonymie, de l'énumération `DayStatus.State` qui, elle, est enregistrée.
        for nom, entete, body in declarations(source, "struct"):
            if est_codable(entete) or re.search(r"extension\s+" + nom + r"\s*:[^{\n]*\bCodable\b", source):
                structures[nom] = body
        for nom, _entete, _body in declarations(source, "enum"):
            enums.add(nom)
        for m in re.finditer(r"@Model\b", source):
            suite = source[m.end():]
            ouvrante = suite.find("{")
            if ouvrante != -1:
                modeles.append(corps(suite, ouvrante))
    return structures, enums, modeles


def enregistrees(structures, modeles):
    """Les structures atteintes depuis une classe `@Model`, de proche en proche."""
    a_voir = []
    for body in modeles:
        a_voir.extend(types_cites(body))
    trouvees = set()
    while a_voir:
        nom = a_voir.pop()
        if nom in trouvees or nom not in structures:
            continue
        trouvees.add(nom)
        a_voir.extend(types_cites(structures[nom]))
    return trouvees


def init_tolerant(corps_struct: str):
    """(présent, appelle_decode) pour l'`init(from:)` d'une structure."""
    m = re.search(r"\binit\s*\(\s*from\s+\w+\s*:\s*Decoder\s*\)[^{]*\{", corps_struct)
    if not m:
        return False, False
    body = corps(corps_struct, m.end() - 1)
    return True, re.search(r"\.decode\s*\(", body) is not None


def problemes(sources=None):
    structures, _enums, modeles = analyser(sources)
    if not modeles:
        return ["Aucune classe `@Model` trouvée — le script ne vérifie plus rien."]
    griefs = []
    for nom in sorted(enregistrees(structures, modeles)):
        presente, appelle_decode = init_tolerant(structures[nom])
        if not presente:
            griefs.append(
                f"{nom} est enregistrée et laisse Swift synthétiser son décodage.\n"
                f"      Le décodeur synthétisé appelle `decode` pour chaque propriété non\n"
                f"      optionnelle — valeur par défaut comprise — donc il tuera l'app à la\n"
                f"      première clé manquante. Écris `init(from:)` à la main."
            )
        elif appelle_decode:
            griefs.append(
                f"{nom}.init(from:) appelle `decode`. Une clé absente arrêtera le processus,\n"
                f"      sans erreur à rattraper. `decodeIfPresent`, avec un repli."
            )
    return griefs


def main() -> int:
    griefs = problemes()
    if griefs:
        print(f"{len(griefs)} structure(s) enregistrée(s) au décodage fragile :\n")
        for g in griefs:
            print(f"  • {g}\n")
        print("Voir l'en-tête de RunUp/Models/Session.swift.")
        return 1
    structures, _e, modeles = analyser(None)
    print(f"Décodage : {len(enregistrees(structures, modeles))} structure(s) enregistrée(s), "
          f"toutes tolérantes aux clés manquantes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
