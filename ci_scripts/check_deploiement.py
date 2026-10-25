#!/usr/bin/env python3
"""Toute route que l'app appelle existe-t-elle VRAIMENT en production ?

# LE DÉFAUT QUE CE CONTRÔLE FERME

Le workflow « Serveur » ne déploie rien : il lance `npm test`, et c'est tout. Son petit rond vert
dit « les tests passent », pas « c'est en ligne » — le déploiement, lui, est fait par
l'intégration Git de Vercel, en dehors du dépôt et sans rien rapporter ici.

Les deux se ressemblent assez pour qu'on confonde. La fonctionnalité des pages de course est
partie avec ses tests verts, son workflow vert, et `api/races/*` répondait 404 en production :
une app installée affichait « Impossible de charger les courses » sur un écran annoncé comme
terminé. Rien, nulle part, ne l'avait dit.

# CE QUI EST REGARDÉ

Les chemins que l'app appelle vraiment, lus dans `RunUp/Services/*.swift` — pas une liste tenue
à la main, qui aurait divergé au premier ajout.

# CE QUI COMPTE COMME « EXISTE »

Tout sauf 404. Une route protégée répond 401 sans jeton, une route POST répond 405 sur un GET :
les deux prouvent qu'une fonction est là. Seul 404 veut dire « rien n'est déployé à cette
adresse ». On ne cherche donc pas à authentifier quoi que ce soit — il n'y a aucun secret ici, et
ce contrôle n'en demande aucun.
"""
import argparse
import concurrent.futures
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

RACINE = pathlib.Path(__file__).resolve().parent.parent
SERVICES = RACINE / "RunUp/Services"

# L'URL de production, lue là où l'app la porte plutôt que recopiée ici : une copie qui dérive
# ferait contrôler le mauvais serveur, et personne ne s'en apercevrait.
BASE = re.compile(r'baseURL\s*=\s*URL\(string:\s*"([^"]+)"')
CHEMIN = re.compile(r'path:\s*"(api/[^"]+)"')
# `api/coach` est appelé par une URL entière, pas par `path:` — il est réel et doit être couvert.
URL_ENTIERE = re.compile(r'"(https://[^"]*/api/[^"]+)"')

DELAI = 25


def base_de_production() -> str:
    for fichier in sorted(SERVICES.glob("*.swift")):
        if trouve := BASE.search(fichier.read_text(encoding="utf-8")):
            return trouve.group(1).rstrip("/")
    sys.exit("Aucune `baseURL` trouvée dans RunUp/Services : le contrôle ne sait pas qui interroger.")


def adresses() -> list:
    """Chaque adresse une fois, dans l'ordre alphabétique."""
    vues = set()
    for dossier in (SERVICES, RACINE / "RunUp"):
        for fichier in sorted(dossier.rglob("*.swift")):
            texte = fichier.read_text(encoding="utf-8")
            for m in CHEMIN.finditer(texte):
                vues.add(m.group(1))
            for m in URL_ENTIERE.finditer(texte):
                vues.add(m.group(1))
    return sorted(vues)


def code(url: str) -> int:
    requete = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(requete, timeout=DELAI) as reponse:
            return reponse.status
    except urllib.error.HTTPError as erreur:
        return erreur.code
    except Exception:
        # Une panne de réseau n'est pas un défaut de déploiement : on la distingue, et elle
        # n'accuse personne.
        return 0


def sonder(base: str, liste: list) -> list:
    def verifier(chemin: str):
        url = chemin if chemin.startswith("http") else f"{base}/{chemin}"
        return chemin, code(url)

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        return list(pool.map(verifier, liste))


def main() -> int:
    arguments = argparse.ArgumentParser(description=__doc__)
    # LE DÉPLOIEMENT COURT APRÈS LE PUSH, PAS AVANT.
    #
    # Vercel construit quand GitHub lui annonce le commit — donc pendant que ce workflow tourne.
    # Sonder une seule fois, tout de suite, accuserait un déploiement parfaitement en route. On
    # laisse donc une fenêtre, et on s'arrête à la première ronde complète.
    arguments.add_argument("--patience", type=int, default=0,
                           help="secondes pendant lesquelles réessayer avant de conclure")
    options = arguments.parse_args()

    base = base_de_production()
    liste = adresses()
    if not liste:
        sys.exit("Aucun appel d'API trouvé : le contrôle regarderait dans le vide.")

    print(f"Production : {base}")
    print(f"{len(liste)} adresse(s) appelée(s) par l'app\n")

    limite = time.monotonic() + max(0, options.patience)
    tour = 0
    while True:
        tour += 1
        resultats = sonder(base, liste)
        if not [c for c, statut in resultats if statut == 404] or time.monotonic() >= limite:
            break
        reste = int(limite - time.monotonic())
        print(f"  … des routes manquent encore (tour {tour}) — nouvelle tentative, {reste} s de patience")
        time.sleep(15)

    absentes = [c for c, statut in resultats if statut == 404]
    injoignables = [c for c, statut in resultats if statut == 0]

    for chemin, statut in resultats:
        marque = "✗" if statut == 404 else ("?" if statut == 0 else "·")
        print(f"  {marque} {statut or '—'}  {chemin}")

    if injoignables:
        print(f"\n{len(injoignables)} adresse(s) injoignable(s) — réseau, pas déploiement.",
              file=sys.stderr)

    if absentes:
        print(f"\n{len(absentes)} route(s) que l'app appelle N'EXISTENT PAS en production :\n",
              file=sys.stderr)
        for chemin in absentes:
            print(f"  {chemin}", file=sys.stderr)
        print("\nL'app installée affichera une erreur sur les écrans concernés. Le workflow",
              file=sys.stderr)
        print("« Serveur » ne déploie RIEN — il lance les tests. Le déploiement est fait par",
              file=sys.stderr)
        print("l'intégration Git de Vercel : va voir l'onglet Deployments du projet, le dernier",
              file=sys.stderr)
        print("build a probablement échoué ou n'a jamais été déclenché.", file=sys.stderr)
        return 1

    print(f"\nDéploiement : les {len(liste)} routes appelées par l'app répondent ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
