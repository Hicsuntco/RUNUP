#!/usr/bin/env python3
"""Les cas de `check_degrade.py`.

CE QU'ILS EMPÊCHENT DE REVENIR. Vingt-quatre fichiers portaient un dégradé, et personne n'avait
mal travaillé : UN jeton du système de design le distribuait, et les écrans l'appelaient comme il
faut. Un garde-fou qui compte les dégradés par fichier ne vaut donc que s'il compte juste — et
la moitié des fichiers de ce dépôt NOMMENT un dégradé dans le commentaire qui raconte son départ.

Les cas « un dégradé cité dans un commentaire ne compte pas » sont là pour ça. Sans eux, le
garde-fou refuserait un fichier pour la phrase qui explique sa correction.

ET CEUX QUI DISENT L'INVERSE. Une liste d'exceptions est une porte : les cas « un de plus sonne »
et « un de moins sonne » vérifient qu'elle ne s'ouvre pas plus large qu'écrit.
"""
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_degrade as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def faux_depot(fichiers):
    """Un dossier temporaire : {chemin relatif → contenu Swift}."""
    racine = pathlib.Path(tempfile.mkdtemp())
    for chemin, contenu in fichiers.items():
        f = racine / chemin
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(contenu, encoding="utf-8")
    return racine


def plaintes(fichiers, permis):
    return ck.verifier(faux_depot(fichiers), permis)


UN = "Circle().fill(LinearGradient(colors: [a, b], startPoint: .top, endPoint: .bottom))\n"


# ─── LE DÉFAUT D'ORIGINE ───────────────────────────────────────────────────────────────────────

@cas_de("un dégradé dans un fichier non listé sonne")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": UN}, {})
    assert any("Ecran.swift" in m and "règle 7" in m for m in p), p


@cas_de("le même dégradé, listé avec sa raison, ne sonne pas")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": UN},
                 {"RunUp/Views/Ecran.swift": (1, "le voile qui rend le titre lisible")})
    assert p == [], p


@cas_de("un de plus que ce que la raison couvre sonne")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": UN * 2},
                 {"RunUp/Views/Ecran.swift": (1, "une raison pour un seul")})
    assert any("2 dégradé(s), 1 autorisé(s)" in m for m in p), p


@cas_de("un de moins sonne aussi : l'exception a cessé de servir")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": UN},
                 {"RunUp/Views/Ecran.swift": (2, "deux raisons")})
    assert any("Retire-la" in m for m in p), p


@cas_de("un fichier listé qui n'en porte plus aucun sonne")
def _():
    # Une exception qui dort est une porte ouverte sur un fichier que plus personne ne relit.
    p = plaintes({"RunUp/Views/Ecran.swift": "let x = 1\n"},
                 {"RunUp/Views/Ecran.swift": (1, "une raison périmée")})
    assert any("encore dans `PERMIS`" in m for m in p), p


# ─── CE QUE LE GARDE-FOU NE DOIT PAS COMPTER ───────────────────────────────────────────────────

@cas_de("un dégradé nommé dans un commentaire // ne compte pas")
def _():
    src = "// C'était un LinearGradient(colors: [rose, violet]) et il est parti.\nlet x = 1\n"
    assert plaintes({"RunUp/Views/Ecran.swift": src}, {}) == []


@cas_de("un dégradé nommé dans un commentaire de documentation /// ne compte pas")
def _():
    src = "/// `accentGradient` était un LinearGradient(...). Règle 7.\nlet x = 1\n"
    assert plaintes({"RunUp/Views/Ecran.swift": src}, {}) == []


@cas_de("un dégradé nommé dans un bloc /* */ ne compte pas")
def _():
    src = "/* RadialGradient(colors: []) vivait ici */\nlet x = 1\n"
    assert plaintes({"RunUp/Views/Ecran.swift": src}, {}) == []


@cas_de("un dégradé nommé dans une chaîne ne compte pas")
def _():
    src = 'let message = "LinearGradient(colors: [])"\n'
    assert plaintes({"RunUp/Views/Ecran.swift": src}, {}) == []


@cas_de("un commentaire ne masque pas le code de la ligne suivante")
def _():
    # Le piège inverse : un effaceur de commentaires trop gourmand rendrait le script aveugle.
    src = "// un LinearGradient( de commentaire\n" + UN
    p = plaintes({"RunUp/Views/Ecran.swift": src}, {})
    assert any("1 dégradé" in m or "règle 7" in m for m in p), p


@cas_de("un angle nommé `gradientStartDegrees` n'est pas un dégradé")
def _():
    # `DailyGoalsWidget` lit `seg.gradientStartDegrees`. Le compter ferait sonner le fichier
    # pour un nombre de degrés.
    src = "let a = seg.gradientStartDegrees\nlet b = seg.gradientEndDegrees\n"
    assert plaintes({"RunUp/Views/Ecran.swift": src}, {}) == []


@cas_de("le raccourci `.gradient` de SwiftUI compte")
def _():
    # Une première version excluait ce cas par une anti-recherche arrière sur `[\\w.]` — or il
    # est TOUJOURS précédé d'un identifiant. Elle ne voyait donc que ce qui n'existe pas.
    p = plaintes({"RunUp/Views/Ecran.swift": "Circle().fill(RUColor.rose.gradient)\n"}, {})
    assert any("règle 7" in m for m in p), p


@cas_de("les quatre autres formes de dégradé comptent aussi")
def _():
    for forme in ["RadialGradient", "AngularGradient", "EllipticalGradient", "MeshGradient"]:
        src = f"Circle().fill({forme}(colors: []))\n"
        p = plaintes({"RunUp/Views/Ecran.swift": src}, {})
        assert any("règle 7" in m for m in p), f"{forme} est passé : {p}"


@cas_de("un fichier sans aucun dégradé ne sonne pas")
def _():
    assert plaintes({"RunUp/Views/Ecran.swift": "Circle().fill(RUColor.rose)\n"}, {}) == []


# ─── SUR LE VRAI DÉPÔT ─────────────────────────────────────────────────────────────────────────

@cas_de("chaque exception du vrai dépôt porte une raison lisible")
def _():
    # Une liste d'exceptions sans raisons devient une liste de passe-droits. Celle-ci doit se
    # relire : une raison d'une ligne ne dit rien.
    for fichier, (n, raison) in ck.PERMIS.items():
        assert n >= 1, f"{fichier} : {n} autorisé(s)"
        assert len(raison) >= 60, f"{fichier} : raison trop courte pour être une raison"


@cas_de("le vrai dépôt ne porte aucun dégradé décoratif")
def _():
    p = ck.verifier()
    assert p == [], "\n".join(p)


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
