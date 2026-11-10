#!/usr/bin/env python3
"""Les cas de `check_manifeste.py`.

CE QU'ILS GARDENT. `RunUpWatch` n'embarque aucun manifeste de confidentialité, et c'est licite
aujourd'hui : la cible n'appelle aucune API à motif obligatoire, et un envoi du 10 novembre 2026
contenant `RunUp.app/Watch/RunUpWatch.app` passe la validation d'Apple sans une erreur.

Une seule ligne rendrait ça faux — un `UserDefaults` écrit dans la montre pour y garder un
réglage. Elle compile, les tests passent, et le refus tombe à l'ENVOI, après quinze minutes
d'archive. Le premier cas ci-dessous est exactement celui-là.

ET CE QUE LE CONTRÔLE NE DOIT PAS FAIRE SONNER : une cible qui porte son manifeste, et une cible
de test, qui ne part jamais chez Apple.
"""
import pathlib
import sys
import tempfile

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import check_manifeste as ck  # noqa: E402

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


def plaintes(fichiers, cibles):
    return ck.verifier(faux_depot(fichiers), {"targets": cibles})


MONTRE = {"type": "application", "sources": [{"path": "Montre"}]}


# ─── LE RISQUE RÉEL ────────────────────────────────────────────────────────────────────────────

@cas_de("un UserDefaults dans une cible sans manifeste sonne")
def _():
    p = plaintes({"Montre/App.swift": 'let x = UserDefaults.standard.bool(forKey: "k")\n'},
                 {"RunUpWatch": MONTRE})
    assert any("ITMS-91053" in m and "UserDefaults" in m for m in p), p


@cas_de("le message nomme la catégorie à déclarer ET le fichier fautif")
def _():
    p = plaintes({"Montre/App.swift": "let d = ProcessInfo.processInfo.systemUptime\n"},
                 {"RunUpWatch": MONTRE})
    assert any("NSPrivacyAccessedAPICategorySystemBootTime" in m for m in p), p
    assert any("Montre/App.swift" in m for m in p), p


@cas_de("les cinq familles d'API à motif obligatoire sont reconnues")
def _():
    lignes = {
        "NSPrivacyAccessedAPICategoryUserDefaults": "UserDefaults.standard\n",
        "NSPrivacyAccessedAPICategoryFileTimestamp": "f.contentModificationDate\n",
        "NSPrivacyAccessedAPICategorySystemBootTime": "p.systemUptime\n",
        "NSPrivacyAccessedAPICategoryDiskSpace": "u.volumeAvailableCapacity\n",
        "NSPrivacyAccessedAPICategoryActiveKeyboards": "k.activeInputModes\n",
    }
    for categorie, ligne in lignes.items():
        p = plaintes({"Montre/App.swift": ligne}, {"RunUpWatch": MONTRE})
        assert any(categorie in m for m in p), f"{categorie} n'a pas été vue : {p}"


# ─── CE QUI NE DOIT PAS SONNER ─────────────────────────────────────────────────────────────────

@cas_de("la même cible AVEC son manifeste ne sonne pas")
def _():
    p = plaintes({"Montre/App.swift": "UserDefaults.standard\n",
                  "Montre/PrivacyInfo.xcprivacy": "<plist/>\n"},
                 {"RunUpWatch": MONTRE})
    assert p == [], p


@cas_de("une cible de test n'est pas regardée : elle ne part pas chez Apple")
def _():
    p = plaintes({"Tests/T.swift": "UserDefaults.standard\n"},
                 {"Tests": {"type": "bundle.unit-test", "sources": [{"path": "Tests"}]}})
    assert p == [], p


@cas_de("une cible qui n'appelle rien et n'a pas de manifeste ne sonne pas")
def _():
    # C'est l'état de `RunUpWatch` aujourd'hui, et il est licite : rien à déclarer, rien à
    # refuser. Faire sonner ici imposerait un manifeste vide à toute cible, ce qu'Apple ne
    # demande pas.
    p = plaintes({"Montre/App.swift": "Text(\"Courir\")\n"}, {"RunUpWatch": MONTRE})
    assert p == [], p


@cas_de("une API nommée dans un commentaire ne compte pas")
def _():
    src = "// la montre n'appelle pas UserDefaults, et c'est ce qui la dispense de manifeste\n"
    assert plaintes({"Montre/App.swift": src}, {"RunUpWatch": MONTRE}) == []


@cas_de("une API nommée dans une chaîne ne compte pas")
def _():
    assert plaintes({"Montre/App.swift": 'let s = "UserDefaults"\n'}, {"RunUpWatch": MONTRE}) == []


@cas_de("un fichier exclu des sources n'est pas lu")
def _():
    # `excludes` décide ce que la cible COMPILE. Un fichier qu'elle ne compile pas ne peut pas
    # l'exposer à un refus.
    p = plaintes({"Montre/App.swift": "Text()\n", "Montre/Vieux.swift": "UserDefaults.standard\n"},
                 {"RunUpWatch": {"type": "application",
                                 "sources": [{"path": "Montre", "excludes": ["Vieux.swift"]}]}})
    assert p == [], p


# ─── SUR LE VRAI DÉPÔT ─────────────────────────────────────────────────────────────────────────

@cas_de("le vrai dépôt : chaque cible livrée est en règle")
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
