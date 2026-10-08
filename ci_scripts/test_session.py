#!/usr/bin/env python3
"""Vérifie `check_session.py` sur des cas écrits exprès."""
import sys
import check_session as ck

cas = []
def cas_test(nom):
    def deco(f):
        cas.append((nom, f)); return f
    return deco

CLIENT_OK = 'enum SessionRenewal {\n    static let header = "X-RunUp-Session-Renewed"\n}'
SERVEUR_OK = ("const RENEWAL_HEADER = 'X-RunUp-Session-Renewed';\n"
              "const ABSOLUTE_SESSION_DAYS = 90;\n"
              "const SESSION_LIFETIME_DAYS = 30;\n")

@cas_test("deux écritures identiques ne posent aucun problème")
def _(): assert ck.problemes(CLIENT_OK, SERVEUR_OK) == [], ck.problemes(CLIENT_OK, SERVEUR_OK)

@cas_test("un nom d'en-tête qui diverge est signalé")
def _():
    p = ck.problemes(CLIENT_OK, SERVEUR_OK.replace("X-RunUp-Session-Renewed", "X-Autre-Chose"))
    assert len(p) == 1 and "renouvellera rien" in p[0], p

@cas_test("un en-tête disparu côté client est signalé")
def _():
    p = ck.problemes("enum Autre {}", SERVEUR_OK)
    assert len(p) == 1 and "AuthService" in p[0], p

@cas_test("un en-tête disparu côté serveur est signalé")
def _():
    p = ck.problemes(CLIENT_OK, "const ABSOLUTE_SESSION_DAYS = 90;\nconst SESSION_LIFETIME_DAYS = 30;")
    assert len(p) == 1 and "auth.js" in p[0], p

@cas_test("un plafond retiré est signalé")
def _():
    p = ck.problemes(CLIENT_OK, "const RENEWAL_HEADER = 'X-RunUp-Session-Renewed';\n"
                                "const SESSION_LIFETIME_DAYS = 30;")
    assert len(p) == 1 and "infini" in p[0], p

@cas_test("un plafond plus court que la vie d'un jeton éteint la fonctionnalité")
def _():
    p = ck.problemes(CLIENT_OK, "const RENEWAL_HEADER = 'X-RunUp-Session-Renewed';\n"
                                "const ABSOLUTE_SESSION_DAYS = 20;\n"
                                "const SESSION_LIFETIME_DAYS = 30;")
    assert len(p) == 1 and "éteinte" in p[0], p

@cas_test("les vrais fichiers du dépôt sont d'accord")
def _(): assert ck.main() == 0

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
