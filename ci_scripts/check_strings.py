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
# TOUT `RunUp/`, ET PAS SEULEMENT LES VUES. La liste s'arrêtait à `Views` et `ViewModels`, donc
# une chaîne affichée écrite dans un service ou un modèle n'était pas contrôlée du tout —
# `RestoreOutcome.message`, les libellés de `SessionKind`, les phrases de panne réseau. Elles
# sortaient en français en anglais et en espagnol sans que rien ne le dise. Le trou ne coûtait
# que quatre chaînes le jour où on l'a fermé ; il aurait grandi à chaque service nouveau.
DOSSIERS = ["RunUp", "RunUpWidgets", "RunUpWatch"]

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


# Un membre dont le TYPE est `LocalizedStringKey` : ses littéraux sont des clés, sans qu'aucun
# `Text("…")` ni `String(localized:)` n'apparaisse.
# Le `\?` compte : un membre peut rendre `LocalizedStringKey?` — « il n'y a rien à dire ici » est
# une réponse courante, et `nil` l'exprime mieux qu'une chaîne vide. Sans lui, les deux phrases
# d'avertissement de l'écran du triathlon n'étaient pas réclamées.
_CLE_LOCALISEE = re.compile(
    r"^\s*(?:private\s+|static\s+|public\s+|internal\s+)*"
    r"(?:var\s+\w+\s*:\s*LocalizedStringKey\??"
    r"|func\s+\w+\s*\([^)]*\)\s*->\s*LocalizedStringKey\??)\s*\{")


def litteraux_des_cles_localisees(source: str):
    """Les littéraux posés dans un membre de type `LocalizedStringKey` : `(ligne, clé)`.

    # LA TROISIÈME ZONE AVEUGLE DE CE CONTRÔLE

    `OUVERTURES` cherche `Text("…")`, `String(localized: "…")` et `LocalizedStringKey("…")`. Mais
    un `switch` dans `var startLabel: LocalizedStringKey` rend ses libellés en littéraux NUS :

        case .trail: return "Démarrer une sortie trail"

    C'est bien une clé du catalogue — SwiftUI la résout comme telle — et aucun des trois motifs ne
    la voit. Les trois libellés de ce membre-là n'y étaient que parce que celui qui les a écrits
    s'en est souvenu ; le quatrième, non, et rien ne l'a signalé.

    On lit donc le corps de ces membres par équilibre d'accolades, et tout littéral qui s'y trouve
    compte. `lire_litteral` et pas une expression régulière, pour la même raison qu'ailleurs : une
    interpolation peut contenir sa propre chaîne.
    """
    lignes = source.split("\n")
    trouves = []
    i = 0
    while i < len(lignes):
        if not _CLE_LOCALISEE.match(lignes[i]):
            i += 1
            continue
        profondeur = 0
        for n in range(i, len(lignes)):
            nue = lignes[n].strip()
            if not nue.startswith("//"):
                for m in re.finditer(r'"', lignes[n]):
                    lu = lire_litteral(lignes[n], m.end())
                    if lu is not None:
                        trouves.append((n + 1, deswiftifie(lu[0])))
                        break
                profondeur += lignes[n].count("{") - lignes[n].count("}")
            if n > i and profondeur <= 0:
                i = n + 1
                break
        else:
            break
    return trouves


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


# Les substituants qu'Apple écrit dans le catalogue là où la source porte une interpolation.
# `%1$@` AUTANT QUE `%@` : dès qu'une chaîne en porte deux, Apple les NUMÉROTE, parce que l'ordre
# des mots change d'une langue à l'autre. Sans le préfixe positionnel ici, « Aimé par %1$@ et
# %2$lld autres » n'était pas reconnu comme une clé à substituants et le contrôle se plaignait
# d'une clé parfaitement présente.
SUBSTITUANT = re.compile(r"%(\d+\$)?(@|lld|ld|d|f|\.\d+f)")


def motif_de(cle: str) -> re.Pattern:
    """La clé, ses interpolations remplacées par un joker."""
    return re.compile("^" + ".+".join(re.escape(m) for m in morceaux_fixes(cle)) + "$")


# ── La QUATRIÈME zone aveugle : un littéral confié à un paramètre qui sera localisé ───────────
#
#     ObTitle(eyebrow: "Étape 3 · ton triathlon", title: "QUEL TRIATHLON ?")
#
# Aucun `Text(`, aucun `String(localized:`, aucun membre typé. Et pourtant ce sont des clés :
# `ObTitle` rend son `title` par `Text(LocalizedStringKey(title))`, donc SwiftUI les résout au
# catalogue. Sept chaînes de l'écran du triathlon sont passées par là sans que rien ne le
# signale, et les mêmes chaînes de l'écran HYROX d'à côté n'y sont que parce que quelqu'un s'en
# est souvenu.
#
# LA RÈGLE EST LIÉE À CE QUE LE TYPE FAIT DE SON PARAMÈTRE, PAS AU NOM DU PARAMÈTRE. N'importe
# quel `title:` ne compte pas : `buildRunRecord(title: "Test")` prend un `String` qu'il stocke
# tel quel, et le titre français d'un relevé n'a rien à faire au catalogue. Un paramètre ne
# compte que si sa déclaration dit `LocalizedStringKey`, OU si le corps du type le passe
# lui-même à `LocalizedStringKey(…)` ou à `String.LocalizationValue(…)`. C'est le geste de
# localisation qui est détecté, à l'endroit où il est écrit.

_TYPE = re.compile(r"^\s*(?:@\w+\s+)*(?:public\s+|private\s+|internal\s+|final\s+)*"
                   r"(?:struct|class|enum)\s+(\w+)")
_PARAM_LOCALISE = re.compile(r"\b(\w+)\s*:\s*LocalizedStringKey\b")
# `var eyebrow: String`, `let title: String`, `var subtitle: String? = nil`, ou la même chose en
# paramètre d'initialiseur — les quatre formes sous lesquelles une étiquette arrive.
# `re.M` est indispensable et pas décoratif : sans lui, `$` ne vaut qu'à la fin du FICHIER, donc
# seules les déclarations suivies d'un `=` ou d'une virgule étaient vues. `var title: String` tout
# seul en fin de ligne — la forme la plus courante — passait à travers, et la première version de
# cette règle n'a attrapé qu'une étiquette sur sept.
_PARAM_TEXTE = re.compile(r"\b(?:var|let)?\s*(\w+)\s*:\s*String\??(?:\s*=|\s*,|\s*\)|\s*$)", re.M)


def parametres_localises(sources):
    """{type: {étiquettes qui finiront dans le catalogue}}.

    Deux pas : on découpe chaque fichier par type déclaré, puis on demande à chaque type ce
    qu'il fait de ses `String`. Le découpage est une heuristique — un type court jusqu'au type
    suivant — et il suffit : ces composants font quinze lignes.
    """
    table, corpus = {}, {}
    for texte in sources:
        blocs, courant, lignes = [], None, []
        for ligne in texte.split("\n"):
            m = _TYPE.match(ligne)
            if m:
                if courant:
                    blocs.append((courant, "\n".join(lignes)))
                courant, lignes = m.group(1), []
            if courant is not None:
                lignes.append(ligne)
        if courant:
            blocs.append((courant, "\n".join(lignes)))

        for nom, corps in blocs:
            sans = re.sub(r"//[^\n]*", "", corps)
            etiquettes = set(_PARAM_LOCALISE.findall(sans))
            for champ in set(_PARAM_TEXTE.findall(sans)):
                if champ in etiquettes:
                    continue
                localise = (re.search(r"LocalizedStringKey\(\s*" + re.escape(champ) + r"\s*\)", sans)
                            or re.search(r"LocalizationValue\(\s*" + re.escape(champ) + r"\s*\)", sans))
                if localise:
                    etiquettes.add(champ)
            if etiquettes:
                table.setdefault(nom, set()).update(etiquettes)
            corpus[nom] = sans

    # ── Le relais : une étiquette passée à une AUTRE étiquette localisée ───────────────────────
    #
    # `ObTitle` ne localise pas son `eyebrow` lui-même : il le transmet à
    # `EyebrowLabel(text: eyebrow)`, et c'est `EyebrowLabel` qui appelle le catalogue. Un pas de
    # plus, et la règle le perdait : « Étape 3 · ton triathlon » n'était pas réclamée, alors que
    # c'est précisément une chaîne qui sortirait en français.
    #
    # On ferme donc la table sur elle-même : tant qu'un tour ajoute une étiquette, on refait un
    # tour. Le point fixe est atteint en deux ou trois passes sur ce code, et la boucle ne peut
    # pas tourner indéfiniment — elle ne fait qu'ajouter à des ensembles finis.
    for _ in range(6):
        ajout = False
        for nom, sans in corpus.items():
            for cible, etiquettes in list(table.items()):
                for etiquette in etiquettes:
                    for relais in re.finditer(
                        r"\b" + re.escape(cible) + r"\s*\([^)]*?\b"
                        + re.escape(etiquette) + r"\s*:\s*(\w+)\b", sans):
                        champ = relais.group(1)
                        if champ in table.get(nom, set()):
                            continue
                        # Seulement si c'est bien un `String` déclaré du type — sinon on
                        # retiendrait une variable locale, qui n'est pas une étiquette d'appel.
                        if champ in set(_PARAM_TEXTE.findall(sans)):
                            table.setdefault(nom, set()).add(champ)
                            ajout = True
        if not ajout:
            break
    return table


def litteraux_des_parametres_localises(source: str, table):
    """Les littéraux confiés à une de ces étiquettes : `(ligne, clé)`.

    La lecture va de la parenthèse ouvrante de l'appel à sa fermante, parenthèses et accolades
    équilibrées — un appel s'étale souvent sur plusieurs lignes, et une closure passée en dernier
    argument ne doit pas emporter la lecture jusqu'au bout du fichier.
    """
    trouves = []
    for nom, etiquettes in table.items():
        for m in re.finditer(r"\b" + re.escape(nom) + r"\s*\(", source):
            depart = source.index("(", m.start())
            niveau, fin = 0, None
            for j in range(depart, len(source)):
                c = source[j]
                if c in "([{":
                    niveau += 1
                elif c in ")]}":
                    niveau -= 1
                    if niveau == 0:
                        fin = j
                        break
            if fin is None:
                continue
            appel = source[depart:fin]
            for a in re.finditer(r'\b(\w+)\s*:\s*(?=")', appel):
                if a.group(1) not in etiquettes:
                    continue
                lu = lire_litteral(appel[a.end():], 1)
                if lu is None:
                    continue
                ligne = source[:depart + a.start()].count("\n") + 1
                trouves.append((ligne, deswiftifie(lu[0])))
    return trouves


# ── Chaque type de séance doit avoir son titre et son sous-titre, dans les TROIS langues ───────
#
# `SessionKind.titleKey` compose « session.<brut>.title ». Ce n'est pas du français : c'est un
# identifiant. Donc si la clé manque au catalogue, SwiftUI affiche l'identifiant — « plan du
# jour : session.tri_brick.title ». Pas un mot de français en anglais, comme ailleurs : une
# chaîne technique, en évidence, sur l'écran le plus regardé de l'app.
#
# Et le FRANÇAIS compte ici, contrairement à toutes les autres clés de ce fichier. Partout
# ailleurs la clé EST le français, donc une entrée sans `fr` sort correctement en français. Pour
# celles-ci, sans `fr`, elle sort en « session.tri_brick.title » — y compris pour quelqu'un dont
# le téléphone est en français, c'est-à-dire pour elle.
#
# Dix types de séance viennent d'être ajoutés d'un coup. Aucune barrière ne regardait ça.

FICHIER_SEANCES = "RunUp/Models/Session.swift"
_SEANCE = re.compile(r'^\s*case \w+ = "([^"]+)"', re.M)
LANGUES_SEANCE = ("fr", "en", "es")


def types_de_seance(source: str):
    """Les valeurs brutes de `SessionKind`, dans l'ordre de déclaration."""
    return _SEANCE.findall(source)


def seances_sans_libelle(source: str, catalogue):
    """`(clé, ce qui manque)` pour chaque titre ou sous-titre de séance incomplet."""
    trous = []
    for brut in types_de_seance(source):
        for suffixe in ("title", "subtitle"):
            cle = f"session.{brut}.{suffixe}"
            entree = catalogue.get(cle)
            if entree is None:
                trous.append((cle, "absente du catalogue"))
                continue
            loc = entree.get("localizations", {})
            absentes = [l for l in LANGUES_SEANCE
                        if not loc.get(l, {}).get("stringUnit", {}).get("value")]
            if absentes:
                trous.append((cle, "sans " + " ni ".join(absentes)))
    return trous


# ── UNE CINQUIÈME ZONE AVEUGLE, CONNUE ET NON GARDÉE ──────────────────────────────────────────
#
#     Text(vm.jours < vm.minimum
#          ? "Choisis au moins 3 jours"
#          : "\(vm.jours) jours / semaine")
#
# `OUVERTURES` cherche `Text(` IMMÉDIATEMENT suivi d'un guillemet. Un ternaire qui respire sur
# trois lignes met donc ses littéraux hors de portée. Trouvée en se faisant prendre : cette
# phrase-là a été écrite sous cette forme et le contrôle l'a laissée passer sans un mot.
#
# ELLE N'EST PAS GARDÉE, ET C'EST UN CHOIX. La règle a été écrite, essayée, et retirée : lire les
# littéraux du premier niveau d'un `Text(…)` étalé demande de distinguer un `(` d'appel d'un `(`
# de groupement, de sauter les littéraux imbriqués dans une interpolation, et d'exclure
# `Text(verbatim:)`. Les deux versions tentées réclamaient entre cinq et dix-huit chaînes dont
# presque toutes étaient fausses — des « %.1f km » passés à `String(format:)`, des morceaux de
# ternaires lus de travers.
#
# Ce contrôle bloque CHAQUE construction du dépôt. Une barrière qui refuse du code juste y coûte
# plus cher qu'ailleurs : elle n'a aucun moyen d'être ignorée, donc elle finit désactivée, et on
# perd les quatre règles qui marchent avec celle qui ne marche pas. Mieux vaut une zone aveugle
# documentée qu'un garde qui crie au loup.
#
# LA PARADE EN ATTENDANT : écrire le littéral collé à `Text(`. Une phrase qui change selon une
# condition se pose dans un membre typé `LocalizedStringKey?` — zone déjà gardée, règle 3 — ce qui
# est de toute façon plus lisible qu'un ternaire à deux étages dans une vue.



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


def cles_positionnelles():
    """Les CLÉS du catalogue qui portent un marqueur positionnel — `%1$@` au lieu de `%@`.

    POURQUOI C'EST UNE FAUTE, ET POURQUOI ELLE NE SE VOIT PAS.

    Une clé de catalogue n'est pas choisie : elle est CALCULÉE à l'exécution, par
    `String.LocalizationValue`, à partir de la phrase interpolée. Pour
    `String(localized: "Aimé par \\(list) et \\(nombre) autres")` elle vaut
    `Aimé par %@ et %lld autres` — jamais `%1$@`. Une entrée écrite à la main avec des
    positions n'est donc JAMAIS trouvée : la recherche échoue, et Foundation retombe sur la
    clé elle-même, c'est-à-dire sur le FRANÇAIS, avec les valeurs quand même insérées.

    C'est arrivé, et seule une capture d'écran l'a montré : « Aimé par Charlotte, Margaux, and
    Sarah et 4 autres » — la liste jointe en anglais à l'intérieur d'une phrase restée
    française. Rien ne plante, le catalogue est « entièrement traduit », et toutes les
    anglophones et hispanophones lisent du français sous chaque activité du club.

    Les marqueurs positionnels restent légitimes dans une TRADUCTION, qui peut avoir besoin de
    réordonner les arguments. C'est la clé, et elle seule, qui ne peut pas en porter.
    """
    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))["strings"]
    return [cle for cle in catalogue if re.search(r"%\d+\$", cle)]


def main() -> int:
    cles = cles_du_catalogue()
    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))["strings"]
    if positionnelles := cles_positionnelles():
        print(f"{len(positionnelles)} clé(s) du catalogue portent un marqueur positionnel :\n",
              file=sys.stderr)
        for cle in positionnelles:
            print(f"  « {cle} »", file=sys.stderr)
        print("\nUne clé est CALCULÉE à l'exécution depuis la phrase interpolée, et elle ne",
              file=sys.stderr)
        print("porte jamais de position : `%@`, pas `%1$@`. Une clé positionnelle n'est donc",
              file=sys.stderr)
        print("jamais trouvée — l'app affiche la clé, c'est-à-dire le FRANÇAIS, à tout le monde.",
              file=sys.stderr)
        print("\nRenomme la clé sans positions. La TRADUCTION, elle, a le droit d'en porter.",
              file=sys.stderr)
        return 1
    seances = seances_sans_libelle((RACINE / FICHIER_SEANCES).read_text(encoding="utf-8"), catalogue)
    if seances:
        print(f"{len(seances)} libellé(s) de séance manquant(s) :\n", file=sys.stderr)
        for cle, pourquoi in seances:
            print(f"  {cle} — {pourquoi}", file=sys.stderr)
        print("\nUne clé de séance n'est PAS du français : c'est un identifiant. Absente, l'app",
              file=sys.stderr)
        print("affiche « session.tri_brick.title » sur l'écran du plan — en français aussi.",
              file=sys.stderr)
        return 1
    trous = sans_traduction()
    fichiers = [f for d in DOSSIERS for f in sorted((RACINE / d).rglob("*.swift"))]
    # La table est construite sur TOUT le code avant la première vérification : un type déclaré
    # dans un fichier est appelé depuis un autre, et une table construite fichier par fichier
    # n'aurait vu aucun appel.
    table = parametres_localises([f.read_text(encoding="utf-8") for f in fichiers])
    if trous:
        print(f"{len(trous)} traduction(s) manquante(s) au catalogue :\n", file=sys.stderr)
        for cle, langue in trous[:20]:
            print(f"  [{langue}] « {cle if len(cle) <= 60 else cle[:57] + '…'} »", file=sys.stderr)
        if len(trous) > 20:
            print(f"  … et {len(trous) - 20} autres", file=sys.stderr)
        return 1
    manquantes = []
    if True:
        for f in fichiers:
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
                            # LA CLÉ TROUVÉE DOIT ELLE AUSSI PORTER UN SUBSTITUANT, et c'est un
                            # faux positif qui a coûté une livraison. Le joker `.+` de `motif_de`
                            # acceptait n'importe quelle clé PLUS PRÉCISE : la source
                            # « Impossible de charger les itinéraires — \(motif). » était déclarée
                            # couverte par « Impossible de charger les itinéraires — vérifie ta
                            # connexion. », qui était l'ancienne phrase en dur qu'on venait
                            # justement de remplacer. À l'exécution, la vraie clé est
                            # « … — %@. » : absente du catalogue, donc du français en anglais.
                            motif = motif_de(cle)
                            if any(motif.match(k) and SUBSTITUANT.search(k) for k in cles):
                                continue
                        chemin = f.relative_to(RACINE)
                        manquantes.append((f"{chemin}:{n}", cle))
            # Et les membres typés `LocalizedStringKey`, que les trois ouvertures ne voient pas.
            for n, cle in litteraux_des_cles_localisees(texte):
                fixe = "".join(morceaux_fixes(cle))
                if not any(c.isalpha() for c in fixe) or cle in cles:
                    continue
                if "\\(" in cle:
                    motif = motif_de(cle)
                    if any(motif.match(k) and SUBSTITUANT.search(k) for k in cles):
                        continue
                manquantes.append((f"{f.relative_to(RACINE)}:{n}", cle))
            # Et les littéraux confiés à un paramètre que le composant localise lui-même.
            for n, cle in litteraux_des_parametres_localises(texte, table):
                fixe = "".join(morceaux_fixes(cle))
                if not any(c.isalpha() for c in fixe) or cle in cles:
                    continue
                if "\\(" in cle:
                    motif = motif_de(cle)
                    if any(motif.match(k) and SUBSTITUANT.search(k) for k in cles):
                        continue
                manquantes.append((f"{f.relative_to(RACINE)}:{n}", cle))

    # Deux chemins peuvent nommer la même chaîne au même endroit (un membre typé qui est AUSSI
    # dans un appel localisé) : on ne la réclame qu'une fois.
    manquantes = sorted(set(manquantes))

    if not manquantes:
        nb = len(types_de_seance((RACINE / FICHIER_SEANCES).read_text(encoding="utf-8")))
        print(f"Catalogue : {len(cles)} clés, aucune chaîne affichée n'en manque.")
        print(f"            {nb} types de séance, tous titrés dans les trois langues.")
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
