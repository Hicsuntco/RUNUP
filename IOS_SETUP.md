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

## Backend (comptes, clubs, activités)

Le Club (classement, fil d'activité, kudos) est maintenant un vrai backend multi-utilisateurs —
plus des données simulées. Il vit dans le **même projet Vercel** que le proxy coach ci-dessus
(mêmes `api/`), mais a besoin de sa propre base de données et de ses propres identifiants
d'authentification. Rien de ceci n'est fait automatiquement — voici les étapes, une fois.

### 1. Base de données (Neon Postgres, via l'intégration Vercel)

1. Dans le projet Vercel → onglet **Storage** → **Create Database** → choisis **Neon** (Postgres
   serverless, gratuit pour démarrer) → connecte-la au projet.
2. Vercel ajoute automatiquement une variable d'environnement `DATABASE_URL` (parfois nommée
   `POSTGRES_URL` selon l'intégration — `lib/db.js` accepte les deux) au projet. Rien à faire de
   plus ici.
3. Ouvre l'onglet **SQL Editor** de Neon (accessible depuis le dashboard Neon, lié depuis l'onglet
   Storage de Vercel) et colle-y tout le contenu de **`db/schema.sql`** (à la racine de ce repo),
   puis exécute-le. Ça crée les tables `users`, `clubs`, `club_members`, `activities`,
   `activity_kudos`. À refaire seulement si `db/schema.sql` change plus tard.

### 2. Variables d'environnement Vercel

Dans les réglages du projet Vercel → **Environment Variables**, ajoute (en plus de
`ANTHROPIC_API_KEY`/`RUNUP_APP_SECRET` déjà configurées pour le coach) :

- `RUNUP_SESSION_SECRET` — une chaîne aléatoire longue (ex. `openssl rand -hex 32` dans un
  terminal) : sert à signer les sessions des utilisatrices connectées. À garder secrète, comme
  `ANTHROPIC_API_KEY`.
- `APPLE_BUNDLE_ID` — `com.hicsuntco.runup` (vérifie qu'il correspond bien à
  `PRODUCT_BUNDLE_IDENTIFIER` dans `project.yml`).
- `GOOGLE_CLIENT_ID` — le Client ID créé à l'étape 4 ci-dessous.

### 3. Sign in with Apple

L'entitlement est déjà dans `project.yml` (`com.apple.developer.applesignin`). Avec la signature
automatique (`CODE_SIGN_STYLE: Automatic`, déjà configuré), Xcode devrait activer la capability
"Sign In with Apple" tout seul au premier build sur un appareil/simulateur connecté à ton compte
développeur. Si Xcode affiche une erreur de provisioning à ce sujet : Signing & Capabilities →
vérifie que "Sign In with Apple" apparaît dans la liste des capabilities de la cible RunUp (elle
devrait y être automatiquement, générée depuis `project.yml`) et relance le build.

### 4. Google Sign-In

1. Va sur [console.cloud.google.com](https://console.cloud.google.com) → crée un projet (ou
   réutilise un projet existant) → **APIs & Services** → **Credentials** → **Create Credentials**
   → **OAuth client ID** → type **iOS**.
2. Bundle ID : `com.hicsuntco.runup`.
3. Une fois créé, Google te donne un **Client ID** (ressemble à
   `123456-abc.apps.googleusercontent.com`) et son équivalent "reversed" (le même ID avec les
   segments inversés, ex. `com.googleusercontent.apps.123456-abc`).
4. Dans `project.yml`, remplace les deux placeholders :
   - `GIDClientID: "REPLACE_ME.apps.googleusercontent.com"` → ton Client ID tel quel.
   - `CFBundleURLSchemes: ["REPLACE_ME_REVERSED_CLIENT_ID"]` → la version reversed.
5. Ajoute aussi ce Client ID comme variable d'environnement Vercel `GOOGLE_CLIENT_ID` (étape 2) —
   c'est ce qui permet à `api/auth/google.js` de vérifier que le token vient bien de cette app.
6. `xcodegen generate` pour que Xcode récupère le package SPM `GoogleSignIn-iOS` (déjà déclaré
   dans `project.yml` sous `packages:`) et les nouveaux réglages Info.plist.

### 5. Déployer et tester

1. Pousse ces changements sur la branche connectée à Vercel — le projet redéploie automatiquement
   et prend en compte le nouveau dossier `api/` (comptes, clubs, activités) et `package.json`
   (nouvelles dépendances : `@neondatabase/serverless`, `bcryptjs`, `jose`).
2. Dans l'app : onglet **Le Club** → "Se connecter" → teste les 3 méthodes (Apple, Google,
   email/mot de passe) → crée un club → termine une course → vérifie qu'elle apparaît dans le fil
   d'activité et que ton XP bouge dans le classement.
3. Pour supprimer un compte de test : Profil → Compte → "Supprimer mon compte" (supprime aussi
   ses données Club côté serveur, requis par les règles App Store sur la suppression de compte).

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
