#!/usr/bin/env python3
"""Un profil de provisionnement porte-t-il bien les capacités que la cible demande ?

# POURQUOI CE CONTRÔLE EXISTE

UN PROFIL EST UNE PHOTO DES CAPACITÉS PRISES LE JOUR DE SA CRÉATION. Cocher une capacité sur
l'identifiant d'app — WeatherKit, HealthKit, App Groups… — ne met à jour AUCUN profil déjà créé.
Il faut les régénérer, les télécharger et remplacer le secret.

Sans ce contrôle, l'oubli se paie douze minutes plus tard, à l'export, par un message d'Apple
qu'on met un moment à relier à la case cochée la veille :

    error: exportArchive Provisioning profile "RunUp App Store"
           doesn't include the com.apple.developer.weatherkit entitlement.

Le même défaut se voit ici en trente secondes, avant la compilation, avec la marche à suivre.

# CE QUI EST COMPARÉ

Les clés du fichier d'entitlements de la cible — celui que XcodeGen fabrique depuis `project.yml`
— contre celles du profil. Seules les capacités qui viennent d'une case du portail sont
regardées : `com.apple.developer.*` et `com.apple.security.*`. Les autres (`application-identifier`,
`get-task-allow`, `aps-environment`) sont posées par Xcode à la signature et n'ont rien à faire
dans un profil.

Seule la PRÉSENCE de la clé compte, pas sa valeur : c'est exactement ce que vérifie `exportArchive`,
et les formes diffèrent légitimement d'un côté à l'autre.

# CE QUE ÇA NE DIT PAS

Qu'un profil est valide, signé par la bonne équipe ou non expiré. Ça, l'export le vérifie déjà, et
son message est clair quand il échoue là-dessus.
"""
import plistlib, sys


def main(argv):
    if len(argv) != 4:
        print("usage: check_profile.py <profil.plist> <cible.entitlements> <nom du profil>",
              file=sys.stderr)
        return 2
    chemin_profil, chemin_demande, nom = argv[1], argv[2], argv[3]

    with open(chemin_profil, "rb") as f:
        profil = plistlib.load(f).get("Entitlements", {})
    with open(chemin_demande, "rb") as f:
        demande = plistlib.load(f)

    interessantes = [k for k in demande
                     if k.startswith("com.apple.developer.")
                     or k.startswith("com.apple.security.")]
    manquantes = [k for k in interessantes if k not in profil]

    if manquantes:
        print(f"::error::Le profil « {nom} » ne porte pas : {', '.join(manquantes)}",
              file=sys.stderr)
        print("::error::Un profil est figé au jour de sa création. Coche la capacité sur "
              "developer.apple.com → Identifiers, PUIS régénère le profil "
              "(Profiles → Edit → Save → Download) et remplace le secret correspondant. "
              "Cocher la case ne met à jour aucun profil déjà créé.", file=sys.stderr)
        return 1

    print(f"    capacités : {len(interessantes)} demandée(s), toutes présentes")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
