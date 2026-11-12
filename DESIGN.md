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
| `textPrimary` | `#15151C` | blanc pur | 265 |
| `text2` | `#443E4C` | `#BBB6C3` | 244 |
| `text3` | `#5B5563` | `#9893A0` | 318 |
| `text4` | `#B7B1BF` | `#514C59` | 8 |

`text4` **ne colore pas du texte à lire** : points médians, filets, pastilles inertes. Ses 1,7:1
sont voulus, et `check_contraste.py` tient la liste fermée de ses emplois avec une raison par
entrée.

Le primaire sombre est le blanc pur, délibérément hors famille : c'est le seul jeton dont on veut
le maximum de lisibilité.

### 2.5 Les surfaces

| Jeton | Clair | Sombre | Rôle |
| --- | --- | --- | --- |
| `card` | `#FFFFFF` | `#16161F` | la carte |
| `card2` | `#EDEBF4` | `#201F2A` | une sous-surface DANS une carte |
| `bg2` | `#E7E5F0` | `#121118` | le second fond |
| `traceBackground` | `#14131E` | les deux | le fond d'un tracé de sortie |

Le fond de page, `RUColor.bg`, n'est pas une constante : il vaut `#F4F3F8` en clair et `#08070D`
en sombre, et l'habillage « teinté » y mélange **3,5 % de l'accent en clair, 10 % en sombre**. Une
trace, pas un aplat : au-delà, le fond cesse d'être un fond et concurrence les cartes posées
dessus. La valeur claire a été à 7 % — sept pour cent du rose sur le neutre donne `#F4E3EF`, une
page rose, et les cartes blanches censées flotter dessus se lisaient comme des trous.

**Le fond est teinté et pas neutre, et c'est un aller-retour assumé.** Deux choses l'ont décidé :
l'app a gagné des images, et une carte blanche portant un rectangle sombre à ras bord sur une page
blanche ne se lit pas comme une surface mais comme un trou — il faut que la page recule pour que
la carte existe. Et le filet à 13 % dessinait chaque carte au trait, ce qui donne une grille de
rectangles cerclés sur un écran qui en empile quatre.

### 2.6 Les deux surfaces de l'écran de séance

| Jeton | Valeur | Thèmes |
| --- | --- | --- |
| `seanceSurface` | `#0E0E14` | les deux |
| `seanceFond` | `#0A0A0E` | les deux |

**Fixes dans les deux thèmes, et ce n'est pas un oubli.** L'écran de course reste sombre même en
apparence claire : on le regarde dehors, en mouvement, à bout de bras, et un fond blanc y perdrait
le contraste que les chiffres demandent.

---

## 3. Les deux thèmes

**Décision D2 de Charlotte, 9 novembre 2026 : le fond clair est le défaut.** Le sombre l'était.
Le `#FBF9F7` chaud du brief **n'est pas imposé** — le fond froid actuel peut rester.

Trois règles, dans cet ordre.

**Une couleur de thème se déclare en deux branches, jamais une.** `isLight ? clair : sombre`, dans
`RUColor`. Une couleur écrite dans un fichier de vue est un défaut, même juste : personne ne la
trouve en ouvrant le système.

**Le texte est opaque, et dans la famille du fond.** Les quatre fonds penchent vers le violet de
l'accent — `#F4F3F8` porte le bleu 4 points au-dessus du rouge, `#EDEBF4` 7, `#E7E5F0` 9. Un gris
pur à côté d'un rose vif prend l'air sale ; un gris qui partage sa famille non. La règle est donc
**bleu au-dessus du rouge, vert au plus égal**, et une opacité est refusée : elle se mélange à ce
qui passe dessous, donc sa couleur serait décidée par la surface et non par le système.

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

> **Écart connu, non résolu.** L'allure cible est à `hero`, soit 35 points, sous un chrono à 52.
> Le code dit de l'allure qu'elle est « la première chose lue de l'écran » et du chrono qu'il
> « cesse d'être la première chose lue » : les deux commentaires annoncent une hiérarchie que les
> tailles ne tiennent pas. Chantier ouvert.

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
| `settle` | 440 ms | l'arrivée d'une carte |
| `glide` | 800 ms | le remplissage d'un anneau |
| `draw` | 1 450 ms | le tracé d'un itinéraire |

Plus `stagger` à 55 ms, plafonné à 6 éléments — au-delà, le dernier d'une liste arriverait une
demi-seconde après le premier.

> **Écart connu, non résolu.** Le brief demande 200 à 300 ms en consultation. `digit`, `ecran` et
> `snap` y sont ; `settle`, `glide` et `draw` sont au-dessus, chacun avec une raison écrite, et
> aucun n'a été confronté à la fourchette. Chantier ouvert.

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
| Le corps du chiffre central de l'écran de séance | Voir l'écart connu du § 5. |
| Les trois durées hors fourchette | Voir l'écart connu du § 6. |
| Le cycle n'a aucun jeton | La DA demande `#F2B8A0` sur `#FDF1EC` ; l'app n'a rien et affiche la phase en gris comme le reste. |
