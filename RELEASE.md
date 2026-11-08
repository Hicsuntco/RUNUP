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
| **TestFlight** (`testflight.yml`) | 34 contrôles et 24 fichiers de cas passent, l'app compile, les tests unitaires passent, l'archive est signée et acceptée par App Store Connect | que les écrans sont justes — elle ne regarde aucune image |
| **Serveur** (`server.yml`) | les dépendances `require` sont du CommonJS, 133 tests passent, et les 83 adresses appelées par l'app répondent autre chose qu'un 404 ou un 5xx **en production** | que la logique est juste sur des données réelles : il n'y a pas de base de test |
| **Captures** (`captures.yml`) | l'app se lance dans trois langues et deux thèmes, 25 écrans sont photographiés, le découpage du film tombe sur les bons écrans | **ce qu'il y a sur les images.** Un vert dit deux choses : l'app n'a pas planté, un fichier a été écrit |
| **Fiche** (`appstore.yml`) | les textes tiennent dans les champs d'Apple, l'aperçu respecte ses règles, tout est déposé | que la fiche dit vrai |

Les 34 contrôles de TestFlight sont nommés dans `.github/workflows/testflight.yml`, un par étape.
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
Ils existent tous parce qu'un défaut est passé : une clé de catalogue absente qui sort le texte en
français chez tout le monde, un nom de symbole SF faux qui ne dessine rien du tout, une demande
d'autorisation non traduite renvoyée par Apple en ITMS-90738 **après** la livraison.

---

## 2. Les quatre questions qu'aucune machine ne pose

### a. Est-ce que j'ai REGARDÉ les captures ?

Pas « est-ce que le harnais est vert ». Ouvrir l'artefact `captures-app-store` et regarder, dans
l'ordre : les six images de la fiche, les quinze du dossier `diagnostic/`, et les quatre de
`diagnostic/grand-texte/`.

Le 7 novembre 2026, deux captures neuves sur trois montraient le mauvais écran — l'écran d'accueil
sous le titre « inscription », le décompte de départ sous « course en cours ». Les deux tests
étaient verts. Je ne l'ai su qu'en ouvrant les fichiers.

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
sh ci_scripts/tout.sh

# 3. Le serveur.
npm ci && python3 ci_scripts/check_cjs.py && npm test

# 4. La production, telle qu'elle est en ce moment.
python3 ci_scripts/check_deploiement.py
```

`check_profile.py` attend trois arguments et `check_grand_texte.py` un dossier de captures :
ni l'un ni l'autre ne s'exécute à vide, et `tout.sh` les saute pour cette raison. Le premier ne
tourne nulle part ailleurs non plus — voir § 4.

`comparer.py` n'est pas un contrôle et ne figure donc pas dans `tout.sh` : c'est l'outil qui dit
si un écran photographié a bougé. On lui donne les captures d'avant et celles d'après, il rend
l'écart moyen, le nombre de pixels changés et le cadre qui les contient, barre d'état masquée. À
lancer autour de toute réorganisation d'un écran que la chaîne Captures photographie :

```sh
python3 ci_scripts/comparer.py --avant /tmp/avant --apres /tmp/apres \
  --seulement club --pixels 0 --sortie /tmp/differences
```

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
  `api/`, `lib/` ou `package.json` est en ligne dans la minute.
- **Ce que fait Vercel du code une fois construit ne se lit pas dans le dépôt.** `jose` 6, livré
  en ESM seul et chargé par `require`, a mis l'API à terre onze minutes le 7 novembre 2026 :
  construction verte, 133 tests verts, et le Node du projet (24.x) charge pourtant ce paquet sans
  broncher en local. C'est l'empaquetage des fonctions qui ne sait pas le faire. `check_cjs.py`
  ferme cette porte-là ; la vraie réponse est d'éprouver un déploiement d'aperçu avant la
  production — ce qui demande de couper `Vercel Authentication` le temps de l'essai.
- **La montre n'a pas de captures propres.** L'app de poignet a ses écrans, et aucun n'a jamais
  été photographié : il n'existe pas de cible de test d'interface pour watchOS. L'iPad, lui, ne
  pose pas la question — `TARGETED_DEVICE_FAMILY` vaut 1 dans les réglages de base comme dans
  ceux du widget (seule la montre porte 4), donc RUNUP est une app iPhone et Apple ne demande
  aucune image d'iPad.
- **`check_profile.py` ne tourne nulle part, et c'est désormais écrit.** Il compare les
  capacités du profil de provisionnement à celles que la cible demande ; il a été écrit pour un
  `exportArchive` refusé sur `com.apple.developer.weatherkit`, douze minutes après le début de
  l'archivage. Aucun workflow ne l'appelle, parce qu'il demande le profil décodé, qui n'existe
  qu'au moment de la signature. Sa place est dans `testflight.yml` juste avant l'export. En
  attendant, il figure dans les `DISPENSES` de `check_cablage.py` avec cette raison : c'est le
  seul fichier de `ci_scripts/` qui ne tourne pas, et plus aucun autre ne peut le devenir en
  silence.
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
