#!/usr/bin/env python3
"""Ce que `check_healthkit.py` doit voir, et ce qu'il ne doit pas inventer.

Les cas négatifs sont des EXTRAITS FIGÉS, écrits ici à la main. Un test qui relirait le dépôt
pour vérifier qu'il attrape une faute passerait tant que la faute est là, et échouerait à la
seconde où elle est corrigée — c'est arrivé une fois dans ce dépôt, et une fois suffit.
"""

import sys

import check_healthkit as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


# Une classe correcte, en miniature : deux portes, chacune avec son garde.
PROPRE = '''
@Observable
final class HealthKitService {
    private let store = HKHealthStore()

    nonisolated(unsafe) private static var desactivee = false

    static func desactiver() { desactivee = true }

    static var isHealthDataAvailable: Bool { !desactivee && HKHealthStore.isHealthDataAvailable() }

    func stepsToday() async -> Double {
        guard Self.isHealthDataAvailable else { return 0 }
        return 1
    }

    private func sum() async -> Double {
        return 2
    }
}

private final class RouteAccumulator {
    func add(_ p: Int) {
        points += p
    }
}
'''

# La même, avec une porte ajoutée sans son garde — exactement la régression qu'on craint.
NUE = PROPRE.replace('''    func stepsToday() async -> Double {
        guard Self.isHealthDataAvailable else { return 0 }
        return 1
    }
''', '''    func stepsToday() async -> Double {
        guard Self.isHealthDataAvailable else { return 0 }
        return 1
    }

    func activeCaloriesToday() async -> Double {
        return await sum()
    }
''')


@cas_test("une classe entièrement gardée ne déclenche rien")
def _():
    assert ck.sans_garde(PROPRE) == [], ck.sans_garde(PROPRE)


@cas_test("une porte sans garde est nommée")
def _():
    nus = ck.sans_garde(NUE)
    assert [n for n, _ in nus] == ["activeCaloriesToday"], nus


@cas_test("les méthodes d'une AUTRE classe du même fichier sont ignorées")
def _():
    # `RouteAccumulator.add` est à quatre espaces d'indentation, comme les portes de Santé, et
    # n'a aucun garde. La première version de ce test la signalait.
    assert "add" not in [n for n, _ in ck.sans_garde(PROPRE)]


@cas_test("une méthode privée n'est pas une porte")
def _():
    assert "sum" not in [n for n, _ in ck.sans_garde(PROPRE)]


@cas_test("le coupe-circuit lui-même est dispensé de se garder")
def _():
    assert "desactiver" not in [n for n, _ in ck.sans_garde(PROPRE)]


@cas_test("un coupe-circuit absent est refusé")
def _():
    assert ck.coupe_circuit_present(PROPRE)
    sans = PROPRE.replace("static func desactiver() { desactivee = true }", "")
    assert not ck.coupe_circuit_present(sans)


@cas_test("un drapeau que la disponibilité ne consulte plus est refusé")
def _():
    # Le cas vicieux : `desactiver()` existe toujours, donc tout a l'air en place, mais
    # `isHealthDataAvailable` ne le lit plus — le coupe-circuit est débranché.
    debranche = PROPRE.replace(
        "static var isHealthDataAvailable: Bool { !desactivee && HKHealthStore.isHealthDataAvailable() }",
        "static var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }")
    assert not ck.coupe_circuit_present(debranche)


@cas_test("le numéro de ligne rapporté est celui de la déclaration")
def _():
    nus = ck.sans_garde(NUE)
    ligne = nus[0][1]
    assert NUE.splitlines()[ligne - 1].strip().startswith("func activeCaloriesToday"), \
        NUE.splitlines()[ligne - 1]


@cas_test("le vrai HealthKitService passe")
def _():
    assert ck.main() == 0, "check_healthkit.py refuse le dépôt"


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f(); print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1; print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
