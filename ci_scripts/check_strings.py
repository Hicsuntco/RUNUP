#!/usr/bin/env python3
"""Toute chaîne affichée doit exister au catalogue.

# POURQUOI CE CONTRÔLE EXISTE

Une clé absente du catalogue ne casse rien. `String(localized:)` rend la clé elle-même, et
`Text("littéral")` fait pareil : l'app compile, les tests passent, et le texte sort EN FRANÇAIS
chez tout le monde. Le défaut ne se voit qu'en lançant l'app dans une autre langue, sur l'écran
concerné — autant dire jamais.

L'audit en a trouvé cinq d'un coup : deux arguments de vente du paywall, la consigne affichée au
moment précis où le GPS lâche pendant une course, la description du widget dans la galerie iOS, et
le type d'une séance saisie à la main. Deux d'entre elles avaient été écrites le jour même, par
quelqu'un qui venait justement de corriger ce genre de défaut. C'est le signe qu'il faut une
machine, pas de la vigilance.

# CE QUI EST REGARDÉ, ET CE QUI NE L'EST PAS

Les couches VISIBLES seulement : les vues, le widget, la montre. `RunUp/Services` en est exclu à
dessein — il contient des dizaines de littéraux français volontaires (prompts du coach, libellés
internes servant d'identifiants stables, voir `WorkoutSession.title`) qui n'ont rien à faire au
catalogue. Les y inclure noierait les vrais défauts sous les faux.

Deux formes sont suivies :

  · `String(localized: "…")` — la forme explicite ;
  · `Text("…")` — un littéral y devient une `LocalizedStringKey`, donc il consulte le catalogue.

`Text(variable)` n'est PAS suivi : il ne consulte jamais le catalogue, c'est un autre défaut, et il
ne se détecte pas par la lecture du seul appel.

Une chaîne SANS AUCUNE LETTRE est ignorée — un emoji, un chevron, un point médian, un nombre. Il
n'y a rien à y traduire, et les signaler noierait les vrais défauts : c'est déjà arrivé au premier
essai de ce script, soixante et un signalements dont l'écrasante majorité était du décor. Le tri se
fait sur la partie fixe, interpolations retirées : « \(a) / \(b) km » garde « km », donc compte.

# LES INTERPOLATIONS

`String(localized: "Semaine \\(n)/\\(total)")` cherche la clé « Semaine %lld/%lld ». Le type du
marqueur dépend de la variable, que ce script ne connaît pas : chaque `\\(…)` devient donc un joker
et la clé est cherchée par motif. Une correspondance approximative suffit ici — on cherche les
absences franches, pas à valider des formats.
"""
import json, pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE = RACINE / "RunUp/Resources/Localizable.xcstrings"
DOSSIERS = ["RunUp/Views", "RunUp/ViewModels", "RunUpWidgets", "RunUpWatch"]

# Les ouvertures qui précèdent un littéral traduit. Le littéral lui-même est lu par `lire_litteral`
# et non par une expression régulière : une interpolation peut contenir sa propre chaîne — par
# exemple `"Cette semaine, \(String(format: "%.1f", km)) km"` — et un motif naïf s'arrête sur le
# guillemet intérieur. Le premier jet de ce script le faisait, et rapportait des clés tronquées.
OUVERTURES = [
    re.compile(r'String\(\s*localized:\s*"'),
    re.compile(r'\bText\(\s*"'),
    re.compile(r'LocalizedStringKey\(\s*"'),
]


def lire_litteral(ligne: str, debut: int):
    """Le contenu du littéral commençant juste après `debut`, ou None s'il n'est pas terminé ici.

    Suit la profondeur des interpolations : tant qu'on est dans un `\(…)`, un guillemet appartient
    à la chaîne intérieure et ne ferme rien.
    """
    i, profondeur, out = debut, 0, []
    while i < len(ligne):
        c = ligne[i]
        if c == "\\" and i + 1 < len(ligne):
            if ligne[i + 1] == "(":
                profondeur += 1
                out.append("\\(")
                i += 2
                continue
            out.append(ligne[i:i + 2])
            i += 2
            continue
        if profondeur > 0:
            if c == "(":
                profondeur += 1
            elif c == ")":
                profondeur -= 1
            elif c == '"':
                # Une chaîne imbriquée dans l'interpolation : on la saute entière.
                j = i + 1
                while j < len(ligne) and ligne[j] != '"':
                    j += 2 if ligne[j] == "\\" else 1
                out.append(ligne[i:j + 1])
                i = j + 1
                continue
            out.append(c)
            i += 1
            continue
        if c == '"':
            return "".join(out), i
        out.append(c)
        i += 1
    return None


def cles_du_catalogue():
    data = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    return set(data["strings"].keys())


def morceaux_fixes(cle: str):
    """La clé découpée sur ses interpolations, parenthèses imbriquées comprises.

    Un découpage naïf s'arrête à la PREMIÈRE parenthèse fermante :
    « \\(PaceModel.formatDuration(minPace)) » y laisse un « ) » orphelin dans la partie fixe, le
    motif devient « Plus rapide .+\\)/km » et ne reconnaît plus « Plus rapide %@/km ». Ce script a
    signalé vingt-sept clés parfaitement présentes avant que ce défaut ne soit vu.
    """
    out, courant, i = [], [], 0
    while i < len(cle):
        if cle.startswith("\\(", i):
            out.append("".join(courant)); courant = []
            prof, i = 1, i + 2
            while i < len(cle) and prof:
                if cle[i] == "(":
                    prof += 1
                elif cle[i] == ")":
                    prof -= 1
                i += 1
        else:
            courant.append(cle[i]); i += 1
    out.append("".join(courant))
    return out


ECHAPPEMENTS = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "0": "\0"}


def deswiftifie(brut: str) -> str:
    """Les échappements Swift rendus en vrais caractères, hors interpolations.

    Le catalogue porte un RETOUR À LA LIGNE là où le code source écrit deux caractères, « \\ » et
    « n ». Sans cette conversion, quatre titres d'accueil parfaitement traduits étaient signalés
    comme absents. Les `\\(` sont laissés intacts : ce sont des interpolations, pas des
    échappements, et le découpage qui suit compte dessus.
    """
    out, i = [], 0
    while i < len(brut):
        if brut[i] == "\\" and i + 1 < len(brut):
            suivant = brut[i + 1]
            if suivant == "(":
                out.append("\\("); i += 2; continue
            if suivant in ECHAPPEMENTS:
                out.append(ECHAPPEMENTS[suivant]); i += 2; continue
        out.append(brut[i]); i += 1
    return "".join(out)


def motif_de(cle: str) -> re.Pattern:
    """La clé, ses interpolations remplacées par un joker."""
    return re.compile("^" + ".+".join(re.escape(m) for m in morceaux_fixes(cle)) + "$")


def sans_traduction():
    """Les clés du catalogue auxquelles il manque l'anglais ou l'espagnol.

    L'autre moitié du même problème : une clé PRÉSENTE mais non traduite ressort elle aussi en
    français. Le contrôle ci-dessus ne la verrait pas — elle est bien au catalogue.
    """
    data = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    trous = []
    for cle, v in data["strings"].items():
        loc = v.get("localizations", {})
        for langue in ("en", "es"):
            unit = loc.get(langue, {}).get("stringUnit", {})
            if unit.get("state") != "translated" or not unit.get("value"):
                trous.append((cle, langue))
    return trous


def main() -> int:
    cles = cles_du_catalogue()
    trous = sans_traduction()
    if trous:
        print(f"{len(trous)} traduction(s) manquante(s) au catalogue :\n", file=sys.stderr)
        for cle, langue in trous[:20]:
            print(f"  [{langue}] « {cle if len(cle) <= 60 else cle[:57] + '…'} »", file=sys.stderr)
        if len(trous) > 20:
            print(f"  … et {len(trous) - 20} autres", file=sys.stderr)
        return 1
    manquantes = []
    for dossier in DOSSIERS:
        for f in sorted((RACINE / dossier).rglob("*.swift")):
            texte = f.read_text(encoding="utf-8")
            for n, ligne in enumerate(texte.splitlines(), 1):
                nue = ligne.strip()
                if nue.startswith("//") or nue.startswith("///"):
                    continue
                for appel in OUVERTURES:
                    for m in appel.finditer(ligne):
                        lu = lire_litteral(ligne, m.end())
                        if lu is None:
                            continue
                        brut, _ = lu
                        cle = deswiftifie(brut)
                        fixe = "".join(morceaux_fixes(cle))
                        if not any(c.isalpha() for c in fixe):
                            continue
                        if cle in cles:
                            continue
                        if "\\(" in cle:
                            motif = motif_de(cle)
                            if any(motif.match(k) for k in cles):
                                continue
                        chemin = f.relative_to(RACINE)
                        manquantes.append((f"{chemin}:{n}", cle))

    if not manquantes:
        print(f"Catalogue : {len(cles)} clés, aucune chaîne affichée n'en manque.")
        return 0

    print(f"{len(manquantes)} chaîne(s) affichée(s) absente(s) du catalogue :\n", file=sys.stderr)
    for ou, cle in manquantes:
        court = cle if len(cle) <= 70 else cle[:67] + "…"
        print(f"  {ou}\n      « {court} »", file=sys.stderr)
    print("\nChacune sortira EN FRANÇAIS en anglais et en espagnol.", file=sys.stderr)
    print("Ajoute-les à RunUp/Resources/Localizable.xcstrings avec leurs deux traductions.",
          file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
