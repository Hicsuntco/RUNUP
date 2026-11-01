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
import subprocess
import sys
import tempfile

import asc

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f)); return f
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
        assert type_.startswith("APP_IPHONE_") or type_.startswith("APP_IPAD_"), type_


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


@cas_test("ffprobe rend la taille, la durée et la cadence")
def _():
    f = film(886, 1920, 2, 30)
    largeur, hauteur, secondes, ips = asc.mesurer_mp4(f)
    assert (largeur, hauteur) == (886, 1920), (largeur, hauteur)
    assert 1.8 <= secondes <= 2.2, secondes
    assert 29.5 <= ips <= 30.5, ips


@cas_test("un film trop court est refusé en nommant la borne")
def _():
    dit = refuse(film(886, 1920, 5).parent)
    assert "5.0 s" in dit and "15" in dit and "30" in dit, dit


@cas_test("un film trop long aussi")
def _():
    dit = refuse(film(886, 1920, 32).parent)
    assert "32" in dit and "hors des" in dit, dit


@cas_test("une taille d'aperçu inconnue arrête la commande")
def _():
    dit = refuse(film(800, 1600, 20).parent)
    assert "800×1600" in dit and "rien n'a été envoyé" in dit, dit


@cas_test("une cadence au-delà de trente images est refusée")
def _():
    dit = refuse(film(886, 1920, 16, ips=60).parent)
    assert "images par seconde" in dit, dit


@cas_test("un dossier sans film le dit")
def _():
    with tempfile.TemporaryDirectory() as d:
        assert "Aucun .mp4" in refuse(d)


@cas_test("un film dans les clous passe la vérification et s'arrête faute de clé")
def _():
    # La commande lit TOUT avant de parler à Apple : sans clé d'API, elle doit donc avoir déjà
    # mesuré le film. C'est ce qui permet à un essai de dire ce qu'il enverrait même quand la
    # version n'existe pas encore.
    dit = refuse(film(886, 1920, 20).parent)
    assert "hors des" not in dit and "inconnue" not in dit, dit


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f(); print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1; print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
