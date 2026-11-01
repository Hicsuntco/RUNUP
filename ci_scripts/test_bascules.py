#!/usr/bin/env python3
"""`bascules.py`, éprouvé sur un film fabriqué dont on connaît le défaut à l'image près.

Un compteur d'images vides qui se trompe est pire que pas de compteur : il dirait « zéro » sur
un écran qui clignote, et on le croirait. On lui donne donc un enregistrement où l'on a MIS
trois images de fond nu, et on vérifie qu'il en trouve trois — ni deux, ni quatre, et pas non
plus les images du fondu, qui sont voulues.
"""
import json
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bascules as bs  # noqa: E402

ICI = pathlib.Path(__file__).resolve().parent
echecs = []
total = 0


def attendu(nom, obtenu, voulu):
    global total
    total += 1
    if obtenu != voulu:
        echecs.append(f"{nom} : {obtenu!r} au lieu de {voulu!r}")
    print(f"  {'ok  ' if obtenu == voulu else 'ÉCHEC'} {nom}")


# --- LE CLASSEMENT D'UNE IMAGE ------------------------------------------------------------------
# Trois cas, et c'est tout ce que le script décide.
L, H = 258, 560


def unie(valeur):
    return Image.new("L", (L, H), valeur)


def chargee(motif):
    """Une image STRUCTURÉE : des bandes, donc un écart-type franc."""
    im = Image.new("L", (L, H), 20)
    for y in range(0, H, 8):
        for x in range(0, L, 1):
            if (y // 8 + motif) % 2 == 0:
                im.putpixel((x, y), 230)
    return im


with tempfile.TemporaryDirectory() as d:
    dossier = pathlib.Path(d)
    ref = chargee(0)
    autre = chargee(1)
    plate = unie(24)

    def classe(im):
        chemin = dossier / "une.png"
        im.save(chemin)
        return bs.classer([chemin], ref)[0]

    attendu("un fond nu est vide", classe(plate), "vide")
    attendu("l'écran posé est posé", classe(ref), "posée")
    attendu("un autre écran est une transition", classe(autre), "transition")
    # L'ÉCRAN D'AVANT est reconnu pour lui-même dès qu'on le donne en seconde référence.
    def classe2(im):
        chemin = dossier / "deux.png"
        im.save(chemin)
        return bs.classer([chemin], ref, autre)[0]
    attendu("l'écran d'avant est reconnu", classe2(autre), "avant")
    attendu("l'écran posé passe devant l'écran d'avant", classe2(ref), "posée")
    # `chargee(2)` rendrait exactement `chargee(0)` — une image sur deux, c'est le même motif.
    # Il faut donc un motif d'une autre sorte : des bandes verticales.
    verticales = Image.new("L", (L, H), 20)
    for x in range(0, L, 8):
        for y in range(H):
            verticales.putpixel((x, y), 230)
    attendu("un troisième écran reste une transition", classe2(verticales), "transition")
    # LE FOND N'EST PAS TOUJOURS LE MÊME GRIS. Clair ou sombre, uni reste uni.
    attendu("un fond clair est vide aussi", classe(unie(242)), "vide")
    # Le bruit de l'encodeur ne doit pas transformer l'écran posé en transition. Deux gris
    # d'écart sur 255, c'est l'ordre de grandeur de ce que rend libx264 sur un aplat.
    bruitee = ref.point(lambda v: min(255, v + 2))
    attendu("deux gris de bruit ne font pas une transition", classe(bruitee), "posée")

# --- LA DERNIÈRE TRAVERSÉE ----------------------------------------------------------------------
# Ce qui se compte, c'est le bloc non posé juste avant que l'écran se pose — pas toutes les
# transitions de la fenêtre, qui contiennent l'écran d'avant.
attendu("trois vides puis six de fondu puis posé",
        bs.mise_en_place(["avant"] * 10 + ["vide"] * 3 + ["transition"] * 6 + ["posée"] * 8),
        (9, 3))
attendu("rien à traverser : déjà posé", bs.mise_en_place(["posée"] * 12), (0, 0))
# La traversée ne compte PAS l'écran d'avant, et c'est tout l'intérêt : rallonger la fenêtre
# ajoute des « avant », pas des images de mise en place.
attendu("une fenêtre plus longue ne gonfle pas la traversée",
        bs.mise_en_place(["avant"] * 40 + ["transition"] * 6 + ["posée"] * 8), (6, 0))
# Un fondu direct, sans trou : six images, zéro vide. C'est ce qu'on attend après la correction.
attendu("un fondu propre : six images, aucune vide",
        bs.mise_en_place(["avant"] * 12 + ["transition"] * 6 + ["posée"] * 9), (6, 0))
# L'écran n'est TOUJOURS PAS posé à la fin de la fenêtre : on ne rend pas un zéro qui dirait
# « rien à signaler » sur le pire des cas.
attendu("jamais posé : tout ce qui suit l'écran d'avant",
        bs.mise_en_place(["avant"] * 3 + ["vide"] * 5 + ["transition"] * 4), (9, 5))
# Pas d'écran d'avant du tout dans la fenêtre : on compte depuis le début.
attendu("sans écran d'avant, on compte depuis le début",
        bs.mise_en_place(["vide"] * 2 + ["transition"] * 3 + ["posée"] * 7), (5, 2))

# --- LE COMPTE SUR UN FILM FABRIQUÉ -------------------------------------------------------------
# Le film : 1 s d'écran A, TROIS IMAGES DE FOND NU, six images de fondu, puis l'écran B qui
# reste. Le plan commence à 1,40 s, donc la fenêtre de 0,90 s relue va de 0,50 à 1,40 s et
# contient exactement le trou et le fondu.
with tempfile.TemporaryDirectory() as d:
    dossier = pathlib.Path(d)
    images = dossier / "images"
    images.mkdir()
    a, b, fond = chargee(0), chargee(1), unie(24)

    def melange(x, y, part):
        return Image.blend(x, y, part)

    suite = []
    suite += [a] * 30            # 0,00 → 1,00 s : l'écran d'avant
    suite += [fond] * 3          # 1,00 → 1,10 s : LE TROU
    suite += [melange(fond, b, (k + 1) / 7) for k in range(6)]   # 1,10 → 1,30 s : le fondu
    suite += [b] * 51            # 1,30 → 3,00 s : l'écran posé
    for i, im in enumerate(suite, start=1):
        im.convert("RGB").save(images / f"{i:04d}.png")

    film = dossier / "brut.mov"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-framerate", str(bs.IPS), "-i", str(images / "%04d.png"),
                    "-c:v", "libx264", "-crf", "12", "-pix_fmt", "yuv420p", str(film)],
                   check=True)

    temps = dossier / "temps.json"
    temps.write_text(json.dumps([
        {"nom": "accueil", "debut": 0.0, "fin": 0.9, "bascule": False},
        {"nom": "coach", "debut": 1.40, "fin": 2.90, "bascule": True},
    ]), encoding="utf-8")

    def lancer(*extra):
        return subprocess.run([sys.executable, str(ICI / "bascules.py"),
                               "--entree", str(film), "--temps", str(temps), *extra],
                              capture_output=True, text=True)

    r = lancer()
    attendu("le film fabriqué est mesuré", r.returncode, 0)
    # TROIS IMAGES VIDES, celles qu'on a mises.
    attendu("les trois images vides sont trouvées", "dont 3 vide(s)" in r.stdout, True)
    # LA TRAVERSÉE, EN FOURCHETTE ET NON AU CHIFFRE PRÈS.
    #
    # On a planté trois images vides et six de fondu : neuf. La mesure en rend sept, parce que
    # les deux dernières images du fondu sont déjà à moins de six gris de l'écran posé — pour
    # l'œil comme pour le seuil, l'écran était arrivé. C'est une propriété du seuil, pas un
    # défaut, et la figer au chiffre près reviendrait à tester l'encodeur.
    #
    # Ce qui se vérifie exactement est le nombre d'images VIDES, qui est le nombre qui accuse.
    traversee = int(r.stdout.split("mise en place : ")[1].split(" images")[0])
    attendu("la traversée tient entre quatre et neuf images", 4 <= traversee <= 9, True)
    attendu("les trois vides se suivent dans la ligne de symboles", "___" in r.stdout, True)
    attendu("la fenêtre commence sur l'écran d'avant", r.stdout.split()[1].startswith("<<<"),
            True)
    # Le plan qui ne vient pas d'une bascule n'est pas relu : sinon on mesurerait la fin du
    # plan d'avant et on appellerait ça une transition d'onglet.
    attendu("le plan sans bascule est ignoré", "accueil" in r.stdout, False)
    attendu("le plan avec bascule est nommé", "coach" in r.stdout, True)

    # LE PLAFOND. Sans lui on mesure et on se tait ; avec, il tranche.
    attendu("un plafond de 0 refuse ce film", lancer("--plafond", "0").returncode, 1)
    attendu("un plafond de 3 l'accepte", lancer("--plafond", "3").returncode, 0)
    attendu("un plafond de 2 le refuse", lancer("--plafond", "2").returncode, 1)

    # UN DÉCOUPAGE SANS AUCUNE BASCULE ne fait pas échouer : il n'y a rien à mesurer, et un
    # script qui échoue faute de travail bloquerait une publication pour rien.
    sans = dossier / "sans.json"
    sans.write_text(json.dumps([{"nom": "accueil", "debut": 0.0, "fin": 0.9,
                                 "bascule": False}]), encoding="utf-8")
    r = subprocess.run([sys.executable, str(ICI / "bascules.py"), "--entree", str(film),
                        "--temps", str(sans), "--plafond", "0"], capture_output=True, text=True)
    attendu("sans bascule, rien à mesurer", (r.returncode, "rien à mesurer" in r.stdout),
            (0, True))

    # LE DÉCALAGE DÉPLACE LA FENÊTRE. Dix secondes de plus, et il n'y a plus de film à lire :
    # mieux vaut le dire que rendre « zéro image vide » sur un fichier qu'on n'a pas lu.
    r = subprocess.run([sys.executable, str(ICI / "bascules.py"), "--entree", str(film),
                        "--temps", str(temps), "--decalage", "10"],
                       capture_output=True, text=True)
    attendu("un décalage hors du film se dit", r.returncode, 1)

# --- LES DEUX HORLOGES ---------------------------------------------------------------------
# `simctl` rend un fichier plus court que le tournage : un repère pris à la seconde de montre
# tombe sur une image plus tardive. C'est le défaut qui a mis l'écran d'accueil du simulateur
# dans le dernier plan du film, sans qu'aucune durée ne bronche.
with tempfile.TemporaryDirectory() as d:
    dossier = pathlib.Path(d)
    im_dir = dossier / "i"
    im_dir.mkdir()
    for i in range(1, 61):
        chargee(i % 2).convert("RGB").save(im_dir / f"{i:04d}.png")
    film = dossier / "deux-secondes.mov"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                    "-i", str(im_dir / "%04d.png"), "-c:v", "libx264", "-crf", "20",
                    "-pix_fmt", "yuv420p", str(film)], check=True)

    # Sans durée de tournage : on ne corrige rien, et le chemin manuel garde son comportement.
    attendu("sans tournage, échelle 1", bs.montage.echelle_horloges(film, None), 1.0)
    attendu("tournage nul, échelle 1", bs.montage.echelle_horloges(film, 0), 1.0)
    # Un fichier de 2 s pour 2,5 s de montre : les repères se resserrent de 20 %.
    attendu("un fichier plus court resserre les repères",
            round(bs.montage.echelle_horloges(film, 2.5), 3), 0.8)
    # Hors de toute vraisemblance, c'est une erreur de mesure, pas une correction : un tournage
    # mal relevé étirerait le découpage au lieu de le remettre en place, et le film sortirait
    # faux sans que rien ne le dise.
    def hors_limites(valeur):
        try:
            bs.montage.echelle_horloges(film, valeur)
        except SystemExit:
            return "refusé"
        return "accepté"
    attendu("un tournage dix fois trop long est refusé", hors_limites(20.0), "refusé")
    attendu("un tournage deux fois trop court est refusé", hors_limites(1.0), "refusé")
    attendu("la limite basse passe", hors_limites(2.0 / 0.95), "accepté")

# --- LES CONSTANTES, contre une faute de frappe -------------------------------------------------
attendu("cadence", bs.IPS, 30)
attendu("fenêtre", bs.FENETRE, 0.9)
attendu("haut utile sous la barre d'onglets", bs.HAUT_UTILE < 0.894, True)

if echecs:
    print(f"\n{len(echecs)} cas se comportent mal :\n", file=sys.stderr)
    for e in echecs:
        print(f"  {e}", file=sys.stderr)
    sys.exit(1)
print(f"\n{total}/{total} cas passent.")
