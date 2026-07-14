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

## Coach backend (proxy Vercel)

Le coach n'appelle jamais l'API Anthropic directement depuis l'app — aucune utilisatrice n'a de
clé à fournir. L'app appelle `api/coach.js` (une fonction serverless Vercel, à la racine de ce
repo), qui détient la vraie clé Anthropic côté serveur et la relaie. `Services/CoachService.swift`
est le seul point d'appel réseau côté app.

**Déploiement (une fois) :**
1. Importe ce repo dans Vercel (vercel.com → Add New → Project → sélectionne ce repo). Vercel
   détecte automatiquement le dossier `api/` et déploie `api/coach.js` comme fonction serverless.
2. Dans les réglages du projet Vercel → **Environment Variables**, ajoute :
   - `ANTHROPIC_API_KEY` — une vraie clé API Anthropic (console.anthropic.com), avec un plafond de
     dépense configuré côté Anthropic — c'est le vrai garde-fou contre une facture qui explose,
     pas la fonction elle-même.
   - `RUNUP_APP_SECRET` — doit être identique à la constante `appSecret` dans
     `RunUp/Services/CoachService.swift` (secret partagé app↔serveur, pas un identifiant
     utilisateur — juste un frein contre un appel externe au hasard sur cette URL).
3. Redéploie, puis vérifie que `RunUp/Services/CoachService.swift`'s `endpoint` pointe bien vers
   l'URL Vercel réelle du projet (`https://<projet>.vercel.app/api/coach`).

`api/coach.js` force son propre `model`/`max_tokens` côté serveur (ignore ce que le client envoie)
et ne journalise jamais le contenu des messages — seule protection de contenu réellement fiable
contre un client modifié ; la protection anti-abus/coût reste principalement le plafond de
dépense Anthropic ci-dessus, pas une limite de débit applicative (aucune n'est implémentée en v1).

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
