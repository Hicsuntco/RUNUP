# Générer et lancer le projet Xcode

Ce repo ne contient **pas** de `.xcodeproj` commité — il est généré depuis `project.yml` avec
[XcodeGen](https://github.com/yonaskolb/XcodeGen). C'est un choix délibéré : cette session tourne
sur un conteneur Linux sans Xcode/Swift, donc impossible de compiler ou de valider un
`.xcodeproj` écrit à la main ici — XcodeGen élimine ce risque (fichier déclaratif, lisible,
généré de façon fiable par un seul outil sur ta machine).

## Prérequis

- macOS avec Xcode 15+ installé
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) : `brew install xcodegen`

## Générer le projet

```bash
cd RunUp   # ou la racine du repo, là où se trouve project.yml
xcodegen generate
open RunUp.xcodeproj
```

Relance `xcodegen generate` à chaque fois que `project.yml` change (nouveau fichier source,
nouvelle capability, etc.) — les fichiers `.swift` eux n'ont pas besoin d'être ajoutés
manuellement au projet, `project.yml` référence le dossier `RunUp/` entier.

## Configurer la clé API Anthropic (coach IA)

Le coach IA appelle directement l'API Anthropic (`https://api.anthropic.com/v1/messages`) depuis
l'app, avec une clé saisie par l'utilisateur dans **Profil → Réglages → Coach IA**, stockée dans
le Keychain iOS (`Services/KeychainService.swift`).

**Pourquoi ce choix pour la v1** (voir aussi le README principal) : c'est la solution la plus
simple à shipper sans backend. Elle convient pour du développement, du test, ou une diffusion
limitée où chaque utilisatrice fournit sa propre clé.

**Avant une diffusion App Store grand public**, il vaut mieux ne pas demander à chaque
utilisatrice sa propre clé API. Deux alternatives, sans avoir à toucher aux écrans :
`Services/CoachService.swift` est le seul point d'appel réseau du coach — remplacer son
implémentation suffit.
1. **Proxy backend** (recommandé) — une fonction serverless (ex. Supabase Edge Function,
   Cloudflare Worker) qui détient la clé Anthropic côté serveur et que l'app appelle à la place
   de l'API Anthropic directement. Permet aussi de limiter l'usage par utilisateur/palier
   d'abonnement.
2. **Clé embarquée via configuration de build** (xcconfig non commité) — plus simple, mais la
   clé reste extractible du binaire distribué ; à réserver à des builds internes/TestFlight.

## HealthKit (Apple Santé)

Le simulateur iOS ne fournit pas de vraies données Santé — pour tester la lecture/écriture
HealthKit (forme du jour, enregistrement des courses), utilise un appareil physique avec
l'app Santé configurée, et accepte les autorisations demandées à l'étape "Connexions santé" de
l'onboarding ou depuis Profil → Réglages.

## Suivi GPS en direct

L'écran "Course en direct" utilise MapKit + CoreLocation avec la position réelle de l'appareil.
Sur simulateur, utilise **Debug → Location → Freeway Drive** (ou un GPX personnalisé) dans
Xcode/Simulator pour simuler un déplacement et voir le tracé se dessiner.

## Polices

Les fichiers `.ttf` (Bebas Neue, DM Sans, DM Mono — Google Fonts, licence OFL) sont déjà présents
dans `RunUp/Resources/Fonts/` et déclarés dans `project.yml` (`UIAppFonts`) — rien à faire de
plus, XcodeGen les enregistre automatiquement.

## Icône de l'app

`RunUp/Resources/Assets.xcassets/AppIcon.appiconset/` contient un slot d'icône App Store
(1024×1024, format "single size" iOS 17+) sans image — à remplir dans Xcode avant tout envoi sur
TestFlight/App Store. Le logo décrit dans le handoff design (voir
`design_handoff_runup_app/README.md` § Assets, fonction `AppMark`) est un bon point de départ :
c'est le même glyphe que `Views/Components/AppMarkView.swift`, à exporter en PNG haute résolution.
