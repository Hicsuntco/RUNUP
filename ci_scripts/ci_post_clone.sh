#!/bin/sh
# Xcode Cloud exécute ce script automatiquement après avoir cloné le dépôt, avant de résoudre les
# dépendances et de construire.
#
# Tout ce qu'il fait de substantiel vit dans `prepare_project.sh`, partagé avec le workflow GitHub
# Actions : ce fichier ne s'occupe que de ce qui est propre à Xcode Cloud — installer XcodeGen,
# se placer dans le dépôt cloné, et traduire les variables maison d'Apple en variables communes.
#
# `RUNUP_APP_SECRET` doit être déclaré en variable d'environnement du workflow Xcode Cloud, cochée
# « Secret » (App Store Connect → Xcode Cloud → ton workflow → Environment → Environment
# Variables), avec exactement la valeur de `RUNUP_APP_SECRET` côté Vercel — sinon le serveur
# rejette l'app et le coach répond 401 dans chaque build.

set -e

echo "→ Installation de XcodeGen"
brew install xcodegen

# Xcode Cloud place le dépôt cloné dans $CI_PRIMARY_REPOSITORY_PATH ; le repli couvre une
# exécution locale du script pour le tester.
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/..}"

# `CI_BUILD_NUMBER` s'incrémente à chaque exécution du workflow Xcode Cloud. C'est le seul nom
# qu'Apple donne à cette valeur ; `prepare_project.sh`, lui, ne connaît que `BUILD_NUMBER`.
export BUILD_NUMBER="$CI_BUILD_NUMBER"

sh ci_scripts/prepare_project.sh
