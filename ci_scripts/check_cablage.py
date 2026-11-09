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
- `check_profile.py` a semblé en être un quatrième — et c'était une erreur de ce contrôle-ci,
  qui ne regardait que les noms écrits dans les workflows. Sa règle tourne à chaque build,
  appelée par `profils.py`. Voir plus bas : l'import compte.
- `test_comparer.py` lui-même, écrit le même jour, n'aurait pas été câblé sans ce contrôle.

# CE QUI EST VÉRIFIÉ

Tout `ci_scripts/check_*.py` et `ci_scripts/test_*.py` tourne : il est nommé dans un fichier de
`.github/workflows/`, ou bien IMPORTÉ par un fichier qui l'est, ou bien il figure dans
`DISPENSES` ci-dessous AVEC SA RAISON. Une dispense n'est pas un silence : elles sont toutes
affichées à chaque exécution, une dispense qui ne correspond à aucun fichier fait échouer le
contrôle, et une dispense sur un fichier redevenu câblé aussi — sinon la liste pourrirait sur
place.

L'IMPORT COMPTE, ET IL A FALLU UNE DISPENSE FAUSSE POUR LE VOIR. `check_profile.py` n'est
appelé par aucun workflow, et sa règle tourne pourtant à chaque build : `profils.py` est appelé
et l'importe pour sa fonction `manquantes()`. Je l'avais inscrit en dispense avec la mention
« ne tourne nulle part », et cette mention était partie dans RELEASE.md. Une dispense fausse est
pire qu'une dispense manquante : elle dit qu'on sait, et on ne sait pas. Il n'y a plus aucune
dispense aujourd'hui.

Ce que ce contrôle ne dit PAS : qu'un contrôle câblé est juste, ni que ses cas couvrent quoi
que ce soit. Il dit seulement qu'il tourne. C'est la seule question qu'une liste de fichiers
sache poser, et c'est celle qui est passée quatre fois.
"""
import ast
import pathlib
import re
import sys

ICI = pathlib.Path(__file__).resolve().parent
RACINE = ICI.parent

#: fichier → pourquoi il ne peut pas être câblé. La raison est lue par un humain : elle doit
#: dire ce qui manque pour le câbler, pas simplement « il ne tourne pas ».
DISPENSES: dict[str, str] = {}


def fichiers() -> list[pathlib.Path]:
    return sorted(
        [p for p in ICI.glob("check_*.py")] + [p for p in ICI.glob("test_*.py")]
    )


def importe(fichier: pathlib.Path) -> set[str]:
    """Les modules que ce fichier importe, lus dans l'arbre syntaxique.

    Dans l'arbre et non dans le texte : ce contrôle cherchait `"from PIL" in texte`, et sa
    propre ligne de recherche contenait ces mots — il s'est accusé lui-même. L'arbre ne
    contient que ce que Python exécute.
    """
    try:
        arbre = ast.parse(fichier.read_text(encoding="utf-8"))
    except SyntaxError:
        return set()
    modules = set()
    for noeud in ast.walk(arbre):
        if isinstance(noeud, ast.Import):
            modules.update(a.name.split(".")[0] for a in noeud.names)
        elif isinstance(noeud, ast.ImportFrom) and noeud.module and noeud.level == 0:
            modules.add(noeud.module.split(".")[0])
    return modules


def nomme(nom: str, texte: str) -> bool:
    """`nom` est-il écrit dans `texte` comme un fichier, et pas comme la fin d'un autre ?

    UNE SOUS-CHAÎNE NE SUFFIT PAS, et ce contrôle l'a appris sur lui-même. Le dépôt a gagné
    `requis.py` à côté de `check_requis.py` et `test_requis.py` ; `"requis.py" in texte` est
    alors vrai partout où l'un des deux autres est nommé. Le contrôle a donc rapporté que
    `requis.py` — qui lit des images — tournait dans `testflight.yml`, qui n'a pas Pillow. Il
    n'y tourne pas, et il ne s'y trouvait pas : seul son nom s'y cachait dans celui d'un voisin.

    Le défaut était SILENCIEUX dans l'autre sens aussi, et c'est le grave : un fichier
    `comparer.py` compte comme « nommé par un workflow » dès qu'un `test_comparer.py` l'est.
    Un script orphelin pouvait donc passer pour câblé, ce qui est exactement ce que ce contrôle
    existe pour empêcher.

    La borne de gauche refuse une lettre, un chiffre, un `_`, un `-` ou un point avant le nom —
    donc `check_requis.py` et `mon-requis.py` ne comptent pas, tandis que `ci_scripts/requis.py`,
    `"requis.py"` et ` requis.py` comptent. Celle de droite refuse qu'autre chose suive.
    """
    return re.search(rf"(?<![\w.\-]){re.escape(nom)}(?![\w.\-])", texte) is not None


def tourne_par_import(fichier: pathlib.Path, nommes: set[str],
                      connus: dict[str, bool]) -> bool:
    """Ce fichier est-il importé, directement ou en chaîne, par un fichier qui tourne ?

    `check_profile.py` n'est appelé par aucun workflow — et sa règle tourne pourtant à CHAQUE
    build : `profils.py`, lui, est appelé, et il importe `check_profile` pour sa fonction
    `manquantes()`. Je l'avais inscrit en dispense avec la mention « ne tourne nulle part », ce
    qui était faux, et cette mention serait partie dans RELEASE.md et dans PROGRESS.md.

    Une dispense fausse est pire qu'une dispense manquante : elle dit qu'on sait, et on ne sait
    pas. D'où cette question-ci, posée avant celle de la dispense.
    """
    nom = fichier.name
    if nom in connus:
        return connus[nom]
    connus[nom] = False  # coupe une éventuelle boucle d'imports
    reponse = False
    for voisin in sorted(fichier.parent.glob("*.py")):
        if voisin.name == nom or fichier.stem not in importe(voisin):
            continue
        if voisin.name in nommes or tourne_par_import(voisin, nommes, connus):
            reponse = True
            break
    connus[nom] = reponse
    return reponse


def lit_des_images(fichier: pathlib.Path, connus: dict[str, bool]) -> bool:
    """Ce fichier a-t-il besoin de Pillow — directement, ou par un voisin de `ci_scripts` ?

    `test_bascules.py` n'importe pas Pillow : il importe `bascules`, qui l'importe. Un seul
    niveau suffit — c'est la forme qu'ont les huit scripts concernés, et deviner plus loin
    coûterait plus que ça ne rapporte.
    """
    nom = fichier.name
    if nom in connus:
        return connus[nom]
    connus[nom] = False  # coupe une éventuelle boucle d'imports
    importes = importe(fichier)
    direct = "PIL" in importes
    if not direct:
        for voisin in sorted(fichier.parent.glob("*.py")):
            if voisin.name != nom and voisin.stem in importes:
                if lit_des_images(voisin, connus):
                    direct = True
                    break
    connus[nom] = direct
    return direct


def jobs_du_workflow(chemin: pathlib.Path) -> list[tuple[str, bool, str]]:
    """Par job : (nom, le job fournit-il Pillow, le texte de ses commandes).

    # POURQUOI CE N'EST PAS `yaml.safe_load`

    Parce que ce contrôle tourne dans `testflight.yml`, dont le python est celui du système,
    et que ce job n'installe RIEN. Dépendre de PyYAML ici serait exactement le défaut que la
    seconde question de ce contrôle existe pour attraper — et `pip install` nu est refusé sur
    les runners macOS, donc l'ajouter demanderait un venv de plus dans le job le plus long.

    # CE QUI EST LU, ET CE QUI NE L'EST PAS

    Les six workflows du dépôt portent UN job chacun. On lit donc le fichier comme un tout, et
    on REFUSE DE JUGER celui qui en porterait deux : un job qui installe Pillow et un autre qui
    lance le script seraient confondus, et le contrôle dirait « tout va bien » à tort. Mieux
    vaut un contrôle qui dit « je ne sais pas » qu'un contrôle qui se trompe en silence.

    Les lignes d'un filtre `paths:` — un élément de liste entre guillemets — nomment des
    fichiers sans les lancer. Elles sont écartées, sinon un script surveillé par un workflow
    passerait pour un script lancé par lui.
    """
    lignes = sans_commentaires(chemin.read_text(encoding="utf-8")).split("\n")

    noms = []
    dans_jobs = False
    for ligne in lignes:
        if not ligne.strip():
            continue
        if not ligne[:1].isspace():
            dans_jobs = ligne.strip() == "jobs:"
            continue
        if dans_jobs and re.fullmatch(r"  ([A-Za-z_][\w-]*):\s*", ligne):
            noms.append(ligne.strip().rstrip(":"))
    if len(noms) > 1:
        raise SystemExit(
            f"{chemin.name} porte {len(noms)} jobs ({', '.join(noms)}). Ce contrôle lit chaque "
            f"workflow comme un seul job — voir `jobs_du_workflow`. À reprendre avant de "
            f"fusionner ce fichier.")

    commandes = "\n".join(l for l in lignes
                          if not re.fullmatch(r"\s*-\s*[\"'].*[\"']\s*", l))
    # Pillow est fourni soit par un appel explicite au python du venv, soit par un venv poussé
    # en tête du PATH — `appstore.yml` fait le second, et ses `python3` nus sont alors le
    # python du venv.
    fournit = ("venv/bin/python" in commandes
               or ("venv/bin" in commandes and "GITHUB_PATH" in commandes))
    return [(noms[0] if noms else chemin.stem, fournit, commandes)]


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
    nommes = {p.name for p in tous if nomme(p.name, workflows)}
    par_import: dict[str, bool] = {}
    orphelins = [p.name for p in tous
                 if p.name not in nommes and not tourne_par_import(p, nommes, par_import)]
    indirects = sorted(p.name for p in tous
                       if p.name not in nommes and p.name not in orphelins)

    dispenses_inutiles = sorted(set(DISPENSES) - {p.name for p in tous})
    dispenses_couvertes = sorted(n for n in DISPENSES
                                 if n in nommes or n in indirects)
    non_dispenses = [n for n in orphelins if n not in DISPENSES]

    # DEUXIÈME QUESTION : CE QUI TOURNE A-T-IL DE QUOI TOURNER ?
    #
    # `test_comparer.py` était bien nommé par un workflow, et il a échoué dix minutes plus tard
    # sur `ModuleNotFoundError: No module named 'PIL'` : je l'avais mis dans `testflight.yml`,
    # dont le python du système n'a pas Pillow. Les huit scripts du dépôt qui lisent des images
    # tournent tous dans un job qui installe Pillow dans un venv — sauf celui-là.
    #
    # Le contrôle le dit maintenant, et c'est la seule dépendance qu'il sache voir : elle a
    # coûté une exécution, elle est portée par huit fichiers, et elle se vérifie sans deviner.
    connus: dict[str, bool] = {}
    images = {p.name for p in ICI.glob("*.py") if lit_des_images(p, connus)}
    sans_pillow = []
    dossier_wf = RACINE / ".github" / "workflows"
    for chemin in sorted([*dossier_wf.glob("*.yml"), *dossier_wf.glob("*.yaml")]):
        for job, fournit, commandes in jobs_du_workflow(chemin):
            if fournit:
                continue
            for nom in sorted(images):
                if nomme(nom, commandes):
                    sans_pillow.append((f"{chemin.name}:{job}", nom))

    print(f"{len(tous)} fichier(s) de contrôle et de cas dans ci_scripts/")
    print(f"{len(nommes)} nommé(s) par un workflow, {len(indirects)} lancé(s) par un import, "
          f"{len(orphelins)} ni l'un ni l'autre")
    print()
    for nom in indirects:
        print(f"  par import : {nom}")
    for nom in sorted(DISPENSES):
        print(f"  dispensé : {nom}")
        print(f"             {DISPENSES[nom]}")

    if sans_pillow:
        print()
        print("CES SCRIPTS LISENT DES IMAGES ET TOURNENT SANS PILLOW :", file=sys.stderr)
        for ou, nom in sans_pillow:
            print(f"  - {nom}  dans  {ou}", file=sys.stderr)
        print("\nLe job doit installer Pillow dans un venv et appeler "
              "\"$RUNNER_TEMP/venv/bin/python\" — ou pousser ce venv en tête du PATH, comme "
              "`appstore.yml`. Les autres scripts qui lisent des images tournent dans "
              "`captures.yml`.", file=sys.stderr)
        return 1

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
    print("Chaque contrôle et chaque fichier de cas tourne : nommé par un workflow, importé "
          "par un fichier qui l'est, ou dispensé avec sa raison.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
