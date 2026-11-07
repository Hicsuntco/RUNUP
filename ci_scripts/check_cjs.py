#!/usr/bin/env python3
"""Aucune dépendance du serveur ne doit être chargée par `require` si elle n'est livrée qu'en ESM.

# LA PANNE QUI A FAIT ÉCRIRE CE CONTRÔLE

Le 7 novembre 2026, `jose` est passé de 5 à 6. La construction Vercel a été verte, les 133 tests
serveur verts, et **toutes les routes de l'API ont répondu 500 pendant onze minutes** :
`FUNCTION_INVOCATION_FAILED`, c'est-à-dire une fonction qui meurt au chargement de ses modules,
avant son propre traitement d'erreur.

`jose` 6 n'est livré qu'en ESM. `require('jose')` fonctionne quand même — mais seulement sur les
versions de Node où `require(esm)` est actif par défaut (^20.19 || ^22.12 || >= 23). La machine
des tests est sur Node 22 : elle ne pouvait pas voir le défaut. Et la version de Node qui exécute
les fonctions vit dans les réglages du projet Vercel, **hors du dépôt** : elle ne se lit pas
d'ici, et aucun test ne peut la deviner.

Donc la règle n'est pas « est-ce que ça marche sur cette machine ». La règle est : une dépendance
chargée par `require` doit être livrée en CommonJS, point. Sinon elle marche ici et peut tomber en
ligne, et la différence ne se voit qu'une fois en ligne.

# CE QUI EST REGARDÉ

Les `require('paquet')` de `api/` et `lib/` — les modules du cœur de Node exclus. Pour chacun, le
`package.json` du paquet installé dans `node_modules` :

  · `"type": "module"` et un `exports` qui ne propose AUCUNE condition `require` → refusé ;
  · `exports` avec une condition `require`, ou pas de `"type": "module"` → accepté.

Il faut donc que `npm ci` soit passé : sans `node_modules`, ce contrôle ne sait rien et le dit
plutôt que de rendre un vert vide.
"""
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ("api", "lib")
REQUIRE = re.compile(r"""require\(\s*['"]([^'".][^'"]*)['"]\s*\)""")

#: Les modules du cœur de Node, qui n'ont pas de `package.json` à lire.
COEUR = {
    "assert", "buffer", "child_process", "crypto", "dns", "events", "fs", "http", "http2",
    "https", "net", "os", "path", "querystring", "stream", "string_decoder", "timers", "tls",
    "url", "util", "zlib",
}


def paquets_requis() -> dict:
    """paquet → les fichiers qui le chargent par `require`."""
    trouves: dict[str, list[str]] = {}
    for dossier in DOSSIERS:
        base = RACINE / dossier
        if not base.is_dir():
            raise SystemExit(f"Le dossier « {dossier} » n'existe pas : ce contrôle ne relit pas "
                             f"ce qu'il annonce.")
        for chemin in sorted(base.rglob("*.js")):
            for nom in REQUIRE.findall(chemin.read_text(encoding="utf-8")):
                if nom.startswith(".") or nom.startswith("node:") or nom in COEUR:
                    continue
                # `@echelle/paquet/sous-chemin` → le paquet, sans le sous-chemin.
                morceaux = nom.split("/")
                paquet = "/".join(morceaux[:2]) if nom.startswith("@") else morceaux[0]
                trouves.setdefault(paquet, []).append(str(chemin.relative_to(RACINE)))
    return trouves


def propose_require(fiche: dict) -> bool:
    """Le paquet offre-t-il un chemin CommonJS ?"""
    if fiche.get("type") != "module":
        return True
    exports = fiche.get("exports")
    if exports is None:
        # `"type": "module"` sans `exports` : `main` est chargé comme un module ESM.
        return False

    def cherche(noeud) -> bool:
        if isinstance(noeud, dict):
            if "require" in noeud:
                return True
            return any(cherche(v) for v in noeud.values())
        return False

    return cherche(exports)


def main() -> int:
    requis = paquets_requis()
    if not requis:
        print("Aucune dépendance chargée par `require` : rien à vérifier.")
        return 0

    fautes = []
    absents = []
    for paquet, fichiers in sorted(requis.items()):
        fiche_chemin = RACINE / "node_modules" / paquet / "package.json"
        if not fiche_chemin.is_file():
            absents.append(paquet)
            continue
        fiche = json.loads(fiche_chemin.read_text(encoding="utf-8"))
        etat = "CommonJS" if propose_require(fiche) else "ESM SEUL"
        print(f"  {etat:10} {paquet} {fiche.get('version', '?')}")
        if etat == "ESM SEUL":
            fautes.append((paquet, fiche.get("version", "?"), sorted(set(fichiers))))

    if absents:
        print(f"\n{len(absents)} paquet(s) introuvable(s) dans node_modules "
              f"({', '.join(absents)}) : lancer `npm ci` d'abord. Sans eux, ce contrôle "
              f"rendrait un vert qui ne mesure rien.", file=sys.stderr)
        return 1

    if fautes:
        print(f"\n{len(fautes)} dépendance(s) chargée(s) par `require` ne sont livrées qu'en "
              f"ESM :\n", file=sys.stderr)
        for paquet, version, fichiers in fautes:
            print(f"  {paquet} {version} — {', '.join(fichiers)}", file=sys.stderr)
        print("\nÇa fonctionne sur cette machine, et ça peut tomber en ligne : `require` d'un",
              file=sys.stderr)
        print("module ESM n'est actif par défaut que sur Node ^20.19, ^22.12 ou >= 23, et la",
              file=sys.stderr)
        print("version de Node qui exécute les fonctions est un réglage du projet Vercel, hors",
              file=sys.stderr)
        print("du dépôt. C'est exactement ce qui a mis l'API à terre onze minutes le 7 novembre",
              file=sys.stderr)
        print("2026 — construction verte, 133 tests verts, toutes les routes en 500.",
              file=sys.stderr)
        print("\nSoit on reste sur une version livrée en CommonJS, soit on charge le paquet par",
              file=sys.stderr)
        print("`await import(...)`, qui ne dépend d'aucune version.", file=sys.stderr)
        return 1

    print(f"\nLes {len(requis)} dépendances chargées par `require` sont livrées en CommonJS ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
