#!/usr/bin/env python3
"""Le filet de séparation passe-t-il bien par `RUFilet` ?

# POURQUOI CE CONTRÔLE EXISTE

Le trait qui sépare deux lignes était écrit de deux façons dans l'app, et les deux ne
dessinaient pas la même chose.

- `Divider().background(RUColor.line)`, trente fois. Le `Divider` de SwiftUI a SA PROPRE
  épaisseur — un pixel d'écran, soit un tiers de point sur un appareil ×3 — et sa propre
  couleur, un gris système. `.background` ne le recolore pas, elle peint derrière lui. Le
  résultat est un trait trois fois plus fin que celui que le système de dessin prescrit, dans
  une couleur qui n'est pas tout à fait `line`. Et il est annoncé par VoiceOver : trente
  « séparateur » sur l'écran des réglages.
- `Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)`, douze fois. Celui-là est
  juste — et il tient sur une ligne qu'on ne relit pas, donc qu'on recopie.

`RUSpacing.hairline` vaut 1 point et non 0,5, et c'est un choix documenté : la maquette trace
`1px solid var(--ru-line)` partout, sans exception. Un filet qui vaut un tiers de point
contredit ce choix sans jamais le dire — aucun contrôle ne le voyait, et aucune capture non
plus, parce que les écrans qui employaient `Divider` ne sont pas photographiés.

# CE QUI EST REFUSÉ

Dans `RunUp/`, hors `FiletView.swift` : tout `Divider(`, et tout `RUSpacing.hairline` posé en
`frame(height:)` ou `frame(width:)`. Les contours (`stroke(…, lineWidth: RUSpacing.hairline)`)
ne sont pas concernés : ce sont des bordures, pas des filets, et ils n'ont jamais eu de second
idiome.

Les commentaires sont blanchis. Ce contrôle-ci cite les deux formes qu'il refuse, et
`FiletView.swift` les cite aussi pour expliquer pourquoi elles sont parties : un contrôle qui
lit ses propres commentaires signale le fichier qu'il vient de faire corriger. C'est arrivé à
`check_cjs.py` et à `check_cablage.py`, chacun le jour de son écriture.
"""
import pathlib
import re
import sys

ICI = pathlib.Path(__file__).resolve().parent
RACINE = ICI.parent

#: Le composant lui-même : c'est le seul endroit où le filet a le droit d'être dessiné.
DISPENSE = "FiletView.swift"

INTERDITS = (
    (re.compile(r"\bDivider\s*\("),
     "`Divider()` — son épaisseur et sa couleur sont celles du système, pas celles de la "
     "maquette. Employez `RUFilet()`."),
    (re.compile(r"\.frame\(\s*height:\s*RUSpacing\.hairline"),
     "un filet horizontal dessiné à la main. Employez `RUFilet()`."),
    (re.compile(r"\.frame\(\s*width:\s*RUSpacing\.hairline"),
     "un filet vertical dessiné à la main. Employez `RUFilet(.vertical)`."),
)


def sans_commentaires(ligne: str) -> str:
    """La ligne, son commentaire `//` retiré — en suivant les guillemets.

    Un `//` dans une chaîne (une URL, par exemple) n'ouvre pas de commentaire. Les commentaires
    de bloc `/* */` ne sont pas traités : l'app n'en emploie aucun, et le contrôle le vérifie
    plus bas plutôt que de le supposer.
    """
    chaine = None
    i = 0
    while i < len(ligne):
        c = ligne[i]
        if chaine:
            if c == "\\":
                i += 2
                continue
            if c == chaine:
                chaine = None
        elif c == '"':
            chaine = '"'
        elif c == "/" and ligne[i + 1:i + 2] == "/":
            return ligne[:i]
        i += 1
    return ligne


def main() -> int:
    dossier = RACINE / "RunUp"
    if not dossier.is_dir():
        raise SystemExit(f"{dossier} est introuvable : le contrôle regarde au mauvais endroit.")

    fichiers = sorted(dossier.rglob("*.swift"))
    if not fichiers:
        raise SystemExit(f"Aucun .swift sous {dossier} : le contrôle regarde au mauvais endroit.")

    # LE COMPOSANT DOIT EXISTER. Sans cette vérification, supprimer `RUFilet` rendrait le
    # contrôle vert — plus personne n'écrit la forme interdite, et plus personne n'écrit de
    # filet non plus.
    composant = dossier / "Views" / "Components" / DISPENSE
    if not composant.is_file():
        raise SystemExit(f"{composant} est introuvable : le composant que ce contrôle protège "
                         f"n'existe plus.")
    if "struct RUFilet" not in composant.read_text(encoding="utf-8"):
        raise SystemExit(f"{composant} ne déclare plus `RUFilet`.")

    fautes = []
    blocs = []
    emplois = 0
    for p in fichiers:
        texte = p.read_text(encoding="utf-8")
        emplois += len(re.findall(r"\bRUFilet\s*\(", texte))
        if p.name == DISPENSE:
            continue
        for n, ligne in enumerate(texte.splitlines(), 1):
            nue = sans_commentaires(ligne)
            if "/*" in nue:
                blocs.append(f"{p.relative_to(RACINE)}:{n}")
            for motif, pourquoi in INTERDITS:
                if motif.search(nue):
                    fautes.append((f"{p.relative_to(RACINE)}:{n}", ligne.strip(), pourquoi))

    print(f"{len(fichiers)} fichier(s) Swift lus, {emplois} emploi(s) de `RUFilet`")

    if blocs:
        print("\nUN COMMENTAIRE DE BLOC `/* */` EST APPARU :", file=sys.stderr)
        for ou in blocs:
            print(f"  - {ou}", file=sys.stderr)
        print("\nCe contrôle ne blanchit que les commentaires `//`. Tant que l'app n'en avait "
              "aucun, c'était suffisant ; ça ne l'est plus. À traiter avant de continuer.",
              file=sys.stderr)
        return 1

    if fautes:
        print(f"\n{len(fautes)} FILET(S) DESSINÉ(S) À LA MAIN :", file=sys.stderr)
        for ou, ligne, pourquoi in fautes:
            print(f"  - {ou}\n      {ligne}\n      {pourquoi}", file=sys.stderr)
        return 1

    if emplois == 0:
        print("\n`RUFilet` n'est employé nulle part : soit les filets ont disparu de l'app, "
              "soit ils sont revenus sous une forme que ce contrôle ne connaît pas.",
              file=sys.stderr)
        return 1

    print("Chaque filet passe par `RUFilet`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
