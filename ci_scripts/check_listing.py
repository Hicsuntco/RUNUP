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

# Où s'arrête chaque section de langue. La description n'est plus le dernier champ vérifié, donc
# la borne ne peut plus être « le titre des mots-clés » : c'est la langue suivante, ou la fin.
SECTIONS = [
    ("FR", "# 🇫🇷", "# 🇬🇧"),
    ("EN", "# 🇬🇧", "# 🇪🇸"),
    ("ES", "# 🇪🇸", "# Sections communes"),
]

# (titre du champ dans chaque langue, limite)
#
# Les quatre champs courts comptent autant que la description, et ils sont plus faciles à
# dépasser sans s'en rendre compte : trente caractères se franchissent d'un mot. Les mots-clés
# français sont sortis à 101 pour un seul terme ajouté, et rien ne l'a signalé — App Store Connect
# aurait simplement refusé le collage, à la fin d'une session de rédaction.
FIELDS = [
    (("Description", "Description", "Descripción"), 4000),
    (("Nom de l'app", "App name", "Nombre de la app"), 30),
    (("Sous-titre", "Subtitle", "Subtítulo"), 30),
    (("Texte promotionnel", "Promotional text", "Texto promocional"), 170),
    (("Mots-clés", "Keywords", "Palabras clave"), 100),
    (("Nouveautés de cette version", "What's New in This Version", "Novedades de esta versión"), 4000),
]


def main() -> int:
    text = DOC.read_text(encoding="utf-8")
    failed = False
    fields_by_lang = {}
    for (lang, start, end), idx in ((sec, i) for i, sec in enumerate(SECTIONS)):
        try:
            i = text.index(start)
            j = text.index(end, i)
        except ValueError:
            print(f"ECHEC [{lang}] : section introuvable dans {DOC.name}")
            failed = True
            continue
        section = text[i:j]
        found = {}
        for names, limit in FIELDS:
            field = names[idx]
            m = re.search(rf"## {re.escape(field)}[^\n]*\n```\n(.*?)\n```", section, re.S)
            if not m:
                print(f"ECHEC [{lang}] : champ « {field} » introuvable")
                failed = True
                continue
            value = m.group(1)
            found[field] = value
            n = len(value)
            status = "OK" if n <= limit else f"DÉPASSE DE {n - limit}"
            print(f"[{lang}] {field} : {n} / {limit} — {status}")
            if n > limit:
                failed = True
        fields_by_lang[lang] = (idx, found)

    # Un mot-clé déjà présent dans le nom ou le sous-titre ne rapporte RIEN : Apple indexe les
    # trois champs comme un seul sac. C'est cent caractères rares dépensés pour zéro recherche
    # nouvelle, et l'erreur est invisible — la fiche reste valide, elle se voit juste moins.
    for lang, (idx, found) in fields_by_lang.items():
        name = found.get(FIELDS[1][0][idx], "")
        subtitle = found.get(FIELDS[2][0][idx], "")
        keywords = found.get(FIELDS[4][0][idx], "")
        indexed = set(re.findall(r"\w+", (name + " " + subtitle).lower()))
        dupes = [k for k in keywords.split(",") if k.strip().lower() in indexed]
        if dupes:
            print(f"ECHEC [{lang}] : mots-clés déjà indexés par le nom ou le sous-titre : {', '.join(dupes)}")
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
