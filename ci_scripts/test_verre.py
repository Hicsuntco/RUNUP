#!/usr/bin/env python3
"""Les cas de `check_verre.py`.

CE QU'ILS EMPÊCHENT DE REVENIR. Douze `.ultraThinMaterial` dans sept fichiers, dont quatre posés
DEVANT une surface déjà opaque à plus de 90 % : ils ne floutaient presque rien et coûtaient une
couche de composition sur l'écran le plus vu de l'app.

ET CE QUE LE GARDE-FOU LUI-MÊME POURRAIT RATER. Son expression doit voir `.bar` — qui est bien un
`Material` de SwiftUI — sans voir `chart.bar.fill` ni `RUSpacing.tabBarHeight`, qui n'en sont pas.
Les deux cas « ce n'est PAS un verre » sont là pour ça : un garde-fou qui refuse un nom de symbole
bloque le dépôt sur rien, et on finit par le désactiver.
"""
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_verre as ck  # noqa: E402

cas = []


def cas_de(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def faux_depot(fichiers):
    racine = pathlib.Path(tempfile.mkdtemp())
    for chemin, contenu in fichiers.items():
        f = racine / chemin
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(contenu, encoding="utf-8")
    return racine


def plaintes(fichiers, permis=None):
    return ck.verifier(faux_depot(fichiers), {} if permis is None else permis)


UN = ".background(.ultraThinMaterial, in: Capsule())\n"


# ─── LE DÉFAUT D'ORIGINE ───────────────────────────────────────────────────────────────────────

@cas_de("un verre dépoli dans un fichier non listé sonne")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": UN})
    assert any("Ecran.swift" in m and "règle 7" in m.lower() for m in p), p


@cas_de("deux dans le même fichier sont comptés comme deux")
def _():
    # Le sélecteur de discipline en portait exactement deux, et `LiveRunView` quatre.
    p = plaintes({"RunUp/Views/Ecran.swift": UN * 2})
    assert any("2 verre(s)" in m for m in p), p


@cas_de("le même, listé avec sa raison, ne sonne pas")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": UN},
                 {"RunUp/Views/Ecran.swift": (1, "une raison écrite quelque part")})
    assert p == [], p


@cas_de("un de plus que ce que la raison couvre sonne")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": UN * 2},
                 {"RunUp/Views/Ecran.swift": (1, "une raison pour un seul")})
    assert any("2 verre(s), 1 autorisé(s)" in m for m in p), p


@cas_de("un de moins sonne aussi : l'exception a cessé de servir")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": UN},
                 {"RunUp/Views/Ecran.swift": (2, "deux raisons")})
    assert any("Retire-la" in m for m in p), p


@cas_de("un fichier listé qui n'en porte plus aucun sonne")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": "let x = 1\n"},
                 {"RunUp/Views/Ecran.swift": (1, "une raison périmée")})
    assert any("encore dans `PERMIS`" in m for m in p), p


# ─── LES CINQ ÉPAISSEURS, ET `.bar` ────────────────────────────────────────────────────────────

@cas_de("les cinq épaisseurs nommées comptent toutes")
def _():
    for forme in ["ultraThinMaterial", "thinMaterial", "regularMaterial",
                  "thickMaterial", "ultraThickMaterial"]:
        p = plaintes({"RunUp/Views/Ecran.swift": f".background(.{forme})\n"})
        assert p, f"{forme} est passé"


@cas_de("`Material.bar` compte")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": ".background(Material.bar)\n"})
    assert p, p


@cas_de("`.background(.bar)` compte")
def _():
    # `.bar` est un `Material` à part entière, et il s'écrit sans le mot « Material ».
    p = plaintes({"RunUp/Views/Ecran.swift": ".background(.bar, in: Capsule())\n"})
    assert p, p


@cas_de("`chart.bar.fill` n'est PAS un verre dépoli")
def _():
    # Un symbole SF. Le refuser bloquerait le dépôt sur un nom d'icône, et quatre écrans
    # l'emploient aujourd'hui.
    src = 'RUCardHeader(icon: "chart.bar.fill", title: "Volume")\n'
    assert plaintes({"RunUp/Views/Ecran.swift": src}) == []


@cas_de("`RUSpacing.tabBarHeight` n'est PAS un verre dépoli")
def _():
    assert plaintes({"RunUp/Views/Ecran.swift": ".frame(height: RUSpacing.tabBarHeight)\n"}) == []


# ─── CE QUE LE GARDE-FOU NE DOIT PAS COMPTER ───────────────────────────────────────────────────

@cas_de("un verre nommé dans un commentaire // ne compte pas")
def _():
    src = "// C'était un .ultraThinMaterial, et il est parti.\nlet x = 1\n"
    assert plaintes({"RunUp/Views/Ecran.swift": src}) == []


@cas_de("un verre nommé dans un commentaire /// ne compte pas")
def _():
    src = "/// Portait un `.ultraThinMaterial` sous un noir à 45 %. Règle 7.\nlet x = 1\n"
    assert plaintes({"RunUp/Views/Ecran.swift": src}) == []


@cas_de("un verre nommé dans un bloc /* */ ne compte pas")
def _():
    assert plaintes({"RunUp/Views/Ecran.swift": "/* .regularMaterial vivait ici */\nlet x = 1\n"}) == []


@cas_de("un verre nommé dans une chaîne ne compte pas")
def _():
    assert plaintes({"RunUp/Views/Ecran.swift": 'let m = "ultraThinMaterial"\n'}) == []


@cas_de("un commentaire ne masque pas le code de la ligne suivante")
def _():
    p = plaintes({"RunUp/Views/Ecran.swift": "// un .ultraThinMaterial de commentaire\n" + UN})
    assert p, p


# ─── SUR LE VRAI DÉPÔT ─────────────────────────────────────────────────────────────────────────

@cas_de("le vrai dépôt ne porte aucun verre dépoli")
def _():
    p = ck.verifier()
    assert p == [], "\n".join(p)


@cas_de("et la liste d'exceptions est vide — si elle ne l'est plus, chaque raison se lit")
def _():
    for fichier, (n, raison) in ck.PERMIS.items():
        assert n >= 1, f"{fichier} : {n} autorisé(s)"
        assert len(raison) >= 60, (
            f"{fichier} : raison trop courte. Écris ce qu'un flou fait ici qu'un aplat ne "
            f"ferait pas — dans les douze cas d'origine, la réponse était « rien ».")


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
