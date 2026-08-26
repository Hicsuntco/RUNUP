# Fiche App Store — RUNUP

Contenu prêt à copier-coller dans App Store Connect (App Information / Fiche de l'app).

L'app est livrée avec trois localisations réelles (`CFBundleLocalizations: fr, en, es` dans
project.yml, adossées à 1 119 clés traduites dans `RunUp/Resources/Localizable.xcstrings`) — la fiche
doit donc exister dans les trois, sinon App Store Connect n'expose l'app qu'en français et les
recherches anglophones/hispanophones ne la trouvent jamais. Chaque locale a sa propre section
ci-dessous ; les sections communes (catégorie, âge, URLs, copyright) ne se saisissent qu'une fois.

> **Règle de rédaction** : rien ici ne doit décrire une fonctionnalité que le code n'implémente pas
> réellement. Une promesse non tenue dans la fiche est un motif de rejet (App Review Guideline 2.3
> — "Accurate Metadata"), et c'est exactement ce qui s'était glissé dans la version précédente de ce
> fichier (un VO2max estimé, retiré du code depuis — voir le commentaire en tête de
> `RunUp/Views/Stats/StatsView.swift` — un verrouillage d'écran qui n'existe plus, et un programme
> annoncé fixe à 9 semaines quand `AdaptivePlanEngine.ProgramShape` en calcule 4 à 20 selon la date
> de course, ou aucun terme du tout pour les objectifs sans date).

---

# 🇫🇷 Français (langue principale)

## Nom de l'app (30 caractères max)
```
RUNUP : Coach de Course
```

## Sous-titre (30 caractères max)
```
Ton coach personnel de course
```

## Texte promotionnel (170 caractères max — modifiable à tout moment sans nouvelle review)
```
Un programme qui s'adapte après chaque sortie, un vrai coach qui te connaît, et tes objectifs du jour en un coup d'œil. Cours comme si tu avais un coach.
```

## Description (4000 caractères max)
```
RUNUP construit ton programme de course sur mesure, l'ajuste après chaque sortie selon ta forme et ton ressenti, et te pousse juste ce qu'il faut — jamais plus, jamais moins.

UN VRAI COACH, PAS UN CHATBOT
Un vrai coach personnel qui connaît ton objectif, ton historique et ta forme du jour. Pose-lui une question avant ta séance, demande un conseil nutrition, ou fais-toi rassurer après une sortie difficile. Pendant l'effort, tu peux même lui parler : tu appuies, tu poses ta question à voix haute, il te répond dans les écouteurs.

UN PROGRAMME QUI VIT AVEC TOI
Après chaque course, donne ton ressenti (RPE) — le programme ajuste la difficulté des semaines suivantes. Base, spécifique, affûtage : un vrai plan périodisé calé sur la date de ta course, de 4 à 20 semaines selon le temps qu'il te reste. Sans date de course (progresser, perdre du poids, reprendre en douceur, rester en forme), il tourne en continu avec ses semaines de décharge. Nuit trop courte ou séance de la veille trop dure ? La séance du jour s'allège d'elle-même.

TES OBJECTIFS DU JOUR, EN UN COUP D'ŒIL
Ta séance, tes calories actives, tes pas — trois objectifs simples à boucler chaque jour, synchronisés avec Apple Santé.

SUIVI DE COURSE EN DIRECT
Carte et tracé en temps réel, allure, fréquence cardiaque, calories. Chaque sortie part dans Apple Santé, s'exporte en GPX, et se partage en carte visuelle avec ton tracé.

APPLE WATCH
Lance ta course depuis ta montre, sans emporter ton iPhone : fréquence cardiaque au poignet, distance et calories en direct. Ta séance du jour est poussée sur la montre, et chaque course terminée au poignet revient sur le téléphone avec son bilan et son adaptation de programme.

WIDGETS ET ÉCRAN VERROUILLÉ
Un widget sur l'écran d'accueil pour tes objectifs du jour et ta série en cours. Pendant une course, l'activité en direct s'affiche sur l'écran verrouillé et dans la Dynamic Island.

STATS QUI COMPTENT VRAIMENT
Tendance d'allure, records personnels, prédictions de temps sur 5 km, 10 km, semi et marathon, charge d'entraînement sur 8 semaines, carte de tous tes parcours, et suivi d'usure de tes chaussures.

OÙ COURIR QUAND TU NE CONNAIS PAS L'ENDROIT
Tu débarques dans une ville et tu ne sais pas où aller courir ? La carte montre les itinéraires publiés par d'autres coureurs autour de toi, avec leur distance, leur dénivelé et souvent une photo du coin. Filtre par longueur, garde ceux qui te tentent, ouvre le départ dans Plans. Tes propres sorties se partagent en deux gestes — et les 300 premiers et derniers mètres sont retirés avant l'envoi : personne ne verra d'où tu es partie ni où tu es rentrée.

CLUB & COMMUNAUTÉ
Classement de la semaine et classement général, défis de club, sorties de groupe, fil d'activité et badges. Et si tu préfères suivre quelques personnes plutôt qu'un club entier, un fil d'amis fait exactement ça.

FIN DE PROGRAMME, PAS FIN DE L'HISTOIRE
À la fin de ton programme : récupération encadrée, puis nouvel objectif ou mode course libre sans plan fixe.

Nécessite iOS 17 ou version ultérieure. La connexion à Apple Santé est optionnelle mais recommandée pour une forme du jour plus précise. Le Club demande un compte ; tout le reste de l'app fonctionne sans.
```

## Mots-clés (100 caractères max, séparés par des virgules sans espace)
```
running,entrainement,fractionné,cardio,marathon,semi,10km,trail,vma,jogging,footing,allure,parcours
```

Aucun de ces mots n'apparaît dans le nom ni dans le sous-titre : Apple indexe déjà tous les mots du
titre et du sous-titre, et les répéter ici ne fait que consommer des caractères sans ajouter une
seule requête. C'est ce que faisait l'ancienne liste — `course`, `coach` et `coureuse` (même racine
que `course`) y étaient tous déjà couverts par « RUNUP : Coach de Course » / « Ton coach personnel
de course ». Les 33 caractères récupérés servent maintenant à des termes réellement nouveaux
(`trail`, `jogging`, `footing`, `allure`, `parcours`). Séparateur : virgule seule, sans espace — un espace
après la virgule compte dans les 100 caractères et n'apporte rien.

---

# 🇬🇧 English

## App name (30 characters max)
```
RUNUP: Running Coach
```

## Subtitle (30 characters max)
```
A plan that adapts to you
```

## Promotional text (170 characters max)
```
A plan that rewrites itself after every run, a real coach who knows your history, and today's goals at a glance. Run like you have a coach.
```

## Description (4000 characters max)
```
RUNUP builds your running plan around your goal, reshapes it after every run based on how you actually felt, and pushes you exactly as much as it should — never more, never less.

A REAL COACH, NOT A CHATBOT
A personal coach who knows your goal, your history and how today is going. Ask a question before a session, get nutrition advice, or talk it through after a run that hurt. Mid-run you can even talk to it: press, ask out loud, hear the answer in your headphones.

A PLAN THAT LIVES WITH YOU
After every run, rate how hard it felt (RPE) — the plan adjusts the difficulty of the weeks ahead. Base, specific, taper: a genuinely periodised plan built around your race date, 4 to 20 weeks depending on how long you have. With no race date (getting faster, losing weight, easing back in, staying fit), it runs continuously with built-in cutback weeks. Short night, or yesterday's session too brutal? Today's session eases off on its own.

TODAY'S GOALS, AT A GLANCE
Your session, your active calories, your steps — three simple goals to close each day, synced with Apple Health.

LIVE RUN TRACKING
Real-time map and route, pace, heart rate, calories. Every run is saved to Apple Health, exports as GPX, and shares as a card with your route on it.

APPLE WATCH
Start a run from your watch and leave your iPhone at home: wrist heart rate, live distance and calories. Today's session is pushed to the watch, and every run you finish on your wrist comes back to the phone with its debrief and its plan adjustment.

WIDGETS AND LOCK SCREEN
A Home Screen widget for today's goals and your current streak. During a run, the live activity shows up on the Lock Screen and in the Dynamic Island.

STATS THAT ACTUALLY MEAN SOMETHING
Pace trend, personal records, finish-time predictions for 5K, 10K, half and marathon, eight weeks of training load, a map of every route you've run, and shoe mileage tracking.

WHERE TO RUN WHEN YOU DON'T KNOW THE PLACE
New city, no idea where to run? The map shows routes published by other runners around you, with distance, elevation and often a photo of the spot. Filter by length, keep the ones you like, open the start in Maps. Sharing your own runs takes two taps — and the first and last 300 metres are stripped before anything is sent, so nobody sees where you set off from or came home to.

CLUB & COMMUNITY
Weekly and all-time leaderboards, club challenges, group runs, an activity feed and badges. And if you'd rather follow a handful of people than a whole club, a friends feed does exactly that.

THE END OF A PLAN ISN'T THE END
When your plan finishes: a guided recovery block, then a new goal or free-run mode with no fixed plan at all.

Requires iOS 17 or later. Connecting Apple Health is optional but recommended for a more accurate daily readiness score. The Club needs an account; everything else works without one.
```

## Keywords (100 characters max, comma-separated, no spaces)
```
run,5k,10k,half,marathon,pace,tracker,gps,interval,cardio,jog,fitness,workout,routes,race,training
```

None of these repeats a word from the name or subtitle — Apple already indexes every word in both,
so repeating them here spends characters and buys nothing.

---

# 🇪🇸 Español

## Nombre de la app (30 caracteres máx.)
```
RUNUP: Entrenador Running
```

## Subtítulo (30 caracteres máx.)
```
Un plan que se adapta a ti
```

## Texto promocional (170 caracteres máx.)
```
Un plan que se reescribe después de cada salida, un entrenador de verdad que te conoce y tus objetivos del día de un vistazo. Corre como si tuvieras entrenador.
```

## Descripción (4000 caracteres máx.)
```
RUNUP construye tu plan a partir de tu objetivo, lo reajusta después de cada salida según cómo te sentiste de verdad, y te exige justo lo que toca — ni más, ni menos.

UN ENTRENADOR DE VERDAD, NO UN CHATBOT
Un entrenador personal que conoce tu objetivo, tu historial y cómo llevas el día. Pregúntale antes de la sesión, pídele consejo de nutrición, o desahógate después de una salida dura. Mientras corres puedes incluso hablarle: pulsas, preguntas en voz alta y te responde en los auriculares.

UN PLAN QUE VIVE CONTIGO
Después de cada salida, valora lo dura que te resultó (RPE) — el plan ajusta la dificultad de las semanas siguientes. Base, específico, puesta a punto: un plan realmente periodizado alrededor de la fecha de tu carrera, de 4 a 20 semanas según el tiempo que te quede. Sin fecha de carrera (progresar, perder peso, volver poco a poco, mantenerte en forma), sigue de forma continua con sus semanas de descarga. ¿Mala noche, o sesión de ayer demasiado dura? La sesión de hoy se aligera sola.

TUS OBJETIVOS DEL DÍA, DE UN VISTAZO
Tu sesión, tus calorías activas, tus pasos — tres objetivos sencillos que cerrar cada día, sincronizados con Apple Salud.

SEGUIMIENTO EN DIRECTO
Mapa y recorrido en tiempo real, ritmo, frecuencia cardíaca y calorías. Cada salida se guarda en Apple Salud, se exporta en GPX y se comparte como tarjeta con tu recorrido.

APPLE WATCH
Empieza a correr desde el reloj y deja el iPhone en casa: frecuencia cardíaca en la muñeca, distancia y calorías en directo. Tu sesión del día se envía al reloj, y cada carrera que termines en la muñeca vuelve al teléfono con su balance y su ajuste de plan.

WIDGETS Y PANTALLA BLOQUEADA
Un widget en la pantalla de inicio con tus objetivos del día y tu racha. Mientras corres, la actividad en directo aparece en la pantalla bloqueada y en la Dynamic Island.

ESTADÍSTICAS QUE SIRVEN PARA ALGO
Tendencia de ritmo, récords personales, predicciones de tiempo en 5 km, 10 km, media y maratón, ocho semanas de carga de entrenamiento, un mapa con todos tus recorridos y control del desgaste de tus zapatillas.

DÓNDE CORRER CUANDO NO CONOCES EL SITIO
¿Llegas a una ciudad nueva y no sabes por dónde correr? El mapa muestra las rutas publicadas por otros corredores a tu alrededor, con su distancia, su desnivel y muchas veces una foto del lugar. Filtra por longitud, guarda las que te apetezcan, abre el inicio en Mapas. Compartir tus propias salidas son dos toques — y los primeros y últimos 300 metros se recortan antes de enviar nada: nadie verá de dónde saliste ni dónde volviste.

CLUB Y COMUNIDAD
Clasificación semanal y general, retos de club, quedadas para correr, muro de actividad e insignias. Y si prefieres seguir a unas pocas personas en vez de a un club entero, hay un muro de amigos que hace justo eso.

QUE ACABE EL PLAN NO ES EL FINAL
Al terminar tu plan: un bloque de recuperación guiado y, después, un nuevo objetivo o modo carrera libre sin plan fijo.

Requiere iOS 17 o posterior. Conectar Apple Salud es opcional, pero recomendable para una forma del día más precisa. El Club necesita una cuenta; todo lo demás funciona sin ella.
```

## Palabras clave (100 caracteres máx., separadas por comas sin espacios)
```
correr,maraton,10k,media,ritmo,entrenamiento,cardio,gps,series,fondo,trote,rutas,carrera,fitness
```

Ninguna repite una palabra del nombre ni del subtítulo: Apple ya indexa todas las palabras de
ambos, así que repetirlas aquí gasta caracteres sin aportar ninguna búsqueda nueva.

---

# Captures d'écran

> **Pourquoi cette section existe.** Ce fichier soignait le nom, le sous-titre, le texte
> promotionnel et 4 000 caractères de description dans trois langues — et ne disait rien des
> captures. Or Apple affiche les trois premières captures directement sur la carte de résultat de
> recherche, et les mesures publiées du secteur convergent : **la première capture décide de 60 à
> 80 % de l'installation**, seuls ~17 % des visiteurs font défiler au-delà d'elle, et la durée
> moyenne passée sur une fiche est de sept secondes. Un jeu de captures construit relève la
> conversion de 20 à 35 % ; les traduire dans la langue du visiteur en ajoute ~26 %. Autrement dit,
> tout ce qui précède dans ce fichier pèse moins que ces six images.

## Format

Une seule série à fournir : **iPhone 6,9″, 1320 × 2868 px, portrait**. Depuis 2026 Apple ne
réclame plus que la plus grande taille de chaque famille et redimensionne lui-même pour les
appareils plus petits. Pas d'iPad ici (l'app ne cible pas l'iPad), pas de 6,5″.

Les trois localisations ont chacune leur série : une capture en français sur une fiche
hispanophone annule le bénéfice de la traduction.

## Règles de composition

1. **Le texte est incrusté dans l'image**, au-dessus de l'appareil, en gros. Une capture brute
   d'écran d'app est illisible à la taille où elle est vue. La phrase doit se lire à 250 px de
   large — c'est le seul test qui compte, et il se fait en réduisant l'image avant de la déposer.
2. **Thème sombre** pour les six. C'est le registre premium du secteur, et une image sombre se
   détache dans une fiche App Store qui est, elle, blanche.
3. **Une promesse par capture**, jamais deux.
4. **Rien qui ne soit dans l'app.** Même règle que pour la description (Guideline 2.3) : une
   capture montrant une fonctionnalité absente est un motif de rejet.
5. **La preuve sociale sur la capture n°1 dès qu'elle existe** — note moyenne, nombre d'avis ou
   citation presse. C'est l'ajout unique le plus rentable documenté sur ce format ; tant que l'app
   n'a pas d'avis, laisser la place vide plutôt que d'inventer.

## Les six images

| # | Écran à capturer | Ce qu'elle doit montrer |
|---|---|---|
| 1 | Accueil | Les anneaux du jour, la séance du jour, le bandeau de programme. C'est l'image qui doit dire « app de course sérieuse » en une seconde. |
| 2 | Coach | Un vrai échange, avec une question précise et une réponse qui montre que le coach connaît l'objectif. C'est ce qu'aucun concurrent direct n'a. |
| 3 | Course en direct | Carte avec tracé, allure, fréquence cardiaque. La preuve que l'app fait le travail pendant l'effort. |
| 4 | Club / Amis | Classement, fil d'activité, une sortie de groupe. À refaire une fois le club rempli — un classement à un membre dessert le propos. |
| 5 | Stats | La bande de volume et la courbe de progression, sur un compte réellement fourni. |
| 6 | Apple Watch + widget | La montre au poignet et le widget d'écran d'accueil, côte à côte. |

## Phrases incrustées

| # | 🇫🇷 Français | 🇬🇧 English | 🇪🇸 Español |
|---|---|---|---|
| 1 | Un plan qui s'adapte à toi | A plan that adapts to you | Un plan que se adapta a ti |
| 2 | Un vrai coach, pas un chatbot | A real coach, not a chatbot | Un coach de verdad, no un chatbot |
| 3 | Chaque sortie, en direct | Every run, live | Cada salida, en directo |
| 4 | Ne cours plus seul | Never run alone | Nunca corras solo |
| 5 | Ta progression, en clair | Your progress, clearly | Tu progreso, con claridad |
| 6 | Aussi à ton poignet | On your wrist too | También en tu muñeca |

## Ordre de production

Les captures 1 à 3 et 6 sont réalisables tout de suite sur un compte de démonstration bien
rempli. Les 4 et 5 demandent des données réelles — un club avec plusieurs membres, un historique
de plusieurs semaines — et valent d'attendre plutôt que d'être montées avec un classement à une
ligne et une courbe plate. En attendant, une série de quatre vaut mieux qu'une série de six dont
deux desservent.

---

# Sections communes (à saisir une seule fois)

## Catégorie
- Principale : **Santé et forme physique** (Health & Fitness)
- Secondaire : **Sport**

## Classification d'âge
Aucun contenu sensible (pas de violence, contenu adulte, jeu d'argent...) → typiquement **4+**. À confirmer via le questionnaire App Store Connect.

Répondre **oui** au contenu généré par les utilisateurs : noms de clubs, messages du fil, photos de
profil, et désormais les itinéraires publiés — leur nom, leurs notes libres, leur photo. La
Guideline 1.2 exige alors quatre choses, toutes présentes, à savoir citer si la revue les demande :
un filtre sur le contenu publié (`lib/moderation.js`, appliqué aux noms et aux notes d'itinéraire),
un signalement dans l'app (`api/moderation/[action].js` accepte `route` comme cible, au même titre
que `user`, `club`, `activity` et `comment`), un blocage entre utilisatrices (`lib/social.js`,
`isBlockedEitherWay`, qui masque les itinéraires dans les deux sens), et un contact — l'URL de
support ci-dessous.

## Confidentialité (App Privacy)

Cinq familles de données à déclarer. Une déclaration incomplète est un motif de rejet au même titre
qu'une description inexacte, et la moitié de ce qui suit n'existait pas avant les itinéraires
partagés.

**Localisation — précise, liée à l'utilisatrice.** Publier un itinéraire envoie un tracé GPS
(`routes.points`, `start_lat`, `start_lng`, `locality`) rattaché au compte et **visible
publiquement**. Les 300 premiers et derniers mètres sont retirés sur l'appareil avant l'envoi
(`RouteGeometry.trimmedForSharing`) : ça protège le domicile, mais ça ne change rien à la
déclaration — c'est bien de la localisation précise, collectée et liée. Usage : **App
Functionality**. À noter pour la revue : rien ne part tant qu'aucun itinéraire n'est publié, le
suivi de course seul reste sur l'appareil et dans Apple Santé.

**Contenu utilisateur — photos, lié à l'utilisatrice.** La photo de profil (`users.avatar_url`) et
la photo facultative d'un itinéraire (`routes.photo_url`), toutes deux stockées dans Vercel Blob et
lisibles par leur URL. Usage : **App Functionality**.

**Santé et forme physique — lié à l'utilisatrice.** Le fil du Club et les classements conservent la
distance et le libellé de chaque sortie (`activities.distance_km`, `activities.text`), ainsi que la
distance, le dénivelé et la durée de chaque itinéraire publié. En revanche, ce qui est lu dans
Apple Santé ne quitte jamais l'appareil. Usage : **App Functionality**.

**Coordonnées et identifiants — liés à l'utilisatrice.** Un compte Club stocke un nom et une adresse
e-mail, ou l'identifiant opaque de Sign in with Apple (`users.name`, `users.email`,
`users.apple_sub`). Usage : **App Functionality**.

**Analytique.** Événements d'usage first-party (voir `api/events.js` et
`RunUp/Services/Analytics.swift`) : **Analytics / Product Interaction**, en **"Data Not Linked to
You"** pour les événements pré-inscription (identifiant anonyme uniquement) et **"Data Linked to
You"** dès qu'un compte Club existe.

**Tracking : non.** Aucun SDK tiers, aucun IDFA, aucun partage avec un courtier de données — donc
pas d'App Tracking Transparency à afficher.

Tout ce qui précède disparaît à la suppression du compte : `routes` et `route_saves` sont en
`ON DELETE CASCADE` sur `users`, ce que `api/account/[action].js` promet explicitement.

## URLs requises
- **URL de support** : `mailto:charlottegrudep@gmail.com`
- **URL de politique de confidentialité** : `https://hicsuntco.github.io/RUNUP/privacy.html`
- **URL marketing** (optionnelle) : —

## Copyright
```
© 2026 Charlotte Grudé
```
