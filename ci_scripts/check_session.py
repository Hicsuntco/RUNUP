#!/usr/bin/env python3
"""Le client et le serveur doivent nommer l'en-tête de renouvellement pareil.

# POURQUOI CE CONTRÔLE EXISTE

Un jeton de session vit trente jours. Passé la moitié, le serveur en joint un neuf à chaque
réponse authentifiée, dans un en-tête ; le client le range, et la session ne s'interrompt jamais
pour quelqu'un qui se sert de l'app.

Ce nom d'en-tête est écrit DEUX FOIS, dans deux langages, dans deux déploiements séparés. S'ils
divergent, rien ne casse de façon visible :

  · le serveur renouvelle consciencieusement, dans un en-tête que personne ne lit ;
  · le client ne voit jamais de jeton neuf, et n'a aucun moyen de savoir qu'il en manquait un ;
  · le jeton expire à trente jours comme avant, et elle se fait déconnecter.

Le symptôme — « on me redemande de me connecter tous les mois » — ne ressemble en rien à sa cause.
C'est la même forme de duplication que `check_events.py` surveille entre le client et le serveur,
et elle échoue de la même manière : en silence.

Le plafond absolu est vérifié au passage. Il est la seule chose qui empêche un jeton volé, dont le
voleur se sert, de se renouveler à l'infini : sans lui, le renouvellement glissant transforme une
fuite de trente jours en fuite définitive. Le retirer doit être un acte délibéré, pas un oubli.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
CLIENT = RACINE / "RunUp" / "Services" / "AuthService.swift"
SERVEUR = RACINE / "lib" / "auth.js"

_CLIENT = re.compile(r'enum SessionRenewal\s*\{\s*static let header\s*=\s*"([^"]+)"')
_SERVEUR = re.compile(r"const RENEWAL_HEADER\s*=\s*'([^']+)'")
_PLAFOND = re.compile(r"const ABSOLUTE_SESSION_DAYS\s*=\s*(\d+)")
_DUREE = re.compile(r"const SESSION_LIFETIME_DAYS\s*=\s*(\d+)")


def entete_client(source):
    trouve = _CLIENT.search(source)
    return trouve.group(1) if trouve else None


def entete_serveur(source):
    trouve = _SERVEUR.search(source)
    return trouve.group(1) if trouve else None


def problemes(source_client, source_serveur):
    """Ce qui ne va pas entre les deux écritures, en français lisible."""
    cote_client = entete_client(source_client)
    cote_serveur = entete_serveur(source_serveur)
    out = []
    if cote_client is None:
        out.append("AuthService.swift n'expose plus `SessionRenewal.header` : ce contrôle ne "
                   "surveille plus rien, corrige-le ou retire-le.")
    if cote_serveur is None:
        out.append("lib/auth.js n'expose plus `RENEWAL_HEADER` : idem.")
    if cote_client and cote_serveur and cote_client != cote_serveur:
        out.append(f"Le client attend « {cote_client} », le serveur envoie « {cote_serveur} ». "
                   f"Personne ne renouvellera rien, et personne ne le verra.")

    plafond = _PLAFOND.search(source_serveur)
    duree = _DUREE.search(source_serveur)
    if not plafond:
        out.append("`ABSOLUTE_SESSION_DAYS` a disparu de lib/auth.js : sans plafond, un jeton "
                   "volé dont on se sert se renouvelle à l'infini.")
    elif duree and int(plafond.group(1)) <= int(duree.group(1)):
        out.append(f"Le plafond ({plafond.group(1)} j) ne dépasse pas la vie d'un jeton "
                   f"({duree.group(1)} j) : plus aucun renouvellement ne peut avoir lieu, "
                   f"la fonctionnalité est éteinte sans que rien ne le dise.")
    return out


def main():
    ennuis = problemes(CLIENT.read_text(encoding="utf-8"), SERVEUR.read_text(encoding="utf-8"))
    if ennuis:
        for e in ennuis:
            print(f"::error::{e}", file=sys.stderr)
        return 1
    entete = entete_client(CLIENT.read_text(encoding="utf-8"))
    print(f"Session : client et serveur s'accordent sur « {entete} », plafond en place.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
