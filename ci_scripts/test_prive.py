#!/usr/bin/env python3
"""Les cas de `check_prive.py`.

Le défaut d'origine : la carte du défi, sortie de `ClubView`, appelait `daysLeft(until:)` restée
`private` dans `ClubView`. Le projet ne compilait plus, et toute la chaîne était verte.

La première écriture de ce contrôle NE L'A PAS RATTRAPÉ, et c'est le cas le plus instructif du
banc : l'appel vit dans une interpolation — `"J-\\(daysLeft(until: d))"` — et la fonction qui
vidait les chaînes l'effaçait avec le texte. Un contrôle qui rate le défaut pour lequel il a été
écrit est pire que pas de contrôle : il rassure. `test_un_appel_dans_une_interpolation_compte`
tient cette correction.

Quatre cas ne vérifient que les façons de se tromper dans l'autre sens, parce qu'une première
version plus large rendait 112 signalements pour zéro défaut réel.
"""
import pathlib, shutil, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_prive as cp


class Atelier(unittest.TestCase):
    """Chaque cas écrit deux fichiers dans une cible de pacotille et lit le verdict."""

    def setUp(self):
        self.d = pathlib.Path(tempfile.mkdtemp())
        (self.d / "RunUp").mkdir(parents=True)

    def tearDown(self):
        shutil.rmtree(self.d, ignore_errors=True)

    def verdict(self, hote, appelant):
        (self.d / "RunUp/Hote.swift").write_text(hote)
        (self.d / "RunUp/Appelant.swift").write_text(appelant)
        textes = {str(f): cp.sans_commentaires(f.read_text())
                  for f in sorted((self.d / "RunUp").rglob("*.swift"))}
        return [nom for nom, _, _ in cp.defauts(textes)]

    # ── ce qui doit être signalé ───────────────────────────────────────────────

    def test_un_appel_nu_depuis_un_autre_fichier(self):
        self.assertEqual(
            self.verdict("struct A { private func calcul() -> Int { 1 } }",
                         "struct B { var n: Int { calcul() } }"),
            ["calcul"])

    def test_un_appel_dans_une_interpolation_compte(self):
        """LE CAS QUI A ÉCHAPPÉ À LA PREMIÈRE VERSION.

        L'appel réel était `String(localized: "J-\\(daysLeft(until: d))")`. Vider les chaînes à la
        regex effaçait l'interpolation avec le texte, et le contrôle rendait vert sur le défaut
        même qu'il devait voir.
        """
        self.assertEqual(
            self.verdict("struct A { private func jours(_ d: Int) -> Int { d } }",
                         'struct B { var t: String { "J-\\(jours(3))" } }'),
            ["jours"])

    def test_une_interpolation_imbriquee_dans_une_chaine_imbriquee(self):
        self.assertEqual(
            self.verdict("struct A { private func f(_ n: Int) -> Int { n } }",
                         'struct B { var t: String { "a \\(g("b \\(f(1))")) c" }\n'
                         '  func g(_ s: String) -> String { s } }'),
            ["f"])

    def test_fileprivate_ne_franchit_pas_davantage_le_fichier(self):
        self.assertEqual(
            self.verdict("struct A { fileprivate func calcul() -> Int { 1 } }",
                         "struct B { var n: Int { calcul() } }"),
            ["calcul"])

    def test_une_fonction_privee_statique_aussi(self):
        self.assertEqual(
            self.verdict("struct A { private static func calcul() -> Int { 1 } }",
                         "struct B { var n: Int { calcul() } }"),
            ["calcul"])

    # ── ce qui ne doit PAS être signalé ────────────────────────────────────────

    def test_une_fonction_privee_appelee_chez_elle(self):
        self.assertEqual(
            self.verdict("struct A {\n  private func calcul() -> Int { 1 }\n"
                         "  var n: Int { calcul() }\n}",
                         "struct B { var m: Int { 2 } }"),
            [])

    def test_une_fonction_non_privee(self):
        self.assertEqual(
            self.verdict("struct A { func calcul() -> Int { 1 } }",
                         "struct B { var n: Int { calcul() } }"),
            [])

    def test_une_etiquette_dargument_du_meme_nom(self):
        """LA RAISON DE LA FORME ÉTROITE DU CONTRÔLE.

        `RoundedRectangle(cornerRadius: 12)` contient `cornerRadius` nu. Une version plus large,
        qui regardait les noms sans exiger la parenthèse, rendait 112 signalements de ce genre
        pour zéro défaut réel.
        """
        self.assertEqual(
            self.verdict("struct A { private func cornerRadius() -> Int { 1 } }",
                         "struct B { var f = Forme(cornerRadius: 12) }"),
            [])

    def test_un_appel_de_membre_avec_un_point(self):
        self.assertEqual(
            self.verdict("struct A { private func calcul() -> Int { 1 } }",
                         "struct B { var n: Int { objet.calcul() } }"),
            [])

    def test_un_nom_declare_dans_les_deux_fichiers(self):
        """Déclaré deux fois : l'appel peut se résoudre sur l'autre, le script passe son tour."""
        self.assertEqual(
            self.verdict("struct A { private func calcul() -> Int { 1 } }",
                         "struct B {\n  func calcul() -> Int { 2 }\n  var n: Int { calcul() }\n}"),
            [])

    def test_le_nom_dans_une_chaine_de_texte_ne_compte_pas(self):
        self.assertEqual(
            self.verdict("struct A { private func calcul() -> Int { 1 } }",
                         'struct B { var t = "appelle calcul() quelque part" }'),
            [])

    def test_le_nom_en_commentaire_ne_compte_pas(self):
        self.assertEqual(
            self.verdict("struct A { private func calcul() -> Int { 1 } }",
                         "struct B {\n  // voir calcul() dans A\n  var n = 1\n}"),
            [])

    def test_un_suffixe_de_nom_ne_compte_pas(self):
        self.assertEqual(
            self.verdict("struct A { private func calcul() -> Int { 1 } }",
                         "struct B { var n: Int { monCalcul() } }"),
            [])

    def test_deux_cibles_distinctes_ne_se_comparent_pas(self):
        """`RunUp` et `RunUpWatch` sont deux modules : un appel entre eux échoue pour une autre
        raison que `private`, et ce script ne prétend pas la dire."""
        (self.d / "RunUp").mkdir(parents=True, exist_ok=True)
        (self.d / "RunUpWatch").mkdir(parents=True, exist_ok=True)
        (self.d / "RunUp/Hote.swift").write_text("struct A { private func calcul() -> Int { 1 } }")
        (self.d / "RunUpWatch/B.swift").write_text("struct B { var n: Int { calcul() } }")
        trouves = []
        for cible in ("RunUp", "RunUpWatch"):
            textes = {str(f): cp.sans_commentaires(f.read_text())
                      for f in sorted((self.d / cible).rglob("*.swift"))}
            trouves += cp.defauts(textes)
        self.assertEqual(trouves, [])


class LeLecteurDeChaines(unittest.TestCase):
    """`sans_commentaires` garde le code, jette le texte — la pièce la plus délicate."""

    def test_le_texte_dune_chaine_disparait(self):
        self.assertNotIn("bonjour", cp.sans_commentaires('let x = "bonjour"'))

    def test_le_code_dune_interpolation_reste(self):
        self.assertIn("f(1)", cp.sans_commentaires('let x = "a \\(f(1)) b"'))

    def test_un_bloc_triple_guillemet_se_ferme(self):
        sortie = cp.sans_commentaires('let x = """\ntexte \\(f(1)) ici\n"""\nlet y = g(2)')
        self.assertIn("f(1)", sortie)
        self.assertIn("g(2)", sortie)
        self.assertNotIn("texte", sortie)

    def test_un_guillemet_echappe_ne_ferme_pas_la_chaine(self):
        sortie = cp.sans_commentaires('let x = "une \\" suite"\nlet y = g(2)')
        self.assertNotIn("suite", sortie)
        self.assertIn("g(2)", sortie)

    def test_un_commentaire_de_bloc_disparait(self):
        self.assertNotIn("caché", cp.sans_commentaires("/* caché */ let x = 1"))


class LeVraiDepot(unittest.TestCase):
    """Et le dépôt réel passe — sans quoi tout ce qui précède ne vérifie qu'un décor."""

    def test_le_depot_reel_passe(self):
        self.assertEqual(cp.main(), 0)

    def test_le_depot_reel_porte_bien_des_fonctions_privees(self):
        """Le compte peut bouger ; zéro voudrait dire que le contrôle ne lit plus rien."""
        total = sum(len(cp.fonctions_privees(code))
                    for cible in cp.CIBLES for code in cp.lire(cible).values())
        self.assertGreater(total, 100)


if __name__ == "__main__":
    unittest.main(verbosity=2)
