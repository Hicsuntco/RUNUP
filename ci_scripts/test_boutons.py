#!/usr/bin/env python3
"""Les cas de `check_boutons.py`.

Ce contrôle garde le défaut le plus discret du dépôt : du code écrit, testé, documenté, et que
personne ne peut lancer. Ses cas doivent donc répondre aux deux questions — « attrape-t-il le
défaut ? » et « comment pourrait-il passer vert pour la mauvaise raison ? »

La seconde a déjà servi, et contre moi. Le premier jet lisait `origin/main` et ne récupérait qu'en
cas d'échec : il a comparé le dépôt du jour à un `main` vieux de plusieurs semaines, parce que
`git fetch origin main` ne met à jour que `FETCH_HEAD`. Deux cas ci-dessous ne vérifient que ça.
"""
import pathlib, shutil, subprocess, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_boutons as cb

MANUEL = """name: Fiche
on:
  workflow_dispatch:
    inputs:
      action:
        description: "Que faire"
        required: true
        type: choice
        options:
          - status
          - nettoyer-les-captures
      version:
        required: true
        type: string
      retirer:
        required: false
        type: string
jobs:
  x:
    runs-on: ubuntu-latest
    steps:
      - run: echo
"""

AU_PUSH = """name: Construire
on:
  push:
    branches: [travail]
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options:
          - une-action-que-main-ignore
jobs:
  x:
    runs-on: ubuntu-latest
    steps:
      - run: echo
"""


class Atelier(unittest.TestCase):
    """Un dépôt git de pacotille, avec sa propre « branche par défaut »."""

    def setUp(self):
        self.d = pathlib.Path(tempfile.mkdtemp())
        self.travail = self.d / "travail"
        self.distant = self.d / "distant.git"
        (self.travail / ".github/workflows").mkdir(parents=True)
        self._git(["init", "-q", "-b", "travail"], self.travail)
        self._git(["config", "user.email", "x@y.z"], self.travail)
        self._git(["config", "user.name", "x"], self.travail)
        # Le dépôt distant porte `main` ; la copie de travail est sur une autre branche.
        self.ecrire("appstore.yml", MANUEL)
        self._git(["add", "-A"], self.travail)
        self._git(["commit", "-qm", "base"], self.travail)
        self._git(["init", "--bare", "-q", "-b", "main", str(self.distant)], self.d)
        self._git(["remote", "add", "origin", str(self.distant)], self.travail)
        self._git(["push", "-q", "origin", "travail:main"], self.travail)
        self.anciens = (cb.RACINE, cb.DOSSIER)
        cb.RACINE, cb.DOSSIER = self.travail, self.travail / ".github/workflows"

    def tearDown(self):
        cb.RACINE, cb.DOSSIER = self.anciens
        shutil.rmtree(self.d)

    def _git(self, args, cwd):
        r = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        return r.stdout

    def ecrire(self, nom, contenu):
        (self.travail / ".github/workflows" / nom).write_text(contenu)

    def pousser_sur_main(self):
        """Fait avancer `main` du distant jusqu'à l'état de la copie de travail."""
        self._git(["add", "-A"], self.travail)
        self._git(["commit", "-qm", "maj"], self.travail)
        self._git(["push", "-q", "origin", "travail:main"], self.travail)

    def defauts(self):
        return cb.controler()[0]


class LeCasOrdinaire(Atelier):

    def test_un_depot_aligne_ne_dit_rien(self):
        self.assertEqual(self.defauts(), [])

    def test_un_workflow_au_push_est_ignore(self):
        """Son bouton manquant est une gêne, pas une panne : il tourne au push, et une exécution
        passée se relance depuis l'onglet Actions. Le signaler noierait le seul cas qui compte."""
        self.ecrire("testflight.yml", AU_PUSH)
        self.assertEqual(self.defauts(), [])


class LeDefautDOrigine(Atelier):

    def test_une_action_absente_de_main_est_attrapee(self):
        self.ecrire("appstore.yml", MANUEL.replace(
            "          - nettoyer-les-captures",
            "          - nettoyer-les-captures\n          - pousser-la-montre"))
        d = self.defauts()
        self.assertTrue(any("pousser-la-montre" in x for x in d), d)

    def test_une_entree_absente_de_main_est_attrapee(self):
        self.ecrire("appstore.yml", MANUEL.replace(
            "      retirer:", "      retirer:\n        required: false\n      nouveau_champ:"))
        d = self.defauts()
        self.assertTrue(any("nouveau_champ" in x for x in d), d)

    def test_un_workflow_manuel_absent_de_main_est_attrape(self):
        """Le cas que `main` porte déjà en commit : « Le bouton qui envoie les captures doit vivre
        sur main, sinon il n'existe pas »."""
        self.ecrire("apercu.yml", MANUEL.replace("name: Fiche", "name: Aperçu"))
        d = self.defauts()
        self.assertTrue(any("apercu.yml" in x and "n'est pas sur" in x for x in d), d)

    def test_la_correction_rend_le_controle_vert(self):
        self.ecrire("appstore.yml", MANUEL.replace(
            "          - status", "          - status\n          - une-action-neuve"))
        self.assertTrue(self.defauts())
        self.pousser_sur_main()
        self.assertEqual(self.defauts(), [])


class VertPourLaMauvaiseRaison(Atelier):

    def test_une_reference_locale_perimee_ne_trompe_pas(self):
        """LE DÉFAUT DU PREMIER JET, et il s'est produit au premier essai réel.

        `git fetch origin main` ne met à jour que `FETCH_HEAD`, pas `refs/remotes/origin/main`. En
        lisant la référence locale, le contrôle comparait à un `main` vieux de plusieurs semaines.
        Ici on fabrique la situation : `main` est corrigé sur le distant, et la référence locale
        est laissée en arrière. Le contrôle doit voir la correction.
        """
        self.ecrire("appstore.yml", MANUEL.replace(
            "          - status", "          - status\n          - action-neuve"))
        self.pousser_sur_main()
        # On périme délibérément la référence locale.
        self._git(["update-ref", "refs/remotes/origin/main", "HEAD~1"], self.travail)
        self.assertEqual(self.defauts(), [],
                         "le contrôle a lu une référence locale périmée au lieu de récupérer")

    def test_une_reference_locale_en_avance_ne_trompe_pas_non_plus(self):
        """Le sens inverse, plus rare et plus grave : une référence locale EN AVANCE ferait passer
        vert une action réellement injoignable."""
        self.ecrire("appstore.yml", MANUEL.replace(
            "          - status", "          - status\n          - action-neuve"))
        self._git(["add", "-A"], self.travail)
        self._git(["commit", "-qm", "local seulement"], self.travail)
        # La référence locale connaît le commit, le distant non.
        self._git(["update-ref", "refs/remotes/origin/main", "HEAD"], self.travail)
        d = self.defauts()
        self.assertTrue(any("action-neuve" in x for x in d),
                        f"une référence locale en avance a masqué le défaut : {d}")

    def test_sans_distant_le_controle_echoue_au_lieu_de_se_taire(self):
        """Il ne passe pas vert sur une comparaison qu'il n'a pas faite."""
        self._git(["remote", "set-url", "origin", str(self.d / "nulle-part.git")], self.travail)
        d = self.defauts()
        self.assertTrue(any("impossible de récupérer" in x for x in d), d)

    def test_aucun_workflow_manuel_est_signale(self):
        """Si la lecture des déclencheurs cesse de fonctionner, le contrôle ne regarde plus rien —
        et un dépôt où il ne regarde rien ressemble à un dépôt sain."""
        self.ecrire("appstore.yml", AU_PUSH)
        d = self.defauts()
        self.assertTrue(any("Aucun workflow à déclenchement manuel" in x for x in d), d)


class LeVraiDepot(unittest.TestCase):
    """Et le dépôt réel passe — sans quoi tout ce qui précède ne vérifie qu'un décor."""

    def test_le_depot_reel_passe(self):
        self.assertEqual(cb.controler()[0], [])

    def test_appstore_est_bien_le_seul_workflow_manuel_seul(self):
        """S'il cesse de l'être, c'est que quelque chose a changé de déclencheur — et ce contrôle
        regarderait soudain un autre ensemble que celui qu'il décrit."""
        self.assertEqual(cb.controler()[1], 1)
        src = (cb.DOSSIER / "appstore.yml").read_text()
        self.assertTrue(cb.seulement_a_la_main(src))


if __name__ == "__main__":
    unittest.main(verbosity=2)
