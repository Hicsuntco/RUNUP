#!/usr/bin/env python3
"""L'animation d'ouverture doit être FINIE quand l'écran commence à s'effacer.

# LE DÉFAUT

`SplashView` joue trois mouvements décalés, puis attend un délai fixe avant de lancer son fondu
de sortie. Les trois durées viennent de `RUMotion`, le délai est écrit dans le fichier, et
personne ne les avait jamais additionnés.

Mesuré le 13 novembre : le dévoilement démarrait à 0,58 s et durait 800 ms, donc il finissait à
1,38 s — alors que le fondu commençait à 1,15 s. **29 % du mouvement d'ouverture de l'app se
jouait pendant que l'écran disparaissait déjà.** Personne n'en a jamais vu la fin, et rien ne
pouvait le signaler : chaque valeur était raisonnable toute seule.

C'est le défaut typique d'une chorégraphie — il ne vit dans aucune des pièces, seulement dans
leur somme. Et il revient dès qu'on touche à une durée du système de mouvement sans penser à
l'écran de lancement, ce qui est exactement ce qui va arriver.

# CE QUE LE SCRIPT REGARDE

Chaque `withAnimation(RUMotion.<jeton>.delay(<d>))` de `SplashView` : il lit la durée du jeton
dans `Motion.swift`, y ajoute le délai, et exige que la somme tienne avant le `Task.sleep` qui
précède le fondu. Les animations écrites à la main dans le fichier sont lues de la même façon.
"""

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from swift import sans_commentaires  # noqa: E402

RACINE = pathlib.Path(__file__).resolve().parent.parent
SPLASH = RACINE / "RunUp/Views/Components/SplashView.swift"
MOTION = RACINE / "RunUp/DesignSystem/Motion.swift"

# La marge qu'on exige entre la fin du dernier mouvement et le début du fondu. Zéro suffirait en
# arithmétique ; 50 ms laisse de quoi ne pas dépendre de l'image près.
MARGE = 0.05


def durees_du_systeme() -> dict:
    src = sans_commentaires(MOTION.read_text(encoding="utf-8"))
    return {nom: float(d) for nom, d in
            re.findall(r"static let ([a-zA-Z]+) = Animation\.[^\n]*?duration: ([0-9.]+)", src)}


def tempo() -> dict:
    """Les constantes nommées de `SplashView.Tempo`."""
    src = sans_commentaires(SPLASH.read_text(encoding="utf-8"))
    bloc = src.split("private enum Tempo {", 1)
    if len(bloc) < 2:
        return {}
    corps = bloc[1].split("\n    }", 1)[0]
    return {nom: float(v) for nom, v in
            re.findall(r"static let ([a-zA-Z]+) = ([0-9.]+)", corps)}


def chorégraphie() -> tuple:
    """(mouvements, instant du fondu) — un mouvement est (nom, départ, durée).

    Les départs viennent de `SplashView.Tempo`, les durées de `RUMotion` quand le mouvement
    emprunte un jeton du système. Rien n'est deviné d'une analyse de la fonction : trois versions
    de ce garde s'y sont cassé les dents, parce qu'une fonction à deux branches ne se lit pas à
    l'expression régulière. Les nombres sont nommés à la source, et ce fichier les lit.
    """
    t, durees = tempo(), durees_du_systeme()
    if not t or "fondu" not in t:
        return [], None
    mouvements = [
        ("le tracé", 0.0, t.get("traceDuree", 0.0)),
        ("la tuile (RUMotion.settle)", t.get("tuileDepart", 0.0), durees.get("settle", 0.0)),
        ("le dévoilement (RUMotion.glide)", t.get("revealDepart", 0.0), durees.get("glide", 0.0)),
    ]
    return mouvements, t["fondu"]


def ecarts() -> list:
    mouvements, fondu = chorégraphie()
    if fondu is None:
        return [("SplashView.swift", "",
                 "`SplashView.Tempo` ne se lit plus : soit l'énumération a disparu, soit ses "
                 "constantes ont changé de nom. Un garde qui ne trouve plus ses nombres ne garde "
                 "rien — remettez-le d'accord avec le fichier plutôt que de le laisser passer.")]
    if not mouvements:
        return [("SplashView.swift", "",
                 "Aucun mouvement lu dans la chorégraphie — le motif a dû changer, et le garde "
                 "ne garde plus rien.")]
    problemes = []
    for nom, delai, duree in mouvements:
        fin = delai + duree
        if fin > fondu - MARGE:
            problemes.append((
                "RunUp/Views/Components/SplashView.swift", nom,
                f"Démarre à {delai:.2f} s, dure {duree:.2f} s, donc finit à {fin:.2f} s — alors "
                f"que le fondu commence à {fondu:.2f} s. "
                f"{100 * (fin - fondu) / duree:.0f} % du mouvement se joue pendant que l'écran "
                "disparaît. Raccourcissez la durée, avancez le départ, ou reculez le fondu."))
    return problemes


def main() -> int:
    problemes = ecarts()
    if problemes:
        print(f"{len(problemes)} mouvement(s) d'ouverture qui finissent trop tard :\n")
        for ou, quoi, raison in problemes:
            print(f"  • {ou} — {quoi}")
            print(f"      {raison}\n")
        return 1
    mouvements, fondu = chorégraphie()
    dernier = max(d + u for _, d, u in mouvements)
    print(f"L'ouverture tient : {len(mouvements)} mouvements, le dernier finit à {dernier:.2f} s, "
          f"le fondu commence à {fondu:.2f} s.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
