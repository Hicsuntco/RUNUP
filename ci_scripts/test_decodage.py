#!/usr/bin/env python3
"""Ce que `check_decodage.py` doit voir, et ce qu'il ne doit pas inventer.

Les cas sont des EXTRAITS FIGÉS, écrits ici à la main. Un test qui relirait le dépôt pour
vérifier qu'il attrape une faute passerait tant que la faute est là, et échouerait à la seconde
où elle est corrigée.
"""

import sys

import check_decodage as ck

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
    var journee: Journee
    var tracé: [Point] = []
}
'''

TOLERANTE = '''
struct Journee: Codable, Equatable {
    var jour: Int
    var seance: Seance?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        jour = try c.decodeIfPresent(Int.self, forKey: .jour) ?? 0
        seance = try c.decodeIfPresent(Seance.self, forKey: .seance)
    }

    private enum CodingKeys: String, CodingKey { case jour, seance }
}

struct Seance: Codable {
    var titre: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        titre = try c.decodeIfPresent(String.self, forKey: .titre) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case titre }
}

struct Point: Codable {
    var lat: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lat = try c.decodeIfPresent(Double.self, forKey: .lat) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case lat }
}
'''


def griefs(*sources):
    return ck.problemes(list(sources))


@cas_test("un ensemble tolérant ne produit aucun grief")
def _():
    assert griefs(MODELE, TOLERANTE) == [], griefs(MODELE, TOLERANTE)


@cas_test("une structure enregistrée sans `init(from:)` est signalée")
def _():
    sans = TOLERANTE.replace('''
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        titre = try c.decodeIfPresent(String.self, forKey: .titre) ?? ""
    }
''', "")
    g = griefs(MODELE, sans)
    assert len(g) == 1 and g[0].startswith("Seance"), g


@cas_test("un `decode` dans un `init(from:)` enregistré est signalé")
def _():
    fautif = TOLERANTE.replace(
        'titre = try c.decodeIfPresent(String.self, forKey: .titre) ?? ""',
        'titre = try c.decode(String.self, forKey: .titre)')
    g = griefs(MODELE, fautif)
    assert len(g) == 1 and g[0].startswith("Seance.init(from:) appelle"), g


@cas_test("LA STRUCTURE IMBRIQUÉE DEUX CRANS PLUS LOIN EST DANS LE PÉRIMÈTRE")
def _():
    # `Seance` n'est pas une propriété du modèle : elle est une propriété de `Journee`, qui en
    # est une. C'est exactement le chemin de la panne d'origine — l'accueil lisait les séances
    # de la semaine, et c'est deux niveaux plus bas que le décodage tombait.
    fautif = TOLERANTE.replace(
        'titre = try c.decodeIfPresent(String.self, forKey: .titre) ?? ""',
        'titre = try c.decode(String.self, forKey: .titre)')
    assert any(g.startswith("Seance") for g in griefs(MODELE, fautif))


@cas_test("une structure Codable qui n'est PAS enregistrée est ignorée")
def _():
    libre = '''
struct ReponseReseau: Codable {
    var jeton: String
}
'''
    assert griefs(MODELE, TOLERANTE, libre) == [], griefs(MODELE, TOLERANTE, libre)


@cas_test("une structure non Codable homonyme ne prend pas la place d'une enregistrée")
def _():
    # Trois `struct State: Equatable` sans rapport vivent dans l'app, et l'énumération
    # `DayStatus.State`, elle, est enregistrée. Sans le filtre `Codable`, l'homonymie faisait
    # accuser les premières.
    modele = MODELE.replace("var journee: Journee", "var etat: State")
    homonyme = "struct State: Equatable { var x: Int }\n"
    vraie = "enum State: String, Codable { case a, b }\n"
    assert griefs(modele, TOLERANTE, homonyme, vraie) == []


@cas_test("UNE PROPRIÉTÉ CALCULÉE N'AMÈNE AUCUN TYPE DANS LE PÉRIMÈTRE")
def _():
    # `var repKm: Double { … }` ne se décode pas : elle n'a pas de clé. Compter son type
    # élargirait le périmètre à des structures que personne n'enregistre.
    avec_calculee = TOLERANTE.replace(
        "struct Point: Codable {",
        "struct Point: Codable {\n    var vue: ReponseReseau { ReponseReseau() }")
    libre = "struct ReponseReseau: Codable { var jeton: String }\n"
    assert griefs(MODELE, avec_calculee, libre) == []


@cas_test("un `decode` cité dans un commentaire n'est pas un appel")
def _():
    commente = TOLERANTE.replace(
        "        let c = try decoder.container(keyedBy: CodingKeys.self)\n        titre",
        "        // Surtout pas de c.decode(String.self, forKey: .titre) ici.\n"
        "        let c = try decoder.container(keyedBy: CodingKeys.self)\n        titre")
    assert griefs(MODELE, commente) == [], griefs(MODELE, commente)


@cas_test("l'absence de toute classe @Model est elle-même un grief")
def _():
    # Sans modèle, le script ne vérifie plus rien et le dirait vert. Une cible renommée, un
    # dossier déplacé, et le garde-fou se tairait pour toujours.
    g = griefs(TOLERANTE)
    assert len(g) == 1 and "Aucune classe" in g[0], g


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
