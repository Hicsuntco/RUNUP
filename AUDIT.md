# Phase 1 — état des lieux

Relevé le 9 novembre 2026, sur `claude/runup-ios-swiftui-app-5b1yv6` (la branche qui EST la
production Vercel et la source des builds TestFlight).

**Rien n'a été modifié.** Tout ce qui suit est mesuré, pas estimé. Quand je n'ai pas pu mesurer,
je le dis à la place du chiffre.

---

## Relecture du 11 novembre 2026 — l'écart avec la DA, remesuré

Cet audit date du 7 novembre. Quarante-quatre chantiers ont passé depuis, et dix-sept des
vingt-deux items de `PHASE2.md` sont faits. Je n'ai donc pas refait l'état des lieux à zéro :
j'ai remesuré **ce qui a vieilli et ce qui est le plus actionnable**, c'est-à-dire l'écart avec la
direction artistique, à la précision où le brief la donne — valeurs hexadécimales comprises.

**Rien n'a été modifié.** Tout ce qui suit est une lecture.

### 1. La palette : aucune des douze couleurs du brief n'existe dans le code

Cherchées une par une, en hexadécimal, dans les 300 fichiers Swift : **zéro occurrence**, pour
les douze.

| rôle | brief | app aujourd'hui |
| --- | --- | --- |
| accent action | `#F0225F` | `#FF0A78` (thème « rose », défaut) |
| accent secondaire | `#7B3FE4` | `#7C5CFF` |
| fond consultation | `#FBF9F7` (blanc chaud) | `#F4F3F8` (gris-lavande froid) |
| cartes | `#FFFFFF` | `#FFFFFF` ✓ |
| fonds teintés | `#F3EEF4` | `#EDEBF4` |
| texte | `#15121A` / `#6B6473` | `#15151C` / des opacités de noir |
| fond séance | `#000000` | `#0E0E14` et `#0A0A0E` |
| texte séance | `#FFFFFF` / `#A09AA8` | blanc / opacités |
| cycle | `#F2B8A0` sur `#FDF1EC` | aucun jeton de cycle |

Les écarts d'accent et de texte sont des nuances ; **le fond de consultation est un désaccord de
nature** : le brief demande un blanc chaud, l'app pose un gris froid légèrement lavande. C'est
précisément ce que la décision D2 avait laissé ouvert — « le `#FBF9F7` chaud du brief n'est pas
imposé » — donc ce n'est pas une dérive, c'est une décision prise. Mais elle n'a jamais été
confrontée au reste de la palette.

### 2. Une teinte par intensité : la structure y est, les valeurs non, et il y en a sept

Le brief demande cinq intensités à teinte fixe. L'app a bien **une teinte par famille de séance,
la même partout** — c'est la structure demandée — mais elle en compte **sept**, et aucune valeur
ne correspond :

| brief | app (clair / sombre) |
| --- | --- |
| facile `#2FB37A` (vert) | endurance → `#6B9E00` / `#C8FF3D` (lime) |
| seuil `#F5A524` | tempo → `#B86A00` / `#FFB03D` |
| intervalles `#F0225F` | intervals → `ember` |
| récupération `#5AA9E6` (bleu) | recovery → `#0E9C8C` / `#38E0D0` (turquoise) |
| sortie longue `#7B3FE4` | longRun → `#5B3FD6` / `#9B7CFF` |
| — | repos, et « fonctionnel » (HYROX) |

**Et il y a une objection technique à la palette du brief**, qu'il faut poser avant de l'adopter :
elle donne une seule valeur par intensité, alors que l'app porte deux thèmes et huit accents, et
que `check_contraste.py` tient chaque couleur sur les deux fonds. `#F5A524` sur blanc donne environ
1,9:1 — très au-dessous du seuil. Les valeurs du brief sont pensées pour un fond sombre ; les
reprendre telles quelles casserait le contraste en mode clair, qui est désormais le défaut.

### 3. Ce qui est conforme

- **La typographie.** Le brief autorise « Geist, Inter Display ou General Sans » : l'app est
  entièrement en **Inter**, chiffres tabulaires compris.
- **Le dégradé.** Zéro dégradé décoratif, zéro verre dépoli, zéro emoji — mesuré, et tenu par
  `check_degrade.py` et `check_verre.py`. Le rose → violet ne vit plus que sur le logo.
- **L'accueil en flux vertical unique.**
- **Live Activity, widget, complication Watch.**

### 4. Les icônes : zéro Phosphor, zéro Lucide

200 appels à `systemName:` — **SF Symbols à 100 %**. Le brief demande « un seul set d'icônes au
trait 1,5 px (Phosphor ou Lucide), pictos de sport dans le même trait ».

C'est un écart entier, et il n'est pas gratuit à combler : les SF Symbols s'alignent sur la ligne
de base du texte, suivent le poids de la fonte et les tailles d'accessibilité tout seuls. Un set
importé demande de refaire ces trois choses à la main, et `check_symboles.py` — qui vérifie
aujourd'hui que les 108 symboles employés existent — devrait être réécrit.

### 5. La barre basse, et le Club rangé sous « Profil »

| | brief | app |
| --- | --- | --- |
| entrées | 3 — Aujourd'hui, Plan, Club | 5 — Prog, Coach, RUN, Stats, Profil |

La décision D3 a tranché pour cinq. Mais il reste un écart qu'aucune décision n'a couvert : **le
Club n'est pas dans la barre.** `RootTabView` le rattache à l'onglet Profil (`case .club, .fil:
return .profile`), donc on y arrive par Profil puis un appui de plus.

Or « il te connecte à un club » est l'un des trois différenciateurs que le brief demande de rendre
évidents **dès le premier écran**. Aujourd'hui, c'est le seul des trois qui se trouve à deux
niveaux de profondeur, sous un onglet qui parle de soi.

### 6. L'inscription

Dix étapes, vingt fichiers de vues. Le brief en demande trois ; la décision D4 a tranché pour la
version longue, « ultra sur mesure pour le plan ». Pas un écart, une décision — mais le brief
re-transmis dit toujours trois.

### 7. L'écran de séance

- **Fond :** `#0E0E14` et `#0A0A0E`, pas le `#000000` du brief.
- **Boutons :** mesurés à 52 et 70 points. Le brief demande **au moins 64**, et une pause « de la
  taille d'une paume ». Deux des trois boutons sont sous le seuil.
- **Chiffre central :** 52 ou 64 points selon qu'une consigne est affichée. Lisible, mais loin du
  « très grand corps » demandé.
- **Et un second jeu de jetons.** `LiveRunView` porte un `enum Ink` avec deux couleurs écrites en
  dur. C'est la **règle 4** — « toute valeur en dur dans un écran est un défaut » — et c'est le
  seul endroit de l'app où un écran se donne sa propre palette.

### 8. Les durées d'animation

Le brief : 200 à 300 ms en consultation, quasi absentes en séance.

`RUMotion` donne 220 ms pour le changement d'écran et 260 ms pour ce qui répond au doigt — dans la
fourchette. Mais **440 ms** pour l'arrivée d'une carte, **800 ms** pour un anneau qui se remplit et
**1 450 ms** pour un tracé qui se dessine, tous trois en consultation. Les trois ont une raison
écrite dans `Motion.swift` ; aucune n'a été confrontée à la fourchette du brief.

### 9. Ce que je n'ai pas refait, et pourquoi

**Les notes sur 10, écran par écran.** L'audit du 7 novembre en porte ; les refaire aujourd'hui
donnerait un chiffre que je ne saurais pas défendre autrement que par mon goût, et vingt-huit
captures existent qui se regardent. Je préfère la table d'écarts ci-dessus, où chaque ligne est
une mesure.

**L'architecture, les dépendances, la sécurité, le RGPD, la relecture du head coach.** Les
sections 1 à 8 et 10 de cet audit tiennent toujours : ce qui a bougé depuis y est consigné
chantier par chantier dans `PROGRESS.md`, et les items correspondants de `PHASE2.md` sont marqués.

### 10. Ce qui demande une décision, et que je ne prendrai pas seul

Le brief que tu viens de renvoyer **contredit quatre décisions que tu as prises le 9 novembre**.
Je ne sais pas si tu as changé d'avis ou si le brief est simplement le document d'origine :

| le brief dit | tu avais tranché (D1–D4, 9 novembre) |
| --- | --- |
| « une seule couleur d'accent RunUp » | **D1** — les huit thèmes d'accent restent |
| « fond blanc chaud `#FBF9F7` » | **D2** — fond clair oui, mais le froid actuel peut rester |
| « barre basse à trois entrées » | **D3** — la barre garde ses cinq entrées |
| « onboarding en trois questions » | **D4** — l'inscription reste longue |

Tant que ce n'est pas tranché, je ne touche à aucun des quatre.

---

## 0. Ce qu'il faut savoir avant de lire le reste

Trois faits qui changent la lecture de tout le document.

**Le brief décrit une direction artistique que l'app ne porte pas.** Pas « imparfaitement » :
une autre. La palette, le nombre d'onglets, le nombre d'écrans d'inscription, la règle « une
seule couleur d'accent » — l'app dit autre chose sur chacun de ces points, et souvent avec une
raison écrite dans le code. C'est le plus gros chantier du document, et c'est une décision de
produit avant d'être du travail de développement. Section 9.

**La base de données n'est pas Supabase.** C'est **Neon** (Postgres serverless), derrière des
fonctions Vercel. Le brief mentionne des « règles Supabase » qui n'existent pas ici ; la sécurité
d'accès repose sur `requireAuth` et sur le SQL de `api/`, pas sur des règles déclaratives.

**Android n'existe pas.** Le brief demande un parcours testé « sur iOS et Android ». Il n'y a ni
cible, ni code, ni projet Android dans ce dépôt. Décision du 7 novembre : iOS seul pour
l'instant.

---

## 1. Architecture

| | |
| --- | --- |
| App iPhone | **215 fichiers Swift, 54 285 lignes** |
| Montre | 4 fichiers, 791 lignes |
| Widgets et Live Activity | 4 fichiers, 717 lignes |
| Tests unitaires | 66 fichiers, 11 790 lignes, **736 cas** |
| Tests d'interface | 2 fichiers, 613 lignes (ils FABRIQUENT les captures) |
| Serveur | 12 fonctions Vercel, 4 795 lignes + 18 modules `lib/`, 1 465 lignes |
| Vues SwiftUI | **111** |
| Services | 35 |
| Modèles | 34 |

SwiftUI + SwiftData, un `AppState` central (1 245 lignes), pas de framework d'architecture
imposé. Le projet est généré par **XcodeGen** depuis `project.yml` — il n'y a pas de
`.xcodeproj` versionné, ce qui est le bon choix : aucun conflit de fusion sur un fichier de
projet.

**Le serveur est contraint par un plafond dur.** Vercel Hobby autorise **douze** fonctions
serverless, une par fichier sous `api/`. Il y en a exactement douze. Le treizième ne « marche pas
moins bien » : il fait échouer le déploiement de production entier, avec un message qui ne dit
rien. `check_fonctions.py` refuse désormais le treizième ; c'est la raison pour laquelle
`lib/rapportsEntrants.js` et `lib/clubsSuggeres.js` vivent dans `lib/` et non dans `api/`.

### Les cinq plus gros fichiers, et ce que ça dit

| Fichier | Lignes | Jugement |
| --- | --- | --- |
| `AdaptivePlanEngine.swift` | 2 231 | Dense, mais c'est le cœur métier et il est documenté ligne à ligne. À scinder un jour, pas en urgence. |
| `ClubService.swift` | 1 723 | Une classe-façade pour tout le réseau social. Candidate à la découpe. |
| `ClubView.swift` | 1 424 | **Trop.** Un écran qui porte le classement, le fil, les défis, les badges, les séances et la recherche. |
| `AppState.swift` | 1 245 | Objet-dieu. C'est la vraie dette d'architecture. |
| `HomeView.swift` | 1 241 | Gros, mais c'est l'écran principal et chaque carte y est justifiée. |

---

## 2. Dette technique

**Ce qui est sain.**

- Aucune valeur de couleur, de taille de titrage, d'icône ou d'écart en dur dans un écran : six
  contrôles automatiques le refusent (`check_accent`, `check_echelle`, `check_icones`,
  `check_grille`, `check_chiffres`, `check_teintes`).
- Zéro `try!` sur 275 sites de gestion d'erreur (143 `try?`, 132 `catch`) — audité le 8 novembre.
- 42 contrôles et 37 fichiers de cas tournent à chaque poussée, en plus des 736 tests Swift.

**Ce qui ne l'est pas.**

- **`AppState` est un objet-dieu** de 1 245 lignes. Tout le monde en dépend. C'est ce qui rendra
  chaque chantier suivant plus cher qu'il ne devrait.
- **Aucun composant d'état vide partagé.** Zéro fichier ne porte un `RUEmpty`/`EtatVide` : chaque
  écran écrit le sien. La règle 3 exige un état vide partout, la règle 4 exige qu'aucune valeur
  ne soit écrite deux fois — ici la deuxième perd.
- **`main` et la branche de travail n'ont en commun que le commit initial** du 13 juillet : 853
  commits d'un côté, 50 de l'autre. Sans conséquence, sauf pour **`privacy.html`** — la page dont
  l'adresse est sur la fiche App Store — servie par GitHub Pages **depuis `main`** et donc
  recopiée à la main. `check_politique.py` compare la page publiée EN LIGNE au dépôt.
  *(Corrigé le 10 novembre : cette ligne parlait de « deux pages ». `support.html` est publiée mais
  rien n'y mène — la fiche et l'app emploient un `mailto:`. Voir `RELEASE.md`.)*
- **Deux branches portent du travail qui n'est nulle part ailleurs** (voir `PROGRESS.md`).

---

## 3. Dépendances

**Quatre, côté serveur.** `@neondatabase/serverless` 1.1, `@vercel/blob` 2.6, `bcryptjs` 3.0,
`jose` 6.2. Aucune obsolète.

**Zéro, côté Swift.** Pas un seul paquet tiers : ni Sentry, ni Firebase, ni Alamofire, ni Lottie.
Tout est écrit à la main sur les frameworks d'Apple.

C'est un choix, et il tient : il n'y a aucune dépendance qui puisse casser un lundi matin, aucun
SDK qui exfiltre quoi que ce soit, et la fiche de confidentialité peut dire « aucun outil tiers »
sans mentir. Le prix est qu'il n'y a pas de filet gratuit — tout ce qui garde cette app a été
écrit pour elle.

**Une leçon payée.** `jose` 6, livré en ESM seul et chargé par `require`, a mis l'API à terre
onze minutes le 7 novembre : construction verte, 133 tests verts, et c'est l'empaquetage des
fonctions Vercel qui ne savait pas le charger. `check_cjs.py` ferme cette porte.

---

## 4. Écrans et parcours réel

**111 vues**, réparties ainsi :

| Dossier | Écrans | |
| --- | --- | --- |
| Club | 23 | classement, fil, mur, défis, séances, badges, amis, profils publics, itinéraires |
| Composants | 30 | la bibliothèque partagée |
| **Inscription** | **19** | voir plus bas |
| Race | 7 | objectif de course, jour J, HYROX, ultra, triathlon, duathlon |
| Profile | 6 | |
| Live | 5 | course en cours, récap, partage, vidéo |
| Stats | 5 | |
| Home | 4 | |
| ProgramEnd | 3 | récupération, nouvel objectif |
| Auth, Coach, Paywall | 5 | |

### Le parcours réel, et ses deux écarts avec le brief

**L'inscription fait dix-neuf écrans.** Le brief en demande trois. Même en retirant les quatre
écrans de détail spécifiques à une discipline (HYROX, ultra, triathlon, duathlon) et le conteneur,
il en reste une douzaine : nom, date de naissance, niveau, objectif, jours de course, point de
départ, bien-être, santé, approfondissement, fabrication du programme, récapitulatif.

**La barre basse a cinq entrées**, pas trois : quatre onglets plus le bouton RUN surélevé au
centre (Prog, Coach, RUN, Stats, Profil). Le brief demande Aujourd'hui, Plan, Club — et le Club,
qui est l'un des trois différenciateurs annoncés, **n'est pas dans la barre**.

---

## 5. Ce qui est testé, et ce qui ne l'est pas

**736 cas Swift**, dont le moteur d'adaptation (`AdaptivePlanEngineSafetyTests`), le cycle
(`CycleTrackingTests`), la charge (`TrainingLoadTests`), le déplacement de séance
(`SessionMoveTests`), le triathlon et le duathlon.

**42 contrôles de dépôt** par-dessus, qui tiennent ce qu'un test unitaire ne voit pas : les
chaînes traduites, les symboles SF qui existent vraiment, le contraste, les pluriels dans trois
langues, l'accord en genre, les séparateurs décimaux, le câblage des contrôles entre eux.

**Ce qui n'est pas testé.**

- **Le GPS en conditions réelles.** Aucun test ne fait bouger un appareil. C'est la case la plus
  chère de la phase 4 et elle demande quelqu'un qui court.
- **Le mode hors ligne et la connexion lente.** `PanneReseau` existe, rien ne l'éprouve sous
  latence.
- **Le paiement de bout en bout.** `SubscriptionService` existe ; il n'y a pas de test de parcours
  d'achat.
- **La montre.** Aucune cible de test d'interface watchOS n'existe. Depuis aujourd'hui, la chaîne
  sait au moins la PHOTOGRAPHIER.

---

## 6. Crashs

**Il n'y a pas de Sentry ni de Crashlytics, et c'est voulu** (décision du 7 novembre : maison).
Le rapport de panne est construit sur **MetricKit**, le mécanisme d'Apple, et part sur notre
propre serveur. Le choix est documenté et sourcé : un gestionnaire de signal ne peut pas écrire
une pile d'appels en Swift — Quinn, chez Apple : « `backtrace` is not an async signal safe
function », « a crash reporter's signal handler cannot use Objective-C or Swift ».

**Ce que ça ne voit pas, et il faut le savoir** : MetricKit ne rapporte que ce que le SYSTÈME
appelle une panne. Les 275 erreurs rattrapées de l'app lui sont invisibles, et rien n'est collecté
sur simulateur. Une table `crash_reports` vide veut dire « rien de ce que le système appelle une
panne », pas « rien ne casse ».

La phase 4 exige « monitoring des crashs actif ». Il l'est, autrement que demandé.

---

## 7. Performance

**GPS.** `kCLLocationAccuracyBest`, `activityType = .fitness`, pas de `distanceFilter` (délibéré :
l'auto-pause lit la vitesse instantanée), `pausesLocationUpdatesAutomatically = false`,
`allowsBackgroundLocationUpdates` posé seulement quand une course démarre. C'est le réglage
correct pour une app de course ; c'est aussi le plus gourmand, et **la consommation réelle n'a
jamais été mesurée**.

**Listes.** 62 fichiers utilisent `ForEach`, **12 seulement** une liste paresseuse. La plupart
des listes sont courtes (une semaine, un podium), mais le fil du club et l'historique ne le sont
pas. À vérifier sur un compte chargé.

**Premier écran en moins de 2 secondes** : non mesuré. Aucun relevé de temps de lancement
n'existe dans le dépôt.

---

## 8. Sécurité, santé, cycle, RGPD

**Aucune clé en clair dans le dépôt.** Recherche sur les formes connues (`sk-`, `AIza`, `xox`) :
rien.

**Le cycle menstruel ne quitte jamais l'appareil.** Recherche sur `api/`, `lib/` et le schéma :
aucune colonne, aucune route, aucun événement. Il vit dans SwiftData, sur le téléphone, et c'est
la position la plus défendable possible. Ce point est meilleur que ce que le brief exigeait.

**HealthKit** porte un coupe-circuit de processus (`HealthKitService.desactiver()`), et un
contrôle refuse tout appel qui le contournerait.

**Suppression du compte** : `api/account/[action].js`, avec **39 contraintes `ON DELETE CASCADE`**
dans le schéma. Ce qui est promis est tenu par la base, pas par du code qui pourrait oublier une
table.

**La fiche de confidentialité d'Apple a été corrigée aujourd'hui** : cinq types de données
manquaient, cinq étaient déclarés « non liés » alors que le manifeste les déclare liés, une
finalité était fausse. La 3.3, publiée le 3 novembre, était partie ainsi. C'est réparé, publié, et
gardé par un relevé daté.

**Ce qui manque encore.**

- Aucun écran ne présente un **consentement explicite et révocable** aux statistiques d'usage.
  La politique les décrit ; l'app ne les propose pas à refuser. C'est le point RGPD le plus
  discutable du produit.
- Les données du téléphone ne sont **pas chiffrées au repos** au-delà de ce que fait iOS. Pour le
  cycle, c'est à poser.

---

## 9. L'écart avec la direction artistique, mesuré

### Ce qui est conforme

| Point du brief | État |
| --- | --- |
| Chiffres tabulaires partout | **Fait**, imposé par le système de titrage |
| Intensités de séance à teinte fixe, indépendante du thème | **Fait** — et chaque famille porte AUSSI un symbole, pour les douze pour cent d'hommes qui distinguent mal le rouge du vert |
| Séance en plein écran, registre sombre forcé | **Fait** — un ensemble de jetons dédié tient tout l'écran en sombre |
| Chiffre géant en séance | **Fait** : 96 pt au décompte, 64 pt sur le temps |
| Zéro emoji pictographique | **Fait** (les seize badges en portaient, ils ont été remplacés par des symboles) |
| Haptique | `Haptics.swift` existe |
| Live Activity, widget, complication | Les trois existent |

### Ce qui ne l'est pas

| Point du brief | Ce que l'app fait | Écart |
| --- | --- | --- |
| **Une seule couleur d'accent RunUp** | **Huit thèmes d'accent au choix** dans Profil → Apparence | Structurel |
| Accent `#F0225F` | `#FF0A78` | Teinte proche, valeur différente |
| Fond de consultation `#FBF9F7` chaud | `#F4F3F8` froid, et **le sombre est le thème par défaut** | Direction inverse |
| Clair en consultation, sombre en séance, automatique | **La personne choisit son thème** ; seule la séance force le sombre | Modèle différent |
| Une seule famille typographique | **Deux** : Inter et DM Mono | Écart réel, défendable |
| Aucun dégradé dans l'interface | **22 fichiers** en contiennent, dont `ClubView`, `StatsView`, `SettingsView`, `TabBarView`, `HomeView` | Règle 7 enfreinte |
| Pas de glassmorphism | **7 fichiers** utilisent un `Material`, dont **la barre d'onglets** (`.ultraThinMaterial`) | Règle 7 enfreinte |
| Barre basse à trois entrées | Cinq, et le Club n'y est pas | Structurel |
| Inscription en trois questions | Dix-neuf écrans | Structurel |
| Un seul set d'icônes au trait 1,5 px (Phosphor/Lucide) | SF Symbols | Écart assumé, à trancher |
| Cycle `#F2B8A0` sur `#FDF1EC` | Aucun jeton de cycle dans le système | Absent |

**La montre est le cas le plus net** : son bouton de départ et ses anneaux de progression sont
peints avec un **dégradé rose → violet**, alors que les widgets et la Live Activity sont passés à
un rendu plat. C'est écrit dans son propre code : « matches the flat, no-gradient scoreboard
treatment the widgets and Live Activity moved to » — et la montre ne l'a pas suivi.

### Notes, et sur quoi elles reposent

Je note ce que j'ai regardé. Quand je n'ai vu que le code, je le dis : **un écran ne se juge pas
sans le voir**, et c'est la leçon de la journée.

| Domaine | Note | Base |
| --- | --- | --- |
| Système de jetons (structure) | **8/10** | Code. Complet, fermé, gardé par des contrôles. Il lui manque le cycle et il autorise huit accents. |
| Typographie | **7/10** | Code + deux captures. Échelle fermée, chiffres tabulaires, mais deux familles. |
| Accueil | **7/10** | **Vu** (sombre et clair). Hiérarchie claire, cartes justifiées, pas de bruit. Trop de cartes pour un « flux vertical unique ». |
| Séance en cours | **7/10** | Code seul. Les réglages sont les bons ; je n'ai pas vu l'écran. |
| Club | **5/10** | Code seul. 1 424 lignes dans un écran, et une recherche qui exige qu'on connaisse déjà un nom. |
| Inscription | **4/10** | Code seul. Dix-neuf écrans contre trois demandés. |
| Montre | **4/10** | **Vue**. L'écran est propre et lisible — et il porte le dégradé que la charte interdit. |
| Conformité à la règle 7 | **4/10** | Mesuré. 22 fichiers à dégradé, 7 à verre dépoli. |
| Fiche App Store | **6/10** | **Vue**. Les six captures iPhone sont belles et à jour ; l'iPad et la montre dataient d'août, corrigé aujourd'hui. |

---

## 10. Le head coach relit la logique

**Ce qui est juste, et sourcé.**

- **La progression de volume est plafonnée à +10 % par semaine, composé** sur un bloc entier —
  pas seulement d'une semaine à la suivante. Le code nomme le risque : fracture de fatigue,
  tendinopathie.
- **Une semaine de décharge toutes les quatre semaines**, et jamais deux fois sur un affûtage.
- **L'affûtage** fait 15 % de la durée du programme, borné à une semaine au minimum.
- **Le cycle menstruel a été corrigé contre la littérature.** L'app affirmait quatre choses que
  la meilleure synthèse disponible ne soutient pas : que la phase folliculaire est « le bon
  moment pour pousser » (alors que la folliculaire PRÉCOCE est la seule où une baisse est
  mesurée — donc l'inverse), un « pic de forme » à l'ovulation qui n'existe pas dans les données,
  une consigne lutéale non établie, et −15 % de durée sur toute la semaine menstruelle pour un
  effet que McNulty et al. (*Sports Medicine* 50(10):1813-1827, 2020 — 78 études) qualifient de
  trivial. C'est corrigé, avec la source dans le code.

**Ce que je ne peux pas valider.**

- **Le contenu des séances HYROX.** Il faut quelqu'un qui en a couru un. L'équipe n'a pas cette
  compétence et ne doit pas l'inventer. C'est le seul endroit du produit où je refuse de me
  prononcer.
- **Les allures cibles** par niveau et par famille de séance : la table existe, je ne l'ai pas
  confrontée à une méthode nommée. À faire avant de prétendre au niveau de Runna.

---

## 11. Ce qui empêche aujourd'hui de dire « zéro défaut »

Dans l'ordre de gravité, et rien de plus :

1. **Le GPS n'a jamais été mesuré en courant.** Ni la précision, ni la batterie, ni la reprise
   après une coupure. C'est le cœur du produit.
2. **Aucun consentement révocable aux statistiques d'usage.**
3. **Le mode hors ligne et la connexion lente ne sont pas éprouvés.**
4. **Le paiement n'a pas de test de parcours.**
5. **La règle 7 est enfreinte à 22 endroits** (dégradés) et 7 autres (verre dépoli).
6. **Le contenu HYROX n'est validé par personne.**

---

## 12. Ce que je n'ai pas fait

- Je n'ai **pas** ouvert les 111 écrans. J'ai vu l'accueil (deux thèmes), la montre, et la fiche
  App Store. Le reste est jugé sur le code, et c'est dit à chaque fois.
- Je n'ai **pas** lancé l'app : il n'y a pas de macOS ici. Tout ce qui se compile ou se
  photographie passe par la chaîne d'intégration.
- Je n'ai rien modifié **pendant l'état des lieux**. La seule exception est la section 13 : un
  défaut trouvé en voulant photographier la montre, que tu m'as dit de corriger avant de passer
  à la phase 2.

---

## 13. Le défaut trouvé en photographiant la montre — corrigé

### Ce qui n'allait pas

`project.yml` déclarait, sur **trois cibles**, les polices et le catalogue de traductions sous une
clé `resources:`. **Cette clé n'existe pas dans XcodeGen.** La documentation officielle
(`Docs/ProjectSpec.md` § Target) ne la liste pas parmi les clés d'une cible ;
`Target.init(jsonDictionary:)` n'a aucune branche pour elle ; `SourceGenerator.getAllSourceFiles`
ne regarde que `target.sources`. La valeur est donc lue puis jetée, **sans erreur ni
avertissement** — c'est le ticket XcodeGen #1645, ouvert et non corrigé (XcodeGen 2.46.0).

### Ce que ça coûtait, mesuré

Sonde du paquet construit `RunUpWatch.app` (workflow « Capture de la montre », commit `5cadd52`) :

| attendu dans le paquet | présent |
|---|---|
| `fr.lproj`, `en.lproj`, `es.lproj` | oui |
| `Localizable.strings` dans chacun | **non, aucun** |
| `Inter-Medium/Bold/SemiBold.ttf` | **non, aucun** |

Donc, **pour tout le monde et depuis le premier jour de la cible montre** :

- **la montre parlait français quelle que soit la langue du téléphone.** Chaque `Text("Courir")`
  retombait sur sa clé, qui est française et parfaitement lisible — c'est pour ça que rien ne se
  voyait ;
- **elle s'affichait dans la police système, pas en Inter**, malgré les trois fichiers enregistrés
  dans son `UIAppFonts`. Un `UIAppFonts` qui nomme un fichier absent du paquet ne lève rien :
  SwiftUI retombe sur la police système en silence.

**Le widget de l'écran d'accueil avait exactement le même défaut**, pour exactement la même
raison — ses deux ressources partagées sont hors de `RunUpWidgets/`. « BOUCLÉS », « SÉANCE »,
« KCAL » en français chez une anglophone, dans la police système, à côté d'une app correctement
traduite et correctement composée. Celui-là n'était pas cherché : c'est le garde-fou écrit pour la
montre qui l'a nommé.

L'app iPhone, elle, n'a jamais été touchée : son unique entrée `sources: - path: RunUp` contient
`RunUp/Resources/`, donc XcodeGen y trouvait tout. Sa clé `resources:` ne faisait rien non plus —
elle redéclarait ce qui entrait déjà. **Retirer cette clé ne peut donc pas changer le binaire
iPhone**, et c'est ce qui rend la correction sans risque de ce côté.

### Pourquoi rien ne l'a signalé

- **Le build était vert** : aucune ressource ne manque à la compilation.
- **`check_fonts.py` était vert, et il avait raison de l'être.** Il compare le code, l'`UIAppFonts`
  de chaque cible et les noms PostScript des fichiers. « Livrée » y veut dire « le fichier existe
  dans `RunUp/Resources/Fonts` », jamais « la cible l'embarque ». Ce n'était pas sa question.
- **Les captures de la montre montraient un écran français**, qu'on prenait pour la capture
  française.
- **Le commentaire de `project.yml` disait la chose au passé** : « sans lui, la montre restait
  entièrement en français ». La phrase décrivait une correction qui n'avait jamais eu lieu.
- **Et ma première sonde m'a fait annoncer le contraire.** Elle vérifiait que les trois dossiers
  `.lproj` existaient. Ils existaient. J'ai conclu que le paquet allait bien, et je l'ai écrit.
  La seconde sonde a regardé dedans : rien. J'avais mesuré le contenant.

### Ce qui est corrigé, et ce qui empêche le retour

1. **`project.yml`** : les trois clés `resources:` sont retirées. Les ressources partagées de la
   montre et du widget passent par `sources:` avec `buildPhase: resources` écrit explicitement —
   la seconde approche documentée sur le même ticket.
2. **`ci_scripts/check_spec.py`** (nouveau) refuse toute clé de cible ou d'entrée `sources:`
   absente des listes documentées, toute valeur inconnue de `buildPhase` et de `type`, **toute
   police enregistrée dans un `UIAppFonts` que sa cible n'embarque pas**, et **toute cible qui
   affiche du texte sans embarquer de catalogue de chaînes**. Lancé sur le `project.yml` d'avant,
   il sort 11 plaintes ; sur celui d'après, zéro.
3. Il lit le YAML **à la main**, parce que le python du runner macOS n'a pas PyYAML et que ce job
   n'installe rien — la décision est déjà écrite dans `check_cablage.py`, et ce script l'avait
   d'abord enfreinte. Un lecteur maison qui se trompe en silence serait pire que pas de contrôle,
   donc il **refuse** tout ce qu'il ne comprend pas, et `test_spec.py` **compare sa lecture du
   vrai `project.yml` à celle de PyYAML** partout où PyYAML existe. Cette comparaison a trouvé une
   faute dans mon lecteur dès le premier essai (`- applinks:runup-nu.vercel.app`, sans espace après
   le deux-points, lu comme une table au lieu d'une chaîne).
4. **La sonde de `montre.yml` est devenue un garde-fou** : elle exige un `Localizable.strings` dans
   chacune des trois langues, exige que « Courir » rende **trois valeurs différentes**, et exige
   que chaque police de l'`UIAppFonts` soit dans le paquet. 29 cas dans `test_spec.py`.

### Ce que la chaîne a rendu, une fois corrigé

Run 5 de « Capture de la montre », commit `a0d27d0`, vert de bout en bout. Dans le paquet :
`fr → Courir`, `en → Run`, `es → Correr`, et les trois Inter présentes. Les trois images ouvertes
une par une : « Aujourd'hui / Course libre / Courir », « Today / Free run / Run », « Hoy / Carrera
libre / Correr ». **23,6 % des pixels sous la barre d'état ont changé** par rapport à l'avant :
ce n'est pas seulement la langue, c'est le rendu.

`appstore/requis/montre/` porte maintenant trois images au lieu d'une, chacune avec l'empreinte de
sa source et celle du code qui l'a dessinée. L'entrée `source: null` qui portait « faite à la main,
et ne montre pas l'app » a disparu.

### Deux écarts avec la DA, vus sur cette image et NON corrigés

1. **Le bouton « Courir » est un dégradé rose → violet, en plein milieu de l'interface.** Règle 7 :
   pas de dégradés dans l'interface. DA : le dégradé rose-violet ne va que sur l'icône, le splash
   et le logo. L'accent d'action est `#F0225F`, plat. C'est l'élément principal de l'écran.
2. **La phrase du bas est coupée par le bord, dans les trois langues.** Aucune des trois ne finit.

Ce sont des décisions de design, pas de la livraison de ressources : elles attendent la phase 2.

### Ce que ça change pour la phase 2

Toutes les captures de montre prises jusqu'ici montrent une app dans la mauvaise police et dans
la mauvaise langue. **Elles ne valent rien comme référence de direction artistique** — la note
donnée à l'écran de course au poignet en section 9 a été mise sur une image qui n'était pas celle
de l'app. Elle est à refaire.

### Ce qui reste ouvert, et que je n'ai pas touché

- **`RunUpWatch` n'embarque aucun `PrivacyInfo.xcprivacy`**, là où l'app et le widget ont le leur.
  La cible montre n'appelle aucune API « à motif obligatoire » (ni `UserDefaults`, ni
  `FileManager`) et n'envoie rien au serveur elle-même, donc l'absence se défend. Mais je n'ai pas
  de source Apple qui dise si un paquet de montre embarqué doit porter le sien. **À trancher avant
  le prochain envoi**, pas à deviner.
- **Le widget ne déclare pas de `CFBundleLocalizations`.** Avec le catalogue désormais livré, ses
  `.lproj` suffisent en principe à faire découvrir ses langues. En principe : ça se mesure sur un
  appareil, et ça ne l'a pas été.
