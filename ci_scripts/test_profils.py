#!/usr/bin/env python3
"""Les décisions de `profils.py`, vérifiées sans toucher au réseau.

Ce qui est testé ici n'est pas l'API d'Apple — c'est la RÈGLE : quand faut-il refaire un profil,
et quand peut-on le garder. Une règle trop large refait trois profils à chaque build et finit par
se faire limiter par Apple ; une règle trop étroite laisse passer un profil périmé, et la panne
revient douze minutes plus tard à l'export.
"""
import base64, datetime, pathlib, plistlib, sys, tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import profils


def enveloppe(donnees: dict) -> str:
    """Un .mobileprovision de test : un plist XML noyé dans du binaire, comme une enveloppe CMS."""
    plist = plistlib.dumps(donnees, fmt=plistlib.FMT_XML)
    return base64.b64encode(b"\x30\x82\x0d\xea" + b"\x00" * 40 + plist + b"\x00" * 60).decode()


def main() -> int:
    echecs = []

    def verifier(nom, condition, detail=""):
        print(("  ✓ " if condition else "  ✗ ") + nom + (f" — {detail}" if not condition else ""))
        if not condition:
            echecs.append(nom)

    # ── Le plist se lit à travers l'enveloppe, sans `security cms` (absent hors macOS) ──
    contenu = enveloppe({"UUID": "ABCD-1234", "Name": "RunUp CI app",
                         "Entitlements": {"com.apple.developer.weatherkit": True,
                                          "application-identifier": "TEAM.com.hicsuntco.runup"}})
    verifier("les entitlements se lisent à travers l'enveloppe",
             profils.entitlements_du_profil(contenu).get("com.apple.developer.weatherkit") is True)
    verifier("l'UUID se lit à travers l'enveloppe",
             profils.plist_du_profil(contenu).get("UUID") == "ABCD-1234")

    # ── La décision de refaire ──
    dossier = pathlib.Path(tempfile.mkdtemp())
    demande = dossier / "cible.entitlements"
    demande.write_bytes(plistlib.dumps({
        "com.apple.developer.weatherkit": True,
        "com.apple.security.application-groups": ["group.com.hicsuntco.runup"],
        # Posé par Xcode à la signature : ne doit PAS être réclamé au profil.
        "get-task-allow": False,
    }))

    maintenant = datetime.datetime.now(datetime.timezone.utc)
    loin = (maintenant + datetime.timedelta(days=200)).isoformat()
    proche = (maintenant + datetime.timedelta(days=3)).isoformat()
    incomplet = contenu
    complet = enveloppe({"UUID": "U", "Entitlements": {
        "com.apple.developer.weatherkit": True,
        "com.apple.security.application-groups": ["group.com.hicsuntco.runup"]}})

    def profil(etat="ACTIVE", exp=loin, cont=complet, typ="IOS_APP_STORE"):
        return {"id": "x", "attributes": {"profileState": etat, "expirationDate": exp,
                                          "profileContent": cont, "profileType": typ}}

    for attendu, p in [
        ("il n'existe pas encore",                  None),
        ("son état est INVALID",                    profil(etat="INVALID")),
        ("il expire le",                            profil(exp=proche)),
        ("son type est IOS_APP_ADHOC",              profil(typ="IOS_APP_ADHOC")),
        ("il ne porte pas com.apple.security.application-groups", profil(cont=incomplet)),
    ]:
        obtenu = profils.pourquoi_refaire(p, demande)
        verifier(f"refait : {attendu}", attendu in obtenu, f"obtenu « {obtenu} »")

    obtenu = profils.pourquoi_refaire(profil(), demande)
    verifier("un profil complet et valide est réutilisé", obtenu == "", f"obtenu « {obtenu} »")

    # `get-task-allow` ne vient pas du portail : l'exiger du profil ferait refaire les trois
    # profils à chaque build, pour toujours, sans que ça ne répare jamais rien.
    verifier("une clé posée par Xcode n'est pas réclamée au profil",
             "get-task-allow" not in profils.check_profile.demandees(demande))

    if echecs:
        print(f"\n::error::{len(echecs)} vérification(s) en échec dans test_profils.py")
        return 1
    print("\nTout passe.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
