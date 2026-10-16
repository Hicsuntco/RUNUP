#!/usr/bin/env python3
"""`RUColor.text4` ne colore pas du texte à lire : c'est la couleur des points et des barres.

# LE DÉFAUT

`text4` vaut 20 à 22 % d'opacité — environ 1,5:1 sur le fond de l'app, là où la règle
d'accessibilité demande 4,5:1 pour du texte courant et 3:1 pour du grand texte. C'est volontaire :
`text4` existe pour les POINTS MÉDIANS entre deux liens, les filets verticaux d'une frise, les
petites pastilles inertes. Des objets dont la fonction est d'être à peine là.

L'audit l'a trouvée sur une vraie phrase : « Records, charge, prédiction », la ligne qui dit ce
que contient la section dépliable des Stats, était affichée en `text4`. Elle ne se lisait pas — et
rien ne pouvait le signaler, puisque `text4` est une couleur légitime du système de design.

# CE QUE LE SCRIPT REGARDE

Uniquement `RUColor.text4` passé à `.foregroundColor(...)`, donc appliqué à un `Text` ou à une
image. Un `.fill(RUColor.text4)` sur une forme n'est jamais un problème de contraste de texte : un
filet de 3 points de large ne se lit pas, il se voit ou pas.

Chaque `.foregroundColor(RUColor.text4)` du dépôt est dans l'ensemble FERMÉ ci-dessous, avec sa
raison. Un nouvel emploi fait donc échouer la CI jusqu'à ce que quelqu'un écrive pourquoi ce
texte-là a le droit d'être presque invisible — ce qui est exactement la question qu'on n'avait pas
posée pour « Records, charge, prédiction ».
"""

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ["RunUp", "RunUpWidgets", "RunUpWatch"]

EMPLOI = re.compile(r"\.foregroundColor\(\s*[^)]*RUColor\.text4")

# Ensemble FERMÉ, une raison par entrée. La reconnaissance se fait sur le TEXTE de la ligne et
# non sur son numéro : une ligne ajoutée ailleurs dans le fichier ne déplace pas une tolérance.
TOLERES = [
    # Le point médian qui sépare « abonnés » de « abonnements ». Un signe de ponctuation
    # décoratif : il n'y a rien à y lire, et le lire à voix haute serait du bruit.
    ("RunUp/Views/Club/FriendsView.swift", 'Text("·")'),
    # Les deux points médians entre les liens du pied du paywall. Même raison, et ils sont en
    # `Text(verbatim:)` précisément parce qu'il n'y a pas de mot dedans.
    ("RunUp/Views/Paywall/PaywallView.swift", 'Text(verbatim: "·")'),
    # Le chevron d'un bouton de navigation DÉSACTIVÉ. Les commandes inactives sont hors du
    # critère de contraste (WCAG 1.4.3), et une flèche pâle est la façon dont iOS dit « pas
    # maintenant » — l'alternative serait de la retirer, ce qui n'apprend rien.
    ("RunUp/Views/Home/PlanView.swift", "enabled ? RUColor.textPrimary : RUColor.text4"),
]


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


def est_tolere(relatif: str, ligne: str) -> bool:
    return any(f == relatif and extrait in ligne for f, extrait in TOLERES)


def problemes() -> list:
    erreurs = []
    for dossier in DOSSIERS:
        base = RACINE / dossier
        if not base.is_dir():
            continue
        for fichier in sorted(base.rglob("*.swift")):
            relatif = fichier.relative_to(RACINE).as_posix()
            source = sans_commentaires(fichier.read_text(encoding="utf-8"))
            lignes = source.splitlines()
            for numero, ligne in enumerate(lignes, start=1):
                if not EMPLOI.search(ligne):
                    continue
                if est_tolere(relatif, ligne):
                    continue
                erreurs.append(
                    f"{relatif}:{numero} colore du texte en `RUColor.text4` — "
                    f"20 % d'opacité, soit ~1,5:1, la couleur des points de séparation. "
                    f"`text3` pour un texte à lire ; sinon, ajoute la raison dans TOLERES"
                )
    return erreurs


def main() -> int:
    erreurs = problemes()
    if erreurs:
        print("Du texte est affiché à un contraste où il ne se lit pas :\n")
        for e in erreurs:
            print(f"  ✗ {e}")
        return 1
    print(f"Contraste : {len(TOLERES)} emplois de text4 sur du texte, tous justifiés ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
