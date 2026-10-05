#!/usr/bin/env python3
"""Les demandes d'autorisation sont-elles écrites dans toutes les langues livrées ?

# POURQUOI CE CONTRÔLE EXISTE

Apple a renvoyé ceci sur la build 1158, APRÈS un envoi réussi :

    ITMS-90738: Invalid purpose string value — The "NSContactsUsageDescription" value for
    the NSContactsUsageDescription key isn't allowed in "fr.lproj".

Traduction : en français, la phrase affichée à quelqu'un à qui l'on demande l'accès à son
carnet d'adresses était « NSContactsUsageDescription ». Le nom de la clé, en toutes lettres,
dans le dialogue système.

# COMMENT C'EST ARRIVÉ

`project.yml` contenait la bonne phrase française. Mais `InfoPlist.xcstrings` TRADUIT ces clés,
et un catalogue de chaînes ÉCRASE l'Info.plist pour chaque langue qu'il déclare. La clé des
contacts y avait `en` et `es` — ajoutées en même temps que la fonctionnalité — et pas `fr`,
pourtant la langue source. Xcode a donc écrit un `fr.lproj` dont la valeur est la clé.

Rien ne pouvait le signaler avant Apple : l'app compile, les tests passent, l'envoi réussit, et
le dialogue ne s'affiche qu'au moment où quelqu'un ouvre la recherche de contacts. Sur un
appareil en anglais — celui du développeur comme celui du simulateur de CI — il est parfait.

# CE QUI EST VÉRIFIÉ

1. Toute clé du catalogue porte TOUTES les langues que le catalogue connaît, la source comprise.
2. Aucune valeur n'est vide, ni égale à sa propre clé — c'est exactement ce qu'Apple refuse.
3. Aucune valeur n'est trop courte pour expliquer quoi que ce soit : Apple refuse aussi les
   phrases qui ne disent rien, et « Accès aux contacts » n'est pas une raison.
4. Les clés déclarées dans `project.yml` et celles du catalogue sont les mêmes des deux côtés.
   Une clé ajoutée à l'Info.plist sans entrée au catalogue reste en français pour tout le monde ;
   une entrée de catalogue sans clé d'Info.plist est du texte traduit que personne ne verra.
"""
import json, pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE = RACINE / "RunUp" / "Resources" / "InfoPlist.xcstrings"
PROJET = RACINE / "project.yml"
CIBLE = "RunUp"
# En dessous, une phrase n'explique rien. Le seuil est bas exprès : il attrape « Contacts » et
# « Accès micro », pas une formulation courte mais réelle.
LONGUEUR_MINIMALE = 25


def cles_declarees() -> set:
    """Les `NS*UsageDescription` de l'Info.plist de la cible, lues dans `project.yml`.

    À la main plutôt qu'avec PyYAML : les autres scripts de `ci_scripts/` ne dépendent que de la
    bibliothèque standard, et rien ne garantit PyYAML sur le Python système d'un runner macOS. Un
    contrôle qui ne peut pas tourner ne protège de rien.

    La montre a ses propres phrases, à son propre niveau d'indentation. On ne lit donc que le bloc
    de la cible demandée — sinon `NSHealthShareUsageDescription` serait comptée deux fois, avec
    deux textes différents.
    """
    lignes = PROJET.read_text(encoding="utf-8").splitlines()
    debut = next((i for i, l in enumerate(lignes) if l.rstrip() == f"  {CIBLE}:"), None)
    if debut is None:
        sys.exit(f"Cible « {CIBLE} » introuvable dans project.yml")
    cles = set()
    for ligne in lignes[debut + 1:]:
        # Fin du bloc : la cible suivante, au même niveau d'indentation.
        if ligne.strip() and not ligne.startswith("    ") and ligne.startswith("  "):
            break
        m = re.match(r"\s+(NS\w+UsageDescription)\s*:", ligne)
        if m:
            cles.add(m.group(1))
    return cles


def main() -> int:
    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    source = catalogue.get("sourceLanguage", "fr")
    chaines = catalogue["strings"]

    # Les langues livrées = celles que le catalogue connaît, plus la source. Déduites plutôt
    # qu'écrites en dur : le jour où une quatrième langue arrive, ce contrôle la réclame tout seul.
    langues = {source}
    for entree in chaines.values():
        langues |= set(entree.get("localizations", {}))

    erreurs = []
    for cle in sorted(chaines):
        locs = chaines[cle].get("localizations", {})
        for langue in sorted(langues):
            unite = locs.get(langue, {}).get("stringUnit", {})
            valeur = (unite.get("value") or "").strip()
            if not valeur:
                erreurs.append(f"{cle} — rien en « {langue} ». Xcode écrira le NOM DE LA CLÉ "
                               f"dans {langue}.lproj, et Apple refuse (ITMS-90738).")
            elif valeur == cle:
                erreurs.append(f"{cle} — la valeur en « {langue} » EST la clé.")
            elif len(valeur) < LONGUEUR_MINIMALE:
                erreurs.append(f"{cle} — « {langue} » ne fait que {len(valeur)} caractères "
                               f"({valeur!r}) : ça n'explique pas pourquoi l'app demande l'accès.")

    declarees = cles_declarees()
    traduites = set(chaines)
    for cle in sorted(declarees - traduites):
        erreurs.append(f"{cle} est dans l'Info.plist de {CIBLE} mais pas dans le catalogue : "
                       f"elle restera en {source} dans toutes les langues.")
    for cle in sorted(traduites - declarees):
        erreurs.append(f"{cle} est traduite dans le catalogue mais absente de l'Info.plist de "
                       f"{CIBLE} : personne ne verra jamais cette phrase.")

    if erreurs:
        for e in erreurs:
            print(f"::error::{e}", file=sys.stderr)
        print(f"::error::Voir ci_scripts/check_infoplist.py pour ce que ces phrases deviennent "
              f"quand elles manquent.", file=sys.stderr)
        return 1

    print(f"Autorisations : {len(chaines)} demande(s), "
          f"{len(langues)} langue(s) ({', '.join(sorted(langues))}), toutes écrites.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
