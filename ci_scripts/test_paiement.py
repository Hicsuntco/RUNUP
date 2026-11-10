#!/usr/bin/env python3
"""Les cas de `check_paiement.py`.

Ce contrôle garde la seule décision de l'app qui coûte de l'argent à l'utilisatrice quand elle est
fausse. Ses cas doivent donc répondre à deux questions, pas une : « attrape-t-il le défaut ? » et
« comment pourrait-il passer vert pour la mauvaise raison ? »

La seconde est celle qui compte ici. Un contrôle qui lit un fichier par expressions régulières
passe vert dès qu'il ne reconnaît plus rien — une signature reformatée, une énumération déplacée,
et il annonce « tout va bien » sur une liste vide. Trois cas ci-dessous ne vérifient que ça.
"""
import pathlib, shutil, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_paiement as cp

RACINE = pathlib.Path(__file__).resolve().parent.parent

SERVICE_SAIN = '''
@MainActor
final class SubscriptionService {
    func purchase(_ product: Product) async -> PurchaseOutcome {
        let resultat: PurchaseOutcome.StoreKitResult = .verified
        await attendreLeDroit()
        return PurchaseOutcome.decide(result: resultat, isSubscribed: isSubscribed)
    }
    func applyRedemption(sheetFailed: Bool) async -> OfferCodeOutcome {
        await attendreLeDroit()
        return OfferCodeOutcome.decide(sheetFailed: sheetFailed, isSubscribed: isSubscribed)
    }
    func restore() async -> RestoreOutcome {
        var syncFailed = false
        do { try await AppStore.sync() } catch { syncFailed = true }
        return RestoreOutcome.decide(syncFailed: syncFailed, isSubscribed: isSubscribed)
    }
}
'''

MODELE = '''
enum %s: Equatable {
    case subscribed
    case failed
    static func decide(result: Int, isSubscribed: Bool?) -> %s { .failed }
}
'''


class Atelier(unittest.TestCase):
    """Un dépôt de pacotille, pour pouvoir casser des choses sans toucher au vrai."""

    def setUp(self):
        self.dossier = pathlib.Path(tempfile.mkdtemp())
        (self.dossier / "RunUp/Services").mkdir(parents=True)
        (self.dossier / "RunUp/Models").mkdir(parents=True)
        (self.dossier / "RunUpTests").mkdir(parents=True)
        self.service = self.dossier / "RunUp/Services/SubscriptionService.swift"
        self.service.write_text(SERVICE_SAIN)
        for issue in cp.ISSUES:
            (self.dossier / f"RunUp/Models/{issue}.swift").write_text(MODELE % (issue, issue))
            (self.dossier / f"RunUpTests/{issue}Tests.swift").write_text(
                "XCTAssertEqual(x, .subscribed)\nXCTAssertEqual(y, .failed)\n")
        self.anciens = (cp.SERVICE, cp.MODELES, cp.CAS)
        cp.SERVICE = self.service
        cp.MODELES = self.dossier / "RunUp/Models"
        cp.CAS = self.dossier / "RunUpTests"

    def tearDown(self):
        cp.SERVICE, cp.MODELES, cp.CAS = self.anciens
        shutil.rmtree(self.dossier)

    def defauts(self):
        return cp.regle_delegation() + cp.regle_type_pur() + cp.regle_cas_testes()


class LaDelegation(Atelier):

    def test_un_depot_sain_ne_dit_rien(self):
        self.assertEqual(self.defauts(), [])

    def test_le_defaut_dorigine_est_attrape(self):
        """La ligne exacte qui annonçait l'échec après un paiement encaissé."""
        self.service.write_text(SERVICE_SAIN.replace(
            "return PurchaseOutcome.decide(result: resultat, isSubscribed: isSubscribed)",
            "return isSubscribed == true ? .subscribed : .failed"))
        d = self.defauts()
        self.assertTrue(any("purchase" in x and "décide son issue sur place" in x for x in d), d)

    def test_un_retour_en_chemin_est_attrape(self):
        """Un `return .failed` posé avant la délégation : la décision repasse dans le service.

        C'est la forme que prend la rechute : on garde l'appel à `decide(` à la fin — donc le
        contrôle naïf qui cherche seulement cette chaîne reste vert — et on ajoute un raccourci
        au-dessus. D'où la règle du `return` UNIQUE.
        """
        self.service.write_text(SERVICE_SAIN.replace(
            "        await attendreLeDroit()\n        return PurchaseOutcome.decide",
            "        if resultat == .unverified { return .failed }\n        return PurchaseOutcome.decide"))
        d = self.defauts()
        self.assertTrue(any("purchase" in x and "2 `return`" in x for x in d), d)

    def test_une_issue_qui_nest_plus_rendue_est_signalee(self):
        """Le cas « vert pour la mauvaise raison » numéro un.

        Si une signature change de forme, les expressions régulières n'en trouvent plus aucune et
        le contrôle n'a plus rien à dire — ce qui ressemble trait pour trait à un dépôt sain.
        """
        self.service.write_text(SERVICE_SAIN.replace("-> RestoreOutcome {", "-> SomethingElse {"))
        d = self.defauts()
        self.assertTrue(any("il en faut au moins" in x for x in d), d)

    def test_une_phrase_contenant_return_ne_compte_pas(self):
        """Les chaînes sont retirées avant comptage : un message peut contenir n'importe quoi."""
        self.service.write_text(SERVICE_SAIN.replace(
            "await attendreLeDroit()",
            'let phrase = "return .failed si tu veux"\n        _ = phrase\n        await attendreLeDroit()'))
        self.assertEqual(self.defauts(), [])

    def test_un_commentaire_citant_la_ligne_fautive_ne_compte_pas(self):
        """Ce fichier-ci cite la ligne fautive, et le vrai service la cite aussi dans un
        commentaire d'explication. Un contrôle qui s'y déclencherait serait inutilisable."""
        self.service.write_text(SERVICE_SAIN.replace(
            "await attendreLeDroit()",
            "// return isSubscribed == true ? .subscribed : .failed — ce que ça coûtait.\n        await attendreLeDroit()"))
        self.assertEqual(self.defauts(), [])


class LeTypePur(Atelier):

    def test_un_modele_absent_est_signale(self):
        (self.dossier / "RunUp/Models/RestoreOutcome.swift").unlink()
        d = self.defauts()
        self.assertTrue(any("n'a pas de modèle" in x for x in d), d)

    def test_un_modele_sans_decide_est_signale(self):
        m = self.dossier / "RunUp/Models/OfferCodeOutcome.swift"
        m.write_text(m.read_text().replace("static func decide(", "func autreChose("))
        d = self.defauts()
        self.assertTrue(any("n'expose pas" in x for x in d), d)

    def test_un_modele_qui_importe_storekit_est_signale(self):
        """Tout l'intérêt du type séparé est de se construire dans un test. Avec StoreKit dedans,
        il ne se construit plus, et le fichier de cas devient décoratif."""
        m = self.dossier / "RunUp/Models/PurchaseOutcome.swift"
        m.write_text("import StoreKit\n" + m.read_text())
        d = self.defauts()
        self.assertTrue(any("importe StoreKit" in x for x in d), d)

    def test_un_fichier_de_cas_absent_est_signale(self):
        (self.dossier / "RunUpTests/PurchaseOutcomeTests.swift").unlink()
        d = self.defauts()
        self.assertTrue(any("n'a pas de cas" in x for x in d), d)


class LesCasCouverts(Atelier):

    def test_un_cas_jamais_nomme_est_signale(self):
        """Ajouter une issue sans la vérifier, c'est rouvrir le trou par le haut."""
        m = self.dossier / "RunUp/Models/PurchaseOutcome.swift"
        m.write_text(m.read_text().replace("    case failed", "    case failed\n    case purchasedAwaitingUnlock"))
        d = self.defauts()
        self.assertTrue(any("purchasedAwaitingUnlock" in x for x in d), d)

    def test_les_cas_sur_une_seule_ligne_sont_lus(self):
        """`case a, b, c` est la forme qu'avait `PurchaseOutcome` avant d'être extraite. Ne pas la
        lire laisserait passer trois cas non testés d'un coup — le cas « vert pour la mauvaise
        raison » numéro deux."""
        m = self.dossier / "RunUp/Models/PurchaseOutcome.swift"
        m.write_text(m.read_text().replace("    case subscribed\n    case failed",
                                           "    case subscribed, failed, jamaisTeste"))
        d = self.defauts()
        self.assertTrue(any("jamaisTeste" in x for x in d), d)

    def test_une_enumeration_illisible_est_signalee(self):
        """Le cas « vert pour la mauvaise raison » numéro trois : si la forme du fichier change et
        qu'aucun cas n'est lu, le contrôle doit le DIRE au lieu de féliciter une liste vide."""
        m = self.dossier / "RunUp/Models/RestoreOutcome.swift"
        m.write_text(m.read_text().replace("    case subscribed\n    case failed", ""))
        d = self.defauts()
        self.assertTrue(any("aucun cas lu" in x for x in d), d)

    def test_les_entrees_imbriquees_ne_sont_pas_exigees(self):
        """`PurchaseOutcome.StoreKitResult` décrit ce que StoreKit a répondu : ce sont les ENTRÉES
        de la décision, pas ses issues. Les compter gonflait le total de 11 à 17 et aurait exigé
        qu'on les « teste » comme des réponses."""
        m = self.dossier / "RunUp/Models/PurchaseOutcome.swift"
        m.write_text(m.read_text().replace(
            "    case failed",
            "    case failed\n    enum StoreKitResult { case verified, jamaisTesteNonPlus }"))
        d = self.defauts()
        self.assertEqual([x for x in d if "jamaisTesteNonPlus" in x], [], d)
        self.assertEqual(d, [])


class LeVraiDepot(unittest.TestCase):
    """Et le dépôt réel passe — sans quoi tout ce qui précède ne vérifie qu'un décor."""

    def test_le_depot_reel_passe(self):
        self.assertEqual(cp.regle_delegation() + cp.regle_type_pur() + cp.regle_cas_testes(), [])

    def test_le_depot_reel_porte_bien_onze_issues(self):
        """Un total qui change sans qu'on l'ait voulu veut dire qu'une issue est apparue ou a
        disparu. Onze : cinq pour l'achat, trois pour le code promo, trois pour la restauration."""
        total = sum(len(cp.cas_de_lenum(
            cp.sans_commentaires_ni_chaines((cp.MODELES / f"{i}.swift").read_text()), i))
            for i in cp.ISSUES)
        self.assertEqual(total, 11)


if __name__ == "__main__":
    unittest.main(verbosity=2)
