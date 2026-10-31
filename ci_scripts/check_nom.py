#!/usr/bin/env python3
"""Le nom de quelqu'un s'écrit à un seul endroit.

# POURQUOI CE CONTRÔLE EXISTE

La même personne ne portait pas le même nom d'un écran à l'autre : « Charlotte » au fil, au
classement, sous un commentaire et sur un record du club ; « Charlotte Grudé » dans la recherche
d'amis et sur sa page. Ce n'était pas un oubli isolé mais une absence de décision — chaque écran
affichait ce que son modèle portait, et les modèles ne portaient pas la même chose.

La règle est désormais écrite une fois, dans `Nomme` : prénom et nom partout où l'on NOMME
quelqu'un. Une règle écrite une fois ne tient que si rien ne la réécrit à côté. Ce contrôle
interdit les trois façons de la réécrire.

# LES TROIS RÈGLES

1. AUCUNE COMPOSITION À LA MAIN. « \\(name) \\(lastName) » et ses variantes sont la forme exacte
   qu'avaient les deux copies supprimées en même temps que `Nomme` a été écrit. C'est par là que
   la divergence revient : une copie ne se trompe pas le jour où on l'écrit, elle se trompe le
   jour où l'original change.

2. `nomComplet` NE SE REDÉFINIT PAS. Une structure qui s'en donne une version à elle gagne sur
   celle du protocole, sans ambiguïté, sans avertissement du compilateur, et sans que rien
   n'indique à la lecture laquelle des deux s'applique.

3. QUI SE DIT `Nomme` PORTE DE QUOI L'ÊTRE. Une conformité qui s'appuie sur un `name` seul
   rendrait `nomComplet` égal au prénom pour toujours — c'est-à-dire exactement le défaut
   d'origine, mais cette fois avec un protocole pour le certifier correct.

# CE QUE CE CONTRÔLE NE SAIT PAS FAIRE, ET IL FAUT LE DIRE

Il ne sait pas voir qu'un écran affiche `item.name` là où il devrait afficher `item.nomComplet` :
il faudrait pour cela inférer le type de `item`, ce qu'un script qui lit du texte ne fait pas.
Cette moitié-là se vérifie en lisant le code et en regardant une capture. Le contrôle couvre ce
qui est mécanique ; il ne prétend pas couvrir le reste.
"""
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
# Le fichier qui DÉFINIT la règle la contient forcément : c'est son corps.
EXEMPTS = {"Nomme.swift"}

# La composition à la main, dans les formes où elle s'est réellement écrite.
COMPOSITIONS = [
    (re.compile(r'"\\\((\w+\.)?name\) \\\((\w+\.)?(lastName|nomDeFamille|\$0)\)"'),
     "une composition à la main de « prénom nom »"),
    (re.compile(r'\.lastName\.map\s*\{'),
     "un `lastName.map { … }` qui recompose le nom"),
    (re.compile(r'\bname\s*\+\s*" "\s*\+\s*\w*[lL]astName'),
     "une concaténation de `name` et `lastName`"),
]

REDEFINITION = re.compile(r'^\s*var nomComplet\b', re.M)
CONFORMITE = re.compile(r'^(?:extension|struct|final class|class) (\w+)[^\{\n]*\bNomme\b[^\{\n]*\{', re.M)


def corps(texte: str, debut: int) -> str:
    """Le corps d'une déclaration, délimité par ses accolades."""
    profondeur, i = 1, debut
    while profondeur and i < len(texte):
        if texte[i] == "{":
            profondeur += 1
        elif texte[i] == "}":
            profondeur -= 1
        i += 1
    return texte[debut:i - 1]


def main() -> int:
    fautes = []
    for chemin in sorted((RACINE / "RunUp").rglob("*.swift")):
        if chemin.name in EXEMPTS:
            continue
        texte = chemin.read_text(encoding="utf-8")
        relatif = chemin.relative_to(RACINE)

        for motif, quoi in COMPOSITIONS:
            for m in motif.finditer(texte):
                ligne = texte[: m.start()].count("\n") + 1
                fautes.append(
                    f"{relatif}:{ligne} — {quoi}.\n"
                    f"    Écrire `nomComplet` (voir RunUp/Shared/Nomme.swift)."
                )

        for m in REDEFINITION.finditer(texte):
            ligne = texte[: m.start()].count("\n") + 1
            fautes.append(
                f"{relatif}:{ligne} — `nomComplet` redéfini.\n"
                f"    Il vient de `Nomme`, et une version locale gagne sur celle du protocole\n"
                f"    sans qu'aucun avertissement ne le signale."
            )

        for m in CONFORMITE.finditer(texte):
            nom = m.group(1)
            interieur = corps(texte, m.end())
            if "lastName" not in interieur and "nomDeFamille" not in interieur:
                ligne = texte[: m.start()].count("\n") + 1
                fautes.append(
                    f"{relatif}:{ligne} — `{nom}` se déclare `Nomme` sans porter de nom de famille.\n"
                    f"    `nomComplet` y rendrait le prénom seul, pour toujours."
                )

    if fautes:
        print("✗ Le nom de quelqu'un ne s'écrit qu'à un endroit.\n")
        for f in fautes:
            print("  " + f + "\n")
        return 1
    print("✓ Aucune écriture de nom en dehors de `Nomme`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
