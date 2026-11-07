# Où en est RunUp

Tenu par l'équipe produit et technique, mis à jour à chaque chantier terminé. Un chantier n'est
« terminé » que quand la construction est verte, les tests sont verts, aucun avertissement nouveau
n'apparaît, l'avant/après est écrit ici, et les trois langues ont été vérifiées.

## Ce qui a été décidé

| Décision | Qui | Quand |
| --- | --- | --- |
| iOS seul pour l'instant ; Android plus tard | Charlotte | 7 novembre 2026 |
| Régler tout ce que l'audit a relevé, sans exception | Charlotte | 7 novembre 2026 |
| Surveillance des plantages : **maison**, pas Sentry — le rapport part sur notre serveur Vercel, aucune dépendance Swift tierce | Charlotte | 7 novembre 2026 |

## Ce qui attend une décision

| Question | Pourquoi ça bloque |
| --- | --- |
| Contenu des séances HYROX | Il faut quelqu'un qui a couru un HYROX. L'équipe n'a pas cette compétence et ne doit pas l'inventer. |

## Au passage

**La version monte dès qu'une version est publiée.** Apple ferme le train d'une version publiée :
depuis la sortie de la 3.3 le 3 novembre 2026, tout envoi à TestFlight en 3.3 est refusé (90186 et
90062). Le défaut ne se voit qu'au DERNIER pas de la chaîne — construction verte, tests verts,
archive signée, puis refus — donc après dix minutes de machine macOS. `project.yml` est passé en
3.4, aux trois cibles.

## Les chantiers de l'audit

Dans l'ordre d'exécution. « Effort » est l'estimation d'origine.

| # | Chantier | Effort | État |
| --- | --- | --- | --- |
| 1 | Cycle : ovulation mal placée, phase du jour appliquée à la semaine, messages qui affirment | 1 j | **fait** |
| 2 | Activité en direct : dire pourquoi elle ne démarre pas | 2 h | **fait** |
| 3 | `@MainActor` sur `LocationService` et `RunWeatherService` | 3 h | à faire |
| 4 | Finitions design : 2 émojis dans l'interface, 2 dégradés, vert isolé du profil d'élévation, boutons gris en capitales, segment blanc sur blanc, contraste de la bulle du coach | 1 j | à faire |
| 5 | Données de démonstration : FC 148 seize fois, « Sortie » seize fois, défi « octobre » affiché en novembre | 4 h | à faire |
| 6 | Bilan de la semaine — l'écran noté 5,5/10 | 1,5 j | à faire |
| 7 | États manquants : chargement de Stats et du Coach, erreurs d'inscription | 1 j | à faire |
| 8 | Harnais de captures : photographier l'inscription, le paywall, l'écran de course | 0,5 j | à faire |
| 9 | Tests : `SubscriptionService` et `LocationService` d'abord | 2 j | à faire |
| 10 | Valeurs en dur → jetons du design system, les 15 % restants | 1,5 j | à faire |
| 11 | Dépendances serveur : `jose` 6 et `bcryptjs` 3 | 0,5 j | à faire |
| 12 | Accessibilité : tailles de texte dynamiques, indices VoiceOver | 1,5 j | à faire |
| 13 | `ClubView.swift`, 2 699 lignes, à découper | 2 j | à faire |
| 14 | Rapport de plantage maison, posté sur notre serveur | 1,5 j | à faire — décidé le 7 novembre |

Le 14 est arrivé après coup, et je le ferais passer devant les finitions de design : c'est le seul
moyen de savoir ce qui casse chez quelqu'un d'autre que nous. Le reste de l'ordre tient.

## Chantier 2 — l'activité en direct

### Ce qui était faux

`startLiveActivity` avait **deux sorties muettes** : un `guard` sur l'interrupteur du système et
un `try?` sur la demande. Les deux rendaient exactement le même écran — l'écran de course
ordinaire — et la coureuse qui verrouillait son téléphone n'y trouvait rien. Ni elle ni nous ne
pouvions distinguer « l'interrupteur des Réglages est éteint » de « ActivityKit a refusé » de
« tout va bien ». Le défaut a coûté une recherche entière : l'absence d'affichage sur l'écran
verrouillé a été prise pour un bug de l'app alors que la case « Activités en direct » était
simplement décochée dans les Réglages du téléphone.

### Ce qui a changé

| | Avant | Après |
| --- | --- | --- |
| Interrupteur éteint | rien | bandeau sur l'écran de course, 45 s, qui ouvre les Réglages |
| Refus d'ActivityKit | rien | bandeau qui dit ce qui est perdu, sans envoyer nulle part |
| Trace durable | aucune | une ligne d'état dans Réglages → Course, suivie en continu |

Les deux causes restent **distinctes** et non un seul « indisponible » : l'une se répare en deux
touches, l'autre ne se répare pas. Les confondre enverrait la coureuse chercher une case qui
n'existe pas. Le bandeau du GPS passe devant celui-ci : il parle de la course, qui est en train de
ne pas être enregistrée.

### Trouvé en travaillant dessus

`bannerBody(icon:text:)` prenait un `String`, donc `Text(text)` **ne consultait jamais le
catalogue**. Les trois avertissements GPS de l'écran de course sortaient en français en anglais et
en espagnol — alors qu'ils y sont, traduits, depuis le début. Quelqu'un avait fait le travail de
traduction et le paramètre le jetait. Dont « Localisation refusée — ouvrir les Réglages » : la
phrase qu'on lit au moment précis où l'app a l'air cassée.

Mesuré ensuite sur tout le dépôt, pour savoir si c'était un cas ou une classe : 48 méthodes
rendent un paramètre `String` par `Text(…)`, et **4 seulement** reçoivent un littéral — `min`,
`km`, des symboles d'unité identiques dans les trois langues. La classe est fermée, le bandeau en
était le seul vrai cas.

Un premier jet de ce scan indexait les méthodes par NOM seulement et a rapporté 21 défauts, dont
17 appartenaient à la méthode d'un autre écran : `HomeView.statTile` fait déjà
`Text(LocalizedStringKey(label))`. Il a fallu ouvrir le fichier pour le voir.

### Ce qui le garde

`check_strings.py` gagne une sixième règle : tout littéral confié à un paramètre de **méthode**
typé `LocalizedStringKey` est réclamé au catalogue. Les cinq rangs précédents ne regardaient que
les initialiseurs de composants, alors que la méthode privée est la forme la plus courante du
dépôt. Aucun faux positif possible — c'est le type du paramètre, pas son nom, qui le dit — et la
règle est scellée au fichier, pour la raison qu'on vient de voir. Trois cas de plus dans
`test_strings.py` (28/28).

## Chantier 1 — le suivi du cycle

### Ce qui était faux

1. **L'ovulation était posée au milieu du cycle** (`length / 2`). C'est la phase lutéale — de
   l'ovulation aux règles suivantes — qui dure à peu près toujours quatorze jours ; c'est la phase
   folliculaire qui varie. Le milieu tombe juste pour vingt-huit jours et faux partout ailleurs :
   trois jours trop tard sur un cycle de 21 jours, quatre jours trop tôt sur un cycle de 35.
   L'erreur grandissait en s'éloignant de vingt-huit jours, donc elle frappait exactement celles
   dont le cycle n'est pas celui du manuel.
2. **La phase du jour était recopiée sur les sept jours de la semaine** — et sur toutes les
   semaines suivantes du plan, que l'écran du plan prévisualise. Une semaine entière pouvait
   s'annoncer « phase menstruelle » alors que les règles finissaient le mardi.
3. **L'heure de la saisie décalait le cycle d'un jour.** `dateComponents([.day])` tronque : des
   règles enregistrées à 23 h et un jour de séance qui vaut minuit étaient séparés de « −1 jour »,
   donc aucune adaptation le jour même de la saisie.
4. **Quatre messages affirmaient des effets que la littérature ne soutient pas** : « bon moment
   pour pousser » en phase folliculaire, « pic de forme estimé » à l'ovulation, un ressenti plus
   dur en phase lutéale, et 15 % de durée en moins sur **toute** la semaine menstruelle — footing
   et sortie longue comprises.
5. La note de phase **écrasait** celle de la blessure : une séance raccourcie de 30 % pour un genou
   sensible s'annonçait « phase lutéale estimée ».

### La source

McNulty KL, Elliott-Sale KJ, Dolan E, Swinton PA, Ansdell P, Goodall S, Thomas K, Hicks KM.
« The Effects of Menstrual Cycle Phase on Exercise Performance in Eumenorrheic Women: A Systematic
Review and Meta-Analysis. » *Sports Medicine* 50(10) : 1813-1827, 2020.

Soixante-dix-huit études. Effet de groupe **trivial** (taille d'effet de l'ordre de −0,06), qualité
de preuve **faible**, recommandation explicite d'une **approche individuelle**. Le seul effet retenu
est une légère baisse de performance en phase folliculaire précoce — c'est-à-dire autour des règles.

### Ce qui a changé

| | Avant | Après |
| --- | --- | --- |
| Jour de l'ovulation | `durée / 2` | `durée − 14` |
| Phase lue | une fois, le jour d'ouverture de l'app | pour chaque jour de séance, à sa vraie date |
| Semaine menstruelle | −15 % sur les sept jours, sortie longue comprise | −10 % sur la seule séance de qualité |
| Phase lutéale | −8 % sur la séance de qualité | rien |
| Folliculaire, ovulation | « bon moment pour pousser », « pic de forme estimé » | la phase estimée, et le renvoi au ressenti |
| Note de blessure | écrasée par la phase | conservée ; le cycle se tait |

Les quatre nouvelles notes sont au catalogue dans les trois langues. Les quatre anciennes y restent
volontairement : une semaine déjà enregistrée les porte encore, et les retirer les ferait ressortir
en français chez une anglophone jusqu'à la régénération du lundi suivant.

### Ce qui le garde

`RunUpTests/CycleTrackingTests.swift`, sept nouveaux tests : le jour d'ovulation sur des cycles de
21, 28 et 35 jours ; la phase calculée pour un autre jour qu'aujourd'hui ; l'heure de saisie qui ne
décale plus rien ; chaque note qui correspond à la phase de son propre jour ; la sortie longue qui
ne dépend plus de la phase ; une semaine hors règles identique à celle de quelqu'un qui ne suit pas
son cycle ; la note de blessure qui survit.
