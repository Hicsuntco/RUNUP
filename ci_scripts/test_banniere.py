#!/usr/bin/env python3
"""Les cas de `check_banniere.py`, sur des images fabriquées.

Ce contrôle existe parce qu'un défaut est passé jusque dans une image livrée à Apple sans
qu'aucune machine ne puisse le voir. Il ne vaut donc que s'il voit vraiment une bannière — et
surtout s'il ne crie pas sur les écrans légitimement clairs du haut, parce qu'une fausse alerte
sur une chaîne de vingt minutes finit par être contournée.

Le cas le plus important est celui du GRAND TEXTE : ce sont les captures saines les plus claires
du relevé (8,0 %), et un plafond mal posé les refuserait toutes.
"""
import contextlib
import io
import pathlib
import sys
import tempfile

from PIL import Image

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_banniere as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


L, H = 300, 600


def ecran(part_claire: float = 0.0, fond: int = 25) -> Image.Image:
    """Un écran sombre, avec une bande claire occupant `part_claire` de la zone surveillée.

    La bande est posée DANS la zone des bannières, pas ailleurs : c'est précisément ce que
    le contrôle regarde, et une image claire du bas ne doit rien déclencher.
    """
    im = Image.new("L", (L, H), fond)
    haut, bas = int(H * ck.BANDE_HAUT), int(H * ck.BANDE_BAS)
    lignes = int((bas - haut) * part_claire)
    for y in range(haut, haut + lignes):
        for x in range(L):
            im.putpixel((x, y), 200)
    return im


def ecrire(dossier: pathlib.Path, chemin: str, im: Image.Image) -> pathlib.Path:
    cible = dossier / chemin
    cible.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGB").save(cible)
    return cible


def lance(fichiers: dict, plafond=25.0):
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        for chemin, im in fichiers.items():
            ecrire(racine, chemin, im)
        argv = sys.argv
        sys.argv = ["check_banniere.py", "--dossier", str(racine)]
        if plafond is not None:
            sys.argv += ["--plafond", str(plafond)]
        try:
            tampon = io.StringIO()
            with contextlib.redirect_stdout(tampon):
                try:
                    code = ck.main()
                except SystemExit as arret:
                    return "arret", str(arret)
            return code, tampon.getvalue()
        finally:
            sys.argv = argv


@cas_de("un écran sombre ordinaire passe")
def _():
    code, sortie = lance({"fr-FR/1-accueil.png": ecran(0.0)})
    assert code == 0, sortie


@cas_de("LE GRAND TEXTE PASSE — c'est le plus clair des écrans sains")
def _():
    # Relevé : 8,0 % au maximum sur quatre-vingt-quatre captures saines, et les cinq plus
    # claires sont toutes des écrans en grand texte. Un plafond qui les refuserait rendrait le
    # contrôle inutilisable.
    code, sortie = lance({"fr-FR/diagnostic/grand-texte/sortie.png": ecran(0.10)})
    assert code == 0, f"une capture en grand texte a été prise pour une bannière :\n{sortie}"


@cas_de("UNE BANNIÈRE EST REFUSÉE, et l'image est nommée")
def _():
    # Le cas réel : 59,7 % de pixels clairs dans la bande du haut.
    code, sortie = lance({"fr-FR/1-accueil.png": ecran(0.60),
                          "en-US/1-accueil.png": ecran(0.02)})
    assert code == 1, sortie
    assert "fr-FR/1-accueil.png" in sortie, sortie
    assert "en-US" not in sortie, f"une image saine a été dénoncée :\n{sortie}"


@cas_de("une bande claire AILLEURS que dans la zone des bannières ne compte pas")
def _():
    im = Image.new("L", (L, H), 25)
    for y in range(int(H * 0.5), int(H * 0.9)):
        for x in range(L):
            im.putpixel((x, y), 220)
    code, sortie = lance({"fr-FR/6-stats.png": im})
    assert code == 0, f"une zone claire hors du haut a déclenché le contrôle :\n{sortie}"


@cas_de("LE THÈME CLAIR N'EST PAS REGARDÉ")
def _():
    # Une capture claire est claire partout : la même mesure n'y voudrait rien dire, et toutes
    # seraient refusées.
    code, sortie = lance({"fr-FR/clair/1-accueil.png": ecran(0.0, fond=240)})
    assert code == 1 and "Aucune capture sombre" in sortie, \
        f"le dossier clair a été regardé :\n{sortie}"


@cas_de("L'ÉCRAN D'INSCRIPTION N'EST PLUS UNE CAPTURE SOMBRE")
def _():
    # Il est photographié sans aucune graine : pas de profil, donc pas d'`isLightMode` à
    # appliquer, donc le défaut d'amorçage — clair depuis le 9 novembre 2026. Le 10, il est
    # entré dans le relevé à 88,7 % dans les trois langues et a fait rougir la chaîne.
    code, sortie = lance({"fr-FR/1-accueil.png": ecran(0.02),
                          "fr-FR/diagnostic/inscription.png": ecran(0.89, fond=240)})
    assert code == 0, f"l'écran d'inscription a été mesuré comme s'il était sombre :\n{sortie}"


@cas_de("et une VRAIE bannière sur un autre écran sonne toujours")
def _():
    # Le cas ci-dessus retire une image du relevé : il faut dire qu'il n'a rien retiré d'autre.
    code, sortie = lance({"fr-FR/diagnostic/inscription.png": ecran(0.89, fond=240),
                          "fr-FR/diagnostic/paywall.png": ecran(0.60)})
    assert code == 1 and "paywall" in sortie, f"la bannière du paywall est passée :\n{sortie}"
    assert "inscription" not in sortie, f"l'inscription a été accusée :\n{sortie}"


@cas_de("la même image fautive dans trois langues : le message dit que ce n'est pas le minutage")
def _():
    # Le message d'origine disait « relancer la chaîne suffit ». Le 10 novembre, relancer n'aurait
    # rien changé — c'était la même image à 88,7 % trois fois. Une bannière ne fait pas ça.
    code, sortie = lance({f"{lg}/diagnostic/paywall.png": ecran(0.60)
                          for lg in ("fr-FR", "en-US", "es-ES")})
    assert code == 1, sortie
    assert "MAIS PAS ICI" in sortie, f"le message n'a pas vu les trois langues :\n{sortie}"


@cas_de("sans plafond, on mesure et on se tait")
def _():
    code, sortie = lance({"fr-FR/1-accueil.png": ecran(0.60)}, plafond=None)
    assert code == 0, sortie
    assert "on mesure" in sortie, sortie
    assert "59" in sortie or "60" in sortie, f"la mesure n'est pas affichée :\n{sortie}"


@cas_de("un dossier sans capture sombre : refus, parce que l'analyse a échoué")
def _():
    code, sortie = lance({})
    assert code == 1, sortie
    assert "Aucune capture sombre" in sortie, sortie


@cas_de("un dossier absent fait s'arrêter le contrôle")
def _():
    argv = sys.argv
    sys.argv = ["check_banniere.py", "--dossier", "/un/dossier/qui/n/existe/pas"]
    try:
        ck.main()
        raise AssertionError("un dossier absent aurait dû arrêter le contrôle")
    except SystemExit as arret:
        assert "n'est pas un dossier" in str(arret), str(arret)
    finally:
        sys.argv = argv


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
