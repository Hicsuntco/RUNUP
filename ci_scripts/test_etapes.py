#!/usr/bin/env python3
"""Ce que `check_etapes.py` doit voir, et ce qu'il ne doit pas inventer.

Extraits figés : un test qui relirait le dépôt passerait tant que la faute y est, et échouerait
à la seconde où elle est corrigée.
"""
import sys

import check_etapes as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


CONTENEUR = '''
    @ViewBuilder
    private var currentStep: some View {
        switch vm.step {
        case 0: NameStepView(vm: vm) { advance() }
        case 1: GoalStepView(vm: vm) { advance() }
        case 2: DaysStepView(vm: vm) { advance() }
        default: BuildingProgramView(vm: vm) { finish() }
        }
    }

    private func stepName(_ step: Int) -> String {
        switch step {
        case 0: return "name"
        case 1: return "goal"
        case 2: return "days"
        default: return "building_program"
        }
    }
'''

MODELE = '''
    static let totalSteps = 4

    func canProceed(fromStep step: Int) -> Bool {
        switch step {
        case 0: return !name.isEmpty
        case 1: return goal != nil
        case 2: return !days.isEmpty
        default: return true
        }
    }
'''

VUE_PROPRE = {"NameStepView.swift": '''
struct NameStepView: View {
    var body: some View {
        ObNext(disabled: !vm.peutContinuer, action: onNext)
    }
}
'''}


def griefs(vues=VUE_PROPRE, conteneur=CONTENEUR, modele=MODELE):
    return ck.problemes(vues=vues, conteneur=conteneur, modele=modele)


@cas_test("un ensemble cohérent ne produit aucun grief")
def _():
    assert griefs() == [], griefs()


@cas_test("UNE VUE QUI ÉCRIT SON NUMÉRO EST SIGNALÉE")
def _():
    # C'est le défaut d'origine : la vue des jours interrogeait l'étape 5 après qu'une étape se
    # fut insérée avant elle, donc elle validait les réponses de sa voisine.
    vue = {"DaysStepView.swift": "ObNext(disabled: !vm.canProceed(fromStep: 5), action: onNext)"}
    g = griefs(vues={**VUE_PROPRE, **vue})
    assert len(g) == 1 and g[0].startswith("DaysStepView.swift écrit"), g


@cas_test("un numéro cité dans un commentaire n'est pas un appel")
def _():
    vue = {"DaysStepView.swift": "// surtout pas canProceed(fromStep: 5)\nObNext(disabled: !vm.peutContinuer)"}
    assert griefs(vues={**VUE_PROPRE, **vue}) == []


@cas_test("UNE ÉTAPE OUBLIÉE PAR LA VALIDATION EST SIGNALÉE")
def _():
    # Ajouter une étape à l'aiguillage sans l'ajouter au `switch` de validation donne un écran
    # qui s'affiche et ne se valide jamais.
    modele = MODELE.replace("case 2: return !days.isEmpty\n", "")
    g = griefs(modele=modele)
    assert len(g) == 1 and "la validation ne traite pas l'étape 2" in g[0], g


@cas_test("une étape oubliée par les statistiques est signalée")
def _():
    conteneur = CONTENEUR.replace('        case 2: return "days"\n', "")
    g = griefs(conteneur=conteneur)
    assert len(g) == 1 and "statistiques ne traite pas l'étape 2" in g[0], g


@cas_test("une étape oubliée par l'aiguillage est signalée")
def _():
    conteneur = CONTENEUR.replace("        case 2: DaysStepView(vm: vm) { advance() }\n", "")
    g = griefs(conteneur=conteneur)
    assert len(g) == 1 and "aiguillage des vues ne traite pas l'étape 2" in g[0], g


@cas_test("UNE ÉTAPE AJOUTÉE À `totalSteps` ET NULLE PART AILLEURS EST SIGNALÉE TROIS FOIS")
def _():
    # Le sens de la vérification : c'est `totalSteps` qui fait foi, et les trois listes qui
    # doivent le suivre.
    modele = MODELE.replace("totalSteps = 4", "totalSteps = 5")
    g = griefs(modele=modele)
    assert len(g) == 3, g


@cas_test("un `switch` sans `default` est signalé")
def _():
    modele = MODELE.replace("        default: return true\n", "")
    g = griefs(modele=modele)
    assert any("n'a pas de `default`" in x for x in g), g


@cas_test("l'absence de `totalSteps` est elle-même un grief")
def _():
    g = griefs(modele=MODELE.replace("static let totalSteps = 4", ""))
    assert any("introuvable" in x for x in g), g


@cas_test("le dépôt tel qu'il est passe")
def _():
    assert ck.problemes() == [], ck.problemes()


def main() -> int:
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  FAIL {nom}\n       {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
