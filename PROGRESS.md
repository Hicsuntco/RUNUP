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
| Et « maison » veut dire MetricKit, pas un gestionnaire de signal : Apple écrit que `backtrace` n'y est pas appelable, donc un rapport écrit là ne peut pas porter de pile d'appels. Voir le chantier 14. | l'équipe technique | 8 novembre 2026 |
| « ABONNÉ » → le libellé dit l'action (« SE DÉSABONNER ») | Charlotte | 7 novembre 2026 |
| « RETIRER » → une confirmation, pas un poids visuel différent | Charlotte | 7 novembre 2026 |
| `privacy.html` et `support.html` portés sur `main`, donc publiés : la politique dit maintenant ce que l'app collecte | Charlotte | 8 novembre 2026 |
| Fiche App Privacy d'App Store Connect corrigée et publiée : cinq types ajoutés, cinq passés de « non lié » à « lié », Product Interaction remis sur Analytics, Other Usage Data retiré | Charlotte | 9 novembre 2026 |
| Une carte de premiers jalons sur l'accueil, et des clubs proposés quand le champ de recherche est vide | Charlotte | 9 novembre 2026 |
| **D1 — les huit thèmes d'accent restent.** Le brief demandait une seule couleur d'accent ; l'app en propose huit au choix, et elles restent. Tout jeton dérivé doit donc être juste pour les huit, jamais écrit en dur. | Charlotte | 9 novembre 2026 |
| **D2 — fond clair par défaut, pas forcément chaud.** Le thème sombre était le défaut. Le `#FBF9F7` chaud du brief n'est pas imposé : le fond froid actuel peut rester. | Charlotte | 9 novembre 2026 |
| **D3 — la barre basse garde ses cinq entrées.** Le brief en demandait trois. | Charlotte | 9 novembre 2026 |
| **D4 — l'inscription reste longue, et vise le plan le plus sur mesure possible.** Le brief demandait trois questions ; la consigne est « fais au mieux pour quelque chose d'ultra sur mesure pour le plan ». La longueur du parcours n'est donc plus un défaut : sa qualité est le critère. | Charlotte | 9 novembre 2026 |
| **D1 à D4 tiennent, face au brief re-transmis.** Le brief d'origine demande une couleur d'accent unique, un fond blanc chaud, trois entrées de barre basse et une inscription en trois questions. Les quatre décisions du 9 novembre les emportent. | Charlotte | 11 novembre 2026 |
| **Le Club reste sous l'onglet Profil.** Mesuré : c'est le seul des trois différenciateurs annoncés qui soit à deux niveaux de profondeur, et le brief le voulait dans la barre. Proposé de le remonter à la place de Stats ; décision de ne pas le faire. Ne pas y revenir. | Charlotte | 11 novembre 2026 |
| **SF Symbols restent.** Le brief demande Phosphor ou Lucide au trait 1,5 px. 200 appels, et les SF Symbols suivent seuls la ligne de base, le poids de la fonte et les tailles d'accessibilité. Gain esthétique, coût structurel : non. | Charlotte | 11 novembre 2026 |
| **Les sept teintes d'intensité actuelles restent.** Le brief en donne cinq, en une seule valeur chacune ; l'app porte deux thèmes et huit accents, et `#F5A524` sur blanc donne 1,9:1. L'esprit du brief — une teinte fixe par intensité, la même partout — est déjà tenu. | Charlotte | 11 novembre 2026 |
| **Pas d'image iPad sur la fiche App Store.** « L'app iPad doit être différente, on ne va pas courir avec son iPad. » RUNUP est une app iPhone (`TARGETED_DEVICE_FAMILY` vaut 1) : Apple n'en demande aucune, et une mise en page iPhone étirée dans un cadre d'iPad n'est pas une app iPad. | Charlotte | 10 novembre 2026 |

## Ce qui attend une décision

| Question | Pourquoi ça bloque |
| --- | --- |
| Contenu des séances HYROX | Il faut quelqu'un qui a couru un HYROX. L'équipe n'a pas cette compétence et ne doit pas l'inventer. |
| Que faire des neuf commits de `claude/running-club-finance-wwuq46` | Mesurés le 9 novembre : ni sur `main` ni sur la branche de travail. Deux idées en ont été reprises (chantiers 16 et 17). Restent une direction artistique concurrente — **Oswald** en fonte d'affichage, quand la branche de travail a tranché pour Inter — et des retouches de profil dont l'équivalent existe. Rien ne presse ; la branche ne se supprime pas tant que ce n'est pas tranché. |
| Que faire de `ef3ad89`, sur `claude/new-session-otcd8z` | « La lecture des agrégats rentre dans `api/events.js` : douze fonctions, pas treize ». Quelqu'un s'est battu contre le même plafond Vercel, sur une autre branche, pour une autre fonctionnalité. Le code n'est nulle part ailleurs. |
| `main` et la branche de travail n'ont en commun que le commit initial | 853 commits d'un côté, 50 de l'autre, aucune fusion depuis le 13 juillet. Ça n'empêche rien, sauf pour `privacy.html` : la page dont l'adresse est sur la fiche App Store est servie par GitHub Pages **depuis `main`**, donc mise à jour à la main. `check_politique.py` compare la page publiée en ligne au dépôt. |
| Cette branche doit-elle rester la production ? | Elle l'est, confirmé dans les réglages Vercel le 7 novembre : `Settings → Environments → Production → Branch Tracking` porte `claude/runup-ios-swiftui-app-5b1yv6`. Donc aucune relecture, aucune préproduction. Les aperçus, eux, sont maintenant éprouvables — voir le chantier 11. |


## Au passage

**Une redondance en attente dans `privacy.html`.** « Aucun outil tiers de rapport de panne » y est
dit deux fois, à deux paragraphes d'écart — repéré le 8 novembre par Charlotte en cherchant la
phrase sur la page publiée. Ce n'est pas faux, c'est redondant, et ça ne valait pas un
aller-retour de plus sur `main` : cette page est servie par GitHub Pages depuis `main`, donc s'y
corriger demande de recopier le fichier à la main dans l'éditeur web. La consigne est écrite en
commentaire DANS le fichier, juste au-dessus du paragraphe concerné — c'est le seul endroit que
le prochain qui l'édite ouvrira forcément.


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

**J'ai écrit un affinage pour reprendre ce décalage sur le changement d'écran, et je l'ai
retiré.** Il a fait TROIS exécutions rouges — plus que le défaut qu'il visait — dont deux sur
des prises dont l'horloge était juste : −0,62 s une fois, −1,33 s une autre.

La cause n'est pas dans l'affinage, elle est dans `classer` : il reconnaît l'écran d'avant en
comparant chaque image à LA PREMIÈRE DE LA FENÊTRE. Ce choix n'est juste que pour une fenêtre
courte — le test laisse 0,6 s entre l'appui et le début du plan, donc sur 0,9 s le premier tiers
est encore l'écran précédent. Élargie à 2 s, la première image tombe n'importe où : au milieu
de la transition d'avant, ou sur un écran encore vide. « Avant » ne correspond alors presque à
rien, l'estimateur rend la longueur de la fenêtre, et l'affinage corrige d'autant. Les images
gardées par `--preuves` le montrent sans discussion : trois écrans VIDES, barre d'onglets seule.

Un affinage demanderait une autre référence pour « l'écran d'avant » — le témoin du plan
PRÉCÉDENT, que la passe claire photographie. C'est faisable, ce n'est pas écrit, et la note
au-dessus de `alignement` le dit. **En attendant, le défaut du plateau se solde par un film
REFUSÉ**, ce qui est le comportement sûr : les images partent, le film faux ne part pas.

**Trois erreurs de ma part sur ce seul sujet.** D'abord j'ai cru que l'instant où l'on regarde
était en cause, et l'exécution suivante a rendu le même −0,75. Ensuite une fenêtre d'affinage
qui ne couvrait pas le cas qui l'avait motivé. Enfin l'affinage lui-même, trois fois rouge.

**Ce qui reste de ces tentatives, et qui est bon.** `instant_du_changement` prend la DERNIÈRE
image de l'écran d'avant et non la première qui n'en est plus — même nombre sur une fenêtre
propre, ce qui explique que tous les cas fabriqués passaient, et immunisé contre un
clignotement.

**Et une question qui était mal posée depuis le début.** « À quel instant juger un plan » a eu
quatre réponses dans la journée, et les trois premières étaient fausses : `debut + 0,5 s`
tombait avant la pose des écrans lents (0,57 s mesuré) ; `fin − 0,25 s` dans l'action suivante,
car les plans sont CONTIGUS, et pour le dernier plan dans le démontage du test ; le MILIEU sur
l'écran des Stats DÉJÀ DÉFILÉ — le test fait défiler pendant le plan, et pas toujours au même
moment. Il n'existe pas d'instant unique qui soit sûr sur les quatre plans à chaque exécution.

Ce qu'on veut savoir n'est pas « quel écran y a-t-il à cet instant précis », c'est « le film,
coupé sur ce plan, montre-t-il le bon écran ». Le plan dure deux secondes et le film les montre
toutes : il suffit qu'il CONTIENNE le bon écran. On regarde donc trois instants répartis dans
le plan et on garde le meilleur. Un plan posé sur le MAUVAIS écran — le décalage de trois
secondes qui a sorti trois films faux — n'a aucun instant qui corresponde, et reste refusé ;
deux cas éprouvent les deux moitiés de la règle.

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

**Une feuille ne se présente que si la vue qui la porte est à l'écran, et deux ne l'étaient
pas.** Relevé pour chacune des douze feuilles de `ClubView` : la vue qui la PORTE, et celle qui
la DÉCLENCHE. « Modifier ce message » est sur le mur et sa feuille était sur l'Aperçu — les
onglets s'excluent, donc le bouton ne faisait RIEN, et la feuille surgissait plus tard sans
qu'on l'ait demandée. « Proposer une sortie » sur la carte qui propose de RÉVEILLER le club
avait le même défaut : `if clubEnSommeil { carteClubAReveiller } else { eventsCard }`, et la
feuille était sur la seconde. Sur un club endormi — le cas même où cette carte existe — le
bouton ne faisait rien. Les deux remontent au corps ; les dix autres étaient chez elles.

L'audit a ensuite été passé sur LES 111 FICHIERS DE VUES de l'app, pas seulement sur le
Club : cinq feuilles sont portées par une vue autre que celle qui les déclenche, et trois sont
des faux positifs — le déclencheur est dans la même branche, l'heuristique ne sait pas le voir.
Les deux du Club étaient les seules vraies. **Ce n'est pas devenu un contrôle** : trois faux
positifs sur cinq feraient un garde-fou qu'on contourne, et savoir si deux vues sont dans la
même branche demande l'arbre d'affichage, que rien ne lit sans exécuter l'app.

**Le chantier 13 s'est arrêté sur une mesure, pas sur une longueur.** Pour chacune des trois
régions qui restaient dans `ClubView`, j'ai compté ce qu'elle citerait de l'extérieur si on la
sortait :

| région | lignes | ports | lignes par port |
| --- | ---: | ---: | ---: |
| les sorties de groupe | 228 | 4 | 57 |
| le mur | 273 | 11 | 25 |
| l'entrée du club | 120 | 8 | 15 |

Les sorties sont parties. Les deux autres non : leurs actions — signaler, bloquer, commenter,
modifier, supprimer — sont PRÉSENTÉES par le parent, donc chaque bouton devient un port. Les
sortir échangerait de la longueur de fichier contre de la surface d'interface, ce qui n'est pas
un gain. `ClubView` reste donc le plus gros fichier de vues de l'app, 1 358 contre 1 172 pour
`HomeView`, et c'est assumé.

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
| 12 | Accessibilité : tailles de texte dynamiques, indices VoiceOver | 1,5 j | **fait** — sept écrans photographiés au deuxième cran, treize défauts vus et corrigés ; le reste mesuré et fermé, voir plus bas |
| 13 | `ClubView.swift`, 2 721 lignes, à découper | 2 j | **fait** — 2 721 → 1 358 lignes, en six fichiers ; zéro pixel d'écart |
| 14 | Rapport de plantage maison, posté sur notre serveur | 1,5 j | **fait** — par MetricKit, sans aucun gestionnaire de signal ; voir plus bas pourquoi |
| 15 | Les erreurs qu'on avale : audit des 275 `try?` et `catch` | 1 j | **fait** — un défaut qui perdait des courses, et du code mort qu'un test tenait en vie |

Le 14 est arrivé après coup, et il est passé devant les finitions de design : c'est le seul moyen
de savoir ce qui casse chez quelqu'un d'autre que nous. Le reste de l'ordre tient.

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

## Chantier 44 — la version 3.4, et l'élagage qui ne s'est pas fait tout seul

### Ce qui était attendu, et ce qui s'est passé

La note disait : « créer la version 3.4, la capture iPad s'élaguera d'elle-même ». C'était vrai
d'une seule façon de créer la version — le bouton `creer-la-version`, qui appelle
`asc.py create-version` et élague d'office les formats de `FORMATS_SANS_RAISON`.

La version a été créée depuis le site d'App Store Connect. Apple y recopie les captures de la
version précédente, **tous formats confondus**, et aucun élagage n'a eu lieu. L'inventaire de la
3.4 le disait noir sur blanc :

```
fr-FR · APP_IPAD_PRO_3GEN_129 · 1 image(s)
    1-accueil.png
```

Une image d'iPad fabriquée à partir d'une mise en page iPhone étirée, sur une app dont
`TARGETED_DEVICE_FAMILY` vaut 1, et que Charlotte avait décidé de retirer le 10 novembre.

### Ce qui a été fait

`nettoyer-les-captures`, format `APP_IPAD_PRO_3GEN_129`, après un essai à blanc qui a confirmé la
portée : **une seule image, et la capture Apple Watch pas touchée** — celle-là, Apple l'exige dès
que la build embarque une app watchOS, et une première version de l'élagage l'avait emportée.

Inventaire après : trois langues × six captures iPhone, plus la capture de la montre. Plus d'iPad.

### Ce que la note aurait dû dire

« La capture iPad s'élaguera d'elle-même **si la version est créée par le bouton**. » Une
instruction qui ne dit pas de quoi elle dépend n'est pas une instruction, c'est un pari — et ici
le pari se perdait en silence, parce que rien dans App Store Connect ne signale qu'une image
recopiée n'avait rien à faire là.

### Ce que le contrôle de soumission a trouvé au passage

`pourquoi-pas-soumettable` sur la 3.4, après l'élagage :

- état PREPARE_FOR_SUBMISSION, informations de vérification présentes, abonnement APPROVED ;
- six captures et un aperçu vidéo par langue, description présente ;
- **« nouveautés NON » dans les trois langues.**

Les notes de version existent dans `APP_STORE_LISTING.md` mais n'ont jamais été poussées vers la
3.4. Et surtout : leur dernière modification est le commit du 1er novembre, « Les nouveautés de la
3.3 parlent enfin de ce que la 3.3 contient ». **Ce sont les notes de la 3.3.** Les pousser telles
quelles afficherait aux gens, sous une mise à jour 3.4, la liste de ce qu'ils ont déjà reçu.

C'est le seul point qui reste entre la 3.4 et une soumission, et il demande un texte, pas une
commande.

### Suite, le même jour

Les notes ont été écrites dans les trois langues, poussées, et Apple les a reçues — `fr-FR mis à
jour, en-US mis à jour, es-ES mis à jour`, puis vérifié côté Apple plutôt que sur le message de
l'outil qui venait de les envoyer : « description oui, **nouveautés oui** » dans les trois langues.

`pourquoi-pas-soumettable` ne rend donc plus qu'une ligne :

```
CE QUI MANQUE :
  - aucune build n'est attachée
```

La fiche est complète. Ce qui manque est une build en 3.4, c'est-à-dire un passage de la chaîne
TestFlight — pas un texte.

### Un détail vu en passant, et qui répond à une question ouverte

Le `supportUrl` envoyé à Apple est `https://hicsuntco.github.io/RUNUP/privacy.html`. Autrement
dit, le lien « Assistance » de la fiche App Store ouvre la politique de confidentialité. La
question « que faire de `support.html`, que personne ne peut atteindre » traînait depuis le
8 novembre : la réponse est qu'elle n'est pas seulement inatteignable, elle est **remplacée par la
mauvaise page** à l'endroit même où Apple la propose.

## Chantier 43 — Apple recevait un tracé à moitié dessiné, et c'était au hasard

### D'abord, ce que la comparaison a prouvé

Campagne 166 contre 165, **même jour**, 181 images : **169 identiques**. `fil` — l'écran que le
mur dessine — est identique dans les trois langues et les deux thèmes, comme les trois autres
écrans du Club. La découpe du chantier 42 n'a rien changé.

Huit des douze écarts sont `course-en-cours`, l'horloge. Restaient `4-club.png` en espagnol
(10 077 pixels) et en français (5 pixels), et une boîte de 24 pixels sur `grand-texte/accueil`.

### Ce que l'image montrait

Le tracé de la sortie, en bas de la carte. Dans la campagne 165 la ligne se termine net. Dans la
166, **une tête blanche lumineuse est posée au milieu du dernier segment, et la ligne s'arrête
avant sa fin**.

`SelfDrawingRoute` dessine le parcours en 1,45 s à l'apparition. La campagne 166 a pris la photo
pendant. La 165, six heures plus tôt, l'avait eu fini.

**`4-club.png` est une des six images livrées à Apple.** Ce n'est donc pas un défaut de
comparaison : c'est le minutage qui décidait de ce qu'Apple reçoit, et il pouvait tout aussi bien
tomber à 60 % du tracé.

### La règle, et pourquoi elle est posée là

**Une photo montre un écran posé. Un film garde son mouvement.** Les deux tournent dans le même
mode démonstration, et c'est pour ça que le défaut a vécu : « pas d'animation en démonstration »
aurait aplati le film d'aperçu, dont c'est tout l'intérêt.

La distinction tient à un argument de lancement, `--film`, posé par `ApercuUITests` et par lui
seul. **Le drapeau est sur le film, pas sur les photos**, et le sens compte : oublier de déclarer
un film donne un film sans mouvement, ça se voit en le regardant ; oublier de déclarer une photo
ramène le non-déterminisme EN SILENCE. C'est le sens où l'erreur se voit.

### Figer en un seul endroit

Une `transaction` à la racine des vues, qui vide l'animation de tout ce qui passe en dessous.

C'était le choix contre lequel il fallait se décider : corriger `SelfDrawingRoute` seul aurait
réglé le cas observé et laissé les autres. Mesuré : l'app compte **22 appels à `RUMotion`** et
**une cinquantaine d'animations écrites à la main** dans les vues — dont l'apparition en cascade
du fil et le ressort des anneaux de l'accueil, tous deux sur des écrans photographiés. Les
corriger une par une aurait laissé la cinquante et unième dehors sans que rien ne le dise.

### Ce qui le garde

`check_film.py` et ses **7 cas** vérifient les cinq faits lisibles dans le code : le film se
déclare, les photos ne se déclarent pas, l'app allume le mode film, la règle dit bien « en
démonstration ET pas en train de filmer », et la racine applique une `transaction`.

**Sa première version ne voyait rien.** Elle cherchait `--film` dans le fichier entier — or le
commentaire qui explique le drapeau contient le drapeau, et celui qui explique la `transaction`
contient `animationsFigees`. Retirer le vrai code laissait le contrôle vert : il relisait sa
propre explication. Deux cas du banc tiennent cette correction, et c'est exactement le piège que
`check_vides` avait rencontré en novembre.

### Ce qui le prouve

**Campagne 167, à 13 h 55, contre la 166 à 12 h 43 — même jour.** 171 images sur 181 identiques.
Neuf des dix écarts sont `course-en-cours`, le chronomètre d'une course en cours.

Le dixième est `4-club.png` en espagnol, et c'est le verdict : il est **identique à celui de la
campagne 165**, celle qui avait eu le tracé fini. Autrement dit, 167 est revenue à l'état posé, et
c'est bien la 166 qui était l'exception.

Sur les six variantes de `4-club.png`, cinq sont identiques au pixel entre 165 et 167. La sixième
diffère de **13 sur 255 au maximum, sur cinq pixels** — de l'anticrénelage sur le bout arrondi du
trait, sous le seuil de bruit de l'outil et invisible à l'œil.

**Et le film garde son mouvement** — vérifié plutôt que supposé, parce que « Filmer l'aperçu »
réussit même si le film ne bouge pas : aucune étape ne juge son contenu. Mesuré en extrayant les
images à 10 par seconde et en comparant chaque image à la précédente :

| | images qui bougent | écart moyen entre deux images |
| --- | --- | --- |
| campagne 166, avant | 16 % | 1,10 |
| campagne 167, après | **27 %** | **1,75** |

Plus de mouvement qu'avant, pas moins. Le drapeau est du bon côté.

### Ce qu'aucun script ne saura dire

Si l'image est effectivement posée. Aucun contrôle ne lit une animation. La preuve reste la
comparaison de deux campagnes prises à des heures différentes — ce qui est précisément comment
ce défaut a été trouvé, et pourquoi le chantier 40 valait la peine.

## Chantier 42 — le mur, et les onze fils qu'il fallait ne pas confondre (B5, dernier morceau)

### Pourquoi celui-ci n'était pas un déplacement

Les quatre cartes sorties avant lui demandaient zéro ou un état : c'est ce qui les rendait sûres,
et c'est pour ça qu'elles sont passées en premier. Le mur en touchait **onze sur les dix-huit** de
`ClubView`.

Onze n'est pas un signe de complexité, c'est un signe que **personne ne les possédait**. Ils
traînaient à plat dans la grande vue, et sortir le mur tel quel aurait voulu dire passer onze fils
à la main — chacun une occasion de brancher le mauvais, sans que rien ne le dise, dans un
remaniement qui ne doit RIEN changer.

### Ce qui a été fait

**`MurDuClub`** porte les huit qui sont vraiment du mur : le brouillon, l'envoi en cours, la
réponse en cours, les quatre feuilles qu'il ouvre et le drapeau de révélation du fil.

**Les deux autres restent dehors, et ce n'est pas un oubli.** `reportTarget` et `pendingBlock`
sont posés aussi par le classement et par la page du club ; les ranger dans le mur aurait fabriqué
un propriétaire faux. Ils passent en liaison, comme ils le faisaient déjà vers `ClubBoardSection`.
Deux liaisons au lieu de onze, et les deux qui restent sont celles qui le méritent.

**`ClubWallView`** prend le magasin, le mur et ces deux liaisons.

`ClubView` : **979 → 707 lignes**, 11 états au lieu de 18. Depuis le début de B5 : **1 425 → 707**.

### Le vrai gain : trois règles qui n'étaient vérifiables nulle part

Elles vivaient en propriétés privées d'une vue de 1 400 lignes, donc vérifiables seulement en
ouvrant l'écran avec les bonnes données — un message, sa réponse, une sortie du même jour —
c'est-à-dire jamais. Chacune porte une décision qui n'était écrite nulle part :

- **une réponse n'entre pas dans le fil**, elle s'affiche sous son message. C'est la moins visible
  des trois, et sa disparition ne casse rien : le fil se remplit simplement de répliques qui n'ont
  plus de question au-dessus d'elles ;
- **les sorties et les messages s'entrelacent par date**, ils ne s'empilent pas en deux listes. Un
  mur posé au-dessus des sorties se lit comme une annonce épinglée ;
- **les réponses se lisent dans l'ordre inverse du fil** — du plus ancien au plus récent. Un fil
  se lit du plus récent parce qu'on vient voir les nouvelles ; une conversation se lit dans
  l'ordre où elle s'est tenue. Deux tris opposés sur le même écran est exactement le genre
  d'écart qu'on « corrige » en croyant bien faire.

Et `peutPublier`, où `isEmpty` seul laisserait passer trois retours à la ligne.

`MurDuClubTests`, **11 cas**, avec des données **décodées depuis du JSON** plutôt que construites
à la main : `ClubPost` et `FeedItem` viennent du serveur, et une fixture écrite avec un `init`
mémberwise cesserait de ressembler à ce que l'app reçoit.

### Une troisième copie évitée de justesse

`seuleDansSonClub` était lue par le fil ET par l'Aperçu. Le chantier 37 avait déjà nommé cette
règle une fois après l'avoir trouvée écrite deux fois mot pour mot. En sortant le mur, le fil en
avait besoin dans un autre fichier : la recopier aurait refait exactement le défaut qu'on venait
de corriger. Elle descend donc sur `ClubStore` — c'est un fait sur le club, pas sur un écran.

### Le piège que le fichier portait déjà écrit

`MurDuClub` est `@MainActor`, et `ClubView.init` l'est explicitement avec sa raison en commentaire :
« construire un objet isolé au fil principal depuis un contexte qui ne l'est pas est une ERREUR DE
COMPILATION, pas un avertissement — et il n'y a pas de compilateur Swift ici pour la voir ». Le mur
est donc construit dans l'`init` comme le magasin, et non en valeur par défaut qui dépendrait de ce
que le compilateur déduit.

### Deux défauts de ma propre extraction, attrapés en relisant

Le renommage automatique en a produit deux que la chaîne ne pouvait pas voir :

- `if let reponseA = mur.reponseA { … Text(mur.reponseA.author…) }` — la variable déballée était
  redevenue optionnelle à l'intérieur de son propre bloc ;
- `reponses(a: message)` n'a pas été remplacé, parce que mon motif terminait par `\b` après une
  parenthèse fermante, où il ne peut pas s'accrocher.

Les deux sont des erreurs de compilation, donc sans danger pour la production — mais à quarante
minutes de machine d'ici. C'est la relecture du fichier produit qui les a trouvées, pas la chaîne.

## Chantier 41 — une bannière d'iOS ne coûte plus une heure

### Ce qui était faux

iOS pose parfois une notification en travers d'une capture. Deux fois en trois jours : le
8 novembre sur `1-accueil.png` — une des six images livrées à Apple — et le 10 sur
`club-classement.png`, 60,1 % de pixels clairs en haut pour un plafond à 25.

`check_banniere.py` l'attrape, et c'est l'essentiel : rien de fautif ne part chez Apple. Mais il
l'attrape **à la fin de la chaîne**, après les deux passes de prise de vue, la composition et les
contrôles d'image. La campagne échoue donc au bout d'une heure, et la relancer en coûte une autre.

### Ce qui a changé

La passe sombre se relit **langue par langue, juste après l'avoir prise**, et se reprend une fois
si une bannière est tombée dessus. Une langue à refaire, c'est deux ou trois minutes, et ça reste
dans la même exécution.

**Une seule reprise, volontairement.** Une bannière est une affaire de minutage ; si la seconde
prise la revoit, ce n'est plus le minutage, et le contrôle de fin doit échouer pour qu'on aille
regarder l'image. Deux essais qui échouent valent un signal, dix valent une boucle qui cache un
défaut.

L'environnement Python remonte avant les captures — il vivait dans « Composer les images
finales », c'est-à-dire après la prise de vue, et le contrôle qui se relit a besoin de Pillow.

### Ce qui n'est pas repris, et c'est écrit sur place

**La passe claire.** Le contrôle ne sait pas la lire : une bande claire sur un écran clair ne dit
rien, et il le déclare lui-même — « seules les captures SOMBRES sont regardées ». Reprendre une
passe qu'on ne sait pas juger serait un geste sans mesure derrière.

### Ce qui le prouve

La logique de reprise a été éprouvée ici, sur les **vrais dossiers** des campagnes 161 (celle qui
portait la bannière) et 163 (propre) :

| première prise | reprise | résultat |
| --- | --- | --- |
| propre | — | vert, **aucune** reprise |
| bannière | propre | vert, **une** reprise |
| bannière | bannière | **rouge**, une seule reprise |

Le troisième cas est celui qui compte : la boucle ne s'acharne pas, et l'échec reste visible.

### Ce qui n'a pas été fait, faute de source

Empêcher le simulateur de poser des bannières. Je n'ai trouvé aucune clé documentée pour ça, et
une recette inventée qui marche par hasard est pire qu'une reprise explicite.

## Chantier 40 — la capture héritait de l'heure de la machine

### D'abord, ce que la comparaison a prouvé

Campagne 162 contre campagne 160, 181 images. **Les quatre écrans du Club sont identiques au
pixel** — `club-apercu`, `club-apercu-bas`, `club-classement`, `fil`. Les trois découpes des
chantiers 36, 37 et 38 n'ont rien changé, et c'est prouvé par l'image.

### Et ce qu'elle a trouvé en passant

Vingt-six images diffèrent. `course-en-cours` est l'horloge, connue. Mais **`profil`,
`profil-bas` et `grand-texte/profil` diffèrent dans les trois langues et les deux thèmes** — neuf
images, systématiquement. Aucune de mes découpes ne touche cet écran.

En regardant les deux images : **« Badges · 6 sur 16 » est devenu « 7 sur 16 »**, « Course de
nuit » est allumé, et tous les badges suivants sont décalés d'une case. Et la carte des amies est
passée de « 2 sorties aujourd'hui » à « 3 ».

### La cause, vérifiée et non supposée

`ClubBadgeEngine` lit l'heure de chaque sortie : `heure < 7` donne « Lève-tôt », `heure >= 21`
donne « Course de nuit ». Or `CaptureSeed.historique` plantait chaque sortie à
`maintenant - N jours` — donc **à l'heure où la machine tourne**.

La campagne 160 a tourné à 18 h UTC, la 162 à 22 h. Le même code rend donc six badges ou sept
selon l'heure de la journée.

Deuxième manifestation, sur la même image : les trois activités d'amies sont posées 3 h, 9 h et
22 h en arrière, et `ProfileView` compte celles du jour. « Il y a 22 h » est HIER à 6 h du matin
et AUJOURD'HUI à 23 h.

**Et celle-là, `comparer.py` ne l'a pas vue.** Je l'ai vue à l'œil en ouvrant les deux images, et
j'ai d'abord cru qu'elle faisait partie de l'écart mesuré : c'est faux. La carte « Amis » vit dans
les 186 px du haut, que l'outil masque pour ignorer l'heure — iOS dessine l'heure par-dessus
l'app, et sur une capture prise au milieu d'un défilement cette bande porte du contenu. Un « = »
de cet outil veut donc dire « identique sous les 186 premiers pixels ». La limite est maintenant
écrite dans son en-tête.

**Et `4-club.png` est une des six images livrées à Apple.** Selon l'heure de la campagne, Apple
recevait un profil avec le badge « Course de nuit » ou sans.

### La troisième fois, dans le fichier qui porte déjà la leçon

`CaptureSeed.swift` contient, depuis un chantier précédent, cette phrase sur les sorties de
groupe : « un décalage en heures depuis l'instant de la capture donne “DEMAIN · 13:01” ou
“VEN. · 06:01” selon le moment où la machine a pris la photo ». La correction y est : l'heure est
posée, le jour calculé.

`CaptureSeedHeureTests.swift` porte la même leçon pour la conversation du coach, avec son
en-tête : « deux exécutions comparées, à 01 h 18 et 04 h 37, s'accordaient ; une troisième à
07 h 00 ne s'accordait plus ».

L'historique des sorties et les activités d'amies ne l'avaient pas. Trois cas frères, deux
corrigés, un oublié — le motif est exactement celui des chantiers 30 et 31.

### Ce qui a changé

- **L'heure de chaque sortie est posée**, et le jour continue de suivre la campagne : sortie
  longue à 9 h, fractionné à 19 h comme une séance de club, le reste à 8 h ou 18 h. Toutes dans
  `7..<21`, donc aucun des deux badges horaires ne s'allume par accident. La minute vient du rang,
  pas de l'horloge — seize sorties à l'heure pile sentiraient la donnée fabriquée.
- **Les trois activités d'amies sont bornées au jour**, exactement comme la conversation du coach :
  le recul est gardé tant qu'il tient dans la journée, raboté au début du jour sinon. Un recul ne
  peut pas être à la fois stable en affichage relatif et stable en jour ; c'est le jour qui porte
  un nombre à l'écran, donc c'est lui qu'on stabilise.

### Ce qui a été mesuré et ne pose pas de problème

Le JOUR DE LA SEMAINE des sorties dérive toujours avec la date de campagne, et le badge
« Guerrière du week-end » se lit dessus. Compté sur les sept jours possibles, le nombre de sorties
de week-end va de **0 à 6** — et le badge en exige **dix**. Il n'est donc jamais atteint, quelle
que soit la date. Vérifié, pas supposé.

### Ce qui reste instable, et pourquoi on ne le corrige pas

Les horodatages RELATIFS du fil du club — « il y a 3 h » — dépendent de l'heure de la campagne par
construction, et c'est ce qu'on veut : un fil doit dire depuis combien de temps. C'est ce qui fait
différer `4-club.png` dans une petite boîte d'une centaine de pixels. Un texte de largeur
différente n'est pas un défaut ; un badge qui apparaît en était un.

### Ce qui le prouve

La campagne **163 a tourné à 23 h** — plus tard encore que la 162, qui est celle qui avait allumé
le badge. `profil-bas.png` y est **identique à celui de la campagne 160**, qui avait tourné à
18 h, dans les trois langues et les deux thèmes. Deux campagnes de part et d'autre de l'heure qui
faisait basculer le badge rendent la même image.

Et le cas était plus dur qu'il n'y paraît : à 23 h l'ancien code allumait « Course de nuit », et à
00 h il aurait allumé « Lève-tôt ». La campagne 163 a photographié les deux côtés de minuit sans
que rien ne bouge sur cet écran.

**Ce qui ne se compare pas d'une campagne à l'autre quand elles ne tombent pas le même jour.** La
163 a commencé à 23 h 39 et fini après minuit : 73 images diffèrent de la 162, et c'est normal —
le plan, l'accueil et le bilan hebdomadaire parlent d'aujourd'hui. Une comparaison à cheval sur
minuit ne prouve rien sur une découpe. C'est pour ça que la preuve de B5 tient sur 160 → 162,
deux campagnes du même jour.

### Ce qui le garde

Six cas de plus dans `CaptureSeedHeureTests`, qui éprouvent **les vingt-quatre heures** plutôt
que d'attendre que l'heure qui casse tombe toute seule :

- aucune sortie de l'historique ne tombe avant 7 h ni après 21 h, à toute heure de campagne ;
- plus largement, l'heure de la campagne ne change **aucune** heure de l'historique — le cas
  précédent ne tient que les deux bornes, celui-ci tient la reproductibilité ;
- le JOUR, lui, suit toujours la campagne : la sortie la plus récente reste à deux jours ;
- chaque type de séance a une heure plausible — le jour où quelqu'un en ajoutera un, le cas lui
  rappellera que l'heure se décide ;
- les trois activités d'amies tombent aujourd'hui à toute heure ;
- et un recul qui tient dans la journée n'est PAS raboté, sans quoi le fil afficherait trois fois
  la même minute.

## Chantier 39 — une non-réponse était plus optimiste que la réponse la plus prudente

### Ce qui était faux

`PaceModel` portait trois VDOT écrits en dur pour le niveau déclaré : 36,34 / 43,61 / 53,94. Le
chantier 29 les avait laissés intacts exprès, en écrivant pourquoi : « un VDOT de 36 est un 10 km
en 54 minutes, ce qui n'est pas “débutante” mais “court déjà” », et « une constante devinée deux
fois ne vaut pas mieux qu'une fois ». La tâche a attendu une mesure.

La mesure n'était pas celle que j'attendais. Je cherchais ce que courent les gens qui cochent
« débutante » — donnée que personne n'a ici, et qui n'existe pas dans l'app. Ce qui se mesure,
c'est une **incohérence interne**, et elle se vérifie en trois lignes.

Converties à la fraction du footing, les trois constantes supposent des footings de :

| niveau | ce que la constante supposait | 5 km équivalent |
| --- | --- | --- |
| débutante — « je cours depuis moins de 6 mois » | **6:54/km** | 26:08 |
| intermédiaire — « je cours 2-3 fois par semaine » | **5:58/km** | 22:23 |
| confirmée — « je m'entraîne sérieusement depuis des années » | **5:02/km** | 18:40 |

Or l'app pose elle-même la question de l'allure de footing, et sa tranche la plus lente est
**« plus de 7 min/km »**. Donc quelqu'un qui se déclarait débutante et répondait « je ne sais pas »
— une vraie réponse, la première de la liste, prévue pour ça — recevait un plan calé sur
**6:54/km, plus rapide que la tranche la plus prudente qu'on lui proposait de cocher**.

Une non-réponse était plus optimiste que la réponse la plus prudente. Et c'est exactement au
niveau « débutante » que vivent les gens qui courent à plus de 7 min/km.

### Ce qui a changé

Les trois constantes ne sont plus des nombres : chaque niveau désigne **la tranche de footing
qu'elle aurait probablement cochée**, et les deux chemins passent ensuite par le même
`Vdot.depuisAllure(…, fraction: .footing)` sur la même valeur.

| niveau | tranche supposée | 5 km | 10 km | avant |
| --- | --- | --- | --- | --- |
| débutante | 7:30/km | 28:35 | 59:25 | 26:08 / 54:16 |
| intermédiaire | 6:30/km | 24:29 | 50:49 | 22:23 / 46:27 |
| confirmée | 5:30/km | 20:28 | 42:27 | 18:40 / 38:43 |

La quatrième tranche — « moins de 5 min/km » — ne s'atteint **que** si elle la coche. Un libellé
qu'on touche pour se décrire ne doit pas suffire à produire un footing sous les cinq minutes.

**Et il n'y a plus trois nombres à maintenir.** C'était le vrai risque : ce calcul a déjà connu un
aller-retour qui se trompait des deux côtés à la fois et dans des sens opposés — le `/ 1.20` du
chantier 29. Deux chemins pour une question, une seule valeur, un seul appel.

### Ce que ça change pour les gens

Pour tout le monde qui n'a donné ni chrono, ni perf récente, ni allure de footing : **les allures
de son plan ralentissent**, de 8 à 9 % selon le niveau. Personne ne perd son plan, et rien ne
change pour qui a donné un chrono ou une allure — leurs trois chemins passent avant celui-ci.

C'est une décision d'entraînement, et elle se discute : elle suppose que quelqu'un qui ne sait pas
dire son allure n'est pas en train de courir plus vite que la tranche médiane de sa catégorie.
L'inverse est possible pour une minorité, et le plan s'ajuste ensuite sur les sorties réellement
enregistrées. Dans le doute, le sens de l'erreur compte : un plan trop lent se corrige à la
première sortie loguée, un plan trop rapide se corrige à la blessure.

### Ce qui le garde

Cinq cas dans `PointDeDepartTests` :

- **le défaut lui-même** — le niveau débutante ne peut pas être plus rapide que la tranche la plus
  lente de la liste, et il doit viser précisément celle-là ;
- le niveau seul vaut **exactement** la tranche qu'il suppose, à 1 ms près : si l'un des deux
  chemins est retouché sans l'autre, le cas tombe ;
- aucun niveau n'atteint la tranche la plus rapide ;
- les trois niveaux restent ordonnés ;
- aucun niveau ne désigne « je ne sais pas », sans quoi le repli du repli — `Vdot.vdotMin` —
  deviendrait le plan de tout un niveau sans que rien ne le dise.

### Ce que l'image ne prouvera pas

**Les captures ne montreront aucune différence, et c'est normal.** Le profil de démonstration
donne `bestRecentPerf: "10 km en 49:12"` — le PREMIER des quatre chemins — donc il n'atteint
jamais la constante de niveau. Les 28 écrans photographiés sont rigoureusement identiques avant et
après.

Autrement dit : la seule preuve de ce chantier est ses cinq cas de test. Aucune capture ne montre
jamais cet écran-là, parce qu'aucun profil de démonstration ne laisse les trois premières questions
vides. C'est une limite réelle de la campagne de captures, et elle mérite d'être écrite plutôt que
découverte en comparant deux images identiques et en concluant que rien n'a changé.

### Ce qui n'a pas bougé, et pourquoi

Les quatre tranches de footing et leur milieu (7:30, 6:30, 5:30, 4:30). Leur commentaire porte un
raisonnement qui tient et qui va dans l'autre sens que l'intuition : pour une **allure**,
sous-estimer n'est pas prudent — ça donne des footings trop lents que personne ne tient et des
séances de qualité qui n'en sont plus. Le milieu de la tranche déclarée reste la réponse honnête.
Ce chantier ne touche qu'au cas où **rien** n'a été déclaré.

## Chantier 38 — l'écran « tu n'as pas encore de club » (B5, quatrième morceau)

### Ce qui est sorti

`ClubSetupCard` — 118 lignes de code, le magasin et **deux liaisons** : les deux champs de
saisie, `newClubName` et `clubQuery`. Tout le reste passe par le magasin, qui porte déjà
`createClub`, `joinClub`, `clubSearchEnCours`, `clubResultats`, `clubSuggestions` et
`chargerLesClubsSuggeres`. Le magasin faisait déjà le travail ; la vue n'avait qu'à le suivre.

Les deux lignes de résultat descendent avec elle — `ligneDUnClubARejoindre` et
`ligneDuClubTrouve` — parce qu'elles n'ont aucun autre appelant. Leur commentaire dit déjà
pourquoi elles sont uniques : « deux vues presque identiques auraient dérivé à la première
retouche, et l'écart se serait lu comme une différence de nature entre un club trouvé et un club
proposé ».

`ClubView` : **1 113 → 979 lignes.** Depuis le début de B5 : **1 425 → 979**, et six fichiers
nommés par ce qu'ils montrent.

### `signInPrompt` reste

14 lignes, une liaison. Un fichier pour quatorze lignes coûte plus à lire qu'il ne fait gagner :
on ouvre un fichier de plus pour voir un bouton « SE CONNECTER ». Le critère de la découpe n'a
jamais été le nombre de lignes du fichier d'origine, c'est qu'une section ait un nom et un état
propre. Celle-là a un nom et presque pas de corps.

### Une section `// MARK:` devenue vide

`// MARK: Signed in, no club yet` ne précédait plus rien. Un intertitre qui ne titre plus rien ne
casse pas la compilation et ne se voit pas en lisant le code autour : il se voit à la couture,
juste après avoir retiré ce qu'il annonçait. Retiré.

### Ce qui prouve les chantiers 37 et 38

**Une seule campagne de captures pour les deux.** Les deux découpes ont été poussées ensemble,
parce que pousser pendant qu'une campagne tourne l'annule — c'est ce qui a fait perdre le run 159.
La comparaison porte donc sur les deux d'un coup, contre la campagne du chantier 36. Pour une
découpe qui ne doit rien changer, c'est le même verdict : identique au pixel, ou pas.

## Chantier 37 — un seuil écrit deux fois, trouvé en découpant (B5, troisième morceau)

### Le plan était plus grossier que le code, pour la deuxième fois sur ce même fichier

Le chantier 35 annonçait « Rejoindre / réveiller : 231 lignes, 4 états ». Mesuré membre par
membre : **286 lignes et six états**. Et surtout, ce n'est pas un groupe. Les huit membres que
j'avais rangés ensemble font trois choses sans rapport :

| ce que ça fait | membres | états |
| --- | --- | --- |
| trouver ou créer un club quand on n'en a pas | `signInPrompt`, `clubSetupCard`, `ligneDUnClubARejoindre`, `ligneDuClubTrouve` | `clubQuery`, `newClubName`, `showSignIn`, `magasin` |
| réveiller un club endormi | `carteClubAReveiller` | `showCreateEvent`, `showManagement` |
| dire qu'on y est seule | `carteClubSeul` | `magasin` |

`banniere` n'appartenait à aucun des trois : elle est appelée depuis `body`, au-dessus de tout.

### Ce qui est sorti, et pourquoi ces deux-là d'abord

- `ClubAloneCard` — 53 lignes de corps, **zéro liaison**, le magasin seul. Elle était déjà
  appelée **depuis deux onglets** : l'Aperçu et le fil. Son commentaire disait pourquoi on ne
  l'avait pas recopiée — « un lien de partage dupliqué, c'est une des deux copies qui garde
  l'ancienne URL le jour où elle change ». La sortir du fichier ne change rien à ce partage ; ça
  le rend lisible depuis le nom du type.
- `ClubWakeCard` — 40 lignes, **deux liaisons et aucun magasin**. Elle n'affiche aucune donnée du
  club : deux boutons, c'est tout. C'est ce qui la rend bon marché malgré ses deux états.

`ClubView` : **1 193 → 1 113 lignes**, et le quatrième groupe du chantier 35 — « trouver ou créer
un club » — attend son tour.

### Le défaut trouvé en découpant : un seuil écrit deux fois

`magasin.board.club.map({ $0.memberCount <= 1 }) == true` était écrit **mot pour mot à deux
endroits** — une fois dans l'Aperçu, une fois dans le fil — chacun pour choisir entre la carte de
partage et autre chose. Les deux copies étaient à six cents lignes l'une de l'autre.

Ce n'est pas un bug : les deux disent la même chose aujourd'hui. C'est le jour où « seule » cesse
de vouloir dire « un membre » — un club où l'on compte les membres actifs, un invité qui n'a pas
encore accepté — que l'une des deux reste en arrière, et le club annonce deux états différents de
lui-même sur deux onglets. La règle est maintenant nommée une seule fois, `seuleDansSonClub`, à
côté de `clubEnSommeil` qui est de la même nature.

### Un renvoi qui ne survit pas à une découpe

`ClubWakeCard` portait un commentaire qui disait « voir la note sur le bouton Partager **plus
bas** ». Cette note est partie dans `ClubAloneCard.swift` avec sa carte. Un renvoi à une position
dans un fichier ne survit pas au découpage de ce fichier, et personne ne le remarque : le
commentaire reste grammaticalement correct, il désigne simplement le vide. Il est recopié en
entier — c'est la règle des 44 points qui s'empilent sous les marges du style, et elle vaut pour
les deux cartes.

De même, un commentaire de `ClubView` décrivait encore `if clubEnSommeil { carteClubAReveiller }`,
un membre qui n'existe plus sous ce nom.

### Ce que `check_prive.py` n'aurait pas rattrapé ici

`carteClubSeul` et `carteClubAReveiller` étaient des `private **var**`, pas des `func`. Le
contrôle écrit au chantier 36 ne regarde que les fonctions, et pour une raison mesurée : étendu
aux propriétés, il rendait 112 signalements faux. Les trois sites d'appel ont donc été vérifiés à
la main, par `grep`, avant la découpe — pas par la chaîne.

## Chantier 36 — la chaîne verte sur du code qui ne compile pas (B5, deuxième morceau)

### Ce qui est sorti

Le groupe « vue d'ensemble » du chantier 35, mesuré à 205 lignes et deux états. Il s'est découpé
en deux, parce que les deux cartes n'ont pas le même coût :

- `ClubWeekPulseCard` — 87 lignes, **zéro liaison**. Elle ne demande que le magasin.
- `ClubChallengeCard` — 83 lignes, **une** liaison : `showManagement`, parce que « créer un
  défi » ouvre la gestion du club.

`ClubView` : **1 338 → 1 193 lignes**, 43 membres, 19 états.

### Le défaut : chaîne verte, code qui ne compile pas

`ClubChallengeCard` appelait `daysLeft(until:)`, une `private func` restée dans `ClubView`. En
Swift, `private` sur un membre porte sur la déclaration englobante **et son fichier** : l'appel ne
se résout pas. Le projet ne compilait plus.

`sh ci_scripts/tout.sh` était vert. Tous les contrôles, tous leurs cas. C'est normal : aucun ne
résout un symbole Swift, et il n'y en aura pas un qui le fasse — ça demanderait un compilateur. Le
coût de ce défaut n'est pas le correctif, qui prend une minute : c'est que la seule machine qui
sait le dire est à quarante minutes d'ici, et qu'une découpe qui ne doit rien changer serait
partie rouge.

Ce qui l'a trouvé n'est pas un contrôle : c'est d'avoir relu les deux fichiers neufs en cherchant
quels membres de `ClubView` ils utilisaient encore. Treize identifiants à vérifier, un seul faux.

### Le contrôle, et ses deux premières versions fausses

`check_prive.py` ne compile rien. Il constate **une** impossibilité : un nom déclaré `private`
dans un seul fichier, appelé nu depuis un autre, ne peut pas se résoudre. Ce n'est pas un soupçon,
c'est une erreur de compilation certaine.

Les deux premières versions étaient fausses, chacune à sa manière, et c'est ce qui vaut d'être
écrit ici :

**La première signalait 112 défauts pour zéro défaut réel.** Elle regardait aussi les propriétés
et les types, sur une référence nue au nom. Or un identifiant nu en Swift n'est pas forcément une
référence : `RoundedRectangle(cornerRadius: 12)` contient `cornerRadius` nu, et c'est une
*étiquette d'argument*, pas la propriété privée du même nom déclarée ailleurs. Même chose pour
`opacity`, `filter`, `columns`, `password`. Un contrôle qui crie 112 fois dans le vide n'est pas
prudent : on apprend à ne plus le lire. D'où la forme étroite — les `func` seules, et seulement
la forme `nom(`.

**La seconde ne rattrapait pas le défaut pour lequel elle était écrite.** Elle vidait le contenu
des chaînes à la `re.sub`, comme les autres contrôles du dépôt — et l'appel vivait dans une
interpolation : `String(localized: "J-\(daysLeft(until: challenge.endDate))")`. La regex effaçait
le code avec le texte. J'ai remis `daysLeft` dans `ClubView` pour éprouver le contrôle sur le vrai
défaut, et il a rendu vert. Un contrôle qui rate le cas qui l'a fait naître est pire que pas de
contrôle : il rassure. Le lecteur de chaînes est maintenant un vrai parcours, qui jette le texte
et **garde le code des interpolations**, imbrications comprises.

C'est le même piège que `check_vides.py` avait rencontré en novembre, résolu là-bas en relisant la
ligne brute. Le dépôt a donc deux contrôles qui ont buté sur la même fonction ; les autres s'en
servent encore, et aucun ne regarde ce qui vit dans une interpolation.

### Ce qui le prouve

- `test_prive.py`, **21 cas**. Cinq sur ce qui doit être signalé, dont celui de l'interpolation et
  celui de l'interpolation imbriquée dans une chaîne imbriquée. Huit sur ce qui ne doit **pas**
  l'être — l'étiquette d'argument, l'appel de membre avec un point, le nom déclaré deux fois, le
  nom dans un texte, le nom en commentaire, un suffixe. Cinq sur le lecteur de chaînes seul.
- Mesuré sur les **301** fichiers Swift des quatre cibles, après correction : **zéro**.
- Et le contrôle rendait vert depuis `ci_scripts/` tant qu'il lisait `RunUp/` en relatif — « aucun
  fichier Swift trouvé ». Il est ancré sur la racine du dépôt, et un cas le tient.

### Ce que ce contrôle ne voit pas

Les propriétés et les types privés : le coût en faux positifs est prohibitif, mesuré à 112. Un nom
déclaré deux fois dans la cible : l'appel pourrait se résoudre sur l'autre, le script passe son
tour plutôt que d'accuser à tort. Et tout le reste de ce que fait un compilateur.

## Chantier 35 — ClubView, la découpe reprise par le bout le moins cher (B5, premier morceau)

### La mesure avant le découpage

1 425 lignes, 51 membres. **844 lignes** sont déplaçables en quatre groupes cohérents ; il
resterait 581, une taille raisonnable pour une vue-conteneur.

Mais le nombre de lignes n'est pas le bon critère de risque. La vue porte **vingt états**, et
chaque état qu'une section doit recevoir est un `@Binding` de plus — donc une chance de brancher
le mauvais, dans un remaniement qui ne doit RIEN changer.

| groupe | lignes | états à passer |
| --- | --- | --- |
| **Le niveau** | 101 | **0** |
| La vue d'ensemble | 205 | 2 |
| Rejoindre / réveiller | 231 | 4 |
| Le mur et le fil | 263 | **10** |

### Une erreur de plan, trouvée en lisant

Mon premier regroupement mettait `segment` avec le niveau, sur la foi de son nom. En ouvrant le
fichier : `segment` est le bouton d'un onglet, appelé par `clubTabs` quatre cents lignes plus
loin, et il a besoin de `tab`. Le groupe « niveau » ne porte donc **aucun** état, et c'est ce qui
en fait le premier morceau.

C'est la sixième fois dans cette session qu'un plan écrit depuis un résumé ne survit pas au
contact du code. Les mesures, elles, tiennent.

### Ce qui est sorti

- `NiveauDuClub` — le calcul du palier, pur et testé. Il vivait en propriété privée au milieu des
  1 425 lignes : vérifiable seulement en ouvrant l'écran avec un compte au bon nombre de points,
  c'est-à-dire jamais. Il porte pourtant trois décisions, dont une qui n'était écrite nulle part :
  **au-delà du septième titre, on ne s'arrête pas de monter.** Le comportement existait — un
  `min(max(…))` — et c'est exactement le bord qu'un remaniement transforme en plantage d'index ou
  en « Premiers pas » retrouvé au niveau 12.
- `ClubLevelCard` — la vue, qui ne connaît plus que son XP. Elle ne consulte plus `AuthService` :
  l'appelant lui donne le nombre, donc elle se dessine pour n'importe quelle valeur.

`ClubView` : **1 425 → 1 338 lignes.**

### Ce qui le prouve

`NiveauDuClubTests`, 9 cas : les deux bords du palier (où un `>=` mal placé décale tout le monde
d'un niveau sans rien casser), les sept titres dans l'ordre, le huitième niveau qui garde le
dernier titre, un XP négatif qui ne descend pas sous le niveau 1, et la monotonie.

Et surtout : **les quatre écrans du Club sont photographiés**, et `comparer.py` existe pour ça. Il
a été écrit pour la première découpe de ce fichier — son en-tête dit « `ClubView.swift` fait 2721
lignes » — et il compare pixel à pixel en masquant la barre d'état. Une découpe qui ne doit rien
changer se prouve par l'image, pas par une intention.

### Ce que je ne découperai pas comme les autres

**Le mur et le fil**, et ses dix `@Binding`. Dix états à faire passer n'est pas une section : c'est
le signe qu'il lui faut son propre objet d'état, comme `magasin` en est déjà un pour le reste du
Club. Le sortir en l'état transformerait une vue longue en une vue longue plus dix fils à ne pas
confondre.

## Chantier 34 — deux listes sans borne, pas soixante-trois fichiers (B6)

### L'item comptait la mauvaise chose

`PHASE2.md` disait : « 63 fichiers utilisent `ForEach`, **11 seulement** une liste paresseuse. »
Ce comptage ne mesure rien. Un `ForEach` sur les sept jours de la semaine n'a aucun besoin d'être
paresseux, et un fichier qui en porte trois ne compte pas pour trois défauts.

Le critère qui compte est la **position** : sous un `ScrollView`, sans `LazyVStack`, `LazyHStack`,
`LazyVGrid` ni `List` entre les deux.

| | |
| --- | --- |
| `ForEach` dans le dépôt | 133, dans 63 fichiers |
| conteneurs paresseux | 13 |
| **`ForEach` réellement construits d'un bloc sous un défilement** | **10** |
| dont la source est bornée dans le code (`allCases`, `0..<7`) | 7 |

### Et les deux écrans que l'item nommait étaient déjà réglés

« Le fil du club et l'historique ne sont pas courts », disait-il. Mesuré :

- **le fil du club** porte un `LazyVStack` depuis longtemps, avec son commentaire : « le serveur
  renvoie 50 activités, et un `VStack` les construisait TOUTES » ;
- **l'historique** est une `List` — paresseuse par construction, et choisie pour une autre raison
  écrite sur place : `.swipeActions` ne marche que là.

### Les deux qui restaient

| écran | collection | ce que porte chaque ligne |
| --- | --- | --- |
| `ActivityCommentsSheet` | les commentaires d'une activité | un avatar à décoder |
| `FriendsView` | la liste de personnes | un `AvatarView` |

Aucune borne, et une image par ligne. Les deux passent en `LazyVStack`, avec le même commentaire
que le fil du club — c'est le même cas.

### Les trois qui restent, et pourquoi

Bornées par une règle de produit que la syntaxe ne montre pas, donc **dispensées avec leur
raison** : les groupes d'allure d'une sortie (« le produit en propose huit au plus », dit le
commentaire de la vue), et les deux bandes de badges, bornées par `ClubBadgeCatalog.all`. Les
trois sont des bandes horizontales à tuiles de largeur fixe, pas des listes qui croissent.

### Ce qui le garde

`ci_scripts/check_listes.py`, **16 cas**. La règle : un `ForEach` sous un défilement, sans
conteneur paresseux, doit avoir une source dont la taille se lit DANS LE CODE — `X.allCases`, un
intervalle littéral — ou une dispense nommée avec sa raison.

Trois cas ne vérifient que les façons de passer vert à tort. Le plus utile : un `LazyVStack` posé
**ailleurs dans le fichier** ne doit pas couvrir une liste qui ne s'y trouve pas — c'est
l'imbrication qui décide, pas la présence du mot. Un autre fixe que `0..<items.count` n'est pas
une borne : c'est la même collection, écrite autrement.

Et le contrôle dit ce qu'il ne sait pas faire : il ne mesure aucune performance. Dix lignes de
texte nu ne valent pas dix lignes à avatar, et il ne connaît pas la différence. Il constate qu'une
liste sans borne est construite d'un bloc — une décision — et demande qu'elle soit prise exprès.

## Chantier 33 — la montre coupait sa seule phrase, et rien ne le disait (B4)

### Regardé, pas déduit

Sur la capture que la fiche App Store publie, dans les trois langues :

```
en-US  11 lignes de pixels encrées jusqu'à la toute dernière (495/496)
es-ES  11 lignes
fr-FR  11 lignes
```

« Cours à ta sensation — ta séance arrive de l'iPhone. » était **tranchée en deux par l'arête
basse**. L'écran est dans un `ScrollView`, donc la phrase était atteignable — en faisant défiler,
sur une montre, une phrase d'explication posée sous un bouton géant. Autant dire jamais.

### La cause, écrite dans le fichier lui-même

L'anneau pointillé faisait **118 points sur les 248** de l'écran, et le commentaire du fichier le
qualifiait : *« purely decorative since there's nothing to track yet »*. La moitié de l'écran pour
une décoration, qui pousse dehors la seule phrase.

| | avant | après |
| --- | --- | --- |
| anneau | 118 | 96 |
| bouton | 92 | **76** (minimum tactile d'Apple : 44) |
| écarts du `VStack` | 8 | 6 |

Vingt-huit points rendus. Et la phrase prend désormais la hauteur qu'il lui faut (`fixedSize`) au
lieu de celle qu'on lui laisse : une langue plus longue que les trois d'aujourd'hui repasserait
sinon sous le bord sans que la mise en page bouge d'un point.

### L'autre moitié de B4 était déjà tombée

`PHASE2.md` annonçait aussi « le dégradé sur le bouton principal ». Mesuré : la montre ne porte
**aucun** dégradé ni verre — ils sont partis avec le chantier 24. Restait le commentaire, qui
décrivait encore un « dashed gradient ring ». Un commentaire qui décrit ce qui n'est plus là est
la moitié d'un mensonge.

### Ce qui le garde

`check_captures_montre.py` savait dire que trois langues rendaient la même image. Il ne savait pas
dire que les trois étaient COUPÉES. Il le dit : la bande basse — 2 % de la hauteur, cinq points —
doit rester vierge.

Elle ne juge aucune mise en page. Elle constate qu'au REPOS rien n'est tranché par l'arête, ce à
quoi une image répond sans ambiguïté, contrairement à « est-ce joli ». **Éprouvée sur les vraies
captures d'avant : elle rougit pour les trois langues.** Cinq cas nouveaux, dont deux pour les
façons de passer vert à tort — un seuil d'encre à zéro accuserait toutes les captures réelles et
on apprendrait à ignorer le rouge ; et la coupe doit l'emporter sur la comparaison des langues,
parce que l'une se corrige dans la vue et l'autre dans la chaîne de capture.

### Et un rouge délibéré, pendant un build

Les trois captures livrées à Apple sont versionnées et portent l'empreinte du code de la montre.
Changer ce code les périme, et `check_requis.py` l'a dit tout de suite — il a refusé le commit.

Les réestampiller sur place aurait été lui mentir : déclarer à jour des images que personne n'a
refaites. Et je ne peux pas les refaire ici, il faut un simulateur watchOS. Le chemin honnête était
donc de pousser le code, laisser `montre.yml` refaire les captures, **les regarder**, et poser les
images fraîches au commit suivant. Un build rouge sur une étape, dix minutes, et le garde-fou a
fait exactement son travail.

## Chantier 32 — la mesure du lancement arrivait déjà, et une méthode vide la jetait (B7)

`PHASE2.md` disait : « Le temps de lancement n'a jamais été relevé. La phase 4 exige premier écran
en moins de 2 secondes. On ne peut pas tenir une promesse qu'on n'a pas mesurée. »

Il n'y avait rien à construire pour la relever.

### La moitié traitée, et la moitié jetée

MetricKit a deux canaux, et `Diagnostics` était abonné aux deux :

| | |
| --- | --- |
| `didReceive(_:[MXDiagnosticPayload])` | traité depuis longtemps — **cinq** listes, dont `appLaunchDiagnostics`, avec la durée dans la note. Chaque lancement anormalement lent arrive déjà, et `privacy.html` le décrit : « met trop longtemps à démarrer » |
| `didReceive(_:[MXMetricPayload])` | **`{}`** |

Une méthode vide. On avait donc les cas EXTRÊMES et pas la normale — et la promesse porte sur la
normale.

### Pourquoi iOS et pas un chronomètre dans l'app

`histogrammedTimeToFirstDraw` est « the time when the first CA commit is finished » : c'est bien
« premier écran ». Et c'est la seule mesure qui inclut ce qu'on ne peut pas voir depuis Swift —
le temps d'avant `main()`, le chargement dynamique, la mise en place du processus. Un chronomètre
posé dans l'app démarrerait trop tard et annoncerait donc des lancements **plus rapides** qu'ils ne
sont : il se tromperait dans le sens qui arrange, sur une promesse.

### Deux choses que je n'ai pas devinées

La documentation d'Apple n'était pas citable sur deux points, et le blog qui l'approche ne les dit
pas non plus :

1. **L'unité des paliers.** Le code de référence lit `bucketEnd.value` brut et traite le résultat
   comme des millisecondes, sans le dire. Un facteur mille ferait juger la promesse sur du vide.
   `Diagnostics` porte déjà `millisecondes(_:)`, qui **convertit** la `Measurement` au lieu de lire
   sa valeur — l'unité n'est donc pas une supposition.
2. **Le nom de la propriété de début de palier.** Non vérifié, et pas nécessaire : les paliers sont
   contigus, et les deux lectures utiles n'ont besoin que de la borne haute. Lire une propriété
   dont on n'est pas sûr, pour une donnée dont on n'a pas besoin, c'est deux risques pour rien.

### Les deux lectures se trompent exprès, et dans le même sens

Un histogramme ne donne aucune durée, seulement des paliers. `Histogramme` l'assume :

- `percentile(_:)` rend la **borne haute** du palier où le cumul franchit le seuil. « p90 =
  1 500 ms » veut dire « neuf sur dix ont fini avant 1 500 ms » ;
- `partAuDessusDe(ms:)` compte un palier **à cheval** sur le seuil comme étant au-dessus.

Les deux penchent vers le pessimisme. C'est le bon sens pour une promesse : on ne veut pas la
découvrir annoncée tenue parce qu'on arrondissait vers le bas. `HistogrammeTests`, **16 cas**,
dont un qui fixe `ceil` plutôt que `round` — à dix observations le p50 est la cinquième, pas la
cinq-et-demie, et `round` faisait sauter d'un palier, soit quatre fois plus de millisecondes
annoncées.

### Elle ne partait pas encore, et maintenant si

`Diagnostics.mesureDuLancementActive` est resté à **faux** le temps d'un chantier, pour une raison
qui n'était pas technique : la politique **publiée** ne décrivait pas cette mesure. Collecter une
donnée que la page liée depuis la fiche App Store ne mentionne pas est exactement le défaut que
`check_politique.py` existe pour empêcher, dans le sens qu'il qualifie de dangereux.

J'avais préparé le paragraphe et le push vers `main` m'a été refusé — un déploiement en
production, et l'autorisation d'alors portait sur un seul geste. Je ne l'ai pas contourné : j'ai
retiré le paragraphe de la branche de travail pour que les deux pages restent d'accord, et j'ai
posé un drapeau écrit en clair, avec sa raison et l'action qui le lève.

Charlotte a autorisé le geste le 10 novembre. **L'ordre a été tenu** : la page a été publiée sur
`main` d'abord, vérifiée servie par GitHub Pages — douze sections au lieu de onze, texte identique
au dépôt — et la constante n'est passée à vrai qu'après. Il n'a donc jamais existé d'instant où
l'app mesurait sans que la page le dise.

Le paragraphe publié :

> **Temps de lancement** — une fois par jour au plus, l'application envoie la mesure du temps que
> ton téléphone a mis à afficher le premier écran, telle qu'iOS l'établit. Elle arrive sous forme
> de *paliers* — « tant de lancements terminés avant 250 millisecondes, tant avant 500 » — et
> jamais sous forme de durées individuelles : aucun lancement en particulier n'est identifiable.
> Elle sert à une seule chose, vérifier que le premier écran s'affiche en moins de deux secondes.
> Elle relève du choix décrit ci-dessus : si tu refuses les statistiques d'usage, elle n'est ni
> enregistrée ni envoyée.

La constante reste en place plutôt que d'être retirée : elle est l'interrupteur par lequel on
arrête cette collecte sans toucher à rien d'autre.

Le manifeste, lui, n'a pas bougé : `PrivacyInfo.xcprivacy` déclare déjà `PerformanceData`, pour
les diagnostics de lancement. Même nature de donnée, même finalité.

Et cette mesure **obéit au consentement**, contrairement aux rapports de panne : elle passe par
`Analytics`, dont `enqueue` et `sendNextBatch` sont gardés par le choix fait à l'inscription. C'est
pour ça que le paragraphe le dit — les deux cas voisins ne se comportent pas pareil.

### Ce qu'on saura, et quand

Rien ce soir. MetricKit livre un lot par appareil et par jour, depuis un appareil RÉEL — un
simulateur n'en envoie pas. Les premiers chiffres arriveront dans la table `events`, événement
`launch_measured`, et la promesse se lira directement dans la propriété `part_au_dessus_de_2s`.

## Chantier 31 — l'état vide, écrit une fois pour de bon (A5, le reliquat)

`RUEmpty` existait depuis le chantier 25, et **six écrans l'utilisaient**. Seize endroits
continuaient d'écrire le leur.

### Ce que la mesure a donné

| | valeurs trouvées pour la même phrase |
| --- | --- |
| graisse du titre | `.bold`, `.semibold`, `.medium` |
| couleur du message | `text3`, `text2` |
| corps du texte | `.small`, `.body` |
| taille de l'icône | `.hero` (28), `.xlarge` (22) |

Deux couleurs et trois graisses pour dire « il n'y a rien ici ». « Aucun défi en cours » existait
dans deux fichiers, avec deux formulations et deux corps de texte.

### Et le composant partagé était le seul à ne pas suivre le système

`RUIconSize.hero` vaut 28, et sa documentation dit : *« l'icône d'un état vide, celle qu'on voit
avant même de lire »*. `RUEmpty` utilisait `.xlarge` (22). Les trois états vides écrits à la main,
eux, utilisaient bien `.hero`. La pièce censée mettre tout le monde d'accord était la seule à
ignorer le cran que le système nomme pour elle.

### Seize conversions, dans dix-sept fichiers

Six appels au départ, **24 maintenant**. Les cas intéressants :

- `FriendsView` recentrait une `.ligne`, alignée à gauche par construction — le site d'appel
  reprenait une décision du composant. La forme était en fait un `.bloc` : il n'y a aucun en-tête
  de section au-dessus, seulement un champ de recherche et une zone de résultats vide.
- `PublicProfileView` portait **deux** états vides à la main, dont un que je n'ai vu qu'en
  réparant l'accolade orpheline laissée par la première conversion.
- `MoveSessionSheet` et `ClubBoardSection` n'étaient dans aucune de mes listes : c'est la mesure
  qui les a sortis.

### Ce qui n'a pas été converti, et pourquoi

- **`StatsView.firstDayBanner`** — une carte héros avec en-tête, sous-titre et un paragraphe qui
  promet ce que l'écran affichera. Ce n'est pas « il n'y a rien », c'est une promesse de premier
  jour. La forcer dans `RUEmpty` aplatirait une intention.
- **`FriendsView`, « Personne à suivre pour l'instant »** — un bloc d'appel à l'action avec
  l'invitation par code, conçu comme tel et documenté sur huit lignes.
- **`PaywallView`** — un état de CHARGEMENT, avec sa roue. `RUEmpty` dit explicitement qu'il n'est
  ni une erreur ni un chargement.
- **`RaceDiscoveryView.message(…)`** reste, pour son unique autre usage : une erreur de
  chargement. « Rien à montrer » et « ça n'a pas marché » sont deux phrases différentes.

### Un trou trouvé en passant, et plus grave que le chantier

Le contrôle des symboles s'est mis à signaler « bell.slash » et « square.stack.3d.up » comme
**éprouvés mais plus employés**. Cause : il lit l'argument de `systemName:` et sait remonter un
membre calculé ou un paramètre de fonction — mais pas une **propriété stockée de structure**, qui
n'a pas de corps accoladé. En adoptant `RUEmpty(icone:)`, les écrans rendaient donc leurs icônes
invisibles à la vérification.

La résolution ajoutée a immédiatement découvert **trois symboles jamais éprouvés** : `shoe`
(`RUEmpty`), `clock` et `ruler` (`RUStatTile`, `RUCardHeader`). Trois familles de composants
passent un nom de symbole par propriété stockée, et aucune de leurs icônes exclusives n'était
vérifiée — depuis leur création. Un nom de symbole faux ne lève rien : il ne dessine rien.
108 symboles sont désormais éprouvés.

### Ce qui le garde — et ce qu'il avoue ne pas garder

`ci_scripts/check_vides.py`, **15 cas**. Trois règles : aucun bloc composé à la main (grande icône
teintée `text3` au-dessus d'un texte), aucun site d'appel qui restyle le composant, et le composant
qui garde `.hero` et `text3`.

**Et il dit ce qu'il ne sait pas faire.** La forme `.ligne` n'a aucune signature détectable : une
phrase sous un en-tête de section ressemble à n'importe quelle autre phrase secondaire. La règle la
plus large essayée — un `Text` teinté `text3` dans une branche qui teste `isEmpty` — a rendu
**35 endroits pour environ 6 vrais** : des `!x.isEmpty` qui testent une présence, des `isValid`,
des URL, des bios. Une règle à trente dispenses ne décrit pas un défaut, elle le noie, et on
apprend à ignorer son rouge. Les conversions ont donc été faites en lisant, et c'est écrit.

Un des quinze cas reproduit un défaut du garde-fou lui-même : il cherchait le nom du symbole de sa
dispense dans la source dont `sans_commentaires` a effacé le contenu des chaînes. La seule dispense
réelle ne s'appliquait jamais.

## Chantier 30 — huit boutons qui n'existaient pas, et une politique qui ne disait pas qu'on peut refuser

Deux demandes de Charlotte — retirer la capture iPad de la fiche, ajouter à `privacy.html` la
phrase sur le refus des statistiques. La première a buté sur un défaut que je n'avais pas vu.

### Le bouton que je lui avais indiqué n'existait pas

Je lui avais écrit : « workflow **App Store**, action **`nettoyer-les-captures`**, champ
« retirer » ». Au premier appel, l'API a répondu :

> Provided value 'lister-les-captures' for input 'action' not in the list of allowed values

**GitHub ne construit le formulaire « Run workflow » que depuis la branche par défaut.**
`appstore.yml` est le seul workflow du dépôt qui ne se déclenche qu'à la main — les six autres
tournent aussi au push — et sa liste d'actions sur `main` est la seule qu'on puisse choisir. Le
corps, lui, récupère explicitement la branche de travail pour y trouver `asc.py`.

Huit actions étaient déclarées dans le dépôt et absentes de `main` :

| | | |
| --- | --- | --- |
| `liberer-la-file` | `nettoyer-les-captures` | `pousser-l-apercu` |
| `lister-les-captures` | `nettoyer-les-captures-essai` | `pousser-l-apercu-essai` |
| `pourquoi-pas-soumettable` | `pousser-la-montre` | |

Dont **deux chantiers entiers** : l'envoi des captures de la montre et l'aperçu vidéo de la fiche.
Chacun écrit, testé, documenté — et impossible à lancer. L'entrée `retirer` manquait aussi, donc
même en atteignant l'action, le champ n'aurait pas été là.

C'est le défaut le plus discret rencontré jusqu'ici : le code existe, ses contrôles passent, sa
documentation le décrit, et il ne s'exécute jamais. Et `main` portait **déjà** un commit intitulé
« Le bouton qui envoie les captures doit vivre sur main, sinon il n'existe pas ». La leçon avait
été apprise une fois et n'a pas tenu, faute de quoi que ce soit qui la vérifie.

`ci_scripts/check_boutons.py` la vérifie maintenant, et **12 cas** le gardent. Deux d'entre eux
reproduisent un défaut du garde-fou lui-même : son premier jet lisait `origin/main` et ne
récupérait qu'en cas d'échec, or `git fetch origin main` ne met à jour que `FETCH_HEAD`. Il a donc
comparé le dépôt du jour à un `main` vieux de plusieurs semaines — et s'est trompé à son premier
essai réel. Il récupère d'abord, toujours, et échoue en le disant s'il ne peut pas regarder.

### Et la capture iPad ne peut pas être retirée de là où elle est

L'inventaire, une fois le bouton réparé, a donné l'état réel :

```
version 3.3      READY_FOR_SALE               plateforme IOS
version 3.2      READY_FOR_SALE               plateforme IOS
```

Il n'existe **aucune version 3.4** sur App Store Connect — les builds 1496-1499 sont en
TestFlight, c'est autre chose. La capture iPad est donc sur la **3.3, en vente, et Apple fige une
version en vente.** Personne ne peut l'en retirer, moi compris.

Ce qui se peut, en revanche, c'est qu'elle ne revienne pas. Créer une version recopie les captures
de la précédente, tous formats confondus : la retirer à la main une fois ne règle rien, il faut
s'en souvenir à chaque version. **`create-version` élague donc d'office**, sur une liste nommée
`FORMATS_SANS_RAISON` qui ne contient que l'iPad, et le geste à ne pas oublier devient une chose
qui arrive.

La capture Apple Watch n'y est pas et ne doit pas y venir : Apple l'exige dès que la build embarque
une app watchOS. Une première version de l'élagage, qui gardait l'iPhone et supprimait le reste,
l'avait emportée et la version était restée bloquée deux heures. Un cas de test l'interdit
nommément, avec cinq formats.

### La politique, et ce que le refus ne couvre pas

L'app pose la question à l'inscription — deux boutons, rien de coché d'avance — et le choix est
révocable dans Profil › Réglages › Plus de réglages. La page décrivait la collecte sans dire qu'on
peut la refuser.

**Et en vérifiant au lieu de supposer** : les rapports de panne n'obéissent PAS à ce consentement.
`Diagnostics.demarrer()` ne regarde que le mode démonstration, et `sendNextBatch` n'a aucune garde
de consentement. La phrase ajoutée le dit donc explicitement, au lieu de laisser quelqu'un déduire
de travers d'un paragraphe voisin.

Deux textes de l'app disaient aussi « rien n'est envoyé » — vrai pour les statistiques, ambigu à
côté d'un canal qui continue d'émettre. Ils disent maintenant « aucune statistique ». Et l'écran
d'inscription indiquait « Profil → Réglages » pour revenir sur son choix : **le réglage est dans
« Plus de réglages »**, une feuille à l'intérieur de Réglages. Quelqu'un qui suivait l'indication
ne trouvait rien. Corrigé dans les trois langues.

Enfin la redondance que la page signalait elle-même en commentaire depuis le 8 novembre est
retirée — « n'embarque aucun outil tiers de rapport de panne » apparaissait deux fois à deux
paragraphes d'écart. Le commentaire disait : « si tu modifies cette page, tu es cette prochaine
fois. »

### Ce qui reste à faire, et par qui

La capture iPad disparaîtra **à la création de la version 3.4**, sans que personne n'ait à y
penser. Créer cette version est une décision de sortie, pas une correction : elle attend
Charlotte.

## Chantier 29 — les allures du plan n'avaient aucune source (B1)

C'est l'item le plus lourd de la liste, et le fond du produit : un plan dont les allures ne se
défendent pas n'est pas un plan d'entraînement.

### Ce qu'il y avait

Quatre multiplications, dans `PaceModel.zones` :

```swift
easy:      paceText(thresholdSecPerKm * 1.20),
marathon:  paceText(thresholdSecPerKm * 1.08),
threshold: paceText(thresholdSecPerKm * 1.0),
interval:  paceText(thresholdSecPerKm * 0.87),
```

L'ancrage était l'allure du 10 km, projetée par Riegel depuis la meilleure performance. Le
commentaire du fichier avouait l'origine des quatre coefficients : *« deliberately simple […] in
the spirit of standard recreational running pace calculators »*. Autrement dit, aucune source.

### La méthode retenue

Jack Daniels et Jimmy Gilbert, *Oxygen Power* (1979), deux équations :

- le coût en oxygène d'une vitesse : `VO2 = −4,60 + 0,182258 v + 0,000104 v²`, v en m/min ;
- la fraction de VO2max soutenable sur une durée :
  `%VO2max = 0,8 + 0,1894393 e^(−0,012778 t) + 0,2989558 e^(−0,1932605 t)`, t en minutes.

Leur quotient sur une performance réelle donne le VDOT. En sens inverse, un VDOT et une fraction
donnent une allure.

**Les fractions ne sont pas recopiées, elles sont mesurées.** Trois sites donnent trois valeurs
différentes pour la même allure — pour le seuil, 83-88 %, 86-92 % et 88-92 %, et l'un des trois
confond %VO2max et %FCmax. Elles ont donc été *retrouvées* depuis la table publiée : pour chaque
allure et chaque VDOT, `coutEnOxygene(allure) / VDOT`. Le résultat est constant à un dixième de
point sur tout l'intervalle VDOT 30-60, ce qui n'arrive pas par hasard :

| Allure | Fraction mesurée | Étendue sur VDOT 30-60 |
| --- | --- | --- |
| footing, bord lent | 62,0 % | 61,9 – 62,1 |
| footing, bord rapide | 70,0 % | 69,9 – 70,1 |
| seuil | 88,0 % | 87,8 – 88,1 |
| intervalle | 97,5 % | 97,3 – 97,7 |
| marathon | **dérive de 80,5 à 82,5 %** | — |

L'allure marathon n'est donc pas une fraction : chez Daniels, c'est l'allure du marathon *prédit*.
Calculée comme telle, elle redonne la table à un demi-seconde près au lieu de trois.

### Ce que la mesure a dit des quatre coefficients

| | RunUp | Daniels (rapport à l'allure du 10 km) | Verdict |
| --- | --- | --- | --- |
| footing | × 1,20 | 1,199 → 1,376 selon le niveau | **faux** : au bord le plus rapide de la plage facile à VDOT 30, **devant** pour tout le monde au-dessus |
| marathon | × 1,08 | 1,076 → 1,094 | **juste** |
| seuil | × 1,00 | 1,003 → 1,037 | légèrement trop rapide, l'écart croît avec le niveau |
| VMA | × 0,87 | intervalle 0,925 → 0,957 ; **répétition 0,872 → 0,893** | **faux** : c'est l'allure du mile, prescrite pour des répétitions de 3 à 5 minutes |

En secondes par kilomètre, pour de vraies personnes :

| VDOT | 10 km | footing Daniels | footing RunUp | écart | VMA Daniels | VMA RunUp | écart |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 30 | 1:03:49 | 8:01 | 7:39 | **−22 s** | 5:54 | 5:33 | **−21 s** |
| 40 | 50:01 | 6:26 | 6:00 | **−25 s** | 4:41 | 4:21 | **−20 s** |
| 50 | 41:20 | 5:22 | 4:58 | **−25 s** | 3:55 | 3:36 | **−19 s** |
| 60 | 35:22 | 4:38 | 4:15 | **−24 s** | 3:23 | 3:05 | **−18 s** |

Le footing porte 70 à 80 % du volume d'une semaine. C'est l'erreur la plus répandue de
l'entraînement de loisir, et l'app la prescrivait.

**Et aucun coefficient fixe ne pouvait être juste.** Les rapports de Daniels varient avec le
niveau : footing/seuil passe de 1,2526 à 1,2659, VMA/10 km de 0,925 à 0,957. Un seul nombre se
trompe forcément à une extrémité.

### Le plus instructif : un test vert interdisait la bonne réponse

`testIntervalPaceIsAGenuineVO2maxStimulus` exigeait un écart seuil→VMA de **11 à 20 %**, sur la
foi de son propre commentaire : *« real vVO2max sits ~12-18% faster »*. Aucune source.

Mesuré sur la table, l'écart vaut **7,7 à 8,2 %**. Le code l'avait eu — × 0,92, soit 8 % — puis
l'a perdu pour satisfaire ce test. Le raisonnement du commentaire était juste sur le symptôme
(« à 8 %, la séance de VMA était un second tempo ») et faux sur le nombre, et il a sur-corrigé
dans la direction même qu'il voulait corriger.

Un chiffre d'entraînement sans source n'est pas une approximation, c'est une invention. Et une
invention sous test devient une invention protégée.

### Riegel sort de l'ancrage

L'exposant 1,06 a été ajusté par Peter Riegel sur des **records du monde** (« Athletic Records and
Human Endurance », *American Scientist* 69(3), 1981) : un travail descriptif, pas un prédicteur
individuel. Il n'est plus nécessaire ici — le VDOT se lit directement depuis n'importe quelle
distance, et les quatre distances d'une même ligne de la table rendent le même VDOT à cinq
centièmes près. Riegel reste le repli pour ce que Daniels ne couvre pas, en dessous de 1 500 m et
au-delà du marathon, où l'appelant affiche une prédiction et non une consigne.

### Deux autres faussetés trouvées en passant

1. **Les statistiques prédisaient depuis l'allure de seuil « sur 10 km ».** Deux propriétés
   séparées, l'une se repliant sur le seuil, l'autre sur dix. L'allure de seuil n'est pas celle
   d'un 10 km — c'est celle d'une course d'environ 67 minutes. Le couple ne tenait que parce que
   le plan se trompait de la même façon. La prédiction repart du VDOT du profil.
2. **Le tableau d'allure du jour J se repliait sur le seuil, quelle que soit la distance.** Sur un
   marathon, il proposait un rythme de course d'une heure sur quarante-deux kilomètres, et la
   ligne « Relance » cinq secondes plus vite encore. Il repart de la prédiction **pour cette
   distance-là**.

### Les deux erreurs de signe contraire

L'ancien code déduisait d'une allure de footing déclarée un seuil **14 s/km trop lent** (`/ 1.20`,
quand Daniels donne 1,25 à 1,27), pendant qu'il déduisait d'un chrono un footing **25 s/km trop
rapide**. Deux chemins d'entrée du questionnaire, deux erreurs opposées, et rien qui les
rapproche. Une seule méthode, maintenant, dans les deux sens.

### Ce qui ne change pas, délibérément

Les trois constantes de niveau — 330, 285, 240 s/km — sont converties en VDOT (36,34 / 43,61 /
53,94) de façon à rendre **exactement le même seuil** qu'avant. Seules les trois autres allures
bougent, ce qui est l'objet du chantier. Les redécider est un autre travail, et il se pose : un
VDOT de 36 est un 10 km en 54 minutes, ce qui n'est pas « débutante » mais « court déjà ». Personne
n'a mesuré ce que courent les gens qui cochent cette case, et une constante devinée deux fois ne
vaut pas mieux qu'une fois.

### La bascule

Rien n'est réécrit sous les pieds de personne. Une séance porte son allure en texte, posée à la
génération de la semaine : les nouvelles allures paraissent à la prochaine régénération — un
changement de réglage, ou le lundi suivant. La semaine commencée reste celle qu'on a sous les yeux,
et aucune séance ne change entre le moment où on la lit et le moment où on la court.

Conséquence attendue et correcte : à distance égale, une sortie longue dure environ 5 % plus
longtemps, puisqu'on la court plus lentement.

### Et le test rouge a trouvé un défaut que j'avais introduit

Une seule défaillance sur 764 : `testProjectionScalesWithTheReferencePace`, qui exigeait qu'une
référence deux fois plus lente donne une prédiction exactement deux fois plus lente. C'est vrai
d'une loi de puissance et faux de la course à pied — la fraction de VO2max soutenue dépend de la
durée, et la personne plus lente passe bien plus de temps sur la distance. Comme le test de la
VMA, celui-ci verrouillait l'algèbre d'une formule en croyant verrouiller une vérité. **Deuxième
fois dans le même chantier.**

Mais en l'examinant, le vrai défaut, et il était de moi : **j'avais borné le VDOT entre 25 et 85,
deux chiffres inventés** — exactement ce que ce chantier existe pour retirer.

| | Mon premier jet | Ce que ça coûtait |
| --- | --- | --- |
| plancher | 25 | Quelqu'un qui court son 10 km en **1 h 40** a un VDOT de 17,2. Ramené à 25, son plan lui prescrivait des footings à **9:11/km** — plus rapides que son allure de course — et lui prédisait un marathon à 7:55/km, soit **plus vite au kilomètre que son propre 10 km** |
| plafond | 85 | Le record du monde du marathon au moment où ces lignes sont écrites, **1 h 59 min 30 s** (Sabastian Sawe, Londres, 26 avril 2026), vaut **86,45**. Une performance humaine réelle était rabotée |

Les deux bornes se nomment maintenant :

- **plancher 13** — la frontière entre marcher et courir. Une marche rapide se tient vers
  12:00/km ; un 10 km à cette allure, deux heures, donne 13,45. Le plancher est juste en dessous
  pour que cette frontière reste dedans.
- **plafond 90** — bien au-dessus du record, et délibérément : son travail est d'écarter une faute
  de frappe, pas de suivre les records. Un 5 km tapé « 8 min » vaut 145, un marathon tapé « 1 h »
  vaut 197. L'écart est si large que la valeur exacte du plafond n'a aucune importance — et le
  dire est le seul argument qui la rende défendable.

Et le bornage est désormais **séparé de la lecture**, parce que les deux appelants ne veulent pas
la même chose : un plan a besoin d'un ancrage même pour une saisie extravagante — mieux un plan
borné qu'aucun plan —, une prédiction non. Une référence hors plage repasse donc par Riegel, qui
ne prétend à aucune physiologie, au lieu d'être ramenée au plancher et affichée avec aplomb.

Le test de proportionnalité est remplacé par les deux propriétés qui sont vraies et qui comptent :
plus lent reste plus lent, et **une plus longue distance n'est jamais prédite plus vite que la
référence** — la promesse qui blesse, que le test de proportionnalité cherchait à atteindre sans
y arriver.

### Ce qui le garde

`RunUpTests/VdotTests.swift`, 20 cas, et le premier ne teste pas notre code pour lui-même : il
vérifie que les deux équations d'*Oxygen Power* retrouvent le VDOT de chaque ligne depuis le temps
de 10 km de cette même ligne. Si ce n'était pas vrai, la table recopiée serait une paraphrase et
tous les autres cas vérifieraient une invention. Les suivants vérifient l'inversion, allure par
allure, à la seconde près — footing (deux bords), seuil, intervalle, marathon, et les quatre
colonnes de temps de course. Puis l'ordre des allures sur toute la plage, la monotonie que la
dichotomie suppose, l'aller-retour allure↔VDOT, le refus de l'ultra, et le bornage d'une saisie
absurde.

Deux cas existent uniquement pour empêcher le retour en arrière : l'un montre que le rapport
footing/seuil n'est pas constant, donc qu'aucune multiplication ne peut le remplacer ; l'autre
fixe l'écart seuil→VMA à celui de la table, avec sa source. Deux autres gardent les bornes : que
le bornage reste séparé de la lecture, et que les bornes séparent bien un record du monde et une
marche-course — dedans — d'une faute de frappe — dehors.

`ci_scripts/check_allures.py` et ses **16 cas**. Trois règles : `PaceModel.zones` ne contient
aucune arithmétique sur un littéral décimal — la forme exacte du défaut, et la seule qu'il puisse
reprendre ; les quatre allures passent par `Vdot`, le marathon par `allureDeCourse` et non par une
fraction ; chaque fraction de `Vdot.Fraction` est nommée dans les cas, qui doivent porter au moins
sept lignes de la table **et citer leur source**. Trois des seize cas ne vérifient que les façons
dont ce contrôle pourrait passer vert pour la mauvaise raison — une signature reformatée, une table
amputée, une source effacée.

## Chantier 28 — « L'achat n'a pas abouti. », dit à quelqu'un qu'Apple vient de débiter (A4)

### L'item était mal posé, pour la quatrième fois

`PHASE2.md` disait « `SubscriptionService` existe, aucun test de parcours d'achat », avec un risque
« moyen, les achats se testent mal sans compte sandbox ». Les trois décisions du parcours étaient
déjà **sorties de StoreKit et déjà sous test** : `Entitlement` (8 cas), `OfferCodeOutcome` (6 cas),
`RestoreOutcome` (7 cas). Il ne manquait que la frontière StoreKit elle-même, qui ne se teste pas
sans configuration `.storekit` et `StoreKitTest`.

Mais en lisant le fichier pour l'écrire, une asymétrie à trente lignes d'écart.

### Le défaut

`applyRedemption(sheetFailed:)` attendait le droit d'accès jusqu'à 3,2 secondes, avec un
commentaire qui disait pourquoi : poser la question une seule fois « répondrait “rien” à quelqu'un
qui vient d'entrer un code parfaitement valide ».

`purchase(_:)`, trente lignes plus haut, la posait **une fois** :

```swift
await transaction.finish()
await refreshEntitlement()
return isSubscribed == true ? .subscribed : .failed
```

Cette ligne tombe après une transaction **vérifiée** et terminée — Apple a signé, l'argent est
engagé — et `Transaction.currentEntitlements` publie le droit quelques centaines de millisecondes
plus tard. Le paywall en tirait les trois pires conséquences possibles d'un coup :

1. le message **« L'achat n'a pas abouti. »** affiché à quelqu'un qui vient d'être débité ;
2. un `purchaseFailed` enregistré — donc un taux d'échec faux, qui pousserait à corriger du code
   qui marche, et la statistique qui devrait signaler le défaut est celle qu'il corrompt ;
3. l'écran laissé ouvert, bouton d'achat toujours actif. C'est exactement le raisonnement que le
   cas `.subscribed` du même fichier tient déjà pour expliquer pourquoi il ferme : « rien ne dit
   que ça a marché, et le geste naturel est de retaper ». Ici, retaper veut dire payer une
   seconde fois.

Le piège était donc **déjà connu, déjà documenté et déjà contourné** dans le même fichier. Deux
chemins, un seul corrigé. Et il ne se voit nulle part ailleurs que chez l'utilisatrice : dans un
simulateur, l'entitlement arrive instantanément.

### Ce qui a changé

| | Avant | Après |
| --- | --- | --- |
| Après une transaction vérifiée | une seule lecture du droit | l'attente bornée d'`attendreLeDroit()`, celle des codes promo |
| Droit pas encore publié | `.failed` → « L'achat n'a pas abouti. » | `.purchasedAwaitingUnlock` → « Paiement validé. Ton accès s'ouvre dans un instant. » |
| Statistique dans ce cas | `purchase_failed` | `purchase_completed`, avec `unlock: deferred` pour compter les fois où 3,2 s n'ont pas suffi |
| Écran | reste ouvert, bouton actif | se referme |
| Signature non vérifiée | indistincte d'un échec réseau | `.unverified`, et le droit tranche s'il est là |
| Où la décision vit | une ligne dans `SubscriptionService` | `PurchaseOutcome.decide`, pur, sans `import StoreKit` |
| L'attente | deux boucles jumelles, une seule corrigée | une fonction, `attendreLeDroit()`, appelée par les deux |

Le droit d'accès n'est **pas** mis à vrai à l'achat, et ce n'est pas un oubli : `refreshEntitlement`
reste la seule source, relue de `currentEntitlements`, pour qu'un remboursement referme l'accès.
Seul le message change.

Une annulation reste une annulation, même chez quelqu'un d'abonné par ailleurs. La règle « le droit
d'abord » de `RestoreOutcome` et `OfferCodeOutcome` ne s'applique qu'aux cas où StoreKit doute :
là-bas on **cherche** un droit, ici StoreKit parle d'un achat précis et il est formel. Confondre les
deux ferait compter une annulation comme une vente — c'est-à-dire fausserait la seule mesure qui
dise si le prix est le problème.

### Ce qui le garde

`RunUpTests/PurchaseOutcomeTests.swift`, 10 cas, dont le premier est le défaut lui-même : une
transaction vérifiée sans droit n'est jamais un échec, et son message n'est jamais celui de
l'échec.

`ci_scripts/check_paiement.py` et ses **16 cas**. Trois règles : une fonction qui rend une issue de
paiement n'a droit qu'à **un seul `return`**, et il appelle `<Issue>.decide(` ; chaque issue vit
dans `RunUp/Models/`, sans `import StoreKit`, avec son fichier de cas ; et **chaque cas de chaque
issue est nommé dans ses cas de test** — ajouter une issue sans la vérifier rouvrirait le trou par
le haut.

Trois des seize cas ne vérifient qu'une chose : comment ce contrôle pourrait passer vert pour la
mauvaise raison. Une signature reformatée et il ne reconnaît plus rien ; un `case a, b, c` sur une
ligne et il laisse passer trois cas d'un coup ; une énumération déplacée et il félicite une liste
vide. Il le dit dans les trois cas. Le quatrième a servi tout de suite : il comptait les six
entrées de `StoreKitResult` parmi les issues, 17 au lieu de 11, et aurait exigé qu'on « teste » des
entrées comme si c'étaient des réponses.

La nouvelle phrase est au catalogue dans les trois langues.

## Chantier 27 — soixante secondes de roue qui tourne (A3)

### L'item était mal posé, pour la troisième fois

`PHASE2.md` disait « le mode hors ligne et la connexion lente ne sont pas éprouvés ». La moitié
était fausse :

- **`PanneReseau`** classe les pannes, rend la bonne phrase, et `check_reseau.py` interdit à un
  écran d'affirmer une panne de réseau de son propre chef. **7 tests.**
- **`ClubActivityOutbox`** garde une sortie publiée hors réseau, le serveur l'accepte sans doublon
  (`ON CONFLICT (client_id) DO NOTHING`), la file est **attachée au compte** — terminer une course
  en mode avion puis connecter un autre compte ne publie plus la course de la première sur le fil
  de la seconde — et son `Codable` survit à une clé manquante. **4 tests.**

Le hors-ligne est donc traité, et mieux que je ne l'avais écrit. **La latence, elle, ne l'était
pas du tout.**

### Ce que la mesure a donné

**Aucun délai d'expiration n'était déclaré nulle part.** Les douze requêtes du dépôt partaient sur
`URLSession.shared` avec les valeurs d'Apple : **soixante secondes** par requête.

Soixante secondes de roue qui tourne, c'est une app cassée. `PanneReseau` savait écrire la bonne
phrase — elle arrivait une minute après que la personne avait compris toute seule.

Et ça ne se voit **jamais** en développement. Aller-retour réel sur notre API, `GET /api/me`, cinq
fois depuis une machine filaire le 10 novembre 2026 : **0,17 à 0,51 seconde**. Le défaut n'existe
que chez quelqu'un dans un train.

### Les chiffres sont mesurés, pas choisis

| | | pourquoi |
| --- | --- | --- |
| `interactif` | **15 s** | Trente fois le temps mesuré, cinq fois un mauvais aller-retour mobile qui FONCTIONNE. Le quart du défaut d'Apple. |
| `coach` | **60 s** | Le seul appel où attendre est normal : on vient de poser une question et un modèle rédige. Le client n'a pas à renoncer avant le serveur. |
| `televersement` | **60 s** | Une photo de plusieurs méga-octets sur un réseau lent prend légitimement plus de quinze secondes, et l'abandonner oblige à tout recommencer. |
| `arrierePlan` | **20 s** | Personne ne regarde : événements d'usage, rapports de panne, inscription aux notifications. |

### Et ça ne perd rien — c'est pour ça qu'on peut être bref

Ce qui compte est **rejoué** : la sortie publiée attend dans l'outbox, les statistiques dans leur
tampon, les rapports de panne reviennent au lancement suivant. Abandonner vite ne jette rien — ça
remplace une minute de gel par une phrase honnête et un nouvel essai plus tard.

### Ce qui le garde

`ci_scripts/check_delais.py` : tout `URLRequest(` doit être suivi, dans les six lignes, d'un
`timeoutInterval` **pris dans `Delais`**. Un délai écrit en dur sonne aussi — douze requêtes,
douze occasions de diverger. 7 cas, dont celui du délai posé trop loin de l'appel : on le lit là
où on lit la requête, pas sept lignes plus bas.

## Chantier 26 — la voix dit enfin la séance (B2) — et elle la disait en français à tout le monde

### Ce que je cherchais

Face à Runna, le guidage vocal par intervalle est ce qui manquait : la voix ne disait que deux
choses — « accélère un peu », « ralentis légèrement ». Rien sur le départ d'une répétition, rien
sur sa fin.

### Ce que j'ai trouvé en ouvrant le fichier

**Les phrases existaient déjà.** `beginSegment` écrit depuis longtemps « Échauffement terminé.
Première répétition : vise 4:30/km, foulée relâchée », « Récupération — souffle, foulée
relâchée », « Dernière répétition faite, bien joué ». Elles étaient **affichées à l'écran**, et
jamais dites.

Une consigne de fractionné affichée sur un téléphone qu'on ne regarde pas — parce qu'on court —
n'a pas été donnée.

### Et un défaut plus grave, trouvé en passant

Ces quatre phrases étaient des **littéraux Swift nus** passés à `showCue(_ message: String)`. Un
`String` n'interroge jamais le catalogue : **elles sortaient en français chez tout le monde**, au
départ de chaque répétition, sur l'écran le plus important de l'app.

Et les quatre clés étaient au catalogue, **traduites dans les trois langues**, depuis longtemps.
Quelqu'un avait fait le travail, et le paramètre le jetait. Soixante lignes plus bas dans le même
fichier, la consigne de pause automatique passe correctement par `String(localized:)`.

C'est le même défaut que la montre, au même endroit du produit : une traduction qui existe et que
personne ne demande.

### Pourquoi aucun des six contrôles ne le voyait

`check_strings.py` porte **six** règles pour six angles morts, chacune avec son histoire. Aucune
ne couvrait celui-ci : `showCue("…")` n'est ni `String(localized:)`, ni `Text("…")`, ni un
initialiseur de composant, ni un paramètre déclaré `LocalizedStringKey`. C'est un `String` nu, et
le type ne dit rien.

**La septième règle est donc NOMMÉE, pas devinée.** On ne peut pas décider par le type qu'un
`String` finira à l'écran : il faut le savoir. `PUITS` liste les fonctions dont on sait que
l'argument est affiché. Y ajouter une fonction est une décision — une règle qui devinerait
signalerait la moitié du dépôt.

Elle lit l'argument complet, parenthèses équilibrées, donc **les deux branches d'un ternaire** :
c'est exactement la forme qu'avait le défaut. Cinq cas, dont celui qui dit qu'un littéral passé à
une autre fonction n'est pas concerné.

### Ce qui change pour quelqu'un qui court

| | Avant | Après |
| --- | --- | --- |
| Départ d'une répétition | écrit à l'écran, en français | **dit à voix haute**, dans sa langue |
| Récupération | idem | idem |
| Fin de la dernière répétition | idem | idem |
| Sur un vélo | les consignes de course s'affichaient quand même | silence — `suitLePlan` les coupe |
| Le réglage | « Alertes vocales d'allure » | « Consignes vocales » — une seule question : le coach parle-t-il ? |

Un seul interrupteur, et c'est voulu : deux réglages pour deux sortes de phrases auraient demandé
à quelqu'un de deviner laquelle il voulait taire.

### Et une tolérance qui a dérivé avec le texte

`check_pluriel.py` tolère `n == 1` dans ce fichier — « ce n'est pas un singulier contre un
pluriel, c'est la première répétition contre les suivantes ». La tolérance s'accroche au TEXTE de
la ligne, pour ne pas dériver avec les numéros ; la ligne a été réécrite, donc elle a dérivé avec
le texte. C'est le prix de ce choix, et c'est le bon : une tolérance qui survit à une réécriture
couvrirait une ligne que plus personne n'a relue.

## Chantier 25 — l'état vide, écrit une fois (A5)

Règle 3 : chaque écran a ses états vide, erreur et chargement. Règle 4 : rien ne s'écrit deux
fois. Ici la seconde perdait — « Aucun composant d'état vide partagé. Zéro fichier ne porte un
`RUEmpty`. Chaque écran écrit le sien. »

### Ils divergeaient, et pas qu'un peu

Trois écrans pris au hasard, pour la même phrase — « il n'y a rien ici » :

| | couleur | interligne | marges |
| --- | --- | --- | --- |
| `FriendsView` | `text3` | 3 | verticale 6, puis 18 ailleurs |
| `HistoryView` | **`text2`** | aucun | horizontale de page |
| `ShoesView` | **`text2`** | 3 | haute 4 |

Deux couleurs de texte différentes pour dire la même chose : c'est la définition d'un système de
design qui ne couvre pas un cas.

### `RUEmpty`, et deux formes dont le choix n'est pas esthétique

**`.bloc`** occupe la place d'un contenu absent : icône, titre, une phrase, éventuellement un
bouton. C'est la forme d'un **écran** vide — l'historique sans course, le carnet sans paire, la
carte sans parcours.

**`.ligne`** ne pose qu'une phrase, parce que la section a déjà son en-tête et que lui ajouter un
titre le redirait. C'est la forme d'une **section** vide dans un écran qui, lui, a du contenu.

Remplacer une ligne par un bloc change la mise en page d'un écran qui marchait : le bloc se
réserve aux endroits où il n'y a vraiment rien d'autre. C'est pourquoi le balayage n'a pas tout
converti d'un coup.

### Ce qui est converti

| écran | forme | ce qui change |
| --- | --- | --- |
| `HistoryView` | `.bloc` | icône + titre, et une phrase réécrite |
| `ShoesView` | `.bloc` | idem |
| `HeatmapView` | `.bloc` | idem |
| `FriendsView` ×2 | `.ligne` | la couleur et l'interligne deviennent ceux du système |
| `ClubEventsSection` | `.ligne` | idem |

### Ce qu'il n'est pas, et c'est écrit dans le fichier

Ni un état d'erreur, ni un état de chargement. « Rien à montrer » et « ça n'a pas marché » sont
deux phrases différentes, et les confondre fait dire « aucune course » à quelqu'un dont la
requête vient d'échouer.

### Ce qui reste

Sept écrans portent encore une phrase d'état vide écrite à la main, toutes dans des sections où
le `.ligne` conviendrait. Elles ne divergent plus que par leurs marges, et les convertir une à
une demande d'ouvrir chaque écran pour vérifier que la mise en page ne bouge pas. À finir.

## Chantier 24 — le consentement aux statistiques d'usage (A2)

Le point que l'audit appelait « le plus discutable du produit » : « Aucun écran ne présente un
consentement explicite et révocable aux statistiques d'usage. La politique les décrit ; l'app ne
les propose pas à refuser. »

### Le problème que le dessin devait résoudre

Les événements de l'inscription sont enregistrés **depuis le premier écran** — c'est l'entonnoir,
et il n'a de sens que complet. Poser la question à la première seconde, avant d'avoir dit ce que
l'app fait, serait impoli et inutile : personne ne décide de ça devant un écran vide. Mais tout
envoyer d'abord et demander ensuite n'est pas un consentement.

### La réponse : trois états, et un tampon

`Analytics` a maintenant un consentement à **trois** états, et c'est le troisième qui résout tout :

| état | on enregistre | on envoie |
| --- | --- | --- |
| `pasDemande` | oui, dans le tampon | **non** |
| `accepte` | oui | oui — et ce qui était gardé part |
| `refuse` | **non**, et le tampon est vidé | non |

Un oui expédie ce qui attendait ; un non le **jette**. Rien ne part avant la réponse, et
l'entonnoir reste mesurable pour qui accepte.

La garde tient en deux lignes parce que le fichier était bien fait : `track`, `trackOnce` et
`trackAppOpenedIfNewSession` passent **tous les trois** par `enqueue`, et `sendNextBatch` est le
seul point d'envoi. C'est là que vivait déjà la garde du mode démonstration.

**Un refus n'enregistre même plus.** Fermer l'envoi suffirait à tenir la promesse — mais accumuler
dans un tampon des événements qu'on s'est engagé à ne jamais envoyer, c'est garder la chose tout
en disant qu'on ne la prend pas.

### Où la question est posée

**Étape 8 de l'inscription**, juste avant la connexion à Santé — pour que « CRÉER MON PLAN » reste
le dernier geste : un bouton qui annonce la fin ne peut pas être suivi d'un écran de plus.

**Deux boutons, et aucun n'est le défaut.** Pas de case pré-cochée, pas de « Continuer » qui vaut
oui. L'écran dit ce qui est mesuré (douze moments du parcours), ce qui ne l'est jamais (ce qu'on
écrit, la position, Apple Santé), et qu'on peut changer d'avis.

**Et révocable** : Profil → Réglages → Confidentialité. Sans ça ce n'est pas un consentement.

### Ce que l'insertion a fait tomber, et c'était voulu

Deux tests Swift pinaient la longueur de l'inscription, avec ce commentaire : « Si ça tombe en
rouge, c'est qu'une étape a été ajoutée ou retirée. » Ils sont tombés en rouge. Mis à jour : neuf
écrans de questions deviennent dix, et la phrase « plus que N écrans » compte cinq au lieu de
quatre.

### Et un nombre recopié que rien ne surveillait

**Neuf écrans écrivent leur numéro d'étape EN DUR dans leur titre** — « Étape 6 · ton rythme ».
Rien ne les reliait à leur place réelle. En insérant le consentement, `HealthConnect` est passée
de 8 à 9 et son sourcil annonçait toujours « Étape 8 » : le numéro que lit la personne qui
s'inscrit.

C'est exactement le défaut que `check_etapes.py` existait pour empêcher — « c'est le propre d'un
nombre recopié », dit son en-tête — mais il ne regardait que la logique, pas l'écran. Il compare
maintenant le numéro du sourcil à celui du `switch`. Un écran qui n'annonce aucun numéro n'est pas
concerné : ne rien dire n'est pas se tromper. Quatre cas de plus, 14 au total.

### Ce qui reste, et qui ne peut pas se faire d'ici

`privacy.html` décrit les statistiques mais ne dit pas qu'on peut les refuser. L'ajouter ferait
rougir `check_politique.py --exiger` jusqu'à ce que la page soit portée sur `main` — et son
en-tête met en garde contre exactement ça : « une chaîne rouge pendant des jours pour une action
qu'elle ne peut pas faire apprend à ignorer un rouge ». La phrase est donc à ajouter **et** à
porter dans le même geste.

## Chantier 23 — les trois portes juridiques (A6, A7, A8)

### A6 — un commentaire faux dans une déclaration légale

`PrivacyInfo.xcprivacy` portait un `TODO(privacy)` affirmant que la phase du cycle « part sans que
le réglage correspondant ne mentionne aucune transmission ». C'était vrai quand la phrase a été
écrite ; ça a cessé de l'être, et personne n'est revenu — **exactement le défaut contre lequel
l'en-tête de ce même fichier met en garde**, et qu'il avait déjà commis sur la localisation.

Mesuré dans `MoreSettingsView` le 10 novembre : `shareCyclePhaseWithCoach` est un réglage
**distinct** du suivi du cycle, **à l'arrêt par défaut**, dont le texte affiché **nomme le
destinataire comme un service extérieur** et précise que refuser ne change rien au programme —
« le calcul se fait sur ton téléphone ». C'est un consentement explicite, spécifique, séparé et
révocable : l'article 9 est satisfait, et il l'était déjà.

L'entrée `NSPrivacyCollectedDataTypeHealth` reste, et elle doit rester : quand la case est cochée,
la donnée part réellement.

### A7 — le manifeste de la montre : mesuré, plus deviné

Je refusais de trancher faute de source. La documentation d'Apple ne traite pas le cas d'un paquet
watchOS imbriqué et les sources publiques se contredisent. **Mais la validation d'Apple répond
elle-même** — c'est elle qui émet ITMS-91053. Journal d'archive du 10 novembre, Xcode 26.6 :

```
ValidateEmbeddedBinary …/RunUp.app/Watch/RunUpWatch.app
"com.hicsuntco.runup.watchkitapp" => "RunUp CI montre"
No errors uploading archive at '…/RunUp.ipa'.
UPLOAD SUCCEEDED with no errors
```

Un paquet contenant la montre **sans manifeste** passe la validation sans une erreur. Et c'est
cohérent avec la règle : ITMS-91053 s'appelle « Missing API declaration » et se déclenche sur
l'**usage** d'une API à motif obligatoire. `RunUpWatch` n'en appelle aucune.

**Ce qui rendrait la réponse fausse tient en une ligne** : un `UserDefaults` écrit dans la montre
pour y garder un réglage. Elle compile, les tests passent, et le refus tombe **à l'envoi**, après
quinze minutes d'archive.

`ci_scripts/check_manifeste.py` ferme la porte : pour chaque cible livrée, il compare les API à
motif obligatoire qu'elle appelle — les cinq familles d'Apple — et le manifeste qu'elle embarque.
Éprouvé en vrai : une ligne `UserDefaults` ajoutée à `WatchViews.swift` le fait sonner, en nommant
la catégorie à déclarer et le fichier fautif. 10 cas.

### A8 — l'item était mal posé, et la moitié était déjà faite

`check_politique.py` **va chercher la page publiée EN LIGNE** et compare le texte de chaque
section, commentaires ignorés, avec `--exiger` dans `server.yml`. C'est mieux que le garde-fou que
j'avais proposé dans `PHASE2.md`, et ça existait avant.

Et l'item parlait des « deux pages qu'Apple affiche ». **Il n'y en a qu'une.** Mesuré :

| | |
| --- | --- |
| URL de politique sur la fiche | `https://hicsuntco.github.io/RUNUP/privacy.html` |
| URL de support sur la fiche | `mailto:charlottegrudep@gmail.com` |
| Dans l'app, « nous contacter » | le même `mailto:`, à deux endroits |
| Ce qui pointe vers `support.html` | **rien** |

`support.html` est publiée sur GitHub Pages et personne ne l'atteint. Quatre documents du dépôt —
`AUDIT.md`, `RELEASE.md`, `PROGRESS.md`, `PHASE2.md` — affirmaient le contraire. Corrigés.

**Ce qui reste, et c'est une décision de fiche, pas de code** : en faire la vraie URL de support,
ou la supprimer. Une page se corrige sans passer par une revue ; un `mailto:` non.

### Et une règle 4 réparée au passage

`sans_commentaires` — la fonction qui décide ce qu'un contrôle VOIT dans du Swift — existait en
deux copies, et `check_manifeste.py` allait en écrire une troisième. Trois copies, trois façons de
diverger sur ce qui est vu. Elle vit maintenant dans `ci_scripts/swift.py`, et les trois
l'importent.

## Chantier 22 — le fond clair devient le défaut (D2)

### Le sombre n'avait jamais été choisi

`ThemeStore` lisait `UserDefaults.bool(forKey:)`, qui rend **`false` quand la clé est absente**.
Et `UserProfile.isLightMode` valait `false`, la valeur qu'une propriété booléenne prend quand
personne ne se prononce. Le thème sombre par défaut tombait donc de deux API, pas d'une décision.

### Quatre endroits décidaient, et il fallait les quatre

| Où | Quand ça décide | Avant | Après |
| --- | --- | --- | --- |
| `UserProfile.isLightMode` | un profil neuf | `false` | **`true`** |
| `ThemeStore.init` | tout premier lancement, avant qu'un profil existe | `d.bool(forKey:)` → `false` | `d.object(forKey:) as? Bool ?? true` |
| `DailyGoalsSnapshot.empty` | le widget avant que l'app ait jamais publié | `false` | **`true`** |
| L'aperçu de la galerie de widgets | la galerie | `false` | **`true`** |

N'en changer que deux aurait donné un widget sombre à côté d'une app claire — exactement la
famille de défauts que ce dépôt passe sa semaine à trouver.

### Le seul endroit qui reste à `false`, et c'est voulu

Le décodage d'un instantané de widget qui n'a pas la clé : `?? false`. Un instantané sans cette
clé a été écrit par une version de l'app ANTÉRIEURE à la clé, donc par quelqu'un qui a déjà un
profil — et un profil déjà enregistré reste en sombre. Mettre `true` là afficherait un widget
clair à côté d'une app sombre, le temps d'un lancement.

### CE QUE ÇA NE FAIT PAS, ET JE L'AI DIT TROP VITE LA PREMIÈRE FOIS

J'avais annoncé qu'on pourrait distinguer « n'a jamais touché le réglage » de « a choisi le
sombre », en regardant si la clé `apparence.clair.v1` existe dans les préférences. **C'est faux.**
`AppState` appelle `ThemeStore.appliquer(...)` à CHAQUE lancement pour synchroniser depuis le
profil, donc la clé est écrite pour tout le monde, dès la première ouverture.

Rien dans l'app n'enregistre si quelqu'un a choisi son thème. Les deux cas sont stockés à
l'identique, `isLightMode = false`. Il n'y a donc aucune façon honnête de retourner l'app de
quelqu'un sans risquer de retourner celle d'une personne qui avait décidé.

**Conséquence, et elle compte : les comptes existants ne changent pas.** Le clair est le défaut
des INSTALLATIONS NEUVES. Sur un téléphone qui a déjà l'app, rien ne bouge — il faut passer par
Profil → Apparence.

### Et la fiche App Store était déjà claire

`screenshots.py` compose à partir de `appstore/raw/<langue>/clair/` : **la passe claire livre la
fiche, la passe sombre sert au diagnostic.** Le magasin montrait donc du clair pendant que l'app
ouvrait en sombre. Cette décision referme cet écart au lieu d'en ouvrir un.

### Ce que la bascule a fait rougir, et pourquoi c'était juste

`check_banniere.py` a refusé la chaîne sur `diagnostic/inscription.png`, **88,7 % de pixels clairs
en haut dans les trois langues**, là où le plafond est à 25 %.

Ce n'était pas une bannière du système. Le contrôle mesure la clarté du haut de l'écran et suppose
que tout ce qui n'est pas dans `clair/` est sombre. Or l'écran d'inscription est photographié
**sans aucune graine** — `CapturesUITests` l'écrit : « aucune graine n'est posée : `onboarded`
vaut `false` à la création, donc l'app ouvre sur l'inscription d'elle-même ». Sans profil, il n'y
a pas d'`isLightMode` à appliquer : l'écran prend le défaut d'amorçage, désormais clair.

**L'app obéissait, et le garde-fou l'a accusée.** Il apprend donc que l'inscription précède le
profil, et la raison est écrite dans son en-tête.

Son message disait aussi « relancer la chaîne suffit : la bannière est une affaire de minutage ».
Ici, relancer n'aurait rien changé, et le tell était dans le relevé lui-même : **la même image, à
88,7 %, trois fois.** Une bannière ne tombe pas trois fois sur la même image au même pourcentage.
Le message le dit maintenant tout seul quand il voit ce motif.

Trois cas de plus dans `test_banniere.py` : l'inscription sort du relevé, une vraie bannière sur
un AUTRE écran sonne toujours, et le message reconnaît les trois langues. 11 cas.

### Et l'écran, regardé

L'inscription s'ouvre en clair — c'est le premier écran que voit quelqu'un, et c'est celui dont la
décision change le plus. La séance en cours, elle, reste sombre comme prévu : son jeu de jetons
`Ink` ne suit pas le thème, et c'est voulu.

## Chantier 21 — l'image iPad n'aurait jamais dû exister, et c'est moi qui l'avais fabriquée

### Ce que Charlotte a dit

« L'app iPad doit être différente, on ne va pas courir avec son iPad. »

### Ce que la mesure a donné

`TARGETED_DEVICE_FAMILY` vaut **1** dans les réglages de base comme dans ceux du widget ; seule la
montre porte 4. **RUNUP est une app iPhone**, et Apple ne demande donc aucune image d'iPad.

Et le dépôt le savait. `RELEASE.md` portait déjà cette phrase, mot pour mot :

> « L'iPad, lui, ne pose pas la question — `TARGETED_DEVICE_FAMILY` vaut 1 […], donc RUNUP est une
> app iPhone et Apple ne demande aucune image d'iPad. »

Et `asc.py` porte une commande écrite exprès pour la **retirer** de la fiche, dont le commentaire
dit : « une mise en page iPhone étirée dans un cadre d'iPad sur une app qui ne vise que l'iPhone.
Ces images ne se corrigent pas, elles se retirent. »

**J'ai passé deux jours à fabriquer, garder et rafraîchir une image que le dépôt avait déjà
décidé de supprimer.** Je l'ai régénérée deux fois, j'ai ajouté une exception au `.gitignore`
pour la nourrir, j'ai cassé un clone neuf en le faisant, et j'ai ouvert une tâche pour résoudre
structurellement un problème qui n'existait pas. Aucun de mes garde-fous ne pouvait l'attraper :
ils vérifient qu'une image est à jour, pas qu'elle a lieu d'être.

### Ce qui a changé

| | Avant | Après |
| --- | --- | --- |
| `requis.py` | composait une image iPad (fond, accroche, cadre d'appareil, filets) et posait la montre | pose la montre, c'est tout — **160 lignes de moins, et plus de dépendance à Pillow** |
| `appstore/requis/ipad/` | trois images versionnées | supprimé |
| `appstore/raw/*/1-accueil.png` | trois captures versionnées contre la règle du `.gitignore` | supprimées, la règle redevient simple |
| Exception du `.gitignore` | ajoutée la veille pour nourrir la composition | retirée, elle aura vécu vingt-quatre heures |
| `appstore.yml` | une action `pousser-l-ipad` | retirée |
| `captures.yml` | composait l'iPad à chaque passage | ne compose plus rien, vérifie la montre |
| `SOURCES.json` | 6 entrées | 3 |

### Ce qui reste à faire UNE FOIS, à la main

La fiche publiée porte encore la capture iPad d'août — App Store Connect recopie les captures de
la version précédente, tous formats confondus. Workflow **App Store**, action
**`nettoyer-les-captures`**, champ « retirer » : **`APP_IPAD_PRO_3GEN_129`**.

Et elle reviendra à chaque nouvelle version tant qu'on ne la retire pas. C'est écrit dans
`RELEASE.md`.

### La question produit, qui reste ouverte

S'il devait y avoir une app iPad un jour, ce ne serait pas la même app : pas d'écran de séance en
cours, mais le plan, les stats, le fil du club, le coach. C'est un chantier à part entière et il
n'est pas dans la liste de la phase 2 — à y ajouter si tu le veux.

## Chantier 20 — le verre dépoli sort de l'interface

La seconde moitié de la règle 7, et l'inverse du chantier 19 : **aucun jeton ne distribuait le
verre dépoli**. Chaque écran écrivait `.ultraThinMaterial` à la main. Douze emplois dans sept
fichiers, donc douze décisions, lues une par une.

### Ce que la lecture a montré

**Quatre d'entre eux ne floutaient presque rien.** La barre d'onglets empilait un
`.ultraThinMaterial` à 90 % **devant** une carte à 92 % en clair : le flou ne captait que **8 %**
de la page. Le sélecteur de discipline faisait pareil deux fois, devant une carte à 96 % — donc
4 %. Une couche de composition de plus sur l'écran le plus vu de l'app, pour un effet que personne
ne peut nommer.

**Trois autres étaient posés sur une carte MapKit**, et leur contraste dépendait donc de ce qui
défilait dessous. La bulle du coach portait **quinze lignes d'arithmétique** pour cette seule
raison : il avait fallu monter son fond à 92 % d'opacité pour que le sourcil « Coach · en direct »
tienne 4,5:1 au-dessus d'une carte claire.

### Ce qui a changé

| | Avant | Après |
| --- | --- | --- |
| Barre d'onglets | verre 90 % devant `card` 92 % | `card`, opaque |
| Sélecteur de discipline (libellé et rond inactif) | verre 90 % devant `card` 96 % | `card`, opaque |
| Décompte de départ | `.ultraThinMaterial` + un `colorScheme` posé à la main pour le forcer en sombre | `Ink.ecran`, opaque |
| Pastille d'état de la séance | teinte d'accent sur du verre — elle changeait de couleur selon la carte dessous | la même teinte sur `Ink.fond` |
| Bandeau de consigne | blanc 9 % sur du verre | blanc 9 % sur `Ink.fond` |
| **Bulle du coach** | `Ink.fond` à 92 % + verre, et quinze lignes pour justifier le 92 | `Ink.fond` opaque, et l'arithmétique disparaît |
| Bouton « agrandir le tracé » | verre sur le tracé | `card` |
| Tracé plein écran : carte d'infos et croix | verre sur MapKit | `card` |
| Retour posé sur une image | verre sous un noir à 45 % | un noir **opaque à 55 %**, calculé |
| Barre d'écriture des commentaires | verre | `card` |

### Deux chiffres, calculés et pas choisis

**La bulle du coach.** Avec un fond opaque, le contraste du sourcil ne dépend plus de la carte.
Les huit palettes, mesurées sur `Ink.fond` (#0E0E14) : rose **6,24:1**, violet 7,13, magenta 7,80,
corail 8,94, bleu 9,51, ambre 13,41, cyan 14,15, lime 17,24. La plus basse gagne **un point
entier** sur ce qu'elle valait à 92 % d'opacité, et aucune ne bouge plus quand la carte défile.

**Le retour posé sur une image.** Le pire cas est une image BLANCHE. À l'ancien noir de 45 %, le
fond composé vaut 0,55 et le chevron blanc n'y tient que **3,35:1** — au-dessus du seuil des
icônes, sous celui du texte courant, et c'est le verre qui rattrapait la différence. À **55 %**,
le fond vaut 0,45 et le chevron tient **4,76:1**. Sur une image sombre, le disque ne peut
qu'améliorer : jusqu'à 21:1.

### Deux noms qui mentaient

`FrostedBackButton` est devenu `OverImageBackButton` — il n'a plus rien de dépoli. Et l'en-tête de
`TabBarView` annonçait « Floating frosted-glass tab bar » : elle ne l'est plus.

### Ce qui le garde

`ci_scripts/check_verre.py`, même forme que `check_degrade.py` : un compte par fichier contre une
liste d'exceptions qui porte chacune sa raison. **La liste est vide, et c'est l'état qu'on veut.**
Elle existe pour qu'une exception future soit écrite avec sa raison plutôt que glissée dans un
écran — et la question à laquelle il faudra répondre est « qu'est-ce qu'un flou fait ici qu'un
aplat ne ferait pas ». Dans les douze cas de ce dépôt, la réponse était « rien ».

Sur le dépôt d'avant : **7 fichiers, 12 verres**. Après : zéro.

`test_verre.py`, 18 cas. Deux disent ce qui n'est PAS un verre dépoli — `chart.bar.fill` et
`RUSpacing.tabBarHeight` — parce que `.bar` EST un `Material` de SwiftUI et qu'une expression trop
large bloquerait le dépôt sur un nom d'icône. Un garde-fou qui refuse un nom de symbole finit par
être désactivé.

## Chantier 19 — le dégradé sort de l'interface

Premier chantier de la phase 3, et c'est le système de design — le brief l'impose, et la mesure
dit pourquoi il avait raison.

### Ce qui était faux

Vingt-quatre fichiers portaient un dégradé. **Personne n'avait mal travaillé** : `AccentTheme`
donne à chaque palette une couleur de queue (`tail`), et `RUColor` exposait `accentGradient`
(rose2 → rose), `violetRoseGradient` (violet → rose), `heroGradient` et `traceBackground`. Les
écrans appelaient le système de design, exactement comme il faut. **C'est le système qui
distribuait le dégradé.**

Corriger les écrans sans corriger les jetons aurait tenu une semaine.

### Ce qui a changé

| | Avant | Après |
| --- | --- | --- |
| `accentGradient` (rose2 → rose) | 7 appels : bouton principal, pastilles, sélecteurs, avatar, carte du fil, paywall | supprimé — `RUColor.rose`, un aplat |
| `violetRoseGradient` | pastille de niveau et jauge d'XP du club, bouton de l'abonnement | supprimé — `RUColor.violet` |
| `heroGradient` | lavis d'accent à 12 % descendant vers la carte, 11 cartes héros | `heroSurface`, un aplat à **6 %** — la moyenne du lavis qu'il remplace |
| `traceBackground` | vignette `#1A1926` → `#0E0D16` sous chaque tracé GPS | `#14131E`, le milieu exact des deux |
| `pageBackground` | un `LinearGradient` à deux arrêts identiques, « pour pouvoir y revenir un jour » | une `Color` — on n'y reviendra pas |
| Bouton RUN de la barre | dégradé rose2 → rose, au centre de tous les écrans | aplat d'accent |
| Bouton principal | dégradé en clair, aplat en sombre — **les deux thèmes ne montraient pas le même bouton** | aplat dans les deux |
| Nuancier de Profil → Apparence | pastilles `primary → tail` : on choisissait un dégradé et on recevait un aplat | la couleur qu'on choisit, et rien d'autre |
| Halo rose de l'onboarding | posé SOUS `pageBackground` dans le même `ZStack`, donc entièrement masqué — c'était noté, et laissé | parti |
| Panneau de commandes de la séance | dégradé `fond` 60 % → `fond` sur du verre dépoli | `Ink.fond`, la couleur que le jeu de jetons avait déjà pour ça |
| La montre | bouton de départ, anneau pointillé et deux anneaux de progression en rose → violet | aplat d'accent |
| `LinearBar.gradient` | un paramètre, trois appelants | supprimé |

**Le panneau de la séance est le seul endroit où je m'étais trompé en classant.** Je l'avais rangé
dans « voile de lisibilité », sans regarder. C'est le fond d'un panneau, et `Ink.fond` existait
depuis longtemps pour ça — « le fond des surfaces de cet écran », un cran au-dessus de `Ink.ecran`.
Le verre dépoli part avec : il n'était visible qu'à travers les 60 % du haut du dégradé.

### Ce qui reste, et pourquoi

Treize dégradés dans dix fichiers, chacun avec sa raison écrite dans `check_degrade.py`. La règle
appliquée n'est pas « aucun dégradé » mais celle-ci :

> Un dégradé est interdit comme **décoration** d'un écran. Il reste permis quand il **porte une
> information**, quand il **rend lisible**, ou quand il appartient à une **image produite**.

- **La marque** : `brandGradient`, l'icône, le splash et le logo. C'est ce que la DA autorise.
- **Une image produite** : les cartes de partage, les images de vidéo, l'avatar fabriqué pour
  quelqu'un qui n'a pas mis de photo.
- **Un voile qui sert à lire** : le noir sous le texte posé sur un tracé GPS, le fondu en bas du
  défilement du récap.
- **La couleur qui porte une information** : l'anneau des objectifs du jour, dont chaque arc vire
  vers la couleur de son **voisin** pour que les deux se rejoignent dans la même teinte et que
  l'anneau se lise comme un seul ruban ; et l'aire sous une courbe, qui s'efface vers le bas parce
  que c'est la convention de lecture d'un graphe.

### Ce qui le garde

`ci_scripts/check_degrade.py` compte les dégradés **par fichier**, contre une liste d'exceptions
qui porte chacune sa raison. Un de plus, un de moins, ou un fichier qui n'en porte plus aucun mais
reste dans la liste : il parle dans les trois cas. Sur le dépôt d'avant il sort **13 plaintes** ;
sur celui d'après, zéro.

`test_degrade.py`, 16 cas. Cinq disent qu'un dégradé **nommé dans un commentaire** ne compte pas —
sans eux, le garde-fou refuserait un fichier pour la phrase qui raconte sa correction, et la
moitié des fichiers de ce chantier en portent une. Un cas a trouvé une exception dont la raison
tenait en une ligne : c'était le panneau de la séance, mal classé.

Et l'expression de recherche avait une faute, trouvée en écrivant ses cas : une anti-recherche
arrière excluait `Color.rose.gradient`, c'est-à-dire exactement le raccourci qu'elle devait voir.

### Ce que ça invalide, et qui n'est pas encore refait

**Toutes les captures de l'App Store.** `check_requis.py` l'a dit tout seul dès que le code a
changé — « le code a changé : fa665226059b → 3dd86db7a0dc » sur les trois images de montre. Les six
captures iPhone montrent le même dégradé sur le bouton RUN, les pastilles et les boutons.

Ce chantier n'est donc **pas terminé** tant que les deux chaînes n'ont pas rephotographié l'app et
que les images ne sont pas versées. C'est la seule raison pour laquelle `tout.sh` n'est pas vert
à ce commit, et c'est un garde-fou qui fait son travail, pas un défaut.

### Ce que la chaîne a rendu, et ce qu'elle a fait trouver

Les trois chaînes sur `e594cae`. « Capture de la montre » verte, « Captures App Store » verte —
**donc l'app iPhone compile**, puisque cette chaîne la construit et la pilote sur simulateur. Et
« TestFlight » rouge, arrêtée AVANT la compilation par le garde-fou des captures périmées, ce qui
est exactement son travail.

Les six captures iPhone, la montre et l'iPad sont refaites et versées. Le bouton RUN de la barre
d'onglets, photographié avant et après : un dégradé vertical avec un halo, puis un aplat d'accent.

**Et en vérifiant d'où venaient ces images, j'ai trouvé plus gros que le chantier.**

### L'image iPad de l'App Store était composée d'une capture du 30 août

`appstore/raw/fr-FR/1-accueil.png` porte la mention `36ed586 — 2026-08-30 — « Add files via
upload »` : quatre captures déposées à la main, en français seulement, jamais revues depuis.
`requis.py` compose l'image iPad À PARTIR DE CE FICHIER, et `appstore.yml` la pousse chez Apple
DEPUIS LE DÉPÔT (`--dir appstore/requis/ipad`), pas depuis l'artéfact.

Donc la fiche App Store montrait, sur iPad, l'app telle qu'elle était il y a trois mois.

**Et le garde-fou écrit ce matin ne pouvait pas le voir.** `check_requis.py` vérifie que l'image
livrée est cohérente AVEC SA SOURCE — pas que la source est fraîche. L'entrée iPad n'avait même
pas d'`empreinte_code`, contrairement aux trois de la montre : un changement de code ne
l'invalidait donc pas. L'image était parfaitement conforme à une capture périmée.

Les captures iPhone, elles, n'ont jamais eu ce problème : `appstore.yml` va les chercher dans
l'artéfact de la dernière exécution réussie de `captures.yml`. C'est le bon mécanisme — et c'est
celui que l'iPad n'avait pas.

**Corrigé ici** : les trois `1-accueil.png` de l'artéfact d'aujourd'hui remplacent la capture
d'août, les trois autres fichiers d'août sont supprimés (rien ne les lisait, et ils avaient déjà
provoqué un `file exists` à l'extraction — c'est écrit dans `appstore.yml`), et l'image iPad existe
pour la première fois **dans les trois langues** au lieu du seul français.

### Ce qui reste ouvert, et que je n'ai pas fait

- **L'image iPad reste une copie versionnée**, donc elle redeviendra périmée au prochain chantier
  qui touche l'accueil. Le bon correctif est structurel : que `appstore.yml` aille la chercher dans
  l'artéfact, comme il le fait déjà pour les six captures iPhone. Un garde-fou de plus ne ferait
  que signaler plus tôt une copie qui n'a pas à exister.
- **Le verre dépoli.** Six fichiers portent encore un `Material`, dont la barre d'onglets
  (`.ultraThinMaterial`). La règle 7 l'interdit aussi. Celui-ci traitait le dégradé, et un
  chantier à la fois.
- **La phrase du bas de la montre n'est pas « coupée », elle est sous la ligne de flottaison.**
  L'écran est un `ScrollView` : le texte s'affiche entier si on fait défiler. Je l'avais annoncé
  comme une troncature, c'était faux, et ça change le correctif — ce n'est pas une réparation de
  mise en page mais un arbitrage de hiérarchie sur un écran de 46 mm.

## Chantier 18 — la montre et le widget parlaient français à tout le monde

### Ce qui était faux

`project.yml` déclarait, sur **trois cibles**, les polices et le catalogue de traductions sous une
clé `resources:`. **Cette clé n'existe pas dans XcodeGen.** `Docs/ProjectSpec.md` § Target ne la
liste pas parmi les clés d'une cible, `Target.init(jsonDictionary:)` n'a aucune branche pour elle,
et `SourceGenerator.getAllSourceFiles` ne regarde que `target.sources`. La valeur est lue puis
jetée, sans erreur ni avertissement — ticket XcodeGen #1645, ouvert (XcodeGen 2.46.0).

### Ce que ça coûtait, mesuré dans le paquet construit

Sonde de `RunUpWatch.app` (workflow « Capture de la montre », commit `5cadd52`) :

| attendu | présent |
| --- | --- |
| `fr.lproj`, `en.lproj`, `es.lproj` | oui |
| `Localizable.strings` dans chacun | **non, aucun** |
| `Inter-Medium/Bold/SemiBold.ttf` | **non, aucun** |

Donc, pour tout le monde et depuis le premier jour de la cible montre : **la montre parlait
français quelle que soit la langue du téléphone** — chaque `Text("Courir")` retombait sur sa clé,
qui est française et parfaitement lisible — et **elle s'affichait dans la police système, pas en
Inter**, malgré les trois fichiers enregistrés dans son `UIAppFonts`.

**Le widget de l'écran d'accueil avait le même défaut**, pour la même raison : ses deux ressources
partagées sont hors de `RunUpWidgets/`. « BOUCLÉS », « SÉANCE », « KCAL » en français chez une
anglophone, dans la police système, à côté d'une app correctement traduite. Celui-là n'était pas
cherché : c'est le garde-fou écrit pour la montre qui l'a nommé.

L'app iPhone n'a jamais été touchée : son unique entrée `sources: - path: RunUp` contient
`RunUp/Resources/`. Sa clé `resources:` ne faisait rien non plus, elle redéclarait ce qui entrait
déjà — **retirer cette clé ne peut donc pas changer le binaire iPhone**.

### Pourquoi rien ne l'a signalé

Le build était vert : aucune ressource ne manque à la compilation. `check_fonts.py` était vert, et
il avait raison de l'être — il compare le code, l'`UIAppFonts` et les noms PostScript des fichiers ;
« livrée » y veut dire « le fichier existe dans `RunUp/Resources/Fonts` », jamais « la cible
l'embarque ». Les captures de la montre montraient un écran français, qu'on prenait pour la capture
française. Et le commentaire de `project.yml` disait la chose **au passé** : « sans lui, la montre
restait entièrement en français » — une correction qui n'avait jamais eu lieu.

**Ma première sonde m'a fait annoncer le contraire.** Elle vérifiait que les trois dossiers `.lproj`
existaient. Ils existaient. J'ai conclu que le paquet allait bien, et je l'ai écrit. La seconde a
regardé dedans : rien. J'avais mesuré le contenant.

### Ce qui a changé

| | Avant | Après |
| --- | --- | --- |
| Ressources partagées | sous `resources:`, jetées en silence | sous `sources:` avec `buildPhase: resources` |
| Clé `resources:` | sur 3 cibles | nulle part |
| Langue de la montre | français pour tout le monde | celle du téléphone |
| Police de la montre et du widget | police système | Inter |
| Clé de cible inconnue | acceptée sans un mot | refusée par `check_spec.py` |
| Police enregistrée non embarquée | invisible | refusée |
| Cible affichant du texte sans catalogue | invisible | refusée |

### Ce qui le garde

**`ci_scripts/check_spec.py`** (nouveau) refuse toute clé de cible ou d'entrée `sources:` absente
des listes documentées, toute valeur inconnue de `buildPhase` et de `type`, toute police enregistrée
dans un `UIAppFonts` que sa cible n'embarque pas, et toute cible qui affiche du texte sans embarquer
de catalogue de chaînes. Sur le `project.yml` d'avant il sort **11 plaintes** ; sur celui d'après,
zéro. Lancé dans `testflight.yml` avant la construction, parce qu'il lit un fichier et coûte une
seconde.

Il lit le YAML **à la main** : le python du runner macOS n'a pas PyYAML et ce job n'installe rien —
la décision est déjà écrite dans `check_cablage.py`, et ce script l'avait d'abord enfreinte. Un
lecteur maison qui se trompe en silence serait pire que pas de contrôle du tout, donc il **refuse**
tout ce qu'il ne comprend pas (tabulation, bloc littéral, ancre, accolade, ligne inclassable), et
`test_spec.py` **compare sa lecture du vrai `project.yml` à celle de PyYAML** partout où PyYAML
existe. Cette comparaison a trouvé une faute dans mon lecteur au premier essai :
`- applinks:runup-nu.vercel.app`, sans espace après le deux-points, était lu comme une table au
lieu d'une chaîne.

**`.github/workflows/montre.yml`** : la sonde est devenue un garde-fou. Elle exige un
`Localizable.strings` dans chacune des trois langues, exige que « Courir » rende **trois valeurs
différentes** — un catalogue compilé peut très bien produire trois fichiers qui rendent tous la clé
française, et c'est exactement le symptôme qu'on vient de passer une journée à ne pas voir — et
exige que chaque police de l'`UIAppFonts` soit présente dans le paquet.

**`ci_scripts/test_spec.py`** : 29 cas. Les deux premiers sont le défaut d'origine reconstitué ; six
disent qu'une déclaration VALIDE ne sonne pas, parce qu'un garde-fou qui refuse tout est aussi
inutile qu'un garde-fou qui accepte tout.

### Ce que la chaîne a rendu, une fois corrigé

Run 5 de « Capture de la montre », commit `a0d27d0`, vert de bout en bout. Le paquet construit :

```
fr : « Courir » → Courir      ✓ Inter-Medium.ttf
en : « Courir » → Run         ✓ Inter-Bold.ttf
es : « Courir » → Correr      ✓ Inter-SemiBold.ttf
```

Les trois captures ouvertes une par une : « Aujourd'hui / Course libre / Courir », « Today / Free
run / Run », « Hoy / Carrera libre / Correr ». Comparées à celles d'avant sous la barre d'état,
**23,6 % des pixels ont changé** et la graisse d'« Aujourd'hui » n'est plus la même : ce n'est pas
seulement la langue qui a bougé, c'est le rendu.

`appstore/requis/montre/` porte désormais **trois** images au lieu d'une, chacune avec l'empreinte
de sa source ET l'empreinte du code qui l'a dessinée. L'entrée `source: null` de `SOURCES.json` —
celle qui portait le constat « faite à la main, et ne montre pas l'app » — a disparu.

### Ce que ça invalide

Toutes les captures de montre prises jusqu'ici montrent une app dans la mauvaise police et dans la
mauvaise langue. La note donnée à l'écran de course au poignet dans `AUDIT.md` § 9 a été mise sur
une image qui n'était pas celle de l'app. **Elle est à refaire.**

### Deux écarts avec la DA, vus sur l'image d'aujourd'hui et NON corrigés

Ce chantier-ci était la livraison des ressources. Ces deux-là sont des décisions de design, donc
ils attendent la phase 2 :

1. **Le bouton « Courir » est un dégradé rose → violet, en plein milieu de l'interface.** La règle
   7 dit « pas de dégradés dans l'interface », et la DA réserve le dégradé rose-violet à l'icône,
   au splash et au logo. L'accent d'action est `#F0225F`, plat. C'est l'élément le plus important
   de l'écran, et c'est l'infraction la plus visible du produit.
2. **La phrase du bas est coupée par le bord de l'écran, dans les trois langues** : « Cours à ta
   sensation — ta séance », « Run by feel — your session is on its », « Corre a tu ritmo; tu sesión
   llega ». Aucune des trois ne finit.

### Ce qui reste ouvert

- **`RunUpWatch` n'embarque aucun `PrivacyInfo.xcprivacy`**, là où l'app et le widget ont le leur.
  La cible montre n'appelle aucune API « à motif obligatoire » (vérifié : ni `UserDefaults`, ni
  `FileManager`) et n'envoie rien au serveur elle-même, donc l'absence se défend. Mais je n'ai pas
  de source Apple qui tranche pour un paquet de montre embarqué. **À décider avant le prochain
  envoi, pas à deviner.**
- **Le widget ne déclare pas de `CFBundleLocalizations`.** Avec le catalogue désormais livré, ses
  `.lproj` devraient suffire à faire découvrir ses langues. *Devraient* : ça se mesure sur un
  appareil, et ça ne l'a pas été.

## Chantier 17 — rejoindre un club sans en connaître un seul

### Ce qui était faux

La carte « Rejoindre un club » demandait un code à six lettres. Le code a été retiré, avec cette
raison écrite dans `db/schema.sql` :

> « Un code suppose qu'on l'ait reçu de quelqu'un, donc qu'on sache déjà que le club existe —
> c'est-à-dire tout ce qu'une recherche rend inutile. »

Le raisonnement était juste et il n'a pas été poussé jusqu'au bout. La recherche qui l'a remplacé
exige **deux caractères du nom**, et le serveur refuse en dessous (`handleSearchClubs` rend une
liste vide pour `q.length < 2`). Elle suppose donc elle aussi qu'on sache déjà qu'un club existe
et comment il s'appelle. Quelqu'un qui ouvre cette carte sans connaître un seul nom voyait un
champ vide et rien d'autre : la même porte fermée, deux crans plus loin.

### Ce qui a changé

Champ vide, cinq clubs ouverts. **Pas un annuaire** : une liste qu'on fait défiler demande de
choisir, cinq lignes demandent d'en essayer une.

L'ordre les choisit pour qu'on arrive dans un club **vivant** plutôt que dans le plus gros — une
séance à venir d'abord, puis un mur qui a parlé dans les quatorze derniers jours, puis le nombre
de membres. Quatorze jours et pas sept : sept ferait disparaître la mention pendant les vacances
scolaires, c'est-à-dire au moment où quelqu'un cherche justement avec qui courir.

Et chaque ligne porte **sa raison** — « Une séance prévue », « Actif ces jours-ci ». C'est la
règle déjà écrite pour les suggestions de personnes : une liste de noms sans explication
ressemble à un annuaire, et on ne suit pas un annuaire. Une séance à venir passe devant un mur
actif, parce que l'une dit où se présenter samedi et l'autre seulement que le club n'est pas
mort.

### Ce qui a été refusé

**Classer par proximité.** C'était la version la plus utile, et elle demandait d'envoyer la ville
ou les coordonnées de quelqu'un pour obtenir une liste de suggestions : une collecte de plus, à
déclarer au manifeste, dans la politique et chez Apple — le jour même où la fiche App Privacy
venait d'être remise d'équerre. Pour cinq lignes, non.

### Ce qui le garde

`lib/clubsSuggeres.js` porte ce qui se calcule sans base de données, donc ce qui s'éprouve sans
elle — même découpage que `lib/recherche.js` et `lib/pannes.js`, et `lib/` ne compte pas dans les
douze fonctions Vercel. Neuf cas, dont les deux qui comptent :

  · **une date illisible ne rend pas « actif » par accident.** `new Date('n'importe quoi')` rend
    NaN, et NaN comparé à quoi que ce soit rend `false` — mais la comparaison écrite dans l'autre
    sens aurait rendu `true` ;
  · **un message daté dans le futur non plus.** Une horloge en avance, et « il y a -3 jours » est
    bien inférieur à quatorze jours.

Côté Swift, les deux booléens sont **optionnels**, parce que `api/clubs/search` ne les renvoie
pas. Un `Bool` non optionnel ferait échouer le décodage de toute la recherche le jour où les deux
routes cesseraient d'être d'accord — et une recherche qui ne rend rien ressemble exactement à
« aucun club ne porte ce nom ».

La **même vue de ligne** sert aux deux listes. Deux vues presque identiques auraient dérivé à la
première retouche, et l'écart se serait lu comme une différence de nature entre un club trouvé et
un club proposé. Il n'y en a pas.

### Une erreur de ma part, en chemin

J'ai annoncé à Charlotte que « parcourir les clubs, ça n'existe pas » après avoir regardé
`api/clubs/public` — qui sert **une** page de club ouverte depuis un lien profond. La recherche
existait, de bout en bout, dans un fichier que je n'avais pas ouvert. Le chantier s'est rétréci
d'un annuaire complet à l'état vide d'un champ, ce qui était le vrai défaut.

## Chantier 16 — la fenêtre entre la 3e et la 10e sortie

### Ce qui était faux

Le catalogue de badges marque la toute première course, puis la dixième. Entre les deux, rien qui
compte les sorties — c'est-à-dire rien dans la fenêtre où l'on arrête.

Mais la fenêtre n'était pas vide : elle était **mal remplie**. La carte des trente derniers jours
s'affiche dès la première sortie et montre une **allure moyenne**. Au cinquième jour d'une
reprise, c'était le seul chiffre de l'écran capable de donner tort à quelqu'un qui hésitait déjà.
Et sa fenêtre **glisse** : elle redescend quand on ralentit, au moment précis où une redescente
coûte le plus cher.

### Ce qui a changé

De la 3e à la 9e sortie, c'est une autre carte, et elle n'affiche **que des grandeurs qui ne
peuvent pas baisser** : nombre de sorties, kilomètres cumulés, plus longue sortie.

Les deux cartes ne coexistent pas. Avec moins de dix sorties, la fenêtre de trente jours contient
à peu près tout ce qu'on a couru, et les afficher ensemble dirait deux fois la même chose.

Elle s'arrête d'elle-même à la dixième, quand le badge prend le relais — pas de réglage, pas de
croix à fermer, et elle ne revient jamais. Elle commence à la troisième : en dessous, « 1 sortie ·
3 km · plus longue 3 km » dit trois fois la même chose.

### Le chiffre écarté

Le **nombre de jours** depuis la première sortie disait quelque chose de vrai sur la régularité —
« 3 sorties en 9 jours » n'est pas « 3 sorties ». Il a été écarté pour la raison même qui fonde la
carte : il grandit qu'on coure ou non. « 3 sorties en 40 jours » est un reproche déguisé en
mesure.

### Ce qui le garde

Trois colonnes, **deux aux tailles d'accessibilité** — même règle que la grille de mesures
d'`ActivityDetailView` : « PLUS LONGUE » en capitales espacées dans un tiers d'écran rétrécit
déjà à 0,7 au corps normal.

### D'où vient l'idée

De `3477d46`, sur `claude/running-club-finance-wwuq46`, une branche d'août jamais fusionnée. Le
code n'en est pas repris : ni le système de couleurs ni les contrôles de ce dépôt n'existaient
alors. Seul le raisonnement l'a été — et corrigé sur un point, le compte des jours.

## Chantier 15 — les erreurs qu'on avale

Annoncé à la fin du chantier 14 : MetricKit ne voit que ce que le système appelle une panne. Les
erreurs rattrapées par l'app lui sont invisibles — de son point de vue, rien n'a mal tourné. Donc
un audit, et un audit commence par compter.

### LE RELEVÉ

**275 sites** : 143 `try?`, 132 `catch`, et **zéro `try!`** — pas un seul point d'exclamation
forcé dans toute l'app.

Les `catch`, par ce que leur corps FAIT :

| | |
|---:|---|
| **97** | montrent quelque chose à l'utilisatrice (`toast`, `errorMessage`, bannière) |
| 8 | relancent l'erreur à l'appelant |
| 5 | rendent un cas d'échec nommé (`.baseNonVide`, `.fichierIllisible`…) |
| 4 | posent un état que l'écran lit (`loadFailed`, `storeState`…) |
| 4 | annulent un changement optimiste |
| 4 | sont VIDES |
| 3 | rendent `nil` ou `[]` en silence |
| 2 | arrêtent l'app en débogage |

Les `try?` : 37 replis sur une valeur, 29 attentes (`Task.sleep`, qui n'échoue qu'à
l'annulation), 26 encodages/décodages avec repli, 6 enregistrements SwiftData, 5 nettoyages de
fichiers temporaires, 2 audio, 1 Santé, 37 divers.

**Les quatre `catch` vides sont tous délibérés et tous commentés** — la photo de profil réessayée
au prochain rafraîchissement, la montre non appairée, une suppression qui n'a rien bougé à
l'écran, une page de fil qui reste juste. J'ai lu les douze candidats au silence un par un ; onze
sont corrects.

### LE DOUZIÈME : UNE COURSE DE MONTRE PERDUE POUR DE BON

`WatchSessionService.handleCompletedRun` finissait par `try? appState.modelContext.save()`. Si
cet enregistrement échouait, **tout le reste se déroulait quand même** :

- l'identifiant de livraison entrait dans `seen`, donc la montre ne redélivrait plus jamais ;
- la feuille de ressenti s'ouvrait ;
- l'app annonçait « Course reçue de ta montre ⌚ ».

Elle affirmait donc avoir reçu une course qui n'existait que dans la mémoire du processus, et qui
disparaissait au lancement suivant sans que rien ne puisse la ramener.

Ce qui rend ce défaut remarquable, c'est que **le commentaire juste au-dessus le décrivait déjà** :
il raconte que le marqueur était autrefois posé avant l'enregistrement, qu'un processus tué entre
les deux perdait la course, et il énonce la règle — « une livraison interrompue doit pouvoir
recommencer ». Un échec d'enregistrement EST une interruption. La branche n'était simplement pas
couverte.

Corrigé avec l'idiome que les deux réparations de données d'`AppState` emploient déjà
(`guard (try? save()) != nil else { return }`), plus deux choses : l'insertion est défaite, et
l'app le DIT — « La course de ta montre n'a pas pu être enregistrée. Elle sera renvoyée », ce qui
est vrai puisqu'on ne consomme pas l'identifiant.

### ET DU CODE MORT QU'UN TEST TENAIT EN VIE

`SauvegardeService.ecrire` était appelée par exactement un endroit : un test. Elle avait été
écrite pour un `ShareLink(item:)`, remplacé depuis par un `fileExporter` — l'app encode, pose les
octets dans un `SauvegardeDocument`, et laisse le système écrire.

Le coût n'était pas la fonction, c'était son test. Son commentaire affirmait : « un vrai fichier
sur un vrai disque, écrit puis relu, parce que c'est le seul trajet que la sauvegarde empruntera
jamais. » Faux — et c'est le genre de phrase qui fait croire que l'export est couvert. Il
emprunte maintenant le chemin réel, et la fonction est sortie du binaire.

### CE QUI A ÉTÉ REGARDÉ ET LAISSÉ

`GPXExporter.fileURL` rend `nil` si l'écriture échoue, et ses deux appelants font
`if let url { ShareLink… }` : le bouton « Exporter en GPX » disparaît sans explication. Ça
confond « pas applicable » et « cassé ». Laissé tel quel : l'écriture est un petit fichier dans
le dossier temporaire, son seul échec réaliste est un disque plein — auquel cas bien d'autres
choses cassent d'abord — et le corriger demanderait de rendre l'export paresseux (`Transferable`
au lieu d'une URL) aux deux endroits. Le seuil où ça change : le jour où cette écriture grossit
ou sort du dossier temporaire.

### CE QUE L'AUDIT DIT DE L'APP

Quatre-vingt-dix-sept `catch` sur cent trente-deux parlent à l'utilisatrice, aucun `try!` nulle
part, et les silences sont presque tous écrits et justifiés. **Un seul défaut sur 275 sites.**
C'était la bonne nouvelle possible, et c'est la raison pour laquelle ce chantier ne se termine
PAS par « on rapporte toutes les erreurs rattrapées au serveur » : il n'y a pas de gisement
d'erreurs avalées à instrumenter, il y en avait une.

## Chantier 14 — le rapport de panne, et la façon de le faire qui ne marche pas

Commencé par chercher comment on fait, et la recherche a renversé le plan.

### LE PLAN D'ORIGINE, ET POURQUOI IL EST MORT

La façon dont presque tous les rapporteurs de panne fonctionnent : poser un
`NSSetUncaughtExceptionHandler` et des `sigaction` sur SIGSEGV, SIGABRT, SIGBUS, SIGILL, relever
la pile d'appels depuis le gestionnaire, l'écrire dans un fichier, l'envoyer au lancement suivant.
C'est ce qu'il fallait écrire. Ce n'est pas ce qui a été écrit, et la raison est une phrase.

Quinn « The Eskimo! », de l'assistance aux développeurs d'Apple, dans « Implementing Your Own
Crash Reporter » (developer.apple.com/forums/thread/113742) :

> `backtrace` is not an async signal safe function.

Un gestionnaire de signal ne peut appeler que des fonctions dites *async signal safe*, et cette
liste ne contient ni `malloc` — donc « a crash reporter's signal handler cannot use Objective-C or
Swift » — ni `backtrace`. Sans `backtrace`, pas de pile d'appels ; sans pile d'appels, un rapport
de panne ne sert à rien. Le reste du texte ferme les autres portes :

> On iOS […] your crash reporter must run inside the crashed process. That means it can never be
> 100% reliable.

> You must ensure that your crash reporter doesn't disrupt the Apple crash reporter.

Et il nomme la sortie :

> I recommend that you lean in to Apple's crash reporter. […] iOS 14 and macOS 12 report crashes
> in MetricKit. This is a *very* cool feature, and I'm surprised by how few people use it
> effectively.

C'est exactement la règle 8 — chercher et citer avant d'écrire. Une journée de C contraint,
impossible à relire et impossible à éprouver ici, a été remplacée par un abonnement.

### CE QUI EST FAIT

`RunUp/Services/Diagnostics.swift` s'abonne à MetricKit. iOS collecte la panne **hors** du
processus mort — le même mécanisme que les rapports de l'organiseur Xcode — et la rend au
lancement suivant. Jumeau volontaire d'`Analytics` : même file privée, même tampon sur disque,
même discipline d'endpoint. Ce n'est pas de la copie, c'est la même forme pour le même problème.

**Cinq genres arrivent, et quatre ne sont pas des plantages.** Un gel de plusieurs secondes, un
dépassement de processeur, une écriture disque excessive, un lancement trop lent. Ce sont les
pannes où l'app ne meurt pas : elle devient mauvaise. Un rapporteur de panne classique ne les voit
JAMAIS, et c'est pourtant ce qu'une utilisatrice appelle « ça plante ».

| Pièce | Rôle |
| --- | --- |
| `RunUp/Services/Diagnostics.swift` | l'abonnement, la traduction d'un lot MetricKit en lignes, le tampon sur disque |
| `lib/pannes.js` | ce qu'on accepte d'un rapport, seul et testé — 19 cas dans `tests/crashes.test.js` |
| `api/crashes.js` | l'endpoint : jeton facultatif, lot borné, genre inconnu jeté ligne par ligne |
| `crash_reports` dans `db/schema.sql` | la table, avec sa charge `jsonb` et ses deux index |
| `ci_scripts/check_pannes.py` | les trois accords, 14 cas dans `test_pannes.py` |

### Ce qui a été VÉRIFIÉ en production, et les deux lignes que ça laisse

Le déploiement réussi prouve que le schéma a été appliqué — `appliquer_schema.js` est la commande
de construction, et « si ce script échoue, la construction échoue, donc RIEN n'est déployé ». Il
ne prouve PAS que l'`INSERT` est juste : il a été écrit à la main contre un schéma écrit à la
main, et une colonne mal nommée rendrait un 500 à chaque panne. Silencieusement : le client garde
son tampon sur un 5xx et réessaie, donc rien ne se perd et rien n'arrive jamais non plus.

Deux sondes envoyées à la production :

| Ce qui est éprouvé | Réponse |
| --- | --- |
| un genre inconnu est jeté ligne par ligne, sans rien écrire | `accepted:0, rejected:1` |
| l'`INSERT` passe, toutes colonnes nommées | `accepted:1` |
| la colonne `payload` accepte du vrai JSON en `jsonb` | `accepted:1` |
| un lot de six est refusé | `payload_too_large` |
| `GET` est refusé | `405` |
| `/api/events` répond toujours, non réécrit | `200` |

Elles laissent **deux lignes** dans `crash_reports`, de genre `app_launch` et non `crash` — pour
qu'aucun compte de plantages ne soit faussé — et dont la note dit en toutes lettres « SONDE DE
DÉPLOIEMENT, pas une vraie panne ». C'est le prix assumé de la vérification : sans elles, la
première preuve que la table marche aurait été la première panne de quelqu'un.

### LA DÉGRADATION, QUI EST LA DÉCISION DE CONCEPTION

Un rapport dont la charge JSON est abîmée ou trop grosse **perd sa pile d'appels et garde sa
ligne**. « Combien de plantages sur la 2.9 » reste une information sans la pile ; refuser tout le
rapport ferait disparaître le plantage au lieu de la pile. Et ce serait invisible, parce qu'une
table de pannes vide ressemble trait pour trait à une app qui ne plante pas.

C'est le même raisonnement partout : un champ trop long devient `NULL` plutôt que tronqué
(tronquer fabriquerait une version qui n'existe pas, et elle serait agrégée comme telle), une date
plus vieille qu'un mois cède à l'heure du serveur, un `isTestflight` qui n'est pas un vrai booléen
devient `NULL` au lieu d'être coercé en `true`.

### LE CONTRÔLE, ET SA TROISIÈME RÈGLE

`check_pannes.py` compare `Diagnostics.Genre` et `KNOWN_KINDS` dans les deux sens, comme
`check_events.py` le fait pour l'analytique. La raison est la même, l'enjeu est plus mauvais : un
rapport de panne n'arrive que quand ça va mal, donc il n'y a aucun volume quotidien dont la chute
sauterait aux yeux. La divergence qui a jeté onze événements d'analytique pendant des mois aurait
ici **zéro symptôme**.

Sa troisième règle n'est pas de la même nature. Tant que l'app s'abonne à MetricKit, le manifeste
`PrivacyInfo.xcprivacy` doit déclarer `NSPrivacyCollectedDataTypeCrashData` **et**
`NSPrivacyCollectedDataTypePerformanceData` — déclarer les plantages et oublier les gels est le
piège exact, et il a son cas de test. Une déclaration incomplète fait refuser le binaire à
l'**envoi**, avant toute revue humaine. Cette règle existe parce que la dérive s'est déjà produite
ici : le manifeste a affirmé pendant des mois que le tracé GPS ne partait jamais, ce qui a cessé
d'être vrai le jour où la table `routes` est apparue. Son propre en-tête mettait en garde contre
exactement ça. Ça n'a pas suffi — c'est la définition d'un travail de machine.

### CE QUI EST ÉCRIT NOIR SUR BLANC COMME NON COUVERT

- **Les erreurs rattrapées.** Les 160 `try?` et 132 `catch` de l'app avalent des erreurs dont
  MetricKit n'entendra jamais parler : de son point de vue, rien n'a mal tourné. C'est le chantier
  suivant, et il commence par un audit de ces sites — pas par du code.
- **Pas de regroupement.** Aucune colonne « signature », aucun compteur d'occurrences : regrouper
  demanderait de symboliser côté serveur. À cette échelle on lit les lignes. Le seuil où ça
  devient faux s'énonce : le jour où une requête rend plus de lignes qu'on n'en lit à l'œil.
- **Rien sur le simulateur.** MetricKit ne collecte que sur un appareil réel, donc ce chemin ne
  sera jamais éprouvé par le harnais. Ce qui est éprouvé, c'est tout ce qui est en dessous : les
  règles d'acceptation (19 cas), les trois accords (14 cas), le découpage du schéma.
- **Pas d'alerte.** Une panne arrive au lancement suivant, et personne n'est prévenu. Il faut
  aller regarder la table.

### L'API UTILISÉE EST DÉPRÉCIÉE EN iOS 27, ET C'EST LE BON CHOIX QUAND MÊME

`MXMetricManager` et les classes `MX*` sont remplacées en iOS 27 par `MetricManager` et sa suite
asynchrone `diagnosticReports`. RUNUP vise iOS 17 : la nouvelle API n'existe pas pour la
quasi-totalité du parc, et les classes `MX*` sont là depuis iOS 14. Le jour où le plancher passe à
27, la migration est dans un seul fichier.

### LA POLITIQUE PUBLIÉE A RATTRAPÉ, LE JOUR MÊME

Le constat était que la page lue par Apple et les utilisatrices — servie par GitHub Pages depuis
`main`, pas depuis cette branche — ne mentionnait pas les rapports de panne, alors que
`testflight.yml` ENVOIE à chaque push (`xcrun altool --upload-app`) : des builds qui les
collectent étaient déjà distribués. Pas une fuite, un manquement de déclaration, et sur une
donnée qui ne contient ni texte écrit, ni santé, ni position.

Charlotte a porté `privacy.html` et `support.html` sur `main` le 8 novembre. Vérifié octet pour
octet : les deux pages publiées sont identiques à celles du dépôt. *(Relevé le 10 novembre :
`support.html` est publiée mais n'est l'adresse de personne — la fiche et l'app emploient un
`mailto:`.)* `check_politique.py` est passé
en `--exiger` dans la foulée — toute nouvelle section ajoutée ici fera désormais rougir la chaîne
tant qu'elle n'est pas publiée.

### CE QUI RESTE À FAIRE À LA MAIN

La fiche App Store Connect doit déclarer **Crash Data** et **Performance Data** en *App
Functionality*, pour concorder avec le manifeste — une divergence entre les deux est un motif de
rejet à part entière. Le détail est dans `APP_STORE_LISTING.md` § Confidentialité.

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

### Trois écrans de plus, et trois défauts de plus (8 novembre, deuxième passe)

Quatre écrans sur les vingt et un photographiés, c'était la couverture. Les trois ajoutés sont les
plus denses de ceux qu'on n'avait jamais vus en grand texte : la sortie dépliée (l'écran le plus
chiffré de l'app), l'aperçu du club (redécoupé en quatre fichiers la veille, donc jamais revu
depuis), et le profil (une grille de tuiles). Les trois ont rendu un défaut chacun.

| Écran | Défaut | Correctif |
| --- | --- | --- |
| Aperçu du club | **une coupure de mot, pas une troncature** : « Classe / ment » en français, et les TROIS à la fois en espagnol — « Resume / n », « Clasific / ación », « Activida / d ». Un onglet dont le nom est coupé en deux ne se lit plus comme un nom. | les trois segments s'empilent au cran d'accessibilité (`AnyLayout`). Chacun a la largeur entière, rien ne rétrécit. |
| Profil | « jours de suite » passait à la ligne et tombait sous le chiffre du milieu, centré sous rien — une quatrième ligne orpheline qui casse le lien entre un chiffre et son unité. | la rangée de chiffres devient une colonne, comme `RUCardHeader` et `WeeklyRecapView` le font déjà. |
| Sortie dépliée | « bpm m… » : `bpm moyen` ne tient pas dans un tiers de largeur, et le `lineLimit(1)` du libellé le coupait. Sans son libellé, « 154 » n'est rien. | deux colonnes au lieu de trois, ET deux lignes autorisées. Aucune des deux ne suffit seule. Le chiffre, lui, garde son `lineLimit(1)` : un chiffre coupé serait pire qu'un chiffre rétréci. |

Le compte de la méthode est donc de **treize défauts sur sept écrans**, tous invisibles aux
tailles ordinaires et tous vus sur une image.

Ce qui a été REGARDÉ et laissé : les textes libres tronqués en fin de ligne — la bio du profil,
le sous-titre « Ton club, tes abonnements et tes c… », le nom d'un club long. Ce sont des limites
de lignes posées exprès sur du contenu de longueur inconnue, pas des mises en page qui cassent, et
la coupure se fait proprement sur un caractère de suite.

### Le calage de l'heure du coach, qui attendait une exécution de nuit

Une dette plus petite, et fermée le même jour. La fausse conversation du coach est plantée cinq
heures en arrière, bornée au début du jour courant : sans cette borne, une chaîne qui tourne à
03 h 00 pose le message à 22 h 00 la VEILLE, et `3-coach` — une des six images livrées à Apple —
affiche un séparateur « HIER ». Le défaut est passé une fois, et n'a été vu qu'à la troisième
exécution comparée.

La borne était écrite, et **impossible à vérifier autrement qu'en attendant qu'une exécution
tombe entre minuit et 05 h 00** — c'est-à-dire en confiant la vérification au hasard de l'heure
à laquelle quelqu'un pousse. Elle est sortie dans `CaptureSeed.poseDeLaConversation`, et
`CaptureSeedHeureTests` éprouve les vingt-quatre heures en une seconde : la pose tombe toujours
le jour courant, le recul de cinq heures reste intact passé 05 h 00, et la réponse du coach —
posée quarante secondes après la question — ne bascule pas au jour suivant non plus.

### Ce qui restait du chantier 12, et pourquoi il est fermé

« Indices VoiceOver » était la seconde moitié de l'item d'audit. Elle est fermée sur une mesure,
pas sur une opinion.

**Les commandes ont toutes un nom.** `check_a11y.py` existe déjà et le garantit : il refuse toute
commande dont le libellé est une icône seule et qui n'a ni `accessibilityLabel`, ni
`accessibilityHidden`, ni `accessibilityElement`. Il est vert. J'ai voulu le vérifier à part et
j'ai écrit deux mesures fausses coup sur coup — la première a rendu trois défauts, tous faux
positifs d'une fenêtre de lecture trop courte ; la seconde en a rendu un, faux lui aussi, parce
que le texte du bouton était passé en ARGUMENT à `RUCardHeader` et non écrit dans un `Text`. La
bonne réponse est zéro, et elle était déjà tenue par une machine.

**Ce qui est DESSINÉ ne parle pas, et c'est délibéré partout.** Quinze fichiers dessinent de
l'information (`Canvas`, `Path`, des rectangles dans un `GeometryReader`). Six ne portent aucune
annotation, et aucun n'est un défaut :

| Fichier | Pourquoi il se tait |
| --- | --- |
| `AppMarkView` | le logo : décoratif |
| `HexagonBadgeShape` | une `Shape`, de la géométrie sans contenu |
| `RunShareCardView` | rendu en image pour le partage, jamais à l'écran |
| `DrawnRoute` | employé par le seul `RunVideoFrameView`, qui fabrique des images de vidéo |
| `ProgressBars` | un `Rectangle` n'est pas un élément d'accessibilité : VoiceOver ne s'y arrête pas. Et aux six endroits où `LinearBar` sert, le nombre qu'elle dessine est ÉCRIT en toutes lettres juste à côté — « 180 / 250 XP », « 212 / 300 km — 71 % », « 245 km / 800 km », « Semaine 7/16 ». L'annoncer en plus ferait lire deux fois la même chose |
| `ElevationProfileView` | son `RUCardHeader` le nomme, et `RecapView` porte déjà le commentaire qui le dit : « the min/max/gain numbers below it are combined into this card's own label instead » |

**Les six indices restent six.** Le relevé : 127 `accessibilityLabel`, 58
`accessibilityElement`, 29 `accessibilityAddTraits`, 25 `accessibilityHidden`, 15
`accessibilityValue`, 6 `accessibilityHint`.

Et la raison de ne pas en ajourer cent vingt d'un coup doit être dite correctement, parce que je
l'ai d'abord dite faux. J'ai écrit que c'était « contre la recommandation d'Apple » : je n'ai pas
pu sourcer cette phrase. La page de `accessibilityHint(_:)` dit ce qu'un indice EST —
« Communicates to the user what happens after performing the view's action », avec pour exemples
« Purchases the item », « Downloads the attachment » — et ne dit rien sur la parcimonie.

La vraie raison tient en une distinction : **un libellé calculé depuis la donnée qu'il décrit ne
peut pas mentir ; un indice est une affirmation sur un COMPORTEMENT.** « Ouvre la sortie en
détail » est vrai ou faux selon ce que fait le bouton, et rien ici ne peut le vérifier — ni le
compilateur, ni une capture, ni un contrôle. En écrire cent vingt reviendrait à poser cent vingt
phrases sur le fonctionnement de l'app que personne n'aurait éprouvées. C'est la règle « rien de
faux » appliquée aux textes de l'interface. Les six qui existent ont été écrits un par un, en
regardant ce que la commande fait.

### Une bannière d'iOS sur une image livrée à Apple

Trouvée par accident, en comparant une dernière fois deux exécutions pour vérifier qu'un
refactorisage de `CaptureSeed` n'avait bougé aucun pixel. Une image avait bougé : `1-accueil.png`
en français, 13,4 de moyenne dans la bande du haut.

C'était une notification du système — « Ready for Apple Intelligence », émise par Réglages — posée
en travers du haut de l'écran. Sur cette image, on ne voit ni le prénom, ni la date, ni la série :
on voit une bannière grise qui parle d'autre chose, par-dessus l'app. Et c'est une des SIX images
livrées à Apple.

Rien ne pouvait l'attraper. Le test de capture était vert, parce qu'il dit deux choses et deux
seulement : l'app n'a pas planté, un fichier a été écrit. Aucun contrôle ne regardait ces six
images. Rien n'a été envoyé — `appstore.yml` ne part qu'au bouton — donc c'est une alerte, pas un
dégât. La prochaine fois, c'est une question de minutage.

`check_banniere.py` mesure la part de pixels clairs dans la bande où iOS pose ses bannières, sur
les captures SOMBRES uniquement. Le relevé de quatre-vingt-quatre captures saines va de 1,3 % à
8,0 % — les plus claires étant les écrans en grand texte, dont les titres occupent légitimement le
haut — contre **59,7 %** pour celle qui portait la bannière. Le plafond est à 25 %, trois fois la
plus claire observée, et il n'y a rien entre 8 et 60 à départager.

**Et la chaîne qui PUBLIE le vérifie aussi.** `captures.yml` refusait déjà une bannière, mais
c'est `appstore.yml` qui parle à Apple — et il télécharge l'artefact d'une exécution qu'on peut
DÉSIGNER par son numéro, y compris une ancienne, antérieure au contrôle. Il relance donc la
mesure sur les images qu'il s'apprête à pousser, avant de toucher à App Store Connect. Sur
`raw/` et non `out/` : le plafond est calibré sur des captures en thème sombre, et les images
composées portent un fond de fiche clair où la mesure ne voudrait rien dire — une bannière dans
une brute se retrouve de toute façon dans la composée. C'est le principe que ce workflow applique
déjà pour l'aperçu : ce que la commande décide sans parler à Apple est éprouvé juste avant.

Il ne l'empêche pas, il la voit — et cette limite doit être dite honnêtement : **je n'ai pas
trouvé comment l'empêcher.** La recherche n'a rien rendu sur une option de `simctl` qui
musellerait les notifications du système, ce qui ne prouve pas qu'elle n'existe pas. Ce qui est
documenté et voisin en ENVOIE (`simctl push`), fige la barre d'état (`status_bar override`) ou
calme les journaux (`spawn log config`) ; aucun ne touche aux bannières. Ce qu'on peut faire sans
rien supposer, c'est refuser de livrer l'image.

### Et la question inverse : est-ce que les écrans ORDINAIRES ont bougé ?

Les trois correctifs ne devaient toucher que le cran d'accessibilité. `comparer.py` entre les
captures d'avant et d'après, sur les quarante-deux images d'une langue : **trente-quatre
identiques au pixel près**, et huit qui diffèrent — toutes expliquées.

| Image | Écart | Explication |
| --- | --- | --- |
| les trois en grand texte corrigés | 11,6 à 17,7 | c'est le correctif |
| `course-en-cours` (×3, dont la version claire et la version grand texte) | 0,17 à 1,12 | écran non reproductible, documenté : chronomètre, calories, tuiles qui n'arrivent pas au même moment |
| `clair/diagnostic/profil` | 0,19 sur une bande de 38 points | écran non reproductible, documenté : la tuile « Amis » dépend de l'heure |
| `diagnostic/club-apercu-bas` | **16,3 et 813 202 pixels** | TROISIÈME écran non reproductible, trouvé ce jour-là |

Le dernier a coûté une demi-heure. Seize de moyenne, c'est cinq fois ce que rend un changement de
LANGUE complet sur ce même écran — le plus gros chiffre que cet outil ait jamais rendu. Et ce
n'était rien : le contenu est identique, le défilement s'est arrêté 105 pixels plus loin. Le
harnais donne un nombre de glissements, pas une destination.

D'où `comparer.py --decalage`, qui cherche désormais si un décalage vertical explique l'écart et
le dit en toutes lettres. Sur cette image : « le contenu d'après est 105 px plus bas (défilement
moins loin) ; la moyenne passe de 19,904 à 1,435 → un défilement, pas une régression. »

Et un écho du même défaut, un cran plus loin : modifier `comparer.py` n'a relancé que TestFlight.
Quatre scripts — `comparer.py` et ses cas, ceux des bascules, le contrôle du grand texte et les
siens — étaient lancés par `captures.yml` sans être dans son filtre de chemins. Câblés sur le
papier, débranchés en pratique. `check_cablage.py` ne pouvait pas le voir : il vérifie qu'un
script est NOMMÉ par un workflow, pas que ce workflow PARTE quand le script change.
`check_declencheur.py` porte maintenant les deux règles.

Deux défauts trouvés en ÉPROUVANT l'option, qui méritent d'être notés parce qu'aucun ne se voyait
à la relecture : le gabarit de test posait une barre toutes les 24 lignes, donc un décalage de 48
retombait exactement sur lui-même et l'écart tombait à zéro des deux côtés ; et la recherche
sautait silencieusement tout décalage qui faisait sortir la bande de l'image — invisible sur une
capture de 2 868 pixels, fatal sur un gabarit de 600. Les deux sont corrigés et écrits dans le
code.

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
