#!/usr/bin/env python3
"""Les cas de `check_listes.py`.

L'item d'origine comptait des FICHIERS — « 63 fichiers utilisent `ForEach`, 11 seulement une liste
paresseuse » — et ce comptage ne mesure rien. Ces cas tiennent la distinction qui compte : un
`ForEach` sous un défilement, sans conteneur paresseux, et dont la source n'est pas bornée dans le
code. Trois d'entre eux ne vérifient que les façons de passer vert à tort.
"""
import pathlib, shutil, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_listes as cl

GABARIT = '''
struct UnEcran: View {
    var body: some View {
        ScrollView {
            %s {
                ForEach(%s) { x in
                    Text(x.nom)
                }
            }
        }
    }
}
'''


class Atelier(unittest.TestCase):

    def setUp(self):
        self.d = pathlib.Path(tempfile.mkdtemp())
        (self.d / "RunUp").mkdir(parents=True)
        self.ecran = self.d / "RunUp/UnEcran.swift"
        # UN ÉCRAN TÉMOIN DANS CHAQUE BANC, et il a sa raison d'être.
        #
        # `controler()` se plaint quand il ne voit AUCUN `ForEach` sous un défilement — c'est sa
        # règle « vert pour la mauvaise raison » : un dépôt où il ne regarde rien ressemble à un
        # dépôt sain. Mais un banc d'essai qui ne contient qu'un écran paresseux est exactement
        # ce cas-là, légitimement. Le témoin porte une source bornée, donc il ne dit jamais rien
        # par lui-même, et il suffit à prouver que la lecture fonctionne.
        self.temoin = self.d / "RunUp/Temoin.swift"
        self.temoin.write_text(GABARIT % ("VStack", "Filtre.allCases"))
        self.anciens = (cl.RACINE, dict(cl.DISPENSES))
        cl.RACINE = self.d
        cl.DISPENSES = {}

    def tearDown(self):
        cl.RACINE, cl.DISPENSES = self.anciens
        shutil.rmtree(self.d)

    def ecrire(self, conteneur, source):
        self.ecran.write_text(GABARIT % (conteneur, source))

    def defauts(self):
        return cl.controler()[0]


class LaPosition(Atelier):

    def test_une_liste_sans_borne_dans_un_defilement_est_attrapee(self):
        self.ecrire("VStack", "commentaires")
        d = self.defauts()
        self.assertTrue(any("commentaires" in x for x in d), d)

    def test_un_conteneur_paresseux_suffit(self):
        for conteneur in ("LazyVStack", "LazyHStack", "LazyVGrid(columns: cols)"):
            with self.subTest(conteneur=conteneur):
                self.ecrire(conteneur, "commentaires")
                self.assertEqual(self.defauts(), [], conteneur)

    def test_une_List_est_paresseuse_par_construction(self):
        self.ecrire("List", "commentaires")
        self.assertEqual(self.defauts(), [])

    def test_hors_defilement_rien_a_dire(self):
        """Un `ForEach` dans une carte fixe construit ce qui est affiché, et c'est tout."""
        self.ecran.write_text('''
struct UnEcran: View {
    var body: some View {
        VStack {
            ForEach(commentaires) { x in Text(x.nom) }
        }
    }
}
''')
        self.assertEqual(self.defauts(), [])


class LesSourcesBornees(Atelier):

    def test_allCases_passe(self):
        for source in ("Filtre.allCases", "GoalType.allCases.filter(\\.estProposable)",
                       "ExperienceLevel.allCases, id: \\.self"):
            with self.subTest(source=source):
                self.ecrire("VStack", source)
                self.assertEqual(self.defauts(), [], source)

    def test_un_intervalle_litteral_passe(self):
        for source in ("0..<7", "1...12"):
            with self.subTest(source=source):
                self.ecrire("VStack", source)
                self.assertEqual(self.defauts(), [], source)

    def test_un_intervalle_calcule_ne_passe_pas(self):
        """`0..<items.count` n'est pas une borne : c'est la même collection, écrite autrement."""
        self.ecrire("VStack", "0..<items.count")
        self.assertTrue(self.defauts())


class LesDispenses(Atelier):

    def test_une_dispense_motivee_passe(self):
        self.ecrire("VStack", "groupes, id: \\.self")
        cl.DISPENSES = {("UnEcran.swift", "groupes"):
                        "Les groupes d'allure d'une sortie : le produit en propose huit au plus, "
                        "et c'est une bande horizontale de pastilles, pas une liste qui croît."}
        self.assertEqual(self.defauts(), [])

    def test_une_dispense_sans_vraie_raison_ne_passe_pas(self):
        self.ecrire("VStack", "groupes")
        cl.DISPENSES = {("UnEcran.swift", "groupes"): "c'est court."}
        self.assertTrue(self.defauts())

    def test_une_dispense_ne_vaut_que_pour_son_fichier(self):
        """Deux vues peuvent nommer `badges` sans parler de la même chose. Une dispense qui
        traverserait les fichiers couvrirait une liste que personne n'a relue."""
        self.ecrire("VStack", "badges")
        cl.DISPENSES = {("UneAutreVue.swift", "badges"):
                        "Le catalogue de badges, borné par ClubBadgeCatalog.all — une trentaine "
                        "d'entrées en bande horizontale, rien n'y croît avec l'usage."}
        self.assertTrue(self.defauts())


class VertPourLaMauvaiseRaison(Atelier):

    def test_aucun_foreach_vu_est_signale(self):
        """Si la lecture de l'imbrication cesse de fonctionner, le contrôle ne regarde plus rien,
        et un dépôt où il ne regarde rien ressemble à un dépôt sain."""
        self.ecran.write_text('struct X: View { var body: some View { Text("rien") } }')
        self.temoin.unlink()
        d = self.defauts()
        self.assertTrue(any("Aucun `ForEach`" in x for x in d), d)

    def test_le_paresseux_doit_etre_ENTRE_le_defilement_et_le_foreach(self):
        """Un `LazyVStack` ailleurs dans le fichier ne rend pas paresseuse une liste qui ne s'y
        trouve pas. C'est l'imbrication qui décide, pas la présence du mot."""
        self.ecran.write_text('''
struct UnEcran: View {
    var body: some View {
        VStack {
            LazyVStack {
                Text("ailleurs")
            }
            ScrollView {
                VStack {
                    ForEach(commentaires) { x in Text(x.nom) }
                }
            }
        }
    }
}
''')
        d = self.defauts()
        self.assertTrue(any("commentaires" in x for x in d),
                        f"un LazyVStack voisin a couvert une liste qui n'est pas dedans : {d}")

    def test_un_commentaire_citant_un_ForEach_ne_compte_pas(self):
        """Le dépôt commente abondamment ce qu'il a corrigé. Un contrôle qui lirait les
        commentaires s'accuserait lui-même."""
        self.ecrire("LazyVStack", "commentaires")
        s = self.ecran.read_text().replace(
            "        ScrollView {",
            "        // Avant : ScrollView { VStack { ForEach(commentaires) — tout d'un bloc.\n        ScrollView {")
        self.ecran.write_text(s)
        self.assertEqual(self.defauts(), [])


class LeVraiDepot(unittest.TestCase):
    """Et le dépôt réel passe — sans quoi tout ce qui précède ne vérifie qu'un décor."""

    def test_le_depot_reel_passe(self):
        self.assertEqual(cl.controler()[0], [])

    def test_les_dispenses_sont_motivees(self):
        for cle, raison in cl.DISPENSES.items():
            self.assertGreaterEqual(len(raison), 60, cle)

    def test_le_depot_reel_porte_bien_des_foreach_sous_defilement(self):
        """Le compte peut bouger ; zéro voudrait dire que le contrôle ne voit plus rien."""
        self.assertGreater(cl.controler()[1], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
