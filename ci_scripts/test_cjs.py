#!/usr/bin/env python3
"""Les cas de `check_cjs.py`, sur des fiches de paquet écrites exprès.

Le défaut que ce contrôle cherche est celui du 7 novembre 2026 : une dépendance livrée en ESM
seul, chargée par `require`, qui marche sur la machine des tests et tombe en ligne. Ce qui est
éprouvé ici, c'est d'abord ce qu'il doit LAISSER PASSER — les quatre dépendances réelles du
serveur en sont, et un faux positif bloquerait toute montée de version.
"""
import pathlib
import sys

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_cjs as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


# ── Ce qui offre un chemin CommonJS ───────────────────────────────────────────────────────────

@cas_de("un paquet sans `type` est du CommonJS")
def _():
    assert ck.propose_require({"main": "index.js"})


@cas_de("`type: commonjs` aussi")
def _():
    assert ck.propose_require({"type": "commonjs", "main": "index.js"})


@cas_de("un paquet ESM qui garde une condition `require` passe")
def _():
    # C'est la forme de `bcryptjs` 3 : ESM pour `import`, UMD pour `require`.
    assert ck.propose_require({"type": "module", "exports": {
        ".": {"import": {"default": "./index.js"}, "require": {"default": "./umd/index.js"}}}})


@cas_de("la condition `require` compte même imbriquée")
def _():
    assert ck.propose_require({"type": "module", "exports": {
        ".": {"node": {"require": "./cjs/index.js", "import": "./index.js"}}}})


# ── Le défaut ─────────────────────────────────────────────────────────────────────────────────

@cas_de("ESM seul avec un `exports` sans `require` : refusé")
def _():
    # C'est la forme exacte de `jose` 6.
    assert not ck.propose_require({"type": "module", "exports": {
        ".": {"types": "./dist/types/index.d.ts", "default": "./dist/webapi/index.js"}}})


@cas_de("ESM seul sans `exports` du tout : refusé")
def _():
    assert not ck.propose_require({"type": "module", "main": "index.js"})


# ── L'extraction des noms de paquets ──────────────────────────────────────────────────────────

@cas_de("les quatre dépendances réelles du serveur sont vues")
def _():
    requis = ck.paquets_requis()
    for paquet in ("jose", "bcryptjs", "@neondatabase/serverless", "@vercel/blob"):
        assert paquet in requis, f"{paquet} manque — l'extraction ne lit plus le code"
    # Et `jose` est bien attribué aux deux fichiers qui le chargent.
    assert any(f.endswith("lib/auth.js") for f in requis["jose"])
    assert any(f.endswith("lib/apns.js") for f in requis["jose"])


@cas_de("les modules du cœur et les chemins relatifs ne sont pas des paquets")
def _():
    requis = ck.paquets_requis()
    for faux in ("crypto", "http2", "fs", ".", "..", "node:crypto"):
        assert faux not in requis, f"{faux} n'est pas une dépendance"


@cas_de("un sous-chemin ne crée pas un paquet de plus")
def _():
    for nom in ck.paquets_requis():
        assert nom.count("/") <= (1 if nom.startswith("@") else 0), nom


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
