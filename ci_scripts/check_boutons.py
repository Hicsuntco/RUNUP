#!/usr/bin/env python3
"""Un bouton qui n'est pas sur la branche par défaut n'existe pas.

# POURQUOI CE CONTRÔLE EXISTE

GitHub ne construit le formulaire « Run workflow » QUE depuis la branche par défaut. Un workflow
qui ne se déclenche qu'à la main — `appstore.yml`, qui pilote la fiche App Store — doit donc vivre
sur `main`, et sa liste d'actions sur `main` est la seule que l'on puisse choisir. Le corps du
workflow, lui, récupère explicitement la branche de travail (`inputs.branche`) pour y trouver
`asc.py` et la fiche : c'est le FORMULAIRE qui est figé par `main`, pas le code qu'il lance.

La leçon avait déjà été apprise une fois : `main` porte un commit intitulé « Le bouton qui envoie
les captures doit vivre sur main, sinon il n'existe pas ». Elle n'a pas tenu. Au 10 novembre 2026,
HUIT actions ajoutées depuis étaient injoignables :

    liberer-la-file            nettoyer-les-captures         pousser-l-apercu
    lister-les-captures        nettoyer-les-captures-essai   pousser-l-apercu-essai
    pourquoi-pas-soumettable   pousser-la-montre

Dont deux chantiers entiers : l'envoi des captures de la montre, et l'aperçu vidéo de la fiche.
Chacun écrit, testé, documenté — et impossible à lancer. L'entrée `retirer`, qui nomme les formats
de capture à supprimer, manquait aussi : même en atteignant l'action, le champ n'aurait pas été là.

C'est le défaut le plus discret de tout le dépôt. Le code existe, ses contrôles passent, sa
documentation le décrit, et il ne s'exécute jamais. Rien ne le dit, parce que rien ne regarde du
côté où GitHub, lui, regarde.

# CE QUI EST REGARDÉ, ET CE QUI NE L'EST PAS

Seuls les workflows qui NE TOURNENT QUE sur `workflow_dispatch`. Les autres se déclenchent au
push : leur bouton manquant est une gêne, pas une panne — et une exécution passée se relance
depuis l'onglet Actions. Les signaler noierait le seul cas qui compte.

Pour ceux-là, trois choses doivent correspondre entre la branche de travail et `main` : le fichier
existe, chaque option de chaque liste de choix s'y trouve, et chaque entrée déclarée s'y trouve
aussi.

# IL NE SE TAIT PAS QUAND IL NE PEUT PAS REGARDER

Lire `main` demande le réseau. S'il manque, ce script ÉCHOUE en le disant, au lieu de passer vert
sur une comparaison qu'il n'a pas faite — c'est précisément la forme de silence qui a laissé huit
actions injoignables.
"""
import pathlib, re, subprocess, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIER = RACINE / ".github/workflows"
DEFAUT = "main"


def rafraichir():
    """Va chercher la branche par défaut, et rend la référence à lire, ou (None, raison).

    ON RÉCUPÈRE AVANT DE LIRE, TOUJOURS, ET ON LIT `FETCH_HEAD`.

    Le premier jet lisait `origin/main` et ne récupérait qu'en cas d'échec. Il s'est trompé à son
    premier essai réel : `git fetch origin main` ne met à jour QUE `FETCH_HEAD`, pas
    `refs/remotes/origin/main`, à moins que la configuration du dépôt ne l'y projette. La
    référence locale datait donc de plusieurs semaines, et le contrôle comparait le dépôt
    d'aujourd'hui à un `main` d'avant-hier.

    Le sens de l'erreur est le pire des deux : un `main` local en retard fait signaler des défauts
    déjà corrigés — ce qui apprend à ignorer le rouge — et un `main` local en AVANCE, quoique plus
    rare, ferait passer vert une action injoignable. Les deux viennent de lire sans récupérer.
    """
    r = subprocess.run(["git", "fetch", "--depth=1", "--quiet", "origin", DEFAUT],
                       cwd=RACINE, capture_output=True, text=True)
    if r.returncode != 0:
        detail = r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "sans message"
        return None, f"impossible de récupérer `{DEFAUT}` ({detail})"
    return "FETCH_HEAD", None


def lire_sur_main(ref, chemin_relatif):
    """Le contenu d'un fichier sur la référence récupérée, ou (None, raison)."""
    r = subprocess.run(["git", "show", f"{ref}:{chemin_relatif}"],
                       cwd=RACINE, capture_output=True, text=True)
    if r.returncode == 0:
        return r.stdout, None
    # Le fichier peut être absent de la branche alors que la référence existe : c'est un défaut à
    # signaler, pas une impossibilité de lire.
    if "does not exist" in r.stderr or "exists on disk, but not in" in r.stderr:
        return None, "absent"
    detail = r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "sans message"
    return None, f"illisible : {detail}"


def bloc_on(src):
    m = re.search(r"^on:\s*$(.*?)^\S", src, re.M | re.S)
    return m.group(1) if m else ""


def declencheurs(src):
    return [l.strip().rstrip(":") for l in bloc_on(src).splitlines() if re.match(r"^  [a-z_]+:", l)]


def seulement_a_la_main(src):
    d = declencheurs(src)
    return d == ["workflow_dispatch"]


def options(src):
    """Toutes les options de toutes les listes de choix du formulaire."""
    return set(re.findall(r"^          - ([\w.-]+)\s*$", src, re.M))


def entrees(src):
    """Les noms d'entrées déclarés sous `inputs:`."""
    m = re.search(r"^      inputs:\s*$(.*?)^(?=\S|  \S)", src, re.M | re.S)
    if not m:
        m = re.search(r"^    inputs:\s*$(.*?)^(?=\S|  \S)", src, re.M | re.S)
    bloc = m.group(1) if m else ""
    return set(re.findall(r"^      ([a-z_]+):\s*$", bloc, re.M))


def controler():
    defauts = []
    regardes = 0
    ref, raison = rafraichir()
    if ref is None:
        return ([f"{raison}. Ce contrôle ne passe pas vert sur une comparaison qu'il n'a pas "
                 f"faite : c'est ce silence-là qui a laissé huit actions injoignables."], 0)
    for fichier in sorted(DOSSIER.glob("*.yml")):
        src = fichier.read_text()
        if not seulement_a_la_main(src):
            continue
        regardes += 1
        relatif = f".github/workflows/{fichier.name}"
        sur_main, raison = lire_sur_main(ref, relatif)
        if raison == "absent":
            defauts.append(f"{fichier.name} ne se déclenche QU'À LA MAIN et n'est pas sur "
                           f"`{DEFAUT}` : GitHub ne construit le formulaire que depuis la branche "
                           f"par défaut, donc ce workflow n'a aucun bouton et ne peut jamais "
                           f"tourner. Recopiez-le sur `{DEFAUT}`.")
            continue
        if sur_main is None:
            defauts.append(f"Impossible de lire {relatif} sur `{DEFAUT}` ({raison}). Ce contrôle "
                           f"ne passe pas vert sur une comparaison qu'il n'a pas faite : c'est "
                           f"ce silence-là qui a laissé huit actions injoignables.")
            continue
        manquantes = options(src) - options(sur_main)
        if manquantes:
            defauts.append(f"{fichier.name} : {len(manquantes)} action(s) déclarée(s) ici et "
                           f"absente(s) de `{DEFAUT}` — {', '.join(sorted(manquantes))}. Elles "
                           f"n'apparaissent pas dans le formulaire, donc personne ne peut les "
                           f"lancer, quoi qu'en dise la documentation.")
        absentes = entrees(src) - entrees(sur_main)
        if absentes:
            defauts.append(f"{fichier.name} : {len(absentes)} entrée(s) déclarée(s) ici et "
                           f"absente(s) de `{DEFAUT}` — {', '.join(sorted(absentes))}. Le champ "
                           f"ne serait pas affiché, et l'action le lirait vide.")
    if regardes == 0:
        defauts.append(f"Aucun workflow à déclenchement manuel seul n'a été trouvé dans "
                       f"{DOSSIER.name}/. Soit il n'y en a plus, soit la lecture des déclencheurs "
                       f"a cessé de fonctionner — et ce contrôle ne regarde plus rien.")
    return defauts, regardes


def main():
    defauts, regardes = controler()
    if defauts:
        for d in defauts:
            print("DÉFAUT", d)
        return 1
    print(f"Boutons : {regardes} workflow(s) à déclenchement manuel seul, "
          f"formulaire identique sur `{DEFAUT}`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
