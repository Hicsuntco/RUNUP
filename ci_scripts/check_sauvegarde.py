#!/usr/bin/env python3
"""Toute propriété enregistrée est DANS la sauvegarde, ou inscrite comme volontairement dehors.

# CE QUE CE SCRIPT PROTÈGE

`Sauvegarde` est le seul filet sous les données de l'app : un fichier que la personne garde, et
qui contient ce qu'aucun autre service ne détient — la conversation avec le coach, les ressentis,
les chaussures et leur kilométrage, la série, l'XP, le programme en cours, les réponses de
l'inscription. Apple Santé ne garde que les courses.

Un filet se dégrade en silence. On ajoute un champ à `UserProfile` un mardi, la sauvegarde ne le
connaît pas, personne ne s'en aperçoit — et le jour où elle sert, ce champ-là manque. Il n'y a
aucun symptôme entre les deux : l'export marche, le fichier s'écrit, la restauration réussit. La
perte ne se voit qu'une fois, au pire moment, et elle est définitive.

# LA RÈGLE

Pour chaque classe `@Model`, chaque propriété STOCKÉE doit être :

  • soit un champ de la structure correspondante de `Sauvegarde` (voir `correspondances`) ;
  • soit inscrite dans `Sauvegarde.nonSauvegardees` AVEC SA RAISON.

Ce qui est demandé n'est pas de tout sauvegarder — plusieurs champs ne doivent justement pas
l'être (un abonnement, un compteur du jour, un cache météo). C'est que le choix soit ÉCRIT. Une
propriété qui n'est ni dans l'un ni dans l'autre n'a pas été décidée : elle a été oubliée.

Le script vérifie aussi l'inverse — un champ de la sauvegarde qui ne correspond plus à aucune
propriété, et une entrée de `nonSauvegardees` qui nomme une propriété disparue — pour que le
fichier ne se remplisse pas de raisons de ne pas sauvegarder des choses qui n'existent plus.
"""
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
MODELES = RACINE / "RunUp" / "Models"
SAUVEGARDE = RACINE / "RunUp" / "Services" / "Sauvegarde.swift"
SERVICE = RACINE / "RunUp" / "Services" / "SauvegardeService.swift"


def sans_commentaires(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


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


def aplatir(body: str) -> str:
    """Le corps d'un type SANS le contenu de ses blocs imbriqués.

    `RunRecord` déclare `struct RoutePoint` à l'intérieur de lui-même, et `lat`/`lng`/`altitude`
    se lisaient alors comme trois propriétés du modèle : le script réclamait leur place dans la
    sauvegarde alors qu'elles y sont déjà, portées par `route`. Les corps de fonction poseraient
    le même problème avec leurs variables locales.

    L'accolade ouvrante et sa fermante sont CONSERVÉES, pour que `var x: T { … }` reste
    reconnaissable comme une propriété calculée après l'opération.
    """
    out, profondeur = [], 0
    for ch in body:
        if ch == "{":
            profondeur += 1
            if profondeur == 1:
                out.append("{")
            continue
        if ch == "}":
            profondeur -= 1
            if profondeur == 0:
                out.append("}")
            continue
        if profondeur == 0:
            out.append(ch)
    return "".join(out)


# `var nom: Type` — et seulement une propriété d'instance.
PROPRIETE = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*var\s+(\w+)\s*:\s*(.+)$")


def proprietes_stockees(body: str):
    """Les noms des propriétés stockées d'un corps de classe ou de structure.

    Une propriété CALCULÉE s'écrit `var x: T { … }` : son accolade n'est précédée d'aucun `=`.
    Elle n'est pas sur le disque, donc elle n'a rien à faire dans une sauvegarde — et l'y mettre
    ferait échouer ce script sur une donnée qui se recalcule.
    """
    noms = []
    for ligne in aplatir(body).split("\n"):
        nue = ligne.strip()
        if nue.startswith("static ") or nue.startswith("private static "):
            continue
        m = PROPRIETE.match(ligne)
        if not m:
            continue
        nom, reste = m.group(1), m.group(2)
        avant_accolade = reste.split("{")[0]
        if "{" in reste and "=" not in avant_accolade:
            continue
        noms.append(nom)
    return noms


def modeles(sources=None):
    """nom de classe `@Model` -> propriétés stockées."""
    if sources is None:
        sources = [f.read_text(encoding="utf-8") for f in sorted(MODELES.rglob("*.swift"))]
    out = {}
    for brut in sources:
        source = sans_commentaires(brut)
        for m in re.finditer(r"@Model\b", source):
            suite = source[m.end():]
            entete = re.search(r"\b(?:final\s+)?class\s+(\w+)", suite)
            ouvrante = suite.find("{")
            if not entete or ouvrante == -1:
                continue
            out[entete.group(1)] = proprietes_stockees(corps(suite, ouvrante))
    return out


def structures_de_sauvegarde(source: str):
    """nom de structure -> champs, pour les structures déclarées dans `Sauvegarde.swift`."""
    propre = sans_commentaires(source)
    out = {}
    for m in re.finditer(r"\bstruct\s+(\w+)\s*:[^{\n]*\{", propre):
        out[m.group(1)] = proprietes_stockees(corps(propre, m.end() - 1))
    return out


def dictionnaire(source: str, nom: str):
    """Les clés d'un `static let nom: [String: String] = [ … ]`, avec leur valeur brute."""
    propre = sans_commentaires(source)
    m = re.search(r"static\s+let\s+" + nom + r"\s*:\s*\[String\s*:\s*String\]\s*=\s*\[", propre)
    if not m:
        return None
    depart = m.end() - 1
    profondeur = 0
    fin = len(propre)
    for i in range(depart, len(propre)):
        if propre[i] == "[":
            profondeur += 1
        elif propre[i] == "]":
            profondeur -= 1
            if profondeur == 0:
                fin = i
                break
    bloc = propre[depart + 1:fin]
    # Les clés, et le texte qui les suit jusqu'à la clé d'après : de quoi vérifier qu'une raison
    # a bien été écrite, sans avoir à analyser les guillemets triples de Swift.
    positions = [(x.group(1), x.start(), x.end()) for x in re.finditer(r'"([A-Za-z]\w*(?:\.\w+)?)"\s*:', bloc)]
    out = {}
    for i, (cle, _debut, apres) in enumerate(positions):
        suivant = positions[i + 1][1] if i + 1 < len(positions) else len(bloc)
        out[cle] = raison(bloc[apres:suivant])
    return out


def raison(brut: str) -> str:
    """Le texte d'une raison, sans ses guillemets.

    Sans ce déshabillage, `"Profil.premium": ""` se lisait comme une raison de deux caractères :
    une entrée vide passait donc le contrôle, alors que c'est exactement ce qu'il doit refuser.
    Swift écrit ces raisons soit entre guillemets simples, soit entre guillemets triples sur
    plusieurs lignes, avec des `\\` de continuation en fin de ligne.
    """
    v = brut.strip().rstrip(",").strip()
    if v.startswith('"""') and v.endswith('"""') and len(v) >= 6:
        v = v[3:-3]
    elif v.startswith('"') and v.endswith('"') and len(v) >= 2:
        v = v[1:-1]
    return re.sub(r"\\\s*\n", " ", v).strip()


# `champ = m.champ` — la ligne qui RECOPIE une propriété du modèle dans la sauvegarde.
RECOPIE = re.compile(r"^\s*(\w+) = m\.\1\b", re.M)


def recopies(source_service: str):
    """Les champs que `SauvegardeService` recopie effectivement depuis le modèle."""
    return set(RECOPIE.findall(sans_commentaires(source_service)))


def problemes(sources_modeles=None, source_sauvegarde=None, source_service=None):
    mods = modeles(sources_modeles)
    src = source_sauvegarde if source_sauvegarde is not None else SAUVEGARDE.read_text(encoding="utf-8")
    service = source_service if source_service is not None else SERVICE.read_text(encoding="utf-8")
    recopies_faites = recopies(service)

    if not mods:
        return ["Aucune classe `@Model` trouvée — le script ne vérifie plus rien."]

    correspondances = dictionnaire(src, "correspondances")
    ignores = dictionnaire(src, "modelesIgnores")
    dehors = dictionnaire(src, "nonSauvegardees")
    manquants = [n for n, d in
                 (("correspondances", correspondances), ("modelesIgnores", ignores),
                  ("nonSauvegardees", dehors)) if d is None]
    if manquants:
        return [f"`Sauvegarde.{n}` est introuvable — le script ne peut rien vérifier." for n in manquants]

    structures = structures_de_sauvegarde(src)
    griefs = []

    for modele, props in sorted(mods.items()):
        if modele in ignores:
            if not ignores[modele]:
                griefs.append(f"`modelesIgnores[\"{modele}\"]` n'écrit aucune raison.")
            continue
        if modele not in correspondances:
            griefs.append(
                f"{modele} est enregistré sur le disque et la sauvegarde ne le connaît pas.\n"
                f"      Ajoute-le à `Sauvegarde.correspondances` avec la structure qui le porte,\n"
                f"      ou à `Sauvegarde.modelesIgnores` en écrivant pourquoi il n'y est pas."
            )
            continue
        nom_struct = correspondances[modele].strip('"')
        if nom_struct not in structures:
            griefs.append(f"`Sauvegarde.correspondances[\"{modele}\"]` désigne `{nom_struct}`, "
                          f"qui n'existe pas dans Sauvegarde.swift.")
            continue
        champs = set(structures[nom_struct])
        contradictions = set()
        for prop in props:
            cle = f"{modele}.{prop}"
            if prop in champs and cle in dehors:
                contradictions.add(prop)
                griefs.append(
                    f"{cle} est à la fois un champ de `{nom_struct}` et inscrit dans\n"
                    f"      `nonSauvegardees`. Les deux ne peuvent pas être vrais."
                )
            elif prop in champs or cle in dehors:
                if cle in dehors and not dehors[cle]:
                    griefs.append(f"`nonSauvegardees[\"{cle}\"]` n'écrit aucune raison.")
            else:
                griefs.append(
                    f"{cle} est enregistré sur le disque et n'est NI sauvegardé NI inscrit\n"
                    f"      comme volontairement dehors. Ajoute le champ à `Sauvegarde.{nom_struct}`\n"
                    f"      (et son report dans `SauvegardeService`), ou une entrée\n"
                    f"      `\"{cle}\"` dans `Sauvegarde.nonSauvegardees` avec sa raison."
                )
        # DÉCLARER LE CHAMP NE LE REMPLIT PAS. Un champ ajouté à la structure et jamais
        # recopié depuis le modèle part à `nil` dans chaque fichier écrit : l'export marche, la
        # restauration réussit, et la donnée n'a jamais quitté le téléphone. C'est la panne la
        # plus silencieuse des deux, et la seule des deux qui soit définitive — dans l'autre
        # sens (recopié mais pas réappliqué), le fichier contient la donnée et une version
        # suivante peut encore la lire.
        for champ in sorted((champs & set(props)) - contradictions):
            if champ not in recopies_faites:
                griefs.append(
                    f"`Sauvegarde.{nom_struct}.{champ}` est déclaré mais jamais rempli.\n"
                    f"      Il sortira à `nil` dans tous les fichiers écrits. Ajoute\n"
                    f"      `{champ} = m.{champ}` dans `SauvegardeService`."
                )
        for champ in sorted(champs - set(props)):
            griefs.append(
                f"`Sauvegarde.{nom_struct}.{champ}` ne correspond à aucune propriété de "
                f"{modele}.\n      Le champ a survécu à la propriété : retire-le."
            )

    connus = {f"{m}.{p}" for m, props in mods.items() for p in props}
    for cle in sorted(set(dehors) - connus):
        griefs.append(
            f"`nonSauvegardees[\"{cle}\"]` nomme une propriété qui n'existe plus. Retire l'entrée."
        )
    for modele in sorted(set(ignores) - set(mods)):
        griefs.append(f"`modelesIgnores[\"{modele}\"]` nomme un modèle qui n'existe plus.")

    return griefs


def main() -> int:
    griefs = problemes()
    if griefs:
        print(f"{len(griefs)} problème(s) dans le filet de sauvegarde :\n")
        for g in griefs:
            print(f"  • {g}\n")
        print("Voir l'en-tête de RunUp/Services/Sauvegarde.swift.")
        return 1
    mods = modeles(None)
    src = SAUVEGARDE.read_text(encoding="utf-8")
    dehors = dictionnaire(src, "nonSauvegardees") or {}
    ignores = dictionnaire(src, "modelesIgnores") or {}
    total = sum(len(p) for m, p in mods.items() if m not in ignores)
    print(f"Sauvegarde : {total - len(dehors)} propriété(s) dans le filet, "
          f"{len(dehors)} volontairement dehors avec leur raison, "
          f"{len(ignores)} modèle(s) entièrement ignoré(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
