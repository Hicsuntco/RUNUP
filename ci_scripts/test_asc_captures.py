#!/usr/bin/env python3
"""Ce que `asc.py push-screenshots` et `push-previews` décident SANS parler à Apple.

Le reste de la commande est du réseau et ne se teste pas ici. Mais trois décisions se prennent
avant le premier appel, et chacune se trompe en silence :

  — la TAILLE lue dans l'image, qui décide du type d'appareil sous lequel la capture est rangée ;
  — l'ORDRE des fichiers, qui décide de quelle accroche se retrouve sur quelle image ;
  — le refus d'une taille inconnue, qui doit arrêter la commande au lieu de deviner.

Une image rangée sous le mauvais appareil n'échoue pas : elle apparaît au mauvais endroit dans
la fiche, et on le découvre en la regardant.
"""

import pathlib
import shutil
import subprocess
import sys
import tempfile

import asc

cas = []

# CE FICHIER TOURNE SUR DEUX MACHINES QUI N'ONT PAS LE MÊME OUTILLAGE.
#
# `testflight.yml` l'exécute sur un runner Ubuntu nu, `captures.yml` après avoir installé
# ffmpeg. Les cas de l'aperçu fabriquent de vrais fichiers vidéo : sans ffmpeg ils ne peuvent
# pas s'exécuter, et ils ont fait échouer une construction entière sur un `FileNotFoundError`.
#
# Les ignorer en silence serait pire que l'échec : un test qu'on croit passé et qui ne tourne
# nulle part. Ils sont donc NOMMÉS comme ignorés, et comptés à part — et ils tournent bien, à
# chaque envoi d'aperçu, là où ffmpeg existe.
FFMPEG = shutil.which("ffmpeg") is not None and shutil.which("ffprobe") is not None


def cas_test(nom, besoin_ffmpeg=False):
    def prendre(f):
        cas.append((nom, f, besoin_ffmpeg)); return f
    return prendre


def png(largeur, hauteur) -> bytes:
    """Un en-tête PNG valide. `taille_png` ne lit que les 24 premiers octets."""
    return (b"\x89PNG\r\n\x1a\n" + (13).to_bytes(4, "big") + b"IHDR"
            + largeur.to_bytes(4, "big") + hauteur.to_bytes(4, "big"))


@cas_test("la taille se lit dans l'en-tête, sans Pillow")
def _():
    with tempfile.TemporaryDirectory() as d:
        f = pathlib.Path(d) / "1.png"
        f.write_bytes(png(1290, 2796))
        assert asc.taille_png(f) == (1290, 2796), asc.taille_png(f)


@cas_test("ce que produit screenshots.py est un iPhone 6,7 pouces")
def _():
    # 1290 × 2796 est la taille que `screenshots.py` compose. Si elle cessait d'être connue
    # d'Apple, la commande s'arrêterait — et ce test le dirait avant.
    assert asc.TYPES_PAR_TAILLE[(1290, 2796)] == "APP_IPHONE_67"


@cas_test("la taille brute du simulateur est un 6,9 pouces, et pas la même")
def _():
    # Les captures BRUTES font 1320 × 2868. Les envoyer telles quelles les rangerait sous un
    # autre appareil que les composées — deux séries, deux catégories, dans la même fiche.
    assert asc.TYPES_PAR_TAILLE[(1320, 2868)] == "APP_IPHONE_69"
    assert asc.TYPES_PAR_TAILLE[(1320, 2868)] != asc.TYPES_PAR_TAILLE[(1290, 2796)]


@cas_test("la montre est une taille connue, parce qu'Apple l'exige")
def _():
    # « Your binary indicates support for Apple Watch. You must provide an Apple Watch
    # screenshot. » La build embarque une app watchOS : sans cette capture, la soumission est
    # refusée. Elle a été supprimée une fois, et la version est restée bloquée.
    assert asc.TYPES_PAR_TAILLE[(416, 496)] == "APP_WATCH_SERIES_10"


@cas_test("une taille inconnue n'est pas devinée")
def _():
    assert (1000, 1000) not in asc.TYPES_PAR_TAILLE


@cas_test("un fichier qui n'est pas un PNG arrête la commande")
def _():
    with tempfile.TemporaryDirectory() as d:
        f = pathlib.Path(d) / "pas-une-image.png"
        f.write_bytes(b"GIF89a" + b"\x00" * 40)
        try:
            asc.taille_png(f)
        except SystemExit:
            return
        raise AssertionError("un GIF déguisé en .png est passé")


@cas_test("2 passe avant 10, et 1 reste premier")
def _():
    noms = ["10.png", "2.png", "1.png", "6.png"]
    assert sorted(noms, key=asc.ordre_naturel) == ["1.png", "2.png", "6.png", "10.png"]


@cas_test("l'ordre tient aussi sur les noms des brutes")
def _():
    noms = ["6-stats.png", "1-accueil.png", "2-plan.png"]
    assert sorted(noms, key=asc.ordre_naturel)[0] == "1-accueil.png"


@cas_test("toutes les tailles connues sont des entiers positifs vers un type Apple")
def _():
    for (l, h), type_ in asc.TYPES_PAR_TAILLE.items():
        assert l > 0 and h > 0, (l, h)
        assert type_.startswith(("APP_IPHONE_", "APP_IPAD_", "APP_WATCH_")), type_


# ── L'APERÇU VIDÉO ───────────────────────────────────────────────────────────────────────────
# Les mêmes décisions, prises sur un film : la taille range l'aperçu sous un appareil, et trois
# bornes d'Apple doivent être refusées ICI plutôt que dans un « Invalid video » après trois
# minutes de téléversement.


def film(largeur, hauteur, secondes, ips=30) -> pathlib.Path:
    """Un vrai .mp4, fabriqué par ffmpeg : c'est ffprobe qu'on éprouve, pas une simulation."""
    d = pathlib.Path(tempfile.mkdtemp())
    sortie = d / "fr-FR.mp4"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-f", "lavfi", "-i", f"testsrc=size={largeur}x{hauteur}:rate={ips}",
                    "-t", str(secondes), "-c:v", "libx264", "-pix_fmt", "yuv420p", str(sortie)],
                   check=True)
    return sortie


def refuse(dossier) -> str:
    """Lance la commande sur ce dossier et rend ce qu'elle a dit en s'arrêtant."""
    class Args:
        version, dir, dry_run = "0.0", str(dossier), True
    try:
        asc.cmd_push_previews(Args())
    except SystemExit as e:
        return str(e)
    return ""


@cas_test("ce que produit montage.py est une taille d'aperçu connue")
def _():
    # 886 × 1920 est ce que compose `montage.py`. Si cette taille cessait d'être dans la table,
    # la commande s'arrêterait — et ce test le dirait avant.
    assert (886, 1920) in asc.TYPES_APERCU_PAR_TAILLE


@cas_test("les types d'aperçu sont essayés, pas devinés")
def _():
    # Une LISTE de noms, parce que la documentation d'Apple ne se laisse pas lire en ligne de
    # commande et qu'on fait trancher l'API. Le jour où elle se réduit à une valeur sûre, ce
    # test tombera — et ce sera le bon moment pour le mettre à jour.
    for taille, candidats in asc.TYPES_APERCU_PAR_TAILLE.items():
        assert isinstance(candidats, tuple) and len(candidats) >= 2, taille
        assert len(set(candidats)) == len(candidats), f"doublon dans {candidats}"


@cas_test("ffprobe rend la taille, la durée et la cadence", besoin_ffmpeg=True)
def _():
    f = film(886, 1920, 2, 30)
    largeur, hauteur, secondes, ips = asc.mesurer_mp4(f)
    assert (largeur, hauteur) == (886, 1920), (largeur, hauteur)
    assert 1.8 <= secondes <= 2.2, secondes
    assert 29.5 <= ips <= 30.5, ips


@cas_test("un film trop court est refusé en nommant la borne", besoin_ffmpeg=True)
def _():
    dit = refuse(film(886, 1920, 5).parent)
    assert "5.0 s" in dit and "15" in dit and "30" in dit, dit


@cas_test("un film trop long aussi", besoin_ffmpeg=True)
def _():
    dit = refuse(film(886, 1920, 32).parent)
    assert "32" in dit and "hors des" in dit, dit


@cas_test("une taille d'aperçu inconnue arrête la commande", besoin_ffmpeg=True)
def _():
    dit = refuse(film(800, 1600, 20).parent)
    assert "800×1600" in dit and "rien n'a été envoyé" in dit, dit


@cas_test("une cadence au-delà de trente images est refusée", besoin_ffmpeg=True)
def _():
    dit = refuse(film(886, 1920, 16, ips=60).parent)
    assert "images par seconde" in dit, dit


@cas_test("un dossier sans film le dit")
def _():
    with tempfile.TemporaryDirectory() as d:
        assert "Aucun .mp4" in refuse(d)


@cas_test("un film dans les clous passe la vérification et s'arrête faute de clé", besoin_ffmpeg=True)
def _():
    # La commande lit TOUT avant de parler à Apple : sans clé d'API, elle doit donc avoir déjà
    # mesuré le film. C'est ce qui permet à un essai de dire ce qu'il enverrait même quand la
    # version n'existe pas encore.
    dit = refuse(film(886, 1920, 20).parent)
    assert "hors des" not in dit and "inconnue" not in dit, dit


# ── L'ÉLAGAGE DES CAPTURES QUI N'ONT AUCUNE RAISON D'ÊTRE ────────────────────────────────────
#
# La fiche de la 3.3 est partie EN VENTE avec une capture iPad : une mise en page iPhone étirée
# dans un cadre d'iPad, sur une app qui ne vise que l'iPhone. Elle n'a pas pu en être retirée —
# Apple fige une version en vente — et elle sera recopiée dans la 3.4 à sa création, comme dans
# toutes les suivantes.
#
# `create-version` élague donc d'office. Ces cas tiennent les deux bords de ce geste : qu'il
# retire bien ce qui n'a pas de raison d'être, et qu'il NE retire pas la capture Apple Watch, dont
# l'absence bloque la soumission.


class FausseFiche:
    """Une fiche App Store en mémoire, pour exercer l'élagage sans parler à Apple."""

    def __init__(self, jeux):
        # jeux : {langue: [types d'affichage]}
        self.jeux = {lg: list(types) for lg, types in jeux.items()}
        self.supprimes = []
        self.versions_creees = []

    def call(self, methode, chemin, corps=None):
        if methode == "POST" and chemin == "appStoreVersions":
            self.versions_creees.append(corps["data"]["attributes"]["versionString"])
            return {"data": {"id": "v-neuve", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}}
        if methode == "GET" and "filter[versionString]" in chemin:
            return {"data": []}
        if methode == "GET" and chemin.endswith("appStoreVersionLocalizations"):
            return {"data": [{"id": f"loc-{lg}", "attributes": {"locale": lg}}
                             for lg in self.jeux]}
        if methode == "GET" and chemin.endswith("appScreenshotSets"):
            lg = chemin.split("appStoreVersionLocalizations/loc-")[1].split("/")[0]
            return {"data": [{"id": f"jeu-{lg}-{t}", "attributes": {"screenshotDisplayType": t}}
                             for t in self.jeux[lg]]}
        if methode == "GET" and chemin.endswith("appScreenshots"):
            jeu = chemin.split("appScreenshotSets/")[1].split("/")[0]
            return {"data": [{"id": f"{jeu}-img{i}"} for i in range(3)]}
        if methode == "DELETE":
            self.supprimes.append(chemin)
            return {}
        raise AssertionError(f"appel non prévu : {methode} {chemin}")


def avec_fiche(jeux, bloc):
    """Exécute `bloc(fiche)` en remplaçant le réseau d'`asc` par une fiche en mémoire."""
    fiche = FausseFiche(jeux)
    vrai_call, vrai_app_id = asc.call, asc.app_id
    asc.call = fiche.call
    asc.app_id = lambda: ("app-1", "RUNUP")
    try:
        bloc(fiche)
    finally:
        asc.call, asc.app_id = vrai_call, vrai_app_id
    return fiche


TROIS_LANGUES = {"en-US": ["APP_IPHONE_67", "APP_IPAD_PRO_3GEN_129", "APP_WATCH_SERIES_10"],
                 "es-ES": ["APP_IPHONE_67", "APP_IPAD_PRO_3GEN_129", "APP_WATCH_SERIES_10"],
                 "fr-FR": ["APP_IPHONE_67", "APP_IPAD_PRO_3GEN_129", "APP_WATCH_SERIES_10"]}


@cas_test("la capture Apple Watch n'est JAMAIS dans les formats sans raison")
def _():
    # Une première version de l'élagage gardait `APP_IPHONE_67` et supprimait tout le reste : elle
    # a emporté la montre, qu'Apple EXIGE dès que la build embarque une app watchOS, et la version
    # est restée bloquée deux heures sur un message qui n'apparaît que dans l'interface web.
    for interdit in ("APP_WATCH_SERIES_10", "APP_WATCH_SERIES_7", "APP_WATCH_ULTRA",
                     "APP_IPHONE_67", "APP_IPHONE_65"):
        assert not any(interdit in f for f in asc.FORMATS_SANS_RAISON), \
            f"{interdit} est dans FORMATS_SANS_RAISON : son absence bloque la soumission"


@cas_test("les formats sans raison ne sont pas une liste vide")
def _():
    # Vert pour la mauvaise raison : une liste vide ferait passer tous les cas ci-dessous sans que
    # l'élagage d'office ne retire jamais rien.
    assert asc.FORMATS_SANS_RAISON, "la liste est vide : l'élagage d'office ne fait plus rien"


@cas_test("l'élagage ne retire que les formats nommés, dans toutes les langues")
def _():
    f = avec_fiche(TROIS_LANGUES,
                   lambda fi: asc.elaguer_les_captures("v-1", {"APP_IPAD_PRO_3GEN_129"}))
    # Trois images par jeu, trois langues, plus la suppression du jeu lui-même.
    assert len([c for c in f.supprimes if c.startswith("appScreenshots/")]) == 9, f.supprimes
    assert len([c for c in f.supprimes if c.startswith("appScreenshotSets/")]) == 3, f.supprimes
    assert all("IPAD" in c for c in f.supprimes), \
        f"l'élagage a touché autre chose que l'iPad : {f.supprimes}"


@cas_test("un essai ne supprime rien et compte quand même")
def _():
    compte = []
    f = avec_fiche(TROIS_LANGUES,
                   lambda fi: compte.append(
                       asc.elaguer_les_captures("v-1", {"APP_IPAD_PRO_3GEN_129"}, dry_run=True)))
    assert f.supprimes == [], f.supprimes
    assert compte == [9], compte


@cas_test("créer une version élague d'office la capture iPad recopiée")
def _():
    class Args:
        version = "3.4"
    f = avec_fiche(TROIS_LANGUES, lambda fi: asc.cmd_create_version(Args()))
    assert f.versions_creees == ["3.4"], f.versions_creees
    assert any("IPAD" in c for c in f.supprimes), \
        "la version a été créée sans élaguer : la capture iPad repart pour une version"
    assert not any("WATCH" in c for c in f.supprimes), \
        f"l'élagage d'office a emporté la montre : {f.supprimes}"


@cas_test("une fiche déjà propre se crée sans rien supprimer")
def _():
    f = avec_fiche({"fr-FR": ["APP_IPHONE_67", "APP_WATCH_SERIES_10"]},
                   lambda fi: asc.cmd_create_version(type("A", (), {"version": "3.5"})()))
    assert f.supprimes == [], f.supprimes


def main():
    echecs, ignores = 0, 0
    for nom, f, besoin in cas:
        if besoin and not FFMPEG:
            ignores += 1; print(f"  ····  {nom}  (ignoré : ffmpeg absent de cette machine)")
            continue
        try:
            f(); print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1; print(f"  ÉCHEC {nom}\n        {e}")
    joues = len(cas) - ignores
    print(f"\n{joues - echecs}/{joues} cas passent"
          + (f", {ignores} ignoré(s) faute de ffmpeg." if ignores else "."))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
