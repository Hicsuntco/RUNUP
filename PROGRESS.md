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
| « ABONNÉ » → le libellé dit l'action (« SE DÉSABONNER ») | Charlotte | 7 novembre 2026 |
| « RETIRER » → une confirmation, pas un poids visuel différent | Charlotte | 7 novembre 2026 |

## Ce qui attend une décision

| Question | Pourquoi ça bloque |
| --- | --- |
| Contenu des séances HYROX | Il faut quelqu'un qui a couru un HYROX. L'équipe n'a pas cette compétence et ne doit pas l'inventer. |
| Cette branche doit-elle être la production ? | Elle l'est : douze déploiements « Production » le 7 novembre, un par commit. Donc aucune relecture, aucune préproduction, et une panne de onze minutes ce jour-là. |
| La version de Node du projet Vercel | Elle ne se lit que dans les paramètres du projet, et c'est la seule chose qui manque pour reprendre le chantier 11. Un `require` d'un paquet ESM en dépend, et une construction verte n'en dit rien. |
| Le chevron « ‹ » des deux boutons de retour | `BackChevronButton` et `FrostedBackButton` dessinent un signe typographique à taille figée là où le reste de l'app emploie `chevron.left`. C'est un choix de dessin, pas un défaut : à trancher. |

## Au passage

**La version monte dès qu'une version est publiée.** Apple ferme le train d'une version publiée :
depuis la sortie de la 3.3 le 3 novembre 2026, tout envoi à TestFlight en 3.3 est refusé (90186 et
90062). Le défaut ne se voit qu'au DERNIER pas de la chaîne — construction verte, tests verts,
archive signée, puis refus — donc après dix minutes de machine macOS. `project.yml` est passé en
3.4, aux trois cibles.

**Un attribut séparé de sa déclaration par une documentation change de propriétaire.** Swift
l'accepte sans rien dire, et l'attribut s'applique à la déclaration SUIVANTE. En extrayant
`viderLeStock` de `poser`, je l'ai posée entre les attributs de `poser` et sa déclaration :
`@MainActor` s'est recollé sur `viderLeStock`, `poser` a perdu son isolation, et la construction
des captures est morte — quarante minutes plus tard, parce qu'ici il n'y a pas de compilateur.
C'était la deuxième fois : `AdaptivePlanEngine.swift` porte déjà le récit d'un
`@discardableResult` resté douze fonctions plus haut. `ci_scripts/check_attributs.py` relit les
281 fichiers Swift du dépôt et refuse ce motif ; il a trouvé un TROISIÈME cas le jour où il a été
écrit (`ClubService.swift` : la documentation de `setRoutePhoto` avait glissé sur
`setActivityPhoto`, avec son attribut). Son premier jet listait « RunUpWidget » au singulier — un
dossier qui n'existe pas, et `rglob` sur un chemin absent ne rend rien, sans rien dire : le
contrôle couvrait le widget en apparence. Il exige maintenant que chaque dossier existe.

**Un garde-fou qui juge une image doit garder l'image.** Le contrôle de découpage du film
d'aperçu a dit « ce plan vise le coach et montre les stats » sur l'espagnol — une langue sur
trois, le français et l'anglais verts dans la même exécution. Il ne restait rien à regarder : le
dossier de travail est temporaire, l'enregistrement brut n'est plus publié, et la comparaison
porte sur un gris réduit à 258 pixels. Deux explications se calculent et tombent toutes les deux :
un décalage uniforme de +3,1 s mettrait aussi le plan du profil sur l'accueil (il est reconnu), et
une dérive d'horloge assez forte pour égarer le coach égarerait le profil davantage. Les quatre
témoins espagnols, eux, sont nets — le plus proche voisin est à 20,7 d'écart. Donc : non élucidé.
`bascules.py --preuves` garde désormais l'image de l'instant jugé, pleine taille et en couleurs,
et l'artefact la publie — seulement quand le verdict est mauvais.

**CETTE BRANCHE DE TRAVAIL EST LA PRODUCTION.** Découvert le 7 novembre à 17 h 20, dans
l'incident ci-dessous. `main` n'a pas bougé depuis le 24 octobre et ne contient même pas
`api/races/`, pourtant les routes `api/races/*` répondaient normalement en production. La preuve
est dans les déploiements que Vercel enregistre sur GitHub : **douze déploiements
« Production » le 7 novembre, un par commit de cette branche**. Chaque poussée qui touche `api/`,
`lib/` ou `package.json` part donc EN LIGNE, tout de suite, chez les gens qui ont l'app. Il n'y a
pas d'étape de préproduction, et il n'y a pas de relecture. À décider : est-ce voulu ?

**La porte de sortie est écrite : [RELEASE.md](RELEASE.md).** Ce que les quatre chaînes
garantissent et ce qu'elles ne garantissent pas, les quatre questions qu'aucune machine ne pose,
les commandes à lancer dans l'ordre, et la liste honnête de ce qui n'est tenu par aucune barrière.

## Les chantiers de l'audit

Dans l'ordre d'exécution. « Effort » est l'estimation d'origine.

| # | Chantier | Effort | État |
| --- | --- | --- | --- |
| 1 | Cycle : ovulation mal placée, phase du jour appliquée à la semaine, messages qui affirment | 1 j | **fait** |
| 2 | Activité en direct : dire pourquoi elle ne démarre pas | 2 h | **fait** |
| 3 | `@MainActor` sur `LocationService` et `RunWeatherService` | 3 h | **fait** |
| 4 | Finitions design : 2 émojis dans l'interface, 2 dégradés, vert isolé du profil d'élévation, boutons gris en capitales, segment blanc sur blanc, contraste de la bulle du coach | 1 j | **fait** |
| 5 | Données de démonstration : FC 148 seize fois, « Sortie » seize fois, défi « octobre » affiché en novembre | 4 h | **fait** |
| 6 | Bilan de la semaine — l'écran noté 5,5/10 | 1,5 j | **fait** |
| 7 | États manquants : chargement de Stats et du Coach, erreurs d'inscription | 1 j | **fait** — l'item était faux |
| 8 | Harnais de captures : photographier l'inscription, le paywall, l'écran de course | 0,5 j | **fait** |
| 9 | Tests : `SubscriptionService` et `LocationService` d'abord | 2 j | **fait** |
| 10 | Valeurs en dur → jetons du design system, les 15 % restants | 1,5 j | **fait** — il en restait six, pas 15 % |
| 11 | Dépendances serveur : `jose` 6 et `bcryptjs` 3 | 0,5 j | **annulé le 7 novembre** — `jose` 6 a mis la production à terre, voir plus bas |
| 12 | Accessibilité : tailles de texte dynamiques, indices VoiceOver | 1,5 j | à faire |
| 13 | `ClubView.swift`, 2 699 lignes, à découper | 2 j | à faire |
| 14 | Rapport de plantage maison, posté sur notre serveur | 1,5 j | à faire — décidé le 7 novembre |

Le 14 est arrivé après coup, et je le ferais passer devant les finitions de design : c'est le seul
moyen de savoir ce qui casse chez quelqu'un d'autre que nous. Le reste de l'ordre tient.

## La page publique d'un club, regardée pour la première fois

`public/club.html` est la seule surface de RUNUP qu'un inconnu voit **avant** d'avoir l'app :
c'est le lien qu'un crew met dans sa bio. Les vingt-cinq écrans de l'app sont photographiés à
chaque commit, dans trois langues et deux thèmes. Celle-ci, jamais.

### Ce qu'on voyait en l'ouvrant

1. **Le bouton ne menait nulle part.** « Rejoindre sur RUNUP » pointait sur `location.href`,
   c'est-à-dire sur la page elle-même. Sur un iPhone où l'app est installée, iOS ouvre le lien
   dans l'app AVANT que la page ne s'affiche — personne de ce côté-là ne voyait jamais ce bouton.
   Pour tous les autres, c'est-à-dire exactement le public de cette page, il rechargeait la page.
   Il mène à l'App Store (`id6790719663`, relevé par `itunes.apple.com/lookup` sur l'identifiant
   de l'app, pas recopié de mémoire).
2. **L'état d'erreur était un cul-de-sac** : une phrase grise sur fond noir, sans marque, sans
   issue. Un lien mort dans une bio tombait sur une page qui n'appartenait visiblement à rien.
3. **Tout était en français**, alors que l'app est livrée en trois langues. Les textes suivent
   maintenant le navigateur et reprennent mot pour mot ceux du catalogue de l'app : « %lld au
   départ » → « %lld going » / « %lld en la salida », « CHAQUE SEMAINE » → « EVERY WEEK » /
   « CADA SEMANA ».

La marque de l'app est maintenant en tête de page, dans les deux états — les quatre barres de
`AppMarkView`, mêmes coordonnées, mêmes graisses, mêmes opacités, recopiées en SVG depuis le
code et non à l'œil.

### Et l'échappement ne couvrait pas les attributs

`echappe` passait par `textContent` → `innerHTML`, qui n'échappe que `&`, `<` et `>`. Dans le
contenu d'un élément, c'est suffisant. Dans un **attribut** — le `src` de la couverture — une
valeur contenant un guillemet droit sort de l'attribut et en ouvre un autre : `onerror`, par
exemple. Rien n'était exploitable aujourd'hui (le serveur n'écrit dans `cover_url` que des URL de
stockage qu'il fabrique lui-même), et il suffisait d'une route acceptant une URL fournie par le
client pour que ça le devienne. Les guillemets sont échappés.

### Ce qui l'empêche de recommencer

`.github/workflows/page-club.yml` : sept cas — trois langues, l'état normal, l'état
« introuvable », un club d'une seule personne, et une couverture piégée — photographiés sur une
machine Linux en une minute. Il refuse une erreur JavaScript, une page sans bouton, un bouton qui
ne mène pas à l'App Store, et un échappement qui laisse une valeur sortir de son attribut.
Éprouvé dans les deux sens : sur la page corrigée il passe, sur une copie dont on a retiré
l'échappement des guillemets il échoue en nommant les deux symptômes.

Le reste ne se juge pas tout seul : les sept images partent dans l'artefact, et quelqu'un les
ouvre.

## Chantier 12 — l'app en grand texte, enfin photographiée

Commencé par la mesure, et la mesure a corrigé l'item de l'audit.

### Ce que l'audit disait, et ce que le code dit

« Tailles de texte dynamiques » : c'est **déjà fait pour le texte**. `RUFont` fait passer chaque
taille dessinée par `scaled(_:)`, qui lit le réglage iOS et plafonne à 2,0 ×. Sur les 174 appels
à `.font(.system(size:))` du dépôt — le seul chemin qui contourne ce système — **167 portent une
icône** et **4 portent du texte** : les deux chevrons « ‹ » des boutons de retour, le repli qui
affiche l'emoji d'une notification déjà enregistrée, et la coche typographique de l'assistant
d'objectif. Les trois derniers sont des glyphes dans un cadre, et c'est justifié.

### Ce qui reste vraiment : les icônes

**170 icônes à taille figée, sur 22 valeurs différentes de 8 à 72 points** — dont 13, 14 et 15 pt
voisinant sur 76 appels. C'est le même défaut que l'échelle de titrage avant `RUDisplaySize` :
personne n'a décidé ces tailles, chaque écran a été réglé à l'œil puis recopié. Et aucune ne suit
le réglage de taille du texte : à AX2, le texte grandit de 94 % et les icônes qui l'accompagnent
restent où elles sont.

Classées par ce qui les contient : **97 à côté d'un texte** (elles doivent grandir avec lui),
**60 dans un cadre chiffré** (les faire grandir les ferait déborder), 15 ni l'un ni l'autre.

### Mais d'abord : regarder l'app en grand texte

Le plafond de `RUFont` est passé de 1,6 × à 2,0 × sur la foi d'un travail de réorganisation —
rangées de mesures qui passent en colonne, bande des sept jours qui laisse tomber le quantième,
barre d'onglets qui laisse tomber ses libellés. Tout cela est **écrit, commenté, et n'a jamais été
photographié**. C'est exactement la forme de défaut que cette journée a trouvée quatre fois.

Quatre captures nouvelles, au deuxième cran d'accessibilité (AX2, ≈1,94 ×, le plus grand que le
plafond couvre en entier) : l'accueil, les statistiques, la course en cours, le bilan de la
semaine — les quatre endroits où un texte deux fois plus grand n'a nulle part où aller. Le
réglage arrive par `-UIPreferredContentSizeCategoryName`, le même chemin que la langue.

Et `check_grand_texte.py` mesure l'écart entre chaque capture et son ordinaire : si le drapeau
cessait d'être lu, les quatre images seraient des copies, le harnais resterait vert, et on
croirait avoir vu l'app en grand texte. **Sans plancher pour l'instant** — il viendra du premier
relevé, comme le plafond d'images vides des bascules.

## Chantier 11 — `jose` 6 : onze minutes de production à terre

**Annulé.** `jose` 5.9.6 → 6.2.15 et `bcryptjs` 2.4.3 → 3.0.3 sont partis à 17 h 08 et sont
revenus à 17 h 20. Entre les deux, **toutes les routes de l'API répondaient 500**.

### La chronologie, mesurée

| Heure (UTC) | Ce qui s'est passé |
| --- | --- |
| 17 h 00 | Les 83 adresses appelées par l'app : 69 × 401, 13 × 405, 1 × 400. Rien de cassé. |
| 17 h 08 | Je pousse `jose` 6 et `bcryptjs` 3. |
| 17 h 09 min 48 | Vercel déploie le commit **en production**, construction verte. |
| 17 h 15 → 17 h 19 | Toutes les routes répondent 500, `x-vercel-error: FUNCTION_INVOCATION_FAILED`, sur quatre sondages. Les pages statiques servent. Vercel annonce « All Systems Operational ». |
| 17 h 20 min 28 | Je pousse le retour arrière. |
| 17 h 20 min 50 | Vercel le déploie en production. |
| 17 h 20 min 59 | `api/events` répond de nouveau 405. Les 83 routes sont revenues. |

### Ce que j'ai fait de travers

`jose` 6 n'est livré qu'en ESM, et tout le serveur est en CommonJS. Son README dit que
`require('jose')` ne marche que là où `require(esm)` est actif par défaut
(^20.19 || ^22.12 || >= 23). J'ai vérifié ce que Vercel **propose** — 26.x par défaut, 24.x,
22.x, la 20.x retirée depuis le 1er octobre 2026 — et j'en ai conclu que le plancher était tenu
quelle que soit la configuration du projet.

**Ce que Vercel propose à la sélection n'est pas ce sur quoi un projet existant tourne.** Le
réglage vit dans les paramètres du projet, chez Vercel, et je n'ai aucun moyen de le lire d'ici.
J'ai pris une liste de versions disponibles pour une mesure de la version déployée. Une
construction verte ne prouve rien là-dessus : le chargement des modules se fait à l'exécution.

`FUNCTION_INVOCATION_FAILED` sur une fonction qui ne touche que `lib/db` (`api/events`) m'a
d'abord fait écarter `jose` — à tort : toutes les fonctions partagent le même conteneur de
construction, et c'est `api/auth` qui porte l'import. Je n'ai pas poussé le diagnostic plus loin
avant de revenir en arrière, et c'était le bon ordre.

### Ce qui reste, et qui a fait son travail

`check_deploiement.py` refusait un 404 et comptait un 5xx comme une présence. Je l'ai corrigée au
même commit pour qu'un 5xx échoue, sur un relevé des 83 adresses. **Elle a trouvé cette panne
vingt minutes plus tard** — c'est le seul contrôle du dépôt capable de la voir, et sans elle la
production serait restée à terre jusqu'à ce que quelqu'un ouvre l'app.

Trois fichiers de tests ne tournaient nulle part non plus : `test_deploiement.py`,
`test_accent.py`, `test_session.py`. Ils sont dans leurs workflows, et l'audit est refait sur les
26 fichiers `ci_scripts/test_*.py`.

### La barrière qui empêche de le refaire

`ci_scripts/check_cjs.py` lit, pour chaque `require('paquet')` de `api/` et `lib/`, le
`package.json` du paquet installé : `"type": "module"` avec un `exports` qui ne propose aucune
condition `require` est refusé. La règle n'est pas « est-ce que ça marche sur cette machine » —
c'est précisément ce qui a trompé : Node 22 fait marcher `require('jose')`, et la version de Node
qui exécute les fonctions ne se lit pas d'ici.

Vérifié dans les deux sens : `jose` 5.10.0 et `bcryptjs` 2.4.3 passent, `jose` 6.2.15 est refusée
en nommant `lib/auth.js` et `lib/apns.js`. Et `bcryptjs` 3 passerait : elle garde une condition
`require` vers une livraison UMD — c'est la différence exacte entre les deux montées, et c'est
celle que je n'avais pas regardée.

### Ce qu'il faut pour reprendre ce chantier

Une seule chose : **la version de Node du projet Vercel** (Settings → General → Node.js Version).
Au-dessus de 20.19, `jose` 6 passe tel quel et la montée prend deux minutes. En dessous, il faut
soit monter le projet, soit convertir les trois fichiers concernés en `await import('jose')`.
`bcryptjs` 3, lui, est mesuré et sans risque : la 2.4.3 écrit `$2a$`, la 3.0.3 écrit `$2b$`, et
chacune vérifie l'empreinte de l'autre — les mots de passe en base passent, dans les deux sens.

## Chantier 10 — les valeurs en dur : six, pas 15 %

Trois barrières en gardent déjà une partie (`check_grille.py`, `check_teintes.py`,
`check_contraste.py`), donc j'ai mesuré les deux classes qu'elles ne couvrent pas.

### Les couleurs écrites à la main

Vingt-et-une occurrences dans les vues, dont la plupart sont des palettes locales **assumées et
documentées** : `Ink` (l'écran de course reste sombre dans les deux thèmes), la carte de partage et
le cadre vidéo (de l'identité de marque, pas de l'interface), l'orange de Strava, et une variable.

Quatre étaient de vrais défauts :

1. **Le dégradé du tracé était écrit deux fois** — dont une dans `RUColor.traceBackground`. Et le
   commentaire de ce jeton **prédit le défaut mot pour mot** : « il vivait en privé dans
   `ActivityFeedRow`, parce qu'un seul écran en avait besoin […] une deuxième copie aurait divergé
   au premier réglage — c'est exactement ce qui est arrivé aux dix rayons et aux dix-neuf écarts ».
   `ActivityDetailView` **était** cette deuxième copie, trois lignes sous un commentaire qui
   renvoie au fil.
2. **`0x0A0A0E`**, le fond de l'écran de course, écrit en dur à son unique point d'usage — à quatre
   centièmes de bleu près de `Ink.fond`. Deux noirs presque identiques écrits à la main sont la
   façon exacte dont on obtient, un jour, deux noirs visiblement différents. Il s'appelle
   `Ink.ecran`.
3. **`0xFFD79A`**, l'ambre lisible des bandeaux. La raison de l'épingler est écrite depuis
   longtemps en tête du fichier ; seule la valeur traînait en dur, soixante lignes plus loin que
   son explication. Elle s'appelle `Ink.amberTexte`.
4. **`0x0A0A0A`** contre `0x0A0A0E` : l'encre des commandes posées sur un disque blanc, à quatre
   centièmes du fond de l'écran. L'écart n'a aucune raison d'être, et c'est tout l'argument pour
   le nommer. `Ink.surBlanc`.

### Les tailles de police

178 emplois de `.font(.system(size:))`, et **162 sont du dimensionnement de symboles** — ce qui est
légitime : un symbole SF se mesure en points, `RUFont` est une échelle de TEXTE. Des quinze autres,
treize sont des icônes que mon premier classifieur avait manquées, et deux sont des glyphes
typographiques assumés (la coche, l'emoji d'une notification déjà posée sur l'appareil).

### La trouvaille que je n'ai pas changée

`BackChevronButton` et `FrostedBackButton` — les deux boutons « retour » de l'app — dessinent leur
chevron avec le **caractère** `‹` (U+2039, un guillemet simple) sizé en points, là où tout le reste
de l'app utilise `chevron.left`. Un caractère tiré de la police système ne suit ni la graisse ni la
couleur comme un symbole, et il ne s'accordera jamais avec les `chevron.right` des lignes voisines :
l'app a donc un chevron gauche dessiné d'une façon et un chevron droit d'une autre. C'est le même
argument que celui qui a fait retirer les émojis.

Je ne l'ai pas changé parce que ça touche le bouton retour de **chaque** écran et que je ne peux pas
voir le résultat avant de pousser. Le harnais photographie vingt-et-un écrans : la bonne façon de le
faire est de le changer et de regarder.

## Chantier 9 — les tests qui manquaient vraiment

`SubscriptionService` était **déjà couvert, et bien** : sa décision vit dans `Entitlement`, sous
test, avec une table de vérité complète et un commentaire qui dit de quel côté la règle penche
quand elle ne sait pas. Ses deux autres sorties ont leurs fichiers. Le reste est de la plomberie
StoreKit — un test unitaire n'y vérifierait pas notre code, il vérifierait Apple.

Le vrai trou était **`LocationService.consomme`**, qui décide la distance de chaque course. Trois
règles longuement expliquées dans le code et éprouvées par rien, parce qu'elles étaient
inatteignables depuis l'extérieur du fichier : le plancher de bruit (né d'un défaut mesuré : **+2 km
sur une course de 4 km**), le saut à plus de 12 m/s, le seuil de confiance à 65 mètres. Les trois se
trompent **en silence**.

Treize tests. Et l'un d'eux m'a pris en flagrant délit : j'avais écrit l'invariant juste dans un
test et **son contraire huit lignes plus bas**. Le plancher de bruit ne met pas à jour
`lastLocation`, donc les pas écartés s'additionnent — un signal flou perd une fenêtre de
comparaison, pas le trajet. Douze tests sur treize passaient ; c'est la construction qui m'a dit
lequel des deux mentait, et c'était le mien.

## Chantier 8 — les trois écrans que personne ne revoit

L'inscription, parce qu'on ne s'inscrit qu'une fois. Le mur d'abonnement, parce qu'on est abonné et
qu'`introShown` s'en souvient pour toujours. L'écran de course, parce qu'on le regarde en courant.
Les trois écrans les plus décisifs de l'app, et les trois qu'aucune capture n'avait jamais montrés
— donc les trois qu'on jugeait de mémoire. Le dépôt écrit cette phrase trois fois déjà.

- **`--inscription`** est le seul des trois à demander un drapeau **de moins** : `onboarded` vaut
  `false` à la création, donc il suffit de ne pas poser la graine. Le mode démonstration reste
  allumé — c'est lui qui coupe le réseau et Santé.
- **`--paywall`** contourne `introShown` sans y toucher, donc il ne consomme pas la présentation
  réelle.
- **`--encours`** démarre une vraie course.

### Le piège de l'écran de course

`demarrer()` appelle `location.requestAuthorization()` : une **boîte de dialogue système** se
serait posée sur la capture — au mieux une image de la boîte, au pire trente secondes d'attente
suivies d'un écran qu'on n'a pas vu. La demande est maintenant gardée par `Demonstration.enCours`,
comme huit autres endroits du dépôt, et c'est juste au-delà du harnais : une construction dont le
profil et le club sont inventés et dont le réseau est coupé n'a aucune raison de réclamer la
position de quelqu'un.

Le micro et les notifications, vérifiés aussi, ne se demandent qu'au **geste** — pas à l'apparition.

### Ce que la capture montrera, et ce qu'elle ne montrera pas

**Pas de distance.** Le simulateur n'a pas de signal GPS : 0,00 km et le bandeau « Recherche du
signal GPS… ». C'est l'état des premières secondes de chaque vraie course, et c'est tout ce qu'on
vient regarder — la disposition, le panneau de mesures, les commandes, la place de la bulle du
coach, et le bandeau lui-même. Attendre d'avoir un GPS simulé pour photographier cet écran
reviendrait à ne jamais le photographier.

## Chantier 7 — les états manquants, qui ne manquaient pas

Les **trois** affirmations de l'item sont fausses, et je les ai vérifiées une par une.

- **Chargement de Stats** : l'écran n'a aucun appel réseau. Son `@Query` SwiftData est synchrone,
  et son unique `.task` compte des tracés en mémoire. Il n'y a rien à attendre, donc rien à
  annoncer.
- **Chargement du Coach** : l'indicateur de frappe existe, animé, avec son `reduceMotion`.
- **Erreurs d'inscription** : `SignInView` distingue **deux 409 différents** (« cette adresse a
  déjà un compte avec mot de passe » et « un compte existe déjà »), le 401, le 422, et retombe sur
  `PanneReseau.phrase` pour le reste. Le Coach fait pareil : un refus du modèle et une panne réseau
  demandent deux choses différentes, et il les dit différemment.

### Le balayage que l'item aurait dû faire

Quinze écrans appellent le réseau. Pour chacun : annonce-t-il qu'il charge, dit-il quand il échoue,
dit-il quand il est vide ? **Les quinze ont leurs états.** Mon scan en a d'abord signalé quatre
comme incomplets, et les quatre étaient des faux positifs : il cherchait `isLoading` alors que ce
dépôt écrit `saving`, `isPublishing`, `enCours`. Quatre sur quatre — la même erreur de clé de
recherche que trois fois aujourd'hui.

**Pas de barrière d'intégration continue pour cette règle**, et c'est un choix : un contrôle dont le
premier jet produit 100 % de faux positifs finirait désactivé, et on perdrait les barrières qui
marchent avec celle qui ne marche pas. C'est l'argument que `check_strings.py` écrit lui-même au
sujet de sa cinquième zone aveugle.

### Le seul vrai trou, et il n'était pas dans la liste

Les deux feuilles qui joignent une photo. Après avoir choisi l'image, le bouton affichait toujours
« Ajouter une photo » pendant tout le décodage, le redimensionnement et l'encodage — une à deux
secondes sur une photo de douze mégapixels, pendant lesquelles l'écran ne bouge pas. Le geste
naturel est alors d'appuyer une seconde fois.

Et les trois `guard` sortaient **en silence** : une photo restée sur iCloud, un format que `UIImage`
ne sait pas lire, un encodage qui échoue — rien ne se passait et rien ne le disait. Exactement le
défaut du chantier 2, sur un autre écran. Le bouton annonce la préparation et se désactive pendant,
et chaque échec a sa phrase.

## Chantier 6 — le bilan de la semaine

Mon audit avait noté cet écran 5,5/10 sans dire pourquoi. En le lisant, la raison est nette et
elle est unique : **cinq définitions différentes de « la semaine »**, dans cinq propriétés privées
d'une vue SwiftUI — donc aucune vérifiable, et deux qui se contredisaient sur le même écran.

| Ce qui était affiché | Ce qui était compté | Ce qui aurait dû l'être |
| --- | --- | --- |
| « Parcourus » | à pied | à pied |
| « Volume par jour (km) » | **toutes disciplines** | à pied |
| « Ta meilleure semaine » | à pied cette semaine **vs toutes** les autres | à pied des deux côtés |
| « Nouveau record d'allure » | **toutes** cette semaine vs course avant | course des deux côtés |
| « Temps actif » | **à pied seulement** | toutes disciplines |
| « Séances » | toutes, sans que ce soit écrit | toutes, écrit |

### Le plus grave

`avgPace` est stocké en secondes au kilomètre pour **toutes** les disciplines. Une sortie à vélo à
20 km/h vaut donc 180 s/km, ce qui bat n'importe quelle allure de course à pied. L'écran annonçait
**« Nouveau record d'allure · 3:00/km sur 20,0 km »** après une sortie à vélo : un record de course
inventé par une discipline qui n'en est pas une.

### La règle qui tranche les six cas

**Les kilomètres ne s'additionnent pas entre disciplines, le temps si.** Vingt kilomètres à vélo ne
sont pas vingt kilomètres en courant — les mettre dans le même total ne mesure rien. Une heure, en
revanche, est une heure, et c'est précisément ce que « temps actif » veut dire à côté d'un compteur
de kilomètres.

`RunRecordDiscipline` portait déjà la doctrine, commentaire compris : `.allDisciplines` existe pour
que « toutes » soit **une décision écrite, pas l'absence de décision**. Les cinq agrégations
l'ignoraient ; plus aucune n'utilise `weekRuns` nu.

### Et un sixième cas, dans la liste des séances

La ligne écrivait `avgPace + "/km"` pour toutes les disciplines — donc **« 3:00/km » sous une sortie
vélo**. `TimeFormat.rythme(_:secondesParKm:)` existe et relit le champ dans l'unité que la
discipline *affiche* : au kilomètre à pied, aux cent mètres en bassin, en km/h à vélo.

### Ce qui le garde

Le calcul est sorti de la vue dans `BilanDeLaSemaine` — même raison que `PlanRecap`, et son
en-tête l'explique : une vue SwiftUI ne se teste pas, une structure qui prend un historique et rend
des nombres, oui. `RunUpTests/BilanDeLaSemaineTests.swift`, onze tests, dont « une sortie à vélo ne
bat pas un record d'allure de course » et « la somme des barres est exactement le total affiché ».

## Chantier 5 — les données de démonstration

Premier point de l'audit dont les **trois** affirmations étaient exactes au chiffre près : seize
sorties portant `avgHeartRate: 148`, seize portant `title: "Sortie"`, et un défi de club dont le
mois est écrit en dur.

### La fréquence cardiaque, et pourquoi le fractionné n'est pas le plus haut

Ces valeurs sont des **moyennes de séance** — échauffement, récupérations et retour au calme
compris — pas des pics. Un fractionné VMA touche Z5 pendant ses répétitions, mais ses
trottinements de récupération tirent la moyenne vers le bas : elle finit **sous** celle d'un tempo,
qui est un effort continu au seuil. Écrire 175 en moyenne sur un fractionné aurait été un chiffre
faux sur une capture de l'App Store.

Pour une coureuse intermédiaire (FC max ≈ 190) : footing facile 136, endurance 146, sortie longue
144 (un peu au-dessus du footing facile à cause de la dérive cardiaque sur une heure et demie),
tempo 158 — la plus haute des cinq — et fractionné 152. Une graine décale de quelques battements
d'une sortie à l'autre : **8 valeurs distinctes au lieu d'une**.

### Le titre, dont le vrai défaut était ailleurs

Le seize fois « Sortie » avait **deux causes**, et la seconde touche de vraies utilisatrices :
`HistoryView` affichait `run.title` — le libellé **français** de l'archétype, écrit à
l'enregistrement — au lieu de `run.titreAffiche`. L'écran qui porte toute l'histoire de quelqu'un
sortait donc en français pour une anglophone.

L'accesseur existait, documenté, et était déjà utilisé par le bilan de course, la vidéo partagée et
la carte du parcours. Il avait été oublié dans `HistoryView` (la ligne **et** son libellé VoiceOver)
et dans `WeeklyRecapView`. Et il est strictement meilleur que ce qu'il remplace : il retombe sur le
texte enregistré quand la sortie n'a pas de `sessionKind`, ce qui est exactement le cas que le
commentaire d'`AddRunSheet` protège — une sortie importée de Strava avec son titre libre.

### Le mois du défi

Les captures de la 3.3 ont été prises en novembre : la fiche annonçait un défi **d'octobre**, avec
six jours restants, à côté d'un historique daté de novembre. Le mois vient maintenant du
calendrier, dans la langue de la capture, avec sa clé dans les trois langues.

## Chantier 4 — les finitions de design (émojis faits)

### Ce que l'audit avait mal compté

L'audit disait « 2 émojis UI ». Il y en avait **57**, et « 2 dégradés » là où il y en a une
trentaine dont quatre violets. L'audit avait compté ce qui se voyait sur dix-huit captures, pas ce
qui est dans le code. La coche `✓` n'entre pas dans le compte : c'est un signe typographique, pas
un emoji, et le widget s'en sert exprès.

### Les deux moitiés du travail

**Trente-cinq occurrences** étaient des émojis posés dans une phrase : aucune décision à prendre,
juste à retirer. Un emoji qui tenait lieu de ponctuation rend le signe qu'il remplaçait. Vingt-huit
clés du catalogue renommées, anglais et espagnol nettoyés de la même façon.

**Vingt-deux** étaient des émojis utilisés comme **icône** — un glyphe seul, donc un remplaçant à
trouver. Les neuf objectifs de l'inscription, les quatre visages du ressenti, trois pictogrammes de
la fiche de débriefing, la série, la coupe, deux cibles, une feuille et la pastille Strava.

### Ce qui a été décidé, écran par écran

Sept des neuf symboles d'objectif étaient **déjà employés ailleurs dans le dépôt** — donc déjà
éprouvés : `dumbbell.fill` est le symbole du renforcement, `mountain.2.fill` celui d'une course de
trail, `leaf.fill` celui de la récupération. Les faire se répondre d'un écran à l'autre vaut mieux
que d'en inventer neuf nouveaux. Chaque symbole prend la **teinte de son objectif**, qui existait
déjà dans le système de design et que l'emoji ne pouvait pas porter.

Deux changements de **sens**, pas de dessin :

- la perte de poids portait 🔥, qui parle de dépense. Elle porte une **balance**, qui est ce qu'on
  regarde. Le feu revient à la série en cours, où il veut dire ce qu'il dit.
- « Rester en forme » portait ⚡, qui parle d'intensité — l'inverse de ce que cet objectif propose.
  Il porte un **cœur**.

Le **ressenti** perd ses quatre visages et garde ses quatre mots. Un visage ne dit rien de plus que
le mot qu'il surmonte, et il dit moins bien : il n'est pas ordonné. L'échelle l'est déjà, par la
position des boutons.

La carte « semaine prochaine » passe de 📈 👍 🧘 à une **flèche qui monte, un signe égal, une
flèche qui descend**. Les trois états sont ordonnés ; un bonhomme en lotus ne se compare pas à un
pouce levé.

La **pastille Strava** reste une pastille, dans l'orange de Strava écrit en dur. Le 🟠 n'était pas
de la décoration : il identifiait la marque par sa couleur. Aucune teinte de notre palette ne
convient, et poser `0xFC4C02` dans `RUColor` laisserait croire qu'il nous appartient.

### La barrière posée avant le remplacement

Un nom de symbole SF faux **ne dessine rien** : pas d'erreur, pas de journal, un cadre vide de la
bonne taille. Écrire neuf noms d'un coup sur le premier écran de l'app, c'était neuf occasions
d'expédier une icône invisible.

`RunUpTests/SymbolesTests.swift` demande donc à `UIImage(systemName:)` de résoudre chaque nom — la
seule façon de poser la question, le catalogue appartenant au système. `check_symboles.py` est le
pont qui garantit que la liste éprouvée est exactement celle que le code emploie.

**En l'écrivant, elle a trouvé que 33 noms déjà en production n'avaient jamais été éprouvés** :
les sept familles de séance, la main qui n'applaudit pas encore dans un ternaire, et
`lock.rectangle` / `lock.slash` que j'avais écrits moi-même au chantier 2 deux heures plus tôt. Mon
premier jet d'extraction les manquait tous — il ne lisait que le littéral collé à `systemName:`.
La lecture est maintenant pilotée par le site d'appel, avec deux précautions contre la collision de
noms entre fichiers : la même erreur que dans mon inventaire d'émojis, qui annonçait 21 défauts
dont 17 appartenaient à l'écran d'à côté.

102 noms, zéro émoji restant dans l'interface, et c'est le simulateur qui valide chaque nom à
chaque construction.

### Les cinq autres points, mesurés un par un

L'audit s'étant trompé d'un facteur 25 sur les émojis, chaque point a été **mesuré** avant d'être
touché. Deux se sont révélés faux, deux étaient réels, et un était une décision déjà documentée.

**Le vert du profil d'élévation : à moitié vrai.** Sur l'écran de bilan le vert tient, parce que le
« +123 m D+ » posé juste sous le graphe est vert aussi — la couleur y est le nom de la mesure. Sur
la page d'activité du club, le D+ existe mais dans la grille générique, en `textPrimary`, à six
cases du graphe : le vert ne désignait rien et c'était la seule tache de couleur d'une page rose et
neutre. Repeindre le graphe aurait été pire — la même donnée en deux couleurs selon l'écran. C'est
le D+ qui prend la couleur de sa courbe.

**La bulle du coach : vrai, et le chiffre le dit.** La bulle est posée sur la carte MapKit, donc son
`.ultraThinMaterial` capte un fond clair en apparence claire. À 0,85 d'opacité le fond effectif vaut
`0x303036`, et le sourcil écrit dans la variante claire de l'accent y tombe à **4,25:1** pour
l'accent par défaut — sous le seuil de 4,5:1 d'un petit texte. Le violet n'était qu'à 4,86. À 0,92,
le rose monte à 5,25 et le violet à 6,00 : sept centièmes d'opacité que l'œil ne distingue pas.

**Le segment blanc sur blanc : vrai, et pire que ce que l'audit disait.** La pastille active est
`card` sur un rail `bg2` : **1,25:1 en clair, 1,04:1 en sombre**. Du blanc sur du blanc et du noir
sur du noir, là où WCAG 1.4.11 demande 3:1 pour un élément qui porte un état. L'état était lisible,
mais par le TEXTE seul. Elle porte maintenant un filet d'accent — 4,97:1 en sombre, 3,03:1 en clair
— et non un remplissage : la raison écrite dans le code tient toujours (deux barres roses empilées
ne se hiérarchisent plus), et le filet est la règle du dépôt.

**Les boutons gris en capitales : faux.** `SecondaryButtonStyle` donne **16,27:1** en sombre et
**15,39:1** en clair. Le reproche ne pouvait pas être le contraste. Ce que j'ai trouvé en regardant
ce qu'ils FONT est autre chose, et je ne l'ai pas changé seul — voir ci-dessous.

**Les dégradés violets : une décision déjà prise.** Quatre sites, dont deux sur les surfaces de
partage (carte et vidéo) qui sont de l'identité de marque, pas de l'interface. Des deux autres, la
pastille du niveau garde son dégradé : le commentaire du code montre qu'une passe précédente l'a
décidé exprès (« un point de couleur, pas un aplat plein cadre »), et repasser par-dessus une
décision documentée sans la poser serait exactement ce qu'il ne faut pas faire.

Le FOND de cette carte, lui, était un vrai défaut : le même commentaire affirme « c'est maintenant
une carte comme les autres » alors que seul le mode CLAIR avait été corrigé. En sombre elle gardait
un dégradé de deux teintes écrites en dur qui n'existent nulle part ailleurs, un contour violet à
30 % — un accent dilué, ce que le dépôt refuse partout — et des textes figés en blanc pour
compenser ce fond. Trois symptômes, une cause, et un commentaire qui annonçait la correction des
trois. C'est une carte, dans les deux thèmes.

### Deux trouvailles d'affordance, tranchées par Charlotte

Toutes deux sur `SecondaryButtonStyle`, et toutes deux de l'**affordance**, pas du contraste — le
style est à 16:1.

1. **« ABONNÉ » était une bascule déguisée en état.** Le bouton affichait l'état et son appui
   désabonnait : on croyait lire un statut, on agissait. Décision du 7 novembre : **le libellé dit
   l'action**. « SE DÉSABONNER » et « ANNULER LA DEMANDE ». L'état ne se perd pas — « se
   désabonner » implique qu'on est abonnée.
2. **« RETIRER » était visuellement identique à « MODIFIER »** et partait sans confirmation, alors
   qu'il fait disparaître de la page et des groupes d'allure. Décision : **une confirmation**,
   plutôt qu'un poids visuel différent. Le texte dit ce qu'on perd **et** que c'est réversible —
   sans la seconde phrase, une confirmation fait hésiter sur un geste qui ne coûte rien à défaire.

## Chantier 3 — les délégués CoreLocation

### Ce qui était faux

L'audit en nommait deux, il y en avait **trois** : `LocationService`, `RunWeatherService`, et
`LocationPermission` dans `RouteDiscoveryView`. Les trois publient de l'état lu par une vue à
chaque image et l'écrivent depuis un rappel système, sans aucune garantie du compilateur. La
promesse tenait sur un fait vrai mais invérifiable : `CLLocationManager` livre ses rappels sur la
boucle d'exécution du fil où il a été créé, et les trois créations sont `@MainActor`.

`RunWeatherService` est le cas le plus net. `enAttente` est un emplacement unique, écrit depuis
`position(fallback:)` et depuis deux rappels, et **une continuation reprise deux fois fait tomber
le processus**. Le fichier raconte déjà une course qu'il a fallu voir pour la croire — deux
demandes qui se chevauchent — et la parade écrite à l'époque reste juste ; ce qu'elle n'avait pas,
c'est une garantie que les deux demandes ne s'exécutent pas en même temps.

### Pourquoi pas `Task { @MainActor in … }`

C'est le patron déjà présent deux fois dans le dépôt (`WatchSessionService`,
`VoiceCoachController`), et il est juste **là-bas** : WatchConnectivity et `AVSpeechSynthesizer`
appellent leur délégué depuis leur propre file, donc le saut est obligatoire, et il s'agit d'un
état à poser — pas d'une mesure à accumuler.

`LocationService.didUpdateLocations` accumule : il compare chaque point au précédent, additionne
une distance, alimente un lissage d'altitude. Or **deux `Task` non structurées n'ont aucun ordre
garanti entre elles**. Deux lots de fixes traités à l'envers ne donnent pas un retard : ils
donnent une distance fausse et un dénivelé faux, sur la mesure qui est tout le produit.

`surLActeurPrincipal` fait donc le travail **tout de suite** quand on est déjà sur le fil principal
(`MainActor.assumeIsolated`) : même ordre, même image, aucune ligne ne change de moment
d'exécution, et l'isolation devient vérifiée. Le repli par `Task` existe parce que
`assumeIsolated` seul fait tomber le processus si l'hypothèse est fausse — ce code tourne pendant
quatre-vingt-dix minutes écran éteint, et un plantage au trentième kilomètre serait un prix absurde
pour une vérification de type.

### Le détail qui a demandé deux essais

`NSObject.init()` n'est pas isolé, et un remplacement ne peut pas l'être plus : les trois
initialiseurs sont donc `nonisolated`. Ça, c'était juste du premier coup.

Ce qui était faux, c'est ce que j'ai cru qu'un tel `init` avait le droit de faire ensuite. J'avais
retiré leur valeur par défaut à `manager` et `authorizationStatus`, en pensant que leur affectation
compterait alors comme de l'**initialisation**, qui n'a pas besoin d'isolation, plutôt que comme
une **mutation**, qui en a besoin. Le compilateur dit non, et il l'a dit en trois lignes dont une
erreur franche :

```
RouteDiscoveryView.swift:355: error: main actor-isolated property 'status'
can not be mutated from a nonisolated context
```

Les propriétés gardent donc leur valeur par défaut, et tout le réglage part dans un
`reglageInitial()` isolé appelé par `surLActeurPrincipal` — qui l'exécute **tout de suite**, avant
que l'`init` ne rende la main, puisque les trois constructions sont `@MainActor`.

J'avais hésité entre deux formes et j'ai poussé la moins sûre sans le dire. La construction est le
seul compilateur de ce projet : quand il y a un doute, la bonne méthode est de pousser la forme
dont on est sûr.

### Ce qui le garde

Le compilateur. L'isolation est une propriété de compilation : une construction verte EST la
vérification, et inventer un test unitaire pour en faire semblant serait pire que rien.
L'algorithme de distance de `LocationService` — plancher de bruit, saut à 12 m/s — n'a toujours
aucun test ; c'est le chantier 9, qui le nomme.

## Les treize avertissements du dépôt, et leur cause unique

Onze des treize venaient d'UNE insertion. `markSessionDone` avait été écrit **entre** le
`@discardableResult` de `applyDebrief` et `applyDebrief` elle-même. L'attribut s'est recollé sur
`markSessionDone`, qui ne rend rien — « declared on a function returning 'Void' is unnecessary » —
et les dix appels à `applyDebrief` se sont mis à avertir « result of call is unused ». La
documentation, elle aussi restée en haut, décrivait une fonction qui n'était pas celle qu'elle
surplombait.

Et l'avertissement avait raison : `applyDebrief` rendait « Programme mis à jour · +120 XP » que
**personne ne lisait**. Son unique appelant, `DebriefSheet`, jetait la valeur et affichait la même
phrase écrite une seconde fois chez lui — les deux copies avaient déjà divergé. La fonction ne rend
donc plus rien ; la phrase appartient à l'écran qui l'affiche.

Les deux derniers : un `try? await auth.refreshMe()` dont on ne voulait que l'effet de bord, et un
`let today` devenu inutile quand la pastille du jour du widget est passée au calcul chez le widget.

**Zéro avertissement.** C'est ce qui rend la règle « aucun avertissement nouveau » vérifiable : un
treizième se perdait dans douze.

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
