# La direction artistique de RunUp

Tenu par la direction artistique. Ce fichier existe pour que la DA ne dépende plus d'une
conversation : les trois questions, la palette, la typographie, les deux thèmes et les règles de
l'écran de séance sont ici, pas dans un fil de discussion.

`RELEASE.md` garde les questions de **livraison** — est-ce que les captures montrent l'app
d'aujourd'hui, est-ce que la production est debout, est-ce que ça se lit dans les trois langues,
est-ce que la politique publiée dit vrai. Ce fichier porte les questions de **design**.

**Ce fichier ne recopie pas le code, il le cite.** Chaque valeur ci-dessous est donnée avec sa
déclaration, et `ci_scripts/check_design.py` vérifie à chaque CI que les deux s'accordent. Un
document de DA qui dérive de l'app est pire qu'aucun document : on le lit en croyant savoir.

---

## 1. Les trois questions, à appliquer à chaque écran avant de le présenter

1. **Est-ce qu'une débutante qui (re)commence à courir s'y sent à sa place ?** Pas intimidant, pas
   réservé aux performeurs.
2. **Est-ce qu'un traileur ou un triathlète le trouve sérieux ?** Précis, crédible, pas gadget.
3. **Est-ce qu'on devine qu'il a été généré ?** Template, dégradé, emoji, texte générique,
   composant sans intention.

**Un oui à la 3, ou un non à la 1 ou à la 2 : on recommence l'écran.**

### Le test final

Sorti de son cadre de téléphone et sans logo, l'écran doit être reconnaissable comme RunUp.

### Ce que les trois questions veulent dire quand on tient un écran dans les mains

Elles ne se répondent pas de mémoire. Elles se répondent sur une image, dans les trois langues, et
dans les deux thèmes — la campagne `captures.yml` existe pour ça.

**Question 1, en pratique.** Est-ce que le premier chiffre que l'œil rencontre est une performance
ou un repère ? Est-ce qu'un écran vide dit quoi faire, ou constate un manque ? Est-ce qu'une
séance ratée est écrite comme un échec ou comme une information ? Un écran qui n'a de sens qu'avec
trois mois d'historique échoue à cette question même s'il est beau.

**Question 2, en pratique.** Est-ce que les nombres sont justes, datés, et sourcés quand ils
viennent d'un règlement ? Est-ce que les unités sont là ? Est-ce qu'une allure est donnée au
format qu'un coureur lit — `4:45/km` et pas `4,75 min/km` ? Un écran qui arrondit pour faire
joli échoue ici.

**Question 3, en pratique.** C'est la seule des trois qui a des gardes automatiques, et ils ne
couvrent qu'une partie :

| Ce qu'on cherche | Ce qui le tient |
| --- | --- |
| Dégradé décoratif | `check_degrade.py` — autorisé dans le logo seul |
| Verre dépoli | `check_verre.py` |
| Taille d'icône écrite à la main | `check_icones.py` |
| Cran de titrage hors échelle | `check_echelle.py` |
| Écart, marge ou rayon hors de la géométrie déclarée | `check_grille.py` |
| Chiffre et unité composés à la main | `check_chiffres.py` |
| Grand chiffre qui peut se tronquer en silence | `check_grands_chiffres.py` |
| Ouverture qui déborde sur son propre fondu | `check_lancement.py` |
| Jeton de texte hors famille ou en opacité | `check_jetons_de_texte.py` |

**L'emoji n'est tenu par aucun garde**, et je l'ai découvert en écrivant ce fichier : j'avais cité
un contrôle des emojis qui n'existe pas, et `check_design.py` l'a refusé — un nom de garde entre
accents graves est une promesse, et celle-là était fausse. `check_strings.py` ignore
au contraire toute chaîne sans aucune lettre — un emoji, un chevron, un point médian — donc un
emoji glissé dans l'interface passerait sans bruit. À faire.

Ce qu'aucun garde ne voit non plus : **le texte générique et le composant sans intention.** Une
carte qui dit « Continuez comme ça ! » passe tous les contrôles. C'est à l'œil, sur l'image, et
c'est la raison pour laquelle cette question est posée à chaque écran et pas une fois par
version.

---

## 2. La palette

Déclarée dans `RunUp/DesignSystem/Colors.swift` (`RUColor`) et
`RunUp/DesignSystem/AccentTheme.swift`. Les valeurs ci-dessous sont celles du code, vérifiées par
`check_design.py`.

### 2.1 L'accent est au choix de la coureuse — huit nuanciers

**Décision D1 de Charlotte, 9 novembre 2026.** Le brief demandait une couleur d'accent unique.
L'app en propose huit. Conséquence directe sur la DA : **aucun jeton dérivé de l'accent ne peut
être écrit en dur**, et tout écran doit être juste pour les huit.

Valeurs de thème sombre, `AccentTheme.all` — `primary`, `light`, `tail` :

| Nuancier | `primary` | `light` | `tail` |
| --- | --- | --- | --- |
| Rose | `#FF0A78` | `#FF4D9E` | `#7C5CFF` |
| Violet | `#7C5CFF` | `#A78BFF` | `#FF0A78` |
| Bleu | `#3D8BFF` | `#8AB8FF` | `#7C5CFF` |
| Cyan | `#2FD9C4` | `#7CF0E4` | `#3D8BFF` |
| Lime | `#9FE83D` | `#DFFF8C` | `#2FD9C4` |
| Ambre | `#FFB03D` | `#FFD08A` | `#FF4D9E` |
| Corail | `#FF5A3D` | `#FF9478` | `#FFB03D` |
| Magenta | `#D633B8` | `#F07ADB` | `#7C5CFF` |

**Sur fond clair, ces valeurs ne sont pas utilisées telles quelles.** `AccentTheme` les descend
par recherche dichotomique jusqu'à 3,5:1 sur blanc (`meetingContrastOnWhite`), une fois par
nuancier. Sans ça, Lime et Cyan donnaient un mode clair inutilisable. Les jetons à lire sont donc
`RUColor.rose`, `rose2` et `violet`, jamais les valeurs du tableau.

### 2.2 Les couleurs qui veulent dire quelque chose ne suivent pas l'accent

Elles sont FIXES, parce qu'une information ne change pas de sens quand on change de goût. Deux
valeurs par jeton : clair, puis sombre. Les valeurs claires sont plus profondes — les valeurs
sombres sont réglées pour ressortir sur du presque-noir et deviendraient illisibles sur blanc.

| Jeton | Clair | Sombre | Ce que ça dit |
| --- | --- | --- | --- |
| `lime` | `#6B9E00` | `#C8FF3D` | forme, disponibilité |
| `cyan` | `#0E9C8C` | `#38E0D0` | récupération |
| `amber` | `#B86A00` | `#FFB03D` | attention, tempo |
| `amberText` | `#8A5A00` | `#FFD79A` | de l'ambre sur une carte ambrée, à lire en longueur |
| `ember` | `#C2352A` | `#FF6B5A` | fractionné |
| `azure` | `#0F62C8` | `#5AA9FF` | fonctionnel |
| `grape` | `#5B3FD6` | `#9B7CFF` | sortie longue |
| `cycle` | `#80462E` | `#F2B8A0` | la phase du cycle, les quatre confondues |
| `cycleSurface` | `#F6EAE5` | `#130702` | le fond d'un bloc qui appartient au cycle |

**Une seule teinte pour les quatre phases, et c'est une mesure.** Elles empruntaient leurs
couleurs : `.menstrual` prenait `rose`, c'est-à-dire **l'accent choisi par la coureuse** — donc la
phase menstruelle était rose pour l'une et vert lime pour celle qui a pris le nuancier Lime. Les
trois autres prenaient `lime`, `cyan` et `amber`, les teintes des familles de séance : un point
lime disait « endurance » sur un écran et « phase folliculaire » sur l'autre.

L'app n'affiche jamais deux phases à la fois, et celle du moment est nommée en toutes lettres à
côté du point. Quatre couleurs distinguaient donc des choses qu'on ne voit jamais ensemble.

`#F2B8A0` est la valeur de la DA, ici telle quelle en sombre. En clair elle donne 1,73:1 sur une
carte blanche — la branche claire descend à la même teinte, jusqu'à 5,93:1 au pire des cinq fonds.
La surface, elle, a repris la teinte de `#FDF1EC` mais pas sa luminosité : sur notre page chaude,
la valeur de la DA donnait **1,006:1**, c'est-à-dire rien.

### 2.3 Une teinte par famille de séance, la même partout

`SessionFamily.tint`, dans `Colors.swift` et non dans le modèle : `SessionFamily` reste une
classification d'entraînement, lisible et testable sans SwiftUI.

| Famille | Teinte | Symbole |
| --- | --- | --- |
| Repos | `text3` | `moon.zzz.fill` |
| Récupération | `cyan` | `leaf.fill` |
| Endurance | `lime` | `figure.run` |
| Sortie longue | `grape` | `arrow.right.to.line` |
| Tempo | `amber` | `speedometer` |
| Fractionné | `ember` | `bolt.fill` |
| Fonctionnel | `azure` | — |

**Chaque famille porte aussi une forme, et ce n'est pas une décoration.** Environ un homme sur
douze distingue mal le rouge du vert, et ce sont précisément les deux extrémités de cette palette
— le footing facile et le fractionné.

**Décision de Charlotte, 11 novembre 2026 : les sept teintes actuelles restent.** Le brief en
donne cinq, en une seule valeur chacune, construites pour un fond sombre — `#F5A524` sur blanc
donne 1,9:1, et le clair est désormais le thème par défaut. L'esprit du brief, une teinte fixe par
intensité et la même partout, est déjà tenu.

### 2.4 Le texte

Quatre jetons, **opaques et dans la famille du fond**. Voir § 3 pour la règle, et
`check_jetons_de_texte.py` pour la barrière.

| Jeton | Clair | Sombre | Emplois |
| --- | --- | --- | --- |
| `textPrimary` | `#181511` | blanc pur | 265 |
| `text2` | `#443F3A` | `#BBB6C3` | 244 |
| `text3` | `#5B5651` | `#9893A0` | 318 |
| `text4` | `#B7B2AD` | `#514C59` | 8 |

`text4` **ne colore pas du texte à lire** : points médians, filets, pastilles inertes. Ses 1,7:1
sont voulus, et `check_contraste.py` tient la liste fermée de ses emplois avec une raison par
entrée.

Le primaire sombre est le blanc pur, délibérément hors famille : c'est le seul jeton dont on veut
le maximum de lisibilité.

Le primaire CLAIR, lui, a bougé le 12 novembre avec le fond, et c'est le garde qui l'a vu. Il était
resté `#15151C` au premier chantier, à juste titre — il portait le bleu 7 points au-dessus du
rouge, donc il était déjà dans la famille des fonds lavande. Quand les fonds sont passés au chaud,
cette raison est devenue fausse sans que rien ne l'écrive, et `check_jetons_de_texte.py` l'a refusé
à la première exécution. `#181511` garde sa luminance — 18,19:1 sur une carte contre 18,17.

### 2.5 Les surfaces

| Jeton | Clair | Sombre | Rôle |
| --- | --- | --- | --- |
| `card` | `#FFFFFF` | `#16161F` | la carte |
| `card2` | `#EEECE7` | `#201F2A` | une sous-surface DANS une carte |
| `bg2` | `#E8E6DF` | `#121118` | le second fond |
| `traceBackground` | `#14131E` | les deux | le fond d'un tracé de sortie |

Le fond de page, `RUColor.bg`, n'est pas une constante : c'est un neutre — `#F5F4F1` en clair,
`#08070D` en sombre — sur lequel l'habillage « teinté » mélange **3,5 % de l'accent en clair, 10 %
en sombre**. Une trace, pas un aplat : au-delà, le fond cesse d'être un fond et concurrence les
cartes posées dessus. La valeur claire a été à 7 % — sept pour cent du rose sur le neutre donne une
page franchement rose, et les cartes blanches censées flotter dessus se lisaient comme des trous.

**Le neutre clair est chaud depuis le 12 novembre, et il a été froid.** Il penchait vers le violet
de l'accent, avec cette raison : « un gris pur à côté d'un rose vif prend l'air sale, un gris qui
partage sa famille non ». L'argument est bon et il ne tient pas, parce qu'il suppose UN accent :
l'app en propose huit (D1), dont le cyan, le lime et le bleu. Un fond lavande ne partageait la
famille que de deux nuanciers sur huit.

Le fond prend donc la position du **papier** — un blanc cassé chaud sur lequel n'importe quelle
encre se pose — plutôt que celle d'un écho de l'accent.

**La teinte du brief, pas sa luminosité**, comme pour les jetons de texte. `#FBF9F7` est presque
blanc : sous une carte blanche il ne recule que de 1,050:1, contre 1,104 pour l'ancien froid. C'est
la moitié de la séparation, et ce recul est précisément ce qui empêche une carte à image pleine de
se lire comme un trou. `#F5F4F1` garde la luminance de l'ancien et retourne sa famille : 1,100:1.

**Les trois surfaces claires ont bougé ensemble**, et c'était obligatoire : une page chaude sous
des sous-surfaces lavande, c'est un écran qui se contredit. `card` reste le blanc pur — c'est la
surface la plus claire, et elle n'a pas de famille à porter.

### 2.6 Les deux surfaces de l'écran de séance

| Jeton | Valeur | Thèmes |
| --- | --- | --- |
| `seanceSurface` | `#0E0E14` | les deux |
| `seanceFond` | `#0A0A0E` | les deux |

**Fixes dans les deux thèmes, et ce n'est pas un oubli.** L'écran de course reste sombre même en
apparence claire : on le regarde dehors, en mouvement, à bout de bras, et un fond blanc y perdrait
le contraste que les chiffres demandent.

**Elles gardent la famille FROIDE quand le reste du clair est passé au chaud**, et c'est cohérent :
une famille suit la clarté de la surface, pas le thème choisi. Ces deux-là sont sombres, donc elles
appartiennent à la famille sombre. Même chose pour `traceBackground`, qui est le fond d'une image.

Les couleurs sémantiques — `azure`, `cyan`, `grape` — ne suivent aucune famille non plus : leur
teinte EST leur sens. Un bleu qui se réchaufferait cesserait de dire « fonctionnel ».

---

## 3. Les deux thèmes

**Décision D2 de Charlotte, 9 novembre 2026 : le fond clair est le défaut.** Le sombre l'était.
Le `#FBF9F7` chaud du brief **n'est pas imposé** — le fond froid actuel peut rester.

Trois règles, dans cet ordre.

**Une couleur de thème se déclare en deux branches, jamais une.** `isLight ? clair : sombre`, dans
`RUColor`. Une couleur écrite dans un fichier de vue est un défaut, même juste : personne ne la
trouve en ouvrant le système.

**Le texte est opaque, et dans la famille du fond — QUELLE QU'ELLE SOIT.** La règle ne nomme aucune
couleur. `check_jetons_de_texte.py` lit les fonds du thème, prend le signe de leur penchant, et
exige du texte le même signe. Une opacité est refusée : elle se mélange à ce qui passe dessous,
donc sa couleur serait décidée par la surface et non par le système.

Cette règle a été éprouvée le jour même où elle a été posée. Elle a été écrite quand les fonds
clairs étaient lavande, et elle exigeait alors du texte violet ; le fond clair est passé au chaud
quelques heures plus tard, et elle a exigé du texte chaud **sans qu'une ligne du garde change**.
Elle a même attrapé le jeton que j'avais oublié de faire suivre. Les jetons sombres, eux, restent
froids : leurs fonds le sont.

**Aucun fond ne perd de contraste.** Un gris violet se détache MOINS d'un fond lavande qu'un gris
neutre. Une valeur se règle donc sur le pire des fonds et pas sur le plus fréquent — calée sur la
carte blanche, `text3` tombait à 4,94:1 sur `bg2`. Les cinq fonds mesurés sont `bg`, `bg2`, `card`,
`card2`, et une borne du fond teinté.

Les rapports de contraste **ne sont écrits nulle part**, ni ici ni en commentaire :
`check_jetons_de_texte.py` les calcule et les imprime à chaque CI. Ils ont vécu dans un commentaire,
et c'est exactement comme ça que la branche sombre de `text3` avait pu rester sous le seuil pendant
qu'un commentaire d'à côté affirmait l'avoir corrigée.

---

## 4. La typographie

Une seule famille de texte : **Inter**, déclinée par taille et par graisse. Livrée dans les trois
cibles, vérifiée par `check_fonts.py`. Le titrage est Inter Medium, la même famille que le texte
courant, une graisse plus haut — pas une seconde famille.

**Les chiffres sont à chasse fixe partout.** `RUFont.display` applique `tnum` lui-même : trois
fichiers appelaient `.monospacedDigit()` à la main et tous les autres l'oubliaient, donc les
colonnes de l'app dansaient partout sauf à trois endroits.

### 4.1 Les deux échelles

Le texte courant, `RUTextSize` — ces valeurs sont des tailles de base, que le réglage
d'accessibilité du système multiplie :

| Cran | Valeur |
| --- | --- |
| `micro` | 8,5 |
| `small` | 10,5 |
| `body` | 12 |
| `label` | 14 |
| `emphasis` | 16 |
| `title` | 18,5 |

Le titrage et les chiffres, `RUDisplaySize` — **l'échelle est fermée**, et `check_echelle.py` la
tient. Elle a remplacé vingt-six tailles relevées dans le dépôt :

| Cran | Valeur | À quoi ça sert |
| --- | --- | --- |
| `caption` | 11 | micro-chiffres, valeurs de pastille |
| `label` | 14 | libellés de bouton, valeurs en ligne |
| `subtitle` | 18 | titres de ligne de liste, grille de mesures dense |
| `title` | 22 | titres de page, de feuille, de carte |
| `figure` | 28 | LE chiffre d'une carte — un cumul, une moyenne, une allure |
| `hero` | 35 | le chiffre unique d'un écran |
| `banner` | 44 | une accroche, un record : **au plus un par écran** |

**La graisse suit le cran**, parce que la graisse perçue baisse quand la taille monte : `figure`,
`hero` et `banner` passent en grasse, les quatre crans du bas non.

Une taille hors échelle s'écrit `display(horsEchelle: 52)`, et l'étiquette est là pour que
l'exception se voie : un `grep horsEchelle` donne la liste complète.

### 4.2 Les sept crans d'icône

`RUIconSize`, relevés sur les 170 appels existants plutôt qu'inventés : 9, 11, 13, 15, puis les
trois crans hauts. Les deux plus employés — 13 et 15, 65 appels à eux deux — n'ont pas bougé.

**Décision de Charlotte, 11 novembre 2026 : les SF Symbols restent.** Le brief demande Phosphor ou
Lucide au trait 1,5 px. 200 appels, et les SF Symbols suivent seuls la ligne de base, le poids de
la fonte et les tailles d'accessibilité. Gain esthétique, coût structurel : non.

---

## 5. Les règles de l'écran de séance

C'est le seul écran qu'on regarde en courant : essoufflée, en mouvement, à bout de bras. Ses
règles ne sont pas celles des écrans de consultation.

**Il reste sombre dans les deux thèmes.** Voir § 2.6.

**La consigne d'abord, le chronomètre ensuite.** Le chrono est le chiffre le moins coaché de
l'écran — une montre à vingt euros le donne. Ce qu'une app de coaching a de plus à dire, c'est quoi
faire maintenant. La consigne est donc au-dessus, avec le segment en surtitre et l'allure visée en
gros ; le chrono descend de 64 à 52 points quand il y a une consigne, et retrouve ses 64 quand il
n'y en a pas (HYROX, course libre).

**L'allure cible est le plus grand corps de l'écran**, au cran `banner` — celui que l'échelle
réserve à « au plus un par écran ». Le chrono prend `hero` quand une consigne l'accompagne, et
retrouve son très grand corps hors échelle (64) quand il est le seul chiffre, en course libre ou
en HYROX.

Ça n'a pas toujours été vrai : l'allure était à `hero` sous un chrono à 52, donc 1,49 fois plus
petit que ce que le code appelait « la première chose lue de l'écran ». Les deux phrases étaient
écrites à soixante lignes l'une de l'autre.

**Le plafond de l'allure est 44, et c'est une mesure.** Sur l'iPhone le plus étroit il reste 284
points utiles. « CIBLE 10:30/km » — le pire cas, un coureur lent pendant son échauffement — occupe
261 points à 44 et 301 à 52. Au-delà de 44, la consigne se tronque en course.

**Tout grand chiffre tenu sur une ligne peut rétrécir.** `lineLimit(1)` sans `minimumScaleFactor`
tronque, et sur un nombre la troncature ment : « 1:23:45 » devient « 1:23… » sans que rien ne dise
que ce n'est pas l'heure complète. Ni le chrono ni l'allure n'en portaient, et la ligne débordait
dès 1,31× de taille de texte quand l'app en autorise 2,00×. `check_grands_chiffres.py` le tient.

**Les chiffres roulent, ils ne sautent pas.** `monospacedDigit` d'abord, et c'est le plus important
des deux : avec des chiffres de largeurs différentes, un chrono de 52 points se décale
horizontalement à chaque seconde — un tremblement permanent au centre de l'écran, sur le seul
objet qu'on fixe en courant.

**Rien ne s'invente quand il n'y a rien à dire.** Sans allure cible au plan, le bloc de consigne
disparaît. Pendant l'échauffement, la récupération et le retour au calme, l'allure cible perd
l'accent et gagne le mot CIBLE : l'écran affichait « ÉCHAUFFEMENT » suivi de l'allure des
répétitions dans le même accent, soit, lu à bout de souffle, la consigne de courir son
échauffement à l'allure de son travail. Même place, même taille, aucun saut de mise en page toutes
les quatre-vingt-dix secondes — l'accent seul dit « c'est maintenant ».

**Le chiffre lui-même est le bouton.** Pas une petite croix qu'on finit par détester.

---

## 6. Le mouvement

`RUMotion`. Sept valeurs nommées, et `RUMotion.respecting(reduceMotion, …)` rend `nil` quand le
système demande moins d'animation — une animation n'est jamais appelée directement.

| Jeton | Durée | Pour quoi |
| --- | --- | --- |
| `digit` | 180 ms | un chiffre qui change |
| `ecran` | 220 ms | une transition d'écran |
| `snap` | 260 ms | une réponse à un geste |
| `settle` | 280 ms | l'arrivée d'une carte, **et le changement d'onglet** |
| `glide` | 500 ms | le remplissage d'un anneau |
| `draw` | 700 ms | le tracé d'un itinéraire |

Plus `stagger` à 55 ms, plafonné à 6 éléments — au-delà, le dernier d'une liste arriverait une
demi-seconde après le premier.

**La fourchette du brief ne couvre pas tout, et c'est la distinction qui tranche.** Elle parle des
TRANSITIONS — ce qui remplace une chose par une autre. Une animation de VALEUR, un anneau qui se
remplit ou un tracé qui se dessine, ne remplace rien : elle montre une quantité en train d'être
parcourue. Sa contrainte est autre, et simple : **être finie avant qu'on ait besoin de lire ou
d'agir.**

`digit`, `ecran` et `settle` sont des transitions, et les trois tiennent la fourchette.

`settle` gouvernait le **changement d'onglet** — ce que son propre commentaire appelle
« l'animation la plus vue de l'app » — à 440 ms. Toute l'app paraissait lente de 160 ms, à chaque
passage d'un onglet à l'autre.

`glide` et `draw` sont des animations de valeur. Leurs bornes sont mesurées, pas choisies :
`glide` doit laisser le dévoilement de l'écran d'ouverture finir avant le fondu, `draw` joue sur
chaque carte du fil qui porte un tracé — ce n'est pas un moment rare qu'on regarde, c'est du
contenu qu'on attend.

**L'ouverture est finie avant que l'écran ne s'efface**, et ça ne l'était pas : le dévoilement
finissait à 1,38 s quand le fondu commençait à 1,15 — 29 % du mouvement d'ouverture de l'app se
jouait pendant qu'elle disparaissait. Chaque valeur était raisonnable toute seule ; le défaut ne
vivait que dans leur somme. `check_lancement.py` refait l'addition à chaque CI.

---

## 7. Ce que Charlotte a décidé, et qu'on ne rouvre pas

| Décision | Quand |
| --- | --- |
| **D1** — les huit nuanciers d'accent restent | 9 novembre 2026 |
| **D2** — fond clair par défaut, pas forcément chaud | 9 novembre 2026 |
| **D3** — la barre basse garde ses cinq entrées (le brief en demandait trois) | 9 novembre 2026 |
| **D4** — l'inscription reste longue, et vise le plan le plus sur mesure possible | 9 novembre 2026 |
| D1 à D4 tiennent, face au brief re-transmis | 11 novembre 2026 |
| Le Club reste sous l'onglet Profil — **ne pas y revenir** | 11 novembre 2026 |
| Les SF Symbols restent | 11 novembre 2026 |
| Les sept teintes d'intensité actuelles restent | 11 novembre 2026 |

---

## 8. Ce qui attend une décision de Charlotte

| Question | L'état mesuré |
| --- | --- |
| La chaleur du fond de consultation | Le brief demande `#FBF9F7`, blanc chaud ; l'app porte `#F4F3F8`, gris-lavande froid. **C'est le plus grand écart visible qui reste**, et D2 a explicitement laissé le chaud non imposé. |
| La nuance de l'accent par défaut | Le brief demande `#F0225F` ; le nuancier « Rose » porte `#FF0A78`. |
| **L'app n'a de signature que sur deux écrans sur six** | Voir § 9. C'est la question qui reste après tout le reste. |


---

## 9. La signature : la carte de nuit

Le test final de la DA — « sorti de son cadre de téléphone et sans logo, l'écran doit être
reconnaissable comme RunUp » — ne tenait que sur deux écrans sur six. Charlotte a tranché le
13 novembre : l'étendre aux quatre autres.

### Ce que l'app avait d'authored

Une seule chose : **la carte sombre au tracé néon.** Un presque-noir plein cadre, un tracé GPS qui
s'y dessine en rose-violet lumineux, la date et les deux chiffres posés dessus. Elle a un point de
vue — la sortie comme un objet qui brille dans le noir — et elle ne ressemble à rien d'autre.

### L'état d'avant, mesuré sur les captures du 12 novembre

Part de l'image occupée par une surface sombre, **en thème clair** — donc là où le sombre est un
choix et non le thème :

| Écran | Surface sombre | Néon |
| --- | --- | --- |
| Club | 30,1 % | 0,9 % |
| Accueil | 15,0 % | 0,6 % |
| Coach | 2,6 % | 7,3 % |
| Stats | 1,9 % | 1,3 % |
| Journée | 1,6 % | 0,2 % |
| Plan | 1,3 % | 4,6 % |

### LA RÈGLE

Elle est écrite dans `RunUp/Views/Components/CarteDeNuit.swift`, qui est le composant, pour qu'on
ne puisse pas la suivre sans la lire. Quatre choses ensemble, et il faut les quatre :

1. **Ce qui est mesuré devient le dessin.** Pas une illustration de la donnée : la donnée
   elle-même, tracée. Le tracé EST la sortie, les barres SONT le plan, la courbe EST l'allure, le
   ruban EST la semaine. Un écran qui n'a rien à dessiner n'a pas de carte de nuit.
2. **Le dessin occupe le cadre**, bord à bord à la marge près. Il n'est pas une vignette posée
   dans une carte : c'est le cadre qui lui est donné.
3. **La nuit, et rien d'autre d'allumé.** `RUColor.traceBackground` (`#14131E`) dans les deux
   thèmes, et l'accent y est à pleine force — ce qu'il n'est nulle part ailleurs sur page claire.
4. **Les chiffres se posent dessus.** Pas dessous, pas à côté : sur le dessin, sous un voile qui
   garantit la lecture quelle que soit la forme. Ils légendent une image, ils n'étiquettent pas un
   graphique.

Et une cinquième, négative : **une seule par écran.** Deux points de fixation n'en font aucun.

### Ce que chaque écran y met

| Écran | Le dessin | Ce qui est posé dessus |
| --- | --- | --- |
| Accueil | le tracé GPS de la dernière sortie | sa date, sa distance, son allure |
| Plan | seize semaines de volume, en couleurs de phase | le nombre de semaines, le plus gros volume |
| Coach | les sept jours de la semaine, famille et durée | forme, séance du jour, dernière sortie |
| Journée | l'anneau des trois objectifs | le compte, **au moyeu** et non en bas à gauche |
| Stats | la courbe d'allure et son point RECORD | l'allure moyenne et son écart |
| Club | le tracé GPS de chaque sortie du mur | *(inchangé — il la portait déjà)* |

La Journée est la seule où les chiffres sont DANS la forme plutôt que dessus : son compte est le
moyeu de l'anneau. C'est une exception à la règle 4, et elle est nommée ici pour ne pas être
imitée ailleurs sans raison.

### L'ENCRE DE LA NUIT

La nuit ne suit pas le thème. Ce qu'on y peint ne doit donc pas le suivre non plus — et c'était le
cas partout :

- l'anneau de départ du tracé était en `RUColor.textPrimary`, soit `#181511` en thème clair : du
  presque-noir à 85 % sur du presque-noir. Sur la capture de l'accueil, il ne se lit pas comme un
  repère mais comme un **trou** percé dans la lueur ;
- la trace fantôme, à 7 % de la même encre, disparaissait tout court ;
- le tracé lisait `RUColor.rose`, qui rend `primaryOnLight` en thème clair — une valeur descendue
  pour rester lisible **sur du blanc**, qu'il n'y a pas ici.

Mesuré sur les huit nuanciers, rapport de luminance de l'accent contre `#14131E` :

| nuancier | sombre | clair | perte |
| --- | --- | --- | --- |
| rose, violet, bleu, magenta | 4,23 à 5,55 | idem à 6 % près | ≤ 6 % |
| corail | 5,94 | 5,25 | 12 % |
| ambre | 10,10 | 5,26 | 48 % |
| cyan | 10,37 | 5,25 | 49 % |
| lime | 12,34 | 5,23 | 58 % |

Le nuancier par défaut ne perdait presque rien, ce qui explique que personne ne l'ait vu pendant
deux mois : trois nuanciers sur huit perdaient la moitié de l'éclat de leur tracé.

Sur la nuit, on lit donc : `surLaNuit`, `surLaNuit2` (0,72) et `surLaNuit3` (0,16) pour l'encre ;
`accentsDeLaNuit` ou `AccentTheme.current.*` pour l'accent ; `limeSombre`, `cyanSombre`,
`amberSombre`, `emberSombre`, `azureSombre`, `grapeSombre` pour le sens ; `SessionFamily.tintSurLaNuit`
pour les sept familles. **`check_nuit.py` le tient** — il refuse un jeton de page dans le corps
d'un appel à `CarteDeNuit`, et dans les fichiers qui ne dessinent que sur la nuit.

Un composant qui vit sur les DEUX fonds ne choisit pas une palette : il reçoit un booléen
`surLaNuit` et calibre ses encres. C'est le cas de `DailyGoalsBarsView`, posé sur la page à
l'accueil et sur la nuit sur la Journée, et de la ligne d'allure des Stats. Une teinte qui doit
*paraître* la même sur deux fonds différents n'a pas la même valeur sur les deux : c'est déjà le
mécanisme de `primaryOnLight`, et ce n'est pas une divergence.

### Ce qui reste à regarder, et que je ne tranche pas

**La Journée.** Un anneau de progression sur fond noir est le vocabulaire de l'app Activité
d'Apple, reconnue partout. Celui de RunUp en diffère réellement — une seule piste segmentée en
trois arcs, et non trois anneaux concentriques, avec le compte au centre — mais la question 3 de
la DA (« est-ce qu'on devine qu'il a été généré ? » et, par extension, copié ?) se pose là et
seulement là. C'est un jugement sur une image rendue, pas une mesure : il appartient à Charlotte,
sur la capture.
