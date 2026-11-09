#!/usr/bin/env python3
"""La politique de confidentialité PUBLIÉE dit-elle ce que l'app collecte ?

# POURQUOI CE CONTRÔLE EXISTE

`privacy.html` est dans ce dépôt, mais ce n'est pas lui qu'Apple et les utilisatrices lisent.
L'adresse déposée sur la fiche App Store est servie par GitHub Pages depuis `main`, pas par
Vercel et pas depuis cette branche. Les deux peuvent donc diverger sans que rien ne le dise.

Elles DIVERGEAIENT le 8 novembre 2026, et de deux façons :

  · la page publiée n'avait pas la couleur d'accent corrigée depuis des semaines ;
  · le jour même, on y a ajouté dans le dépôt le paragraphe des rapports de panne — qui décrit
    une collecte que l'app fait RÉELLEMENT depuis ce commit — et la page publiée ne l'avait pas.

Le second cas est le dangereux, et il a un nom côté Apple : la fiche de confidentialité d'App
Store Connect déclare « Crash Data » et « Performance Data » (via `PrivacyInfo.xcprivacy`),
pendant que la politique liée depuis cette même fiche n'en parle pas. Une divergence entre les
deux est un motif de rejet à part entière, et c'est aussi, plus simplement, faux envers les gens
qui lisent la page.

# LE SENS QUI COMPTE

Une section présente dans le dépôt et ABSENTE de la page publiée est le défaut : l'app collecte
quelque chose que la page ne dit pas. L'inverse — une section publiée qui n'est plus dans le
dépôt — est signalé aussi, mais il est bien moins grave : une page qui déclare de trop ne trompe
personne sur ce qui est pris.

# IL REFUSE, DEPUIS LE JOUR MÊME

`server.yml` lui passe `--exiger`. Il a mesuré sans refuser pendant quelques heures seulement :
la correction ne se faisait pas depuis cette branche — la page est servie par GitHub Pages depuis
`main` — et une chaîne rouge pendant des jours pour une action qu'elle ne peut pas faire apprend
à ignorer un rouge. La page a rattrapé le 8 novembre 2026, vérifiée octet pour octet, et le
drapeau est entré dans la foulée.

Sans `--exiger`, il mesure et se tait : c'est la forme à reprendre si la situation se représente,
la même que `--plancher` dans `check_grand_texte.py`.

# LES INTERTITRES NE SUFFISAIENT PAS

Pendant sa première journée, ce contrôle ne comparait que les intertitres en gras : « Statistiques
d'usage », « Rapports de panne »… Il attrapait donc une section entière qui manque — le défaut du
8 novembre — et RIEN d'autre. Une durée de conservation changée de 180 à 400 jours, un type
d'événement ajouté à la liste, la phrase « n'embarque aucun outil tiers » retirée : tout cela
tient à l'intérieur d'un paragraphe dont le titre ne bouge pas, et serait passé.

Ce n'est pas théorique pour cette page-là : elle est servie par GitHub Pages depuis `main`, une
branche qui ne partage avec la branche de travail que le commit initial du 13 juillet 2026. Elle
se met à jour en recopiant le fichier à la main. C'est exactement la manœuvre où l'on reporte un
paragraphe sur deux.

Il compare donc maintenant le TEXTE de chaque section, pas seulement son titre : balises
retirées, espaces normalisés, apostrophes et espaces insécables ramenés à une forme unique — ce
qui reste est ce qu'une personne lit. Les commentaires HTML sont ignorés des deux côtés : la
branche de travail en porte un que `main` n'a pas, et un commentaire ne se lit pas.
"""
import argparse
import pathlib
import re
import sys
import unicodedata
import urllib.error
import urllib.request

RACINE = pathlib.Path(__file__).resolve().parent.parent
PAGE = RACINE / "privacy.html"
#: L'adresse est lue sur la fiche plutôt que recopiée ici : une copie qui dérive ferait contrôler
#: la mauvaise page, et personne ne s'en apercevrait. Même raison que la `baseURL` de
#: `check_deploiement.py`.
FICHE = RACINE / "APP_STORE_LISTING.md"
ADRESSE = re.compile(r"URL de politique de confidentialité\*\*\s*:\s*`(https://[^`]+)`")

#: Un paragraphe de la page : son intertitre en gras — « Statistiques d'usage », « Rapports de
#: panne »… — qui nomme une famille de données collectées, et le texte qui le suit.
PARAGRAPHE = re.compile(r"<p><strong>([^<]+)</strong>(.*?)</p>", re.S)
COMMENTAIRE = re.compile(r"<!--.*?-->", re.S)
BALISE = re.compile(r"<[^>]+>")

DELAI = 25


def adresse_publiee() -> str:
    texte = FICHE.read_text(encoding="utf-8")
    if trouve := ADRESSE.search(texte):
        return trouve.group(1)
    raise SystemExit(f"Aucune URL de politique dans {FICHE.name} — ce script est à revoir.")


def lisible(fragment: str) -> str:
    """Ce qu'une personne lit : sans balises, sans fantaisie d'espaces ni d'apostrophes."""
    texte = unicodedata.normalize("NFC", BALISE.sub(" ", fragment))
    texte = texte.replace("\u00a0", " ").replace("\u202f", " ").replace("\u2019", "'")
    return re.sub(r"\s+", " ", texte).strip()


def paragraphes(html: str) -> dict:
    """{intertitre: texte lisible}, dans l'ordre, première occurrence gardée."""
    sans_commentaires = COMMENTAIRE.sub("", html)
    trouves = {}
    for titre, corps in PARAGRAPHE.findall(sans_commentaires):
        # Le titre passe par `lisible` lui aussi : une apostrophe typographique d'un côté et
        # droite de l'autre ferait crier « section absente » — l'alarme la plus forte de ce
        # script — pour un caractère que personne ne distingue en lisant.
        propre = lisible(titre)
        if propre and propre not in trouves:
            trouves[propre] = lisible(corps)
    return trouves


def sections(html: str) -> list:
    """Les intertitres seuls, dans l'ordre."""
    return list(paragraphes(html))


def premier_ecart(a: str, b: str) -> tuple:
    """Les deux abords du premier caractère qui diffère — de quoi voir QUOI a changé."""
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            return a[max(0, i - 70):i + 70], b[max(0, i - 70):i + 70]
    return a[-140:], b[-140:]


def telecharger(url: str) -> str:
    requete = urllib.request.Request(url, headers={"User-Agent": "runup-ci"})
    with urllib.request.urlopen(requete, timeout=DELAI) as reponse:
        return reponse.read().decode("utf-8", errors="replace")


def main() -> int:
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("--exiger", action="store_true",
                         help="refuser quand la page publiée ne dit pas ce que le dépôt dit")
    args = options.parse_args()

    url = adresse_publiee()
    au_depot = paragraphes(PAGE.read_text(encoding="utf-8"))
    locales = list(au_depot)
    if not locales:
        print(f"Aucun intertitre lu dans {PAGE.name} — l'analyse a échoué, pas le code.")
        return 1

    try:
        publiee = telecharger(url)
    except (urllib.error.URLError, TimeoutError, OSError) as panne:
        print(f"La politique publiée n'a pas répondu ({url}) : {panne}")
        print("C'est l'adresse déposée sur la fiche App Store. Si elle ne répond pas, personne")
        print("ne peut lire ce que l'app collecte — et Apple non plus.")
        return 1 if args.exiger else 0

    publiees = paragraphes(publiee)
    manquantes = [s for s in locales if s not in publiees]
    divergentes = [s for s in locales if s in publiees and au_depot[s] != publiees[s]]
    en_trop = [s for s in publiees if s not in locales]

    if manquantes:
        print(f"La politique publiée ne dit pas tout ce que le dépôt dit ({url}) :\n")
        for section in manquantes:
            print(f"  · « {section} » est dans privacy.html et PAS sur la page publiée.")
        print("\n    L'app collecte donc quelque chose que la page liée depuis la fiche App Store")
        print("    ne mentionne pas. Cette page est servie par GitHub Pages depuis `main` : la")
        print("    corriger demande d'y porter `privacy.html`, ce qui ne se fait pas depuis la")
        print("    branche de travail.")
        if en_trop:
            print("\n    (Et dans l'autre sens, moins grave :)")
            for section in en_trop:
                print(f"      · « {section} » est publiée et n'est plus dans le dépôt.")
        return 1 if args.exiger else 0

    if divergentes:
        print(f"La politique publiée ne dit plus la même chose que le dépôt ({url}) :\n")
        for section in divergentes:
            ici, la = premier_ecart(au_depot[section], publiees[section])
            print(f"  · « {section} » existe des deux côtés, mais son texte diffère.")
            print(f"      dépôt   … {ici}")
            print(f"      publiée … {la}")
        print("\n    L'intertitre est le même, donc rien ne se voyait : une durée de conservation,")
        print("    un type d'événement, une phrase retirée tiennent tous à l'intérieur d'un")
        print("    paragraphe. La page publiée est servie par GitHub Pages depuis `main` ; la")
        print("    corriger demande d'y porter `privacy.html`, ce qui ne se fait pas depuis la")
        print("    branche de travail.")
        return 1 if args.exiger else 0

    if en_trop:
        print(f"La politique publiée déclare plus que le dépôt ({url}) :\n")
        for section in en_trop:
            print(f"  · « {section} » est publiée et n'est plus dans privacy.html.")
        print("\n    Moins grave : une page qui déclare de trop ne trompe personne sur ce qui est")
        print("    pris. À reporter quand même, pour que les deux disent la même chose.")
        return 1 if args.exiger else 0

    print(f"Politique publiée : {len(locales)} sections, texte compris, "
          f"les mêmes que dans le dépôt.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
