#!/usr/bin/env python3
"""Les trois listes d'étapes de l'inscription disent la même chose.

# LE DÉFAUT QUE CE SCRIPT EMPÊCHE DE REVENIR

L'inscription décrit ses étapes à TROIS endroits : le `switch` qui choisit la vue, celui qui
nomme l'étape pour les statistiques, et celui qui décide si l'on peut la quitter. Insérer une
étape au milieu oblige à décaler les trois. Il a suffi d'en oublier un pour que des écrans
valident les réponses de leur voisin — celui des jours de course laissait passer une semaine à
zéro jour, parce qu'il interrogeait une étape qui répond toujours oui.

Rien ne cassait : ça compilait, les tests passaient, l'écran s'affichait. C'est le propre d'un
nombre recopié.

Ce script vérifie deux choses :

  1. AUCUNE VUE N'ÉCRIT SON PROPRE NUMÉRO. `vm.peutContinuer` lit l'étape courante sur le
     modèle ; `canProceed(fromStep: 5)` dans une vue est le nombre recopié d'origine.
  2. LES TROIS LISTES COUVRENT LES MÊMES INDICES, de 0 à `totalSteps - 1`, chacune avec son
     `default` pour la dernière. Une étape ajoutée à l'une et oubliée dans l'autre est une
     étape qui s'affiche sans se valider, ou qui se valide sans s'afficher.
"""
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
VUES = RACINE / "RunUp/Views/Onboarding"
CONTENEUR = VUES / "OnboardingContainerView.swift"
MODELE = RACINE / "RunUp/ViewModels/OnboardingViewModel.swift"


def sans_commentaires(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def cas_du_switch(source: str, ancre: str):
    """Les indices `case N:` du bloc qui suit `ancre`, et s'il porte un `default`."""
    depart = source.find(ancre)
    if depart == -1:
        return None, False
    # Le bloc s'arrête au prochain `func`/`var` de même niveau — suffisant ici, les trois
    # `switch` visés sont les derniers de leur fonction.
    suite = source[depart:]
    fin = suite.find("\n    }")
    bloc = suite[:fin if fin != -1 else len(suite)]
    indices = set()
    for m in re.finditer(r"case\s+([0-9,\s]+):", bloc):
        for n in re.findall(r"\d+", m.group(1)):
            indices.add(int(n))
    return indices, "default:" in bloc


def problemes(vues=None, conteneur=None, modele=None):
    griefs = []

    # 1. Aucune vue n'écrit son propre numéro.
    if vues is None:
        vues = {f.name: f.read_text(encoding="utf-8") for f in sorted(VUES.glob("*.swift"))}
    for nom, source in vues.items():
        if nom == "OnboardingContainerView.swift":
            continue
        for m in re.finditer(r"canProceed\(fromStep:\s*(\d+)\)", sans_commentaires(source)):
            griefs.append(
                f"{nom} écrit son numéro d'étape en dur : `canProceed(fromStep: {m.group(1)})`.\n"
                f"      Une étape insérée avant elle rendra ce nombre faux en silence, et "
                f"l'écran\n      validera les réponses de son voisin. `vm.peutContinuer`."
            )

    conteneur = conteneur if conteneur is not None else CONTENEUR.read_text(encoding="utf-8")
    modele = modele if modele is not None else MODELE.read_text(encoding="utf-8")
    c, m = sans_commentaires(conteneur), sans_commentaires(modele)

    total = re.search(r"totalSteps\s*=\s*(\d+)", m)
    if not total:
        return griefs + ["`totalSteps` est introuvable — le script ne vérifie plus rien."]
    attendu = set(range(int(total.group(1)) - 1))  # la dernière étape passe par `default`

    listes = {
        "l'aiguillage des vues": cas_du_switch(c, "private var currentStep"),
        "le nom d'étape des statistiques": cas_du_switch(c, "private func stepName"),
        "la validation": cas_du_switch(m, "func canProceed"),
    }
    for nom, (indices, defaut) in listes.items():
        if indices is None:
            griefs.append(f"{nom} : bloc introuvable — le script ne vérifie plus rien.")
            continue
        manquants = sorted(attendu - indices)
        if manquants:
            griefs.append(
                f"{nom} ne traite pas l'étape {', '.join(map(str, manquants))}, "
                f"alors que `totalSteps` l'annonce."
            )
        if not defaut:
            griefs.append(f"{nom} n'a pas de `default` pour la dernière étape.")
    return griefs


def main() -> int:
    griefs = problemes()
    if griefs:
        print(f"{len(griefs)} incohérence(s) dans les étapes de l'inscription :\n")
        for g in griefs:
            print(f"  • {g}\n")
        return 1
    print("Étapes : les trois listes couvrent les mêmes indices, "
          "et aucune vue n'écrit son numéro.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
