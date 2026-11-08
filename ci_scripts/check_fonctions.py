#!/usr/bin/env python3
"""Douze fonctions serverless, pas treize.

# POURQUOI CE CONTRÔLE EXISTE

Vercel compte UN fichier sous `api/` = UNE fonction serverless, et le plan Hobby en autorise
douze. Le treizième ne dégrade rien : il fait échouer TOUT déploiement production, avec

    No more than 12 Serverless Functions can be added to a Deployment on the Hobby plan.

Ce défaut est arrivé DEUX FOIS dans ce dépôt, et les deux fois il a coûté du temps parce qu'il
n'a aucun symptôme du côté où l'on regarde :

  · à l'ajout de l'analytique, `api/events.js` a été le treizième fichier. L'en-tête
    d'`api/account/[action].js` raconte la panne et le regroupement qui l'a réparée ;
  · le 8 novembre 2026, `api/crashes.js` a été le treizième. Les quatre chaînes étaient VERTES —
    TestFlight compris — parce qu'aucune ne déploie : c'est l'intégration Git de Vercel qui
    déploie, et elle échoue ailleurs. Ce qui l'a établi n'est pas un journal de construction mais
    une mesure : la production servait encore l'ANCIEN `privacy.html`, donc le déploiement entier
    n'avait pas eu lieu.

Un déploiement qui n'a pas lieu laisse l'ancienne version servir. L'app continue de marcher, les
tests restent verts, et tout ce qu'on vient d'écrire n'existe nulle part.

# CE QUI EST COMPTÉ

Les fichiers `.js` sous `api/`, récursivement. Un `[action].js` compte pour UN, quel que soit le
nombre d'actions derrière — c'est précisément pourquoi sept domaines de ce serveur sont écrits
sous cette forme.

Ce qui ne compte pas : `lib/`, les réécritures de `vercel.json`, les fichiers statiques. D'où la
sortie de secours quand le plafond est atteint — mettre le gestionnaire dans `lib/` et le faire
appeler par une route existante, ou le regrouper derrière un `[action].js`. Les deux gardent
l'URL publique intacte, donc n'affectent aucune version de l'app déjà installée.

# LE PLAFOND EST CELUI DU PLAN, PAS UNE PRÉFÉRENCE

Douze est la limite du plan Hobby. Passer en Pro la lève — c'est une décision de dépense, pas une
décision technique, et elle n'appartient pas à ce script. Tant que le plan est Hobby, treize
fichiers veut dire zéro déploiement.
"""
import pathlib
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
API = RACINE / "api"

#: Le plafond du plan Hobby, cité mot pour mot dans le message d'erreur de Vercel.
PLAFOND = 12


def fonctions():
    return sorted(f.relative_to(RACINE).as_posix() for f in API.rglob("*.js"))


def main():
    if not API.is_dir():
        print(f"{API} n'existe pas — l'analyse a échoué, pas le code.")
        return 1

    liste = fonctions()
    if not liste:
        print(f"Aucune fonction sous {API.name}/ — l'analyse a échoué, pas le code.")
        return 1

    if len(liste) > PLAFOND:
        print(f"{len(liste)} fonctions serverless sous api/, et le plan Hobby en autorise "
              f"{PLAFOND} :\n")
        for nom in liste:
            print(f"  · {nom}")
        print("\n    Vercel refusera le déploiement entier, avec cette phrase :\n")
        print(f"      No more than {PLAFOND} Serverless Functions can be added to a Deployment "
              "on the Hobby plan.\n")
        print("    Rien ne rougira ici : l'ancienne version continuera de servir, les quatre")
        print("    chaînes resteront vertes, et le code qu'on vient d'écrire n'existera nulle")
        print("    part.")
        print("\n    Deux sorties, qui gardent toutes deux l'URL publique intacte :")
        print("      · mettre le gestionnaire dans `lib/` et le faire appeler par une route")
        print("        existante, avec une réécriture dans `vercel.json` pour l'adresse ;")
        print("      · le regrouper derrière un routeur `[action].js`, comme `activities`,")
        print("        `clubs`, `auth`, `account`, `friends`, `moderation`, `races` et `strava`.")
        return 1

    reste = PLAFOND - len(liste)
    marge = "aucune place libre" if reste == 0 else f"{reste} place(s) libre(s)"
    print(f"Fonctions serverless : {len(liste)} sur {PLAFOND}, {marge}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
