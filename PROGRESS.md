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
| 3 | `@MainActor` sur `LocationService` et `RunWeatherService` | 3 h | **fait** |
| 4 | Finitions design : 2 émojis dans l'interface, 2 dégradés, vert isolé du profil d'élévation, boutons gris en capitales, segment blanc sur blanc, contraste de la bulle du coach | 1 j | à faire |
| 5 | Données de démonstration : FC 148 seize fois, « Sortie » seize fois, défi « octobre » affiché en novembre | 4 h | **fait** |
| 6 | Bilan de la semaine — l'écran noté 5,5/10 | 1,5 j | **fait** |
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
