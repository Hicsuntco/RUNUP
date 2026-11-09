#!/usr/bin/env python3
"""Refuse un `project.yml` dont XcodeGen jetterait une partie en silence.

# LE DÉFAUT QUI A FAIT ÉCRIRE CE SCRIPT

`project.yml` portait, sur trois cibles, une clé `resources:` listant les polices et le catalogue
de traductions. Cette clé N'EXISTE PAS. `Docs/ProjectSpec.md` § Target ne la liste pas,
`Target.init(jsonDictionary:)` n'a aucune branche pour elle, et `SourceGenerator.getAllSourceFiles`
ne regarde que `target.sources` : la valeur est lue, puis jetée, sans erreur ni avertissement
(ticket XcodeGen #1645, ouvert — XcodeGen 2.46.0).

Conséquence mesurée dans le paquet construit (`RunUpWatch.app`, commit 5cadd52) : aucun
`Localizable.strings`, aucun `.ttf`. La montre parlait français à tout le monde et s'affichait
dans la police système. Le widget de l'écran d'accueil aussi, pour la même raison. Pendant ce
temps le build était vert, `check_fonts.py` était vert, et les captures montraient un écran
français qu'on prenait pour la capture française.

Un fichier de configuration qui accepte n'importe quelle clé sans rien dire est un piège : on y
écrit une intention, on la relit, on la croit. Ce script fait la seule chose qui aurait arrêté ça.

# CE QU'IL VÉRIFIE

1. CLÉS INCONNUES. Toute clé de cible et toute clé d'entrée de `sources:` absente des listes
   documentées est refusée — `resources`, mais aussi une faute de frappe (`ressources`,
   `exclude` au lieu d'`excludes`, `buildphase`…), qui coûterait exactement le même silence.
2. VALEURS INCONNUES de `buildPhase` et de `type`, pour la même raison.
3. POLICES NON LIVRÉES. Chaque fichier nommé dans l'`UIAppFonts` d'une cible doit se trouver
   dans les fichiers que CETTE cible embarque. `Font.custom` sur une police absente ne lève
   rien : SwiftUI retombe sur la police système en silence. `check_fonts.py` compare le code,
   l'`UIAppFonts` et les noms PostScript des fichiers — jamais la livraison. C'est le trou.
4. TRADUCTIONS NON LIVRÉES. Une cible qui déclare plusieurs langues dans `CFBundleLocalizations`
   doit embarquer un catalogue de chaînes autre qu'`InfoPlist.xcstrings` — celui-ci ne traduit
   que les descriptions d'autorisation, pas l'interface. Sans catalogue, `Text("Courir")` retombe
   sur sa clé, qui est du français parfaitement lisible : rien ne se voit.

# CE QU'IL NE VÉRIFIE PAS

Les clés au niveau du PROJET (`options`, `schemes`, `packages`…) : je n'ai pas relevé cette liste
dans la documentation, et deviner reviendrait à refuser une clé valide.

Il ne vérifie pas non plus le PAQUET CONSTRUIT. Il lit le fichier, donc il attrape la cause et
non le symptôme — mais une erreur d'XcodeGen qu'il ne connaît pas lui échapperait. La sonde qui
ouvre `RunUpWatch.app` et y cherche les fichiers, elle, vit dans `.github/workflows/montre.yml`.
"""
import fnmatch
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
SPEC = RACINE / "project.yml"

# Les clés d'une cible, telles que `Docs/ProjectSpec.md` § Target les liste (XcodeGen 2.46.0).
CLES_CIBLE = {
    "type", "platform", "supportedDestinations", "deploymentTarget", "sources", "configFiles",
    "settings", "dependencies", "info", "entitlements", "templates", "templateAttributes",
    "transitivelyLinkDependencies", "directlyEmbedCarthageDependencies", "requiresObjCLinking",
    "onlyCopyFilesOnInstall", "buildToolPlugins", "preBuildScripts", "postCompileScripts",
    "postBuildScripts", "buildRules", "scheme", "legacy", "attributes",
    "putResourcesBeforeSourcesBuildPhase",
}

# Les clés d'une entrée de `sources:`, § Target Source.
CLES_SOURCE = {
    "path", "name", "group", "compilerFlags", "excludes", "includes", "explicitFolders",
    "destinationFilters", "inferDestinationFiltersByPath", "createIntermediateGroups", "optional",
    "buildPhase", "type", "headerVisibility", "attributes", "resourceTags",
}

PHASES = {"sources", "resources", "headers", "copyFiles", "none"}
TYPES = {"file", "group", "folder", "syncedFolder"}

# Ce que ce catalogue traduit — les `NS*UsageDescription` — ne couvre pas l'interface. Une cible
# qui n'embarque que celui-ci est une cible non traduite.
PAS_UN_CATALOGUE_D_INTERFACE = "InfoPlist.xcstrings"

# Les cibles dont quelqu'un lit l'écran. Les cibles de test n'affichent rien à personne.
CIBLES_QUI_S_AFFICHENT = {"application", "app-extension"}


# ───────────────────────── LIRE project.yml SANS PyYAML ────────────────────────────────────────
#
# POURQUOI PAS `yaml.safe_load`. Ce contrôle tourne dans `testflight.yml`, dont le python est
# celui du système, et ce job n'installe rien ; `pip install` nu est refusé sur les runners
# macOS. C'est la même décision, écrite pour la même raison, que dans `check_cablage.py` —
# et ce script l'avait d'abord enfreinte.
#
# UN LECTEUR MAISON PEUT SE TROMPER EN SILENCE, et ce serait pire que pas de contrôle du tout :
# une cible mal lue est une cible dont on ne vérifie plus rien. Deux garde-fous contre ça :
#
#   · il REFUSE tout ce qu'il ne comprend pas (tabulation, bloc littéral, ancre, accolade,
#     document multiple, ligne inclassable) plutôt que de passer outre. Le silence est l'ennemi,
#     donc toute surprise est une erreur bruyante ;
#   · `test_spec.py` compare sa lecture du VRAI `project.yml` à celle de PyYAML partout où PyYAML
#     est installé — ma machine, et tout poste de développement. Une divergence tombe là.

# Le deux-points doit être suivi d'une ESPACE ou de la fin de ligne, sinon ce n'est pas une clé.
# Sans cette exigence, l'élément `- applinks:runup-nu.vercel.app` des entitlements était lu comme
# une table `{applinks: runup-nu.vercel.app}` au lieu d'une chaîne. C'est la comparaison avec
# PyYAML, dans `test_spec.py`, qui l'a dit — et c'est précisément pour ça qu'elle existe.
MOTIF_CLE = re.compile(r"^([A-Za-z0-9_.\-/$()]+):(?=\s|$)(.*)$")

# Les mots que YAML 1.1 — donc PyYAML — lit comme des booléens.
VRAIS = {"y", "Y", "yes", "Yes", "YES", "true", "True", "TRUE", "on", "On", "ON"}
FAUX = {"n", "N", "no", "No", "NO", "false", "False", "FALSE", "off", "Off", "OFF"}


class ErreurDeLecture(Exception):
    """Le fichier emploie une construction que ce lecteur ne sait pas lire. Jamais ignorée."""


def _scalaire(brut, n):
    v = brut.strip()
    for interdit, quoi in (("|", "bloc littéral"), (">", "bloc replié"), ("&", "ancre"),
                           ("*", "alias"), ("{", "table en ligne")):
        if v.startswith(interdit):
            raise ErreurDeLecture(f"ligne {n} : {quoi} — ce lecteur ne sait pas le lire.")
    if v.startswith("["):
        if not v.endswith("]"):
            raise ErreurDeLecture(f"ligne {n} : liste en ligne non fermée.")
        corps = v[1:-1].strip()
        return [] if not corps else [_scalaire(x, n) for x in corps.split(",")]
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    if " #" in v:
        v = v.split(" #", 1)[0].strip()
    if v in VRAIS:
        return True
    if v in FAUX:
        return False
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    if re.fullmatch(r"-?\d+\.\d+", v):
        return float(v)
    return v


def _lignes(texte):
    """(indentation, contenu, numéro) des lignes qui portent quelque chose."""
    out = []
    for n, brute in enumerate(texte.split("\n"), 1):
        if "\t" in brute:
            raise ErreurDeLecture(f"ligne {n} : tabulation.")
        nue = brute.strip()
        if not nue or nue.startswith("#"):
            continue
        if nue.startswith("---") or nue.startswith("..."):
            raise ErreurDeLecture(f"ligne {n} : document multiple.")
        out.append((len(brute) - len(brute.lstrip(" ")), nue, n))
    return out


def _bloc(lignes, i, indent):
    """Lit la valeur composée qui commence à `lignes[i]` au niveau `indent`. Rend (valeur, i)."""
    if lignes[i][1] == "-" or lignes[i][1].startswith("- "):
        return _liste(lignes, i, indent)
    return _table(lignes, i, indent)


def _table(lignes, i, indent):
    table = {}
    while i < len(lignes) and lignes[i][0] == indent:
        _, contenu, n = lignes[i]
        m = MOTIF_CLE.match(contenu)
        if not m:
            raise ErreurDeLecture(f"ligne {n} : « {contenu} » n'est ni une clé ni un élément.")
        cle, reste = m.group(1), m.group(2).strip()
        i += 1
        if reste and not reste.startswith("#"):
            table[cle] = _scalaire(reste, n)
            continue
        if i < len(lignes) and lignes[i][0] > indent:
            table[cle], i = _bloc(lignes, i, lignes[i][0])
        else:
            table[cle] = None
    return table, i


def _liste(lignes, i, indent):
    liste = []
    while i < len(lignes) and lignes[i][0] == indent and (
            lignes[i][1] == "-" or lignes[i][1].startswith("- ")):
        _, contenu, n = lignes[i]
        tete = contenu[2:].strip() if contenu.startswith("- ") else ""
        # Les lignes qui prolongent cet élément : celles plus indentées que le tiret.
        j = i + 1
        while j < len(lignes) and lignes[j][0] > indent:
            j += 1
        suite = lignes[i + 1:j]
        if tete and MOTIF_CLE.match(tete) and not tete.startswith("\"") \
                and not tete.startswith("'"):
            # Un élément-table : sa première clé est sur la ligne du tiret, le reste en dessous.
            propre = [(indent + 2, tete, n)] + [(ln[0], ln[1], ln[2]) for ln in suite]
            valeur, k = _table(propre, 0, indent + 2)
            if k != len(propre):
                raise ErreurDeLecture(f"ligne {propre[k][2]} : indentation inattendue.")
            liste.append(valeur)
        elif tete:
            if suite:
                raise ErreurDeLecture(f"ligne {suite[0][2]} : élément scalaire suivi d'un bloc.")
            liste.append(_scalaire(tete, n))
        else:
            if not suite:
                raise ErreurDeLecture(f"ligne {n} : tiret sans valeur.")
            valeur, k = _bloc(suite, 0, suite[0][0])
            if k != len(suite):
                raise ErreurDeLecture(f"ligne {suite[k][2]} : indentation inattendue.")
            liste.append(valeur)
        i = j
    return liste, i


def lire(texte):
    """project.yml, en structures Python. Lève `ErreurDeLecture` plutôt que de deviner."""
    lignes = _lignes(texte)
    if not lignes:
        return {}
    valeur, i = _bloc(lignes, 0, lignes[0][0])
    if i != len(lignes):
        raise ErreurDeLecture(f"ligne {lignes[i][2]} : indentation inattendue.")
    return valeur


def entrees(cible):
    """Les entrées de `sources:`, qu'elles soient écrites en chaîne ou en dictionnaire."""
    for e in cible.get("sources") or []:
        yield {"path": e} if isinstance(e, str) else e


def exclu(relatif, motifs):
    """Vrai si ce chemin relatif tombe sous l'un des motifs d'exclusion.

    Les motifs sont relatifs au `path` de l'entrée (§ Target Source : « relative to `path` »).
    La comparaison est volontairement LARGE — chemin complet, nom seul, et chaque dossier parent.
    Trop exclure fait croire à une ressource non livrée, donc fait SONNER le script ; trop peu
    excluerait la détection. Entre une fausse alerte et un silence, on choisit l'alerte.
    """
    candidats = [relatif.as_posix(), relatif.name] + [p.as_posix() for p in relatif.parents]
    return any(fnmatch.fnmatch(c, m) for m in motifs for c in candidats)


def fichiers_embarques(cible, racine=RACINE):
    """Les fichiers que cette cible emporte réellement, d'après ses seules entrées `sources:`.

    C'est la seule liste qui compte : `getAllSourceFiles` ne regarde rien d'autre.
    """
    vus = set()
    for e in entrees(cible):
        if e.get("buildPhase") == "none":
            continue
        chemin = racine / e["path"]
        if chemin.is_file():
            vus.add(chemin)
            continue
        if not chemin.is_dir():
            continue
        motifs = e.get("excludes") or []
        gardes = e.get("includes") or []
        for f in sorted(chemin.rglob("*")):
            if not f.is_file():
                continue
            relatif = f.relative_to(chemin)
            if exclu(relatif, motifs):
                continue
            if gardes and not exclu(relatif, gardes):
                continue
            vus.add(f)
    return vus


def verifier(spec=None, racine=RACINE):
    """Les plaintes, dans l'ordre où on les lit. Vide = le fichier dit ce qu'il fait."""
    if spec is None:
        spec = lire((racine / "project.yml").read_text(encoding="utf-8"))
    plaintes = []

    for nom, cible in (spec.get("targets") or {}).items():
        for cle in sorted(set(cible) - CLES_CIBLE):
            detail = ""
            if cle == "resources":
                detail = (" — cette clé n'existe pas : XcodeGen la jette en silence et les"
                          " ressources n'entrent jamais dans le paquet. Passe-les dans `sources:`"
                          " avec `buildPhase: resources` (ticket XcodeGen #1645)")
            plaintes.append(f"{nom} : clé de cible inconnue « {cle} »{detail}.")

        for e in entrees(cible):
            ou = f"{nom} / sources[{e.get('path', '?')}]"
            for cle in sorted(set(e) - CLES_SOURCE):
                plaintes.append(f"{ou} : clé inconnue « {cle} ».")
            if "buildPhase" in e and isinstance(e["buildPhase"], str) \
                    and e["buildPhase"] not in PHASES:
                plaintes.append(f"{ou} : `buildPhase: {e['buildPhase']}` inconnu "
                                f"(attendus : {', '.join(sorted(PHASES))}).")
            if "type" in e and e["type"] not in TYPES:
                plaintes.append(f"{ou} : `type: {e['type']}` inconnu "
                                f"(attendus : {', '.join(sorted(TYPES))}).")

        proprietes = (cible.get("info") or {}).get("properties") or {}
        embarques = fichiers_embarques(cible, racine)
        noms = {f.name for f in embarques}

        for police in proprietes.get("UIAppFonts") or []:
            if police not in noms:
                plaintes.append(
                    f"{nom} : `UIAppFonts` enregistre « {police} », que cette cible n'embarque "
                    f"pas. SwiftUI retombera sur la police système sans rien dire.")

        langues = proprietes.get("CFBundleLocalizations") or []
        # Une cible qui s'affiche doit porter ses traductions, qu'elle déclare ses langues ou non :
        # le widget n'a pas de `CFBundleLocalizations` (ses `.lproj` suffisent à les faire
        # découvrir) et il était pourtant français pour tout le monde.
        if len(langues) > 1 or cible.get("type") in CIBLES_QUI_S_AFFICHENT:
            catalogues = sorted(n for n in noms
                                if n.endswith(".xcstrings") and n != PAS_UN_CATALOGUE_D_INTERFACE)
            if not catalogues:
                dit = (f"{len(langues)} langues déclarées ({', '.join(langues)})"
                       if len(langues) > 1 else f"cible « {cible.get('type')} » affichant du texte")
                plaintes.append(
                    f"{nom} : {dit} et aucun catalogue de chaînes embarqué. Chaque "
                    f"`Text(\"…\")` affichera sa clé française, dans toutes les langues.")

    return plaintes


def main():
    try:
        plaintes = verifier()
    except ErreurDeLecture as e:
        print(f"✗ project.yml : {e}")
        print("  Ce contrôle refuse de juger un fichier qu'il n'a pas lu en entier.")
        return 1
    for p in plaintes:
        print(f"✗ {p}")
    if plaintes:
        print(f"\n{len(plaintes)} problème(s) dans project.yml.")
        return 1
    print("✓ project.yml : aucune clé inconnue, polices et traductions livrées à chaque cible.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
