#!/usr/bin/env python3
"""Le contrôle de `check_reseau` se trompe-t-il ? On le vérifie dans les deux sens.

Un contrôle qui ne rapporte jamais rien est indistinguable d'un contrôle cassé. Celui-ci est donc
éprouvé sur des cas plantés : du code qui doit échouer, et du code qui doit passer.
"""
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_reseau as ck  # noqa: E402
import check_strings as cs  # noqa: E402

DOIT_ECHOUER = [
    'errorMessage = String(localized: "Impossible de charger — vérifie ta connexion.")',
    'errorMessage = String(localized: "Connexion impossible — vérifie ta connexion internet.")',
    'Text("Connexion coupée — réessaie.")',
    'appState.toast(String(localized: "Pas de connexion, réessaie plus tard."))',
    'Text("Tu es hors ligne.")',
    'errorMessage = String(localized: "Réessaie quand tu auras du réseau.")',
    'LocalizedStringKey("Vérifie ton réseau et recommence")',
    # Le littéral est lu caractère par caractère : une interpolation qui contient sa propre chaîne
    # ne doit pas arrêter la lecture avant la tournure interdite.
    'Text("\\(String(format: "%.1f", km)) km — vérifie ta connexion")',
]

DOIT_PASSER = [
    # La bonne façon de le dire.
    'errorMessage = PanneReseau.phrase(pour: error)',
    'identityError = PanneReseau.motif(pour: error)',
    # Le mot « connexion » seul : c'est le titre de l'écran de connexion, et un bouton.
    'Text("Connexion")',
    'Text("Se connecter avec Apple")',
    'Text("Connexion avec Apple")',
    # Une vraie phrase de panne, mais qui ne nomme pas le réseau.
    'Text("RUNUP ne répond pas pour l\'instant — réessaie dans un moment.")',
    'Text("Ta session a expiré — reconnecte-toi.")',
    # En commentaire, la tournure est licite : c'est ainsi qu'on explique le défaut qu'on répare.
    '// affichait « vérifie ta connexion » pour une session expirée',
    '/// Voir `PanneReseau` : « vérifie ta connexion » était affirmé à tort.',
    # Et une chaîne qui n'est pas affichée n'est pas concernée.
    'let cle = "verifie_ta_connexion"',
]


def lance(ligne: str) -> int:
    """Le contrôle, lancé sur un faux projet d'un seul fichier."""
    with tempfile.TemporaryDirectory() as tmp:
        racine = pathlib.Path(tmp)
        (racine / "RunUp" / "Views").mkdir(parents=True)
        (racine / "RunUp" / "Views" / "Faux.swift").write_text(ligne + "\n", encoding="utf-8")
        vraie_racine, vrais_dossiers = cs.RACINE, cs.DOSSIERS
        cs.RACINE, cs.DOSSIERS = racine, ["RunUp"]
        try:
            return len(ck.fautes())
        finally:
            cs.RACINE, cs.DOSSIERS = vraie_racine, vrais_dossiers


def main() -> int:
    echecs = []
    for ligne in DOIT_ECHOUER:
        if lance(ligne) == 0:
            echecs.append(("devait être rejetée", ligne))
    for ligne in DOIT_PASSER:
        n = lance(ligne)
        if n:
            echecs.append(("devait passer", ligne))

    total = len(DOIT_ECHOUER) + len(DOIT_PASSER)
    if echecs:
        print(f"{len(echecs)} cas sur {total} se comportent mal :\n", file=sys.stderr)
        for quoi, ligne in echecs:
            print(f"  {quoi} : {ligne}", file=sys.stderr)
        return 1
    print(f"\n{total}/{total} cas passent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
