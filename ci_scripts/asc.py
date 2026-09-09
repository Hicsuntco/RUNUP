#!/usr/bin/env python3
"""App Store Connect depuis le terminal : créer une version, y pousser la fiche, l'envoyer en revue.

Recopier trois descriptions de 4 000 caractères, trois jeux de mots-clés et trois textes
promotionnels dans un formulaire web est exactement le genre de tâche où l'on colle la mauvaise
langue au mauvais endroit sans s'en apercevoir. `APP_STORE_LISTING.md` est la source, ce script
l'envoie tel quel.

# NORMALEMENT, ON NE LANCE PAS CE SCRIPT À LA MAIN.
#
# Il est piloté par `.github/workflows/appstore.yml` : onglet Actions → App Store → Run workflow.
# Les trois secrets y sont déjà, ce sont ceux de la chaîne TestFlight — donc pas de fichier `.p8`
# à retrouver sur une machine, et rien à taper dans un terminal. C'était tout l'intérêt de monter
# cette chaîne ; l'utiliser à moitié n'aurait aucun sens.
#
# En local, si un jour c'est utile :
#
#     export ASC_KEY_ID=...          # l'identifiant de la clé
#     export ASC_ISSUER_ID=...       # l'identifiant d'émetteur (page Clés d'API)
#     export ASC_KEY_PATH=~/AuthKey_XXXXXXXX.p8
#
#     python3 ci_scripts/asc.py status              # ce qu'App Store Connect voit aujourd'hui
#     python3 ci_scripts/asc.py create-version 2.5  # créer la version iOS
#     python3 ci_scripts/asc.py push-metadata 2.5   # y pousser fr, en et es depuis le markdown
#     python3 ci_scripts/asc.py push-metadata 2.5 --dry-run   # afficher sans rien envoyer
#     python3 ci_scripts/asc.py submit 2.5          # attacher la build et envoyer en revue

Ce que le script NE fait PAS, parce que l'API ne l'expose pas ou mal : les captures d'écran, le
questionnaire de confidentialité, la classification d'âge, et le nom et le sous-titre de l'app
(`appInfoLocalizations`, qui ne dépendent pas d'une version). Ceux-là restent sur le web.
"""
import argparse, base64, datetime, hashlib, json, os, pathlib, re, subprocess, sys, tempfile, time
import urllib.request, urllib.error

ROOT = pathlib.Path(__file__).resolve().parent.parent
LISTING = ROOT / "APP_STORE_LISTING.md"
BUNDLE_ID = "com.hicsuntco.runup"
API = "https://api.appstoreconnect.apple.com/v1"

# (locale App Store, ancre de section, titres des champs dans cette langue)
LANGS = [
    ("fr-FR", "# 🇫🇷", {"name": "Nom de l'app", "subtitle": "Sous-titre",
                         "promo": "Texte promotionnel", "description": "Description",
                         "keywords": "Mots-clés", "whatsNew": "Nouveautés de cette version"}),
    ("en-US", "# 🇬🇧", {"name": "App name", "subtitle": "Subtitle",
                         "promo": "Promotional text", "description": "Description",
                         "keywords": "Keywords", "whatsNew": "What's New in This Version"}),
    ("es-ES", "# 🇪🇸", {"name": "Nombre de la app", "subtitle": "Subtítulo",
                         "promo": "Texto promocional", "description": "Descripción",
                         "keywords": "Palabras clave", "whatsNew": "Novedades de esta versión"}),
]


# ── Authentification ──────────────────────────────────────────────────────────────────────────

def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token() -> str:
    """Un JWT ES256 valable 20 minutes, signé avec la clé .p8.

    Signé via `openssl` plutôt qu'avec une bibliothèque : le Python livré avec macOS n'a ni PyJWT
    ni `cryptography`, et demander une installation pour créer une version serait un obstacle de
    plus. `openssl` est là par défaut.
    """
    key_id = os.environ.get("ASC_KEY_ID")
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_path = os.environ.get("ASC_KEY_PATH")
    missing = [n for n, v in (("ASC_KEY_ID", key_id), ("ASC_ISSUER_ID", issuer),
                              ("ASC_KEY_PATH", key_path)) if not v]
    if missing:
        sys.exit(f"Variables manquantes : {', '.join(missing)}\n"
                 f"Elles se trouvent sur App Store Connect → Utilisateurs et accès → Intégrations "
                 f"→ Clés d'API. Le fichier .p8 n'est téléchargeable qu'UNE fois ; sans lui, il "
                 f"faut créer une nouvelle clé.")
    key_file = pathlib.Path(key_path).expanduser()
    if not key_file.exists():
        sys.exit(f"Clé introuvable : {key_file}")

    header = _b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"},
                             separators=(",", ":")).encode())
    payload = _b64(json.dumps({"iss": issuer, "iat": int(time.time()),
                               "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"},
                              separators=(",", ":")).encode())
    signing_input = f"{header}.{payload}".encode()

    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp.write(signing_input)
        tmp_path = tmp.name
    try:
        der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key_file), tmp_path],
                             capture_output=True, check=True).stdout
    except subprocess.CalledProcessError as e:
        sys.exit(f"Signature impossible : {e.stderr.decode().strip()}")
    finally:
        os.unlink(tmp_path)

    # `openssl` rend une signature DER ; JWT attend R||S bruts, 32 octets chacun.
    def der_to_raw(sig: bytes) -> bytes:
        assert sig[0] == 0x30
        idx = 2 if sig[1] < 0x80 else 3
        out = b""
        for _ in range(2):
            assert sig[idx] == 0x02
            ln = sig[idx + 1]
            val = sig[idx + 2: idx + 2 + ln].lstrip(b"\x00")
            out += val.rjust(32, b"\x00")
            idx += 2 + ln
        return out

    return f"{header}.{payload}.{_b64(der_to_raw(der))}"


def call(method: str, path: str, body=None):
    url = path if path.startswith("http") else f"{API}/{path}"
    data = json.dumps(body).encode() if body is not None else None

    # UN 500 SUR UNE LECTURE SE RÉESSAIE, PAS UN 500 SUR UNE ÉCRITURE. Le serveur d'Apple rend
    # des 500 passagers : la même requête `GET .../offerCodes` a échoué puis réussi à deux minutes
    # d'intervalle, et faire tomber toute la commande pour ça n'a aucun sens. Mais un POST qui
    # rend 500 peut très bien avoir créé l'objet avant de se plaindre — le rejouer créerait un
    # doublon d'une offre qu'on ne peut ensuite que désactiver. Les lectures seulement, donc.
    tentatives = 3 if method == "GET" else 1
    for essai in range(tentatives):
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {token()}")
        if data:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            if e.code >= 500 and essai < tentatives - 1:
                time.sleep(2 ** essai)
                continue
            detail = e.read().decode()
            try:
                for err in json.loads(detail).get("errors", []):
                    print(f"  Apple : {err.get('title')} — {err.get('detail')}", file=sys.stderr)
            except Exception:
                print(detail, file=sys.stderr)
            sys.exit(f"HTTP {e.code} sur {method} {path}")


# ── Lecture de la fiche ───────────────────────────────────────────────────────────────────────

def listing():
    text = LISTING.read_text(encoding="utf-8")
    out = {}
    for locale, anchor, fields in LANGS:
        start = text.index(anchor)
        nxt = [text.index(a) for _, a, _ in LANGS if text.index(a) > start]
        end = min(nxt) if nxt else text.index("# Sections communes")
        section = text[start:end]
        values = {}
        for key, title in fields.items():
            m = re.search(rf"^## {re.escape(title)}[^\n]*\n```\n(.*?)\n```", section, re.S | re.M)
            if not m:
                sys.exit(f"Champ « {title} » introuvable pour {locale} dans {LISTING.name}")
            values[key] = m.group(1).strip()
        out[locale] = values
    return out


def app_id():
    apps = call("GET", f"apps?filter[bundleId]={BUNDLE_ID}")["data"]
    if not apps:
        sys.exit(f"Aucune app avec le bundle {BUNDLE_ID} sur ce compte.")
    return apps[0]["id"], apps[0]["attributes"]["name"]


# ── Commandes ─────────────────────────────────────────────────────────────────────────────────

def print_run_actions(build_run_id: str) -> None:
    """Le détail des actions d'une exécution qui ne s'est pas plantée.

    « SUCCEEDED » ne veut pas dire « la build est sur TestFlight ». Une exécution peut très bien
    compiler et archiver proprement sans que l'étape de distribution ait tourné — et de l'extérieur
    les deux cas sont rigoureusement identiques : un vert dans Xcode Cloud, rien dans TestFlight.
    Lister les actions et leur état sépare les deux sans ouvrir un navigateur.
    """
    try:
        actions = call("GET", f"ciBuildRuns/{build_run_id}/actions?limit=10")["data"]
    except SystemExit:
        return
    for action in actions:
        aa = action["attributes"]
        state = aa.get("completionStatus") or aa.get("executionProgress") or "?"
        print(f"      [{aa.get('name', '?')}] {state}")


def print_build_issues(build_run_id: str, limit: int = 15) -> None:
    """Les erreurs qui ont fait échouer une exécution, lues depuis App Store Connect.

    Sans elles, « FAILED » oblige à ouvrir Xcode Cloud dans un navigateur pour apprendre qu'il
    manquait une virgule. Une exécution se décompose en actions (Build, Test, Archive…) et chaque
    action porte ses problèmes.

    Rien n'est filtré. La première version ne demandait les problèmes qu'aux actions dont
    `issueCounts.errors` était non nul, et ne gardait que le type ERROR : sur une exécution
    réellement en échec, elle n'a rien affiché du tout. Un outil de diagnostic qui se tait est
    pire que pas d'outil — il fait conclure qu'il n'y a rien à voir. On demande donc tout, et on
    montre ce qui vient, y compris le décompte brut par action quand Apple ne détaille pas.

    Tout est protégé : ce bloc sert à comprendre une panne, il n'a pas le droit d'en provoquer une.
    """
    try:
        actions = call("GET", f"ciBuildRuns/{build_run_id}/actions?limit=10")["data"]
    except SystemExit:
        print("      (impossible de lire les actions de cette exécution)")
        return
    if not actions:
        print("      (aucune action rattachée à cette exécution)")
        return

    shown = 0
    for action in actions:
        aa = action["attributes"]
        name = aa.get("name", "?")
        counts = aa.get("issueCounts") or {}
        summary = ", ".join(f"{k} : {v}" for k, v in counts.items() if v) or "aucun décompte"
        print(f"      [{name}] {aa.get('completionStatus') or aa.get('executionProgress')} — {summary}")
        try:
            issues = call("GET", f"ciBuildActions/{action['id']}/issues?limit={limit}")["data"]
        except SystemExit:
            print("        (problèmes non lisibles pour cette action)")
            continue
        for issue in issues:
            ia = issue["attributes"]
            source = ia.get("fileSource") or {}
            where = source.get("path") or ""
            line = source.get("lineNumber") if isinstance(source.get("lineNumber"), int) else None
            location = f"{where}:{line}" if where and line else where
            message = " ".join((ia.get("message") or "").split())
            print(f"        {ia.get('issueType', '?')} · {message}")
            if location:
                print(f"          {location}")
            shown += 1
            if shown >= limit:
                return
    if shown == 0:
        print("      (Apple ne renvoie le détail d'aucun problème — voir Xcode Cloud)")


def cmd_status(_):
    aid, name = app_id()
    print(f"App : {name}  ({BUNDLE_ID})\n")

    # Les builds d'abord. C'est la question qu'on se pose vraiment en ouvrant cet écran : « ce que
    # je viens de pousser est-il dans ce que j'ai sur mon téléphone ? » — et le numéro de version
    # ne la répond pas, puisque dix builds partagent la même version 2.5. Le numéro de build et sa
    # date d'envoi la répondent, en une ligne, sans ouvrir App Store Connect.
    #
    # Route de premier niveau avec un filtre, et non la relation `apps/{id}/builds` : celle-ci
    # refuse `sort` avec un 400. Et le bloc entier est protégé — un ajout de diagnostic n'a pas à
    # emporter la commande qui l'héberge, sinon `status` cesse de dire l'état des versions le jour
    # où Apple change quelque chose à l'endpoint des builds.
    #
    # Le tri est fait ici, sur le numéro de build, et non par l'API sur `uploadedDate` : cette
    # date est remplie n'importe comment. La build 1072 y était datée de 13 h 03 alors qu'elle est
    # apparue après 20 h — un tri sur cette date range donc les plus récentes n'importe où, et
    # « les cinq dernières » en devient un mensonge. On demande une grande page, on trie sur le
    # seul champ fiable, et on n'affiche que le haut.
    #
    # `preReleaseVersion` est demandé pour la même raison : une build rattachée à une autre chaîne
    # de version (2.4, 2.6…) est invisible dans l'écran TestFlight de la 2.5 tout en existant
    # parfaitement côté API. Si elle est là, il faut le voir ici plutôt que la chercher à la main.
    builds, trains = None, {}
    for query in (f"builds?filter[app]={aid}&limit=200&include=preReleaseVersion",
                  f"builds?filter[app]={aid}&limit=200"):
        try:
            page = call("GET", query)
        except SystemExit:
            continue
        builds = page["data"]
        trains = {i["id"]: i["attributes"].get("version")
                  for i in page.get("included", []) if i["type"] == "preReleaseVersions"}
        break
    if builds is None:
        print("  (impossible de lire les builds — le reste du statut suit)\n")
    if builds:
        def build_number(b):
            raw = (b["attributes"].get("version") or "").strip()
            return int(raw) if raw.isdigit() else -1
        builds.sort(key=build_number, reverse=True)
        print(f"  Dernières builds envoyées sur TestFlight ({len(builds)} au total) :")
        for b in builds[:8]:
            a = b["attributes"]
            uploaded = (a.get("uploadedDate") or "")[:16].replace("T", " à ")
            state = a.get("processingState", "?")
            expired = " (expirée)" if a.get("expired") else ""
            rel = b.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}
            train = trains.get(rel.get("id")) or "?"
            print(f"    build {a.get('version', '?'):>6}   version {train:<6} "
                  f"{uploaded} UTC   {state}{expired}")
        print()
    elif builds is not None:
        print("  Aucune build envoyée.\n")

    # ⚠️ CE QUI SUIT N'EST PAS LA CHAÎNE DE LIVRAISON.
    #
    # Les builds qui arrivent sur TestFlight sont construites et envoyées par le workflow GitHub
    # Actions « TestFlight » (`.github/workflows/testflight.yml`), sur une machine macOS louée,
    # avec les certificats de distribution du dépôt. Son numéro de build vaut 1000 + son numéro
    # d'exécution — d'où les 10XX de la liste ci-dessus.
    #
    # Xcode Cloud, lui, ne fait qu'archiver dans son coin : « Distribution Preparation » est sur
    # None, il n'envoie rien. C'est un contrôle de compilation, utile, et RIEN D'AUTRE.
    #
    # Cette confusion a coûté une journée entière. Cet outil affichait les exécutions Xcode Cloud
    # sous les builds, sans rien dire de leur rôle ; trois d'entre elles se sont terminées
    # SUCCEEDED pendant que la vraie chaîne échouait à l'envoi sur un quota Apple épuisé, et le
    # diagnostic a conclu à un blocage de compte. Un outil qui montre le mauvais tuyau est pire
    # qu'un outil muet : il donne une réponse, et elle est fausse.
    #
    # En lecture seule, protégé : une clé sans droits Xcode Cloud ne doit pas empêcher le reste
    # de s'afficher.
    print("  Les builds ci-dessus viennent du workflow GitHub Actions « TestFlight »")
    print("  (numéro de build = 1000 + numéro d'exécution). Ce qui suit ne livre RIEN :\n")
    try:
        products = call("GET", "ciProducts?limit=20")["data"]
    except SystemExit:
        products = []
    for product in products:
        if not (product["attributes"].get("name") or "").upper().startswith("RUNUP"):
            continue
        try:
            workflows = call("GET", f"ciProducts/{product['id']}/workflows?limit=20")["data"]
        except SystemExit:
            break
        for wf in workflows:
            a = wf["attributes"]
            print(f"  Xcode Cloud · « {a.get('name')} » — {'actif' if a.get('isEnabled') else 'DÉSACTIVÉ'}"
                  f"   (contrôle de compilation seulement)")
            try:
                runs = call("GET", f"ciWorkflows/{wf['id']}/buildRuns?limit=3&sort=-number")["data"]
            except SystemExit:
                runs = []
            if not runs:
                print("    aucune exécution")
            for r in runs:
                ra = r["attributes"]
                started = (ra.get("startedDate") or ra.get("createdDate") or "")[:16].replace("T", " à ")
                status = ra.get("completionStatus") or ra.get("executionProgress") or "?"
                reason = f"   ({ra['cancelReason']})" if ra.get("cancelReason") else ""
                print(f"    #{ra.get('number', '?'):<5} {started} UTC   {status}{reason}")
                if status == "FAILED":
                    print_build_issues(r["id"])
                else:
                    print_run_actions(r["id"])
        print()

    versions = call("GET", f"apps/{aid}/appStoreVersions?limit=5")["data"]
    if not versions:
        print("Aucune version. → python3 ci_scripts/asc.py create-version 2.5")
        return
    for v in versions:
        a = v["attributes"]
        print(f"  version {a['versionString']:8} {a['appStoreState']:28} plateforme {a['platform']}")
        locs = call("GET", f"appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]
        print(f"    localisations : {', '.join(sorted(l['attributes']['locale'] for l in locs)) or 'aucune'}")


def cmd_ci(_):
    """Les dernières exécutions Xcode Cloud : ont-elles tourné, et se sont-elles bien terminées ?

    Une build absente de TestFlight a deux causes très différentes — la construction a échoué, ou
    elle n'a jamais démarré (quota épuisé, déclencheur qui ne couvre pas la branche) — et le
    remède n'est pas le même. La liste des builds ne les distingue pas : dans les deux cas, elle
    ne montre rien. Celle-ci les distingue.

    Xcode Cloud est exposé par la même API et la même clé, à condition que la clé ait le rôle qui
    va avec. Si Apple refuse, on le dit et on s'arrête là plutôt que de laisser une trace HTTP.
    """
    try:
        products = call("GET", "ciProducts?limit=20")["data"]
    except SystemExit:
        sys.exit("Cette clé d'API n'a pas accès à Xcode Cloud (rôle insuffisant). "
                 "→ regarde directement dans App Store Connect → Xcode Cloud.")

    mine = [p for p in products
            if (p["attributes"].get("name") or "").upper().startswith("RUNUP")] or products
    if not mine:
        print("Aucun produit Xcode Cloud sur ce compte.")
        return

    for product in mine:
        print(f"Produit Xcode Cloud : {product['attributes'].get('name')}\n")
        workflows = call("GET", f"ciProducts/{product['id']}/workflows?limit=20")["data"]
        for wf in workflows:
            a = wf["attributes"]
            state = "actif" if a.get("isEnabled") else "DÉSACTIVÉ"
            locked = " (verrouillé)" if a.get("isLockedForEditing") else ""
            print(f"  Workflow « {a.get('name')} » — {state}{locked}")
            runs = call("GET", f"ciWorkflows/{wf['id']}/buildRuns?limit=5&sort=-number")["data"]
            if not runs:
                print("    aucune exécution\n")
                continue
            for r in runs:
                ra = r["attributes"]
                started = (ra.get("startedDate") or ra.get("createdDate") or "")[:16].replace("T", " à ")
                status = ra.get("completionStatus") or ra.get("executionProgress") or "?"
                reason = ra.get("cancelReason")
                branch = ((ra.get("sourceCommit") or {}).get("webUrl") or "")
                print(f"    #{ra.get('number', '?'):<5} {started} UTC   {status}"
                      + (f"   ({reason})" if reason else ""))
                if branch:
                    print(f"          {branch}")
            print()


def cmd_create_version(args):
    aid, _ = app_id()
    existing = call("GET", f"apps/{aid}/appStoreVersions?filter[versionString]={args.version}")["data"]
    if existing:
        print(f"La version {args.version} existe déjà ({existing[0]['attributes']['appStoreState']}). Rien à faire.")
        return
    r = call("POST", "appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": args.version},
        "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})
    print(f"Version {args.version} créée — état : {r['data']['attributes']['appStoreState']}")


def cmd_push_metadata(args):
    aid, _ = app_id()
    versions = call("GET", f"apps/{aid}/appStoreVersions?filter[versionString]={args.version}")["data"]
    if not versions:
        sys.exit(f"Version {args.version} introuvable. → create-version {args.version} d'abord.")
    vid = versions[0]["id"]
    data = listing()
    existing = {l["attributes"]["locale"]: l["id"]
                for l in call("GET", f"appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]}

    for locale, fields in data.items():
        # `whatsNew` est OBLIGATOIRE dès qu'une version de l'app est déjà en vente : sans notes
        # de version, la soumission est refusée. L'app est publiée depuis la 1.1, donc ce champ
        # ne peut pas être omis.
        attrs = {"description": fields["description"], "keywords": fields["keywords"],
                 "promotionalText": fields["promo"], "whatsNew": fields["whatsNew"],
                 "supportUrl": "https://hicsuntco.github.io/RUNUP/privacy.html"}
        if args.dry_run:
            print(f"\n── {locale} " + "─" * 50)
            for k, v in attrs.items():
                one = v.replace("\n", " ⏎ ")
                print(f"  {k:16} {len(v):>5} car.  {one[:70]}{'…' if len(one) > 70 else ''}")
            continue
        if locale in existing:
            call("PATCH", f"appStoreVersionLocalizations/{existing[locale]}",
                 {"data": {"type": "appStoreVersionLocalizations", "id": existing[locale],
                           "attributes": attrs}})
            print(f"  {locale} mis à jour")
        else:
            call("POST", "appStoreVersionLocalizations", {"data": {
                "type": "appStoreVersionLocalizations",
                "attributes": {**attrs, "locale": locale},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
            print(f"  {locale} créé")
    if args.dry_run:
        print("\n(--dry-run : rien n'a été envoyé)")


def builds_for(aid: str, version: str):
    """Les builds envoyées SUR CETTE CHAÎNE DE VERSION, la plus récente d'abord.

    Le filtre décisif est `preReleaseVersion` et non le numéro de build : une build 1128 peut
    parfaitement porter la version 2.6 si elle a été construite avant le changement de
    `CFBundleShortVersionString`. Attachée à la 2.7, Apple la refuse avec un 90062 — et c'est
    exactement l'erreur qui a coûté une soirée à la 2.6.
    """
    page = call("GET", f"builds?filter[app]={aid}&limit=200&include=preReleaseVersion")
    trains = {i["id"]: i["attributes"].get("version")
              for i in page.get("included", []) if i["type"] == "preReleaseVersions"}
    out = []
    for b in page["data"]:
        a = b["attributes"]
        rel = b.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}
        if trains.get(rel.get("id")) != version or a.get("expired"):
            continue
        raw = (a.get("version") or "").strip()
        out.append({"id": b["id"], "number": int(raw) if raw.isdigit() else -1,
                    "state": a.get("processingState", "?"),
                    "uploaded": (a.get("uploadedDate") or "")[:16].replace("T", " à ")})
    out.sort(key=lambda b: b["number"], reverse=True)
    return out


def screenshot_count(vid: str) -> dict:
    """Combien de captures porte chaque langue de cette version.

    Une version créée par l'API hérite normalement des captures de la précédente, mais « normalement »
    n'est pas une vérification : une soumission sans captures est refusée, et le refus arrive des
    heures plus tard. Ça se lit en trois requêtes, autant les faire avant d'envoyer.
    """
    counts = {}
    for loc in call("GET", f"appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]:
        n = 0
        try:
            for s in call("GET", f"appStoreVersionLocalizations/{loc['id']}/appScreenshotSets"
                                 "?include=appScreenshots")["data"]:
                n += len(s.get("relationships", {}).get("appScreenshots", {}).get("data") or [])
        except SystemExit:
            n = -1
        counts[loc["attributes"]["locale"]] = n
    return counts


def annuler_soumission(aid: str, vid: str) -> bool:
    """Retirer une version de la file de revue, pour pouvoir lui changer sa build.

    Une version déjà envoyée ne se modifie pas : sa build est figée tant qu'elle est dans la file.
    Le seul chemin est de retirer la soumission, changer la build, renvoyer. Tant que la revue n'a
    pas COMMENCÉ, ça ne coûte que la place dans la file — quelques heures au pire. Une fois la
    revue commencée, c'est une autre affaire : on repart de zéro derrière tout le monde.
    """
    for etat in ("READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"):
        for r in call("GET", f"reviewSubmissions?filter[app]={aid}&filter[state]={etat}")["data"]:
            items = call("GET", f"reviewSubmissions/{r['id']}/items?include=appStoreVersion")["data"]
            porte = any((i.get("relationships", {}).get("appStoreVersion", {}).get("data") or {})
                        .get("id") == vid for i in items)
            if not porte:
                continue
            call("PATCH", f"reviewSubmissions/{r['id']}", {"data": {
                "type": "reviewSubmissions", "id": r["id"], "attributes": {"canceled": True}}})
            print(f"  Soumission retirée de la file (elle était en {etat}).")
            return True
    return False


def cmd_submit(args):
    """Attacher une build à la version, puis l'envoyer en revue.

    C'est le dernier maillon qui manquait : `create-version` et `push-metadata` préparaient la
    fiche, mais il fallait encore ouvrir App Store Connect dans un navigateur pour choisir la
    build et cliquer sur « Envoyer ». Les deux gestes sont ici.
    """
    aid, _ = app_id()

    versions = call("GET", f"apps/{aid}/appStoreVersions?filter[versionString]={args.version}")["data"]
    if not versions:
        sys.exit(f"Version {args.version} introuvable. → create-version {args.version} d'abord.")
    vid, state = versions[0]["id"], versions[0]["attributes"]["appStoreState"]
    # Une soumission engage aussi la MISE EN VENTE : `AFTER_APPROVAL` publie tout seul dès qu'Apple
    # approuve, `MANUAL` attend un clic. Ça ne se devine pas depuis l'écran de soumission, et ça se
    # découvre mal en voyant la version apparaître sur l'App Store un dimanche matin.
    sortie = versions[0]["attributes"].get("releaseType") or "non précisé"
    print(f"  Version {args.version} — état {state}, mise en vente : {sortie}")

    # Les états où la version accepte encore une build et une soumission. Tout le reste — déjà en
    # revue, en attente de publication, en vente — n'est pas une erreur à contourner : c'est une
    # information, et la réponse est de ne rien faire.
    OUVERTS = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
               "METADATA_REJECTED", "INVALID_BINARY"}
    if state not in OUVERTS and args.replace:
        # Apple ne rend pas la version modifiable dans la seconde qui suit le retrait : on
        # attend qu'elle repasse dans un état ouvert plutôt que d'échouer sur un 409 deux lignes
        # plus bas.
        if annuler_soumission(aid, vid):
            for _ in range(10):
                time.sleep(3)
                state = call("GET", f"appStoreVersions/{vid}")["data"]["attributes"]["appStoreState"]
                if state in OUVERTS:
                    break
            print(f"  La version est repassée en {state}.")
    if state not in OUVERTS:
        print(f"La version {args.version} est en état {state} — rien à envoyer."
              + ("" if args.replace else "  (--replace pour la retirer de la file et recommencer)"))
        return

    candidates = builds_for(aid, args.version)
    if not candidates:
        sys.exit(f"Aucune build sur la chaîne {args.version}. La chaîne d'une build est fixée par "
                 f"son CFBundleShortVersionString au moment de la compilation.")

    print(f"  Builds de la chaîne {args.version} :")
    for b in candidates[:6]:
        print(f"    build {b['number']:>6}   {b['uploaded']} UTC   {b['state']}")
    print()

    valides = [b for b in candidates if b["state"] == "VALID"]
    if args.build:
        choisie = next((b for b in candidates if b["number"] == args.build), None)
        if choisie is None:
            sys.exit(f"La build {args.build} n'est pas sur la chaîne {args.version}.")
        if choisie["state"] != "VALID":
            sys.exit(f"La build {args.build} est en état {choisie['state']}, pas VALID.")
    else:
        if not valides:
            sys.exit(f"Aucune build VALID sur la chaîne {args.version} — la plus récente est en "
                     f"état {candidates[0]['state']}. Le traitement Apple prend ~10 minutes.")
        choisie = valides[0]
    print(f"  Build retenue : {choisie['number']}")

    # SEULE LA LANGUE PRINCIPALE DOIT PORTER DES CAPTURES. Les autres s'en passent : l'App Store
    # affiche alors celles de la langue principale. C'est une règle qu'il aurait été facile de
    # rater dans l'autre sens — bloquer sur en-US et es-ES vides, et partir chercher des captures
    # que la version précédente n'avait pas non plus. D'où le rappel de ce que portait la dernière
    # version APPROUVÉE : c'est la seule preuve qui vaille que l'absence passe la revue.
    primaire = call("GET", f"apps/{aid}")["data"]["attributes"].get("primaryLocale") or "fr-FR"
    captures = screenshot_count(vid)
    if not captures:
        sys.exit("Aucune localisation sur cette version. → push-metadata d'abord.")
    for locale, n in sorted(captures.items()):
        role = "  ← langue principale" if locale == primaire else " (repli sur la principale)" if not n else ""
        print(f"    {locale} : {n if n >= 0 else '?'} captures{role}")
    for v in call("GET", f"apps/{aid}/appStoreVersions?limit=10")["data"]:
        if v["attributes"]["appStoreState"] != "READY_FOR_SALE":
            continue
        ref = screenshot_count(v["id"])
        print(f"    (pour mémoire, la {v['attributes']['versionString']} approuvée portait : "
              + ", ".join(f"{l} {n}" for l, n in sorted(ref.items())) + ")")
        break
    if captures.get(primaire, 0) < 1 and not args.force:
        sys.exit(f"Aucune capture pour {primaire}, la langue principale — la soumission serait "
                 f"refusée. Les ajouter sur le web, ou relancer avec --force.")

    if args.dry_run:
        print(f"\n(--dry-run : la build {choisie['number']} SERAIT attachée à la {args.version}, "
              f"et la version SERAIT envoyée en revue. Rien n'a été envoyé.)")
        return

    call("PATCH", f"appStoreVersions/{vid}/relationships/build",
         {"data": {"type": "builds", "id": choisie["id"]}})
    print(f"\n  Build {choisie['number']} attachée à la version {args.version}.")

    # Une soumission de revue est un OBJET, distinct de la version : on en crée une, on y met la
    # version comme article, puis on la marque envoyée. Le compte n'en accepte qu'une ouverte à la
    # fois — si une traîne, la réutiliser plutôt que d'en créer une seconde qui échouera.
    ouverte = None
    try:
        for r in call("GET", f"reviewSubmissions?filter[app]={aid}"
                             "&filter[state]=READY_FOR_REVIEW")["data"]:
            ouverte = r["id"]
    except SystemExit:
        ouverte = None
    if ouverte:
        print("  Une soumission ouverte existait déjà — elle est réutilisée.")
    else:
        ouverte = call("POST", "reviewSubmissions", {"data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]["id"]

    # `include` est indispensable : sans lui, la relation `appStoreVersion` d'un article ne porte
    # qu'un lien, sans identifiant — la comparaison serait toujours fausse, et l'article ajouté
    # une deuxième fois.
    deja = [i for i in call("GET", f"reviewSubmissions/{ouverte}/items?include=appStoreVersion")["data"]
            if (i.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id") == vid]
    if deja:
        print(f"  La version {args.version} est déjà dans la soumission.")
    else:
        call("POST", "reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": ouverte}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        print(f"  Version {args.version} ajoutée à la soumission.")

    r = call("PATCH", f"reviewSubmissions/{ouverte}",
             {"data": {"type": "reviewSubmissions", "id": ouverte, "attributes": {"submitted": True}}})
    print(f"\n  Envoyée en revue — état de la soumission : {r['data']['attributes']['state']}")


# ── Codes promo ───────────────────────────────────────────────────────────────────────────────
#
# UN CODE PROMO D'ABONNEMENT EST UN OBJET D'APP STORE CONNECT, pas une chaîne que l'app
# comparerait. Apple le vérifie, l'app ne le voit jamais, et il ne peut donc pas être contourné
# en bidouillant le téléphone. Ce qui suit crée ces objets ; l'app, elle, n'ouvre que la feuille.
#
# DEUX FORMES, ET ELLES NE SE RESSEMBLENT PAS :
#
#   · un CODE PERSONNALISÉ — une seule chaîne, « RUNUPTEAM », qu'on distribue à qui l'on veut,
#     utilisable N fois jusqu'à une date. C'est ce qu'on veut ici : un code à envoyer par message.
#   · des codes À USAGE UNIQUE — un lot de chaînes tirées au hasard, à télécharger en CSV.
#     Utile pour une campagne, inutile pour une poignée de testeurs.
#
# CE QU'APPLE NE SAIT PAS FAIRE, ET C'EST IMPORTANT : « -50 % » n'existe pas. Une offre est
# gratuite, ou fixée à un PALIER DE PRIX choisi, pour un nombre de périodes donné — après quoi
# l'abonnement reprend son tarif plein. Le « 50 % » est donc le palier le plus proche de la
# moitié du prix, calculé territoire par territoire, et il dure ce qu'on lui dit de durer.

ANNUEL = "com.hicsuntco.runup.plus.yearly"
MENSUEL = "com.hicsuntco.runup.plus.monthly"

OFFRES_PROMO = [
    # LES TESTEURS : un an offert, sur l'annuel seulement. Un testeur n'a aucune formule à
    # choisir, et deux codes pour la même chose est une source d'erreur au moment de les envoyer.
    # Une testeuse peut avoir déjà été abonnée, ou l'être encore : lui refuser le code pour ça
    # n'aurait aucun sens, d'où les trois éligibilités.
    {"produit": ANNUEL, "nom": "Testeurs RUNUP", "code": "RUNUPTEAM",
     "mode": "FREE_TRIAL", "duree": "ONE_YEAR", "periodes": 1, "remise": 1.0,
     # Mille, et non deux cents : Apple refuse les petits nombres pour un code personnalisé
     # (« Invalid number of codes »). C'est un PLAFOND d'utilisations, pas une quantité à
     # distribuer — le code reste unique, et personne ne le reçoit qu'on ne lui ait envoyé.
     "eligibilites": ["NEW", "EXPIRED", "EXISTING"], "codes": 1000},
    # LES NOUVELLES : la première année à moitié prix, puis le tarif plein. Un code appartient à
    # UNE offre, donc à UN produit — celui qui suit existe pour qui préfère payer au mois, sans
    # quoi la feuille d'Apple lui répondrait « non éligible » sans expliquer pourquoi.
    {"produit": ANNUEL, "nom": "Bienvenue moitié prix (annuel)", "code": "RUNUP50",
     "mode": "PAY_AS_YOU_GO", "duree": "ONE_YEAR", "periodes": 1,
     "eligibilites": ["NEW"], "codes": 10000, "remise": 0.5},
    {"produit": MENSUEL, "nom": "Bienvenue moitié prix (mensuel)", "code": "RUNUP50M",
     "mode": "PAY_AS_YOU_GO", "duree": "ONE_MONTH", "periodes": 3,
     "eligibilites": ["NEW"], "codes": 10000, "remise": 0.5},
]


def abonnements(aid):
    """Les abonnements de l'app, avec leur groupe."""
    out = []
    for g in call("GET", f"apps/{aid}/subscriptionGroups?limit=20")["data"]:
        for s in call("GET", f"subscriptionGroups/{g['id']}/subscriptions?limit=50")["data"]:
            out.append((g["attributes"].get("referenceName"), s))
    return out


def cmd_promo(args):
    aid, _ = app_id()
    trouves = abonnements(aid)
    if not trouves:
        sys.exit("Aucun abonnement sur cette app. Les codes promo ne s'appliquent qu'à un "
                 "abonnement, et il n'y en a pas encore.")

    for groupe, abo in trouves:
        a = abo["attributes"]
        print(f"\n  {a.get('productId')}  « {a.get('name')} »  — {a.get('state')}   [groupe {groupe}]")

        prix = call("GET", f"subscriptions/{abo['id']}/prices"
                           "?include=subscriptionPricePoint,territory&limit=200")
        points = {i["id"]: i["attributes"] for i in prix.get("included", [])
                  if i["type"] == "subscriptionPricePoints"}
        territoires = {i["id"]: i["id"] for i in prix.get("included", []) if i["type"] == "territories"}
        print(f"    {len(prix['data'])} prix sur {len(territoires)} territoires")
        for p in prix["data"]:
            rel = p.get("relationships", {})
            terr = (rel.get("territory", {}).get("data") or {}).get("id")
            pt = points.get((rel.get("subscriptionPricePoint", {}).get("data") or {}).get("id"), {})
            if terr in ("FRA", "USA", "ESP"):
                print(f"      {terr} : {pt.get('customerPrice')}")

        codes = call("GET", f"subscriptions/{abo['id']}/offerCodes?limit=50")["data"]
        if not codes:
            print("    aucun code promo")
        for c in codes:
            ca = c["attributes"]
            print(f"    offre « {ca.get('name')} » — {ca.get('offerMode')} "
                  f"{ca.get('numberOfPeriods')}×{ca.get('duration')}, "
                  f"{'active' if ca.get('active') else 'INACTIVE'}, "
                  f"éligibilité {','.join(ca.get('customerEligibilities') or [])}")
            for cc in call("GET", f"subscriptionOfferCodes/{c['id']}/customCodes?limit=20")["data"]:
                cca = cc["attributes"]
                print(f"      code « {cca.get('customCode')} » — {cca.get('numberOfCodes')} "
                      f"utilisations, expire le {(cca.get('expirationDate') or '?')[:10]}, "
                      f"{'actif' if cca.get('active') else 'INACTIF'}")
                # LE LIEN, PARCE QUE C'EST LUI QU'ON ENVOIE. Taper un code à la main dans l'App
                # Store demande de trouver « Utiliser un code cadeau » au fond d'un menu de
                # compte ; ce lien ouvre directement l'écran, code prérempli. Il fonctionne sans
                # aucune mise à jour de l'app — un code promo est un objet du compte, pas du
                # binaire.
                print(f"        https://apps.apple.com/redeem?ctx=offercodes&id={aid}"
                      f"&code={cca.get('customCode')}")
    print()


def points_de_prix(sub_id: str, territoires: list) -> dict:
    """Tous les paliers de prix disponibles, par territoire.

    Demandés par paquets : le filtre accepte plusieurs territoires, et une requête par pays en
    ferait cent soixante-quinze. `include=territory` est indispensable — sans lui, les paliers
    reviennent en vrac, sans moyen de savoir lequel appartient à quel pays.
    """
    out = {t: [] for t in territoires}
    for i in range(0, len(territoires), 25):
        paquet = ",".join(territoires[i:i + 25])
        url = (f"subscriptions/{sub_id}/pricePoints?filter[territory]={paquet}"
               f"&include=territory&limit=8000")
        while url:
            page = call("GET", url)
            for p in page["data"]:
                terr = (p.get("relationships", {}).get("territory", {}).get("data") or {}).get("id")
                brut = p["attributes"].get("customerPrice")
                if terr in out and brut is not None:
                    out[terr].append((float(brut), p["id"]))
            url = page.get("links", {}).get("next")
    return out


def prix_actuels(sub_id: str) -> dict:
    """Le prix en vigueur dans chaque territoire — la base sur laquelle la remise se calcule."""
    # `territory` DANS L'INCLUDE, et pas seulement `subscriptionPricePoint` : sans lui la relation
    # ne porte qu'un lien, sans identifiant, et chaque prix revient sans pays. Le calcul rendait
    # alors « 0 territoires tarifés » — pas une erreur, un silence.
    page = call("GET", f"subscriptions/{sub_id}/prices"
                       f"?include=subscriptionPricePoint,territory&limit=200")
    points = {i["id"]: i["attributes"] for i in page.get("included", [])
              if i["type"] == "subscriptionPricePoints"}
    out = {}
    for p in page["data"]:
        rel = p.get("relationships", {})
        terr = (rel.get("territory", {}).get("data") or {}).get("id")
        pt = points.get((rel.get("subscriptionPricePoint", {}).get("data") or {}).get("id"), {})
        if terr and pt.get("customerPrice") is not None:
            out[terr] = float(pt["customerPrice"])
    return out


def palier_le_plus_proche(paliers: list, cible: float):
    """Le palier le plus proche de la cible, et à égalité le moins cher. Rend (prix, identifiant).

    « Moitié prix » n'existe pas chez Apple : une offre est gratuite, ou fixée à un PALIER, et les
    paliers sont une grille imposée — 19,99 €, 21,99 €, jamais 19,995. La moitié d'un prix tombe
    donc presque toujours à côté, et il faut choisir. À égalité on descend : une remise annoncée à
    moitié prix doit être au moins la moitié, jamais un centime au-dessus.
    """
    return min(paliers, key=lambda p: (abs(p[0] - cible), p[0]))


def tarifs_de_remise(sub_id: str, remise: float, gratuite: bool = False):
    """La grille de l'offre : un palier par territoire. Rend (inclus, références, retenus).

    UNE OFFRE GRATUITE EST UN CAS À PART, et les deux refus d'Apple se contredisaient en
    apparence : la liste des prix est OBLIGATOIRE, mais chaque entrée doit avoir un palier NUL.
    Les deux tiennent ensemble dès qu'on voit à quoi sert cette liste — elle déclare les
    territoires où l'offre existe, pas ce qu'on y paie. Pour une offre gratuite il n'y a
    justement rien à payer, donc pas de palier, et pas non plus de grille à aller chercher.
    """
    base = prix_actuels(sub_id)
    grille = {} if gratuite else points_de_prix(sub_id, sorted(base))
    inclus, refs, retenus = [], [], {}
    for terr, prix in sorted(base.items()):
        if gratuite:
            montant, pid = 0.0, None
        else:
            paliers = grille.get(terr) or []
            if not paliers:
                print(f"    {terr} : aucun palier disponible, territoire ignoré.")
                continue
            montant, pid = palier_le_plus_proche(paliers, prix * remise)
        retenus[terr] = (prix, montant)
        # Les accolades font partie de l'identifiant, ce n'est pas une interpolation oubliée :
        # Apple distingue par cette syntaxe une référence LOCALE — un objet créé dans la même
        # requête — d'un identifiant d'objet existant. « prix-FRA » tout court est refusé.
        ref = f"${{prix-{terr}}}"
        refs.append({"type": "subscriptionOfferCodePrices", "id": ref})
        # ABSENTE PLUTÔT QUE NULLE. Apple répond « subscriptionPricePoint must be null » pour une
        # offre gratuite ; envoyer littéralement `{"data": null}` lui fait rendre un 500, deux
        # fois de suite. La relation est donc simplement omise — ce que JSON:API traite comme la
        # même chose, et ce que leur serveur, lui, sait lire.
        relations = {"territory": {"data": {"type": "territories", "id": terr}}}
        if pid is not None:
            relations["subscriptionPricePoint"] = {
                "data": {"type": "subscriptionPricePoints", "id": pid}}
        inclus.append({"type": "subscriptionOfferCodePrices", "id": ref,
                       "relationships": relations})
    return inclus, refs, retenus


def cmd_promo_creer(args):
    aid, _ = app_id()
    par_produit = {a["attributes"].get("productId"): a for _, a in abonnements(aid)}

    for offre in OFFRES_PROMO:
        abo = par_produit.get(offre["produit"])
        if abo is None:
            print(f"  {offre['produit']} : abonnement introuvable, offre « {offre['nom']} » sautée.")
            continue
        print(f"\n  {offre['produit']} — offre « {offre['nom']} », code {offre['code']}")

        existantes = {c["attributes"].get("name"): c["id"]
                      for c in call("GET", f"subscriptions/{abo['id']}/offerCodes?limit=50")["data"]}
        oid = existantes.get(offre["nom"])
        if oid:
            print("    l'offre existe déjà — rien à créer.")
        else:
            corps = {"data": {
                "type": "subscriptionOfferCodes",
                "attributes": {
                    "name": offre["nom"],
                    "customerEligibilities": offre["eligibilites"],
                    "offerMode": offre["mode"],
                    "duration": offre["duree"],
                    "numberOfPeriods": offre["periodes"],
                    # CE QUI ARRIVE À L'ESSAI DE SEPT JOURS. L'app en offre un à tout nouvel
                    # abonné ; un code promo croise donc forcément cette offre-là. « Empiler »
                    # donnerait sept jours gratuits PUIS la remise — la personne à qui l'on a
                    # promis la moitié du prix paierait zéro d'abord, et le décompte de son
                    # année à moitié prix commencerait une semaine plus tard. « Remplacer »
                    # donne exactement ce qui est annoncé, tout de suite.
                    "offerEligibility": "REPLACE_INTRO_OFFERS",
                },
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": abo["id"]}}}}}

            # UNE LISTE DE PRIX EST EXIGÉE MÊME POUR UNE OFFRE GRATUITE — Apple refuse la
            # création sans elle, tout en refusant qu'elle porte un palier. Les deux tiennent
            # ensemble : cette liste déclare les TERRITOIRES où l'offre existe, pas ce qu'on y
            # paie. Une offre gratuite y met donc ses pays, et rien d'autre.
            #
            # Une offre à prix réduit exige un palier DANS CHAQUE TERRITOIRE où l'abonnement est
            # vendu — cent soixante-quinze ici. Et la moitié du prix français convertie ne serait
            # pas la bonne réponse au Japon : chaque pays a sa propre grille imposée, et c'est sur
            # SON prix local que la remise se calcule.
            inclus, refs, retenus = tarifs_de_remise(
                abo["id"], offre["remise"], gratuite=offre["mode"] == "FREE_TRIAL")
            corps["data"]["relationships"]["prices"] = {"data": refs}
            corps["included"] = inclus
            for terr in ("FRA", "USA", "ESP", "JPN"):
                if terr in retenus:
                    fleche = "offert" if offre["mode"] == "FREE_TRIAL" else str(retenus[terr][1])
                    print(f"    {terr} : {retenus[terr][0]} → {fleche}")
            print(f"    {len(refs)} territoires tarifés")

            if args.dry_run:
                print("    (--dry-run : l'offre n'est pas créée, donc pas de code non plus)")
                continue
            oid = call("POST", "subscriptionOfferCodes", corps)["data"]["id"]
            print("    offre créée.")

        if args.dry_run:
            print("    (--dry-run : le code n'est pas créé)")
            continue

        deja = {c["attributes"].get("customCode")
                for c in call("GET", f"subscriptionOfferCodes/{oid}/customCodes?limit=50")["data"]}
        if offre["code"] in deja:
            print(f"    le code {offre['code']} existe déjà.")
            continue
        expire = (datetime.date.today() + datetime.timedelta(days=365)).isoformat()
        call("POST", "subscriptionOfferCodeCustomCodes", {"data": {
            "type": "subscriptionOfferCodeCustomCodes",
            "attributes": {"customCode": offre["code"], "numberOfCodes": offre["codes"],
                           "expirationDate": expire},
            "relationships": {"offerCode": {"data": {"type": "subscriptionOfferCodes", "id": oid}}}}})
        print(f"    code {offre['code']} créé — {offre['codes']} utilisations, expire le {expire}.")
    print()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status").set_defaults(func=cmd_status)
    sub.add_parser("ci").set_defaults(func=cmd_ci)
    c = sub.add_parser("create-version"); c.add_argument("version"); c.set_defaults(func=cmd_create_version)
    m = sub.add_parser("push-metadata"); m.add_argument("version")
    m.add_argument("--dry-run", action="store_true"); m.set_defaults(func=cmd_push_metadata)
    s = sub.add_parser("submit"); s.add_argument("version")
    s.add_argument("--build", type=int, default=None,
                   help="numéro de build à attacher (par défaut : la plus récente VALID)")
    s.add_argument("--force", action="store_true", help="envoyer même sans captures")
    s.add_argument("--replace", action="store_true",
                   help="retirer la version de la file de revue pour lui changer sa build")
    s.add_argument("--dry-run", action="store_true"); s.set_defaults(func=cmd_submit)
    g = sub.add_parser("promo"); g.set_defaults(func=cmd_promo)
    gc = sub.add_parser("promo-create")
    gc.add_argument("--dry-run", action="store_true"); gc.set_defaults(func=cmd_promo_creer)
    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
