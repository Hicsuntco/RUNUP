#!/usr/bin/env python3
"""Les cas de `check_spec.py`.

CE QU'ILS EMPÊCHENT DE REVENIR. Trois cibles portaient une clé `resources:` qui n'existe pas dans
XcodeGen. Le fichier se relisait très bien, le build était vert, et la montre comme le widget
étaient français pour tout le monde et composés dans la police système.

Les deux premiers cas sont celui-là, reconstitué : la clé fantôme, et la conséquence qu'elle avait
même si on la croyait lue.

ET CE QUE LE GARDE-FOU LUI-MÊME POURRAIT RATER. Un contrôle de clés inconnues passe au vert pour
deux raisons opposées : parce que tout est reconnu, ou parce qu'il ne regarde pas au bon endroit.
Les cas « une clé valide ne sonne pas » sont là pour ça — un garde-fou qui refuse tout est aussi
inutile qu'un garde-fou qui accepte tout.
"""
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_spec as ck  # noqa: E402

cas = []


class Saute(Exception):
    """Ce cas ne peut pas tourner ici. Il s'affiche, il ne se tait pas."""


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def faux_depot(fichiers):
    """Un dossier temporaire portant les chemins demandés, chacun avec un octet dedans."""
    racine = pathlib.Path(tempfile.mkdtemp())
    for chemin in fichiers:
        f = racine / chemin
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text("x")
    return racine


def cible(**kw):
    """Une cible minimale : une application qui ne déclare ni police ni langue."""
    base = {"type": "application", "platform": "iOS", "sources": []}
    base.update(kw)
    return base


def plaintes(cibles, fichiers=()):
    racine = faux_depot(fichiers)
    return ck.verifier({"targets": cibles}, racine)


# ─── LE DÉFAUT D'ORIGINE ───────────────────────────────────────────────────────────────────────

@cas_de("la clé `resources:` est refusée, et le message dit quoi faire")
def _():
    p = plaintes({"Montre": cible(
        sources=[{"path": "Montre"}],
        resources=[{"path": "Partage/Fonts"}],
    )}, ["Montre/App.swift", "Partage/Fonts/Inter-Bold.ttf"])
    assert any("resources" in m for m in p), f"la clé fantôme est passée : {p}"
    assert any("#1645" in m for m in p), f"le message ne dit pas où chercher : {p}"


@cas_de("une police enregistrée mais non embarquée sonne")
def _():
    p = plaintes({"Montre": cible(
        sources=[{"path": "Montre"}],
        info={"properties": {"UIAppFonts": ["Inter-Bold.ttf"]}},
    )}, ["Montre/App.swift", "Partage/Fonts/Inter-Bold.ttf"])
    assert any("Inter-Bold.ttf" in m and "n'embarque pas" in m for m in p), \
        f"la police absente du paquet n'a pas été vue : {p}"


@cas_de("la même police, passée par `sources:`, ne sonne plus")
def _():
    p = plaintes({"Montre": cible(
        sources=[{"path": "Montre"},
                 {"path": "Partage/Fonts", "buildPhase": "resources"},
                 {"path": "Partage/Localizable.xcstrings", "buildPhase": "resources"}],
        info={"properties": {"UIAppFonts": ["Inter-Bold.ttf"],
                             "CFBundleLocalizations": ["fr", "en", "es"]}},
    )}, ["Montre/App.swift", "Partage/Fonts/Inter-Bold.ttf", "Partage/Localizable.xcstrings"])
    assert p == [], f"une déclaration correcte a sonné : {p}"


@cas_de("trois langues sans catalogue de chaînes sonnent")
def _():
    p = plaintes({"Montre": cible(
        sources=[{"path": "Montre"}],
        info={"properties": {"CFBundleLocalizations": ["fr", "en", "es"]}},
    )}, ["Montre/App.swift"])
    assert any("catalogue" in m for m in p), f"la cible non traduite est passée : {p}"


@cas_de("`InfoPlist.xcstrings` seul ne compte pas pour un catalogue d'interface")
def _():
    # C'est EXACTEMENT ce que portait `RunUpWatch.app` : trois `.lproj`, et dans chacun le seul
    # `InfoPlist.strings`. La cible avait l'air trilingue et ne traduisait que ses autorisations.
    p = plaintes({"Montre": cible(
        sources=[{"path": "Montre"}],
        info={"properties": {"CFBundleLocalizations": ["fr", "en", "es"]}},
    )}, ["Montre/App.swift", "Montre/InfoPlist.xcstrings"])
    assert any("catalogue" in m for m in p), \
        f"`InfoPlist.xcstrings` a été pris pour les traductions de l'interface : {p}"


@cas_de("une application sans aucune langue déclarée doit quand même être traduite")
def _():
    # Le widget ne déclarait pas de `CFBundleLocalizations` — et il était français pour tout le
    # monde. Un contrôle qui ne sonne que sur `CFBundleLocalizations` l'aurait laissé passer.
    p = plaintes({"Widget": cible(type="app-extension", sources=[{"path": "Widget"}])},
                 ["Widget/W.swift"])
    assert any("catalogue" in m for m in p), f"l'extension non traduite est passée : {p}"


@cas_de("une cible de test n'a pas à être traduite")
def _():
    p = plaintes({"Tests": cible(type="bundle.unit-test", sources=[{"path": "Tests"}])},
                 ["Tests/T.swift"])
    assert p == [], f"une cible de test a été traitée comme un écran : {p}"


# ─── LES AUTRES SILENCES DU MÊME GENRE ─────────────────────────────────────────────────────────

@cas_de("une faute de frappe sur une clé de cible sonne")
def _():
    p = plaintes({"App": cible(sources=[{"path": "App"}], setings={"base": {}})}, ["App/A.swift"])
    assert any("setings" in m for m in p), f"la faute de frappe est passée : {p}"


@cas_de("une faute de frappe sur une clé d'entrée de sources sonne")
def _():
    p = plaintes({"App": cible(sources=[{"path": "App", "exclude": ["*.md"]}])}, ["App/A.swift"])
    assert any("exclude" in m for m in p), f"`exclude` au lieu d'`excludes` est passé : {p}"


@cas_de("un `buildPhase` inconnu sonne")
def _():
    p = plaintes({"App": cible(sources=[{"path": "App", "buildPhase": "ressources"}])},
                 ["App/A.swift"])
    assert any("buildPhase" in m for m in p), f"`buildPhase: ressources` est passé : {p}"


@cas_de("un `type` d'entrée inconnu sonne")
def _():
    p = plaintes({"App": cible(sources=[{"path": "App", "type": "dossier"}])}, ["App/A.swift"])
    assert any("type" in m for m in p), f"`type: dossier` est passé : {p}"


@cas_de("toutes les clés documentées d'une cible sont acceptées")
def _():
    # Un garde-fou qui refuse une clé valide bloque le dépôt sur rien. Celui-ci doit connaître
    # toute la liste, pas seulement celles que RunUp utilise aujourd'hui.
    toutes = {c: {} for c in ck.CLES_CIBLE}
    toutes.update({"type": "bundle.unit-test", "platform": "iOS", "sources": [{"path": "App"}]})
    p = plaintes({"App": toutes}, ["App/A.swift"])
    assert p == [], f"une clé documentée a été refusée : {p}"


@cas_de("toutes les clés documentées d'une entrée de sources sont acceptées")
def _():
    entree = {c: None for c in ck.CLES_SOURCE}
    entree.update({"path": "App", "excludes": [], "includes": [], "buildPhase": "resources",
                   "type": "group"})
    p = plaintes({"App": cible(type="bundle.unit-test", sources=[entree])}, ["App/A.swift"])
    assert p == [], f"une clé documentée d'entrée a été refusée : {p}"


# ─── CE QUE `sources:` EMBARQUE VRAIMENT ───────────────────────────────────────────────────────

@cas_de("`excludes` écarte bien un fichier du paquet")
def _():
    p = plaintes({"Montre": cible(
        sources=[{"path": "Fonts", "buildPhase": "resources", "excludes": ["Inter-Light.ttf"]}],
        info={"properties": {"UIAppFonts": ["Inter-Light.ttf"]}},
    )}, ["Fonts/Inter-Light.ttf"])
    assert any("Inter-Light.ttf" in m for m in p), \
        f"un fichier exclu a été compté comme livré : {p}"


@cas_de("`excludes` relatif à un sous-dossier écarte le bon fichier")
def _():
    # C'est la forme qu'utilise la cible iOS : `Resources/Fonts/*.md`, relatif au `path`.
    f = ck.fichiers_embarques(
        {"sources": [{"path": "App", "excludes": ["Resources/Fonts/*.md"]}]},
        faux_depot(["App/Resources/Fonts/Inter.ttf", "App/Resources/Fonts/LISEZMOI.md"]))
    noms = sorted(x.name for x in f)
    assert noms == ["Inter.ttf"], f"l'exclusion n'a pas porté : {noms}"


@cas_de("`buildPhase: none` n'embarque rien")
def _():
    f = ck.fichiers_embarques(
        {"sources": [{"path": "App", "buildPhase": "none"}]},
        faux_depot(["App/A.swift"]))
    assert f == set(), f"une entrée hors phase a été comptée : {f}"


@cas_de("un fichier nommé un par un est embarqué")
def _():
    f = ck.fichiers_embarques(
        {"sources": [{"path": "Partage/Localizable.xcstrings", "buildPhase": "resources"}]},
        faux_depot(["Partage/Localizable.xcstrings", "Partage/Autre.xcstrings"]))
    noms = sorted(x.name for x in f)
    assert noms == ["Localizable.xcstrings"], f"mauvais périmètre : {noms}"


@cas_de("une entrée écrite en chaîne simple est lue comme un chemin")
def _():
    # `sources: - App` est une forme valide du format. La lire comme un dictionnaire planterait.
    f = ck.fichiers_embarques({"sources": ["App"]}, faux_depot(["App/A.swift"]))
    assert len(f) == 1, f"la forme courte de `sources:` n'a pas été lue : {f}"


@cas_de("un chemin absent ne fait pas planter le contrôle")
def _():
    # `optional: true` existe dans le format, et un chemin manquant doit se signaler par une
    # ressource non livrée, pas par une pile d'appels.
    p = plaintes({"App": cible(
        sources=[{"path": "Nulle/Part"}],
        info={"properties": {"UIAppFonts": ["Inter-Bold.ttf"]}},
    )})
    assert any("Inter-Bold.ttf" in m for m in p), f"attendu une police non livrée : {p}"


# ─── LE LECTEUR DE project.yml ─────────────────────────────────────────────────────────────────
#
# Ce script lit le YAML à la main, parce que le python du runner macOS n'a pas PyYAML et que ce
# job n'installe rien. Un lecteur maison qui se trompe en silence serait pire que pas de contrôle
# du tout : une cible mal lue est une cible dont on ne vérifie plus rien. D'où le premier cas
# ci-dessous, qui est le plus important de ce fichier.

@cas_de("la lecture maison du VRAI project.yml est identique à celle de PyYAML")
def _():
    try:
        import yaml
    except ImportError:
        raise Saute("PyYAML absent ici — ce cas tourne sur un poste de développement")
    texte = (ICI.parent / "project.yml").read_text(encoding="utf-8")
    assert ck.lire(texte) == yaml.safe_load(texte), \
        "le lecteur maison et PyYAML ne lisent pas le même fichier"


@cas_de("un deux-points sans espace n'est pas une clé")
def _():
    # `- applinks:runup-nu.vercel.app`, dans les entitlements, était lu comme une table. C'est la
    # comparaison avec PyYAML qui l'a dit, et ce cas est là pour que ça ne revienne pas.
    lu = ck.lire("domaines:\n  - applinks:exemple.fr\n")
    assert lu == {"domaines": ["applinks:exemple.fr"]}, lu


@cas_de("une liste en ligne est lue, vide ou pleine")
def _():
    lu = ck.lire("acces: []\nschema: [run, test]\n")
    assert lu == {"acces": [], "schema": ["run", "test"]}, lu


@cas_de("une liste de tables imbriquées est lue")
def _():
    lu = ck.lire(
        "sources:\n"
        "  - path: App\n"
        "    excludes:\n"
        "      - \"*.md\"\n"
        "  - path: Partage/Fonts\n"
        "    buildPhase: resources\n")
    assert lu == {"sources": [
        {"path": "App", "excludes": ["*.md"]},
        {"path": "Partage/Fonts", "buildPhase": "resources"}]}, lu


@cas_de("les booléens de YAML 1.1 sont lus comme PyYAML les lit")
def _():
    lu = ck.lire("a: YES\nb: true\nc: NO\nd: off\ne: Automatic\n")
    assert lu == {"a": True, "b": True, "c": False, "d": False, "e": "Automatic"}, lu


@cas_de("les commentaires et les lignes vides ne comptent pas")
def _():
    lu = ck.lire("# en tête\ncle: valeur\n\n  # dedans\n")
    assert lu == {"cle": "valeur"}, lu


@cas_de("une tabulation est refusée au lieu d'être devinée")
def _():
    try:
        ck.lire("cle:\n\t- a\n")
    except ck.ErreurDeLecture:
        return
    raise AssertionError("une tabulation est passée")


@cas_de("un bloc littéral est refusé au lieu d'être deviné")
def _():
    # `run: |` dans un workflow est courant ; dans project.yml ce serait une construction que ce
    # lecteur ne sait pas lire. Mieux vaut qu'il le dise que qu'il rende la moitié du fichier.
    try:
        ck.lire("script: |\n  deux lignes\n  de texte\n")
    except ck.ErreurDeLecture:
        return
    raise AssertionError("un bloc littéral est passé")


@cas_de("une ancre est refusée au lieu d'être devinée")
def _():
    try:
        ck.lire("base: &commun\n  a: 1\n")
    except ck.ErreurDeLecture:
        return
    raise AssertionError("une ancre est passée")


@cas_de("une clé vide rend None, pas une table vide")
def _():
    lu = ck.lire("a:\nb: 1\n")
    assert lu == {"a": None, "b": 1}, lu


def main():
    echecs = 0
    sautes = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except Saute as e:
            sautes += 1
            print(f"  sauté {nom} — {e}")
        except AssertionError as e:
            echecs += 1
            print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs - sautes}/{len(cas)} cas passent"
          + (f", {sautes} sauté(s)." if sautes else "."))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
