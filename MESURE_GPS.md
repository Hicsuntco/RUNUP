# Mesurer le GPS en courant — le protocole

Chantier **A1**. Il demande quelqu'un qui court : cette page est ce qu'on lui donne.

## Ce qui est déjà éprouvé, et ce qui ne peut pas l'être

L'item disait « rien ne l'a jamais fait bouger ». C'est faux, et la mesure le dit : **24 cas**
éprouvent déjà la logique — 13 dans `LocationServiceTests` (plancher de bruit, saut après perte de
signal, seuil de confiance, pont de pause, alignement trace/altitudes, lots de points) et 11 dans
`AutoPauseTests` (armement, arrêt réel, délai, reprise).

Ce qu'aucun test ne peut atteindre, parce qu'il faut un vrai ciel et un vrai corps :

| Question | Ce qui est éprouvé | Ce qui ne l'est pas |
| --- | --- | --- |
| Précision | le filtrage des fix douteux | l'écart réel sur un parcours connu |
| Batterie | — | la consommation par heure |
| Reprise après coupure | le pont de pause, sur des fix synthétiques | une vraie perte de signal, app suspendue |
| Auto-pause | les seuils et le délai | le ressenti aux feux rouges et aux demi-tours |

## La configuration demandée à iOS, relue

Vérifiée dans `LocationService` plutôt que supposée. Elle est juste sur chaque point :

- `desiredAccuracy = kCLLocationAccuracyBest` — et non `BestForNavigation`, plus lourd et conçu
  pour la navigation routière ;
- `activityType = .fitness` ;
- **`pausesLocationUpdatesAutomatically = false`** — le piège classique. iOS le laisse à `true` et
  arrête alors les mises à jour en pleine course, sans rien dire. Il est désamorcé ;
- aucun `distanceFilter`, volontairement : l'auto-pause lit la vitesse instantanée ;
- `allowsBackgroundLocationUpdates` posé seulement une fois l'autorisation accordée, et **rendu à
  l'arrêt** depuis le 12 novembre.

## Les seuils que la course doit éprouver

Ce sont les nombres réels du code. Le protocole sert à savoir s'ils sont les bons.

| Règle | Seuil | Où |
| --- | --- | --- |
| Fix rejeté au-delà de | 65 m de précision annoncée | `LocationService` |
| Précision jugée instable au-delà de | 30 m | `unstableAccuracyThreshold` |
| Saut rejeté au-delà de | 12 m/s | `LocationService` |
| Auto-pause sous | 0,6 m/s pendant 10 s | `AutoPause` |
| Reprise au-dessus de | 1,3 m/s, ou 25 m parcourus | `AutoPause` |

## Le protocole

### 1. Précision — une boucle connue

Un parcours **mesuré** : une piste d'athlétisme (400 m par couloir 1), ou un aller-retour sur une
distance relevée au cadastre. Quatre tours = 1600 m.

- Courir 4 tours en couloir 1, téléphone dans la main.
- Relever la distance annoncée par l'app.
- **Attendu** : entre 1570 et 1630 m, soit ±2 %. Au-delà, noter la précision annoncée pendant la
  course (visible dans les diagnostics).
- Refaire **une fois téléphone en poche**, une fois **au brassard**. L'écart entre les trois porte
  autant d'information que l'écart absolu.

### 2. Batterie — une heure, deux fois

- Charger à 100 %, noter l'heure, courir ou marcher **60 minutes** écran éteint.
- Relever le pourcentage restant, et la part attribuée à RUNUP dans Réglages → Batterie.
- **Attendu** : à comparer à Strava ou Runna sur le même téléphone, même jour, même parcours. Le
  chiffre absolu ne veut rien dire ; l'écart avec un concurrent, oui.
- Refaire **avec la montre appairée** : c'est la configuration réelle de beaucoup de gens.

### 3. Reprise après coupure — trois coupures provoquées

Chacune pendant une course en cours, puis reprendre la course normalement et relever la trace :

1. **Tunnel ou parking souterrain** — 2 à 3 minutes sans ciel. La trace doit reprendre sans ligne
   droite traversant les bâtiments (c'est ce que le seuil de 12 m/s doit couper).
2. **Mode avion 60 secondes**, puis retour. Le GPS n'en dépend pas, mais la montre et la
   synchronisation si.
3. **App tuée depuis le sélecteur**, puis relancée. La course doit se retrouver, ou l'app doit le
   dire — pas faire semblant.

Relever à chaque fois : la distance avant, la distance après, et si la trace saute.

### 4. Auto-pause — le test des feux rouges

- Courir un parcours urbain avec **au moins quatre arrêts complets** de 20 à 60 secondes.
- Relever : le temps en mouvement, le temps total, et le nombre de pauses détectées.
- **Attendu** : une pause par arrêt, déclenchée après environ 10 secondes d'immobilité, et une
  reprise dans les 2 à 3 secondes suivant le redémarrage.
- Le cas qui compte le plus : **un demi-tour serré** et **une montée très lente**. Ni l'un ni
  l'autre ne doit déclencher une pause — le seuil est à 0,6 m/s, soit 2,2 km/h, ce qui est plus
  lent qu'une marche.

## Ce qu'on en fait

Chaque mesure revient ici avec sa date, son téléphone et sa version d'iOS. Un seuil qu'une course
réelle contredit se change **dans le code et dans le tableau ci-dessus**, pas dans l'un des deux.
