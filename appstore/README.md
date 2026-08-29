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
   `captions.json` :

   | | Écran |
   |---|---|
   | 1 | Accueil — objectifs du jour, programme en cours |
   | 2 | Programme — le plan complet |
   | 3 | Ta journée — les trois objectifs |
   | 4 | Le coach, avec une réponse à l'écran |
   | 5 | Stats — ta forme évolue |
   | 6 | Le partage d'une course |

   L'ordre des accroches suit celui des captures, pas l'inverse : si tes captures sortent dans un
   autre ordre, il est plus rapide de réécrire `captions.json` que de tout reprendre.

3. **Les déposer dans `appstore/raw/`.** Pas besoin de les renommer : le script les prend dans
   l'ordre de leur nom, et les captures d'un iPhone se numérotent déjà dans l'ordre où elles ont
   été prises (`IMG_0008.PNG`, `IMG_0009.PNG`…). Depuis le navigateur, sur le téléphone comme sur
   l'ordinateur : ouvrir le dossier `appstore/raw` sur GitHub → **Add file** → **Upload files** →
   déposer → **Commit changes** en choisissant la branche de travail.

   Le run affiche l'ordre retenu en première ligne. C'est là qu'on voit une inversion, pas sur la
   fiche publiée.

4. **Lancer la composition.** Onglet **Actions** → **App Store** → **Run workflow** → action
   `composer-les-captures`, choisir la langue → **Run workflow**.

5. **Récupérer le résultat.** À la fin de l'exécution, le fichier `captures-<langue>.zip`
   apparaît en bas de la page du run, dans **Artifacts**. Il contient les six images finies, à
   glisser dans App Store Connect.

Refaire l'étape 4 pour chaque langue : les captures brutes sont les mêmes, seule l'accroche
change.

## Changer les accroches

Elles vivent dans `appstore/captions.json`, six par langue, dans l'ordre des captures. Le script
refuse de tourner s'il y a plus de captures que d'accroches — plutôt que de composer une image
muette et de la laisser filer sur la fiche.
