#!/usr/bin/env python3
"""Aucun écran n'affirme une panne de réseau de son propre chef.

# LE DÉFAUT QUE CE CONTRÔLE FERME

Trois services — le Club, l'authentification, le coach — portent chacun leur propre énumération
d'erreurs, avec les mêmes formes : `network`, `badResponse(code, corps)`, et une panne de session.
Onze écrans attrapaient tout ça par un `catch` nu ou un `try?`, puis affichaient la même phrase :
« vérifie ta connexion ».

Ces trois pannes ont des remèdes opposés — se reconnecter, attendre, changer d'endroit — et
« vérifie ta connexion » est la pire des trois à deviner, parce que c'est la seule que la personne
peut vérifier d'un coup d'œil. Affichée sur un téléphone au wifi plein, elle n'apprend rien sur la
panne et beaucoup sur l'app.

`PanneReseau` classe la cause et rend la bonne phrase. Mais un écran écrit demain n'a aucune raison
de penser à la distinction : rien, dans le compilateur, n'empêche de retaper la phrase à la main.
C'est ce contrôle-là qui l'empêche.

# CE QUI EST AUTORISÉ, ET POURQUOI

`PanneReseau` lui-même, évidemment : c'est lui qui a le droit de le dire, parce que c'est lui qui
le sait. Et `RestoreOutcome`, dont le cas `couldNotCheck` naît d'un échec de synchronisation
StoreKit — là, l'absence de réseau est bien la cause, elle est modélisée, et `RestoreOutcomeTests`
la tient.

Le littéral est lu par `check_strings.lire_litteral` et non par une expression régulière : une
interpolation peut contenir sa propre chaîne, et un motif naïf s'arrête sur le guillemet intérieur.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_strings as ck  # noqa: E402

# Les tournures qui AFFIRMENT une panne de réseau. Des tournures et non le mot « connexion » seul :
# « Connexion » est aussi le titre de l'écran de connexion, et « Se connecter » un bouton.
CLAMEURS = [
    "vérifie ta connexion",
    "vérifie ton réseau",
    "vérifiez votre connexion",
    "connexion internet",
    "connexion coupée",
    "pas de connexion",
    "sans connexion",
    "hors ligne",
    "du réseau",
]

# Les deux seuls fichiers qui ont le droit de nommer le réseau. Voir l'en-tête.
AUTORISES = {
    "RunUp/Services/PanneReseau.swift",
    "RunUp/Models/RestoreOutcome.swift",
}


def fautes():
    trouvees = []
    for dossier in ck.DOSSIERS:
        racine = ck.RACINE / dossier
        if not racine.exists():
            continue
        for f in sorted(racine.rglob("*.swift")):
            rel = str(f.relative_to(ck.RACINE))
            if rel in AUTORISES:
                continue
            for n, ligne in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                nue = ligne.strip()
                if nue.startswith("//"):
                    continue
                for appel in ck.OUVERTURES:
                    for m in appel.finditer(ligne):
                        lu = ck.lire_litteral(ligne, m.end())
                        if lu is None:
                            continue
                        cle = ck.deswiftifie(lu[0]).lower()
                        for clameur in CLAMEURS:
                            if clameur in cle:
                                trouvees.append((f"{rel}:{n}", clameur, ck.deswiftifie(lu[0])))
    return trouvees


def main() -> int:
    mauvaises = fautes()
    if not mauvaises:
        print(f"Réseau : {len(ck.DOSSIERS)} arborescences lues, aucun écran n'invente de panne de réseau.")
        print("         La cause vient de `PanneReseau`, qui est le seul à la connaître.")
        return 0

    print(f"{len(mauvaises)} chaîne(s) affirment une panne de réseau sans la connaître :\n", file=sys.stderr)
    for ou, clameur, texte in mauvaises:
        court = texte if len(texte) <= 70 else texte[:67] + "…"
        print(f"  {ou}\n      « {court} »\n      → « {clameur} »", file=sys.stderr)
    print("\nCes trois pannes ont des remèdes opposés : se reconnecter, attendre, changer", file=sys.stderr)
    print("d'endroit. L'erreur sait laquelle c'est ; l'écran ne peut que le supposer.", file=sys.stderr)
    print("Utilise `PanneReseau.phrase(pour: error)`, ou `PanneReseau.motif(pour: error)`", file=sys.stderr)
    print("quand la phrase est déjà commencée.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
