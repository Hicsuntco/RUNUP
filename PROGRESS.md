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
| Cette branche doit-elle rester la production ? | Elle l'est, confirmé dans les réglages Vercel le 7 novembre : `Settings → Environments → Production → Branch Tracking` porte `claude/runup-ios-swiftui-app-5b1yv6`. Donc aucune relecture, aucune préproduction. Les aperçus, eux, sont maintenant éprouvables — voir le chantier 11. |


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

**Suite, le lendemain : il s'est reproduit, en anglais, et avec ses images.** Deux plans sur
quatre tombaient sur l'écran du plan SUIVANT — le coach montrait les stats, le profil montrait
l'accueil — et `--preuves` a gardé les deux images, qui le montrent sans discussion (la barre
d'onglets y désigne l'onglet Stats sous un plan qui annonce le Coach).

**Donc le découpage ne peut pas reposer sur l'heure annoncée par la caméra.** `simctl` dit
« Recording started » avant d'écrire sa première image, et le reste de l'écart varie avec la
charge de la machine. Une horloge qu'on ne peut pas vérifier n'est pas une mesure.

`bascules.py --aligner` cherche donc le décalage par le CONTENU : les quatre écrans visés sont
photographiés par la passe claire, on essaie des décalages au quart de seconde sur ±4 s, et on
garde celui qui met les quatre plans sur leurs écrans. Le montage coupe sur ce décalage-là. Si
aucun ne les met tous les quatre, la mesure le dit et le film n'est pas fabriqué — ce qui reste
le bon comportement : à ce moment-là, ce n'est plus une horloge, c'est autre chose.

Éprouvé dans les deux sens sur un film fabriqué dont on connaît le découpage : on ment de trois
secondes, il retrouve zéro ; on dit la vérité, il ne déplace rien. (Et le premier jet de ce
test-là se trompait lui-même — deux de ses quatre écrans d'essai étaient identiques, parce que
leur motif était modulo 2.)

**Et cette recherche-là ne sait pas faire mieux qu'à une seconde près — c'est intrinsèque.** La
question « ce plan montre-t-il le bon écran ? » a la MÊME RÉPONSE sur deux secondes et demie :
le test appuie sur l'onglet 0,6 s avant le début du plan, et le plan dure deux secondes. Il n'y
a pas de minimum à trouver, il y a un plateau, et c'est le bruit de l'image qui y tranche. Elle
a rendu 0 pendant des semaines et −0,75 s le 8 novembre, sur le même harnais. Un décalage de
−0,75 est parfait pour l'identité et faux pour le découpage : la fenêtre de 0,9 s qui cherche
le changement d'écran tombe alors entièrement avant lui, et le garde-fou ne voit plus rien.

**Le décalage se reprend donc sur le CHANGEMENT d'écran, qui est net.** `affinage` le cherche
dans une fenêtre asymétrique — 2,0 s avant le plan, 1,2 s après, parce qu'au décalage fautif le
changement tombe APRÈS le début de plan supposé — et ramène le décalage pour que le changement
retombe à 0,6 s. La recherche grossière garde son rôle : ramener une horloge fausse de plusieurs
secondes à moins d'une, ce qu'elle sait faire.

**Trois erreurs de ma part sur ce seul sujet, et la troisième est la plus instructive.** D'abord
j'ai cru que l'instant où l'on regarde était en cause, et l'exécution suivante a rendu le même
−0,75. Ensuite j'ai écrit un affinage dont la fenêtre ne couvrait pas le cas qui l'avait motivé.
Enfin — et c'est celle qui compte — l'affinage a déplacé le découpage de −0,62 s sur une prise
dont l'horloge était juste, parce que `instant_du_changement` rendait la PREMIÈRE image qui
n'est plus l'écran d'avant. Sur 0,9 s ça marche ; sur 2 s, une seule image qui s'écarte — un
défilement qui finit, une tuile de carte qui arrive — suffit à la faire tomber trop tôt. Elle
rend maintenant la DERNIÈRE image de l'écran d'avant : même nombre sur une fenêtre propre, ce
qui explique que tous les cas fabriqués passaient, et seul le second tient sur une vraie prise.

**Et un message disait l'inverse de sa condition.** « La fenêtre ne commence pas sur l'écran
d'avant » s'affichait quand AUCUNE image de la fenêtre ne quitte l'écran d'avant. Il m'a fait
raisonner une demi-heure sur la mauvaise cause.

**L'épisode précédent, lui, ne s'était pas reproduit sur le coup.** Deux exécutions complètes du harnais
ont suivi, et leur étape de film est verte dans les trois langues — `es-ES.mp4` existe et son
découpage tombe sur les bons écrans. C'était donc un accident de prise, pas un défaut de
l'alignement : un appui d'onglet qui n'a pas pris, très probablement. Ce qu'il faut en retenir
n'est pas la cause, qu'on ne connaîtra pas, mais le comportement : **le garde-fou a refusé de
publier un film faux**, ce que trois films sortis avant lui n'avaient pas eu pour les arrêter. Et
la prochaine fois, l'image sera dans l'artefact.

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

**Les chevrons sont des symboles, décision du 7 novembre.** Les deux boutons de retour
dessinaient le caractère « ‹ » là où cinq autres retours de l'app emploient déjà `chevron.left` ;
six indicateurs de ligne dessinaient « › » dans des fichiers qui, deux lignes plus loin,
employaient `chevron.right`. Huit caractères typographiques remplacés par les deux symboles, aux
crans de l'échelle d'icônes. Il ne reste aucun `Text("›")` ni `Text("‹")` dans l'app.

**Un contrôle qui cherche un motif dans un fichier finit par se trouver lui-même.** Trois fois
le 8 novembre. `check_cjs.py` refuse qu'un paquet livré en ESM seul soit chargé par `require` —
et le correctif qu'il venait de faire écrire cite `require('jose')` dans son commentaire, donc il
a signalé ce fichier-là. `check_filet.py` cite les deux formes qu'il refuse, dans sa propre
documentation. `check_cablage.py` cherchait `"from PIL" in texte`, et sa propre ligne de
recherche contenait ces mots : il s'est accusé lui-même de lire des images. Les deux premiers
blanchissent les commentaires ; le troisième ne pouvait pas, puisque c'était son code — il lit
les imports dans l'ARBRE syntaxique, qui ne contient que ce que Python exécute.

**Un garde-fou qu'on croit avoir est pire que pas de garde-fou**, et trois existaient sans
tourner : `test_session.py`, `test_accent.py`, et `test_comparer.py`, écrit le 8 novembre.
(Un quatrième, `check_profile.py`, a semblé en être un — et c'était le contrôle qui se
trompait : sa règle tourne à chaque build, appelée par `profils.py`, qui l'importe. Il suit
les imports depuis. Une dispense fausse est pire qu'une dispense manquante : elle dit qu'on
sait, et on ne sait pas.) `check_cablage.py` exige maintenant que tout
`check_*.py` et tout `test_*.py` de `ci_scripts/` soit nommé par un workflow, ou figure dans une
liste de dispenses AVEC sa raison — ou soit importé par un fichier qui, lui, est nommé. Il n'y
a aucune dispense aujourd'hui.

**Et câblé ne veut pas dire qu'il a de quoi tourner.** `test_comparer.py` était bien nommé par
un workflow, et il a échoué dix minutes plus tard sur `ModuleNotFoundError: No module named
'PIL'` : il était dans TestFlight, dont le python est celui du système. Les huit scripts du dépôt
qui lisent des images tournent dans un job qui installe Pillow dans un venv. `check_cablage.py`
pose donc la seconde question, et ne dépend lui-même de rien — c'est le job qui n'installe rien
qui le lance, et `pip install` nu est refusé sur les runners macOS.

**Le trait qui sépare deux lignes était écrit de deux façons, et une des deux était fausse.**
Trente endroits posaient `Divider().background(RUColor.line)` : le `Divider` de SwiftUI a sa
propre épaisseur — un pixel d'écran, un tiers de point sur un ×3 — et sa propre couleur, et
`.background` peint derrière lui au lieu de le recolorer. Douze autres dessinaient le bon filet à
la main. Aucun contrôle ne le voyait, aucune capture non plus : les écrans qui employaient
`Divider` ne sont pas photographiés. `RUFilet` les remplace tous les quarante-deux et nomme son
orientation au lieu de la deviner ; `check_filet.py` tient la porte.

**Le harnais de captures ne dit pas ce qu'il y a sur les images**, et découper un écran
photographié est par définition un changement qui ne doit rien changer à l'écran. `comparer.py`
prend les captures d'avant et celles d'après et dit ce qui a bougé : écart moyen, nombre de
pixels au-delà du bruit, et le CADRE qui les contient. Barre d'état masquée — elle porte l'heure,
et un outil qui compte ce pixel-là dit « tout a changé » à chaque fois. Le compte de pixels est
là à côté de la moyenne parce qu'un petit bloc changé du tout au tout ne pèse presque rien sur la
moyenne d'une image de 2 796 points, et que c'est exactement la forme d'un défaut de découpage.

**Découper une pile SwiftUI n'est pas neutre, et deux questions restent sans réponse sûre.**
Le classement est sorti de `ClubView` sans histoire : c'était un enfant unique d'un `Group`, le
sortir ne change rien à la mise en page, et TestFlight est vert dessus. Les trois sections de
pépites — ce que le club prépare, les séances tenues, les records — étaient au contraire trois
enfants DIRECTS d'une pile espacée de 24, et les regrouper en fait un seul enfant. Deux
comportements décident alors du résultat, et aucun des deux ne se lit dans la documentation :

1. **Une pile sans enfant est-elle espacée comme une vue vide ?** Quand les trois sections se
   taisent — un club tout neuf — chacune rendait une `EmptyView`, et une pile n'espace pas
   autour d'une `EmptyView`. Une pile vide est, elle, une vue de hauteur nulle mais présente.
   Quarante-huit points de blanc apparaîtraient là où l'aperçu a justement été retravaillé pour
   ne plus montrer de sections vides.
2. **`.task` part-il sur un `Group` dont le contenu est vide ?** La parade au point 1 est de ne
   rien rendre quand il n'y a rien — mais `highlights` vaut `nil` au premier rendu, toujours,
   donc la condition est fausse au moment même où le chargement doit partir. Les sources se
   contredisent : les unes disent que `.task` ne part jamais sur un `Group` vide, une autre
   qu'Apple l'a traité à part depuis iOS 26. Ce n'est pas une question à trancher par vote.

L'extraction a donc été annulée, et la bonne réponse est celle que le relevé indiquait déjà :
sortir les données et le réseau du club dans un magasin observable, et ne laisser aux vues que
de l'affichage. Six états sur trente sont partagés par trois régions ou plus, et ce sont
exactement ceux-là.

**`ClubStore` existe depuis, et il fait disparaître les deux questions au lieu d'y répondre.**
Les neuf états de données, les dix-huit fonctions de réseau, puis les quinze appels qui
traînaient au milieu des feuilles et des boutons : le mur, les sorties de groupe, les quatre
réglages du club, la suppression d'activité et `highlights`. `ClubView` ne garde que ce qui est
de l'écran — l'onglet affiché, les feuilles, les brouillons, les confirmations en attente — et
ne connaît plus `clubService` que pour le passer à une sous-vue. 2 721 → 1 799 lignes.

C'est `highlights` qui débloque les pépites : la donnée étant au magasin, la sous-vue n'en
recevra qu'une copie en lecture et le parent gardera son `.task`. Il n'y a plus de `Group` vide
dont il faudrait deviner le comportement.

L'état de l'application entre par le CONSTRUCTEUR et non par chaque appel : onze des dix-huit
fonctions le lisent, et le passer en paramètre aurait changé dix-huit corps — ce qui transforme
un déménagement vérifiable en réécriture. `@State` ne s'initialise pas depuis l'environnement,
mais il s'initialise depuis un paramètre, et c'est `SocialView` qui le passe.

Le magasin s'appelle `magasin` et non `club`, et ce n'est pas une préférence : le fichier est
plein de `if let club = board.club`, et le premier renommage a fait MASQUER le magasin par ces
liants locaux dans quatre blocs. Trouvé en lisant le diff, avec trois autres dégâts du même
renommage — les cases de l'énumération `Tab`, qui s'appellent `board` et `feed`, deux étiquettes
d'argument, et un `if let errorMessage` devenu `if let magasin.errorMessage`, qui n'est pas du
Swift.

**Et le découpage ne change rien à l'écran, c'est mesuré.** Vingt-quatre captures du Club —
trois langues, deux thèmes, quatre écrans — rendent `ÉCART MAXIMAL=0,000` et `PIXELS=0` entre
l'avant et l'après de la première extraction. C'est ce pour quoi `comparer.py` a été écrit avant
d'y toucher.

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
| 11 | Dépendances serveur : `jose` 6 et `bcryptjs` 3 | 0,5 j | **fait** — après une panne de onze minutes, une reproduction sur aperçu et un correctif éprouvé |
| 12 | Accessibilité : tailles de texte dynamiques, indices VoiceOver | 1,5 j | **en cours** — quatre écrans photographiés au deuxième cran, dix défauts vus et corrigés |
| 13 | `ClubView.swift`, 2 721 lignes, à découper | 2 j | **en cours** — 2 721 → 1 799 lignes, le magasin est en place |
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

### Et deux autres, trouvés en regardant les images que la barrière venait de produire

**Une couverture qui ne charge pas laissait un cadre cassé** de 240 points — icône d'image
absente comprise — qui poussait le nom du club sous la ligne de flottaison. Vu sur la capture du
cas piégé, dont l'URL est volontairement morte. La page se passe très bien de couverture (c'est
le cas de tout club qui n'en a pas posé) : l'image se retire d'elle-même si elle échoue.

**Un club sans séance ne disait rien du tout.** Aucun titre, aucune phrase : un club qui n'a rien
annoncé et un club dont on cacherait les séances rendaient exactement la même page. Quelqu'un qui
décide s'il vient a besoin de la différence. « Aucune séance annoncée pour l'instant. », dans les
trois langues.

### Ce qui l'empêche de recommencer

`.github/workflows/page-club.yml` : huit cas — trois langues, l'état normal, l'état
« introuvable », un club d'une seule personne, une couverture morte et une couverture piégée — photographiés sur une
machine Linux en une minute. Il refuse une erreur JavaScript, une page sans bouton, un bouton qui
ne mène pas à l'App Store, et un échappement qui laisse une valeur sortir de son attribut.
Éprouvé dans les deux sens : sur la page corrigée il passe, sur une copie dont on a retiré
l'échappement des guillemets il échoue en nommant les deux symptômes.

Le reste ne se juge pas tout seul : les huit images partent dans l'artefact, et quelqu'un les
ouvre.

## La démonstration parlait français sur la fiche espagnole

Vu sur la capture n° 4 de la fiche App Store espagnole : sous un écran entièrement en espagnol —
« El Club », « Resumen · Clasificación · Actividad », « 18 miembros », « hace 3 h » — la
description du club s'affiche en français, en toutes lettres et sur trois lignes.

Le mécanisme existait déjà et était documenté : `echange()` et `commentaire()` choisissent la
langue à la main, avec la bonne raison — « c'est du texte libre, que rien dans l'app ne sait
retraduire ». Le reste du fil se refabrique à partir de `contentKey` (« a couru 6,0 km ·
Fractionné » devient « ran 6.0 km · VO2max intervals » tout seul), et c'est précisément ce qui
donnait l'impression que tout était traduit.

**Onze autres phrases ne passaient par rien** : la description du club, la bio de Charlotte, les
deux titres de séance hebdomadaire, les deux groupes d'allure de la séance de piste, les trois
annonces du mur et les trois messages de la page de course. Toutes passent maintenant par un
passeur unique, `libre(_:en:es:)`, plutôt que par onze `switch` recopiés.

Les noms propres n'y passent pas : « Les Foulées du Canal », « Bassin de la Villette », « Stade
Jules-Ladoumègue » et les prénoms restent ce qu'ils sont — un club parisien reste un club
parisien, et c'est une décision, pas un oubli.

Et les deux titres de séance sont désormais nommés **une seule fois** : ils paraissent aux
séances à venir ET à l'historique du club, qui rejoue les mêmes rendez-vous. Deux copies
auraient fini par diverger, et le club aurait annoncé une sortie qu'il n'a jamais tenue.

## Chantier 12 — l'app en grand texte, enfin photographiée

Commencé par la mesure, et la mesure a corrigé l'item de l'audit.

### Ce que l'audit disait, et ce que le code dit

« Tailles de texte dynamiques » : c'est **déjà fait pour le texte**. `RUFont` fait passer chaque
taille dessinée par `scaled(_:)`, qui lit le réglage iOS et plafonne à 2,0 ×. Sur les 174 appels
à `.font(.system(size:))` du dépôt — le seul chemin qui contourne ce système — **167 portent une
icône** et **4 portent du texte** : les deux chevrons « ‹ » des boutons de retour, le repli qui
affiche l'emoji d'une notification déjà enregistrée, et la coche typographique de l'assistant
d'objectif. Les trois derniers sont des glyphes dans un cadre, et c'est justifié.

### Ce qui est fait : l'échelle d'icônes

`RUIconSize`, sept crans — 9, 11, 13, 15, 18, 22, 28 — et `RUFont.icone(_:weight:)`. Les 170
appels sont convertis, et `ci_scripts/check_icones.py` refuse désormais une taille écrite à la
main dans `RunUp/Views` : il en reste **deux** depuis que les chevrons « ‹ » sont devenus
`chevron.left`, toutes deux listées avec leur raison, et aucune n'est une icône (le repli qui
affiche l'emoji d'une notification déjà en base, la coche typographique de l'assistant
d'objectif). Le test, lui, RÉPÉTAIT le nombre quatre au lieu de le dériver de la liste : il est
resté rouge dix minutes après le commit qui ramenait quatre à deux, parce que j'avais lancé les
contrôles sans lancer leurs cas. D'où `ci_scripts/tout.sh`, qui lance les deux en une commande.

Les crans sont relevés, pas inventés : **13 et 15 — les deux tailles les plus employées, 65
appels à elles deux — sont des crans**, donc ces 65 appels rendent exactement ce qu'ils
rendaient. Les autres se déplacent d'un point, deux au plus. Quatre sorties d'échelle restent,
toutes des illustrations : 72 points pour un état vide, 52 pour une carte de badge partagée, 42
et 40 pour deux hexagones dont la taille suit leur médaillon.

### Ce qui n'est PAS fait, et pourquoi c'est écrit dans le code

**Les icônes ne suivent toujours pas le réglage de taille du texte.** C'est un vrai défaut
d'accessibilité et il reste ouvert. La raison est celle qui a tenu le plafond de titrage à 1,6 ×
pendant des mois : une icône qui double dans un cadre qui ne double pas déborde. La barre
d'onglets enferme ses symboles dans 22 points de haut, calculés pour qu'un symbole de 18 y tienne
sans déborder — et sa hauteur sert d'encart au bas de chaque écran. Une dizaine de colonnes
d'alignement (`.frame(width: 26)`, `.frame(width: 30)`) sont dans le même cas.

Ouvrir la croissance sans reprendre ces cadres ne rendrait pas l'app accessible : **ça la
casserait à AX2 pour exactement les gens qui en dépendent**. Ce qu'il faut est ce qui a permis de
lever le plafond de titrage : reprendre les cadres un par un, et regarder. Les captures en grand
texte existent maintenant pour ça.

### Le relevé qui a mené là

**170 icônes à taille figée, sur 22 valeurs différentes de 8 à 72 points** — dont 13, 14 et 15 pt
voisinant sur 76 appels. C'est le même défaut que l'échelle de titrage avant `RUDisplaySize` :
personne n'a décidé ces tailles, chaque écran a été réglé à l'œil puis recopié. Et aucune ne suit
le réglage de taille du texte : à AX2, le texte grandit de 94 % et les icônes qui l'accompagnent
restent où elles sont.

Classées par ce qui les contient : **97 à côté d'un texte** (elles doivent grandir avec lui),
**60 dans un cadre chiffré** (les faire grandir les ferait déborder), 15 ni l'un ni l'autre.

### Ce que les quatre captures ont trouvé, et ce qui est corrigé

Douze mesures d'écart entre chaque capture en grand texte et son ordinaire : **17,3 à 31,3**. Le
réglage a donc bien pris partout, et ce qu'on voit est l'app.

**L'écran de course — celui qu'on lit à bout de bras — cassait en trois endroits.**

| Défaut | Correctif |
| --- | --- |
| « Recherche du signal **GP…** » | le bandeau est posé en `.overlay` sur une rangée haute d'un bouton : la hauteur proposée était celle d'une ligne. `fixedSize(vertical:)` lui rend sa hauteur. |
| le panneau de mesures s'effondrait — les tirets d'allure passaient à la ligne et « ALLURE » ne s'alignait plus | `ViewThatFits` : trois de front quand ça tient, l'une sous l'autre sinon. Le patron de `RUMetricRow`. |
| le bouton d'arrêt affichait « **ST…** » | le mot rétrécit, le cercle non. Faire grandir les trois commandes ferait déborder la rangée (52 + 70 + 52 à 1,94 ×), et leur taille est une sécurité quand on les vise en courant. |

**L'accueil.** « TA JOURNÉE » chevauchait l'anneau : l'anneau fait 186 points, son trait 15 × 0,74
sur un canevas de 100, donc un carré inscrit de ≈ 102 points — le mot en demandait plus du
double. Les deux lignes rétrécissent pour y tenir ; l'anneau, lui, ne grandit pas (il déborderait
de l'écran). Et le tracé de la dernière sortie passait par-dessus les chiffres : le bandeau était
haut de 150 points fixes, il suit maintenant le texte, plafonné à 2,0 × comme la typographie —
c'est la proportion pour laquelle le voile dégradé a été réglé.

**Le bilan de la semaine.** La pastille d'écart chevauchait le chiffre qu'elle commente. Elle
rejoint le flux aux tailles d'accessibilité. Et l'écran Stats montrait déjà le MÊME écart dans le
flux ET avec son unité — « ▼ 16,6 km » — là où le bilan affichait « ▼ 16,6 » tout court : un
nombre sans unité à côté d'un total en kilomètres se lit comme un pourcentage. Les deux écrans
disent maintenant la même chose de la même façon.

**Stats.** « prochain palier : 30 jours » s'affichait « prochain palier :… » — exactement le
défaut que le commentaire de ce bloc existe pour empêcher : « une barre aux deux tiers sans son
palier est un pourcentage de rien ». Deux lignes plutôt qu'une.

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
croirait avoir vu l'app en grand texte. **Le plancher vaut 10 depuis le 8 novembre**, et il vient
de trente-six mesures — trois exécutions, trois langues, quatre écrans — qui vont de 16,2 à 31,3.
Deux copies du même écran ne diffèrent que par l'heure, soit une fraction de point : il n'y a rien
entre 0,x et 17 à départager, donc rien à régler finement.

### Ce que les quatre captures ont montré, le 8 novembre

Regardées, pas supposées. L'écart au texte ordinaire va de **19,1 à 27,4** sur les douze mesures
— trois langues, quatre écrans : le réglage prend partout, et les images ne sont pas des copies.

Trois des sept correctifs posés la veille tiennent, et la capture les montre : la pastille
d'écart du bilan rejoint le flux au lieu de flotter, la barre d'onglets laisse tomber ses
libellés, le bandeau GPS passe sur deux lignes. Restaient trois choses.

1. **Les trois mesures de la course ne basculaient pas en colonne.** « --:-- » se cassait en deux
   DANS sa cellule, et le libellé ALLURE descendait d'un cran sans plus s'aligner avec FC ni
   KCAL — exactement le défaut que le `ViewThatFits` posé la veille existait pour corriger,
   photographié une deuxième fois. `ViewThatFits` compare la taille IDÉALE de chaque candidat à
   la place offerte, et la taille idéale d'un `Text` qui a le droit de revenir à la ligne est
   toute petite : la rangée « tenait » toujours. Les cellules disent maintenant leur vraie
   largeur — `lineLimit(1)` et `fixedSize(horizontal:)`. C'est le même raisonnement que le
   `Spacer(minLength: 0)` de `RUMetricRow`, commenté depuis longtemps dans `ChipView.swift` :
   un élément élastique rend la rangée inextensible à la mesure.

2. **« Allure moy… » — un titre de section tronqué, deux fois**, sur les Stats et sur le bilan.
   Le titre de `RUCardHeader` porte `lineLimit(1)` et `minimumScaleFactor(0.8)` : à côté d'un
   accessoire il rétrécit d'un cinquième, puis se coupe — et c'est le seul mot qui dise de quoi
   parle la carte. Corrigé dans le composant et non aux deux appels : au deuxième cran
   d'accessibilité l'accessoire passe SOUS le titre, poussé à droite pour rester la valeur de cet
   en-tête. Rien ne bouge aux tailles ordinaires, ni pour les soixante-douze en-têtes sans
   accessoire.

3. **La carte de trace n'était PAS rognée**, et j'avais commencé par la « corriger ». J'ai lu
   « 8,1 km 5:18/km » coupé net et changé `height:` en `minHeight:`. Puis j'ai mis les deux
   captures côte à côte : en taille ordinaire, « À faire / 612 / 9 240 » passe exactement pareil
   derrière la barre d'onglets, qui est translucide et flottante. Modification annulée. On ne
   change pas la mise en page d'un écran photographié pour un défaut qu'on n'a pas vu.

### Et le film espagnol, qui n'avait pas le défaut qu'il annonçait

La chaîne Captures est passée au rouge : « ce plan vise stats et montre profil (écart 24,4 contre
25,0) ». Un quasi-ex æquo — là où un plan posé rend 6,4 contre 24,6 — et les trois autres plans du
même film étaient reconnus sans hésitation. Le découpage était donc juste. C'est l'INSTANT du
jugement qui ne l'était pas : l'image était prise à `debut + 0,5 s`, et « stats » a mis 0,57 s à
se poser ce jour-là — dix-sept images sur vingt. On jugeait un mélange de l'écran qui part et de
celui qui arrive.

Le jugement se prend maintenant un quart de seconde avant la FIN du plan, qui dure deux secondes.
La référence de transition, elle, reste à 0,5 s : c'est l'état vers lequel la fenêtre précédente
converge, c'est son rôle. Et c'est `--preuves` qui a permis de le voir — le garde-fou a refusé le
film ET gardé l'image jugée, ce pour quoi il avait été écrit la veille.

## Chantier 11 — `jose` 6 : onze minutes de panne, puis la cause, trouvée sur un aperçu

**Fait.** `jose` 5.9.6 → 6.2.15 et `bcryptjs` 2.4.3 → 3.0.3, après une panne, une reproduction
hors production et un correctif éprouvé avant d'être poussé.

### La panne

| Heure (UTC) | |
| --- | --- |
| 17 h 00 | les 83 adresses : 69 × 401, 13 × 405, 1 × 400 |
| 17 h 09 min 48 | `jose` 6 + `bcryptjs` 3 déployés **en production**, construction verte |
| 17 h 15 → 17 h 19 | toutes les routes en 500, `FUNCTION_INVOCATION_FAILED`, quatre sondages |
| 17 h 20 min 50 | retour arrière déployé |
| 17 h 20 min 59 | tout revient |

### Les deux explications fausses, dans l'ordre où je les ai eues

**« Le Node du projet est trop vieux. »** `jose` 6 n'est livré qu'en ESM, et `require` d'un module
ESM n'est actif par défaut que sur Node ^20.19, ^22.12 ou ≥ 23. J'avais vérifié ce que Vercel
*propose* et conclu que le plancher était tenu. Charlotte a ouvert le réglage : **le projet est
sur Node 24.x**. L'explication tombe.

**« Alors c'est le code. »** Node 24.22 installé ici, les quatre points d'entrée du serveur
chargés avec `jose` 6.2.15 et `bcryptjs` 3.0.3 : **les quatre chargent sans broncher**.
L'explication tombe aussi.

### La reproduction, sur un déploiement d'aperçu

Quatre aperçus sur une branche jetable, même code à chaque fois sauf la ligne testée. Il a fallu
couper `Vercel Authentication` le temps de l'essai : sans ça, un aperçu répond 302 vers une page
de connexion et ne se sonde pas.

| Aperçu | Ce qui change | Résultat |
| --- | --- | --- |
| témoin | rien | 405 / 401 — sain, donc les variables d'environnement sont partagées |
| épreuve | `jose` 6 + `bcryptjs` 3 par `require` | **500 partout** — la panne, rejouée |
| bissection | `bcryptjs` 3 seul | 405 / 401 — sain |
| correctif | `jose` 6 par `import()` | 405 / 401 — sain |

**La cause : l'empaquetage des fonctions par Vercel ne sait pas charger par `require` un paquet
livré en ESM seul.** Ni le code, ni la version de Node. Rien dans le dépôt ne pouvait le dire —
construction verte, 133 tests verts, Node au-dessus du plancher. Seule une requête à un
déploiement réel le disait. `bcryptjs` 3 est innocent : il garde une condition `require` vers une
livraison UMD, et c'est toute la différence entre les deux montées.

### Le correctif

`lib/auth.js` et `lib/apns.js` chargent `jose` par `await import('jose')`. C'est un import ESM
ordinaire, qu'aucun empaqueteur n'a à interpréter. Le module est chargé une fois et gardé ; le jeu
de clés d'Apple est construit à la première vérification au lieu de l'ouverture du fichier.

### `bcryptjs` 3, mesuré

Les empreintes déjà en base doivent continuer de se vérifier. Les deux versions installées côte à
côte : la 2.4.3 écrit `$2a$`, la 3.0.3 écrit `$2b$`, et **chacune vérifie l'empreinte de l'autre**.
Les mots de passe existants passent, et un retour en arrière reste possible. Coût 12 : 317 ms. La
licence passe de MIT à BSD-3-Clause.

### Les deux barrières

`ci_scripts/check_cjs.py` refuse un paquet livré en ESM seul chargé par `require`. Il a d'abord
signalé le fichier qu'il venait de faire corriger : le commentaire du correctif CITE
`require('jose')` pour expliquer pourquoi il n'est plus là, et le contrôle lisait ses propres
commentaires. Il les blanchit désormais, en suivant les chaînes pour ne pas couper sur le `//`
d'une URL.

`check_deploiement.py` refuse un 5xx depuis ce matin — c'est lui qui a vu la panne, vingt minutes
après avoir été écrit.

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

**Terminé, et vérifié en regardant les images.** Les trois captures neuves — inscription, mur
d'abonnement, course en cours — montrent bien ce qu'elles annoncent. Deux d'entre elles ne le
faisaient pas au premier essai, et le harnais était vert : l'inscription montrait l'accueil de
Charlotte (le stock SwiftData survit d'un lancement à l'autre, et sauter la graine ne l'efface
pas), la course en cours montrait le décompte de trois secondes (deux secondes d'attente ne
suffisaient pas). Les deux correctifs sont posés et les deux images sont justes.

Ce que la course en cours montre, maintenant qu'on la voit : la carte au niveau du continent
tant que le signal n'est pas pris — c'est l'état du simulateur, pas un défaut —, le bandeau
« Recherche du signal GPS… », le panneau de mesures avec ses tirets d'absence, et les trois
commandes. Elle se tient.


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
