#!/usr/bin/env python3
"""Les cas de `check_captures_montre.py`.

CE QU'ILS EMPÊCHENT DE REVENIR. La première version de ce garde-fou comparait les empreintes des
fichiers entiers, et elle est passée au VERT sur trois captures de montre qui étaient toutes les
trois en français : la barre d'état porte l'heure, elle avance entre deux captures, et deux images
par ailleurs identiques ont donc des octets différents. Le garde-fou mesurait l'horloge.

Le premier cas ci-dessous est exactement celui-là.
"""
import contextlib
import io
import pathlib
import sys
import tempfile

from PIL import Image, ImageDraw

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_captures_montre as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def capture(texte: str, heure: str) -> Image.Image:
    """Une fausse capture de montre : une heure en haut, un texte au milieu."""
    im = Image.new("RGB", (416, 496), (0, 0, 0))
    d = ImageDraw.Draw(im)
    d.text((300, 20), heure, fill=(255, 255, 255))     # dans la barre d'état
    d.text((100, 250), texte, fill=(255, 255, 255))    # dans le contenu
    return im


def lance(images: dict):
    """`images` : {langue: Image}."""
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        for langue, im in images.items():
            (racine / langue).mkdir(parents=True, exist_ok=True)
            im.save(racine / langue / ck.NOM, "PNG")
        avant = sys.argv
        sys.argv = ["check_captures_montre.py", str(racine)]
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                code = ck.main()
            return code, tampon.getvalue()
        finally:
            sys.argv = avant


@cas_de("L'HEURE SEULE NE SUFFIT PAS À DISTINGUER DEUX LANGUES")
def _():
    # Le défaut du 9 novembre 2026, au bit près : deux captures en français, prises à une minute
    # d'écart, que la comparaison d'octets déclarait différentes.
    code, sortie = lance({"fr-FR": capture("Course libre", "11:44"),
                          "en-US": capture("Course libre", "11:46")})
    assert code == 1, "l'horloge a suffi à faire passer deux fois la même image :\n" + sortie
    assert "la langue n'a pas pris" in sortie, sortie


@cas_de("deux langues réellement différentes passent")
def _():
    code, sortie = lance({"fr-FR": capture("Course libre", "11:44"),
                          "en-US": capture("Free run", "11:46")})
    assert code == 0, sortie
    assert "2 images distinctes" in sortie, sortie


@cas_de("trois langues, une seule en trop : les deux fautives sont nommées")
def _():
    code, sortie = lance({"fr-FR": capture("Course libre", "11:44"),
                          "en-US": capture("Free run", "11:45"),
                          "es-ES": capture("Free run", "11:46")})
    assert code == 1, sortie
    assert "en-US" in sortie and "es-ES" in sortie, sortie
    assert "fr-FR et" not in sortie, "le français est accusé à tort :\n" + sortie


@cas_de("UNE SEULE CAPTURE NE REND PAS VERT — elle ne prouve rien")
def _():
    # Sinon une chaîne qui n'en produit qu'une (langue sautée, dossier mal nommé) passerait pour
    # vérifiée, ce qui est précisément la forme de défaut que ce fichier existe pour empêcher.
    code, sortie = lance({"fr-FR": capture("Course libre", "11:44")})
    assert code == 1, sortie
    assert "au moins deux" in sortie, sortie


@cas_de("un changement SOUS la barre, même minuscule, est vu")
def _():
    # La bande écartée fait 18 % du haut. Un texte à mi-hauteur en est loin ; ce cas garde la
    # marge, pour qu'on ne puisse pas l'élargir jusqu'à avaler le contenu sans rien casser.
    a = capture("Course libre", "11:44")
    b = capture("Course libre", "11:44")
    ImageDraw.Draw(b).point((10, int(496 * 0.19)), fill=(255, 0, 0))
    code, sortie = lance({"fr-FR": a, "en-US": b})
    assert code == 0, "un pixel sous la barre n'a pas été vu :\n" + sortie


# ── LA BANDE BASSE : QUELQUE CHOSE EST-IL TRANCHÉ PAR L'ARÊTE ? ──────────────────────────────
#
# Ce contrôle savait dire que trois langues rendaient la même image. Il ne savait pas dire que les
# trois étaient COUPÉES — et elles l'étaient : onze lignes de pixels encrées jusqu'à la toute
# dernière, dans les trois langues, sur la capture exigée par l'App Store.


@cas_de("une capture coupée au bord bas est attrapée, dans chaque langue")
def _():
    a = capture("Course libre", "11:44")
    b = capture("Free run", "11:45")
    for im in (a, b):
        ImageDraw.Draw(im).rectangle([0, 488, 415, 495], fill=(200, 200, 200))
    code, sortie = lance({"fr-FR": a, "en-US": b})
    assert code == 1, sortie
    assert "TRANCHÉ" in sortie, sortie
    assert "fr-FR" in sortie and "en-US" in sortie, sortie


@cas_de("la toute dernière ligne suffit à accuser")
def _():
    # Le défaut réel touchait onze lignes, mais une seule suffit : au repos, ce qui atteint
    # l'arête est coupé, et rien ne dit de combien.
    a = capture("Course libre", "11:44")
    ImageDraw.Draw(a).point((200, 495), fill=(255, 255, 255))
    code, sortie = lance({"fr-FR": a, "en-US": capture("Free run", "11:45")})
    assert code == 1, sortie
    assert "fr-FR" in sortie and "TRANCHÉ" in sortie, sortie


@cas_de("une mise en page qui respire ne dit rien")
def _():
    # Le texte des fausses captures est à mi-hauteur : rien n'approche le bord.
    code, sortie = lance({"fr-FR": capture("Course libre", "11:44"),
                          "en-US": capture("Free run", "11:45")})
    assert code == 0, sortie
    assert "TRANCHÉ" not in sortie, sortie


@cas_de("le bruit de compression ne passe pas pour de l'encre")
def _():
    # VERT POUR LA MAUVAISE RAISON, À L'ENVERS : un seuil à zéro accuserait toutes les captures
    # réelles, on apprendrait à ignorer le rouge, et la règle ne vaudrait plus rien. Le fond de
    # la montre est noir ; un gris très sombre reste du fond.
    a = capture("Course libre", "11:44")
    ImageDraw.Draw(a).rectangle([0, 490, 415, 495], fill=(12, 12, 12))
    code, sortie = lance({"fr-FR": a, "en-US": capture("Free run", "11:45")})
    assert code == 0, "du bruit sombre a été pris pour du texte coupé :\n" + sortie


@cas_de("le bord l'emporte sur la comparaison des langues")
def _():
    # Deux images identiques ET coupées : c'est la coupe qu'on veut lire d'abord, parce qu'elle
    # se corrige dans la vue et l'autre dans la chaîne de capture. Mélanger les deux diagnostics
    # ferait chercher au mauvais endroit.
    a = capture("Course libre", "11:44")
    ImageDraw.Draw(a).rectangle([0, 489, 415, 495], fill=(255, 255, 255))
    b = a.copy()
    code, sortie = lance({"fr-FR": a, "en-US": b})
    assert code == 1, sortie
    assert "TRANCHÉ" in sortie, sortie
    assert "MÊME image" not in sortie, "les deux diagnostics sont mélangés :\n" + sortie


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
