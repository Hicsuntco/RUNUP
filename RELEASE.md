# La porte de sortie

Ce qu'il faut avoir fait, et avoir REGARDÉ, avant qu'une version de RUNUP parte chez quelqu'un.

Ce fichier n'est pas une liste de bonnes intentions : chaque ligne renvoie à une commande qui
s'exécute ou à une image qu'on ouvre. Et il dit aussi ce qu'aucune machine ne tient — la
différence entre les deux est la seule chose qui compte un dimanche soir.

---

## 1. Ce que la machine tient toute seule

Quatre chaînes, et chacune garantit une chose précise. Aucune ne garantit celle d'à côté.

| Chaîne | Ce qu'elle prouve | Ce qu'elle ne prouve PAS |
| --- | --- | --- |
| **TestFlight** (`testflight.yml`) | 37 contrôles et 26 fichiers de cas passent, l'app compile, les tests unitaires passent, l'archive est signée et acceptée par App Store Connect | que les écrans sont justes — elle ne regarde aucune image |
| **Serveur** (`server.yml`) | les dépendances `require` sont du CommonJS, il y a au plus douze fonctions serverless, 155 tests passent, les 84 adresses appelées par l'app répondent autre chose qu'un 404 ou un 5xx **en production**, et l'écart entre la politique de confidentialité publiée et celle du dépôt est affiché | que la logique est juste sur des données réelles : il n'y a pas de base de test |
| **Captures** (`captures.yml`) | l'app se lance dans trois langues et deux thèmes, 28 écrans sont photographiés (21 ordinaires et 7 en grand texte), le découpage du film tombe sur les bons écrans. Une seule série à la fois : un nouveau push annule la précédente, l'artefact qu'on ouvre étant celui de la tête de branche | **ce qu'il y a sur les images.** Un vert dit deux choses : l'app n'a pas planté, un fichier a été écrit |
| **Fiche** (`appstore.yml`) | les textes tiennent dans les champs d'Apple, l'aperçu respecte ses règles, aucune bannière du système n'est sur les images qu'elle pousse, tout est déposé | que la fiche dit vrai |

Les 37 contrôles de TestFlight sont nommés dans `.github/workflows/testflight.yml`, un par étape.
L'un d'eux, `check_cablage.py`, veille sur les autres et sur les vingt-quatre fichiers de cas,
et il pose deux questions.

1. **Est-ce que ça tourne ?** Tout `check_*.py` et tout `test_*.py` de `ci_scripts/` doit être
   nommé par un workflow, ou figurer dans une liste de dispenses AVEC sa raison. Quatre
   garde-fous écrits et jamais câblés l'ont demandé — `test_session.py`, `test_accent.py`,
   `check_profile.py`, et `test_comparer.py`, attrapé le jour de son écriture.
2. **Est-ce que ça a de quoi tourner ?** Un script qui lit des images doit être lancé par un job
   qui fournit Pillow. `test_comparer.py` était bien câblé, dans TestFlight, dont le python du
   système n'a pas Pillow : `ModuleNotFoundError`, dix minutes après le commit. Les huit scripts
   du dépôt qui lisent des images tournent dans `captures.yml` ou `appstore.yml`, qui ont un venv.

Il n'y a **aucune dispense** aujourd'hui. Il y en a eu une, et elle était fausse :
`check_profile.py` n'est nommé par aucun workflow, et sa règle tourne pourtant à chaque build —
`profils.py` est appelé et l'importe pour sa fonction `manquantes()`. Le contrôle ne regardait
que les noms écrits dans les workflows ; il suit maintenant les imports. Une dispense fausse est
pire qu'une dispense manquante : elle dit qu'on sait, et on ne sait pas.
Ils existent tous parce qu'un défaut est passé : une clé de catalogue absente qui sort le texte en
français chez tout le monde, un nom de symbole SF faux qui ne dessine rien du tout, une demande
d'autorisation non traduite renvoyée par Apple en ITMS-90738 **après** la livraison.

---

## 2. Les quatre questions qu'aucune machine ne pose

### a. Est-ce que j'ai REGARDÉ les captures ?

Pas « est-ce que le harnais est vert ». Ouvrir l'artefact `captures-app-store` et regarder, dans
l'ordre : les six images de la fiche, les quinze du dossier `diagnostic/`, et les sept de
`diagnostic/grand-texte/`.

Le 7 novembre 2026, deux captures neuves sur trois montraient le mauvais écran — l'écran d'accueil
sous le titre « inscription », le décompte de départ sous « course en cours ». Les deux tests
étaient verts. Je ne l'ai su qu'en ouvrant les fichiers.

Et le 8 novembre, une notification d'iOS — « Ready for Apple Intelligence » — s'est posée en
travers du haut de `1-accueil` en français, UNE DES SIX IMAGES LIVRÉES. Même vert, même silence,
et elle n'a été vue qu'en comparant deux exécutions à la main. `check_banniere.py` la refuse
maintenant ; relancer la chaîne suffit, c'est une affaire de minutage.

### b. Est-ce que la production est debout ?

```sh
python3 ci_scripts/check_deploiement.py
```

Les 83 adresses doivent répondre 401, 405 ou 400. Un 404 veut dire qu'une route n'est pas
déployée ; un 5xx veut dire qu'une fonction est en ligne et ne démarre pas.

**Et c'est à faire APRÈS chaque poussée qui touche `api/`, `lib/` ou `package.json`, pas avant.**
La branche de travail est déployée en production à chaque commit (voir § 4).

### c. Est-ce que ça se lit dans les trois langues ?

Le catalogue est tenu par `check_strings.py` : toute chaîne affichée existe en français, anglais
et espagnol, à l'état `translated`. Ce qu'il ne voit pas, c'est la mise en page : un mot allemand
de dix-sept lettres dans un bouton de 88 points tronque sans rien casser. Les captures sont prises
dans les trois langues pour ça — donc voir (a).

### c bis. Est-ce que la politique PUBLIÉE dit ce que l'app collecte ?

Pas celle du dépôt : celle qui répond à l'adresse déposée sur la fiche App Store. Elle est servie
par GitHub Pages depuis `main`, donc elle ne bouge pas quand cette branche bouge.

```sh
python3 ci_scripts/check_politique.py
```

La chaîne Serveur le lance avec `--exiger` et ROUGIT sur une divergence. Une section présente
ici et absente là-bas veut dire que l'app collecte quelque chose que la page ne dit pas, et la
fiche de confidentialité d'App Store Connect le déclare pourtant : la divergence entre les deux
est un motif de rejet à part entière.

Si elle se représente, la correction ne se fait PAS depuis la branche de travail : la page est
servie par GitHub Pages depuis `main`. Il faut y porter `privacy.html` — c'est deux copier-coller
dans l'éditeur web de GitHub, et ça ne déclenche aucune de nos chaînes.

### d. Est-ce que c'est une décision, ou une absence de décision ?

Trois exemples de ce que ça veut dire, et les trois sont dans le code :
`RunRecordDiscipline.allDisciplines` existe pour que « toutes » soit écrit plutôt que sous-entendu ;
`display(horsEchelle:)` oblige à nommer une sortie d'échelle ; `check_echelle.py` demande d'écrire
pourquoi cet écran-là ne tient pas sur les sept crans. Une valeur qui n'est justifiée nulle part
est une valeur que personne n'a choisie.

---

## 3. La porte, dans l'ordre

```sh
# 1 et 2. Tous les contrôles, ET tous leurs cas. Une seule commande, parce que j'ai déjà
# poussé un contrôle vert dont le test était rouge : le 8 novembre, `check_icones.py` passait
# et `test_icones.py` répétait un nombre devenu faux. Découvert sur la machine, dix minutes
# plus tard.
#
# Compter DEUX MINUTES : 42 contrôles et 37 fichiers de cas, dont trois qui fabriquent des films
# avec ffmpeg, quatre qui relancent un contrôle en sous-processus pour l'éprouver, et deux qui
# interrogent le réseau. 107 à 117 s mesurées le 8 novembre 2026. Ce n'est pas une commande qu'on
# lance « pour voir », c'est la porte. (Plus que les 37 et 26 de TestFlight : `tout.sh` lance
# AUSSI ce qui tourne dans les autres chaînes — le serveur, les captures, la fiche.)
sh ci_scripts/tout.sh

# 3. Le serveur.
npm ci && python3 ci_scripts/check_cjs.py && npm test

# 4. La production, telle qu'elle est en ce moment.
python3 ci_scripts/check_deploiement.py
```

`check_profile.py` attend trois arguments ; `check_grand_texte.py` et `check_banniere.py`
attendent un dossier de captures. Aucun des trois ne s'exécute à vide, et `tout.sh` les saute
pour cette raison — ils tournent dans la chaîne Captures, qui a les images. La règle du premier
tourne quand même à chaque build, appelée par `profils.py`.

`comparer.py` n'est pas un contrôle et ne figure donc pas dans `tout.sh` : c'est l'outil qui dit
si un écran photographié a bougé. On lui donne les captures d'avant et celles d'après, il rend
l'écart moyen, le nombre de pixels changés et le cadre qui les contient, barre d'état masquée. À
lancer autour de toute réorganisation d'un écran que la chaîne Captures photographie :

```sh
python3 ci_scripts/comparer.py --avant /tmp/avant --apres /tmp/apres \
  --seulement club --pixels 0 --sortie /tmp/differences
```

**Juger sur `--pixels`, pas sur `--plafond`.** Relevé sur les captures réelles du Club, en
comparant le français à l'espagnol — tout le texte de l'écran changé, le pire cas qu'un
découpage puisse produire : la moyenne ne bouge que de **3,4 à 6,0** sur 255, et le compte de
pixels passe de zéro à **91 000 – 159 000**. Un plafond posé pour tolérer le rendu d'un dégradé
laisserait passer la moitié de ces cas. Deux captures du même état, l'heure masquée, rendent
0,000 et zéro pixel : il n'y a pas de bruit de fond à soustraire.

Puis, sur la machine :

1. **Captures App Store** → lancer → **ouvrir les images** (§ 2a).
2. **TestFlight** → vert de bout en bout, y compris l'envoi.
3. **La version monte dès qu'une version est publiée.** Apple ferme le train d'une version
   publiée : tout envoi en 3.3 est refusé depuis la sortie de la 3.3 (90186, 90062). Le refus
   arrive au DERNIER pas, après dix minutes de machine. `project.yml`, aux trois cibles.

---

## 4. Ce qui n'est tenu par aucune barrière

À lire avant de croire que la liste ci-dessus suffit.

- **La branche de travail est la production.** Vercel enregistre un déploiement « Production » par
  commit — douze le 7 novembre 2026. Il n'y a ni préproduction, ni relecture : une modification de
  `api/`, `lib/` ou `package.json` est en ligne dans la minute. Le projet :
  <https://vercel.com/hic-sunt/runup>, et ses réglages de protection :
  <https://vercel.com/hic-sunt/runup/settings/deployment-protection>.
- **Ce que fait Vercel du code une fois construit ne se lit pas dans le dépôt.** `jose` 6, livré
  en ESM seul et chargé par `require`, a mis l'API à terre onze minutes le 7 novembre 2026 :
  construction verte, 133 tests verts, et le Node du projet (24.x) charge pourtant ce paquet sans
  broncher en local. C'est l'empaquetage des fonctions qui ne sait pas le faire. `check_cjs.py`
  ferme cette porte-là ; la vraie réponse est d'éprouver un déploiement d'aperçu avant la
  production — ce qui demande de couper `Vercel Authentication` le temps de l'essai, puis de le
  remettre sur **Standard Protection** une fois l'essai fini. C'est un réglage qui se coupe en
  deux clics et qui ne se rallume pas tout seul : il n'existe aucun contrôle de ce dépôt qui
  puisse voir qu'il est resté ouvert.
- **La montre est photographiée depuis le 9 novembre 2026** par `.github/workflows/montre.yml`,
  dans les trois langues, et `check_requis.py` refuse une image qui ne montre plus l'app.
- **L'iPad ne pose pas la question** — `TARGETED_DEVICE_FAMILY` vaut 1 dans les réglages de base
  comme dans ceux du widget (seule la montre porte 4), donc RUNUP est une app iPhone et Apple ne
  demande aucune image d'iPad. Ce dépôt en a pourtant FABRIQUÉ une pendant vingt-quatre heures,
  le 9 novembre, alors que ce paragraphe disait déjà le contraire. Elle est partie le 10.
  **Ce qui reste à faire une fois, à la main** : la fiche publiée porte encore la capture iPad
  d'août, héritée d'une version précédente — App Store Connect recopie les captures de la version
  d'avant, tous formats confondus. Action `nettoyer-les-captures` du workflow App Store, avec
  `APP_IPAD_PRO_3GEN_129` dans le champ « retirer ». Et elle reviendra à chaque nouvelle version
  tant qu'on ne la retire pas : c'est pour ça que c'est une commande et pas un geste.
- **Le rapport de panne ne voit ni le simulateur, ni les erreurs rattrapées.** `Diagnostics.swift`
  s'abonne à MetricKit, donc iOS collecte la panne hors du processus mort et nous la rend au
  lancement SUIVANT — il n'y a pas d'alerte, et rien du tout sur un simulateur, où MetricKit ne
  collecte pas. Et par construction il ne voit que ce qui a mal tourné du point de vue du
  système : les 160 `try?` et 132 `catch` de l'app avalent des erreurs dont MetricKit n'entendra
  jamais parler. Une table `crash_reports` vide veut donc dire « rien de ce que le système
  appelle une panne », pas « rien ne casse ».
- **`main` et la branche de travail n'ont en commun que le commit initial.** Mesuré le 9 novembre
  2026 : 853 commits d'un côté, 50 de l'autre, aucune fusion depuis le 13 juillet. Ça n'empêche
  rien — l'app, Vercel et TestFlight sortent tous de la branche de travail — sauf sur un point :
  **`privacy.html`**, la page dont l'adresse est déposée sur la fiche App Store, est servie par
  GitHub Pages **depuis `main`**. Elle se met donc à jour en recopiant le fichier à la main, d'une
  branche à l'autre. `check_politique.py` va chercher la page PUBLIÉE en ligne et la compare au
  dépôt, texte compris, précisément parce que c'est la manœuvre où l'on reporte un paragraphe sur
  deux.
- **`support.html` n'est la page de personne.** Mesuré le 10 novembre 2026 : la fiche App Store
  déclare `mailto:charlottegrudep@gmail.com` comme URL de support, l'app propose ce même `mailto:`
  à deux endroits, et `privacy.html` ne pointe pas vers `support.html`. La page est publiée sur
  GitHub Pages et **rien n'y mène**. Quatre documents de ce dépôt parlaient des « deux pages
  qu'Apple affiche » : il n'y en a qu'une. Soit on fait de `support.html` la vraie URL de support —
  une page se corrige sans passer par une revue, un `mailto:` non — soit on la supprime. C'est une
  décision de fiche, pas de code.
- **Deux branches portent du travail qui n'est ni sur `main` ni sur la branche de travail.**
  `claude/running-club-finance-wwuq46`, neuf commits : annuaire de clubs, bouton d'invitation des
  amis, comblement de l'accueil entre la 1re et la 10e sortie, thème clair sans pastel, et une
  seule fonte d'affichage — **Oswald**, quand la branche de travail est sur Inter et DM Mono. Ce
  n'est pas du reste, c'est une direction artistique concurrente jamais tranchée.
  `claude/new-session-otcd8z`, un commit utile : `ef3ad89`, la lecture des agrégats rentrée dans
  `api/events.js` pour tenir sous les douze fonctions Vercel — le même plafond que `lib/` a servi
  à contourner ici, résolu autrement, ailleurs. `correction-auteur` ne porte rien d'unique.
- **Le contenu des séances HYROX** attend quelqu'un qui en a couru un (voir `PROGRESS.md`).

---

## 5. Les quatre leçons du 7 novembre 2026

Elles tiennent en une page et elles ont toutes coûté quelque chose.

1. **Un vert ne dit que ce qu'il mesure.** Un test de capture vert prouve que l'app n'a pas planté
   et qu'un fichier a été écrit. Il ne dit rien de ce qu'il y a dessus. Un film d'aperçu vert
   prouvait une durée, pas un découpage — trois films faux sont sortis avant qu'on compare les
   images aux captures.
2. **Un audit qui lit des captures se trompe d'un facteur 25.** « 2 émojis dans l'interface » :
   il y en avait 57. « 15 % de valeurs en dur » : il en restait six. Trois états « manquants »
   étaient tous présents. Et cinq vrais défauts n'étaient pas dans l'audit du tout. On mesure
   dans le code, pas sur une image de l'écran.
3. **Un contrôle qui ne tourne pas ne garde rien.** `test_deploiement.py`, `test_accent.py`,
   `test_session.py` existaient et aucun workflow ne les lançait. Un dossier listé au singulier —
   `RunUpWidget` au lieu de `RunUpWidgets` — faisait relire un dossier inexistant en silence,
   parce que `rglob` sur un chemin absent ne rend rien et ne dit rien.
4. **Ce qui marche sur la machine des tests ne dit rien de ce qui tourne en ligne.** Node 22 fait
   marcher `require` d'un module ESM. Le Node de Vercel, peut-être pas. La seule mesure valable
   d'une production est une requête à la production.

Et une cinquième, du 8 novembre 2026 : **quatre chaînes vertes ne disent pas qu'un déploiement a
eu lieu.** Le treizième fichier sous `api/` dépasse les douze fonctions serverless du plan Hobby,
et Vercel refuse alors la construction production entière. Rien ne rougit ici — aucune de ces
quatre chaînes ne déploie. Ce qui l'a établi n'est pas un journal de construction — on ne peut
pas le lire d'ici — c'est une mesure : une fois le compte ramené à douze, `/api/crashes` a répondu
200 en moins d'une minute, donc la réécriture, le gestionnaire et la migration du schéma étaient
arrivés d'un seul coup. `check_fonctions.py` compte désormais, et la sonde `check_deploiement.py`
reste la seule chose qui regarde la production elle-même.

Et une sixième, du même jour et de la même famille : **une mesure qui donne la bonne réponse peut
être fausse.** La première preuve tentée ci-dessus comparait le `privacy.html` servi par la
production à celui du dépôt. Il n'en sert aucun : ce fichier rend 404 sur Vercel, parce qu'il est
publié par GitHub Pages depuis `main`. Le compteur à zéro ne disait pas « ancienne version », il
disait « page d'erreur ». La conclusion était juste par accident, et il a fallu la refaire.
