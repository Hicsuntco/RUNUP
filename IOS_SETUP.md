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

## Envoyer un build sur TestFlight

Deux chaînes existent, et elles font la même chose : `.github/workflows/testflight.yml` (GitHub
Actions) et `ci_scripts/ci_post_clone.sh` (Xcode Cloud). Toutes deux appellent
`ci_scripts/prepare_project.sh`, qui écrit `Secrets.xcconfig`, impose le numéro de build aux trois
cibles et lance `xcodegen` — c'est le seul endroit où ces gestes sont décrits, pour qu'elles ne
puissent pas produire des binaires différents.

**Il faut en choisir une.** GitHub numérote ses builds `1000 + numéro d'exécution`, Xcode Cloud
repart de son propre compteur (autour de 15). Une fois qu'un build 1001 est arrivé chez Apple, un
build 16 est refusé pour la même version : App Store Connect exige un numéro strictement croissant.
Les faire alterner ne marche pas.

### Depuis GitHub (recommandé — tout part du dépôt)

Un envoi se déclenche de deux façons : automatiquement à chaque push sur la branche de
développement qui touche au code iOS (les commits ne concernant que `api/`, `db/`, `lib/`, la doc
ou le site sont ignorés — reconstruire à l'identique sur une machine macOS facturée dix fois le
tarif normal n'apporte rien), ou à la main depuis **Actions → TestFlight → Run workflow**, qui
accepte un numéro de build imposé.

Le workflow génère le projet, **exécute les tests** (dont `RouteSharingPrivacyTests`, qui vérifie
que les 300 premiers et derniers mètres d'un tracé partagé sont bien retirés), archive, signe et
envoie. Comptez vingt à trente minutes, plus dix à trente minutes de traitement chez Apple avant
que le build apparaisse dans TestFlight.

**Neuf secrets à créer une fois** (Settings → Secrets and variables → Actions). Aucune de ces
valeurs ne doit se retrouver dans le dépôt, dans un message ou dans une capture d'écran :

| Secret | D'où il vient |
| --- | --- |
| `RUNUP_APP_SECRET` | La même chaîne que la variable Vercel du même nom. Sans elle, le coach répond 401 dans le build et rien d'autre ne casse — donc ça passe inaperçu. |
| `APPLE_DIST_CERT_P12` | Trousseaux d'accès → clic droit sur « Apple Distribution: … » → Exporter au format `.p12`, puis `base64 -i Certificats.p12 \| tr -d '\n' \| gh secret set APPLE_DIST_CERT_P12`. |
| `APPLE_DIST_CERT_PASSWORD` | Le mot de passe choisi pendant cet export. |
| `ASC_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API → **+**, rôle **Admin**. Pas « App Manager » : ce rôle crée des profils de développement mais se voit refuser la signature dans le nuage, et l'export échoue sur `Cloud signing permission error` après avoir archivé — soit un quart d'heure de machine pour découvrir un refus de permission. Le rôle d'une clé ne se change pas après coup ; il faut en recréer une. |
| `ASC_ISSUER_ID` | Affiché en haut de la même page. |
| `ASC_KEY_P8` | Le fichier `AuthKey_XXXXXXXXXX.p8`, téléchargeable **une seule fois** à la création de la clé. Posé directement : `base64 -i AuthKey_XXXXXXXXXX.p8 \| tr -d '\n' \| gh secret set ASC_KEY_P8`. |
| `APPLE_PROFILE_APP` | Le profil de distribution de `com.hicsuntco.runup` (voir juste en dessous). |
| `APPLE_PROFILE_WIDGETS` | Celui de `com.hicsuntco.runup.widgets`. |
| `APPLE_PROFILE_WATCH` | Celui de `com.hicsuntco.runup.watchkitapp`. |

Le Team ID (`SW49TQ25NV`) n'est pas un secret : il est déjà dans `project.yml`, et les options
d'export sont fabriquées à l'exécution à partir des profils eux-mêmes.

#### Les trois profils de distribution

Sur [developer.apple.com](https://developer.apple.com/account/resources/profiles/list) →
Certificates, Identifiers & Profiles → **Profiles** → **+**, trois fois :

| App ID à choisir | Type de profil |
| --- | --- |
| `com.hicsuntco.runup` | iOS → Distribution → **App Store Connect** |
| `com.hicsuntco.runup.widgets` | iOS → Distribution → **App Store Connect** |
| `com.hicsuntco.runup.watchkitapp` | **watchOS** → Distribution → **App Store Connect** |

Chacun doit s'appuyer sur le certificat **Apple Distribution** — le même que `APPLE_DIST_CERT_P12`.
Nomme-les comme tu veux : le workflow lit le nom et le bundle ID dans le fichier lui-même, il n'y a
aucune correspondance recopiée à la main qui pourrait devenir fausse.

Télécharge les trois, puis, en remplaçant chaque nom de fichier :

```bash
base64 -i ~/Downloads/RunUp_App_Store.mobileprovision | tr -d '\n' | gh secret set APPLE_PROFILE_APP
base64 -i ~/Downloads/RunUp_Widgets.mobileprovision   | tr -d '\n' | gh secret set APPLE_PROFILE_WIDGETS
base64 -i ~/Downloads/RunUp_Watch.mobileprovision     | tr -d '\n' | gh secret set APPLE_PROFILE_WATCH
```

**Ils expirent au bout d'un an.** À ce moment-là, l'export échouera ; il suffira de régénérer les
trois profils au même endroit et de rejouer ces trois commandes.

#### Pourquoi les profils sont fournis, et pas demandés à Apple

Parce que la signature automatique ne va pas jusqu'au bout en CI. Elle fonctionne pour
**archiver** — `-allowProvisioningUpdates` crée des profils de *développement* tout seul, et
l'archivage réussit. Mais l'export vers l'App Store réclame des profils de *distribution*, que la
signature automatique ne sait obtenir que par la « signature dans le nuage ». Celle-ci a répondu
`Cloud signing permission error` sur les trois bundle IDs, avec une clé d'équipe au rôle Admin —
donc pour une raison qui ne dépend ni du dépôt ni du workflow. Fournir les profils supprime cette
dépendance entière : pendant l'export, plus rien n'est demandé à Apple.

La construction tourne sur l'image `macos-26`, et le workflow y sélectionne explicitement le Xcode
le plus récent installé plutôt que celui par défaut. App Store Connect refuse tout binaire construit
avec un SDK iOS antérieur à 26 — et le refus tombe à la toute dernière étape, une fois l'IPA signé
et téléversé. Le workflow vérifie donc la version du SDK avant de compiler.

Le certificat est importé dans un trousseau jetable, détruit à la fin du job même en cas d'échec.

La première étape du workflow vérifie que les neuf secrets existent, et que les cinq qui sont des
fichiers encodés se décodent bien en ce qu'ils prétendent être : une clé PEM, une archive PKCS#12,
trois profils lisibles. Sans ce contrôle, un secret vide ne se manifeste qu'à l'archivage —
`xcodebuild` parle alors de `invalidPEMDocument`, soit un message de cryptographie pour dire « ce
fichier est vide », après avoir compilé et testé toute l'app.

### Depuis Xcode Cloud

`ci_scripts/ci_post_clone.sh` s'exécute tout seul après le clone. Il faut déclarer
`RUNUP_APP_SECRET` en variable d'environnement du workflow, **cochée « Secret »** (App Store
Connect → Xcode Cloud → le workflow → Environment → Environment Variables) — sans quoi sa valeur
apparaîtrait en clair dans les logs de build. Le workflow doit aussi comporter une action
**Archive** avec distribution **TestFlight (Internal Testing)** : un workflow « Default » se
contente de construire et de tester, sans jamais rien envoyer.

### Depuis Xcode, à la main

`xcodegen generate`, puis Product → Archive, puis Distribute App → App Store Connect → Upload. Il
faut alors incrémenter `CFBundleVersion` soi-même dans `project.yml` — aux **trois** endroits, car
Apple refuse un binaire dont l'app, le widget et la montre ne portent pas le même couple
(version, build).

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
   - `RUNUP_APP_SECRET` — doit être identique à `RUNUP_APP_SECRET` dans `Secrets.xcconfig` côté
     app (voir juste en dessous) — secret partagé app↔serveur, pas un identifiant utilisateur —
     juste un frein contre un appel externe au hasard sur cette URL.
3. Redéploie, puis vérifie que `RunUp/Services/CoachService.swift`'s `endpoint` pointe bien vers
   l'URL Vercel réelle du projet (`https://<projet>.vercel.app/api/coach`).

**Côté app — `Secrets.xcconfig` (une fois, sur ta machine) :**

Ce secret n'est **plus** écrit en dur dans `CoachService.swift` : il était committé en clair dans
le repo (et il reste dans l'historique git — voir plus bas). L'app le lit maintenant dans son
Info.plist (`RUNUPAppSecret`), rempli au build depuis le réglage `RUNUP_APP_SECRET`.

1. À la racine du repo, crée un fichier **`Secrets.xcconfig`** (déjà dans `.gitignore`, il ne sera
   jamais committé) contenant une seule ligne :
   ```
   RUNUP_APP_SECRET = <le secret, la même chaîne que la variable Vercel>
   ```
   Génère-en un nouveau avec `openssl rand -hex 24` : l'ancien secret ayant été committé, il doit
   être considéré comme compromis et **remplacé des deux côtés** (ici et dans les variables
   d'environnement Vercel), pas réutilisé.
2. `xcodegen generate` puis rebuild — `Config.xcconfig` (committé, valeurs vides par défaut)
   inclut `Secrets.xcconfig` s'il existe. Sans ce fichier, l'app compile quand même mais envoie un
   secret vide et le coach répond 401.

Important : un secret embarqué dans l'app reste extractible de l'IPA par n'importe qui, quel que
soit l'endroit où il est rangé — c'est un frein contre un appel au hasard, pas une vraie barrière.
La vraie réponse est App Attest / DeviceCheck (voir le `TODO(security)` dans `CoachService.swift`).

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

`RunUp/Resources/Assets.xcassets/AppIcon.appiconset/` contient l'icône App Store (1024×1024,
format "single size" iOS 17+), et `RunUpWatch/Assets.xcassets/` la même pour la montre — les deux
sont en place, un binaire sans elles étant refusé à l'envoi. Pour la refaire, le logo décrit dans
le handoff design (voir
`design_handoff_runup_app/README.md` § Assets, fonction `AppMark`) est un bon point de départ :
c'est le même glyphe que `Views/Components/AppMarkView.swift`, à exporter en PNG haute résolution.

---

## Abonnement RUNUP Plus — ce qu'il reste à faire dans App Store Connect

Le code est en place et compile, mais **aucun abonnement ne peut être acheté ni testé** tant que
les étapes ci-dessous ne sont pas faites. Elles ne peuvent l'être que depuis le compte Apple
Developer, pas depuis le dépôt.

### 1. Contrat des applications payantes

App Store Connect → **Accord, taxes et services bancaires** → signer le *Paid Applications
Agreement*, puis renseigner les coordonnées bancaires et fiscales.

Tant que ce contrat est « en attente », `Product.products(for:)` renvoie une liste **vide** : le
paywall affichera « Les formules n'ont pas pu être chargées » et rien d'autre. C'est la cause n° 1
des paywalls vides, et elle ne produit aucun message d'erreur exploitable.

### 2. Le groupe d'abonnement

App Store Connect → l'app → **Abonnements** → créer un groupe, par exemple `RUNUP Plus`.

Les deux formules doivent être **dans le même groupe**. Sinon, passer du mensuel à l'annuel crée un
second abonnement au lieu de changer de formule, et l'utilisatrice paie les deux.

### 3. Les deux produits

Les identifiants doivent être **exactement** ceux-ci — ils sont écrits dans
`SubscriptionService.ProductID` et une faute de frappe donne un paywall vide, sans erreur :

| Identifiant | Durée | Prix cible |
|---|---|---|
| `com.hicsuntco.runup.plus.yearly` | 1 an | 59,99 € |
| `com.hicsuntco.runup.plus.monthly` | 1 mois | 9,99 € |

Positionnement retenu : la moitié de Runna (19,99 $/mois, 119,99 $/an). L'annuel revient à 5 €/mois,
soit 50 % de moins que le mensuel — l'app calcule et affiche cet écart à partir des prix réels
renvoyés par StoreKit, donc il suffit de changer les prix pour que l'affichage suive.

### 4. L'essai de 7 jours

Sur **chacun** des deux produits : **Offres d'introduction** → *Essai gratuit* → 7 jours → toutes
les zones.

C'est là que vit l'essai, et nulle part ailleurs dans le code. Un compte à rebours maison serait
contourné en changeant l'heure du téléphone, remis à zéro à la réinstallation, et ne suivrait pas
l'utilisatrice d'un appareil à l'autre.

### 5. Métadonnées de revue

Chaque produit a besoin d'un nom affiché, d'une description et d'une **capture d'écran de revue**
(le paywall suffit). Un produit sans capture reste bloqué en « Métadonnées manquantes » et ne se
charge pas en production.

### 6. Tester avant de livrer

- **Sandbox** : Réglages iOS → App Store → Compte Sandbox. Un abonnement d'un an s'y renouvelle
  toutes les heures et l'essai de 7 jours y dure 3 minutes.
- **TestFlight** : les achats sont automatiquement en sandbox, rien n'est débité.

### 7. Ce qui reste ouvert, et qu'il faudra traiter

La vérification est faite **sur l'appareil**. C'est solide contre la falsification ordinaire —
StoreKit vérifie la signature d'Apple — mais un appareil débridé reste un appareil débridé.

Le seul endroit où ça coûte de l'argent est le coach : chaque message est un appel serveur payé.
La suite logique est que `api/coach` exige le JWS de la transaction en plus du secret partagé, et
le vérifie contre les clés publiques d'Apple avant de répondre. Tant que ce n'est pas fait, un
client modifié peut appeler le coach sans payer.

### Le verrou s'arme tout seul — et pas avant

Tant qu'App Store Connect répond que `com.hicsuntco.runup.plus.*` n'existe pas, **l'app reste
ouverte**. Ce n'est pas une porte dérobée, c'est le seul comportement défendable : enfermer
quelqu'un dehors d'une app qu'on ne peut pas encore lui vendre est pire que de la laisser entrer.

Le jour où les deux produits existent, le paywall se met en place de lui-même, sans rien à
redéployer.

Le distinguo tient parce que StoreKit sépare les deux cas : `Product.products(for:)` renvoie un
tableau **vide** pour des identifiants inconnus, et **lève une erreur** quand elle ne peut pas
joindre l'App Store. Couper le réseau ne donne donc pas l'app gratuitement.
