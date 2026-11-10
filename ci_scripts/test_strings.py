#!/usr/bin/env python3
"""Vérifie `check_strings.py` sur des cas écrits exprès.

# POURQUOI CE FICHIER ARRIVE SI TARD

`check_strings.py` est la barrière la plus souvent durcie du dépôt — quatre fois, et chaque
durcissement a immédiatement trouvé de vraies chaînes qui partaient en français. Elle n'avait
pourtant aucun test, et ça s'est payé : la quatrième règle est partie avec une expression
régulière sans `re.M`, donc `$` ne valait qu'à la fin du FICHIER. Elle n'a attrapé qu'une
étiquette sur sept, et seule une vérification à la main l'a montré.

Comme pour `test_disciplines.py`, ce qui est vérifié ici c'est surtout ce que l'analyse doit
LAISSER PASSER. Ce contrôle bloque chaque construction du dépôt : un faux positif y coûte plus
cher qu'ailleurs, parce qu'il n'y a aucun moyen de livrer en l'ignorant.
"""
import sys
import check_strings as ck

cas = []
def cas_test(nom):
    def deco(f):
        cas.append((nom, f)); return f
    return deco


# ── Zone 7 : un littéral NU confié à un puits d'affichage typé `String` ───────────────────────
#
# Le défaut du 10 novembre 2026 : les quatre consignes de fractionné de l'écran de course étaient
# des littéraux passés à `showCue(_ message: String)`. Un `String` n'interroge jamais le
# catalogue — les clés y étaient, traduites dans les trois langues, et personne ne les demandait.
# Au départ de chaque répétition, en anglais comme en espagnol, la phrase sortait en français.

@cas_test("un littéral nu passé à `showCue` est signalé")
def _():
    trouves = ck.litteraux_des_puits('showCue("Récupération — souffle.")')
    assert [x[2] for x in trouves] == ["Récupération — souffle."], trouves

@cas_test("le même, enveloppé dans `String(localized:)`, ne l'est pas")
def _():
    assert ck.litteraux_des_puits('showCue(String(localized: "Récupération."))') == []

@cas_test("LES DEUX BRANCHES D'UN TERNAIRE SONT VUES")
def _():
    # C'est la forme exacte qu'avait le défaut : `showCue(n == 1 ? "…" : "…")`. Ne lire que le
    # premier littéral en aurait laissé passer la moitié.
    trouves = ck.litteraux_des_puits('showCue(n == 1 ? "Premier" : "Suivant")')
    assert [x[2] for x in trouves] == ["Premier", "Suivant"], trouves

@cas_test("une variable passée au puits ne dit rien — ce n'est pas la même faute")
def _():
    assert ck.litteraux_des_puits("showCue(consigne)") == []

@cas_test("un littéral passé à une AUTRE fonction n'est pas concerné")
def _():
    # La règle est NOMMÉE : on ne peut pas deviner qu'un `String` finira à l'écran. Signaler
    # tous les littéraux de tous les appels refuserait la moitié du dépôt.
    assert ck.litteraux_des_puits('analytics.track("run_started")') == []


# ── Zone 1 à 3 : les ouvertures et les membres typés ──────────────────────────────────────────

def ouvre(ligne, attendu, nom):
    trouve = None
    for appel in ck.OUVERTURES:
        for m in appel.finditer(ligne):
            lu = ck.lire_litteral(ligne, m.end())
            if lu is not None:
                trouve = ck.deswiftifie(lu[0]); break
        if trouve is not None:
            break
    assert trouve == attendu, f"{nom} : {attendu!r} attendu, {trouve!r} trouvé"

@cas_test("un `Text(\"…\")` est lu")
def _(): ouvre('Text("Bonjour")', "Bonjour", "Text")

@cas_test("un `String(localized:)` est lu")
def _(): ouvre('return String(localized: "Natation")', "Natation", "String(localized:)")

@cas_test("une interpolation qui contient sa propre chaîne ne coupe pas la lecture")
def _(): ouvre('Text("Reste \\(n > 1 ? "des jours" : "un jour")")',
               'Reste \\(n > 1 ? "des jours" : "un jour")', "interpolation")

@cas_test("un membre typé `LocalizedStringKey` livre ses littéraux nus")
def _():
    src = ('    var libelle: LocalizedStringKey {\n'
           '        switch self {\n'
           '        case .run: return "EN DIRECT"\n'
           '        case .swim: return "NAGE · EN DIRECT"\n'
           '        }\n'
           '    }\n')
    lus = [c for _, c in ck.litteraux_des_cles_localisees(src)]
    assert lus == ["EN DIRECT", "NAGE · EN DIRECT"], lus

@cas_test("un membre typé `LocalizedStringKey?` compte aussi")
def _():
    src = ('    private var avertissement: LocalizedStringKey? {\n'
           '        guard x else { return nil }\n'
           '        return "Attention"\n'
           '    }\n')
    lus = [c for _, c in ck.litteraux_des_cles_localisees(src)]
    assert lus == ["Attention"], lus

@cas_test("un membre typé `String` n'est pas lu comme une clé")
def _():
    src = '    var titreStocke: String {\n        return "Course importée"\n    }\n'
    assert ck.litteraux_des_cles_localisees(src) == []


# ── Zone 4 : les littéraux confiés à une étiquette localisée ──────────────────────────────────

COMPOSANTS = '''
struct EyebrowLabel: View {
    var text: String
    var color: Color = RUColor.text3
    var body: some View {
        Text(LocalizedStringKey(text)).eyebrowStyle(color: color)
    }
}

struct ObTitle: View {
    var eyebrow: String
    var title: String
    var subtitle: String? = nil
    var body: some View {
        EyebrowLabel(text: eyebrow, color: RUColor.rose)
        Text(LocalizedStringKey(title))
        // `if let` rend une locale du MÊME nom, et c'est bien le paramètre qu'on suit — c'est
        // exactement la forme du vrai `ObTitle`.
        if let subtitle {
            Text(LocalizedStringKey(subtitle))
        }
    }
}

struct Chip: View {
    var label: LocalizedStringKey
    var body: some View { Text(label) }
}

struct Releve {
    var title: String
    var distanceKm: Double
}
'''

TABLE = ck.parametres_localises([COMPOSANTS])

@cas_test("une étiquette que le type passe à `LocalizedStringKey` est retenue")
def _():
    assert "title" in TABLE.get("ObTitle", set()), TABLE.get("ObTitle")
    assert "text" in TABLE.get("EyebrowLabel", set()), TABLE.get("EyebrowLabel")

@cas_test("une étiquette déclarée `LocalizedStringKey` est retenue sans autre indice")
def _(): assert TABLE.get("Chip") == {"label"}, TABLE.get("Chip")

@cas_test("une étiquette relayée à un autre composant localisé est retenue")
def _():
    # `ObTitle.eyebrow` ne touche jamais le catalogue lui-même : il le passe à `EyebrowLabel`.
    # C'est le cas qui a fait manquer « Étape 3 · ton triathlon ».
    assert "eyebrow" in TABLE.get("ObTitle", set()), TABLE.get("ObTitle")

@cas_test("un `String` que le type se contente de stocker n'est PAS retenu")
def _():
    # `Releve(title: "Course importée")` stocke un titre français et n'a rien à faire au
    # catalogue. C'est le faux positif que la règle doit éviter à tout prix.
    assert "Releve" not in TABLE, TABLE.get("Releve")

@cas_test("un littéral confié à une étiquette localisée est réclamé")
def _():
    src = 'ObTitle(eyebrow: "Étape 3", title: "QUEL TRIATHLON ?", subtitle: "Nager, rouler.")'
    lus = sorted(c for _, c in ck.litteraux_des_parametres_localises(src, TABLE))
    assert lus == ["Nager, rouler.", "QUEL TRIATHLON ?", "Étape 3"], lus

@cas_test("un littéral confié à une étiquette NON localisée est laissé tranquille")
def _():
    src = 'Releve(title: "Course importée", distanceKm: 8.2)'
    assert ck.litteraux_des_parametres_localises(src, TABLE) == []

@cas_test("une variable passée à une étiquette localisée n'est pas une clé")
def _():
    src = 'ObTitle(eyebrow: unEyebrow, title: leTitre)'
    assert ck.litteraux_des_parametres_localises(src, TABLE) == []

@cas_test("un appel sur plusieurs lignes est lu en entier")
def _():
    src = ('ObTitle(\n'
           '    eyebrow: "Étape 3",\n'
           '    title: "QUEL TRIATHLON ?"\n'
           ')')
    lus = sorted(c for _, c in ck.litteraux_des_parametres_localises(src, TABLE))
    assert lus == ["QUEL TRIATHLON ?", "Étape 3"], lus

@cas_test("une closure en dernier argument ne fait pas déborder la lecture")
def _():
    src = ('Chip(label: "Sprint") {\n'
           '    faireQuelqueChose(avec: "ceci n\'est pas une clé")\n'
           '}\n')
    lus = [c for _, c in ck.litteraux_des_parametres_localises(src, TABLE)]
    assert lus == ["Sprint"], lus

@cas_test("la ligne rapportée est celle du littéral, pas celle de l'appel")
def _():
    src = 'ObTitle(\n    eyebrow: "A",\n    title: "B"\n)'
    lignes = {c: n for n, c in ck.litteraux_des_parametres_localises(src, TABLE)}
    assert lignes == {"A": 2, "B": 3}, lignes


# ── Les libellés de séance ────────────────────────────────────────────────────────────────────

SOURCE_SEANCES = '''
    case easyFooting = "easy_footing"
    case triBrick = "tri_brick"
'''

def _trio(mot):
    return {"localizations": {l: {"stringUnit": {"value": mot}}
                              for l in ck.LANGUES_SEANCE}}

def _catalogue_complet():
    c = {}
    for brut in ("easy_footing", "tri_brick"):
        for suffixe in ("title", "subtitle"):
            c[f"session.{brut}.{suffixe}"] = _trio(brut)
    return c

@cas_test("les types de séance sont lus à la source")
def _():
    lus = ck.types_de_seance(SOURCE_SEANCES)
    assert lus == ["easy_footing", "tri_brick"], lus

@cas_test("un type de séance complet dans les trois langues passe")
def _(): assert ck.seances_sans_libelle(SOURCE_SEANCES, _catalogue_complet()) == []

@cas_test("un sous-titre de séance absent est signalé")
def _():
    c = _catalogue_complet(); del c["session.tri_brick.subtitle"]
    t = ck.seances_sans_libelle(SOURCE_SEANCES, c)
    assert [cle for cle, _ in t] == ["session.tri_brick.subtitle"], t

@cas_test("un libellé de séance sans FRANÇAIS est signalé")
def _():
    # Le cas qui distingue cette règle de toutes les autres : ailleurs la clé EST le français.
    # Ici, sans `fr`, l'app affiche « session.tri_brick.title » — y compris en français.
    c = _catalogue_complet()
    c["session.tri_brick.title"] = {"localizations": {
        "en": {"stringUnit": {"value": "Brick"}},
        "es": {"stringUnit": {"value": "Enlace"}}}}
    t = ck.seances_sans_libelle(SOURCE_SEANCES, c)
    assert len(t) == 1 and "fr" in t[0][1], t

@cas_test("les 53 types de séance du vrai dépôt sont tous titrés")
def _():
    import json
    src = (ck.RACINE / ck.FICHIER_SEANCES).read_text(encoding="utf-8")
    catalogue = json.loads(ck.CATALOGUE.read_text(encoding="utf-8"))["strings"]
    t = ck.seances_sans_libelle(src, catalogue)
    assert t == [], f"{len(t)} trous : {t[:4]}"
    assert len(ck.types_de_seance(src)) >= 50, len(ck.types_de_seance(src))


# ── Le vrai dépôt ─────────────────────────────────────────────────────────────────────────────

@cas_test("la table du vrai code voit les composants d'onboarding, et pas `RunRecord`")
def _():
    fichiers = [f for d in ck.DOSSIERS for f in sorted((ck.RACINE / d).rglob("*.swift"))]
    table = ck.parametres_localises([f.read_text(encoding="utf-8") for f in fichiers])
    assert "eyebrow" in table.get("ObTitle", set()), "ObTitle.eyebrow manque"
    assert "text" in table.get("EyebrowLabel", set()), "EyebrowLabel.text manque"
    # `RunRecord(title:)` stocke le titre français du relevé — il ne doit jamais être réclamé.
    assert "title" not in table.get("RunRecord", set()), "RunRecord.title réclamé à tort"

@cas_test("aucune clé du catalogue ne porte de marqueur positionnel")
def _():
    # `Aimé par %1$@ et %2$lld autres` était écrite à la main avec des positions. La clé
    # calculée à l'exécution vaut `Aimé par %@ et %lld autres` : la recherche échouait, et
    # toutes les anglophones lisaient « Aimé par Charlotte, Margaux, and Sarah et 4 autres ».
    assert ck.cles_positionnelles() == [], ck.cles_positionnelles()


@cas_test("la règle attrape bien une clé positionnelle, et laisse passer la traduction")
def _():
    import re as _re
    motif = _re.compile(r"%\d+\$")
    assert motif.search("Aimé par %1$@ et %2$lld autres")
    assert not motif.search("Aimé par %@ et %lld autres")
    # Une TRADUCTION a le droit de réordonner : la règle ne regarde que les clés.
    assert motif.search("Von %2$lld Leuten, darunter %1$@")


@cas_test("un littéral confié à un paramètre de méthode typé LocalizedStringKey est réclamé")
def _():
    source = """
    struct Ecran: View {
        var body: some View { bandeau(icone: "wifi.slash", texte: "Pas de réseau") }
        private func bandeau(icone: String, texte: LocalizedStringKey) -> some View {
            HStack { Image(systemName: icone); Text(texte) }
        }
    }
    """
    trouves = [cle for _, cle in ck.litteraux_des_methodes_localisees(source)]
    assert "Pas de réseau" in trouves, trouves
    # L'ICÔNE N'EST PAS UNE PHRASE. Son paramètre est un `String` : un nom de symbole SF n'a
    # rien à faire au catalogue, et le réclamer noierait les vrais défauts.
    assert "wifi.slash" not in trouves, trouves


@cas_test("la règle est scellée au fichier : deux méthodes du même nom ne se contaminent pas")
def _():
    # Un premier jet indexait les méthodes par NOM seulement. Un `statTile(label:)` typé
    # `LocalizedStringKey` dans un écran réclamait alors les littéraux du `statTile(label: String)`
    # d'un autre écran : vingt-et-un défauts rapportés dont dix-sept appartenaient à la méthode
    # d'à côté. C'est ce que ce cas interdit.
    sans_localisation = """
    struct Autre: View {
        var body: some View { statTile(label: "Distance") }
        private func statTile(label: String) -> some View { Text(label) }
    }
    """
    assert ck.litteraux_des_methodes_localisees(sans_localisation) == []


@cas_test("le vrai code : les cinq bandeaux de l'écran de course sont réclamés")
def _():
    source = (ck.RACINE / "RunUp/Views/Live/LiveRunView.swift").read_text(encoding="utf-8")
    table = ck.methodes_localisees(source)
    assert "text" in table.get("bannerBody", set()), table.get("bannerBody")
    trouves = [cle for _, cle in ck.litteraux_des_methodes_localisees(source)]
    # Les trois du GPS sortaient en français chez tout le monde : `bannerBody` prenait un
    # `String`, donc `Text(text)` ne consultait jamais le catalogue où elles étaient traduites.
    assert "Localisation refusée — ouvrir les Réglages" in trouves, trouves
    assert len(trouves) >= 5, trouves


@cas_test("le vrai catalogue est complet et entièrement traduit")
def _():
    assert ck.main() == 0, "check_strings.py refuse le dépôt"


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f(); print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1; print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
