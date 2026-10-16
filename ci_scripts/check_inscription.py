#!/usr/bin/env python3
"""Un écran d'inscription doit pouvoir défiler : sinon son bouton sort de l'écran en grand texte.

# LA PANNE

Les écrans d'inscription sont écrits « le contenu au milieu, le bouton en bas » :

    ObScreen {
        Spacer()
        ObTitle(...)
        ...
        Spacer()
        ObNext(label: "C'EST PARTI", action: onDone)
    }

Cette mise en page centre joliment — tant que le contenu est plus court que l'écran. L'app
autorise le texte jusqu'à DEUX FOIS sa taille (`RUFont.maxScale`). À cette taille, les deux
`Spacer` tombent à zéro, le contenu dépasse la hauteur disponible, et ce qui est en bas de la
pile sort de l'écran. En bas de `PlanRecapView`, il y a « C'EST PARTI » — le seul bouton qui
termine l'inscription.

Autrement dit : quelqu'un qui agrandit le texte pour pouvoir lire l'app ne pouvait pas finir de
s'y inscrire, et rien à l'écran ne lui disait pourquoi. Dix des quinze écrans avaient leur propre
`ScrollView` ; les quatre qui n'en avaient pas étaient précisément ceux de la fin du parcours.

# LA RÈGLE

Tout fichier qui emploie `ObScreen` doit contenir soit un `ScrollView`, soit `ObCorps` — le
conteneur qui garde le centrage quand ça tient et fait défiler quand ça ne tient plus.

`ObCorps` ne coûte rien à un écran court : il centre, comme les deux `Spacer` qu'il remplace. Il
n'y a donc pas de cas où un écran d'inscription aurait raison de n'avoir ni l'un ni l'autre, et
c'est ce qui permet à cette règle de n'avoir aucune exception.
"""

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
INSCRIPTION = RACINE / "RunUp/Views/Onboarding"

# Le fichier qui DÉFINIT les composants n'est pas un écran.
DEFINITIONS = {"OnboardingComponents.swift"}

EMPLOI = re.compile(r"\bObScreen\s*\{")
DEFILEMENT = re.compile(r"\bScrollView\b|\bObCorps\s*\{")


def sans_commentaires(source: str) -> str:
    sortie, i, n, bloc = [], 0, len(source), 0
    while i < n:
        if bloc:
            if source.startswith("/*", i):
                bloc += 1; i += 2
            elif source.startswith("*/", i):
                bloc -= 1; i += 2
            else:
                sortie.append("\n" if source[i] == "\n" else " "); i += 1
            continue
        if source.startswith("/*", i):
            bloc = 1; sortie.append("  "); i += 2
        elif source.startswith("//", i):
            while i < n and source[i] != "\n":
                sortie.append(" "); i += 1
        else:
            sortie.append(source[i]); i += 1
    return "".join(sortie)


def problemes() -> list:
    if not INSCRIPTION.is_dir():
        return ["RunUp/Views/Onboarding a disparu — le contrôle ne vérifie plus rien"]
    erreurs, ecrans = [], 0
    for fichier in sorted(INSCRIPTION.glob("*.swift")):
        if fichier.name in DEFINITIONS:
            continue
        source = sans_commentaires(fichier.read_text(encoding="utf-8"))
        if not EMPLOI.search(source):
            continue
        ecrans += 1
        if DEFILEMENT.search(source):
            continue
        erreurs.append(
            f"RunUp/Views/Onboarding/{fichier.name} emploie `ObScreen` sans `ScrollView` "
            f"ni `ObCorps` — à deux fois la taille de texte, son bouton sort de l'écran "
            f"et rien ne permet d'aller le chercher"
        )
    if ecrans == 0:
        erreurs.append("Aucun écran d'inscription trouvé : le contrôle ne vérifie plus rien")
    return erreurs


def main() -> int:
    erreurs = problemes()
    if erreurs:
        print("Un écran d'inscription peut cacher son propre bouton :\n")
        for e in erreurs:
            print(f"  ✗ {e}")
        print("\n`ObCorps` centre quand ça tient et fait défiler quand ça ne tient plus.")
        return 1
    print("Inscription : tous les écrans peuvent défiler en grand texte ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
