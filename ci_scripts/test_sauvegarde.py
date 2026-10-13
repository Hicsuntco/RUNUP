#!/usr/bin/env python3
"""Ce que `check_sauvegarde.py` doit voir, et ce qu'il ne doit pas inventer.

Les cas sont des EXTRAITS FIGÉS, écrits ici à la main. Un test qui relirait le dépôt pour
vérifier qu'il attrape une faute passerait tant que la faute est là, et échouerait à la seconde
où elle est corrigée.
"""

import sys

import check_sauvegarde as ck

cas = []


def cas_test(nom):
    def prendre(f):
        cas.append((nom, f))
        return f
    return prendre


MODELE = '''
@Model
final class Profil {
    var nom: String
    var serie: Int
    var premium: Bool
    /// Calculée — elle ne va pas sur le disque.
    var seriePerdue: Bool {
        serie == 0
    }
}
'''

SAUVEGARDE = '''
struct Sauvegarde: Codable {
    static let correspondances: [String: String] = [
        "Profil": "ProfilSauve",
    ]
    static let modelesIgnores: [String: String] = [:]
    static let nonSauvegardees: [String: String] = [
        "Profil.premium": "L'abonnement se lit chez StoreKit.",
    ]
}

extension Sauvegarde {
    struct ProfilSauve: Codable {
        var nom: String?
        var serie: Int?
    }
}
'''

# `SauvegardeService` : la recopie du modèle vers la sauvegarde. Un champ déclaré mais absent
# d'ici sort à `nil` dans tous les fichiers écrits.
SERVICE = '''
extension Sauvegarde.ProfilSauve {
    init(_ m: Profil) {
        self.init()
        nom = m.nom
        serie = m.serie
    }
}
'''


@cas_test("un extrait complet et cohérent passe")
def _():
    assert ck.problemes([MODELE], SAUVEGARDE, SERVICE) == []


@cas_test("une propriété ni sauvegardée ni inscrite est signalée")
def _():
    modele = MODELE.replace("var serie: Int", "var serie: Int\n    var xp: Int")
    griefs = ck.problemes([modele], SAUVEGARDE, SERVICE)
    assert len(griefs) == 1, griefs
    assert "Profil.xp" in griefs[0], griefs[0]


@cas_test("une propriété CALCULÉE n'est pas réclamée")
def _():
    # `seriePerdue` est déjà dans `MODELE` et le premier cas passe ; celui-ci fixe la raison,
    # pour qu'une régression du détecteur de propriétés calculées ne se lise pas comme un
    # champ oublié.
    assert all("seriePerdue" not in g for g in ck.problemes([MODELE], SAUVEGARDE, SERVICE))


@cas_test("une structure imbriquée dans le modèle n'apporte pas ses champs")
def _():
    # LE CAS RÉEL : `RunRecord` déclare `struct RoutePoint` à l'intérieur de lui-même, et ses
    # lat/lng/altitude se lisaient comme trois propriétés du modèle.
    modele = MODELE.replace("var nom: String", """struct Point: Codable {
        var lat: Double
        var lng: Double
    }
    var nom: String""")
    assert ck.problemes([modele], SAUVEGARDE, SERVICE) == [], ck.problemes([modele], SAUVEGARDE, SERVICE)


@cas_test("une variable locale d'une fonction n'est pas une propriété")
def _():
    modele = MODELE.replace("var nom: String", """func compter() -> Int {
        var total = 0
        return total
    }
    var nom: String""")
    assert ck.problemes([modele], SAUVEGARDE, SERVICE) == [], ck.problemes([modele], SAUVEGARDE, SERVICE)


@cas_test("une raison vide ne compte pas comme une décision")
def _():
    src = SAUVEGARDE.replace('"L\'abonnement se lit chez StoreKit."', '""')
    griefs = ck.problemes([MODELE], src, SERVICE)
    assert len(griefs) == 1 and "aucune raison" in griefs[0], griefs


@cas_test("un champ de la sauvegarde sans propriété derrière est signalé")
def _():
    src = SAUVEGARDE.replace("var serie: Int?", "var serie: Int?\n        var ancienChamp: Int?")
    griefs = ck.problemes([MODELE], src, SERVICE)
    assert len(griefs) == 1 and "ancienChamp" in griefs[0], griefs


@cas_test("une entrée `nonSauvegardees` périmée est signalée")
def _():
    src = SAUVEGARDE.replace('"Profil.premium": "L\'abonnement se lit chez StoreKit.",',
                             '"Profil.premium": "L\'abonnement se lit chez StoreKit.",\n'
                             '        "Profil.disparu": "une raison d\'hier",')
    griefs = ck.problemes([MODELE], src, SERVICE)
    assert len(griefs) == 1 and "Profil.disparu" in griefs[0], griefs


@cas_test("sauvegardé ET inscrit dehors : contradiction signalée")
def _():
    src = SAUVEGARDE.replace("var serie: Int?", "var serie: Int?\n        var premium: Bool?")
    griefs = ck.problemes([MODELE], src, SERVICE)
    assert len(griefs) == 1 and "ne peuvent pas être vrais" in griefs[0], griefs


@cas_test("un modèle que la sauvegarde ne connaît pas est signalé")
def _():
    modele = MODELE + '''
@Model
final class Chaussure {
    var nom: String
}
'''
    griefs = ck.problemes([modele], SAUVEGARDE, SERVICE)
    assert len(griefs) == 1 and "Chaussure" in griefs[0], griefs


@cas_test("un modèle entièrement ignoré, avec sa raison, passe")
def _():
    modele = MODELE + '''
@Model
final class Alerte {
    var texte: String
}
'''
    src = SAUVEGARDE.replace('static let modelesIgnores: [String: String] = [:]',
                             'static let modelesIgnores: [String: String] = ['
                             '"Alerte": "Le centre se reconstruit tout seul."]')
    assert ck.problemes([modele], src, SERVICE) == [], ck.problemes([modele], src, SERVICE)


@cas_test("un modèle ignoré SANS raison est signalé")
def _():
    modele = MODELE + '''
@Model
final class Alerte {
    var texte: String
}
'''
    src = SAUVEGARDE.replace('static let modelesIgnores: [String: String] = [:]',
                             'static let modelesIgnores: [String: String] = ["Alerte": ""]')
    griefs = ck.problemes([modele], src, SERVICE)
    assert len(griefs) == 1 and "aucune raison" in griefs[0], griefs


@cas_test("une correspondance qui désigne une structure inexistante est signalée")
def _():
    src = SAUVEGARDE.replace('"Profil": "ProfilSauve",', '"Profil": "Absente",')
    griefs = ck.problemes([MODELE], src, SERVICE)
    assert len(griefs) == 1 and "Absente" in griefs[0], griefs


@cas_test("sans aucun modèle, le script le dit au lieu de passer")
def _():
    assert ck.problemes([""], SAUVEGARDE) != []


@cas_test("les trois tables manquantes font échouer au lieu de passer")
def _():
    griefs = ck.problemes([MODELE], "struct Sauvegarde: Codable {}")
    assert len(griefs) == 3, griefs


@cas_test("un champ déclaré mais jamais rempli est signalé")
def _():
    # LA PANNE LA PLUS SILENCIEUSE : le champ existe, l'export marche, la restauration réussit,
    # et la donnée n'a jamais quitté le téléphone.
    src = SAUVEGARDE.replace("var serie: Int?", "var serie: Int?\n        var xp: Int?")
    modele = MODELE.replace("var serie: Int", "var serie: Int\n    var xp: Int")
    griefs = ck.problemes([modele], src, SERVICE)
    assert len(griefs) == 1 and "jamais rempli" in griefs[0], griefs


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
