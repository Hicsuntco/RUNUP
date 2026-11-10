#!/usr/bin/env python3
"""Les cas de `check_allures.py`.

Ce contrôle garde les quatre nombres qui décident de ce que les gens courent. Ses cas répondent
donc aux deux questions, pas à une : « attrape-t-il le défaut ? » et « comment pourrait-il passer
vert pour la mauvaise raison ? »

Trois cas ci-dessous ne vérifient que la seconde. Un script qui lit du Swift par expressions
régulières passe vert dès qu'il ne reconnaît plus rien, et un dépôt où il ne reconnaît rien
ressemble trait pour trait à un dépôt sain.
"""
import pathlib, re, shutil, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_allures as ca

PACE_SAIN = '''
enum PaceModel {
    static func zones(for profile: UserProfile) -> Zones {
        let vdot = referenceVdot(for: profile)
        let seuil = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.seuil)
        let footing = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.footing)
        return Zones(
            easy: paceText(footing),
            marathon: paceText(Vdot.allureDeCourse(vdot: vdot, km: 42.195)),
            threshold: paceText(seuil),
            interval: paceText(Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.intervalle)),
            easySecPerKm: footing,
            thresholdSecPerKm: seuil,
            vdot: vdot
        )
    }
}
'''

VDOT_SAIN = '''
enum Vdot {
    enum Fraction {
        static let footingLent = 0.620
        static let footingRapide = 0.700
        static let footing = 0.660
        static let seuil = 0.880
        static let intervalle = 0.975
    }
}
'''

CAS_SAINS = ("// Table de Daniels\n"
             + "".join(f"Ligne(vdot: {v},\n" for v in (30, 35, 40, 45, 50, 55, 60))
             + "Vdot.Fraction.footingLent Vdot.Fraction.footingRapide Vdot.Fraction.footing "
               "Vdot.Fraction.seuil Vdot.Fraction.intervalle\n")


class Atelier(unittest.TestCase):

    def setUp(self):
        self.d = pathlib.Path(tempfile.mkdtemp())
        (self.d / "RunUp/Services").mkdir(parents=True)
        (self.d / "RunUp/Models").mkdir(parents=True)
        (self.d / "RunUpTests").mkdir(parents=True)
        self.pace = self.d / "RunUp/Services/PaceModel.swift"
        self.vdot = self.d / "RunUp/Models/Vdot.swift"
        self.cas = self.d / "RunUpTests/VdotTests.swift"
        self.pace.write_text(PACE_SAIN)
        self.vdot.write_text(VDOT_SAIN)
        self.cas.write_text(CAS_SAINS)
        self.anciens = (ca.PACE, ca.VDOT, ca.CAS)
        ca.PACE, ca.VDOT, ca.CAS = self.pace, self.vdot, self.cas

    def tearDown(self):
        ca.PACE, ca.VDOT, ca.CAS = self.anciens
        shutil.rmtree(self.d)

    def defauts(self):
        return (ca.regle_aucun_coefficient() + ca.regle_les_quatre_passent_par_vdot()
                + ca.regle_chaque_fraction_est_eprouvee())


class LesCoefficients(Atelier):

    def test_un_depot_sain_ne_dit_rien(self):
        self.assertEqual(self.defauts(), [])

    def test_le_defaut_dorigine_est_attrape(self):
        """Les quatre multiplications telles qu'elles étaient écrites."""
        self.pace.write_text(PACE_SAIN.replace(
            "easy: paceText(footing),", "easy: paceText(seuil * 1.20),"))
        d = self.defauts()
        self.assertTrue(any("coefficient écrit à la main" in x for x in d), d)

    def test_une_division_compte_aussi(self):
        """L'ancien code déduisait un seuil d'une allure de footing par `/ 1.20`, et se trompait
        du côté opposé. Les deux sens sont le même défaut."""
        self.pace.write_text(PACE_SAIN.replace(
            "let footing = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.footing)",
            "let footing = seuil / 1.20"))
        d = self.defauts()
        self.assertTrue(any("coefficient écrit à la main" in x for x in d), d)

    def test_les_entiers_sont_tolores(self):
        """60, 1000, 42 sont des conversions d'unité. Les signaler noierait le vrai défaut."""
        self.pace.write_text(PACE_SAIN.replace(
            "            vdot: vdot", "            vdot: vdot * 1"))
        self.assertEqual(self.defauts(), [])

    def test_un_commentaire_citant_le_defaut_ne_compte_pas(self):
        """Le vrai fichier cite `thresholdSecPerKm * 1.20` dans son commentaire d'explication.
        Un contrôle qui s'y déclencherait serait inutilisable."""
        self.pace.write_text(PACE_SAIN.replace(
            "    static func zones",
            "    // Avant : paceText(thresholdSecPerKm * 1.20) — 25 s/km trop vite.\n    static func zones"))
        self.assertEqual(self.defauts(), [])

    def test_une_signature_introuvable_est_signalee(self):
        """« Vert pour la mauvaise raison » numéro un : si la signature change de forme, les
        expressions régulières ne trouvent plus rien et le script n'a plus rien à dire."""
        self.pace.write_text(PACE_SAIN.replace("-> Zones {", "-> AutreChose {"))
        d = self.defauts()
        self.assertTrue(any("introuvable" in x for x in d), d)


class LesQuatreAllures(Atelier):

    def test_une_allure_qui_ne_passe_plus_par_vdot_est_signalee(self):
        for attendu in ("Vdot.Fraction.seuil", "Vdot.Fraction.intervalle",
                        "Vdot.Fraction.footing", "Vdot.allureDeCourse("):
            with self.subTest(attendu=attendu):
                self.pace.write_text(PACE_SAIN.replace(attendu, "QuelqueChoseDAutre"))
                d = self.defauts()
                self.assertTrue(any("ne passe pas par" in x for x in d), (attendu, d))

    def test_le_marathon_ne_peut_pas_devenir_une_fraction_fixe(self):
        """La fraction qu'implique l'allure marathon de Daniels dérive de 80,5 à 82,5 % le long de
        la table : la figer se tromperait jusqu'à trois secondes au kilomètre."""
        self.pace.write_text(PACE_SAIN.replace(
            "Vdot.allureDeCourse(vdot: vdot, km: 42.195)",
            "Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.marathon)"))
        d = self.defauts()
        self.assertTrue(any("allureDeCourse" in x for x in d), d)


class LesFractionsEprouvees(Atelier):

    def test_une_fraction_non_eprouvee_est_signalee(self):
        self.vdot.write_text(VDOT_SAIN.replace(
            "        static let seuil = 0.880",
            "        static let seuil = 0.880\n        static let jamaisEprouvee = 0.5"))
        d = self.defauts()
        self.assertTrue(any("jamaisEprouvee" in x for x in d), d)

    def test_une_table_amputee_est_signalee(self):
        """« Vert pour la mauvaise raison » numéro deux : sans la table, les cas ne vérifient plus
        que la cohérence du code avec lui-même."""
        self.cas.write_text(CAS_SAINS.replace("Ligne(vdot: 55,\n", "").replace("Ligne(vdot: 60,\n", ""))
        d = self.defauts()
        self.assertTrue(any("ligne(s) de la table" in x for x in d), d)

    def test_une_source_effacee_est_signalee(self):
        """« Vert pour la mauvaise raison » numéro trois. Le défaut d'origine tenait précisément
        à un chiffre dont personne ne pouvait dire d'où il venait."""
        self.cas.write_text(CAS_SAINS.replace("Table de Daniels", "Table"))
        d = self.defauts()
        self.assertTrue(any("source" in x for x in d), d)

    def test_un_fichier_de_cas_absent_est_signale(self):
        self.cas.unlink()
        d = self.defauts()
        self.assertTrue(any("est absent" in x for x in d), d)

    def test_une_enumeration_de_fractions_illisible_est_signalee(self):
        self.vdot.write_text(VDOT_SAIN.replace("enum Fraction {", "struct Fraction2 {"))
        d = self.defauts()
        self.assertTrue(any("introuvable" in x for x in d), d)


class LeVraiDepot(unittest.TestCase):
    """Et le dépôt réel passe — sans quoi tout ce qui précède ne vérifie qu'un décor."""

    def test_le_depot_reel_passe(self):
        self.assertEqual(ca.regle_aucun_coefficient() + ca.regle_les_quatre_passent_par_vdot()
                         + ca.regle_chaque_fraction_est_eprouvee(), [])

    def test_le_depot_reel_porte_les_cinq_fractions(self):
        self.assertEqual(sorted(ca.fractions_declarees()),
                         ["footing", "footingLent", "footingRapide", "intervalle", "seuil"])

    def test_lancien_coefficient_ne_traine_plus_dans_zones(self):
        """0,87 — l'allure du mile prescrite pour un intervalle de trois à cinq minutes."""
        body = ca.corps_de_zones()
        self.assertIsNotNone(body)
        for ancien in ("1.20", "1.08", "0.87"):
            self.assertNotIn(ancien, body, f"le coefficient {ancien} est revenu dans `zones`")


if __name__ == "__main__":
    unittest.main(verbosity=2)
