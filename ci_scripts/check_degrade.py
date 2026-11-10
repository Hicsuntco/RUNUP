#!/usr/bin/env python3
"""Refuse un dégradé dans l'interface, et nomme ceux qui ont le droit d'y rester.

# LA RÈGLE, ET POURQUOI ELLE A UNE LISTE D'EXCEPTIONS

Règle 7 du brief : « pas de dégradés dans l'interface ». La direction artistique précise où le
dégradé rose-violet a le droit d'exister : « sur l'icône, le splash et le logo », nulle part
ailleurs.

Appliquée à la lettre, cette règle interdirait aussi le voile noir qui rend un titre lisible
par-dessus un tracé GPS, et l'anneau dont chaque arc vire vers la couleur de son voisin pour se
lire comme un seul ruban. Ni l'un ni l'autre n'est de la décoration : le premier sert à LIRE, le
second PORTE une information. La règle visée est donc celle-ci, et c'est elle que ce script
applique :

    Un dégradé est interdit comme DÉCORATION d'un écran.
    Il reste permis quand il porte une information, quand il rend lisible,
    ou quand il appartient à une image produite — la marque, un avatar, une carte de partage.

Trois exceptions, nommées, comptées, et chacune avec sa raison écrite ci-dessous. Tout le reste
est refusé. Une liste d'exceptions sans raisons devient une liste de passe-droits ; celle-ci se
relit.

# POURQUOI UN COMPTE EXACT PAR FICHIER

Autoriser un fichier en bloc rouvrirait la porte qu'on vient de fermer : il suffirait d'ajouter un
dégradé décoratif dans `AvatarView` pour qu'il passe. Chaque entrée dit COMBIEN de dégradés ce
fichier a le droit de porter. Un de plus, un de moins, et le script parle — dans les deux sens,
parce qu'un dégradé qui disparaît est une exception devenue inutile, et qu'elle doit sortir de la
liste au lieu d'y dormir.

# CE QU'IL NE VOIT PAS

Un dégradé fabriqué autrement : une image qui en contient un, un `Canvas`, un `.shadow` assez
large pour en faire un. Ce script lit du texte Swift ; ce qui se voit à l'œil se voit sur une
capture, et c'est l'autre moitié du travail.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from swift import sans_commentaires  # noqa: E402

RACINE = pathlib.Path(__file__).resolve().parent.parent
CIBLES = ["RunUp", "RunUpWatch", "RunUpWidgets"]

# `.gradient` est le raccourci de SwiftUI (`Color.rose.gradient`), et il est TOUJOURS précédé
# d'un identifiant — une première version excluait justement ce cas-là par une anti-recherche
# arrière, et ne voyait donc que ce qui n'existe pas. `(?!\w)` suffit à écarter
# `seg.gradientStartDegrees`, qui n'est pas un dégradé mais un angle.
DEGRADE = re.compile(
    r"\b(LinearGradient|RadialGradient|AngularGradient|EllipticalGradient|MeshGradient)\s*\(|"
    r"\.gradient(?!\w)")

#: fichier → (nombre de dégradés autorisés, pourquoi)
PERMIS = {
    # ── 1. LA MARQUE ──────────────────────────────────────────────────────────────────────────
    "RunUp/DesignSystem/Colors.swift": (
        1, "`brandGradient` — le seul dégradé que la direction artistique nomme : l'icône, le "
           "splash et le logo. `AppMarkView` est son unique appelant."),

    # ── 2. UNE IMAGE PRODUITE, PAS UN ÉCRAN ───────────────────────────────────────────────────
    "RunUp/Views/Club/BadgeShareCardView.swift": (
        1, "La carte qu'on partage quand on décroche un badge. C'est une image qu'on poste "
           "ailleurs, pas un écran de l'app : elle porte la marque comme le logo la porte."),
    "RunUp/Views/Live/RunShareCardView.swift": (
        1, "La carte qu'on partage après une course, style « RunUp ». Même raison."),
    "RunUp/Views/Live/RunVideoFrameView.swift": (
        3, "Les images d'une vidéo de course, destinées à être publiées. Deux halos et un titre."),
    "RunUp/Views/Components/AvatarView.swift": (
        2, "L'avatar fabriqué pour quelqu'un qui n'a pas mis de photo. Il REMPLACE une image, "
           "donc c'en est une — et deux lueurs décalées lui donnent une matière qu'un disque "
           "uni n'a pas."),

    # ── 3. UN VOILE QUI SERT À LIRE ───────────────────────────────────────────────────────────
    "RunUp/Views/Home/HomeView.swift": (
        1, "Le voile noir sous le texte posé SUR un tracé GPS. Sans lui, le titre tombe sur une "
           "carte claire ou sombre selon le parcours, et devient illisible une fois sur deux."),
    "RunUp/Views/Live/RecapView.swift": (
        1, "Le fondu en bas du défilement : le contenu s'efface sous le bord au lieu d'y être "
           "coupé net."),

    # ── 4. LA COULEUR PORTE UNE INFORMATION ───────────────────────────────────────────────────
    "RunUp/Views/Components/DailyGoalsBarsView.swift": (
        1, "L'anneau des objectifs du jour. Chaque arc garde sa couleur sur ses quatre premiers "
           "cinquièmes puis vire vers celle de son VOISIN : les deux se rejoignent dans la même "
           "teinte de part et d'autre de l'écart, et l'anneau se lit comme un seul ruban qui "
           "change de couleur au lieu de trois bâtons posés en cercle. Le dégradé est ici la "
           "frontière entre deux mesures, pas un ornement."),
    "RunUpWidgets/DailyGoalsWidget.swift": (
        1, "Le même anneau, dans le widget. Mêmes arcs, même raison — et il doit rester "
           "identique à celui de l'app, sinon l'écran d'accueil et l'app se contredisent."),
    "RunUp/Views/Components/SparklineView.swift": (
        1, "L'aire sous la courbe, qui s'efface vers le bas. C'est la convention de lecture d'un "
           "graphe : l'aire dit « voilà le volume », le fondu dit « ce n'est pas une surface "
           "pleine ». Un aplat la ferait lire comme une barre."),
}


def releve(racine=RACINE):
    """fichier (relatif) → nombre de dégradés dans son code."""
    compte = {}
    for cible in CIBLES:
        dossier = racine / cible
        if not dossier.is_dir():
            continue
        for f in sorted(dossier.rglob("*.swift")):
            n = len(DEGRADE.findall(sans_commentaires(f.read_text(encoding="utf-8"))))
            if n:
                compte[f.relative_to(racine).as_posix()] = n
    return compte


def verifier(racine=RACINE, permis=None):
    permis = PERMIS if permis is None else permis
    compte = releve(racine)
    plaintes = []
    for fichier, n in sorted(compte.items()):
        if fichier not in permis:
            plaintes.append(
                f"{fichier} : {n} dégradé(s) dans l'interface. La règle 7 les interdit — "
                f"pose un aplat, ou ajoute ce fichier à `PERMIS` avec la raison écrite.")
            continue
        attendu, _ = permis[fichier]
        if n != attendu:
            plaintes.append(
                f"{fichier} : {n} dégradé(s), {attendu} autorisé(s). "
                + ("Un de plus que ce que la raison couvre." if n > attendu
                   else "Un de moins : l'exception a servi, elle ne sert plus. Retire-la."))
    for fichier in sorted(permis):
        if fichier not in compte:
            plaintes.append(
                f"{fichier} : plus aucun dégradé, mais le fichier est encore dans `PERMIS`. "
                f"Une exception qui dort finit par servir à autre chose.")
    return plaintes


def main():
    plaintes = verifier()
    for p in plaintes:
        print(f"✗ {p}")
    if plaintes:
        print(f"\n{len(plaintes)} problème(s). Les exceptions et leurs raisons sont en tête de "
              f"ci_scripts/check_degrade.py.")
        return 1
    total = sum(n for n, _ in PERMIS.values())
    print(f"✓ Aucun dégradé décoratif. {total} autorisés dans {len(PERMIS)} fichiers, chacun avec "
          f"sa raison.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
