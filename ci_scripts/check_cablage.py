#!/usr/bin/env python3
"""Chaque contrôle et chaque fichier de cas est-il VRAIMENT lancé par un workflow ?

# POURQUOI CE CONTRÔLE EXISTE

Un garde-fou qu'on croit avoir est pire que pas de garde-fou : on cesse de regarder l'endroit
qu'il surveille. Ce défaut-là s'est présenté quatre fois, et jamais par négligence — toujours
parce que écrire le contrôle et le câbler sont deux gestes, et que le premier donne le
sentiment d'avoir fini.

- `test_session.py` et `test_accent.py` existaient tous les deux, et aucun workflow ne les
  appelait. Le commentaire est resté dans `testflight.yml`, à l'étape qui les a câblés.
- `test_icones.py` répétait un nombre devenu faux. Il était bien câblé, celui-là, et c'est ce
  qui l'a montré : TestFlight est passé au rouge dix minutes après le commit. Un test non
  câblé n'aurait rien dit du tout.
- `check_profile.py` compare les capacités du profil de provisionnement à celles que la cible
  demande. Écrit après un `exportArchive` refusé sur WeatherKit, douze minutes après le début
  de l'archivage. Appelé par aucun workflow — découvert en comptant les fichiers, pas en
  lisant le code, le 8 novembre 2026.
- `test_comparer.py` lui-même, écrit le même jour, n'aurait pas été câblé sans ce contrôle.

# CE QUI EST VÉRIFIÉ

Tout `ci_scripts/check_*.py` et `ci_scripts/test_*.py` est nommé dans au moins un fichier de
`.github/workflows/`, ou bien figure dans `DISPENSES` ci-dessous AVEC SA RAISON. Une dispense
n'est pas un silence : elles sont toutes affichées à chaque exécution, et une dispense qui ne
correspond à aucun fichier fait échouer le contrôle — sinon la liste pourrirait sur place.

Ce que ce contrôle ne dit PAS : qu'un contrôle câblé est juste, ni que ses cas couvrent quoi
que ce soit. Il dit seulement qu'il tourne. C'est la seule question qu'une liste de fichiers
sache poser, et c'est celle qui est passée quatre fois.
"""
import pathlib
import sys

ICI = pathlib.Path(__file__).resolve().parent
RACINE = ICI.parent

#: fichier → pourquoi il ne peut pas être câblé. La raison est lue par un humain : elle doit
#: dire ce qui manque pour le câbler, pas simplement « il ne tourne pas ».
DISPENSES = {
    "check_profile.py":
        "demande le profil de provisionnement décodé, qui n'existe qu'au moment de la "
        "signature. À câbler dans testflight.yml juste avant l'export — voir RELEASE.md § 4.",
}


def fichiers() -> list[pathlib.Path]:
    return sorted(
        [p for p in ICI.glob("check_*.py")] + [p for p in ICI.glob("test_*.py")]
    )


def sans_commentaires(source: str) -> str:
    """Le même texte, commentaires blanchis — ligne par ligne, sans en perdre une.

    CE CONTRÔLE A LU SES PROPRES COMMENTAIRES, le jour de son écriture. L'étape qui le câble
    explique, en commentaire, que `check_profile.py` ne tourne nulle part — et la phrase cite
    le nom du fichier. Le contrôle l'a compté comme un câblage et a déclaré la dispense
    périmée. Exactement le défaut que `check_cjs.py` avait déjà eu, pour la même raison : un
    contrôle qui cherche un motif dans un fichier qui le commente.

    Un `#` ouvre un commentaire en YAML, et aussi dans un bloc littéral `run: |`, où c'est le
    shell qui le lit. Les deux sont du texte non exécuté, et les deux se blanchissent ici. On
    suit les guillemets pour ne pas couper sur le `#` d'une chaîne.
    """
    lignes = []
    for ligne in source.split("\n"):
        chaine = None
        for i, c in enumerate(ligne):
            if chaine:
                if c == chaine:
                    chaine = None
            elif c in "\"'":
                chaine = c
            elif c == "#":
                ligne = ligne[:i]
                break
        lignes.append(ligne)
    return "\n".join(lignes)


def texte_des_workflows() -> str:
    dossier = RACINE / ".github" / "workflows"
    if not dossier.is_dir():
        raise SystemExit(f"{dossier} est introuvable : le contrôle ne peut rien vérifier.")
    morceaux = [p.read_text(encoding="utf-8") for p in sorted(dossier.glob("*.yml"))]
    morceaux += [p.read_text(encoding="utf-8") for p in sorted(dossier.glob("*.yaml"))]
    if not morceaux:
        raise SystemExit(f"Aucun workflow dans {dossier} : le contrôle ne peut rien vérifier.")
    return sans_commentaires("\n".join(morceaux))


def main() -> int:
    tous = fichiers()
    if not tous:
        raise SystemExit(f"Aucun check_*.py ni test_*.py dans {ICI} : "
                         f"le contrôle regarde au mauvais endroit.")

    workflows = texte_des_workflows()
    # LE NOM SUFFIT — HORS COMMENTAIRE. Vérifier qu'un fichier est bien EXÉCUTÉ demanderait
    # d'interpréter le shell de chaque étape, et ce n'est pas le défaut qui s'est présenté
    # quatre fois : celui-là, c'est le fichier dont le nom n'apparaît nulle part. Les
    # commentaires sont blanchis, parce que le nom d'un fichier qu'on explique ne pas câbler
    # est écrit, justement, dans un commentaire. Le `tout.sh`, lui, exécute pour de vrai.
    orphelins = [p.name for p in tous if p.name not in workflows]

    dispenses_inutiles = sorted(set(DISPENSES) - {p.name for p in tous})
    dispenses_couvertes = sorted(n for n in DISPENSES
                                 if n in workflows and n != "check_cablage.py")
    non_dispenses = [n for n in orphelins if n not in DISPENSES]

    print(f"{len(tous)} fichier(s) de contrôle et de cas dans ci_scripts/")
    print(f"{len(tous) - len(orphelins)} nommé(s) par un workflow, "
          f"{len(orphelins)} non nommé(s)")
    print()
    for nom in sorted(DISPENSES):
        print(f"  dispensé : {nom}")
        print(f"             {DISPENSES[nom]}")

    if non_dispenses:
        print()
        print("CES FICHIERS NE TOURNENT NULLE PART :", file=sys.stderr)
        for nom in sorted(non_dispenses):
            print(f"  - {nom}", file=sys.stderr)
        print("\nAjoutez une étape dans .github/workflows/testflight.yml — ou, s'il ne peut "
              "pas tourner en l'état, une entrée dans DISPENSES avec la raison.",
              file=sys.stderr)
        return 1

    if dispenses_inutiles:
        print()
        print("CES DISPENSES NE CORRESPONDENT À AUCUN FICHIER :", file=sys.stderr)
        for nom in dispenses_inutiles:
            print(f"  - {nom}", file=sys.stderr)
        print("\nLe fichier a été renommé ou supprimé. Retirez la dispense : une liste de "
              "dispenses périmée finit par dispenser autre chose que ce qu'on croit.",
              file=sys.stderr)
        return 1

    if dispenses_couvertes:
        print()
        print("CES FICHIERS SONT DISPENSÉS ET POURTANT CÂBLÉS :", file=sys.stderr)
        for nom in dispenses_couvertes:
            print(f"  - {nom}", file=sys.stderr)
        print("\nC'est une bonne nouvelle : retirez la dispense, le contrôle veillera dessus.",
              file=sys.stderr)
        return 1

    print()
    print("Chaque contrôle et chaque fichier de cas est nommé par un workflow, "
          "ou dispensé avec sa raison.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
