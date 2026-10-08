# Les captures de la fiche App Store

Apple demande des images de **1290 × 2796** (iPhone 15/16 Pro Max) ; toutes les autres tailles
d'iPhone en sont dérivées automatiquement. Une capture prise sur le téléphone fait la bonne
taille, mais reste une capture d'écran : ce que les gens voient sur une fiche est une image
composée — fond de marque, accroche, téléphone qui déborde du cadre.

`ci_scripts/screenshots.py` fabrique la seconde à partir de la première, et tourne depuis
l'onglet **Actions**, pour ne pas avoir à ouvrir un terminal.

## Ce qu'il y a à faire

1. **Remplir l'app.** Une capture d'un écran vide ne vend rien. Cinq ou six sorties, de durées
   et d'allures différentes, suffisent à ce que les graphiques et les objectifs aient l'air
   vivants.

2. **Prendre six captures brutes**, dans cet ordre — c'est celui des accroches de
   `captions.json`. La troisième colonne n'est pas un détail de confort : c'est ce qui fait qu'une
   capture PROUVE quelque chose au lieu de montrer un écran.

   | | Écran | L'état dans lequel il faut le prendre |
   |---|---|---|
   | 1 | Accueil | Les trois anneaux remplis à des hauteurs DIFFÉRENTES — trois anneaux vides, ou trois pleins, ne disent rien. La séance du jour visible, et la barre d'onglets entière. |
   | 2 | Le plan | Sur un objectif à DATE. C'est la seule façon d'afficher Base / Spécifique / Affûtage avec l'état de chaque bloc ; un objectif sans date rend « Programme ouvert, sans date de fin fixe », qui est vrai et ne vend rien. |
   | 3 | Le coach | Une RÉPONSE à l'écran, pas la question seule — et une réponse qui cite une séance réelle, puisque c'est l'accroche qui le promet. |
   | 4 | Le club | Le fil, avec au moins trois activités de personnes différentes. Un fil à une seule ligne prouve le contraire de « tu ne cours pas seul ». |
   | 5 | Ta journée | Les trois objectifs, dont un atteint et un en cours. |
   | 6 | Stats | Une courbe avec au moins six points, donc six sorties enregistrées. Une courbe à deux points est une ligne droite. |

   L'ordre des accroches suit celui des captures, pas l'inverse : si tes captures sortent dans un
   autre ordre, il est plus rapide de réécrire `captions.json` que de tout reprendre.

   **Ce tableau a été remis d'aplomb** : il annonçait « Ta journée » en 3, le coach en 4 et « Le
   partage d'une course » en 6, alors que `captions.json` — qui décide du texte posé sur l'image —
   portait depuis longtemps coach / club / journée / stats. Une capture du partage se serait donc
   retrouvée sous l'accroche « Tes records, en courbe ».

3. **Reprendre TOUTES les captures depuis la refonte de l'accent.** Celles du dossier `fr-FR`
   datent du 30 août et portent l'ancien rose, plus terne — repérable à l'œil à côté de l'app
   actuelle, et Apple refuse les captures qui ne correspondent plus à ce qu'on installe. Ont aussi
   changé depuis : le cadran de discipline sur le bouton RUN (appui long), le widget de l'écran
   d'accueil pendant une course, les modes vélo et trail, et l'objectif ultra-trail.

4. **Recommencer dans chaque langue.** L'app est traduite ; les captures, elles, montrent la
   langue du téléphone au moment de la prise. Une interface en français sous une accroche en
   anglais se voit tout de suite, et coûte l'installation. Réglages → Général → Langue et région,
   puis reprendre les six mêmes écrans.

   Les captures vont dans le dossier de leur langue — `appstore/raw/fr-FR/`, `appstore/raw/en-US/`,
   `appstore/raw/es-ES/`. Pas besoin de les renommer : le script les prend dans l'ordre de leur
   nom, et les captures d'un iPhone se numérotent déjà dans l'ordre où elles ont été prises
   (`IMG_0008.PNG`, `IMG_0009.PNG`…).

   Depuis le navigateur, sur un ordinateur — GitHub refuse les envois de fichiers depuis un
   navigateur mobile : ouvrir le dossier de la langue sur GitHub → **Add file** → **Upload files**
   → déposer → **Commit changes** en choisissant la branche de travail.

   Le run affiche en tête le dossier lu et l'ordre retenu. C'est là qu'on voit une inversion, pas
   sur la fiche publiée.

5. **Lancer la composition.** Onglet **Actions** → **App Store** → **Run workflow** → action
   `composer-les-captures`, choisir la langue → **Run workflow**.

6. **Récupérer le résultat.** À la fin de l'exécution, le fichier `captures-<langue>.zip`
   apparaît en bas de la page du run, dans **Artifacts**. Il contient les six images finies, à
   glisser dans App Store Connect.

Refaire l'étape 5 pour chaque langue : les captures brutes sont les mêmes, seule l'accroche
change.

## Le fond du cadre vient de la palette, et non d'ici

Le dégradé derrière le téléphone est lu dans `RunUp/DesignSystem/AccentTheme.swift`, nuancier
« rose ». Il ne l'était pas : `screenshots.py` portait deux jeux de constantes de marque, écrits
deux fois avec deux valeurs différentes, et **aucun des deux n'était lu** — le dégradé réellement
dessiné était trois littéraux réglés à la main le jour où le châssis est né.

Quand le rose de marque a changé de teinte, les quatre copies Swift ont suivi (`check_accent.py`
les tient ensemble) ; ce script-ci, non. Le cadre des captures gardait donc l'ancien rose, sur la
seule surface qu'on voit AVANT d'installer — et personne ne l'aurait signalé, puisque ça ressemble
à un choix. Une copie qui n'existe pas ne peut pas dériver.

## Changer les accroches

Elles vivent dans `appstore/captions.json`, six par langue, dans l'ordre des captures. Le script
refuse de tourner s'il y a plus de captures que d'accroches — plutôt que de composer une image
muette et de la laisser filer sur la fiche.
