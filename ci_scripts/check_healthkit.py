#!/usr/bin/env python3
"""Chaque porte d'entrée de `HealthKitService` doit demander si Santé répond.

POURQUOI CETTE RÈGLE EXISTE.

`HKSource.default()` — appelé deux fois dans ce fichier, pour écarter des sommes du jour ce que
RUNUP a elle-même écrit dans Santé — ne renvoie pas d'erreur Swift quand le binaire tourne sans le
droit `com.apple.developer.healthkit`. Il lève une exception Objective-C, que Swift ne peut pas
rattraper : ni `try`, ni `if let`, ni aucun garde-fou du langage. Le processus meurt sur SIGABRT.

C'est arrivé : les captures d'écran se construisent avec `CODE_SIGNING_ALLOWED=NO`, donc sans
aucun droit, et l'app mourait une seconde après le lancement — avant le premier écran, quatre
exécutions de suite. La parade est `HealthKitService.desactiver()`, un coupe-circuit de processus
que `isHealthDataAvailable` consulte.

Mais un coupe-circuit ne coupe que ce qui passe par lui. Une méthode publique ajoutée demain sans
son garde appellerait `sum(type:unit:on:)`, donc `HKSource.default()`, et tuerait l'app à nouveau
— dans une construction que personne ne regarde, avec un rapport de plantage qu'il faut aller
chercher dans le simulateur. D'où ce test, qui coûte une seconde.

La règle : toute méthode NON privée de `HealthKitService` cite `isHealthDataAvailable`.
"""

import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
FICHIER = RACINE / "RunUp" / "Services" / "HealthKitService.swift"

# Le drapeau que le garde doit consulter, sous l'une ou l'autre de ses écritures.
GARDE = re.compile(r"\bisHealthDataAvailable\b")

# `func nom(` au premier niveau d'indentation de la classe (quatre espaces), sans `private` ni
# `fileprivate` devant. `static` et `nonisolated` sont tolérés entre les deux.
ENTREE = re.compile(r"^    (?:(?:static|nonisolated|final|@\w+)\s+)*func\s+(\w+)\s*\(")
PRIVEE = re.compile(r"^    (?:(?:private|fileprivate)\b.*)func\s+(\w+)\s*\(")

# Le coupe-circuit lui-même. Il ne peut pas se garder : c'est lui qui ferme la porte.
DISPENSEES = {"desactiver"}


def classe(texte, nom):
    """Le corps de la classe `nom`, et lui seul.

    Ce fichier contient aussi `RouteAccumulator`, dont les méthodes n'ont rien à voir avec
    Santé — et dont `add`/`finish` étaient signalées à tort par la première version de ce
    test. Une déclaration de premier niveau se reconnaît à son indentation de quatre espaces,
    peu importe la classe : il faut donc d'abord découper.
    """
    lignes = texte.splitlines()
    debut = next((i for i, l in enumerate(lignes) if re.search(rf"\bclass {nom}\b.*\{{", l)), None)
    if debut is None:
        return None
    # La première accolade seule en colonne zéro referme la classe.
    fin = next((i for i in range(debut + 1, len(lignes)) if lignes[i] == "}"), len(lignes))
    # Les lignes vides du début sont conservées pour que les numéros restent justes.
    return "\n" * debut + "\n".join(lignes[debut:fin])


def corps_des_entrees(texte):
    """[(nom, ligne, corps)] pour chaque méthode non privée de premier niveau.

    Le corps court jusqu'à la prochaine déclaration de même indentation — pas d'analyse
    d'accolades : une méthode qui s'arrête à la suivante suffit pour y chercher un mot, et un
    comptage d'accolades se tromperait sur les chaînes et les commentaires.
    """
    lignes = texte.splitlines()
    debuts = []
    for i, ligne in enumerate(lignes):
        if PRIVEE.match(ligne):
            continue
        if m := ENTREE.match(ligne):
            if m.group(1) in DISPENSEES:
                continue
            debuts.append((m.group(1), i))
    # Toute déclaration de premier niveau ferme la précédente, privée comprise.
    frontieres = [i for i, l in enumerate(lignes)
                  if re.match(r"^    (?:@\w+\s+)*(?:static|private|fileprivate|nonisolated|final|func|var|let)\b", l)]
    sorties = []
    for nom, i in debuts:
        suivantes = [f for f in frontieres if f > i]
        fin = suivantes[0] if suivantes else len(lignes)
        sorties.append((nom, i + 1, "\n".join(lignes[i:fin])))
    return sorties


def sans_garde(texte):
    """Les méthodes non privées de `HealthKitService` qui ne consultent jamais la disponibilité."""
    corps = classe(texte, "HealthKitService")
    if corps is None:
        raise SystemExit("classe HealthKitService introuvable — le test ne peut rien affirmer")
    return [(nom, ligne) for nom, ligne, corps in corps_des_entrees(corps)
            if not GARDE.search(corps)]


def coupe_circuit_present(texte):
    """Le coupe-circuit lui-même : sans lui, le garde ne coupe rien."""
    return ("static func desactiver()" in texte
            and bool(re.search(r"static var isHealthDataAvailable[^\n]*!desactivee", texte)))


def coupe_circuit_tire(racine):
    """Le harnais de captures doit tirer le coupe-circuit, sinon tout ceci est décoratif."""
    app = (racine / "RunUp" / "RunUpApp.swift").read_text(encoding="utf-8")
    return "HealthKitService.desactiver()" in app


def main():
    texte = FICHIER.read_text(encoding="utf-8")

    if not coupe_circuit_present(texte):
        print("Le coupe-circuit a disparu de HealthKitService.", file=sys.stderr)
        print("Il faut `static func desactiver()` ET `isHealthDataAvailable` qui consulte",
              file=sys.stderr)
        print("`!desactivee` — sans les deux, aucun garde ne coupe quoi que ce soit.",
              file=sys.stderr)
        return 1

    if not coupe_circuit_tire(RACINE):
        print("Rien n'appelle plus `HealthKitService.desactiver()`.", file=sys.stderr)
        print("Les captures se construisent sans signature, donc sans droit HealthKit :",
              file=sys.stderr)
        print("sans cet appel, `HKSource.default()` tue le processus au lancement.",
              file=sys.stderr)
        return 1

    if nus := sans_garde(texte):
        print(f"{len(nus)} méthode(s) de HealthKitService n'interrogent jamais Santé avant"
              " de lui parler :\n", file=sys.stderr)
        for nom, ligne in nus:
            print(f"  RunUp/Services/HealthKitService.swift:{ligne}  {nom}(…)", file=sys.stderr)
        print("\nAjoute le premier geste du corps :", file=sys.stderr)
        print("  guard Self.isHealthDataAvailable else { return … }", file=sys.stderr)
        print("\nSans lui, l'appel atteint `HKSource.default()`, qui lève une exception"
              " Objective-C", file=sys.stderr)
        print("quand le binaire n'est pas signé — et Swift ne peut PAS la rattraper.",
              file=sys.stderr)
        return 1

    total = len(corps_des_entrees(classe(texte, "HealthKitService")))
    print(f"HealthKit : coupe-circuit en place et tiré par les captures,")
    print(f"            {total} portes d'entrée, toutes gardées.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
