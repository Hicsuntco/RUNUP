#!/bin/sh
# Xcode Cloud exécute ce script automatiquement après avoir cloné le dépôt, avant de résoudre les
# dépendances et de construire. C'est le seul endroit où réparer deux choses qui, sans lui, font
# échouer chaque build.
#
# 1. IL N'Y A PAS DE .xcodeproj DANS LE DÉPÔT.
#    `.gitignore` contient `*.xcodeproj/` : le projet est généré par XcodeGen à partir de
#    `project.yml`, ce qui évite des conflits de fusion permanents sur un fichier que Xcode
#    réécrit sans arrêt. Sur ta machine tu lances `xcodegen` à la main ; Xcode Cloud, lui, clone
#    un dépôt où le projet n'existe pas encore et n'a donc rien à construire. D'où la génération
#    ci-dessous.
#
# 2. LE SECRET DU COACH N'EST PAS COMMITÉ.
#    `Secrets.xcconfig` est gitignoré (c'est voulu : il contient le secret partagé avec
#    `api/coach.js`). Sans lui, `RUNUP_APP_SECRET` vaut la chaîne vide, l'app envoie un secret
#    vide, et le serveur répond 401 — le coach serait donc MORT dans chaque build TestFlight et
#    App Store, alors que tout le reste fonctionnerait. Une panne silencieuse et parfaitement
#    évitable.
#
#    Il faut donc déclarer `RUNUP_APP_SECRET` comme variable d'environnement du workflow Xcode
#    Cloud, cochée « Secret » (App Store Connect → Xcode Cloud → ton workflow → Environment →
#    Environment Variables). Sa valeur doit être exactement celle de `RUNUP_APP_SECRET` côté
#    Vercel, sinon le serveur rejette l'app.

set -e

echo "→ Installation de XcodeGen"
brew install xcodegen

# Xcode Cloud place le dépôt cloné dans $CI_PRIMARY_REPOSITORY_PATH ; le repli couvre une
# exécution locale du script pour le tester.
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/..}"

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
  echo "⚠️  Ajoute-le en variable d'environnement secrète du workflow Xcode Cloud."
fi

echo "→ Génération de RunUp.xcodeproj"
xcodegen generate

echo "✓ Prêt à construire"
