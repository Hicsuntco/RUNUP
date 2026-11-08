#!/usr/bin/env python3
"""Les cas de `check_grand_texte.py`, sur des images fabriquées.

Ce qui est éprouvé ici, c'est la MESURE : qu'une capture identique rende un écart nul, qu'une
capture dont le texte a grandi rende un écart franc, et que le plancher sépare les deux. Un
contrôle qui se trompe là-dessus déclarerait le grand texte « bien pris » sur deux copies.
"""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_grand_texte as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


L, H = 300, 600


def bandes(epaisseur: int) -> Image.Image:
    """Un écran de « texte » : des bandes dont l'épaisseur tient lieu de taille de police."""
    im = Image.new("L", (L, H), 18)
    for y in range(0, H, epaisseur * 3):
        for yy in range(y, min(y + epaisseur, H)):
            for x in range(20, L - 20):
                im.putpixel((x, yy), 220)
    return im


def ecrire(dossier: pathlib.Path, chemin: str, im: Image.Image) -> pathlib.Path:
    cible = dossier / chemin
    cible.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGB").save(cible)
    return cible


@cas_de("deux fois la même capture : écart nul")
def _():
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        a = ecrire(dossier, "a.png", bandes(4))
        b = ecrire(dossier, "b.png", bandes(4))
        assert ck.ecart(a, b) == 0.0, ck.ecart(a, b)


@cas_de("du texte deux fois plus grand : écart franc")
def _():
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        petit = ecrire(dossier, "petit.png", bandes(4))
        grand = ecrire(dossier, "grand.png", bandes(8))
        valeur = ck.ecart(grand, petit)
        assert valeur > 20, f"écart trop faible pour être distingué d'une copie : {valeur}"


@cas_de("deux tailles d'écran ne se comparent pas en silence")
def _():
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        a = ecrire(dossier, "a.png", bandes(4))
        b = ecrire(dossier, "b.png", bandes(4).resize((L // 2, H // 2)))
        try:
            ck.ecart(a, b)
            raise AssertionError("une comparaison entre deux tailles aurait dû s'arrêter")
        except SystemExit:
            pass


@cas_de("une capture absente fait échouer, elle ne se saute pas")
def _():
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        ecrire(dossier, "1-accueil.png", bandes(4))
        sortie = subprocess.run([sys.executable, str(ICI / "check_grand_texte.py"),
                                 "--dossier", str(dossier)],
                                capture_output=True, text=True)
        assert sortie.returncode == 1, sortie.stdout + sortie.stderr
        assert "absente" in sortie.stderr


@cas_de("le plancher sépare une copie d'une vraie montée")
def _():
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        for grand, ordinaire in ck.PAIRES.items():
            ecrire(dossier, ordinaire, bandes(4))
            ecrire(dossier, grand, bandes(8))
        lance = [sys.executable, str(ICI / "check_grand_texte.py"), "--dossier", str(dossier)]
        ok = subprocess.run(lance + ["--plancher", "3"], capture_output=True, text=True)
        assert ok.returncode == 0, ok.stdout + ok.stderr
        # Les mêmes images des deux côtés : le contrôle doit refuser.
        for grand in ck.PAIRES:
            ecrire(dossier, grand, bandes(4))
        refus = subprocess.run(lance + ["--plancher", "3"], capture_output=True, text=True)
        assert refus.returncode == 1, refus.stdout + refus.stderr
        assert "ordinaire" in refus.stderr.lower()


@cas_de("sans plancher, on mesure et on se tait")
def _():
    with tempfile.TemporaryDirectory() as d:
        dossier = pathlib.Path(d)
        for grand, ordinaire in ck.PAIRES.items():
            ecrire(dossier, ordinaire, bandes(4))
            ecrire(dossier, grand, bandes(4))
        sortie = subprocess.run([sys.executable, str(ICI / "check_grand_texte.py"),
                                 "--dossier", str(dossier)], capture_output=True, text=True)
        assert sortie.returncode == 0, sortie.stdout + sortie.stderr


@cas_de("chaque paire vise des captures que le harnais prend vraiment")
def _():
    test = (ICI.parent / "RunUpUITests/CapturesUITests.swift").read_text(encoding="utf-8")
    for grand, ordinaire in ck.PAIRES.items():
        nom = grand[len("diagnostic/"):-len(".png")]
        assert f'nom: "{nom}"' in test, f"aucun test ne prend « {nom} »"
    # Et les ordinaires existent aussi, sous leur propre nom.
    for ordinaire in ck.PAIRES.values():
        nom = ordinaire.split("/")[-1][:-len(".png")]
        nom = nom.split("-", 1)[1] if nom[0].isdigit() else nom
        assert f'nom: "{nom}"' in test, f"aucun test ne prend « {nom} »"


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
