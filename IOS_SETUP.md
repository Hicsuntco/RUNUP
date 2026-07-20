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

### 3. Sign in with Apple

L'entitlement est déjà dans `project.yml` (`com.apple.developer.applesignin`). Avec la signature
automatique (`CODE_SIGN_STYLE: Automatic`, déjà configuré), Xcode devrait activer la capability
"Sign In with Apple" tout seul au premier build sur un appareil/simulateur connecté à ton compte
développeur. Si Xcode affiche une erreur de provisioning à ce sujet : Signing & Capabilities →
vérifie que "Sign In with Apple" apparaît dans la liste des capabilities de la cible RunUp (elle
devrait y être automatiquement, générée depuis `project.yml`) et relance le build.

### 4. Déployer et tester

1. Pousse ces changements sur la branche connectée à Vercel — le projet redéploie automatiquement
   et prend en compte le nouveau dossier `api/` (comptes, clubs, activités) et `package.json`
   (nouvelles dépendances : `@neondatabase/serverless`, `bcryptjs`, `jose`).
2. Dans l'app : onglet **Le Club** → "Se connecter" → teste les 2 méthodes (Apple, email/mot de
   passe) → crée un club → termine une course → vérifie qu'elle apparaît dans le fil d'activité et
   que ton XP bouge dans le classement.
3. Pour supprimer un compte de test : Profil → Compte → "Supprimer mon compte" (supprime aussi
   ses données Club côté serveur, requis par les règles App Store sur la suppression de compte).

## Notifications push (APNs)

Les rappels quotidiens ("ta séance du jour t'attend") sont des notifications **locales** — elles
marchent déjà sans rien configurer, purement depuis l'horloge de l'appareil. Ce qui suit active en
plus de **vraies notifications push serveur** (un kudos reçu, un membre du club qui poste une
activité) — ça arrive même si l'app est complètement fermée, ce que les notifications locales ne
peuvent pas faire. `lib/apns.js` signe les requêtes avec une clé d'authentification APNs (`.p8`),
pas un certificat par app — une seule clé suffit pour tous les builds.

### 1. Créer (ou vérifier) la clé APNs sur Apple Developer

1. [developer.apple.com](https://developer.apple.com/account) → **Certificates, Identifiers &
   Profiles** → **Keys** → si tu as déjà une clé d'une session précédente, ouvre-la et vérifie que
   la case **"Apple Push Notifications service (APNs)"** est cochée — sinon crée une clé (bouton
   **+**), coche cette case, **Continue** → **Register**.
2. **Télécharge le fichier `AuthKey_XXXXXXXXXX.p8`** — c'est la seule fois où Apple te laisse le
   télécharger, garde-le en lieu sûr (ne le commite jamais dans le repo).
3. Note le **Key ID** (10 caractères, affiché sur la page de la clé, aussi présent dans le nom du
   fichier téléchargé).

Le **Team ID** est déjà connu : `SW49TQ25NV` (visible dans `project.yml`, `DEVELOPMENT_TEAM`).

### 2. Variables d'environnement Vercel

Dans les réglages du projet Vercel → **Environment Variables**, ajoute :

- `APNS_KEY_ID` — le Key ID noté ci-dessus.
- `APNS_TEAM_ID` — `SW49TQ25NV`.
- `APNS_PRIVATE_KEY` — ouvre le fichier `.p8` dans un éditeur de texte et colle **tout son
  contenu tel quel**, lignes `-----BEGIN PRIVATE KEY-----`/`-----END PRIVATE KEY-----` incluses.
- `APNS_ENV` — laisse absent (ou mets `development`) tant que tu testes depuis Xcode sur un
  appareil branché ; passe-la à `production` une fois que tu testes via TestFlight ou l'App Store
  — un jeton d'appareil obtenu dans un environnement ne fonctionne que sur le serveur APNs de ce
  même environnement, d'où l'importance de ne pas se tromper.

Redéploie ensuite le projet Vercel pour que ces variables prennent effet.

### 3. Rejouer `db/schema.sql`

Une nouvelle table `device_tokens` a été ajoutée — retourne dans le **SQL Editor** de Neon (voir
section précédente) et réexécute tout le contenu de `db/schema.sql` (`CREATE TABLE IF NOT EXISTS`
partout, donc sans risque pour les données déjà présentes).

### 4. Régénérer le projet Xcode et tester

`project.yml` a changé (nouvel entitlement `aps-environment`, nouveau `UIBackgroundModes`) —
relance `xcodegen generate` puis rebuild. Les push **ne fonctionnent jamais sur le Simulateur** —
teste sur un vrai appareil : connecte-toi au Club, verrouille l'appareil ou quitte l'app, puis
depuis un second compte, applaudis une de tes activités ou poste dans le même club — une
notification doit arriver.

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

## Widget écran d'accueil

Un nouveau target `RunUpWidgets` (WidgetKit) affiche l'anneau des 3 objectifs du jour + la série
sur l'écran d'accueil. Il tourne dans son propre processus, séparé de l'app — il ne voit jamais
`UserProfile` directement, seulement l'instantané que l'app publie dans un App Group partagé
(`DailyGoalsSnapshot`, `AppState.publishWidgetSnapshot()`).

1. `xcodegen generate` (voir plus haut) crée le nouveau target automatiquement à partir de
   `project.yml` — rien à ajouter à la main dans Xcode.
2. Au premier build, Xcode peut demander de créer le véritable **App Group**
   (`group.com.hicsuntco.runup`) sur ton compte développeur — avec la signature automatique
   (`CODE_SIGN_STYLE: Automatic`, déjà configuré sur les deux targets), il devrait proposer de le
   créer tout seul. Si Xcode affiche une erreur de provisioning à ce sujet : sélectionne la cible
   `RunUp` → Signing & Capabilities → vérifie que "App Groups" apparaît et que
   `group.com.hicsuntco.runup` est bien coché, puis fais pareil pour la cible `RunUpWidgets`.
3. Lance l'app une première fois sur un appareil (pas besoin du Simulateur, mais ça marche aussi)
   pour qu'elle publie un premier instantané, puis ajoute le widget : appui long sur l'écran
   d'accueil → **+** → cherche "RunUp" → choisis la taille (petite ou moyenne).
4. Le widget ne se met à jour tout seul qu'une fois par heure environ (limite du système) — mais
   l'app lui demande de se rafraîchir immédiatement à chaque fois que les objectifs du jour
   changent (fin de séance, sync Santé, changement de thème), donc en pratique il devrait toujours
   être à jour peu après avoir rouvert l'app.

## Icône de l'app

`RunUp/Resources/Assets.xcassets/AppIcon.appiconset/` contient un slot d'icône App Store
(1024×1024, format "single size" iOS 17+) sans image — à remplir dans Xcode avant tout envoi sur
TestFlight/App Store. Le logo décrit dans le handoff design (voir
`design_handoff_runup_app/README.md` § Assets, fonction `AppMark`) est un bon point de départ :
c'est le même glyphe que `Views/Components/AppMarkView.swift`, à exporter en PNG haute résolution.
