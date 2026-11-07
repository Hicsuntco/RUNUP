#!/usr/bin/env python3
"""Aucune taille d'icône écrite à la main hors de l'échelle.

# LE DÉFAUT

`RUIconSize` a sept crans. Avant, il y avait VINGT-DEUX tailles écrites à la main sur 170 appels,
de 8 à 72 points — 13, 14 et 15 voisinant sur 76 d'entre eux. Trois tailles dans deux points,
donc des écarts trop petits pour se lire comme une hiérarchie et assez grands pour que rien ne
s'aligne. Personne ne les avait décidées : chaque écran avait été réglé à l'œil, puis recopié.

C'est exactement le défaut que `RUDisplaySize` a fermé pour le titrage et `RUTextSize` pour le
texte courant. Les icônes étaient la troisième famille, et la dernière à ne rien avoir.

# CE QUI EST REGARDÉ

Tout appel à `.font(.system(size:` dans `RunUp/Views`. Il en reste DEUX, et ce sont des glyphes : les deux chevrons « ‹ » des boutons de retour ont rejoint `chevron.left` le 7 novembre, sur décision de Charlotte. Le compilateur ne peut pas l'interdire :
c'est une API de SwiftUI, pas une des nôtres. Ce contrôle fixe donc la liste des exceptions,
fichier par fichier, avec son compte et sa raison — en ajouter une demande de modifier CE
fichier, c'est-à-dire d'écrire pourquoi cet appel-là ne peut pas tenir sur les sept crans.

# CE QUI N'EST PAS REGARDÉ, ET POURQUOI

Le widget et la montre. `RunUp/DesignSystem/Typography.swift` n'appartient pas à leurs cibles —
seule une poignée de fichiers de `RunUp/Shared` y est partagée — donc `RUFont` n'y existe pas, et
leurs quatre appels ne peuvent pas prendre un cran. Les y obliger demanderait de partager tout le
système de typographie avec deux processus qui ne portent ni thème ni réglage de taille ; ce
n'est pas ce qu'on répare ici.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
MOTIF = re.compile(r"\.font\(\s*\.system\(size:")

# fichier → (nombre d'appels attendu, la raison)
AUTORISE = {
    "RunUp/Views/Home/Sheets/NotificationsSheet.swift":
        (1, "le repli qui affiche l'emoji d'une notification déjà enregistrée en base"),
    "RunUp/Views/ProgramEnd/NewGoalWizardView.swift":
        (1, "la coche typographique « ✓ » de la fin de construction du plan"),
}


def comptes() -> dict:
    """fichier → nombre d'appels à `.font(.system(size:))`, pour les vues qui en ont."""
    trouves = {}
    dossier = RACINE / "RunUp/Views"
    if not dossier.is_dir():
        raise SystemExit("RunUp/Views est introuvable : ce contrôle ne relit pas ce qu'il annonce.")
    for chemin in sorted(dossier.rglob("*.swift")):
        n = len(MOTIF.findall(chemin.read_text(encoding="utf-8")))
        if n:
            trouves[str(chemin.relative_to(RACINE))] = n
    return trouves


def ecarts(trouves: dict, autorise: dict | None = None) -> list[str]:
    """Ce qui ne colle pas entre ce qu'on a trouvé et ce qui est justifié ici."""
    autorise = AUTORISE if autorise is None else autorise
    fautes = []
    for fichier, n in sorted(trouves.items()):
        attendu = autorise.get(fichier)
        if attendu is None:
            fautes.append(f"{fichier} — {n} taille(s) écrite(s) à la main. "
                          f"Prendre un cran de `RUIconSize` : RUFont.icone(.body) par exemple.")
        elif n != attendu[0]:
            fautes.append(f"{fichier} — {n} appel(s) pour {attendu[0]} autorisé(s) "
                          f"({attendu[1]}).")
    for fichier, (attendu, _raison) in sorted(autorise.items()):
        if fichier not in trouves:
            fautes.append(f"{fichier} — {attendu} appel(s) attendu(s), aucun trouvé : "
                          f"l'exception n'a plus lieu d'être, la retirer d'ici.")
    return fautes


def main() -> int:
    trouves = comptes()
    fautes = ecarts(trouves)

    if fautes:
        print(f"{len(fautes)} écart(s) à l'échelle d'icônes :")
        for f in fautes:
            print(f"  · {f}")
        return 1
    total = sum(trouves.values())
    print(f"{total} appel(s) à `.font(.system(size:))` dans les vues, tous listés et justifiés ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
