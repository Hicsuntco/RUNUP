#!/usr/bin/env python3
"""Ce qu'on répond à quelqu'un qui paye ne se décide pas dans StoreKit.

# POURQUOI CE CONTRÔLE EXISTE

`SubscriptionService.purchase(_:)` a longtemps fini par cette ligne :

    return isSubscribed == true ? .subscribed : .failed

Elle tombait APRÈS une transaction vérifiée et terminée — Apple a signé, l'argent est prélevé — et
le droit d'accès, lui, met quelques centaines de millisecondes à paraître dans
`Transaction.currentEntitlements`. Le résultat à l'écran : « L'achat n'a pas abouti. », affiché à
quelqu'un qui vient d'être débité, au-dessus d'un bouton d'achat toujours actif.

Le piège était DÉJÀ connu et DÉJÀ contourné trente lignes plus bas, pour les codes promo, avec un
commentaire qui l'expliquait. Deux chemins, un seul corrigé. C'est la forme la plus traître de la
duplication : la connaissance est dans le fichier, et elle ne s'applique qu'à un endroit.

Et le défaut était invisible autrement qu'en payant pour de vrai. Il ne se voit ni au compilateur,
ni aux tests, ni dans un simulateur — où l'entitlement arrive instantanément. Il se voit chez
l'utilisatrice, sur un réseau lent, et il s'enregistre lui-même comme un échec d'achat : la
statistique qui devrait le signaler est celle qu'il corrompt.

# LES TROIS RÈGLES

1. Chaque fonction de paiement DÉLÈGUE. Une fonction de `SubscriptionService` qui rend une issue
   de paiement n'a droit qu'à un seul `return`, et c'est un appel à `<Issue>.decide(`. Pas de
   ternaire, pas de `return .failed` écrit à la main : ces décisions ne se vérifient qu'en
   achetant un abonnement, donc elles doivent vivre dans un type pur.

2. Chaque issue est un type pur et TESTÉ. Elle vit dans `RunUp/Models/`, elle porte un
   `static func decide(`, et elle a son fichier de cas dans `RunUpTests/`.

3. Chaque CAS de chaque issue est nommé dans ses cas de test. Ajouter une issue sans la tester,
   c'est rouvrir le même trou par le haut.

# CE QUE CE CONTRÔLE NE SAIT PAS FAIRE

Il ne lit pas les phrases. Il ne peut pas dire qu'une issue annonce une chose fausse — c'est le
travail des cas de test, qui vérifient que deux issues distinctes ne disent pas la même chose.
Il garantit seulement que la décision est à un endroit où elle PEUT être vérifiée.
"""
import pathlib, re, sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
SERVICE = RACINE / "RunUp/Services/SubscriptionService.swift"
MODELES = RACINE / "RunUp/Models"
CAS = RACINE / "RunUpTests"

# Les issues de paiement, par nom de type. Chacune est rendue par une fonction du service et
# consommée par le paywall.
ISSUES = ["PurchaseOutcome", "OfferCodeOutcome", "RestoreOutcome"]

# `func nom(...) async -> Issue {` — la flèche peut porter n'importe quel attribut avant elle.
def signatures(src, issue):
    return re.finditer(r"func\s+(\w+)\s*\([^)]*\)[^{\n]*->\s*" + issue + r"\s*\{", src)


def corps(src, debut):
    """Le corps de la fonction dont l'accolade ouvrante est à `debut`, accolades équilibrées.

    Un découpage par accolades et non par indentation : un `switch` imbriqué, une fermeture passée
    en argument ou un `do { } catch { }` déplaceraient n'importe quel comptage de colonnes.
    """
    niveau = 0
    for i in range(debut, len(src)):
        if src[i] == "{":
            niveau += 1
        elif src[i] == "}":
            niveau -= 1
            if niveau == 0:
                return src[debut + 1:i]
    return src[debut:]


def sans_commentaires_ni_chaines(src):
    from swift import sans_commentaires
    # Les chaînes partent aussi : un message peut contenir le mot `return`, et un commentaire de
    # ce fichier cite justement la ligne fautive — ce contrôle se signalerait lui-même.
    return re.sub(r'"[^"\n]*"', '""', sans_commentaires(src))


def regle_delegation():
    """1. Une fonction qui rend une issue de paiement n'a qu'un `return`, et il délègue."""
    defauts = []
    src = sans_commentaires_ni_chaines(SERVICE.read_text())
    trouvees = 0
    for issue in ISSUES:
        for m in signatures(src, issue):
            trouvees += 1
            nom = m.group(1)
            body = corps(src, m.end() - 1)
            retours = re.findall(r"\breturn\b([^\n]*)", body)
            if len(retours) != 1:
                defauts.append(
                    f"{SERVICE.name} : `{nom}` rend {issue} par {len(retours)} `return` au lieu "
                    f"d'un seul. Une issue de paiement se décide en UN endroit, dans {issue}.decide(), "
                    f"où elle se vérifie sans acheter d'abonnement.")
                continue
            if f"{issue}.decide(" not in retours[0]:
                defauts.append(
                    f"{SERVICE.name} : `{nom}` décide son issue sur place — `return{retours[0]}`. "
                    f"C'est exactement la ligne qui annonçait « L'achat n'a pas abouti. » après une "
                    f"transaction signée par Apple. Elle appartient à {issue}.decide().")
    if trouvees < len(ISSUES):
        defauts.append(
            f"{SERVICE.name} : {trouvees} fonction(s) rendant une issue de paiement, il en faut au "
            f"moins {len(ISSUES)} — une par issue. Une signature a changé, ou une issue n'est plus "
            f"rendue par le service : ce contrôle ne regarde plus ce qu'il croit regarder.")
    return defauts


def regle_type_pur():
    """2. Chaque issue vit dans un modèle pur, avec un `decide` et un fichier de cas."""
    defauts = []
    for issue in ISSUES:
        modele = MODELES / f"{issue}.swift"
        if not modele.exists():
            defauts.append(f"{issue} n'a pas de modèle `RunUp/Models/{issue}.swift` : la décision "
                           f"est mêlée à StoreKit, donc invérifiable autrement qu'en payant.")
            continue
        src = modele.read_text()
        if "static func decide(" not in src:
            defauts.append(f"RunUp/Models/{issue}.swift n'expose pas `static func decide(` : il n'y "
                           f"a rien à appeler depuis le service, ni rien à tester.")
        if "import StoreKit" in src:
            defauts.append(f"RunUp/Models/{issue}.swift importe StoreKit. Une issue qui dépend de "
                           f"StoreKit ne se construit pas dans un test — c'est tout ce qu'on gagnait "
                           f"en la sortant du service.")
        if not (CAS / f"{issue}Tests.swift").exists():
            defauts.append(f"{issue} n'a pas de cas : `RunUpTests/{issue}Tests.swift` est absent.")
    return defauts


def cas_de_lenum(src, issue):
    """Les noms de cas déclarés par l'énumération `issue`, y compris les `case a, b, c`."""
    m = re.search(r"enum\s+" + issue + r"\b[^{]*\{", src)
    if not m:
        return []
    body = corps(src, m.end() - 1)
    # LES ÉNUMÉRATIONS IMBRIQUÉES SONT RETIRÉES EN ENTIER, corps compris. `StoreKitResult` porte
    # six cas qui sont des ENTRÉES de la décision, pas des issues ; les compter ici gonflait le
    # total de 11 à 17 et aurait exigé qu'on « teste » des entrées comme si c'étaient des
    # réponses. Le premier jet ne remplaçait que l'en-tête `enum X {`, ce qui laissait ses cas
    # dans le texte — un contrôle vert sur la mauvaise liste.
    while True:
        imbriquee = re.search(r"enum\s+\w+\b[^{]*\{", body)
        if not imbriquee:
            break
        fin = imbriquee.end() + len(corps(body, imbriquee.end() - 1)) + 1  # +1 : l'accolade fermante.
        body = body[:imbriquee.start()] + body[fin:]
    noms = []
    for ligne in re.findall(r"^\s*case\s+([^\n/]+)$", body, re.M):
        for brut in ligne.split(","):
            n = brut.strip().split("(")[0].strip()
            if re.fullmatch(r"[a-z]\w*", n):
                noms.append(n)
    return noms


def regle_cas_testes():
    """3. Chaque cas d'une issue est nommé dans ses cas de test."""
    defauts = []
    for issue in ISSUES:
        modele = MODELES / f"{issue}.swift"
        fichier_cas = CAS / f"{issue}Tests.swift"
        if not modele.exists() or not fichier_cas.exists():
            continue  # Déjà signalé par la règle 2.
        noms = cas_de_lenum(sans_commentaires_ni_chaines(modele.read_text()), issue)
        if not noms:
            defauts.append(f"RunUp/Models/{issue}.swift : aucun cas lu dans l'énumération. La forme "
                           f"du fichier a changé et ce contrôle ne voit plus rien — il passerait "
                           f"vert pour la mauvaise raison.")
            continue
        texte = sans_commentaires_ni_chaines(fichier_cas.read_text())
        for n in noms:
            if not re.search(r"\.\s*" + n + r"\b", texte):
                defauts.append(f"{issue}.{n} n'apparaît dans aucun cas de "
                               f"RunUpTests/{issue}Tests.swift : une issue que personne ne vérifie.")
    return defauts


def main():
    defauts = regle_delegation() + regle_type_pur() + regle_cas_testes()
    if defauts:
        for d in defauts:
            print("DÉFAUT", d)
        return 1
    total = sum(len(cas_de_lenum(sans_commentaires_ni_chaines((MODELES / f"{i}.swift").read_text()), i))
                for i in ISSUES)
    print(f"Paiement : {len(ISSUES)} issues déléguées à un type pur, {total} cas tous couverts.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
