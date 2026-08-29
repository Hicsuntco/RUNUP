#!/usr/bin/env python3
"""Refuse une fiche App Store qui ne rentrerait pas dans les champs d'App Store Connect.

Les limites sont dures : au-delà, le champ refuse le collage. Et la description est le seul
endroit où la longueur se découvre à la main, au moment de la saisie, après avoir tout rédigé.

Ce contrôle existe parce que le bloc d'abonnement — obligatoire, guideline 3.1.2 — a poussé deux
descriptions au-dessus de la limite, et que la vérification a été faite APRÈS la publication deux
fois de suite.
"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "APP_STORE_LISTING.md"

# (langue, ancre de section, ancre de fin, titre du champ, limite)
FIELDS = [
    ("FR", "# 🇫🇷", "## Mots-clés", "Description", 4000),
    ("EN", "# 🇬🇧", "## Keywords", "Description", 4000),
    ("ES", "# 🇪🇸", "## Palabras clave", "Descripción", 4000),
]


def main() -> int:
    text = DOC.read_text(encoding="utf-8")
    failed = False
    for lang, start, end, field, limit in FIELDS:
        try:
            i, j = text.index(start), text.index(end, text.index(start))
        except ValueError:
            print(f"ECHEC [{lang}] : section introuvable dans {DOC.name}")
            failed = True
            continue
        m = re.search(rf"## {field}[^\n]*\n```\n(.*?)\n```", text[i:j], re.S)
        if not m:
            print(f"ECHEC [{lang}] : champ « {field} » introuvable")
            failed = True
            continue
        n = len(m.group(1))
        status = "OK" if n <= limit else f"DÉPASSE DE {n - limit}"
        print(f"[{lang}] {field} : {n} / {limit} — {status}")
        if n > limit:
            failed = True

    # Le bloc d'abonnement doit figurer dans les trois : un seul manquant est un rejet.
    for lang, marker in (("FR", "ABONNEMENT RUNUP PLUS"),
                         ("EN", "RUNUP PLUS SUBSCRIPTION"),
                         ("ES", "SUSCRIPCIÓN RUNUP PLUS")):
        if marker not in text:
            print(f"ECHEC [{lang}] : bloc d'abonnement absent (guideline 3.1.2)")
            failed = True

    print("\nFiche conforme." if not failed else "\nLa fiche ne passerait pas la saisie ou la revue.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
