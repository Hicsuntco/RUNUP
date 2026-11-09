#!/usr/bin/env python3
"""Les cas de `check_requis.py`, sur un dossier de livraison fabriqué.

CE QU'ILS EMPÊCHENT DE REVENIR. Deux images livrées à Apple ont vieilli de trois mois sans que
rien ne rougisse, parce que rien ne les regardait. Le piège, maintenant qu'un contrôle existe,
est qu'il reste vert pour la mauvaise raison : un dossier vide, une image qu'aucune entrée ne
décrit, ou une entrée sans source qui absorberait tout. Les trois ont leur cas.
"""
import contextlib
import hashlib
import io
import json
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_requis as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def lance(images: dict, table, ecrire: bool = False, sources: bool = True):
    """`images` : {chemin relatif: octets}. Les chemins hors `requis/` sont posés à la racine.

    Un chemin en `.swift` sert de code source fabriqué, pour les cas de l'empreinte du code.
    """
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        requis = racine / "appstore/requis"
        for chemin, octets in images.items():
            cible = racine / chemin
            cible.parent.mkdir(parents=True, exist_ok=True)
            cible.write_bytes(octets)
        requis.mkdir(parents=True, exist_ok=True)
        if sources:
            (requis / "SOURCES.json").write_text(json.dumps(table, ensure_ascii=False),
                                                 encoding="utf-8")
        avant = (ck.RACINE, ck.REQUIS, ck.SOURCES, sys.argv)
        ck.RACINE, ck.REQUIS = racine, requis
        ck.SOURCES = requis / "SOURCES.json"
        sys.argv = ["check_requis.py"] + (["--ecrire"] if ecrire else [])
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                try:
                    code = ck.main()
                except SystemExit as arret:
                    return "arret", str(arret), None
            relu = json.loads((requis / "SOURCES.json").read_text(encoding="utf-8")) if sources else None
            return code, tampon.getvalue(), relu
        finally:
            ck.RACINE, ck.REQUIS, ck.SOURCES, sys.argv = avant


BRUT = b"une capture"
AUTRE = b"une autre capture"


def png(largeur: int, hauteur: int) -> bytes:
    """Un PNG dont seul l'en-tête compte : `asc.taille_png` ne lit que les 24 premiers octets."""
    import struct
    import zlib
    ihdr = struct.pack(">IIBBBBB", largeur, hauteur, 8, 2, 0, 0, 0)
    bloc = struct.pack(">I", len(ihdr)) + b"IHDR" + ihdr
    bloc += struct.pack(">I", zlib.crc32(b"IHDR" + ihdr) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + bloc


def emp(octets: bytes) -> str:
    return hashlib.sha256(octets).hexdigest()[:12]


#: 416 × 496 : la seule taille de montre qu'Apple accepte, et une de celles que `asc.py` connaît.
BONNE = png(416, 496)
IMAGES = {
    "appstore/requis/ipad/fr-FR/1.png": BONNE,
    "appstore/raw/fr-FR/1-accueil.png": BRUT,
}
TABLE = {"ipad/fr-FR/1.png": {"source": "appstore/raw/fr-FR/1-accueil.png",
                              "empreinte": emp(BRUT)}}


@cas_de("l'image est faite de la capture courante : rien à signaler")
def _():
    code, sortie, _ = lance(IMAGES, TABLE)
    assert code == 0, sortie
    assert "1 composée" in sortie, sortie


@cas_de("LA CAPTURE A CHANGÉ : l'image livrée ne montre plus l'app, et on le dit")
def _():
    images = dict(IMAGES, **{"appstore/raw/fr-FR/1-accueil.png": AUTRE})
    code, sortie, _ = lance(images, TABLE)
    assert code == 1, "l'image a vieilli et le contrôle est vert :\n" + sortie
    assert emp(AUTRE) in sortie, sortie
    assert "requis.py" in sortie, "le remède n'est pas nommé :\n" + sortie


@cas_de("UNE IMAGE QU'AUCUNE ENTRÉE NE DÉCRIT est refusée, pas ignorée")
def _():
    # C'est exactement la façon dont les deux précédentes ont vieilli : rien ne les décrivait,
    # donc rien ne pouvait constater qu'elles avaient vieilli.
    images = dict(IMAGES, **{"appstore/requis/montre/fr-FR/1.png": BONNE})
    code, sortie, _ = lance(images, TABLE)
    assert code == 1, sortie
    assert "montre/fr-FR/1.png" in sortie, sortie


@cas_de("une entrée SANS SOURCE est signalée, et ne fait pas échouer")
def _():
    # Un rouge que personne ne peut éteindre s'apprend à être ignoré, et il emporterait avec lui
    # les rouges qu'on peut éteindre.
    images = dict(IMAGES, **{"appstore/requis/montre/fr-FR/1.png": BONNE})
    table = dict(TABLE, **{"montre/fr-FR/1.png": {"source": None, "constat": "ne montre pas l'app"}})
    code, sortie, _ = lance(images, table)
    assert code == 0, sortie
    assert "ne montre pas l'app" in sortie, "le constat n'est pas affiché :\n" + sortie
    assert "1 à reprendre à la main" in sortie, sortie


@cas_de("UN DOSSIER VIDE NE REND PAS VERT — Apple exige ces images")
def _():
    code, sortie, _ = lance({}, {})
    assert code == 1, "aucune image livrée et le contrôle est vert :\n" + sortie
    assert "exige" in sortie, sortie


@cas_de("la capture source disparue est traitée comme une péremption, pas ignorée")
def _():
    images = {"appstore/requis/ipad/fr-FR/1.png": BONNE}
    code, sortie, _ = lance(images, TABLE)
    assert code == 1, sortie
    assert "disparu" in sortie, sortie


@cas_de("SOURCES.json absent fait s'arrêter, en disant à quoi il sert")
def _():
    code, message, _ = lance(IMAGES, TABLE, sources=False)
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "SOURCES.json" in message, message


@cas_de("--ecrire repose les empreintes, et seulement celles qui ont une source")
def _():
    images = dict(IMAGES, **{"appstore/raw/fr-FR/1-accueil.png": AUTRE,
                             "appstore/requis/montre/fr-FR/1.png": BONNE})
    table = dict(TABLE, **{"montre/fr-FR/1.png": {"source": None, "constat": "à refaire"}})
    code, sortie, relu = lance(images, table, ecrire=True)
    assert code == 0, sortie
    assert relu["ipad/fr-FR/1.png"]["empreinte"] == emp(AUTRE), relu
    assert relu["montre/fr-FR/1.png"]["source"] is None, relu
    assert relu["montre/fr-FR/1.png"]["constat"] == "à refaire", "le constat a été perdu : " + str(relu)


CODE = {"RunUpWatch/WatchViews.swift": b"Circle().fill(rose)"}


@cas_de("LE CODE A CHANGÉ : l'image ne montre plus l'écran que l'app dessine")
def _():
    # Le défaut exact du 9 novembre 2026 : le bouton est passé de la pilule au cercle le 6 août,
    # et l'image livrée est restée celle d'avant pendant trois mois. Rien ne reliait l'une à
    # l'autre, parce qu'une capture de montre n'a pas de capture brute intermédiaire.
    images = dict(CODE, **{"appstore/requis/montre/fr-FR/1.png": BONNE,
                           "appstore/raw-montre/fr-FR/1.png": BONNE})
    table = {"montre/fr-FR/1.png": {
        "source": "appstore/raw-montre/fr-FR/1.png",
        "empreinte": emp(BONNE),
        "code": "RunUpWatch",
        "empreinte_code": "000000000000",
    }}
    code, sortie, _ = lance(images, table)
    assert code == 1, "le code a changé et le contrôle est vert :\n" + sortie
    assert "le code a changé" in sortie, sortie


@cas_de("le code inchangé et la capture inchangée : vert")
def _():
    import check_requis as verif
    images = dict(CODE, **{"appstore/requis/montre/fr-FR/1.png": BONNE,
                           "appstore/raw-montre/fr-FR/1.png": BONNE})
    # L'empreinte du code se calcule SUR LE DÉPÔT FABRIQUÉ, donc après l'avoir posé : c'est
    # `lance` qui déplace `ck.RACINE`, et la calculer avant la lirait sur le vrai dépôt.
    table = {"montre/fr-FR/1.png": {
        "source": "appstore/raw-montre/fr-FR/1.png",
        "empreinte": emp(BONNE),
        "code": "RunUpWatch",
        "empreinte_code": None,
    }}
    code, sortie, relu = lance(images, table, ecrire=True)
    assert code == 0, sortie
    table["montre/fr-FR/1.png"]["empreinte_code"] = relu["montre/fr-FR/1.png"]["empreinte_code"]
    assert table["montre/fr-FR/1.png"]["empreinte_code"], "aucune empreinte de code posée : " + str(relu)
    code, sortie, _ = lance(images, table)
    assert code == 0, sortie


@cas_de("UN FICHIER RENOMMÉ compte comme un changement de code")
def _():
    # Le chemin entre dans l'empreinte, pas seulement le contenu : déplacer une vue change ce qui
    # est dessiné autant que la modifier, et un contrôle qui ne verrait que les octets laisserait
    # passer une réorganisation entière.
    images = dict(CODE, **{"appstore/requis/montre/fr-FR/1.png": BONNE,
                           "appstore/raw-montre/fr-FR/1.png": BONNE})
    table = {"montre/fr-FR/1.png": {"source": "appstore/raw-montre/fr-FR/1.png",
                                    "empreinte": emp(BONNE),
                                    "code": "RunUpWatch", "empreinte_code": None}}
    _, _, relu = lance(images, table, ecrire=True)
    avant = relu["montre/fr-FR/1.png"]["empreinte_code"]

    renomme = {"RunUpWatch/Vues.swift": CODE["RunUpWatch/WatchViews.swift"],
               "appstore/requis/montre/fr-FR/1.png": BONNE,
               "appstore/raw-montre/fr-FR/1.png": BONNE}
    _, _, relu2 = lance(renomme, table, ecrire=True)
    assert relu2["montre/fr-FR/1.png"]["empreinte_code"] != avant, \
        "renommer un fichier n'a pas changé l'empreinte du code"


@cas_de("un dossier de code qui n'existe pas fait s'arrêter, il ne vaut pas zéro")
def _():
    # `rglob` sur un chemin absent ne rend rien, SANS RIEN DIRE : l'empreinte d'un dossier vide
    # est stable, donc le contrôle resterait vert en ne regardant plus rien. C'est le défaut que
    # `check_attributs.py` a déjà eu avec « RunUpWidget » au singulier.
    images = {"appstore/requis/montre/fr-FR/1.png": BONNE,
              "appstore/raw-montre/fr-FR/1.png": BONNE}
    table = {"montre/fr-FR/1.png": {"source": "appstore/raw-montre/fr-FR/1.png",
                                    "empreinte": emp(BONNE),
                                    "code": "RunUpWatch", "empreinte_code": "abc"}}
    code, message, _ = lance(images, table)
    assert code == "arret", f"attendu un arrêt, reçu {code} : {message}"
    assert "RunUpWatch" in message, message


@cas_de("UNE TAILLE QU'APPLE NE CONNAÎT PAS est refusée, même si l'image est fraîche")
def _():
    # Le défaut du 9 novembre 2026 : le sélecteur de simulateur a pris la montre de 42 mm, et la
    # capture faisait 374 × 446. Elle montrait le bon écran, elle était toute fraîche, et
    # `asc.py push-screenshots` s'y serait arrêté sur « taille inconnue » — après une chaîne
    # entièrement verte.
    images = {"appstore/requis/montre/fr-FR/1.png": png(374, 446),
              "appstore/raw-montre/fr-FR/1.png": png(374, 446)}
    table = {"montre/fr-FR/1.png": {"source": "appstore/raw-montre/fr-FR/1.png",
                                    "empreinte": emp(png(374, 446))}}
    code, sortie, _ = lance(images, table)
    assert code == 1, "une taille inconnue d'Apple est passée :\n" + sortie
    assert "374 × 446" in sortie, sortie
    assert "TYPES_PAR_TAILLE" in sortie, "la table n'est pas nommée :\n" + sortie


@cas_de("le vrai dépôt : les images livrées sont décrites et à jour")
def _():
    sortie = io.StringIO()
    with contextlib.redirect_stdout(sortie):
        code = ck.main()
    assert code == 0, sortie.getvalue()


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
