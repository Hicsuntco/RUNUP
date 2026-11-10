#!/usr/bin/env python3
"""Les cas de `check_vides.py`.

Ce contrôle garde une pièce du système de design, et il a une particularité : il AVOUE ce qu'il ne
sait pas garder. La forme `.ligne` n'a aucune signature détectable, la règle la plus large essayée
rendait trente-cinq endroits pour environ six vrais, et les conversions ont donc été faites en
lisant. Deux cas ci-dessous vérifient que cet aveu reste honnête — c'est-à-dire que ce qu'il
prétend garder, il le garde vraiment.
"""
import pathlib, shutil, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_vides as cv

COMPOSANT = '''
struct RUEmpty: View {
    enum Forme {
        case bloc
        case ligne
    }
    var body: some View {
        switch forme {
        case .ligne:
            Text(message).foregroundColor(RUColor.text3)
        case .bloc:
            Image(systemName: icone).font(RUFont.icone(.hero)).foregroundColor(RUColor.text3)
            Text(message).foregroundColor(RUColor.text3)
        }
    }
}
'''

ECRAN_SAIN = '''
struct UnEcran: View {
    var body: some View {
        if items.isEmpty {
            RUEmpty(icone: "bell.slash",
                    titre: String(localized: "Rien pour l'instant"),
                    message: String(localized: "Ça arrivera ici."))
                .padding(.top, 40)
        }
    }
}
'''

BLOC_A_LA_MAIN = '''
struct UnEcran: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(RUFont.icone(.hero)).foregroundColor(RUColor.text3)
            Text("Rien pour l'instant")
                .font(RUFont.sans(.emphasis, weight: .bold))
        }
    }
}
'''


class Atelier(unittest.TestCase):

    def setUp(self):
        self.d = pathlib.Path(tempfile.mkdtemp())
        (self.d / "Components").mkdir(parents=True)
        self.composant = self.d / "Components/EmptyStateView.swift"
        self.composant.write_text(COMPOSANT)
        self.ecran = self.d / "UnEcran.swift"
        self.ecran.write_text(ECRAN_SAIN)
        self.anciens = (cv.VUES, cv.COMPOSANT, dict(cv.DISPENSES))
        cv.VUES, cv.COMPOSANT = self.d, self.composant
        cv.DISPENSES = {}

    def tearDown(self):
        cv.VUES, cv.COMPOSANT, cv.DISPENSES = self.anciens
        shutil.rmtree(self.d)

    def defauts(self):
        return cv.bloc_a_la_main() + cv.style_repris() + cv.composant_fidele()


class LeBloc(Atelier):

    def test_un_ecran_sain_ne_dit_rien(self):
        self.assertEqual(self.defauts(), [])

    def test_un_bloc_ecrit_a_la_main_est_attrape(self):
        self.ecran.write_text(BLOC_A_LA_MAIN)
        d = self.defauts()
        self.assertTrue(any("compose un état vide à la main" in x for x in d), d)

    def test_une_petite_icone_nest_pas_un_etat_vide(self):
        """Les icônes de ligne et de puce sont teintées `text3` elles aussi, et il y en a
        quatorze. Les signaler noierait le seul cas qui compte — c'est ce qui a fait resserrer
        la règle sur les grands crans."""
        self.ecran.write_text(BLOC_A_LA_MAIN.replace(".icone(.hero)", ".icone(.micro)"))
        self.assertEqual(self.defauts(), [])

    def test_une_dispense_nommee_passe(self):
        self.ecran.write_text(BLOC_A_LA_MAIN)
        cv.DISPENSES = {("UnEcran.swift", "square.stack.3d.up"):
                        "Ce n'est pas un état vide mais un cadre de photo à remplir, et le bouton "
                        "d'à côté ouvre la galerie — soixante caractères de raison au moins."}
        self.assertEqual(self.defauts(), [])

    def test_une_dispense_sans_vraie_raison_ne_passe_pas(self):
        """Une dispense sans raison est une dispense qu'on reconduit sans la relire."""
        self.ecran.write_text(BLOC_A_LA_MAIN)
        cv.DISPENSES = {("UnEcran.swift", "square.stack.3d.up"): "parce que."}
        self.assertTrue(self.defauts())

    def test_la_dispense_se_lit_dans_la_chaine_non_effacee(self):
        """LE DÉFAUT DU PREMIER JET. `sans_commentaires` efface le CONTENU des chaînes — voulu,
        parce que les commentaires du dépôt nomment ce que les contrôles refusent. Mais le nom du
        symbole, qui désigne la dispense, est un contenu de chaîne : cherché dans la version
        effacée, il ne se trouvait jamais, et la seule dispense réelle ne s'appliquait pas."""
        self.ecran.write_text(BLOC_A_LA_MAIN.replace(
            'VStack(spacing: 10) {',
            '// Un LinearGradient vivait ici, et un "square.stack.3d.up" aussi.\n        VStack(spacing: 10) {'))
        cv.DISPENSES = {("UnEcran.swift", "square.stack.3d.up"):
                        "Un cadre de photo de couverture à remplir, pas une phrase qui annonce "
                        "qu'il n'y a rien à montrer. Le bouton d'à côté ouvre la galerie."}
        self.assertEqual(self.defauts(), [], "la dispense n'a pas été reconnue")


class LeSiteDAppel(Atelier):

    def test_un_restylage_est_attrape(self):
        for modificateur in (".multilineTextAlignment(.center)", ".font(RUFont.sans(.small))",
                             ".foregroundColor(RUColor.text2)", ".lineSpacing(8)"):
            with self.subTest(modificateur=modificateur):
                self.ecran.write_text(ECRAN_SAIN.replace(
                    "                .padding(.top, 40)",
                    f"                {modificateur}"))
                d = self.defauts()
                self.assertTrue(any("restyle" in x for x in d), (modificateur, d))

    def test_une_marge_nest_pas_un_restylage(self):
        """Une marge positionne, elle ne redécide pas de la forme. Les vingt-quatre appels en
        portent, et les refuser rendrait le contrôle inutilisable."""
        for modificateur in (".padding(.top, 40)", ".padding(.horizontal, 18)", ".ruCard()"):
            with self.subTest(modificateur=modificateur):
                self.ecran.write_text(ECRAN_SAIN.replace(
                    "                .padding(.top, 40)", f"                {modificateur}"))
                self.assertEqual(self.defauts(), [], modificateur)

    def test_un_appel_sur_plusieurs_lignes_est_lu_en_entier(self):
        """Les arguments sont lus à parenthèses équilibrées : un appel tient sur quatre lignes et
        contient des `String(localized:)`. Un motif naïf s'arrête au milieu et croit voir un
        modificateur là où il y a encore des arguments."""
        self.ecran.write_text(ECRAN_SAIN)
        self.assertEqual(self.defauts(), [])


class LeComposant(Atelier):

    def test_le_composant_doit_garder_le_cran_hero(self):
        self.composant.write_text(COMPOSANT.replace(".icone(.hero)", ".icone(.xlarge)"))
        d = self.defauts()
        self.assertTrue(any("hero" in x for x in d), d)

    def test_le_composant_doit_garder_text3(self):
        self.composant.write_text(COMPOSANT.replace("RUColor.text3", "RUColor.text2"))
        d = self.defauts()
        self.assertTrue(any("text3" in x for x in d), d)

    def test_une_forme_disparue_est_signalee(self):
        """Vert pour la mauvaise raison : si les deux formes n'existent plus, ce contrôle parle
        d'un composant qui a changé de nature."""
        self.composant.write_text(COMPOSANT.replace("case ligne", "case autreChose"))
        d = self.defauts()
        self.assertTrue(any("case ligne" in x for x in d), d)

    def test_un_composant_absent_est_signale(self):
        self.composant.unlink()
        d = self.defauts()
        self.assertTrue(any("absent" in x for x in d), d)


class LeVraiDepot(unittest.TestCase):
    """Et le dépôt réel passe — sans quoi tout ce qui précède ne vérifie qu'un décor."""

    def test_le_depot_reel_passe(self):
        self.assertEqual(cv.bloc_a_la_main() + cv.style_repris() + cv.composant_fidele(), [])

    def test_une_seule_dispense_et_elle_est_motivee(self):
        self.assertEqual(len(cv.DISPENSES), 1)
        for cle, raison in cv.DISPENSES.items():
            self.assertGreaterEqual(len(raison), 60, cle)


if __name__ == "__main__":
    unittest.main(verbosity=2)
