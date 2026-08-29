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
   | 1 | Programme — la semaine en cours |
   | 2 | Accueil — les chiffres de la semaine |
   | 3 | Le détail d'une sortie (carte + splits) |
   | 4 | Le coach, avec une réponse à l'écran |
   | 5 | Objectifs — l'anneau bien rempli |
   | 6 | Le Club |

3. **Les déposer dans `appstore/raw/`**, nommées `1.png` … `6.png`. Depuis le navigateur :
   ouvrir le dossier `appstore/raw` sur GitHub → **Add file** → **Upload files** → déposer →
   **Commit changes** en choisissant la branche de travail.

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
