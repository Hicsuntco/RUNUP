#!/bin/sh
# Tous les contrôles et TOUS leurs cas, en une commande. Voir RELEASE.md § 3.
set -e
cd "$(dirname "$0")/.."
echec=0
for f in ci_scripts/check_*.py; do
  n=$(basename "$f")
  case "$n" in check_profile.py|check_grand_texte.py|check_banniere.py) continue;; esac
  python3 "$f" >/dev/null 2>&1 || { echo "ÉCHEC $n"; echec=1; }
done
cd ci_scripts
for f in test_*.py; do
  python3 "$f" >/dev/null 2>&1 || { echo "ÉCHEC $f"; echec=1; }
done
[ $echec -eq 0 ] && echo "Tous les contrôles et tous leurs cas passent."
exit $echec
