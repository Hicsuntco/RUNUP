#!/usr/bin/env python3
"""Les pages publiées sont annoncées PARTOUT avec la même adresse.

L'adresse de la politique de confidentialité était écrite en dur à NEUF endroits : la fiche App
Store dans ses trois langues, le script qui l'envoie à Apple, la page d'assistance, la page de
club, le paywall de l'app. Le dépôt a changé de propriétaire, GitHub Pages a suivi, et les neuf
copies pointaient toujours vers l'ancien domaine — qui répond 404.

Aucune conséquence bruyante, et deux conséquences graves : la fiche App Store annonçait une
politique de confidentialité introuvable, ce qu'Apple exige de fournir ; et le lien du paywall, dans
l'app livrée, ouvrait une page d'erreur au moment précis où quelqu'un s'apprête à payer.

CE QUE CE CONTRÔLE TIENT, ET CE QU'IL NE PEUT PAS TENIR. Il ne demande pas au réseau si les pages
répondent — ce serait un contrôle qui échoue pour une raison étrangère au code. Cette question se
pose là où elle compte : `asc.py push-metadata` la vérifie juste avant d'envoyer la fiche à Apple.
Ici, trois choses hors ligne :

  • toute adresse `github.io` du dépôt est l'une des deux déclarées ;
  • les deux déclarations, Swift et Python, disent la même chose ;
  • chaque page annoncée existe comme fichier dans le dépôt. La page d'assistance existait depuis
    des semaines pendant que la fiche envoyait vers la politique de confidentialité à sa place.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import liens  # noqa: E402

RACINE = pathlib.Path(__file__).resolve().parent.parent

# LES JOURNAUX GARDENT LES ANCIENNES ADRESSES, et c'est leur travail : ils racontent ce qui a été
# fait, y compris une adresse depuis corrigée. Les relire comme des porteurs vivants obligerait à
# réécrire l'histoire à chaque renommage.
JOURNAUX = {"PROGRESS.md", "AUDIT.md", "PHASE2.md"}

# La déclaration elle-même, et le contrôle qui la lit.
DECLARATIONS = {"RunUp/Models/Liens.swift", "ci_scripts/liens.py", "ci_scripts/check_liens.py",
                "ci_scripts/test_liens.py"}

EXTENSIONS = {".swift", ".py", ".html", ".md", ".yml", ".yaml", ".json", ".js"}

# LES DOSSIERS QU'ON NE RELIT PAS : ils ne sont pas à nous.
#
# La première version lisait tout, `node_modules` compris, et signalait cinquante et un liens de
# spécification dans les dépendances — « https://w3c.github.io/FileAPI/ » n'est pas une page de
# RUNUP mal adressée. Un contrôle qui noie son rapport sous des lignes étrangères ne se lit plus.
IGNORES = {"node_modules", ".build", "DerivedData", "vendor", ".git", "__pycache__", "Pods"}

# LA RÈGLE PORTE SUR NOS PAGES, PAS SUR TOUT GITHUB PAGES.
#
# Le segment de projet vient de la déclaration : si le dépôt est renommé, c'est elle qui change, et
# le motif suit. Une adresse `github.io` qui ne vise pas notre projet n'est pas de notre ressort —
# et c'est la seule façon d'exclure un lien de spécification sans tenir une liste d'exceptions.
PROJET = liens.BASE.rstrip("/").rsplit("/", 1)[-1]
ADRESSE = re.compile(rf"https://[\w.-]+\.github\.io/{re.escape(PROJET)}[\w./-]*")


def fichiers():
    for chemin in sorted(RACINE.rglob("*")):
        if not chemin.is_file() or chemin.suffix not in EXTENSIONS:
            continue
        relatif = chemin.relative_to(RACINE).as_posix()
        if IGNORES & set(relatif.split("/")[:-1]):
            continue
        if chemin.name in JOURNAUX or relatif in DECLARATIONS:
            continue
        yield relatif, chemin


def ecarts():
    attendues = {liens.CONFIDENTIALITE, liens.ASSISTANCE}
    problemes = []

    for relatif, chemin in fichiers():
        texte = chemin.read_text(encoding="utf-8", errors="replace")
        for numero, ligne in enumerate(texte.splitlines(), start=1):
            for url in ADRESSE.findall(ligne):
                if url.rstrip("/") not in {a.rstrip("/") for a in attendues}:
                    problemes.append((
                        f"{relatif}:{numero}", url,
                        "Adresse publiée écrite en dur et différente des deux déclarées. "
                        "Utilise `Liens` (Swift) ou `liens` (Python), ou corrige la page.",
                    ))

    # Les deux déclarations disent-elles la même chose ?
    swift = (RACINE / "RunUp/Models/Liens.swift").read_text(encoding="utf-8")
    base = re.search(r'static let base = "([^"]+)"', swift)
    if not base:
        problemes.append(("RunUp/Models/Liens.swift", "—", "`base` est introuvable."))
    elif base.group(1) != liens.BASE:
        problemes.append((
            "RunUp/Models/Liens.swift", base.group(1),
            f"Diffère de `ci_scripts/liens.py`, qui dit {liens.BASE}. Les deux doivent "
            "s'accorder, sinon l'app et la fiche n'annoncent pas la même page.",
        ))

    # Chaque page annoncée existe-t-elle dans le dépôt ?
    for url, fichier in liens.FICHIERS.items():
        if not (RACINE / fichier).is_file():
            problemes.append((fichier, url, "La page annoncée n'existe pas dans le dépôt."))

    return problemes


def main() -> int:
    problemes = ecarts()
    if problemes:
        print(f"{len(problemes)} problème(s) sur les adresses publiées :\n")
        for ou, url, raison in problemes:
            print(f"  • {ou} — {url}")
            print(f"      {raison}\n")
        print("Voir l'en-tête de RunUp/Models/Liens.swift.")
        return 1
    print("Adresses publiées : une seule par page, les deux déclarations s'accordent, "
          "et chaque page existe.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
