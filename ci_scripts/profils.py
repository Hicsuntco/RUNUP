#!/usr/bin/env python3
"""Fabrique les profils de provisionnement de distribution au moment du build.

# POURQUOI CE FICHIER EXISTE

UN PROFIL EST UNE PHOTO DES CAPACITÉS PRISES LE JOUR DE SA CRÉATION. Cocher WeatherKit sur
l'identifiant d'app ne met à jour AUCUN profil déjà créé : il faut aller les refaire à la main,
les retélécharger, et remplacer trois secrets.

Ces trois photos étaient stockées dans `APPLE_PROFILE_APP`, `APPLE_PROFILE_WIDGETS` et
`APPLE_PROFILE_WATCH`. Ajouter WeatherKit les a périmées toutes les trois d'un coup, et la chaîne
est restée rouge plusieurs jours — le temps qu'un humain trouve une machine, retrouve le portail,
régénère, retélécharge, réencode en base64 et repousse les secrets. Pendant ce temps, tout le
travail déjà fait attendait derrière.

Deux fois sur ce trajet, l'opération a produit un secret VIDE sans que rien ne le signale :
`gh secret set` accepte une entrée vide sans broncher.

Ici, les profils ne sont plus stockés : ils sont DEMANDÉS à Apple à chaque build, par la même clé
d'API qui sert déjà à envoyer la version. Un profil fabriqué il y a trente secondes porte
forcément les capacités d'il y a trente secondes. La panne n'a plus d'endroit où se produire, et
il n'y a plus de secret à tenir à jour.

# CE QUE ÇA NE RÉPARE PAS

Si la capacité n'est pas cochée sur l'IDENTIFIANT D'APP, aucun profil au monde ne la portera.
C'est le seul cas qui demande encore un humain, et le message le dit alors sans ambiguïté — au
lieu du « doesn't include the com.apple.developer.weatherkit entitlement » d'Apple, qui arrive
douze minutes plus tard et ne distingue pas les deux causes.

# CE QUE ÇA DEMANDE À LA CLÉ

Le rôle **Admin**. Une clé « App Manager » n'a pas accès à l'API Certificates, Identifiers &
Profiles : elle rendra 403 ici. Le rôle d'une clé est figé à sa création (voir l'en-tête de
`.github/workflows/testflight.yml`).
"""
import base64, datetime, os, pathlib, plistlib, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import asc
import check_profile

ROOT = pathlib.Path(__file__).resolve().parent.parent

# (créneau, bundle ID, entitlements de la cible, nom du profil chez Apple)
#
# Le nom est préfixé « RunUp CI » pour que ce script ne touche JAMAIS aux profils créés à la main
# dans le portail : il ne lit, ne supprime et ne refait que les siens.
CIBLES = [
    ("APP",     "com.hicsuntco.runup",
     "RunUp/RunUp.entitlements",               "RunUp CI app"),
    ("WIDGETS", "com.hicsuntco.runup.widgets",
     "RunUpWidgets/RunUpWidgets.entitlements", "RunUp CI widgets"),
    ("WATCH",   "com.hicsuntco.runup.watchkitapp",
     "RunUpWatch/RunUpWatch.entitlements",     "RunUp CI montre"),
]

TYPE_PROFIL = "IOS_APP_STORE"
# Un profil qui expire pendant la semaine qui vient est refait tout de suite : le refaire coûte
# une seconde ici, et le découvrir un vendredi soir coûte une soirée.
MARGE_EXPIRATION = datetime.timedelta(days=7)


def _date(iso: str):
    if not iso:
        return None
    return datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))


def entitlements_du_profil(contenu_b64: str) -> dict:
    """Les entitlements d'un .mobileprovision, sans passer par `security cms`.

    Un .mobileprovision est un plist XML enveloppé dans une signature CMS. `security cms -D`
    sait le désenvelopper, mais n'existe que sur macOS — or ce script doit pouvoir être essayé
    ailleurs. Le plist est en clair à l'intérieur de l'enveloppe : le délimiter suffit.
    """
    brut = base64.b64decode(contenu_b64)
    debut = brut.find(b"<?xml")
    fin = brut.find(b"</plist>")
    if debut < 0 or fin < 0:
        sys.exit("Le profil rendu par Apple ne contient pas de plist lisible.")
    return plistlib.loads(brut[debut:fin + len(b"</plist>")]).get("Entitlements", {})


def plist_du_profil(contenu_b64: str) -> dict:
    brut = base64.b64decode(contenu_b64)
    debut, fin = brut.find(b"<?xml"), brut.find(b"</plist>")
    return plistlib.loads(brut[debut:fin + len(b"</plist>")])


def certificats_de_distribution() -> list:
    """Les certificats de distribution encore valides, à inclure dans chaque profil.

    Tous, et pas seulement le premier : le profil doit contenir celui qui se trouve dans le
    trousseau de la machine, et rien ici ne permet de savoir lequel c'est. En inclure plusieurs
    ne coûte rien ; en inclure le mauvais fait échouer l'export.
    """
    maintenant = datetime.datetime.now(datetime.timezone.utc)
    gardes = []
    for c in asc.call("GET", "certificates?limit=200").get("data", []):
        a = c["attributes"]
        if a.get("certificateType") not in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
            continue
        fin = _date(a.get("expirationDate"))
        if fin and fin <= maintenant:
            continue
        gardes.append(c["id"])
    return gardes


def identifiant_du_bundle(bundle: str) -> str:
    rep = asc.call("GET", f"bundleIds?filter[identifier]={bundle}&limit=200")
    for b in rep.get("data", []):
        if b["attributes"].get("identifier") == bundle:
            return b["id"]
    sys.exit(f"::error::Aucun identifiant d'app « {bundle} » sur ce compte Apple.")


def profils_existants() -> dict:
    """Les profils de ce compte, indexés par nom."""
    return {p["attributes"]["name"]: p
            for p in asc.call("GET", "profiles?limit=200").get("data", [])}


def creer(nom: str, bundle_id: str, certs: list) -> dict:
    rep = asc.call("POST", "profiles", {
        "data": {
            "type": "profiles",
            "attributes": {"name": nom, "profileType": TYPE_PROFIL},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}},
                "certificates": {"data": [{"type": "certificates", "id": c} for c in certs]},
            },
        }
    })
    return rep["data"]


def pourquoi_refaire(profil, chemin_entitlements) -> str:
    """La raison de refaire ce profil, ou une chaîne vide s'il convient tel quel."""
    if profil is None:
        return "il n'existe pas encore"
    a = profil["attributes"]
    if a.get("profileState") != "ACTIVE":
        return f"son état est {a.get('profileState')}"
    if a.get("profileType") != TYPE_PROFIL:
        return f"son type est {a.get('profileType')}"
    fin = _date(a.get("expirationDate"))
    if fin and fin - datetime.datetime.now(datetime.timezone.utc) < MARGE_EXPIRATION:
        return f"il expire le {fin:%d/%m/%Y}"
    absentes = check_profile.manquantes(entitlements_du_profil(a["profileContent"]),
                                        chemin_entitlements)
    if absentes:
        return "il ne porte pas " + ", ".join(absentes)
    return ""


def main(argv):
    if len(argv) != 3:
        print("usage: profils.py <dossier d'installation> <fichier de correspondance>",
              file=sys.stderr)
        return 2
    dossier = pathlib.Path(argv[1]).expanduser()
    dossier.mkdir(parents=True, exist_ok=True)
    correspondance = pathlib.Path(argv[2])

    try:
        certs = certificats_de_distribution()
    except SystemExit as e:
        if "403" in str(e):
            print("::error::La clé d'API n'a pas accès aux certificats et profils. Il lui faut le "
                  "rôle Admin ; « App Manager » ne suffit pas, et le rôle d'une clé est figé à sa "
                  "création — il faut en créer une autre.", file=sys.stderr)
        raise
    if not certs:
        print("::error::Aucun certificat de distribution valide sur ce compte. Le profil ne "
              "pourrait signer personne.", file=sys.stderr)
        return 1

    existants = profils_existants()
    lignes = []
    for slot, bundle, entitlements, nom in CIBLES:
        chemin_entitlements = ROOT / entitlements
        if not chemin_entitlements.exists():
            print(f"::error::{entitlements} absent — XcodeGen doit avoir tourné avant ce script.",
                  file=sys.stderr)
            return 1

        profil = existants.get(nom)
        raison = pourquoi_refaire(profil, chemin_entitlements)
        if raison:
            if profil is not None:
                # Apple refuse deux profils de même nom : l'ancien part avant que le neuf arrive.
                asc.call("DELETE", f"profiles/{profil['id']}")
            profil = creer(nom, identifiant_du_bundle(bundle), certs)
            print(f"  ↻ {nom} — refait ({raison})")
        else:
            print(f"  ✓ {nom} — réutilisé")

        contenu = profil["attributes"]["profileContent"]

        # Un profil tout juste fabriqué qui ne porte TOUJOURS pas la capacité ne dit pas la même
        # chose qu'un profil périmé : il dit que la case n'est pas cochée sur l'identifiant d'app.
        # C'est le seul cas qui demande encore un humain, et il mérite son propre message.
        absentes = check_profile.manquantes(entitlements_du_profil(contenu), chemin_entitlements)
        if absentes:
            print(f"::error::Le profil « {nom} » vient d'être fabriqué et ne porte toujours pas : "
                  f"{', '.join(absentes)}", file=sys.stderr)
            print(f"::error::Ce n'est donc pas un profil périmé : la capacité n'est pas activée "
                  f"sur l'identifiant d'app lui-même. developer.apple.com → Certificates, "
                  f"Identifiers & Profiles → Identifiers → {bundle} → cocher la capacité → Save. "
                  f"Puis relancer : le profil se refera tout seul.", file=sys.stderr)
            return 1

        plist = plist_du_profil(contenu)
        uuid = plist["UUID"]
        (dossier / f"{uuid}.mobileprovision").write_bytes(base64.b64decode(contenu))
        lignes.append(f"{bundle}={nom}")
        capacites = check_profile.demandees(chemin_entitlements)
        print(f"      {bundle} → {uuid}  ({len(capacites)} capacité(s) : {', '.join(c.rsplit('.', 1)[-1] for c in capacites) or '—'})")

    correspondance.write_text("\n".join(lignes) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
