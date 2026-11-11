#!/usr/bin/env python3
"""Les cas de `check_film.py`.

Chaque cas casse UN des cinq faits et vérifie que le contrôle le dit. Sans eux, un contrôle qui
rend vert quoi qu'il arrive est indiscernable d'un dépôt sain — et celui-ci garde une image qui
part chez Apple.
"""
import pathlib, shutil, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_film as cf


class Atelier(unittest.TestCase):
    """Chaque cas recopie les cinq vrais fichiers, en abîme un, et lit le verdict."""

    def setUp(self):
        self.d = pathlib.Path(tempfile.mkdtemp())
        self.vrais = dict(cf.FICHIERS)
        self.copies = {}
        for cle, source in self.vrais.items():
            cible = self.d / source.name
            cible.write_text(source.read_text())
            self.copies[cle] = cible
        cf.FICHIERS = dict(self.copies)
        cf.RACINE = self.d

    def tearDown(self):
        cf.FICHIERS = self.vrais
        cf.RACINE = pathlib.Path(cf.__file__).resolve().parent.parent
        shutil.rmtree(self.d, ignore_errors=True)

    def abimer(self, cle, ancien, nouveau):
        p = self.copies[cle]
        t = p.read_text()
        self.assertIn(ancien, t, f"l'ancre a disparu de {cle}")
        p.write_text(t.replace(ancien, nouveau))

    # ── Le dépôt tel quel ────────────────────────────────────────────────────

    def test_le_depot_reel_passe(self):
        self.assertEqual(cf.controler(), [])

    # ── Les cinq façons de casser ────────────────────────────────────────────

    def test_le_film_qui_ne_se_declare_plus(self):
        self.abimer("film", '"--film", ', "")
        self.assertTrue(any("ApercuUITests" in p for p in cf.controler()))

    def test_les_photos_qui_se_declarent_film(self):
        self.abimer("photos", 'app.launchArguments = ["--captures"',
                    'app.launchArguments = ["--captures", "--film"')
        self.assertTrue(any("CapturesUITests" in p for p in cf.controler()))

    def test_lapp_qui_nallume_plus_le_mode_film(self):
        self.abimer("app", "Demonstration.filmer()", "// rien")
        self.assertTrue(any("n'allume plus" in p for p in cf.controler()))

    def test_la_regle_inversee(self):
        self.abimer("mode", "enCours && !filme", "enCours && filme")
        plaintes = cf.controler()
        self.assertTrue(any("animationsFigees" in p for p in plaintes), plaintes)

    def test_la_racine_qui_ne_fige_plus(self):
        self.abimer("app", ".transaction { if Demonstration.animationsFigees",
                    "// .transaction retirée { if rien")
        self.assertTrue(any("racine" in p for p in cf.controler()))

    # ── Et le cas « vert pour la mauvaise raison » ───────────────────────────

    def test_un_fichier_absent_fait_echouer_le_controle(self):
        """Un contrôle qui ne trouve pas ses fichiers doit se plaindre, pas rendre vert."""
        self.copies["mode"].unlink()
        plaintes = cf.controler()
        self.assertTrue(any("introuvable" in p for p in plaintes), plaintes)


if __name__ == "__main__":
    unittest.main(verbosity=2)
