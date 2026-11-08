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

# --- UNE RÉFÉRENCE DANS UN ENREGISTREMENT À CADENCE VARIABLE ------------------------------------
# LE DÉFAUT EXACT QUI A FAIT ÉCHOUER UNE EXÉCUTION. `simctl` n'écrit pas d'image tant que l'écran
# ne bouge pas : sur un écran posé, deux images peuvent être séparées d'une seconde. Demander
# « la fenêtre d'un trentième de seconde à cet instant » n'y rend alors AUCUNE image, et la
# mesure s'arrêtait en annonçant un enregistrement trop court — sur un fichier qui durait
# quarante secondes de plus.
with tempfile.TemporaryDirectory() as d:
    dossier = pathlib.Path(d)
    im_dir = dossier / "i"
    im_dir.mkdir()
    # Trois secondes d'un écran parfaitement immobile, puis un autre.
    for i in range(1, 91):
        chargee(0 if i <= 60 else 1).convert("RGB").save(im_dir / f"{i:04d}.png")
    fige = dossier / "fige.mov"
    # `mpdecimate` jette les images identiques et `-fps_mode vfr` garde les horodatages : c'est
    # ce que rend un enregistrement de simulateur sur un écran qui ne bouge pas.
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                    "-i", str(im_dir / "%04d.png"), "-vf", "mpdecimate", "-fps_mode", "vfr",
                    "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", str(fige)],
                   check=True)
    reference = bs.posee(fige, 1.5, dossier, "ref")
    attendu("une référence au milieu d'un écran immobile existe", reference.size[0], 258)
    # Et au-delà du fichier, on le dit encore.
    try:
        bs.posee(fige, 99.0, dossier, "loin")
        attendu("au-delà du fichier, on le dit", "accepté", "refusé")
    except SystemExit:
        attendu("au-delà du fichier, on le dit", "refusé", "refusé")

# --- L'ÉCRAN VISÉ EST-IL CELUI QU'ON VOIT -------------------------------------------------------
# LE CONTRÔLE QUI MANQUAIT, et sans lequel trois films sont sortis faux. Un découpage décalé met
# chaque plan sur l'écran suivant : vu des durées tout va bien, vu des horloges aussi — les plans
# se suivent à trois secondes et un décalage de trois secondes se confond avec le voisin. Seul
# l'écran lui-même ne se confond pas.
with tempfile.TemporaryDirectory() as d:
    dossier = pathlib.Path(d)
    # Deux « écrans » photographiés, aux noms que le script attend.
    (dossier / "diagnostic").mkdir(parents=True)
    chargee(0).convert("RGB").save(dossier / "3-coach.png")
    chargee(1).convert("RGB").save(dossier / "6-stats.png")
    gabarit = chargee(0)
    refs = bs.temoins(dossier, gabarit)
    attendu("les captures présentes sont chargées", sorted(refs), ["coach", "stats"])
    attendu("une capture absente ne bloque pas", "profil" in refs, False)
    # L'image à reconnaître arrive rognée au-dessus de la barre d'onglets, comme celle que
    # ffmpeg tire de l'enregistrement. La comparer non rognée à des témoins rognés fausserait
    # tout — et les deux écarts seraient du bruit.
    def comme_le_film(im):
        return im.crop((0, 0, im.width, int(im.height * bs.HAUT_UTILE))).resize(gabarit.size)

    attendu("l'écran du coach se reconnaît",
            bs.le_plus_proche(comme_le_film(chargee(0)), refs)[0][0], "coach")
    attendu("celui des stats aussi",
            bs.le_plus_proche(comme_le_film(chargee(1)), refs)[0][0], "stats")
    # Et l'écart au bon écran doit être FRANCHEMENT plus petit qu'à l'autre : c'est ce qui
    # dispense de régler un seuil.
    classement = bs.le_plus_proche(comme_le_film(chargee(1)), refs)
    attendu("le bon écran gagne largement", classement[1][1] > 4 * max(classement[0][1], 0.5),
            True)
    # Les noms des plans du test visent le bon écran.
    attendu("« première-coach » vise le coach", bs.ecran_vise("première-coach"), "coach")
    attendu("« retour » vise l'accueil", bs.ecran_vise("retour"), "accueil")
    attendu("« stats » vise les stats", bs.ecran_vise("stats"), "stats")

# --- LA PIÈCE QUI ACCOMPAGNE LE VERDICT ---------------------------------------------------------
# Le garde-fou a dit « ce plan montre le mauvais écran » sur une langue, une seule fois, et l'image
# sur laquelle il s'était prononcé était déjà effacée : dossier de travail temporaire, brut non
# publié, comparaison faite sur un gris de 258 pixels. Un verdict sans pièce ne se vérifie pas.
# Ce qui est gardé doit donc être l'image TELLE QU'ELLE EST : taille réelle, couleurs, non rognée.
with tempfile.TemporaryDirectory() as d:
    dossier = pathlib.Path(d)
    im_dir = dossier / "i"
    im_dir.mkdir()
    for i in range(1, 61):
        chargee(0 if i <= 30 else 1).convert("RGB").save(im_dir / f"{i:04d}.png")
    film = dossier / "film.mov"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                    "-i", str(im_dir / "%04d.png"),
                    "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", str(film)],
                   check=True)
    garde = bs.preuve(film, 0.5, dossier / "preuves", "coach-montre-stats")
    attendu("l'image jugée est écrite", garde.is_file(), True)
    attendu("elle porte le nom du plan et de l'écran vu", garde.name, "coach-montre-stats.png")
    with Image.open(garde) as im:
        # Ni rognée au-dessus de la barre d'onglets, ni réduite à la largeur de comparaison :
        # c'est l'écran entier qu'on veut reconnaître d'un coup d'œil.
        attendu("elle fait la taille de l'écran, pas celle de la comparaison", im.size, (L, H))
        attendu("elle est en couleurs", im.mode, "RGB")

# --- L'ALIGNEMENT PAR LE CONTENU -----------------------------------------------------------------
# L'horloge de la caméra se trompe par intermittence : `simctl` annonce qu'il tourne avant
# d'écrire sa première image. Deux films ont été refusés pour ça — un en espagnol, un en anglais —
# et les images gardées montraient le même symptôme : chaque plan sur l'écran du plan SUIVANT.
#
# On fabrique donc un film dont on connaît le découpage à la demi-seconde près, on MENT au script
# de trois secondes, et on vérifie qu'il retrouve le bon décalage tout seul.
with tempfile.TemporaryDirectory() as d:
    dossier = pathlib.Path(d)
    im_dir = dossier / "i"
    im_dir.mkdir()
    # QUATRE ÉCRANS VRAIMENT DIFFÉRENTS, et le premier jet ne l'était pas : `chargee(0)` et
    # `chargee(2)` rendent la même image — la phase des bandes est modulo 2 — donc le coach et le
    # profil étaient indiscernables, et le test accusait l'alignement d'une faute de sa propre
    # mise en scène.
    def ecran(n):
        im = Image.new("L", (L, H), 16 + 8 * n)
        epaisseur = 4 + 3 * n
        for y in range(0, H, epaisseur * 3):
            for yy in range(y, min(y + epaisseur, H)):
                for x in range(0, L):
                    im.putpixel((x, yy), 210 - 30 * n)
        return im

    for i in range(1, 361):
        ecran((i - 1) // 90).convert("RGB").save(im_dir / f"{i:04d}.png")
    film = dossier / "quatre.mov"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                    "-i", str(im_dir / "%04d.png"), "-c:v", "libx264", "-crf", "18",
                    "-pix_fmt", "yuv420p", str(film)], check=True)
    temoins_dir = dossier / "clair"
    (temoins_dir / "diagnostic").mkdir(parents=True)
    ecran(0).convert("RGB").save(temoins_dir / "3-coach.png")
    ecran(1).convert("RGB").save(temoins_dir / "6-stats.png")
    ecran(2).convert("RGB").save(temoins_dir / "diagnostic" / "profil.png")
    ecran(3).convert("RGB").save(temoins_dir / "1-accueil.png")

    bascules = [{"nom": n, "debut": d0, "fin": d0 + 2.0, "bascule": True}
                for n, d0 in [("coach", 0.5), ("stats", 3.5), ("profil", 6.5), ("retour", 9.5)]]
    gabarit = bs.posee(film, 1.0, dossier, "g")
    refs = bs.temoins(temoins_dir, gabarit)
    attendu("les quatre témoins du film d'essai sont chargés", sorted(refs),
            ["accueil", "coach", "profil", "stats"])

    # Le décalage juste est 0 ; on annonce 3.
    trouve, ecart, parfait = bs.alignement(film, bascules, refs, 3.0, dossier)
    attendu("le décalage faux de +3 s est retrouvé", round(trouve, 2), 0.0)
    attendu("et chaque plan tombe alors sur son écran", parfait, True)

    # Et quand l'horloge est juste, la recherche ne déplace rien.
    trouve2, _, parfait2 = bs.alignement(film, bascules, refs, 0.0, dossier)
    attendu("une horloge juste n'est pas corrigée", round(trouve2, 2), 0.0)
    attendu("et elle reste parfaite", parfait2, True)

    # LE DÉCALAGE TROUVÉ DOIT SERVIR À DÉCOUPER, PAS SEULEMENT À RECONNAÎTRE.
    #
    # Le 8 novembre, la recherche a rendu −0,75 s en annonçant « chaque plan sur son écran » —
    # et la mesure qui suit n'a plus rien vu : la fenêtre de transition ne contenait plus le
    # changement d'écran. L'identité était juste, le découpage faux de trois quarts de seconde.
    # La cause : la recherche jugeait sur l'image de la FIN du plan, où l'écran est posé depuis
    # plus d'une seconde et demie — une large plage de décalages y met le bon écran, et la
    # recherche tombe n'importe où sur ce plateau.
    #
    # Reconnaître ne suffit donc pas : on vérifie que le décalage trouvé remet le CHANGEMENT
    # d'écran là où le film l'a mis. Dans ce film d'essai, les écrans changent toutes les trois
    # secondes et les plans commencent une demi-seconde après : le changement doit tomber à
    # 0,50 s du début du plan.
    # ET ON VÉRIFIE LA DÉCISION ELLE-MÊME, parce qu'un film fabriqué ne peut pas la montrer.
    #
    # Le plateau n'existe que si les distances varient à peine d'un décalage à l'autre — c'est
    # le bruit d'une vraie vidéo qui tranche alors, et ici il n'y en a pas : deux images
    # identiques rendent exactement la même distance, le départage prend le plus petit décalage
    # d'essai, et il tombe juste par hasard. J'ai remis le défaut dans le script pour vérifier :
    # les quatre cas ci-dessous restaient VERTS. Un test qui ne tombe pas sur le défaut qu'il
    # vise ne garde rien.
    #
    # On regarde donc À QUEL INSTANT la recherche prend ses images. La règle est courte et
    # c'est elle qui a été enfreinte : près du DÉBUT du plan, là où l'écran vient de changer et
    # où la distance au témoin a un minimum net — jamais vers la fin, où l'écran est posé
    # depuis plus d'une seconde et demie et où toute une plage de décalages se vaut.
    appels = []
    vrai_juge = bs.instant_juge
    try:
        bs.instant_juge = lambda b: (appels.append(b["nom"]), vrai_juge(b))[1]
        bs.alignement(film, bascules, refs, 0.0, dossier)
    finally:
        bs.instant_juge = vrai_juge
    attendu("la recherche n'emploie pas l'instant du verdict", appels, [])
    # Et l'inverse, pour que ce couple de cas dise les deux moitiés de la règle : le verdict,
    # lui, l'emploie bel et bien. Vérifié plus haut sur le film « lent ».
    attendu("alors que le verdict, lui, regarde tard",
            round(bs.instant_juge({"debut": 1.0, "fin": 3.0}), 2), 2.75)

    for depart in (3.0, 0.0):
        trouve3, _, _ = bs.alignement(film, bascules, refs, depart, dossier)
        ecarts = []
        for i, b in enumerate(bascules, start=1):
            ref = bs.posee(film, trouve3 + b["debut"] + 0.5, dossier, f"v{i}")
            suite = bs.images(film, trouve3 + b["debut"] - 0.9, 0.9, dossier, f"w{i}")
            classes = bs.classer(suite, ref, bs._gris(suite[0]) if suite else None)
            quand = bs.instant_du_changement(classes, 0.9)
            ecarts.append(quand)
        attendu(f"le changement est vu sur les quatre plans (horloge annoncée {depart})",
                all(q is not None for q in ecarts), True)
        if all(q is not None for q in ecarts):
            moyen = sum(ecarts) / len(ecarts)
            attendu(f"et il tombe où le film l'a mis (horloge annoncée {depart})",
                    abs(moyen - 0.5) < 0.2, True)

# --- QUAND ON JUGE UN PLAN -----------------------------------------------------------------------
# LE DÉFAUT DU 8 NOVEMBRE 2026, ET IL N'ÉTAIT PAS UN DÉFAUT DE DÉCOUPAGE.
#
# Le film espagnol a été refusé : « ce plan vise stats et montre profil (écart 24,4 contre 25,0) ».
# Un quasi-ex æquo, là où un plan posé rend 6,4 contre 24,6 — et les trois autres plans du même
# film étaient reconnus sans la moindre hésitation. L'alignement était donc juste. Ce qui ne
# l'était pas, c'est l'INSTANT : « stats » a mis 0,57 s à se poser ce jour-là — dix-sept images
# sur vingt — et l'image prise à 0,5 s était un mélange des deux écrans.
#
# On fabrique un film où le plan met délibérément du temps à se poser, et on vérifie les deux
# verdicts sur le même film : à `debut + 0,5 s` on se trompe, à la fin du plan on ne se trompe pas.
attendu("l'instant jugé est pris un quart de seconde avant la fin",
        round(bs.instant_juge({"debut": 3.5, "fin": 5.5}), 2), 5.25)
attendu("un plan trop court garde l'ancien instant",
        round(bs.instant_juge({"debut": 3.5, "fin": 3.6}), 2), 4.0)

with tempfile.TemporaryDirectory() as d:
    dossier = pathlib.Path(d)
    im_dir = dossier / "i"
    im_dir.mkdir()

    def uni(n):
        """Deux écrans franchement différents : un clair, un sombre."""
        return Image.new("L", (L, H), 40 + 150 * n)

    # Trois secondes à 30 images : 0,0–1,0 s l'écran 0 (« profil »), 1,0–1,8 s un MÉLANGE des
    # deux — l'écran qui arrive, pas encore posé — puis l'écran 1 (« stats ») jusqu'au bout.
    for i in range(1, 91):
        t_s = (i - 1) / 30
        if t_s < 1.0:
            im = uni(0)
        elif t_s < 1.8:
            im = Image.blend(uni(0), uni(1), 0.5)
        else:
            im = uni(1)
        im.convert("RGB").save(im_dir / f"{i:04d}.png")
    film = dossier / "lent.mov"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                    "-i", str(im_dir / "%04d.png"), "-c:v", "libx264", "-crf", "18",
                    "-pix_fmt", "yuv420p", str(film)], check=True)

    temoins_dir = dossier / "clair"
    (temoins_dir / "diagnostic").mkdir(parents=True)
    uni(0).convert("RGB").save(temoins_dir / "diagnostic" / "profil.png")
    uni(1).convert("RGB").save(temoins_dir / "6-stats.png")
    gabarit = bs.posee(film, 2.5, dossier, "g2")
    refs = bs.temoins(temoins_dir, gabarit)

    # Le plan « stats » commence à 1,0 s et dure deux secondes ; il se pose à 1,8 s.
    plan = {"nom": "stats", "debut": 1.0, "fin": 3.0, "bascule": True}

    tot = bs.le_plus_proche(bs.posee(film, plan["debut"] + 0.5, dossier, "tot"), refs)
    attendu("à 0,5 s du début, le plan ne ressemble à aucun des deux écrans",
            abs(tot[0][1] - tot[1][1]) < 10, True)

    tard = bs.le_plus_proche(bs.posee(film, bs.instant_juge(plan), dossier, "tard"), refs)
    attendu("à la fin du plan, c'est « stats » sans hésitation", tard[0][0], "stats")
    attendu("et l'écart au suivant est franc", tard[1][1] - tard[0][1] > 40, True)


# --- L'ALIGNEMENT DES DEUX HORLOGES -------------------------------------------------------------
# LE DÉFAUT QUI A SORTI TROIS FILMS FAUX. Le test appuie sur l'onglet, attend 0,6 s, puis déclare
# le plan : le changement d'écran doit tomber à 0,6 s du début du plan. Il tombait trois secondes
# plus tôt, parce que la caméra met trois secondes à démarrer et que personne ne les comptait.
# Aucune durée ne pouvait le dire — un plan de deux secondes découpé au mauvais endroit dure
# toujours deux secondes.
attendu("le changement juste où on l'attend",
        round(bs.instant_du_changement(["avant"] * 9 + ["transition"] * 4 + ["posée"] * 14, 0.9), 2),
        0.6)
attendu("un changement trop tôt se chiffre",
        round(bs.instant_du_changement(["transition"] * 4 + ["posée"] * 23, 0.9), 2), 0.9)
attendu("un changement tardif aussi",
        round(bs.instant_du_changement(["avant"] * 24 + ["posée"] * 3, 0.9), 2), 0.1)
# Rien que l'écran d'avant : on n'a pas vu le changement, et on ne l'invente pas.
attendu("aucun changement vu", bs.instant_du_changement(["avant"] * 27, 0.9), None)
# La fenêtre ne commence pas sur l'écran d'avant : le premier élément décide, et c'est tout
# l'intérêt — un désalignement de trois secondes met la fenêtre entière après la bascule.
attendu("une fenêtre qui commence déjà posée", bs.instant_du_changement(["posée"] * 27, 0.9), 0.9)

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
