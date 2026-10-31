#!/usr/bin/env python3
"""Le découpage et la commande de `check_apercu`, éprouvés sans ffmpeg.

Un aperçu refusé par App Store Connect ne dit pas laquelle des cinq contraintes a sauté. Les
décisions qui mènent au refus — combien de secondes garder, quelle taille viser, quelle cadence —
sont ici, et elles se vérifient sans toucher à un fichier vidéo.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import apercu as ap  # noqa: E402

echecs = []
# LE TOTAL SE COMPTE, IL NE S'ÉCRIT PAS.
#
# Il était posé en dur — `total = 24` — au bas du fichier. Cinq cas ajoutés plus haut, et le
# fichier continuait d'annoncer « 24/24 cas passent » : un compte faux dans les deux sens, qui
# dirait la même chose avec trois cas qu'avec trente. Un test dont le compte est une constante ne
# peut pas signaler qu'on a cessé de l'alimenter.
total = 0


def attendu(nom, obtenu, voulu):
    global total
    total += 1
    if obtenu != voulu:
        echecs.append(f"{nom} : {obtenu!r} au lieu de {voulu!r}")


def refuse(nom, fn):
    global total
    total += 1
    try:
        fn()
    except SystemExit:
        return
    echecs.append(f"{nom} : aurait dû être refusé")


# --- Le découpage ------------------------------------------------------------------------------
# Pile dans la fourchette : on garde tout.
attendu("22 s gardées en entier", ap.decoupe(22.0, 0), (0, 22.0))
# Les deux bornes d'Apple sont INCLUSES.
attendu("15 s exactement", ap.decoupe(15.0, 0), (0, 15.0))
attendu("30 s exactement", ap.decoupe(30.0, 0), (0, 30.0))
# Trop long : on coupe à trente, pas plus.
attendu("90 s ramenées à 30", ap.decoupe(90.0, 0), (0, 30.0))
# Avec un début décalé, la durée se mesure sur ce qui RESTE.
attendu("90 s à partir de 70", ap.decoupe(90.0, 70), (70, 20.0))
attendu("90 s à partir de 10", ap.decoupe(90.0, 10), (10, 30.0))

# UNE DURÉE DEMANDÉE, quand l'appelant sait où la prise s'arrête. Sans elle, un enregistrement
# plus long que la prise donne trente secondes pile — le plafond, pas une fin — et la vidéo
# s'achève sur ce qui traînait après le dernier plan.
attendu("prise de 26 s dans 40 s filmées", ap.decoupe(40.0, 0, 26.0), (0, 26.0))
attendu("prise plus longue que le plafond", ap.decoupe(60.0, 0, 44.0), (0, 30.0))
attendu("prise plus longue que ce qui reste", ap.decoupe(25.0, 0, 40.0), (0, 25.0))
attendu("prise de 26 s à partir de 4", ap.decoupe(40.0, 4, 26.0), (4, 26.0))
# Une prise trop courte se dit ici, pas après l'envoi — même règle que pour l'enregistrement.
refuse("prise de 12 s", lambda: ap.decoupe(40.0, 0, 12.0))

# Le piège le plus courant : filmer douze secondes et l'apprendre après l'envoi.
refuse("12 s", lambda: ap.decoupe(12.0, 0))
refuse("40 s mais à partir de 30", lambda: ap.decoupe(40.0, 30))
refuse("début négatif", lambda: ap.decoupe(30.0, -1))

# --- Le filtre --------------------------------------------------------------------------------
f = ap.filtre()
for morceau in ["scale=886:1920", "force_original_aspect_ratio=decrease",
                "pad=886:1920", "fps=30"]:
    if morceau not in f:
        echecs.append(f"filtre : « {morceau} » manque dans « {f} »")
# ON NE DÉFORME PAS, ET ON NE RECADRE PAS. `increase` étirerait l'app, `crop` lui couperait un
# bord — sur un rapport de forme qui diffère de trois millièmes, les deux seraient absurdes.
for interdit in ["increase", "crop"]:
    if interdit in f:
        echecs.append(f"filtre : « {interdit} » ne doit pas y être")

# --- La commande ------------------------------------------------------------------------------
entree = pathlib.Path("/tmp/entree.mov")
sortie = pathlib.Path("/tmp/sortie.mp4")

avec = ap.arguments(entree, sortie, 3, 20, a_du_son=True)
sans = ap.arguments(entree, sortie, 3, 20, a_du_son=False)

# `-ss` AVANT `-i`, sinon ffmpeg décode tout le fichier depuis le début pour arriver au même point.
if avec.index("-ss") > avec.index("-i"):
    echecs.append("-ss doit précéder -i")
# Sans son dans la source, une piste muette est ajoutée.
if "anullsrc=channel_layout=stereo:sample_rate=48000" not in " ".join(sans):
    echecs.append("piste muette absente quand la source n'a pas de son")
if "anullsrc" in " ".join(avec):
    echecs.append("piste muette ajoutée alors que la source a du son")
# Les réglages qu'Apple exige, présents dans les deux cas.
for cas, args in (("avec son", avec), ("sans son", sans)):
    joint = " ".join(args)
    for attendu_dans in ["-c:v libx264", "-pix_fmt yuv420p", "-c:a aac", "+faststart", "-t 20"]:
        if attendu_dans not in joint:
            echecs.append(f"{cas} : « {attendu_dans} » manque")

# --- Les constantes, contre une faute de frappe -----------------------------------------------
attendu("largeur", ap.LARGEUR, 886)
attendu("hauteur", ap.HAUTEUR, 1920)
attendu("cadence", ap.IMAGES_PAR_SECONDE, 30)
attendu("plancher", ap.SECONDES_MIN, 15)
attendu("plafond", ap.SECONDES_MAX, 30)

if echecs:
    print(f"{len(echecs)} cas se comportent mal :\n", file=sys.stderr)
    for e in echecs:
        print(f"  {e}", file=sys.stderr)
    sys.exit(1)
print(f"\n{total}/{total} cas passent.")
