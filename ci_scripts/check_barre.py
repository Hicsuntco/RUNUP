#!/usr/bin/env python3
"""Les libellés de la barre du bas tiennent-ils, à la taille de texte par défaut ?

# LA PANNE, DEUX FOIS

La barre d'onglets a une hauteur FIXE — `RUSpacing.tabBarHeight`, la même constante que l'encart
que chaque écran réserve en bas pour ne pas passer dessous. Une barre qui grandirait avec le
texte recouvrirait donc le contenu. C'est le contenu qui doit céder, et il cède par un
`ViewThatFits` : si la barre complète ne tient pas dans sa hauteur, les libellés disparaissent.

D'où un défaut sans symptôme intermédiaire. Au build 270, le plus haut des cinq éléments mesurait
56,2 points dans une barre de 56 : il manquait DEUX DIXIÈMES de point, et le mot « RUN » n'était
plus affiché pour personne. Rien ne débordait, rien n'était rogné, rien ne plantait — le mot
n'était simplement plus là. Trois tours ont été nécessaires pour le voir.

# CE QUE LE SCRIPT REFAIT

L'addition, depuis les constantes elles-mêmes :

    libellé  = micro × bodySizeFactor × hauteur de ligne
    onglet   = point + écart + icône + écart + libellé
    bouton   = rond + écart + libellé

Le plus grand des deux doit tenir dans `tabBarHeight` AVEC DE LA MARGE. Pas « tenir tout juste » :
une marge, parce que la hauteur de ligne exacte d'Inter à 10,6 points n'est connue ni de ce
script ni de personne qui additionne de tête, et que c'est précisément cet écart-là qui a fait
disparaître le mot.

# POURQUOI LA MARGE EST CE QU'ELLE EST

`MARGE_MINIMALE` vaut deux points, et `LIGNE` majore la hauteur de ligne à 1,30 × la taille de
police — Inter tourne autour de 1,21, donc l'estimation est volontairement pessimiste. Les deux
ensemble disent : le calcul doit rester juste même si l'on s'est trompé de 7 % sur une métrique
de fonte.
"""
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
BARRE = RACINE / "RunUp/Views/Components/TabBarView.swift"
ESPACEMENT = RACINE / "RunUp/DesignSystem/Spacing.swift"
TYPO = RACINE / "RunUp/DesignSystem/Typography.swift"

# Majorant de la hauteur de ligne d'Inter, en multiples de la taille de police.
LIGNE = 1.30
MARGE_MINIMALE = 2.0


def nombre(source: str, motif: str, quoi: str, griefs: list):
    """La valeur d'une constante nommée, ou un grief si elle est introuvable.

    Un script qui rendrait zéro sur une constante disparue passerait en silence — c'est-à-dire
    échouerait exactement comme la barre qu'il surveille.
    """
    m = re.search(motif, source)
    if not m:
        griefs.append(f"`{quoi}` est introuvable : le script ne peut plus refaire l'addition.")
        return None
    return float(m.group(1))


def mesures(sources=None):
    """(constantes, griefs). `sources` : (barre, espacement, typo) — pour les tests."""
    griefs = []
    if sources is None:
        sources = (BARRE.read_text(encoding="utf-8"),
                   ESPACEMENT.read_text(encoding="utf-8"),
                   TYPO.read_text(encoding="utf-8"))
    barre, espacement, typo = sources

    c = {
        "hauteur": nombre(espacement, r"static let tabBarHeight:\s*CGFloat\s*=\s*([\d.]+)",
                          "RUSpacing.tabBarHeight", griefs),
        "facteur": nombre(typo, r"bodySizeFactor:\s*CGFloat\s*=\s*([\d.]+)",
                          "RUFont.bodySizeFactor", griefs),
        "micro": nombre(typo, r"case micro\s*=\s*([\d.]+)", "RUTextSize.micro", griefs),
        "rond": nombre(barre, r"diametreDuRond:\s*CGFloat\s*=\s*([\d.]+)",
                       "TabBarView.diametreDuRond", griefs),
        "icone": nombre(barre, r"cotesDeLIcone:\s*CGFloat\s*=\s*([\d.]+)",
                        "TabBarView.cotesDeLIcone", griefs),
        "point": nombre(barre, r"diametreDuPoint:\s*CGFloat\s*=\s*([\d.]+)",
                        "TabBarView.diametreDuPoint", griefs),
        "ecartPile": nombre(barre, r"ecartDeLaPile:\s*CGFloat\s*=\s*([\d.]+)",
                            "TabBarView.ecartDeLaPile", griefs),
        "ecartBouton": nombre(barre, r"ecartDuBouton:\s*CGFloat\s*=\s*([\d.]+)",
                              "TabBarView.ecartDuBouton", griefs),
    }
    return c, griefs


def piles(c):
    """(hauteur d'un onglet, hauteur du bouton central, hauteur du libellé)."""
    libelle = c["micro"] * c["facteur"] * LIGNE
    onglet = c["point"] + c["ecartPile"] + c["icone"] + c["ecartPile"] + libelle
    bouton = c["rond"] + c["ecartBouton"] + libelle
    return onglet, bouton, libelle


def problemes(sources=None):
    c, griefs = mesures(sources)
    if griefs:
        return griefs

    onglet, bouton, libelle = piles(c)
    plus_haut = max(onglet, bouton)
    marge = c["hauteur"] - plus_haut
    if marge < MARGE_MINIMALE:
        qui = "le bouton central" if bouton >= onglet else "un onglet"
        griefs.append(
            f"Les libellés de la barre ne tiennent plus : {qui} mesure {plus_haut:.1f} pt dans "
            f"une barre de {c['hauteur']:.0f}, soit {marge:.1f} pt de marge (minimum "
            f"{MARGE_MINIMALE:.0f}).\n"
            f"      onglet = {c['point']:.0f} + {c['ecartPile']:.0f} + {c['icone']:.0f} + "
            f"{c['ecartPile']:.0f} + {libelle:.1f} = {onglet:.1f}\n"
            f"      bouton = {c['rond']:.0f} + {c['ecartBouton']:.0f} + {libelle:.1f} = {bouton:.1f}\n"
            f"      Les libellés ne déborderont PAS : ils disparaîtront, sans rien signaler.\n"
            f"      Voir `TabBarView.diametreDuRond`."
        )
    return griefs


def main() -> int:
    griefs = problemes()
    if griefs:
        print("La barre du bas ne tient plus ses libellés :\n")
        for g in griefs:
            print(f"  • {g}\n")
        return 1
    c, _ = mesures()
    onglet, bouton, _ = piles(c)
    marge = c["hauteur"] - max(onglet, bouton)
    print(f"Barre du bas : le plus haut des cinq éléments mesure {max(onglet, bouton):.1f} pt "
          f"dans {c['hauteur']:.0f}, soit {marge:.1f} pt de marge.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
