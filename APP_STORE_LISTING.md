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

HYROX, ULTRA, TRIATHLON — RUNUP PLUS
Trois préparations entières, pas des variantes du plan de course. HYROX : les huit stations et leurs transitions. Ultra : dénivelé, marche rapide, nuit. Triathlon : natation, vélo et enchaînements, du sprint à la longue distance.

SUIVI DE COURSE EN DIRECT
Carte et tracé en temps réel, allure, fréquence cardiaque, calories. Chaque sortie part dans Apple Santé, s'exporte en GPX, et se partage en carte avec ton tracé.

APPLE WATCH
Lance ta course depuis ta montre, sans emporter ton iPhone : fréquence cardiaque au poignet, distance et calories en direct. Chaque course terminée au poignet revient sur le téléphone avec son bilan. Avec RUNUP Plus, ta séance du jour est poussée sur la montre.

STATS QUI COMPTENT VRAIMENT
Tendance d'allure, records personnels, carte de tes parcours, usure des chaussures. Avec RUNUP Plus : prédictions sur 5 km, 10 km, semi et marathon, et charge d'entraînement sur 8 semaines.

OÙ COURIR QUAND TU NE CONNAIS PAS L'ENDROIT
Tu débarques dans une ville et tu ne sais pas où courir ? La carte montre les itinéraires publiés autour de toi, avec distance, dénivelé et souvent une photo. Partage les tiennes en deux gestes : les 300 premiers et derniers mètres sont retirés avant l'envoi, personne ne verra d'où tu pars ni où tu rentres.

CLUB & COMMUNAUTÉ
Classements de la semaine et général, défis de club, sorties de groupe, fil d'activité et badges. Et si tu préfères suivre quelques personnes plutôt qu'un club entier, un fil d'amis fait exactement ça.

FIN DE PROGRAMME, PAS FIN DE L'HISTOIRE — RUNUP PLUS
À la fin : récupération encadrée, puis nouvel objectif ou course libre sans plan fixe.

La connexion à Apple Santé est optionnelle, mais affine la forme du jour. Le Club demande un compte ; tout le reste de l'app fonctionne sans.

ABONNEMENT RUNUP PLUS
RUNUP fonctionne sans abonnement. RUNUP Plus débloque le programme et le coach, après 7 jours d'essai gratuit.
• Mensuel — 6,99 € par mois
• Annuel — 39,99 € par an (soit 3,33 € par mois)
Renouvellement automatique, résiliable à tout moment depuis les réglages de ton compte Apple.
Conditions d'utilisation : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Politique de confidentialité : https://hicsuntco.github.io/RUNUP/privacy.html
```

## Nouveautés de cette version (4000 caractères max — obligatoire pour une mise à jour)
```
RUNUP regarde le ciel et te dit quand sortir.

IL PLEUVRA CE SOIR — TU LE SAIS CE MATIN
Ta séance est prévue à 18 h, et la pluie arrive à 17 h. En ouvrant l'app, RUNUP a déjà comparé le matin, le midi et le soir, heure par heure, et te propose le créneau sec.

Il ne parle que quand il a quelque chose à dire. Il faut que ton créneau habituel soit franchement mauvais, qu'un autre moment de la journée soit vraiment sec, que l'écart entre les deux soit net, et qu'il te reste deux heures pour t'organiser. Une alerte par jour au maximum.

Quand il pleut toute la journée, il se tait. Tu courras sous la pluie ou pas du tout : te le dire ne changerait que ton humeur.

Ça s'éteint d'un interrupteur, « Prévenir s'il va pleuvoir », et aucune autorisation nouvelle n'est demandée. Prévisions Apple Weather.

« À FAIRE » ET « FAITE » NE PEUVENT PLUS S'AFFICHER EN MÊME TEMPS
L'accueil pouvait se contredire tout seul : le mot « Faite », un arc plein sur l'anneau, et juste en dessous une barre vide. Deux endroits répondaient à la question « la séance est-elle faite ? », et pas de la même façon. Il n'y en a plus qu'un.

Et une course arrivée d'Apple Santé, ou récupérée après un plantage, compte désormais tout de suite — sans attendre que tu aies rempli ton ressenti. L'app annonçait « À faire » pour une sortie qu'elle montrait dans ton historique.
```

## Mots-clés (100 caractères max, séparés par des virgules sans espace)
```
running,entrainement,fractionné,gratuit,marathon,semi,10km,trail,ultra,hyrox,debutant,triathlon
```

Aucun de ces mots n'apparaît dans le nom ni dans le sous-titre : Apple indexe déjà tous les mots du
titre et du sous-titre, et les répéter ici ne fait que consommer des caractères sans ajouter une
seule requête. C'est ce que faisait l'ancienne liste — `course`, `coach` et `coureuse` (même racine
que `course`) y étaient tous déjà couverts par « RUNUP : Coach de Course » / « Ton coach personnel
de course ». Les caractères récupérés servent à des termes réellement nouveaux. Séparateur : virgule
seule, sans espace — un espace après la virgule compte dans les 100 caractères et n'apporte rien.

`triathlon` a pris la place de `footing` et d'`allure`. C'était le seul des trois nouveaux plans
qu'aucune des trois listes ne portait : quelqu'un qui cherche « triathlon » ne pouvait pas tomber
sur l'app, alors que la préparation existe en entier — quatre formats, de la natation à
l'enchaînement vélo-course. `allure` seul est une requête faible, personne ne cherche « allure »
pour trouver une app, et `footing` recouvre ce que `running` et le mot « Course » du titre
attrapent déjà. En anglais c'est `routes` qui a cédé la place, en espagnol `ritmo` et `rutas` : la
carte d'itinéraires est une vraie fonctionnalité, mais pas une requête, et la description la
décrit mieux qu'un mot-clé ne la cherche.

`ultra` et `hyrox` ont pris la place de `jogging`. Apple assemble lui-même les mots-clés en
expressions, donc `ultra` + `trail` couvre « ultra trail » et « trail ultra » sans qu'il faille
écrire la paire : cinq caractères achètent une requête entière. Et ces deux termes-là désignent
maintenant quelque chose de réel dans l'app — un plan d'ultra qui compte en kilomètres-effort, un
plan HYROX avec ses stations — là où `jogging` faisait doublon avec `running` et `footing`, déjà
présents tous les deux. `hyrox` est en plus une requête à forte intention et à concurrence quasi
nulle : personne ne la cherche par hasard.

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

HYROX, ULTRA, TRIATHLON — RUNUP PLUS
Three full preparations, not variations on the running plan. HYROX: the eight stations and their transitions. Ultra: elevation, fast hiking, running at night. Triathlon: swimming, cycling and brick sessions, from sprint to long distance.

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

Connecting Apple Health is optional but recommended for a more accurate daily readiness score. The Club needs an account; everything else works without one.

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
RUNUP watches the sky and tells you when to go.

IT WILL RAIN TONIGHT — YOU KNOW THIS MORNING
Your session is set for 6pm, and the rain starts at 5. Open the app and RUNUP has already compared morning, midday and evening, hour by hour, and offers you the dry window.

It only speaks when it has something to say. Your usual slot has to be genuinely bad, another part of the day genuinely dry, the gap between them clear-cut, and you need two hours left to rearrange things. One alert a day, at most.

When it rains all day, it says nothing. You'll run in the rain or not at all: telling you would only change your mood.

One switch turns it off — "Warn me if it's going to rain" — and no new permission is requested. Forecasts by Apple Weather.

"TO DO" AND "DONE" CAN NO LONGER SHOW AT ONCE
The home screen could contradict itself: the word "Done", a full arc on the ring, and right below it an empty bar. Two places answered the question "is the session done?", and not the same way. Now there's only one.

And a run that arrives from Apple Health, or is recovered after a crash, now counts straight away — without waiting for you to fill in how it felt. The app was announcing "To do" for a run it was showing in your history.
```

## Keywords (100 characters max, comma-separated, no spaces)
```
run,5k,10k,half,marathon,pace,tracker,gps,interval,free,ultra,hyrox,beginner,race,training,triathlon
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

HYROX, ULTRA, TRIATLÓN — RUNUP PLUS
Tres preparaciones enteras, no variantes del plan de carrera. HYROX: las ocho estaciones y sus transiciones. Ultra: desnivel, marcha rápida, noche. Triatlón: natación, ciclismo y transiciones, del sprint a la larga distancia.

SEGUIMIENTO EN DIRECTO
Mapa y recorrido en tiempo real, ritmo, frecuencia cardíaca y calorías. Cada salida se guarda en Apple Salud, se exporta en GPX y se comparte como tarjeta con tu recorrido.

APPLE WATCH
Empieza a correr desde el reloj y deja el iPhone en casa: frecuencia cardíaca en la muñeca, distancia y calorías en directo. Cada carrera que termines en la muñeca vuelve al teléfono con su balance. Con RUNUP Plus, tu sesión del día se envía al reloj.

ESTADÍSTICAS QUE SIRVEN PARA ALGO
Tendencia de ritmo, récords personales, un mapa con todos tus recorridos y control del desgaste de tus zapatillas. Con RUNUP Plus: predicciones de tiempo en 5 km, 10 km, media y maratón, y ocho semanas de carga de entrenamiento.

DÓNDE CORRER CUANDO NO CONOCES EL SITIO
¿Llegas a una ciudad nueva y no sabes por dónde correr? El mapa muestra las rutas publicadas a tu alrededor, con distancia, desnivel y muchas veces una foto. Comparte las tuyas en dos toques: los primeros y últimos 300 metros se recortan antes de enviar, nadie verá de dónde saliste ni dónde volviste.

CLUB Y COMUNIDAD
Clasificación semanal y general, retos de club, quedadas, muro de actividad e insignias. Y si prefieres seguir a unas pocas personas en vez de a un club entero, hay un muro de amigos.

QUE ACABE EL PLAN NO ES EL FINAL — RUNUP PLUS
Al terminar: un bloque de recuperación guiado y, después, un nuevo objetivo o carrera libre sin plan fijo.

Conectar Apple Salud es opcional, pero afina la forma del día. El Club necesita una cuenta; todo lo demás funciona sin ella.

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
RUNUP mira el cielo y te dice cuándo salir.

ESTA NOCHE LLOVERÁ — LO SABES ESTA MAÑANA
Tu sesión está prevista a las 18 h y la lluvia llega a las 17. Al abrir la app, RUNUP ya ha comparado la mañana, el mediodía y la tarde, hora por hora, y te propone la ventana seca.

Solo habla cuando tiene algo que decir. Tu franja habitual debe estar francamente mal, otro momento del día realmente seco, la diferencia entre ambos clara, y deben quedarte dos horas para reorganizarte. Un aviso al día como máximo.

Cuando llueve todo el día, se calla. Correrás bajo la lluvia o no correrás: decírtelo solo cambiaría tu humor.

Se apaga con un interruptor, «Avisarme si va a llover», y no se pide ningún permiso nuevo. Previsiones de Apple Weather.

«POR HACER» Y «HECHA» YA NO PUEDEN APARECER A LA VEZ
La pantalla de inicio podía contradecirse sola: la palabra «Hecha», un arco lleno en el anillo, y justo debajo una barra vacía. Dos sitios respondían a la pregunta «¿está hecha la sesión?», y no de la misma forma. Ahora solo hay uno.

Y una carrera que llega de Apple Salud, o que se recupera tras un fallo, cuenta ya de inmediato, sin esperar a que rellenes tus sensaciones. La app anunciaba «Por hacer» para una salida que mostraba en tu historial.
```

## Palabras clave (100 caracteres máx., separadas por comas sin espacios)
```
correr,maraton,10k,media,entrenamiento,gratis,gps,series,principiante,trail,ultra,hyrox,triatlon
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
