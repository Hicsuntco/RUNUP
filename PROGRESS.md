# Où en est RunUp

Tenu par l'équipe produit et technique, mis à jour à chaque chantier terminé. Un chantier n'est
« terminé » que quand la construction est verte, les tests sont verts, aucun avertissement nouveau
n'apparaît, l'avant/après est écrit ici, et les trois langues ont été vérifiées.

## Ce qui a été décidé

| Décision | Qui | Quand |
| --- | --- | --- |
| iOS seul pour l'instant ; Android plus tard | Charlotte | 7 novembre 2026 |
| Régler tout ce que l'audit a relevé, sans exception | Charlotte | 7 novembre 2026 |

## Ce qui attend une décision

| Question | Pourquoi ça bloque |
| --- | --- |
| Surveillance des plantages : Sentry, ou maison ? | Aucune dépendance Swift tierce dans le projet aujourd'hui. Sentry est un paquet SPM, donc la première ; « maison » veut dire poster le rapport sur notre propre serveur Vercel, moins complet et à écrire. Sans l'un des deux, un plantage chez une utilisatrice reste invisible. |
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
| 2 | Activité en direct : dire pourquoi elle ne démarre pas | 2 h | à faire |
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
