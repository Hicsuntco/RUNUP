# Phase 2 — la liste unique des chantiers

Établie le 9 novembre 2026, à partir de `AUDIT.md` et de mesures refaites aujourd'hui sur
`claude/runup-ios-swiftui-app-5b1yv6`.

**Rien n'est commencé.** Le brief dit : j'attends ta validation avant d'écrire du code. Cette
liste est donc à lire, à trancher et à renvoyer — pas à exécuter.

---

## Comment lire les trois colonnes

**Effort** — la taille du changement et le prix de sa vérification, pas une durée.

| | |
| --- | --- |
| **S** | Un ou deux fichiers, un garde-fou, une passe de chaîne. |
| **M** | Plusieurs fichiers, un garde-fou à écrire, des captures à refaire dans les trois langues. |
| **L** | Touche une structure — navigation, parcours d'inscription, `AppState` — ou demande une mesure sur un vrai appareil. |
| **XL** | Demande quelqu'un d'autre que moi : quelqu'un qui court, quelqu'un qui a fait un HYROX, ou une décision produit lourde. |

**Impact** — qui le voit, et à quel moment. **Risque** — ce qui peut casser en le faisant.

---

## Avant tout : quatre décisions qui sont les tiennes

Ces quatre-là ne sont pas des chantiers. Ce sont des arbitrages, et **la moitié de la liste en
dépend** : tant qu'ils ne sont pas tranchés, je ne peux pas savoir si un item du groupe A est du
travail ou une erreur.

Dans chaque cas, l'app a une raison écrite dans son code. Ce n'est pas de la négligence : c'est un
autre produit que celui du brief.

### D1 — Huit thèmes d'accent, ou un seul ?

`AccentTheme.all` propose **huit palettes** au choix dans Profil → Apparence : rose, violet, bleu,
cyan, lime, ambre, corail, magenta. Le brief dit « une seule couleur d'accent RunUp ».

- **Si on ferme à un seul** : l'identité devient reconnaissable, et le système de jetons se
  simplifie beaucoup. On retire un réglage que des gens utilisent peut-être déjà.
- **Si on garde les huit** : le brief est à réécrire sur ce point, et toutes les règles qui en
  découlent avec.

### D2 — Sombre par défaut, ou fond clair chaud ?

Le brief décrit un fond de consultation `#FBF9F7` (blanc chaud) et une séance sur noir.
**L'app fait l'inverse** : le thème sombre est le défaut, le fond est `#F4F3F8` (froid), et la
personne choisit. C'est une direction opposée, pas un écart de teinte.

### D3 — La barre basse : cinq entrées ou trois ?

Aujourd'hui : **Prog, Coach, RUN, Stats, Profil** — et **le Club n'y est pas**, alors que c'est
l'un des trois différenciateurs annoncés. Le brief demande **Aujourd'hui, Plan, Club**.

Le passage à trois onglets déplace le Coach, les Stats et le Profil ailleurs. C'est le chantier
le plus structurant du document et il ne se fait pas par morceaux.

### D4 — L'inscription : dix-neuf écrans ou trois questions ?

Dix-neuf écrans aujourd'hui. En retirant les quatre écrans propres à une discipline et le
conteneur, il en reste **une douzaine**. Le brief en demande trois.

Chaque écran actuel alimente le moteur de plan. Passer à trois questions veut dire que le moteur
doit se contenter de beaucoup moins, ou deviner le reste. **C'est une décision produit sur la
qualité du premier plan**, pas une décision d'interface.

---

## Groupe A — bloquant avant tout nouveau téléchargement

Ce qui doit être réglé avant qu'une nouvelle personne télécharge l'app. Classé par gravité.

| # | Chantier | Effort | Impact | Risque |
| --- | --- | --- | --- | --- |
| **A1** | **Mesurer le GPS en courant** — précision, batterie, reprise après coupure, auto-pause. Rien ne l'a jamais fait bouger. | **XL** | C'est le cœur du produit. Une trace fausse rend tout le reste sans valeur. | Aucun, c'est une mesure. Mais elle demande quelqu'un qui court, avec un téléphone et une montre. |
| **A2** | **Consentement révocable aux statistiques d'usage.** `Analytics.track` n'a aucune porte : le seul garde-fou est le mode démonstration. La politique les décrit, l'app ne les propose pas à refuser. | **M** | Le point RGPD le plus discutable du produit. Un refus de l'App Store se joue là. | Faible. Un réglage, une porte dans `Analytics`, un garde-fou qui refuse tout `track` non gardé. |
| **A3** | **Le mode hors ligne et la connexion lente.** `PanneReseau` existe ; rien ne l'éprouve sous latence ni en coupure franche. | **M** | Une coupure en pleine course, c'est le moment où l'app doit être la plus solide. | Moyen : écrire ces cas demande de simuler le réseau, donc de toucher la couche d'appel. |
| **A4** | ~~**Le paiement de bout en bout.** `SubscriptionService` existe, aucun test de parcours d'achat.~~ **FAIT — et l'item était mal posé, pour la quatrième fois.** Les trois décisions du parcours étaient déjà sorties de StoreKit et déjà sous test : `Entitlement` (8 cas), `OfferCodeOutcome` (6), `RestoreOutcome` (7). Mais en lisant, une asymétrie : `applyRedemption` attendait le droit d'accès 3,2 s, commentaire à l'appui ; `purchase(_:)` le lisait **une fois** et répondait **« L'achat n'a pas abouti. »** après une transaction signée par Apple — plus un `purchaseFailed` dans la statistique et un bouton d'achat laissé actif. Voir « Chantier 28 » dans `PROGRESS.md`. | — | — | — |
| **A5** | ~~**Un composant d'état vide partagé.** Zéro fichier ne porte un `RUEmpty`.~~ **FAIT, composant ET reliquat.** 6 appels au départ, **24** dans 17 fichiers. La mesure : trois graisses de titre, deux couleurs de message, deux corps de texte, deux tailles d'icône pour la même phrase — et le composant partagé était LUI-MÊME le seul à ne pas utiliser `RUIconSize.hero`, le cran que le système nomme pour lui. Quatre endroits ne sont pas convertis, chacun avec sa raison écrite (une promesse de premier jour, un appel à l'action, un chargement, une erreur). Gardé par `check_vides.py` (15 cas), qui **dit aussi ce qu'il ne sait pas garder** : la forme `.ligne` n'a pas de signature détectable — 35 candidats pour 6 vrais. Et un trou trouvé en passant : trois familles de composants passaient un nom de symbole par propriété stockée, invisible au contrôle des symboles ; 3 symboles n'avaient jamais été éprouvés. Voir « Chantier 31 » dans `PROGRESS.md`. | — | — | — |
| **A6** | **Le `TODO(privacy)` périmé dans `PrivacyInfo.xcprivacy`** affirme que la phase du cycle part « sans que le réglage correspondant ne mentionne aucune transmission ». **C'est faux** : `shareCyclePhaseWithCoach` est un réglage distinct, à l'arrêt par défaut, dont le texte dit exactement ce qui part et que refuser ne change rien au programme. | **S** | Un commentaire faux dans un fichier qui est une déclaration légale. | Nul. C'est une correction de texte. |
| **A7** | **`RunUpWatch` n'embarque aucun `PrivacyInfo.xcprivacy`**, là où l'app et le widget ont le leur. La cible n'appelle aucune API à motif obligatoire — l'absence se défend — mais je n'ai pas de source Apple qui tranche pour un paquet de montre embarqué. | **S** | Un rejet à l'envoi (ITMS-91053) coûte une journée et se découvre après l'archivage. | Nul si on en pose un vide et honnête. **À chercher, pas à deviner.** |
| **A8** | ~~`privacy.html` et `support.html` sont recopiés à la main depuis `main`~~ **DÉJÀ COUVERT, et l'item était mal posé.** `check_politique.py` va chercher la page PUBLIÉE en ligne et compare le texte de chaque section, commentaires ignorés, avec `--exiger` dans `server.yml`. Et `support.html` n'est la page de personne : la fiche App Store déclare un `mailto:`, l'app aussi, rien n'y mène. Reste une décision de fiche : en faire la vraie URL de support, ou la supprimer. | — | — | — |

---

## Groupe B — ce qui nous sépare de Runna et de Strava

Classé par ce que ça change pour quelqu'un qui compare les trois apps côte à côte.

| # | Chantier | Effort | Impact | Risque |
| --- | --- | --- | --- | --- |
| **B1** | ~~**Les allures cibles n'ont jamais été confrontées à une méthode nommée.**~~ **FAIT.** Les quatre coefficients (× 1,20, × 1,08, × 1,00, × 0,87) passent par Daniels–Gilbert, *Oxygen Power* (1979), avec les fractions de VO2max **retrouvées depuis la table publiée** plutôt que recopiées d'un site. Trois des quatre étaient faux : le footing 18 à 25 s/km trop rapide à tous les niveaux — sur l'allure qui porte 70 à 80 % du volume —, la VMA à l'allure du **mile** pour des répétitions de 3 à 5 min, le seuil légèrement trop rapide ; seul le marathon était juste. Et un test **vert** interdisait la bonne réponse, qu'une version antérieure du code avait eue. Riegel sort de l'ancrage. Bascule : à la prochaine régénération de semaine, rien n'est réécrit en cours de semaine. Voir « Chantier 29 » dans `PROGRESS.md`. | — | — | — |
| **B2** | **Le guidage vocal par intervalle n'existe pas.** La voix dit deux choses, et seulement deux : « accélère un peu », « ralentis légèrement ». Pas de départ de répétition, pas de fin, pas de décompte, pas d'annonce de kilomètre. **C'est la signature de Runna.** | **M** | Sur une séance de fractionné, c'est la différence entre regarder son téléphone et courir. | Faible. `VoiceCoachController.announce` existe déjà ; ce qui manque est ce qui l'appelle. |
| **B3** | **La règle 7 est enfreinte, et la cause est dans le système de jetons.** 24 fichiers portent un dégradé, 7 un verre dépoli — dont **la barre d'onglets** (`.ultraThinMaterial`). Mais ce ne sont pas 24 décisions : `AccentTheme` porte un `tail` par palette, et `RUColor` expose `accentGradient`, `brandGradient`, `heroGradient`, `violetRoseGradient`. **Le système distribue le dégradé.** Une décision au niveau des jetons, puis ~14 appels à reprendre. | **M** | C'est ce qui fait qu'une app a l'air dessinée ou générée. | Moyen : un aplat là où il y avait un dégradé change le contraste, donc les garde-fous de contraste vont parler. C'est voulu. |
| **B4** | ~~**La montre : le dégradé sur le bouton principal, et la phrase du bas coupée dans les trois langues.**~~ **FAIT.** Le dégradé était déjà parti avec le chantier 24 — restait son commentaire. La phrase, elle, était **tranchée par l'arête basse** : 11 lignes de pixels encrées jusqu'à la dernière, dans les trois langues, sur l'image que la fiche App Store publie. Cause : l'anneau décoratif prenait 118 points sur 248, et le code le disait lui-même « purely decorative ». 96/76/écarts à 6, soit 28 points rendus. Gardé par une règle neuve de `check_captures_montre.py` — la bande basse doit rester vierge — éprouvée sur les vraies captures d'avant. Voir « Chantier 33 » dans `PROGRESS.md`. | — | — | — |
| **B5** | **`ClubView` fait 1 424 lignes** et porte le classement, le fil, les défis, les badges, les séances et la recherche. C'est le différenciateur annoncé, dans un seul fichier. | **L** | Tout ajout au Club coûtera cher tant que c'est un seul écran. | Moyen. Une découpe sans changement de comportement se vérifie mal autrement que par des captures. |
| **B6** | **Les listes longues.** 63 fichiers utilisent `ForEach`, **11 seulement** une liste paresseuse. Le fil du club et l'historique ne sont pas courts. | **M** | Invisible sur un compte neuf, net sur un compte chargé — c'est-à-dire chez les gens qui restent. | Faible, mais il faut un compte chargé pour mesurer avant/après. |
| **B7** | **Le temps de lancement n'a jamais été relevé.** La phase 4 exige « premier écran en moins de 2 secondes ». | **S** pour la mesure, inconnu pour la suite | On ne peut pas tenir une promesse qu'on n'a pas mesurée. | Nul : c'est une mesure. |
| **B8** | **`AppState` est un objet-dieu de 1 245 lignes.** C'est la vraie dette d'architecture : elle rend chaque chantier suivant plus cher. | **L** | Invisible pour l'utilisatrice, décisif pour tout le reste de cette liste. | Élevé. À faire par morceaux, jamais d'un bloc, et seulement si un autre chantier le réclame. |

---

## Groupe C — nouveautés à forte valeur

**Ce groupe est court, et c'est une bonne nouvelle.** La plupart de ce que j'aurais proposé existe
déjà et je l'ai vérifié : export GPX (`GPXExporter`), liaison Strava (`StravaService` +
`api/strava/`), écriture dans Santé, records personnels, notifications, Live Activity, widget,
complication, montre autonome, fil de club, défis, badges, itinéraires partagés.

Il reste ceci :

| # | Chantier | Effort | Impact | Risque |
| --- | --- | --- | --- | --- |
| **C1** | **Dire pourquoi cette séance, aujourd'hui.** Le moteur sait tout : la charge, la décharge, l'affûtage, le plafond à +10 %. L'app affiche la séance, pas le raisonnement. Une phrase par séance, tirée de ce que le moteur a réellement décidé — pas un texte générique. | **M** | C'est ce qui transforme un calendrier en coach. Et c'est gratuit : la donnée existe déjà. | Faible — à condition que la phrase vienne du moteur et pas d'un catalogue de phrases. Sinon c'est un texte générique, donc un défaut. |
| **C2** | **Un test d'interface pour la montre.** Aucune cible de test watchOS n'existe. Depuis aujourd'hui la chaîne sait la photographier ; elle ne sait pas la piloter. | **M** | La montre est la seule partie du produit qu'aucun test ne touche — et c'est celle qui vient de passer des mois en français pour tout le monde. | Faible. |
| **C3** | **Le contenu des séances HYROX, validé par quelqu'un qui en a couru un.** | **XL** | C'est le seul endroit du produit où je refuse de me prononcer. Publier un plan HYROX non validé, c'est enfreindre la règle 2. | Le risque est de ne PAS le faire. |

---

## L'ordre que je propose

Le brief fixe la règle : **le design system d'abord, puis un chantier à la fois.** Appliquée ici,
elle donne un ordre qui n'est pas celui de la gravité, et je l'assume :

1. **D1 à D4** — tes quatre décisions. Rien de sérieux ne commence avant.
2. **B3, le système de jetons** — parce que c'est là que vit la cause des dégradés, et que tout
   chantier d'écran fait après devra être refait avant. Le brief le dit, et la mesure le confirme :
   ce n'est pas 24 fichiers, c'est quatre jetons et quatorze appels.
3. **A6, A7, A8** — trois corrections courtes qui ferment des portes juridiques. Une demi-journée
   pour les trois, et A7 demande une recherche, pas une supposition.
4. **A2, le consentement aux statistiques** — le seul point de cette liste qui peut faire retirer
   l'app.
5. **A5, l'état vide partagé** — parce que tous les chantiers d'écran qui suivent en auront besoin.
6. **B4, la montre** — court, et elle vient d'être remise à neuf.
7. **B2, le guidage vocal par intervalle** — le meilleur rapport entre ce que ça coûte et ce que
   ça change face à Runna.
8. **A3 et A4** — hors ligne et paiement.
9. **B1, les allures** — le plus lourd du groupe B, et celui qui demande le plus de lecture avant
   la première ligne de code.
10. **A1, le GPS** — à caler dès que quelqu'un peut courir avec. Ça ne dépend pas de moi, donc ça
    ne doit bloquer personne.

**B5, B6, B8 et C1 à C3 viennent après**, et je les reproposerai quand les précédents seront
faits plutôt que de promettre un ordre que la réalité démentira.

---

## Ce que je ne mets pas dans la liste, et pourquoi

- **Android.** Décision du 7 novembre : iOS seul. Il n'y a ni cible, ni code, ni projet.
- **Remplacer SF Symbols par Phosphor ou Lucide.** Le brief le demande ; c'est un écart assumé qui
  coûterait une passe sur 111 écrans pour un gain que je ne sais pas chiffrer. À rouvrir si tu y
  tiens, pas à faire en silence.
- **Chiffrer les données au repos au-delà de ce que fait iOS.** À poser pour le cycle — mais le
  cycle ne quitte déjà jamais l'appareil, ce qui est la position la plus défendable possible. Le
  gain réel est faible devant le reste de cette liste.
- **Les deux branches qui portent du travail nulle part ailleurs** (`claude/running-club-finance-wwuq46`,
  `claude/new-session-otcd8z`). C'est une question de dépôt, pas de produit ; elle reste dans
  `PROGRESS.md`.

---

## Ce que je n'ai pas pu mesurer

- **Je n'ai pas ouvert les 111 écrans.** J'ai vu l'accueil dans les deux thèmes, la montre dans
  les trois langues, et la fiche App Store. Tout le reste de cette liste qui parle d'un écran est
  jugé sur le code, et c'est dit à chaque fois.
- **Je n'ai pas lancé l'app** : il n'y a pas de macOS ici. Tout ce qui se compile ou se
  photographie passe par la chaîne d'intégration.
- **Aucun chiffre de performance réelle** : ni batterie, ni temps de lancement, ni fil de club
  chargé. Ce sont des mesures, et elles manquent toutes.
