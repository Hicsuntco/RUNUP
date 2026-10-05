#!/usr/bin/env python3
"""Une commande qui ne montre qu'une icône doit avoir un nom prononçable.

# POURQUOI CE CONTRÔLE EXISTE

Un bouton dont le libellé est un `Text` se nomme tout seul : VoiceOver lit le mot. Un bouton dont
le libellé est une `Image(systemName:)` ne se nomme pas du tout — il s'annonce « bouton », et
rien d'autre. Rien ne le signale : l'app compile, l'écran est juste, et le défaut ne se constate
qu'en naviguant l'app au doigt avec l'écran éteint.

Les commandes à icône de l'app sont toutes nommées à la main, une par une, et aucune n'est
oubliée au moment où ce script est écrit. C'est exactement le moment de poser la machine : elle ne
rattrape pas une dette, elle empêche la prochaine. Le prochain bouton icône sera écrit un soir,
dans une feuille modale, et personne ne relira la liste.

# CE QUI EST REGARDÉ

Les couches visibles — `RunUp/Views`, le widget, la montre. Une commande n'est signalée que si
TOUS ces points sont vrais, parce qu'un faux positif dans une barrière d'intégration continue
coûte plus cher que le défaut qu'elle cherche :

  · c'est un `Button` ou un `NavigationLink` ;
  · son libellé contient une `Image(` ;
  · son libellé ne contient AUCUN `Text(`, `Label(` ni `LocalizedStringKey(` ;
  · sa chaîne de modificateurs ne porte ni `accessibilityLabel`, ni `accessibilityHidden`
    (décoratif assumé), ni `accessibilityElement` (fusionné avec un voisin qui, lui, parle).

Le doute profite donc toujours au code. Une commande nommée par une variable
(`Button(monLibelle)`) n'est pas regardée : elle a un nom, ce script ne sait simplement pas lequel.

# POURQUOI UN ANALYSEUR ET PAS UNE EXPRESSION RÉGULIÈRE

Le premier jet en utilisait une, et rapportait cinquante-six commandes dont cinquante-six
nommées : un motif ne sait pas où s'arrête un bouton. Il faut compter les profondeurs, et surtout
IGNORER ce qui se trouve dans une chaîne ou un commentaire — ce fichier-ci en est la preuve
vivante, il contient des accolades dans ses propres commentaires. `decouper` fait les deux, et
`test_a11y.py` le vérifie sur des cas écrits exprès.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ["RunUp/Views", "RunUpWidgets", "RunUpWatch"]
COMMANDES = re.compile(r'\b(Button|NavigationLink)\b')
A_UN_NOM = re.compile(r'\baccessibilityLabel\b|\baccessibilityHidden\b|\baccessibilityElement\b')
PARLE = re.compile(r'\bText\s*\(|\bLabel\s*\(|\bLocalizedStringKey\s*\(')
MONTRE_UNE_ICONE = re.compile(r'\bImage\s*\(')
ETIQUETTE = re.compile(r'\w+\s*:\s*\{')


def blanchir(src):
    """Le même texte, de la même longueur, commentaires et contenus de chaînes remplacés par des
    espaces.

    Tout le reste de ce fichier analyse cette copie, et n'a donc plus à se demander si l'accolade
    qu'il compte est du code. Les retours à la ligne sont préservés pour que les numéros de ligne
    restent justes.

    Les interpolations sont blanchies AVEC leurs parenthèses — les deux, l'ouvrante et la
    fermante — pour que l'équilibre du fichier n'en soit pas changé. Sans ça, `"\\(a) km"` laissait
    une parenthèse fermante orpheline et la fin du bouton partait vingt lignes trop loin.
    """
    out = list(src)
    n = len(src)
    pile = []

    def blanc(k):
        if src[k] != "\n":
            out[k] = " "

    i = 0
    while i < n:
        c = src[i]
        dedans = pile[-1][0] if pile else None

        if dedans is None:
            if src.startswith("//", i):
                j = src.find("\n", i)
                j = n if j < 0 else j
                for k in range(i, j):
                    blanc(k)
                i = j
                continue
            if src.startswith("/*", i):
                prof, j = 0, i
                while j < n:
                    if src.startswith("/*", j):
                        prof += 1
                        j += 2
                        continue
                    if src.startswith("*/", j):
                        prof -= 1
                        j += 2
                        if prof == 0:
                            break
                        continue
                    j += 1
                j = min(j, n)
                for k in range(i, j):
                    blanc(k)
                i = j
                continue
            if src.startswith('"""', i):
                pile.append(["str3", 0])
                i += 3
                continue
            if c == '"':
                pile.append(["str", 0])
                i += 1
                continue
            i += 1
            continue

        if dedans in ("str", "str3"):
            if c == "\\" and i + 1 < n and src[i + 1] == "(":
                blanc(i)
                blanc(i + 1)
                pile.append(["interp", 1])
                i += 2
                continue
            if c == "\\" and i + 1 < n:
                blanc(i)
                blanc(i + 1)
                i += 2
                continue
            if dedans == "str3" and src.startswith('"""', i):
                pile.pop()
                i += 3
                continue
            if dedans == "str" and c == '"':
                pile.pop()
                i += 1
                continue
            if dedans == "str" and c == "\n":
                # Une chaîne simple ne traverse pas la ligne : mieux vaut refermer que dériver.
                pile.pop()
                i += 1
                continue
            blanc(i)
            i += 1
            continue

        # Dans une interpolation : du vrai code, blanchi lui aussi, en comptant ses parenthèses
        # pour savoir où elle s'arrête.
        if src.startswith('"""', i):
            pile.append(["str3", 0])
            for k in range(i, i + 3):
                blanc(k)
            i += 3
            continue
        if c == '"':
            pile.append(["str", 0])
            blanc(i)
            i += 1
            continue
        if c == "(":
            pile[-1][1] += 1
            blanc(i)
            i += 1
            continue
        if c == ")":
            pile[-1][1] -= 1
            blanc(i)
            if pile[-1][1] == 0:
                pile.pop()
            i += 1
            continue
        blanc(i)
        i += 1
        continue

    return "".join(out)


def _saute_blancs(src, i):
    while i < len(src) and src[i] in " \t\n":
        i += 1
    return i


def _bloc(src, i):
    """L'indice juste après le groupe équilibré qui s'ouvre en `src[i]`. Sur du texte blanchi."""
    profondeur = 0
    while i < len(src):
        c = src[i]
        if c in "([{":
            profondeur += 1
        elif c in ")]}":
            profondeur -= 1
            if profondeur == 0:
                return i + 1
        i += 1
    return len(src)


def decouper(src, debut):
    """L'expression complète de la commande qui commence en `debut`, sur du texte blanchi : son
    appel, ses closures de libellé, et toute sa chaîne de modificateurs."""
    mot = re.match(r'\w+', src[debut:])
    i = _saute_blancs(src, debut + (mot.end() if mot else 1))
    if i >= len(src) or src[i] not in "({":
        return src[debut:debut + 1], debut + 1
    i = _bloc(src, i)
    # Les closures qui suivent l'appel. Deux formes, et il fallait les deux : `Button(action:) {
    # libellé }` — une closure anonyme — et `Button { action } label: { libellé }`, où le libellé
    # est nommé. L'analyseur ne connaissait que la première, donc il ne voyait jamais l'icône de
    # la seconde : les trois quarts des boutons de l'app passaient inaperçus.
    while True:
        j = _saute_blancs(src, i)
        if j < len(src) and src[j] == "{":
            i = _bloc(src, j)
            continue
        etiquette = ETIQUETTE.match(src[j:]) if j < len(src) else None
        if etiquette:
            i = _bloc(src, j + etiquette.end() - 1)
            continue
        break
    # Puis la chaîne de modificateurs.
    while True:
        j = _saute_blancs(src, i)
        if j >= len(src) or src[j] != ".":
            break
        nom = re.match(r'\.\w+', src[j:])
        if not nom:
            break
        i = j + nom.end()
        k = _saute_blancs(src, i)
        if k < len(src) and src[k] in "({":
            i = _bloc(src, k)
            k = _saute_blancs(src, i)
            if k < len(src) and src[k] == "{":
                i = _bloc(src, k)
    return src[debut:i], i


def sans_nom(source):
    """Les (ligne, extrait) des commandes qui ne montrent qu'une icône et ne se nomment pas."""
    src = blanchir(source)
    trouves = []
    position = 0
    for m in COMMANDES.finditer(src):
        if m.start() < position:
            continue
        expr, _ = decouper(src, m.start())
        position = m.start() + 1
        if not MONTRE_UNE_ICONE.search(expr):
            continue
        if PARLE.search(expr) or A_UN_NOM.search(expr):
            continue
        extrait = source[m.start():m.start() + len(expr)]
        trouves.append((src[:m.start()].count("\n") + 1, " ".join(extrait.split())[:120]))
    return trouves


def main():
    total, fautifs = 0, []
    for dossier in DOSSIERS:
        for f in sorted((RACINE / dossier).rglob("*.swift")):
            source = f.read_text()
            total += len(COMMANDES.findall(blanchir(source)))
            for ligne, extrait in sans_nom(source):
                fautifs.append((f.relative_to(RACINE), ligne, extrait))
    if fautifs:
        print(f"{len(fautifs)} commande(s) n'affichent qu'une icône et n'ont pas de nom :\n")
        for chemin, ligne, extrait in fautifs:
            print(f"  {chemin}:{ligne}")
            print(f"    {extrait}")
        print("\nAjoute `.accessibilityLabel(\"…\")` — ou `.accessibilityHidden(true)` si la")
        print("commande est vraiment décorative et qu'un voisin porte déjà l'action.")
        return 1
    print(f"Accessibilité : {total} commandes lues, toutes celles qui n'ont qu'une icône ont un nom.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
