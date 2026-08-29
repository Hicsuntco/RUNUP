#!/usr/bin/env python3
"""App Store Connect depuis le terminal : créer une version, y pousser la fiche.

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

Ce que le script NE fait PAS, parce que l'API ne l'expose pas ou mal : les captures d'écran, le
questionnaire de confidentialité et la classification d'âge. Ceux-là restent sur le web.
"""
import argparse, base64, hashlib, json, os, pathlib, re, subprocess, sys, tempfile, time
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
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
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
    try:
        builds = call("GET", f"builds?filter[app]={aid}&limit=5&sort=-uploadedDate")["data"]
    except SystemExit:
        builds = None
        print("  (impossible de lire les builds — le reste du statut suit)\n")
    if builds:
        print("  Dernières builds envoyées sur TestFlight :")
        for b in builds:
            a = b["attributes"]
            uploaded = (a.get("uploadedDate") or "")[:16].replace("T", " à ")
            state = a.get("processingState", "?")
            expired = " (expirée)" if a.get("expired") else ""
            print(f"    build {a.get('version', '?'):>6}   {uploaded} UTC   {state}{expired}")
        print()
    elif builds is not None:
        print("  Aucune build envoyée.\n")

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
            runs = call("GET", f"ciWorkflows/{wf['id']}/buildRuns?limit=5")["data"]
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


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status").set_defaults(func=cmd_status)
    sub.add_parser("ci").set_defaults(func=cmd_ci)
    c = sub.add_parser("create-version"); c.add_argument("version"); c.set_defaults(func=cmd_create_version)
    m = sub.add_parser("push-metadata"); m.add_argument("version")
    m.add_argument("--dry-run", action="store_true"); m.set_defaults(func=cmd_push_metadata)
    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
