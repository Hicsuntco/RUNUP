# L'aperçu vidéo de la fiche App Store

La vidéo de quinze à trente secondes qui se lance toute seule, en haut de la fiche, avant la
première capture. C'est la seule chose qu'on voit bouger avant d'installer.

## Ce qu'Apple exige, et qui se vérifie tout seul

| | |
|---|---|
| Taille | **886 × 1920** en portrait (grands iPhone) |
| Durée | **entre 15 et 30 secondes**, bornes incluses |
| Cadence | **30 images par seconde** au maximum |
| Format | H.264, dans un `.mp4`, `.mov` ou `.m4v` |
| Poids | 500 Mo au plus |

Source : [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications),
relue le 8 octobre 2026.

Un enregistrement d'iPhone 16 Pro Max sort en 1320 × 2868 à 60 images par seconde : il ne respecte
**ni la taille, ni la cadence**. `ci_scripts/apercu.py` corrige les cinq contraintes d'un coup, et
refuse avec une phrase claire quand l'enregistrement fait moins de quinze secondes — c'est le piège
le plus courant, et App Store Connect ne le dit qu'après l'envoi.

Il met l'image **à l'intérieur** du cadre plutôt que de l'étirer : le rapport de forme de
l'enregistrement diffère de trois millièmes de celui qu'Apple demande, donc au pire six pixels de
bande, et aucune déformation.

## Trois règles qui décident de tout

**1. Ça se regarde SANS SON.** L'aperçu démarre muet, et la plupart des gens ne le dés-ilencent
jamais. Rien d'important ne doit passer par une voix ou une musique. Pas de sous-titres non plus :
l'app parle d'elle-même à l'écran.

**2. Les trois premières secondes décident.** Elles sont vues par tout le monde, la suite par très
peu. On commence donc par ce qui MONTRE, pas par ce qui promet.

**3. Ça finit sur ce qu'on veut poster.** Une vidéo qui s'arrête sur un écran de réglages ne donne
envie de rien. La nôtre finit sur la vidéo de course — ce qu'on repart avec.

## Le découpage, vingt-quatre secondes

| | Durée | Ce qu'on filme | Ce que ça prouve |
|---|---|---|---|
| 1 | 0 → 3 s | **L'accueil.** Les trois anneaux à des hauteurs différentes, la séance du jour. | L'app en une seconde : voilà ta journée. |
| 2 | 3 → 7 s | **Le plan.** Un seul mouvement du pouce, Base / Spécifique / Affûtage visibles avec l'état de chaque bloc. | Ce n'est pas une liste de séances, c'est une périodisation. |
| 3 | 7 → 10 s | **Appui long sur RUN**, le cadran s'ouvre, glisse vers Trail. | Trois disciplines, et un geste qu'aucune autre app n'a. |
| 4 | 10 → 14 s | **La course en direct.** La carte, la distance qui monte. Quelques secondes d'une vraie sortie. | Ça marche vraiment, dehors. |
| 5 | 14 → 18 s | **La fin de course**, puis « FAIRE MA VIDÉO » et la barre qui se remplit. | L'app te rend quelque chose. |
| 6 | 18 → 24 s | **La vidéo qui se joue** : le tracé qui se dessine, les compteurs qui montent, la dernière image. | Ce que tu vas poster. |

L'ordre n'est pas celui de l'app, c'est celui de ce que chaque plan PROUVE — même principe que
l'ordre des captures. Le plan passe avant le coach parce qu'il se voit ; le coach, qui est du
texte, ne se lit pas en quatre secondes sans son.

## Avant de filmer

- **Remplir l'app.** Cinq ou six sorties de durées différentes, sinon les anneaux et les courbes
  sont vides et les quatre premières secondes ne montrent rien.
- **Un objectif à DATE**, sinon le plan affiche « Programme ouvert, sans date de fin fixe » — vrai,
  et sans intérêt ici.
- **Mode concentration activé.** Une bannière de notification en plein milieu est un motif de
  refus, et de toute façon une seconde perdue.
- **Batterie au-dessus de 30 %**, pour qu'aucun indicateur rouge ne traîne en haut de l'écran.
- **Une sortie avec un vrai tracé**, et assez longue pour survivre au rognage de confidentialité :
  le bouton « FAIRE MA VIDÉO » n'apparaît pas en dessous d'un kilomètre utile.

## Filmer, puis fabriquer

1. Réglages → Centre de contrôle → ajouter **Enregistrement de l'écran** s'il n'y est pas.
2. Enregistrer les six plans **d'une seule traite**, dans l'ordre. Viser vingt-cinq à trente
   secondes : on coupe ensuite, on ne rallonge pas.
3. Déposer le fichier dans `appstore/apercu/` — un seul fichier à la fois, le script refuse de
   choisir entre deux.

   **Et c'est là qu'est la vraie contrainte : GitHub n'accepte que 25 Mo par fichier déposé
   depuis un navigateur.** Un enregistrement d'écran de vingt-cinq secondes pèse entre dix et
   trente-cinq mégaoctets selon ce qu'il montre — l'interface compresse très bien, la carte en
   mouvement et la vidéo de course beaucoup moins. Si le dépôt est refusé :

   - **Raccourcir d'abord sur le téléphone** (Photos → Modifier → les deux poignées). Descendre à
     quinze ou dix-huit secondes suffit presque toujours, et c'est de toute façon un meilleur
     aperçu : les plans 4 et 5 peuvent perdre une seconde chacun sans rien perdre.
   - Refilmer en coupant le plan 4 (la course en direct), qui est le plus lourd de la série —
     une carte qui défile est ce qui compresse le plus mal.

   Ce n'est pas une limite qu'on peut contourner depuis un téléphone : `git push` en accepterait
   cent, mais il demande un terminal.
4. Onglet **Actions** → **App Store** → **Run workflow** → action `assembler-l-apercu`. Le champ
   `debut` permet de sauter les premières secondes, le temps de ranger le doigt.
5. Récupérer `apercu.mp4` dans **Artifacts**, en bas de la page du run, et le déposer dans App
   Store Connect au-dessus des captures.

## Et dans les trois langues

Comme les captures : l'interface filmée est celle de la langue du téléphone. Une app en français
sous une fiche anglaise se voit immédiatement. Réglages → Général → Langue et région, puis refaire
les six plans.

Si le temps manque, **l'anglais d'abord** : c'est la fiche que voient tous les pays sans
traduction dédiée.
