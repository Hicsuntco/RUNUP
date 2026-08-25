#!/bin/sh
# Prépare le dépôt pour une construction automatisée, quelle que soit la machine qui la lance :
# Xcode Cloud (via `ci_post_clone.sh`), GitHub Actions (via `.github/workflows/testflight.yml`),
# ou ta machine si tu veux reproduire exactement ce que fait la CI.
#
# Ce fichier existe pour qu'il n'y ait qu'UN seul endroit où ces trois gestes sont écrits. Ils
# étaient auparavant dans `ci_post_clone.sh` ; les recopier dans le workflow GitHub aurait garanti
# qu'un jour les deux chaînes ne produisent plus le même binaire — et c'est précisément le genre
# de divergence qu'on ne remarque qu'après avoir envoyé la mauvaise version aux testeurs.
#
# Deux variables d'environnement, toutes deux facultatives :
#   RUNUP_APP_SECRET — le secret partagé avec `api/coach.js`. Absent, l'app compile mais le coach
#                      répondra 401 (voir plus bas).
#   BUILD_NUMBER     — le numéro de build à imposer aux trois cibles. Absent, `project.yml` garde
#                      celui qui y est écrit.

set -e

# Racine du dépôt, quel que soit l'endroit d'où le script est appelé.
cd "$(dirname "$0")/.."

# 1. LE SECRET DU COACH N'EST PAS COMMITÉ.
#    `Secrets.xcconfig` est gitignoré (c'est voulu). Sans lui, `RUNUP_APP_SECRET` vaut la chaîne
#    vide, l'app envoie un secret vide, et le serveur répond 401 — le coach serait donc MORT dans
#    le build, alors que tout le reste fonctionnerait. Une panne silencieuse et parfaitement
#    évitable.
if [ -n "$RUNUP_APP_SECRET" ]; then
  echo "→ Écriture de Secrets.xcconfig depuis la variable d'environnement"
  # `Config.xcconfig` fait un `#include?` de ce fichier : présent, il gagne sur la valeur vide
  # par défaut ; absent, la construction se poursuit avec un secret vide.
  printf 'RUNUP_APP_SECRET = %s\n' "$RUNUP_APP_SECRET" > Secrets.xcconfig
else
  # Volontairement un avertissement et non une erreur : un build de test peut légitimement se
  # passer du coach, et faire échouer toute la construction pour ça serait disproportionné. Mais
  # le message doit être impossible à rater dans les logs, parce que le symptôme (le coach qui
  # répond 401) n'a rien d'évident quand on le découvre dans TestFlight.
  echo "⚠️  RUNUP_APP_SECRET absent — le coach répondra 401 dans ce build."
fi

# 2. LE NUMÉRO DE BUILD EST FIGÉ DANS LE DÉPÔT.
#    `project.yml` porte `CFBundleVersion` en dur, à trois endroits (app, widget, montre), et rien
#    ne l'incrémente. App Store Connect refuse un couple (version, build) déjà reçu : le deuxième
#    envoi échouerait, et il faudrait éditer trois lignes à la main avant chacun — avec le risque
#    qu'elles divergent, ce qu'Apple refuse aussi (les trois cibles doivent porter le même couple).
#
#    On substitue AVANT la génération, donc les trois cibles reçoivent le numéro d'un seul coup et
#    restent forcément d'accord. En local, la variable est absente et le fichier n'est pas touché.
if [ -n "$BUILD_NUMBER" ]; then
  echo "→ Numéro de build imposé : $BUILD_NUMBER"
  tmp=$(mktemp)
  sed "s/CFBundleVersion: \"[0-9][0-9]*\"/CFBundleVersion: \"$BUILD_NUMBER\"/g" project.yml > "$tmp"
  mv "$tmp" project.yml
  aligned=$(grep -c "CFBundleVersion: \"$BUILD_NUMBER\"" project.yml)
  echo "  ($aligned cibles alignées)"
  # Trois cibles portent un CFBundleVersion : l'app, le widget, la montre. Si la substitution n'en
  # touche pas trois, le format de `project.yml` a changé sous ce `sed` — et laisser passer un
  # build où les cibles ne s'accordent pas ne mène qu'à un rejet d'App Store Connect quinze
  # minutes plus tard, après avoir payé toute la construction.
  if [ "$aligned" -ne 3 ]; then
    echo "✗ Attendu 3 cibles, trouvé $aligned. Vérifie le format de CFBundleVersion dans project.yml."
    exit 1
  fi
fi

# 3. IL N'Y A PAS DE .xcodeproj DANS LE DÉPÔT.
#    `.gitignore` contient `*.xcodeproj/` : le projet est généré par XcodeGen à partir de
#    `project.yml`, ce qui évite des conflits de fusion permanents sur un fichier que Xcode
#    réécrit sans arrêt. Sur ta machine tu lances `xcodegen` à la main ; une machine de CI clone
#    un dépôt où le projet n'existe pas encore et n'a donc rien à construire.
echo "→ Génération de RunUp.xcodeproj"
xcodegen generate

echo "✓ Prêt à construire"
