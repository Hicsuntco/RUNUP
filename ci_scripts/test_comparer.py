#!/usr/bin/env python3
"""Les cas de `comparer.py`, sur des images fabriquées.

Ce qui est éprouvé ici, c'est que l'outil DIT CE QUI A BOUGÉ et ne se tait pas quand quelque
chose a bougé. Trois pièges, et ce sont ceux qui rendraient l'outil inutile pour le chantier
qui l'a demandé :

1. L'HEURE. Deux prises du même écran diffèrent toujours dans la barre d'état. Un outil qui
   compte ce pixel-là déclare « tout a changé » à chaque fois, on cesse de le lire, et il ne
   protège plus rien.
2. LA MOYENNE QUI NOIE. Un bloc de 40 px qui change du tout au tout sur un écran de 2796 px de
   haut rend une moyenne minuscule. C'est EXACTEMENT la forme d'un défaut de découpage : une
   carte qui perd son retrait, une ligne qui disparaît. D'où le compte de pixels, qui ne se
   laisse pas diluer, et le cadre, qui dit où.
3. L'IMAGE QUI DISPARAÎT. Un écran que le test ne trouve plus après le découpage ne se
   photographie plus. Comparer les seules images présentes des deux côtés rendrait « tout est
   identique » sur un écran perdu.
"""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import comparer as cp  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


L, H = 300, 600
# La barre d'état fabriquée : les 6,5 % du haut, soit les 39 premières lignes sur 600.
BARRE = int(round(H * cp.HAUT_MASQUE))


def ecran(horloge: int = 0, bloc: tuple[int, int] | None = None) -> Image.Image:
    """Un écran : du contenu réparti, une « heure » en haut, et un bloc en option.

    `horloge` déplace un carré DANS la barre d'état — ce que fait une minute qui passe.
    `bloc` noircit une bande (y, hauteur) sous la barre — ce que fait un défaut de découpage.
    """
    im = Image.new("L", (L, H), 30)
    for y in range(BARRE + 20, H - 20, 24):
        for yy in range(y, min(y + 8, H)):
            for x in range(20, L - 20):
                im.putpixel((x, yy), 200)
    for x in range(10 + horloge, 40 + horloge):
        for y in range(8, BARRE - 8):
            im.putpixel((x, y), 240)
    if bloc:
        debut, hauteur = bloc
        for y in range(debut, min(debut + hauteur, H)):
            for x in range(20, L - 20):
                im.putpixel((x, y), 255)
    return im


def ecrire(dossier: pathlib.Path, chemin: str, im: Image.Image) -> pathlib.Path:
    cible = dossier / chemin
    cible.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGB").save(cible)
    return cible


def lancer(avant: pathlib.Path, apres: pathlib.Path, *extra: str):
    r = subprocess.run([sys.executable, str(ICI / "comparer.py"),
                        "--avant", str(avant), "--apres", str(apres), *extra],
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def deux_dossiers(tmp: str) -> tuple[pathlib.Path, pathlib.Path]:
    avant, apres = pathlib.Path(tmp) / "avant", pathlib.Path(tmp) / "apres"
    avant.mkdir(); apres.mkdir()
    return avant, apres


@cas_de("l'heure qui change ne compte pas")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran(horloge=0))
        ecrire(apres, "club.png", ecran(horloge=9))
        code, sortie = lancer(avant, apres, "--plafond", "0.5", "--pixels", "0")
        assert code == 0, f"l'heure a fait échouer la comparaison :\n{sortie}"
        assert "PIXELS=0" in sortie, f"des pixels comptés sous la barre d'état :\n{sortie}"


@cas_de("la moyenne laisse passer un petit bloc, le compte de pixels le voit")
def _():
    """LE CAS QUI JUSTIFIE `--pixels`.

    Un plafond de 5 sur l'écart moyen est généreux, et c'est le genre de nombre qu'on pose
    pour tolérer le rendu d'un dégradé. Un bloc de six lignes passe sous ce plafond : il ne
    pèse presque rien sur la moyenne de l'image entière. Il ne passe pas le compte de pixels,
    qui ne se dilue pas. Le cas éprouve les deux verdicts sur la MÊME paire d'images.
    """
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran())
        ecrire(apres, "club.png", ecran(bloc=(300, 6)))

        code, sortie = lancer(avant, apres, "--plafond", "5")
        assert code == 0, f"la moyenne a attrapé le bloc, le cas ne montre plus rien :\n{sortie}"
        moyenne = float(sortie.split("ÉCART MAXIMAL=")[1].split()[0])
        assert moyenne < 5, f"la moyenne vaut {moyenne}, pas sous le plafond 5"

        code, sortie = lancer(avant, apres, "--plafond", "5", "--pixels", "0")
        assert code == 1, f"le compte de pixels a laissé passer le bloc :\n{sortie}"
        assert "pixels différents" in sortie, sortie
        # Le cadre doit désigner le bloc, en coordonnées PRISES SOUS LA BARRE D'ÉTAT.
        cadre = sortie.split("cadre x ")[1].split(" (")[0]
        assert f"y {300 - BARRE}" in cadre, f"le cadre ne désigne pas le bloc : {cadre}"


@cas_de("deux captures identiques ne diffèrent pas")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        for d in (avant, apres):
            ecrire(d, "a/club.png", ecran())
            ecrire(d, "b/profil.png", ecran(bloc=(200, 10)))
        code, sortie = lancer(avant, apres, "--plafond", "0", "--pixels", "0")
        assert code == 0, f"deux copies ont été déclarées différentes :\n{sortie}"
        assert "IMAGES_DIFFERENTES=0" in sortie, sortie


@cas_de("une image qui disparaît fait échouer, même si le reste est identique")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran())
        ecrire(avant, "club-classement.png", ecran())
        ecrire(apres, "club.png", ecran())
        code, sortie = lancer(avant, apres)
        assert code == 1, f"un écran perdu est passé :\n{sortie}"
        assert "club-classement.png : photographiée avant, absente après" in sortie, sortie


@cas_de("sans plafond, on mesure et on se tait")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran())
        ecrire(apres, "club.png", ecran(bloc=(300, 200)))
        code, sortie = lancer(avant, apres)
        assert code == 0, f"sans plafond, l'outil a jugé :\n{sortie}"
        assert "on ne juge pas" in sortie, sortie
        assert "IMAGES_DIFFERENTES=1" in sortie, sortie


@cas_de("--seulement ne compare que ce qu'on nomme")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran())
        ecrire(apres, "club.png", ecran())
        ecrire(avant, "profil.png", ecran())
        ecrire(apres, "profil.png", ecran(bloc=(300, 200)))
        code, sortie = lancer(avant, apres, "--seulement", "club", "--pixels", "0")
        assert code == 0, f"--seulement club a regardé le profil :\n{sortie}"
        assert "profil.png" not in sortie, sortie


@cas_de("deux tailles d'écran ne se comparent pas en silence")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran())
        ecrire(apres, "club.png", ecran().resize((L // 2, H // 2)))
        code, sortie = lancer(avant, apres)
        assert code != 0, f"deux tailles sont passées :\n{sortie}"
        assert "ne se comparent pas" in sortie, sortie


@cas_de("un dossier vide ne rend pas un vert")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        code, sortie = lancer(avant, apres, "--plafond", "0")
        assert code != 0, f"deux dossiers vides ont rendu un vert :\n{sortie}"
        assert "Aucune image" in sortie, sortie


@cas_de("la différence est gardée quand on le demande")
def _():
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "a/club.png", ecran())
        ecrire(apres, "a/club.png", ecran(bloc=(300, 20)))
        preuves = pathlib.Path(tmp) / "preuves"
        code, sortie = lancer(avant, apres, "--sortie", str(preuves))
        assert code == 0, sortie
        gardees = list(preuves.rglob("*.png"))
        assert len(gardees) == 1, f"{len(gardees)} image(s) gardée(s) :\n{sortie}"
        assert gardees[0].name == "a-club.png", gardees[0].name


# --- `--decalage` : « ça a bougé » ou « ça a juste défilé » ? ----------------------------------


def ecran_varie() -> Image.Image:
    """Un écran dont le contenu n'est PAS périodique.

    Le gabarit ordinaire (`ecran`) pose une barre toutes les 24 lignes. C'est commode pour tout
    le reste de ce fichier et FAUX pour éprouver un décalage : glissé de 48 pixels, il retombe
    exactement sur lui-même, l'écart tombe à zéro à deux décalages à la fois, et le cas réussit
    ou échoue pour une raison qui n'a rien à voir avec ce qu'on mesure. Relevé en l'écrivant.

    Ici les barres sont à des hauteurs irrégulières mais FIXES — pas de tirage au sort : un cas
    qui change d'une exécution à l'autre ne prouve rien.
    """
    im = Image.new("L", (L, H), 30)
    hauteurs = [0, 17, 39, 44, 90, 103, 158, 171, 230, 266, 301, 355, 362, 418, 470, 505]
    for i, y in enumerate(h + BARRE + 20 for h in hauteurs):
        for yy in range(y, min(y + 6 + (i % 3), H)):
            for x in range(20 + (i % 5) * 12, L - 20):
                im.putpixel((x, yy), 200)
    return im


def defile(im: Image.Image, dy: int) -> Image.Image:
    """La même image, son contenu remonté de `dy` pixels — ce que fait un glissement de plus.

    La barre d'état ne bouge pas, puisqu'elle ne défile pas : la recopier telle quelle est ce
    qui rend ce faux défilement fidèle, et c'est aussi ce qui empêche le test de réussir pour
    une mauvaise raison (une image entièrement translatée se retrouverait trop facilement).
    """
    sortie = Image.new("L", im.size, 30)
    sortie.paste(im.crop((0, dy, im.width, im.height)), (0, 0))
    sortie.paste(im.crop((0, 0, im.width, BARRE)), (0, 0))
    return sortie


@cas_de("UN DÉFILEMENT EST RECONNU COMME TEL, avec son décalage")
def _():
    # Le cas réel du 8 novembre 2026 : `club-apercu-bas` rendait le plus gros écart que cet
    # outil ait jamais mesuré — cinq fois un changement de langue complet — et ce n'était qu'un
    # glissement arrêté 105 pixels plus loin.
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran_varie())
        ecrire(apres, "club.png", defile(ecran_varie(), 48))
        code, sortie = lancer(avant, apres, "--decalage")
        assert "48 px plus haut" in sortie, f"le décalage n'est pas trouvé :\n{sortie}"
        assert "un défilement" in sortie, sortie
        assert "régression" in sortie, sortie


@cas_de("un vrai changement de contenu n'est PAS pris pour un défilement")
def _():
    # L'erreur que cette option pourrait introduire : excuser une régression en la baptisant
    # défilement. Un bloc ajouté ne se rattrape par aucun décalage.
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran())
        ecrire(apres, "club.png", ecran(bloc=(200, 120)))
        code, sortie = lancer(avant, apres, "--decalage")
        assert "CONTENU" in sortie or "n'explique pas" in sortie, sortie
        assert "un défilement, pas une régression" not in sortie, \
            f"un changement de contenu a été excusé comme un défilement :\n{sortie}"


@cas_de("sans --decalage, rien n'est cherché")
def _():
    # La recherche coûte quatre cents comparaisons par image : elle ne doit pas se payer
    # quand on n'a pas posé la question.
    with tempfile.TemporaryDirectory() as tmp:
        avant, apres = deux_dossiers(tmp)
        ecrire(avant, "club.png", ecran_varie())
        ecrire(apres, "club.png", defile(ecran_varie(), 48))
        code, sortie = lancer(avant, apres)
        assert "décalage" not in sortie, sortie


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
