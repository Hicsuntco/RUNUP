# Fiche App Store — RUNUP

Contenu prêt à copier-coller dans App Store Connect (App Information / Fiche de l'app).

L'app est livrée avec trois localisations réelles (`CFBundleLocalizations: fr, en, es` dans
project.yml, adossées à 1 119 clés traduites dans `RunUp/Resources/Localizable.xcstrings`) — la fiche
doit donc exister dans les trois, sinon App Store Connect n'expose l'app qu'en français et les
recherches anglophones/hispanophones ne la trouvent jamais. Chaque locale a sa propre section
ci-dessous ; les sections communes (catégorie, âge, URLs, copyright) ne se saisissent qu'une fois.

> **Abonnement** : les trois descriptions se terminent par le bloc que la revue exige pour un
> abonnement à renouvellement automatique — titre, durée, prix, conditions de renouvellement, et
> les deux liens. Ce n'est pas de la prose, c'est la guideline 3.1.2 : un de ces éléments manquant
> est un rejet, pas une remarque. Les prix y sont écrits en dur, donc ils doivent être remis à jour
> ici le jour où ils changent dans App Store Connect.

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
Plan sur mesure et suivi GPS
```

Les trente caractères précédents — « Ton coach personnel de course » — n'achetaient qu'un seul mot
nouveau. Apple indexe le nom, le sous-titre et les mots-clés comme un seul sac : « coach » et
« course » étaient déjà dans le nom, et il ne restait que « personnel », que personne ne tape. Les
cinq mots ci-dessus sont tous absents du nom ET des mots-clés, et ils annoncent les deux moitiés du
produit — celle qui se paye et celle qui ne se paye pas.

Volontairement pas le mot « gratuit » ici : la 2.3.7 interdit l'information de prix dans les
métadonnées de titre, et il n'y a aucune raison de risquer un rejet pour un mot qui a toute sa
place dans le texte promotionnel et dans la description, où il sera lu de toute façon.

## Texte promotionnel (170 caractères max — modifiable à tout moment sans nouvelle review)
```
Enregistre tes courses, rejoins le Club, garde tes stats — gratuitement, sans limite de temps. Et essaie ton programme sur mesure et ton coach pendant 7 jours.
```

## Description (4000 caractères max)
```
Enregistre tes courses, retrouve tes amis, suis tes progrès — gratuitement, sans limite de temps. Et quand tu veux un vrai programme, RUNUP le construit sur mesure et l'ajuste après chaque sortie selon ta forme et ton ressenti.

GRATUIT, POUR TOUJOURS
Le suivi GPS de tes courses : distance, allure, tracé, dénivelé, fréquence cardiaque. Ton historique complet et tes statistiques. Tes trois objectifs du jour et ta série. Ton bilan de la semaine. Apple Santé, l'Apple Watch, les widgets et l'écran verrouillé. Et tout le Club : classements, défis, fil d'activité, amis, itinéraires partagés. Sans compte à rebours et sans publicité.

RUNUP PLUS — 7 JOURS OFFERTS
Le programme périodisé et son adaptation, le coach écrit et vocal, la préparation d'une date de course, tes temps prévus et ta charge d'entraînement.

UN VRAI COACH, PAS UN CHATBOT — RUNUP PLUS
Un vrai coach personnel qui connaît ton objectif, ton historique et ta forme du jour. Pose-lui une question avant ta séance, demande un conseil nutrition, ou fais-toi rassurer après une sortie difficile. Pendant l'effort, tu peux même lui parler : tu appuies, tu poses ta question à voix haute, il te répond dans les écouteurs.

UN PROGRAMME QUI VIT AVEC TOI — RUNUP PLUS
Après chaque course, donne ton ressenti (RPE) — le programme ajuste la difficulté des semaines suivantes. Base, spécifique, affûtage : un vrai plan périodisé calé sur la date de ta course, de 4 à 20 semaines selon le temps qu'il te reste. Sans date de course (progresser, perdre du poids, reprendre en douceur, rester en forme), il tourne en continu avec ses semaines de décharge. Nuit trop courte ou séance de la veille trop dure ? La séance du jour s'allège d'elle-même.

SUIVI DE COURSE EN DIRECT
Carte et tracé en temps réel, allure, fréquence cardiaque, calories. Chaque sortie part dans Apple Santé, s'exporte en GPX, et se partage en carte visuelle avec ton tracé.

APPLE WATCH
Lance ta course depuis ta montre, sans emporter ton iPhone : fréquence cardiaque au poignet, distance et calories en direct. Chaque course terminée au poignet revient sur le téléphone avec son bilan. Avec RUNUP Plus, ta séance du jour est poussée sur la montre.

STATS QUI COMPTENT VRAIMENT
Tendance d'allure, records personnels, carte de tes parcours, usure des chaussures. Avec RUNUP Plus : prédictions sur 5 km, 10 km, semi et marathon, et charge d'entraînement sur 8 semaines.

OÙ COURIR QUAND TU NE CONNAIS PAS L'ENDROIT
Tu débarques dans une ville et tu ne sais pas où courir ? La carte montre les itinéraires publiés autour de toi, avec distance, dénivelé et souvent une photo. Tes propres sorties se partagent en deux gestes — et les 300 premiers et derniers mètres sont retirés avant l'envoi : personne ne verra d'où tu es partie ni où tu es rentrée.

CLUB & COMMUNAUTÉ
Classement de la semaine et classement général, défis de club, sorties de groupe, fil d'activité et badges. Et si tu préfères suivre quelques personnes plutôt qu'un club entier, un fil d'amis fait exactement ça.

FIN DE PROGRAMME, PAS FIN DE L'HISTOIRE — RUNUP PLUS
À la fin de ton programme : récupération encadrée, puis nouvel objectif ou mode course libre sans plan fixe.

Nécessite iOS 17 ou version ultérieure. La connexion à Apple Santé est optionnelle, mais affine la forme du jour. Le Club demande un compte ; tout le reste de l'app fonctionne sans.

ABONNEMENT RUNUP PLUS
RUNUP fonctionne sans abonnement, sans limite de temps. RUNUP Plus débloque le programme et le coach, après 7 jours d'essai gratuit.
• Mensuel — 6,99 € par mois
• Annuel — 39,99 € par an (soit 3,33 € par mois)
Renouvellement automatique, résiliable à tout moment depuis les réglages de ton compte Apple.
Conditions d'utilisation : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Politique de confidentialité : https://hicsuntco.github.io/RUNUP/privacy.html
```

## Nouveautés de cette version (4000 caractères max — obligatoire pour une mise à jour)
```
RUNUP s'ouvre à tout le monde.

TON COACH CHANGE TON PROGRAMME, PAS SEULEMENT D'AVIS
Dis-lui qu'une tendinite revient, que tu n'as que deux créneaux cette semaine, que tu veux lever le pied dix jours : il applique. Séances raccourcies, fractionné mis en pause, jours de course déplacés. Tu vois exactement ce qu'il a changé, et tu peux l'annuler d'un geste. Avec RUNUP PLUS.

GRATUIT, POUR TOUJOURS
Le suivi GPS de tes courses, ton historique, tes statistiques, tes objectifs du jour, ta série, ton bilan de la semaine, Apple Santé, l'Apple Watch et les widgets. Et tout le Club : classements, défis, fil d'activité, amis et itinéraires partagés. Sans compte à rebours et sans publicité.

RUNUP PLUS
Le programme périodisé et son adaptation après chaque sortie, le coach écrit et vocal, la préparation d'une date de course, tes temps prévus et ta charge d'entraînement. Sept jours d'essai gratuit.

CORRECTIONS
• Le suivi GPS se mettait en pause tout seul dans les premières secondes de chaque course, et la distance restait bloquée à 0,00. L'appareil ne connaît pas encore ta vitesse pendant que la puce accroche, et l'app prenait ce « je ne sais pas » pour un arrêt.
• L'écran de course dit maintenant ce qu'il fait : recherche du signal, signal instable, ou localisation refusée — avec un accès direct aux réglages dans ce dernier cas.
• Une pause automatique prise à l'arrêt sous un immeuble ne se levait plus toute seule.
• L'anneau de construction du programme sautait au lieu de se remplir, et affichait sa coche de fin avant d'avoir fini.
• Sur la courbe d'allure, la mention « RECORD » était coupée par le tracé.
• La carte à partager s'affichait minuscule au milieu d'un grand cadre vide : l'aperçu a maintenant la forme de ce que tu partages.
• Sur le Profil, le chiffre de ta série tombait plus bas que les deux autres.
• Les semaines grises du plan disent enfin ce qu'elles sont : des semaines de décharge, où le volume baisse exprès.
• Restaurer un achat pouvait annoncer « aucun abonnement » alors que c'était le réseau qui manquait.
• Recherche d'amis depuis ton carnet d'adresses : les adresses sont transformées en empreintes sur ton iPhone, aucune n'est envoyée ni conservée.
• Une séance déjà faite s'ajoute depuis l'accueil, avec sa vraie distance et sa vraie durée.
• Le suivi du cycle menstruel se réancre quand les règles arrivent en avance ou en retard.
```

## Mots-clés (100 caractères max, séparés par des virgules sans espace)
```
running,entrainement,fractionné,gratuit,marathon,semi,10km,trail,jogging,footing,allure,debutant
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
Custom plan, stats and club
```

## Promotional text (170 characters max)
```
Track your runs, join the Club, keep your stats — free, with no time limit. Then try your custom plan and your coach for 7 days.
```

## Description (4000 characters max)
```
Track your runs, find your friends, follow your progress — free, with no time limit. And when you want a real plan, RUNUP builds it around your goal and reshapes it after every run based on how you actually felt.

FREE, FOREVER
GPS tracking for every run: distance, pace, route, elevation, heart rate. Your full history and your stats. Today's three goals and your streak. Your weekly recap. Apple Health, Apple Watch, widgets and the Lock Screen. And the whole Club: leaderboards, challenges, activity feed, friends, shared routes. No countdown, no ads.

RUNUP PLUS — 7 DAYS FREE
The periodised plan and its adaptation, the coach by text and by voice, race-day preparation, your predicted times and your training load.

A REAL COACH, NOT A CHATBOT — RUNUP PLUS
A personal coach who knows your goal, your history and how today is going. Ask a question before a session, get nutrition advice, or talk it through after a run that hurt. Mid-run you can even talk to it: press, ask out loud, hear the answer in your headphones.

A PLAN THAT LIVES WITH YOU — RUNUP PLUS
After every run, rate how hard it felt (RPE) — the plan adjusts the difficulty of the weeks ahead. Base, specific, taper: a genuinely periodised plan built around your race date, 4 to 20 weeks depending on how long you have. With no race date (getting faster, losing weight, easing back in, staying fit), it runs continuously with built-in cutback weeks. Short night, or yesterday's session too brutal? Today's session eases off on its own.

LIVE RUN TRACKING
Real-time map and route, pace, heart rate, calories. Every run is saved to Apple Health, exports as GPX, and shares as a card with your route on it.

APPLE WATCH
Start a run from your watch and leave your iPhone at home: wrist heart rate, live distance and calories. Every run you finish on your wrist comes back to the phone with its debrief. With RUNUP Plus, today's session is pushed to the watch.

STATS THAT ACTUALLY MEAN SOMETHING
Pace trend, personal records, a map of every route you've run, and shoe mileage tracking. With RUNUP Plus: finish-time predictions for 5K, 10K, half and marathon, and eight weeks of training load.

WHERE TO RUN WHEN YOU DON'T KNOW THE PLACE
New city, no idea where to run? The map shows routes published by other runners around you, with distance, elevation and often a photo of the spot. Filter by length, keep the ones you like, open the start in Maps. Sharing your own runs takes two taps — and the first and last 300 metres are stripped before anything is sent, so nobody sees where you set off from or came home to.

CLUB & COMMUNITY
Weekly and all-time leaderboards, club challenges, group runs, an activity feed and badges. And if you'd rather follow a handful of people than a whole club, a friends feed does exactly that.

THE END OF A PLAN ISN'T THE END — RUNUP PLUS
When your plan finishes: a guided recovery block, then a new goal or free-run mode with no fixed plan at all.

Requires iOS 17 or later. Connecting Apple Health is optional but recommended for a more accurate daily readiness score. The Club needs an account; everything else works without one.

RUNUP PLUS SUBSCRIPTION
RUNUP works without a subscription, with no time limit. RUNUP Plus unlocks the plan and the coach, after a 7-day free trial.
• Monthly — €6.99 per month
• Yearly — €39.99 per year (€3.33 per month)
Auto-renewing, cancellable at any time from your Apple account settings.
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://hicsuntco.github.io/RUNUP/privacy.html
```

## What's New in This Version (4000 characters max — required for an update)
```
RUNUP is now open to everyone.

YOUR COACH NOW CHANGES THE PLAN ITSELF
Say a niggle is back, that you only have two slots this week, that you want to ease off for ten days — and it is applied. Shorter sessions, speed work paused, running days moved. You see exactly what changed, and one tap undoes it. With RUNUP PLUS.

FREE, FOREVER
GPS run tracking, your full history, your stats, today's goals, your streak, your weekly recap, Apple Health, Apple Watch and widgets. Plus the whole Club: leaderboards, challenges, activity feed, friends and shared routes. No countdown, no ads.

RUNUP PLUS
The periodised plan and its adaptation after every run, the coach by text and by voice, race-day preparation, your predicted times and your training load. Seven-day free trial.

FIXES
• GPS tracking paused itself within the first seconds of every run and distance stayed at 0.00. The device does not know your speed yet while the chip acquires a fix, and the app read that "don't know" as a stop.
• The run screen now says what it is doing: acquiring signal, unstable signal, or location denied — with a direct route to Settings in that last case.
• An auto-pause taken at a standstill under a building would never lift on its own.
• The plan-building ring jumped instead of filling, and showed its completion tick before finishing.
• On the pace trend, the "RECORD" label was cut through by the curve.
• The share card showed up tiny inside a big empty frame; the preview is now shaped like the thing you share.
• On the Profile, your streak number sat lower than the two beside it.
• The grey weeks in the plan finally say what they are: recovery weeks, where the volume drops on purpose.
• Restoring a purchase could report "no subscription" when the network was the thing that was missing.
• Find friends from your address book: e-mail addresses are turned into fingerprints on your iPhone; none is ever sent or stored.
• Log an already-completed session from the home screen, with its real distance and duration.
• Menstrual cycle tracking re-anchors when your period arrives early or late.
```

## Keywords (100 characters max, comma-separated, no spaces)
```
run,5k,10k,half,marathon,pace,tracker,gps,interval,free,jog,fitness,beginner,routes,race,training
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
Plan a medida, stats y club
```

## Texto promocional (170 caracteres máx.)
```
Registra tus carreras, únete al Club y guarda tus estadísticas: gratis y sin límite de tiempo. Y prueba tu plan a medida y tu entrenador 7 días.
```

## Descripción (4000 caracteres máx.)
```
Registra tus carreras, encuentra a tus amigos, sigue tu progreso: gratis y sin límite de tiempo. Y cuando quieras un plan de verdad, RUNUP lo construye a partir de tu objetivo y lo reajusta después de cada salida según cómo te sentiste.

GRATIS, PARA SIEMPRE
El seguimiento GPS de cada carrera: distancia, ritmo, recorrido, desnivel y frecuencia cardiaca. Tu historial completo y tus estadísticas. Tus tres objetivos del día y tu racha. Tu resumen semanal. Apple Salud, Apple Watch, widgets y pantalla bloqueada. Y todo el Club: clasificaciones, retos, muro de actividad, amigos y rutas compartidas. Sin cuenta atrás y sin publicidad.

RUNUP PLUS — 7 DÍAS GRATIS
El plan periodizado y su adaptación, el entrenador por escrito y por voz, la preparación de una carrera, tus tiempos previstos y tu carga de entrenamiento.

UN ENTRENADOR DE VERDAD, NO UN CHATBOT — RUNUP PLUS
Un entrenador personal que conoce tu objetivo, tu historial y cómo llevas el día. Pregúntale antes de la sesión, pídele consejo de nutrición, o desahógate después de una salida dura. Mientras corres puedes incluso hablarle: pulsas, preguntas en voz alta y te responde en los auriculares.

UN PLAN QUE VIVE CONTIGO — RUNUP PLUS
Después de cada salida, valora lo dura que te resultó (RPE) — el plan ajusta la dificultad de las semanas siguientes. Base, específico, puesta a punto: un plan realmente periodizado alrededor de la fecha de tu carrera, de 4 a 20 semanas según el tiempo que te quede. Sin fecha de carrera (progresar, perder peso, volver poco a poco, mantenerte en forma), sigue de forma continua con sus semanas de descarga. ¿Mala noche, o sesión de ayer demasiado dura? La sesión de hoy se aligera sola.

SEGUIMIENTO EN DIRECTO
Mapa y recorrido en tiempo real, ritmo, frecuencia cardíaca y calorías. Cada salida se guarda en Apple Salud, se exporta en GPX y se comparte como tarjeta con tu recorrido.

APPLE WATCH
Empieza a correr desde el reloj y deja el iPhone en casa: frecuencia cardíaca en la muñeca, distancia y calorías en directo. Cada carrera que termines en la muñeca vuelve al teléfono con su balance. Con RUNUP Plus, tu sesión del día se envía al reloj.

ESTADÍSTICAS QUE SIRVEN PARA ALGO
Tendencia de ritmo, récords personales, un mapa con todos tus recorridos y control del desgaste de tus zapatillas. Con RUNUP Plus: predicciones de tiempo en 5 km, 10 km, media y maratón, y ocho semanas de carga de entrenamiento.

DÓNDE CORRER CUANDO NO CONOCES EL SITIO
¿Llegas a una ciudad nueva y no sabes por dónde correr? El mapa muestra las rutas publicadas por otros corredores a tu alrededor, con su distancia, su desnivel y muchas veces una foto del lugar. Filtra por longitud, guarda las que te apetezcan, abre el inicio en Mapas. Compartir tus propias salidas son dos toques — y los primeros y últimos 300 metros se recortan antes de enviar nada: nadie verá de dónde saliste ni dónde volviste.

CLUB Y COMUNIDAD
Clasificación semanal y general, retos de club, quedadas, muro de actividad e insignias. Y si prefieres seguir a unas pocas personas en vez de a un club entero, hay un muro de amigos.

QUE ACABE EL PLAN NO ES EL FINAL — RUNUP PLUS
Al terminar tu plan: un bloque de recuperación guiado y, después, un nuevo objetivo o modo carrera libre sin plan fijo.

Requiere iOS 17 o posterior. Conectar Apple Salud es opcional, pero afina la forma del día. El Club necesita una cuenta; todo lo demás funciona sin ella.

SUSCRIPCIÓN RUNUP PLUS
RUNUP funciona sin suscripción y sin límite de tiempo. RUNUP Plus desbloquea el plan y el entrenador, tras 7 días de prueba gratis.
• Mensual — 6,99 € al mes
• Anual — 39,99 € al año (3,33 € al mes)
Renovación automática, cancelable cuando quieras desde los ajustes de tu cuenta de Apple.
Términos de uso: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Política de privacidad: https://hicsuntco.github.io/RUNUP/privacy.html
```

## Novedades de esta versión (4000 caracteres máx. — obligatorio para una actualización)
```
RUNUP se abre a todo el mundo.

TU ENTRENADOR YA CAMBIA EL PLAN, NO SOLO DE OPINIÓN
Dile que te vuelve una molestia, que esta semana solo tienes dos huecos, que quieres bajar el ritmo diez días: lo aplica. Sesiones más cortas, series en pausa, días de carrera cambiados. Ves exactamente qué ha cambiado y puedes deshacerlo con un toque. Con RUNUP PLUS.

GRATIS, PARA SIEMPRE
El seguimiento GPS de tus carreras, tu historial, tus estadísticas, tus objetivos del día, tu racha, tu resumen semanal, Apple Salud, el Apple Watch y los widgets. Y todo el Club: clasificaciones, retos, muro de actividad, amigos y rutas compartidas. Sin cuenta atrás y sin publicidad.

RUNUP PLUS
El plan periodizado y su adaptación tras cada salida, el entrenador por escrito y por voz, la preparación de una carrera, tus tiempos previstos y tu carga de entrenamiento. Siete días de prueba gratis.

CORRECCIONES
• El seguimiento GPS se pausaba solo en los primeros segundos de cada carrera y la distancia se quedaba en 0,00. El dispositivo aún no conoce tu velocidad mientras el chip fija la señal, y la app tomaba ese «no lo sé» por una parada.
• La pantalla de carrera ahora dice qué hace: buscando señal, señal inestable o ubicación denegada, con acceso directo a los Ajustes en este último caso.
• Una pausa automática tomada al detenerse bajo un edificio ya no se levantaba sola.
• El anillo de construcción del plan saltaba en vez de llenarse, y mostraba su marca de fin antes de terminar.
• En la curva de ritmo, la palabra «RECORD» quedaba cortada por el trazo.
• La tarjeta para compartir salía diminuta dentro de un marco vacío; ahora la vista previa tiene la forma de lo que compartes.
• En el Perfil, el número de tu racha quedaba más bajo que los otros dos.
• Las semanas grises del plan dicen por fin lo que son: semanas de descarga, donde el volumen baja a propósito.
• Restaurar una compra podía anunciar «sin suscripción» cuando lo que faltaba era la red.
• Buscar amigos desde tu agenda: las direcciones se convierten en huellas en tu iPhone; ninguna se envía ni se guarda.
• Añade una sesión ya hecha desde el inicio, con su distancia y duración reales.
• El seguimiento del ciclo menstrual se reajusta cuando la regla llega antes o después.
```

## Palabras clave (100 caracteres máx., separadas por comas sin espacios)
```
correr,maraton,10k,media,ritmo,entrenamiento,gratis,gps,series,principiante,trote,rutas,carrera
```

Ninguna repite una palabra del nombre ni del subtítulo: Apple ya indexa todas las palabras de
ambos, así que repetirlas aquí gasta caracteres sin aportar ninguna búsqueda nueva.

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

**Contacts — liés à l'utilisatrice.** « Trouver mes contacts sur RUNUP » lit les adresses e-mail du
carnet d'adresses, les hache **sur l'appareil** (SHA-256 de l'adresse en minuscules, sans espaces —
voir `ContactMatcher`) et n'envoie que les empreintes. Le serveur les compare à la colonne générée
`users.email_sha256`, ne reçoit aucune adresse, n'en stocke aucune et ne conserve pas les empreintes
reçues. Les numéros de téléphone ne sont jamais lus. Usage : **App Functionality**.

À déclarer malgré tout, et c'est un choix délibéré. Apple dispense de déclaration les données qui
ne servent qu'à traiter la requête en cours et ne sont pas conservées — ce qui est exactement notre
cas, et on pourrait donc ne rien déclarer. Mais la dispense se plaide, alors qu'une déclaration se
lit : sur le carnet d'adresses, qui est la donnée la plus sensible qu'une app puisse demander,
déclarer en trop n'a jamais fait rejeter personne et déclarer en moins est un motif de retrait.
Préciser en notes de revue que rien ne quitte l'appareil en clair et que rien n'est conservé.

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

## Informations pour la vérification (App Review Information)

Ce champ n'est pas localisé et n'est lu que par Apple : il est donc en anglais, la langue de
l'équipe de revue. Il n'apparaît nulle part dans la fiche publique.

Deux choses le rendent nécessaire ici plutôt que facultatif. L'app entière est derrière un essai
puis un abonnement — un vérificateur qui tombe sur le mur de paiement sans savoir quoi en faire
rejette au titre du 2.1, et c'est le rejet le plus fréquent des apps par abonnement. Et une app de
course ne se vérifie normalement qu'en allant courir, ce qu'un vérificateur ne fera pas : il faut
lui donner le chemin qui montre l'app pleine sans quitter son bureau.

```
DEMO ACCOUNT
  Sign in with e-mail (not "Sign in with Apple") using the credentials in the fields above.
  The account already has a generated training plan, a few logged runs and one club, so the
  app is populated on first launch.

FREE TIER AND SUBSCRIPTION
  Most of the app is free with no time limit and no account required beyond the Club: GPS run
  tracking, history, stats, daily goals, the weekly recap, Apple Health, Apple Watch, widgets,
  and the whole social side (leaderboards, challenges, feed, friends, shared routes).

  RUNUP Plus adds the periodised training plan and its week-to-week adaptation, the coach by
  text and by voice, race-day preparation, predicted race times and training load. A 7-day free
  trial precedes it.

  Two notes that save time:
  - Access is granted by the StoreKit entitlement of the *Apple ID* on the device, NOT by the
    RUNUP account, so the demo account above cannot have "used up" the trial for you. On your
    sandbox Apple ID the introductory offer is available and costs nothing.
  - Nothing is behind a wall you cannot get past. Locked features show what they contain and
    offer the trial; declining leaves the rest of the app fully usable. If StoreKit products
    fail to load for any reason, the app deliberately unlocks everything rather than showing a
    paywall it cannot honour.

  Path to the paid features: finish onboarding (about 6 short questions), the offer appears
  once and can be dismissed. Afterwards, opening the Coach tab or the full plan offers it again.

SEEING A RUN WITHOUT GOING FOR A RUN
  On the Home tab, next to the START button, the "+" logs an already-completed session: enter
  a distance and a duration and confirm. This fills the stats, the weekly plan, the streak and
  the club feed exactly as a real GPS run would, and needs neither location nor movement.
  Use it if you would rather not walk around with the device.

LOCATION
  Requested only when a run is started, and used only for distance, pace and the route trace.
  The background mode exists because tracking must survive the screen locking mid-run.
  Sharing a route is a separate, explicit action; when it happens the first and last 300 m of
  the trace are removed on-device before upload, so a published route cannot point at a home
  address. Nothing about a run leaves the device unless the user publishes it.

CONTACTS
  One opt-in button in the Friends screen ("find my contacts on RUNUP"). E-mail addresses are
  hashed on-device (SHA-256, lowercased and trimmed) and only the hashes are sent; the server
  compares them to a generated column of hashes, receives no address, stores none, and keeps
  no hash it was sent. Phone numbers are never read. Declining the permission leaves every
  other feature working.

HEALTH
  HealthKit is read-only (heart rate during a run, and workout history). Nothing is written
  back, and nothing read from Health ever leaves the device.

USER-GENERATED CONTENT (guideline 1.2)
  The club feed, comments and shared routes are user-generated. In the app: a blocklist filter
  runs server-side on every submission; any member can be reported or blocked from their
  profile and from the leaderboard (blocking hides content in both directions); and an account
  can be deleted from Settings → More settings → Delete my account, which cascades and removes
  the user's runs, comments, routes and club memberships.
```
