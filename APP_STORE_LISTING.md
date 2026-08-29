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
Tendance d'allure, records personnels, prédictions sur 5 km, 10 km, semi et marathon, charge d'entraînement sur 8 semaines, carte de tes parcours, usure des chaussures.

OÙ COURIR QUAND TU NE CONNAIS PAS L'ENDROIT
Tu débarques dans une ville et tu ne sais pas où courir ? La carte montre les itinéraires publiés autour de toi, avec distance, dénivelé et souvent une photo. Tes propres sorties se partagent en deux gestes — et les 300 premiers et derniers mètres sont retirés avant l'envoi : personne ne verra d'où tu es partie ni où tu es rentrée.

CLUB & COMMUNAUTÉ
Classement de la semaine et classement général, défis de club, sorties de groupe, fil d'activité et badges. Et si tu préfères suivre quelques personnes plutôt qu'un club entier, un fil d'amis fait exactement ça.

FIN DE PROGRAMME, PAS FIN DE L'HISTOIRE
À la fin de ton programme : récupération encadrée, puis nouvel objectif ou mode course libre sans plan fixe.

Nécessite iOS 17 ou version ultérieure. La connexion à Apple Santé est optionnelle, mais affine la forme du jour. Le Club demande un compte ; tout le reste de l'app fonctionne sans.

ABONNEMENT RUNUP PLUS
RUNUP s'utilise avec un abonnement RUNUP Plus, précédé de 7 jours d'essai gratuit.
• RUNUP Plus mensuel — 6,99 € par mois
• RUNUP Plus annuel — 39,99 € par an (soit 3,33 € par mois)
Le paiement est débité sur ton compte Apple à la confirmation de l'achat, à la fin des 7 jours d'essai. L'abonnement se renouvelle automatiquement sauf s'il est résilié au moins 24 heures avant la fin de la période en cours. Ton compte est débité du renouvellement dans les 24 heures précédant la fin de la période. Tu peux gérer ton abonnement et désactiver le renouvellement automatique depuis les réglages de ton compte Apple après l'achat. Toute partie non utilisée d'une période d'essai gratuite est perdue si tu souscris un abonnement pendant cette période.
Conditions d'utilisation : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Politique de confidentialité : https://hicsuntco.github.io/RUNUP/privacy.html
```

## Nouveautés de cette version (4000 caractères max — obligatoire pour une mise à jour)
```
Refonte complète de l'interface.

• Une seule typographie dans toute l'app, plus grande et mieux hiérarchisée. Les chiffres dominent enfin les libellés qui les accompagnent.
• Des cartes aux angles adoucis, des titres en gras là où il n'y avait que de petites étiquettes grises, et un mode clair repensé.
• L'onglet Programme est réorganisé : la semaine en cours d'abord, les suivantes groupées par phase, les semaines faites rangées.
• L'écran Stats passe en grille : quatre chiffres qui ont enfin la place d'être lus.
• Le profil affiche tes badges et l'usure de tes chaussures, qui étaient enterrés dans les réglages.
• Le premier jour montre ce que ton programme va faire, au lieu d'une page de zéros.
• Le widget et l'Apple Watch suivent la même direction — et le widget est enfin traduit en anglais et en espagnol.
• Contraste corrigé sur les nuanciers Lime, Cyan, Ambre et Corail : leur mode clair était illisible.

RUNUP passe à l'abonnement. RUNUP Plus donne accès à tout — programme adaptatif, coach sans limite, stats, montre, club — après 7 jours d'essai gratuit. Si tu utilisais déjà l'app, l'essai s'applique aussi à toi.
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

RUNUP PLUS SUBSCRIPTION
RUNUP is used with a RUNUP Plus subscription, starting with a 7-day free trial.
• RUNUP Plus monthly — €6.99 per month
• RUNUP Plus yearly — €39.99 per year (that's €3.33 per month)
Payment is charged to your Apple account at confirmation of purchase, at the end of the 7-day trial. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Your account is charged for renewal within 24 hours prior to the end of the current period. You can manage your subscription and switch off auto-renewal in your Apple account settings after purchase. Any unused portion of a free trial period is forfeited when you purchase a subscription during that period.
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://hicsuntco.github.io/RUNUP/privacy.html
```

## What's New in This Version (4000 characters max — required for an update)
```
A full interface redesign.

• One typeface across the whole app, larger and better ranked. Numbers finally dominate the labels beside them.
• Softer card corners, bold headings where there were only small grey labels, and a reworked light mode.
• The Program tab is reorganised: this week first, the following ones grouped by phase, finished weeks tucked away.
• Stats moves to a grid — four figures with room to be read.
• Your profile now shows your badges and your shoe mileage, which were buried in settings.
• Day one shows what your program is going to do, instead of a page of zeros.
• The widget and the Apple Watch follow the same direction — and the widget is finally translated into English and Spanish.
• Contrast fixed on the Lime, Cyan, Amber and Coral palettes: their light mode was unreadable.

RUNUP moves to a subscription. RUNUP Plus unlocks everything — adaptive program, unlimited coach, stats, watch, club — after a 7-day free trial. If you were already using the app, the trial applies to you too.
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
Clasificación semanal y general, retos de club, quedadas, muro de actividad e insignias. Y si prefieres seguir a unas pocas personas en vez de a un club entero, hay un muro de amigos.

QUE ACABE EL PLAN NO ES EL FINAL
Al terminar tu plan: un bloque de recuperación guiado y, después, un nuevo objetivo o modo carrera libre sin plan fijo.

Requiere iOS 17 o posterior. Conectar Apple Salud es opcional, pero afina la forma del día. El Club necesita una cuenta; todo lo demás funciona sin ella.

SUSCRIPCIÓN RUNUP PLUS
RUNUP se usa con una suscripción RUNUP Plus, precedida de 7 días de prueba gratuita.
• RUNUP Plus mensual — 6,99 € al mes
• RUNUP Plus anual — 39,99 € al año (es decir, 3,33 € al mes)
El pago se carga en tu cuenta de Apple al confirmar la compra, al final de los 7 días de prueba. La suscripción se renueva automáticamente salvo que se cancele al menos 24 horas antes del final del periodo en curso. El cargo de renovación se realiza en las 24 horas previas al final del periodo. Puedes gestionar tu suscripción y desactivar la renovación automática en los ajustes de tu cuenta de Apple después de la compra. Cualquier parte no utilizada de un periodo de prueba gratuito se pierde si contratas una suscripción durante ese periodo.
Términos de uso: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Política de privacidad: https://hicsuntco.github.io/RUNUP/privacy.html
```

## Novedades de esta versión (4000 caracteres máx. — obligatorio para una actualización)
```
Rediseño completo de la interfaz.

• Una sola tipografía en toda la app, más grande y mejor jerarquizada. Los números por fin dominan a las etiquetas que los acompañan.
• Esquinas de tarjeta más suaves, títulos en negrita donde solo había etiquetas grises pequeñas, y un modo claro replanteado.
• La pestaña Programa se reorganiza: primero la semana en curso, las siguientes agrupadas por fase, las semanas hechas recogidas.
• Estadísticas pasa a una cuadrícula: cuatro cifras con sitio para leerse.
• Tu perfil muestra ahora tus insignias y el kilometraje de tus zapatillas, que estaban enterrados en los ajustes.
• El primer día muestra lo que tu programa va a hacer, en vez de una página de ceros.
• El widget y el Apple Watch siguen la misma dirección — y el widget está por fin traducido al inglés y al español.
• Contraste corregido en las paletas Lima, Cian, Ámbar y Coral: su modo claro era ilegible.

RUNUP pasa a suscripción. RUNUP Plus desbloquea todo — programa adaptativo, entrenador sin límite, estadísticas, reloj, club — tras 7 días de prueba gratuita. Si ya usabas la app, la prueba también se aplica a ti.
```

## Palabras clave (100 caracteres máx., separadas por comas sin espacios)
```
correr,maraton,10k,media,ritmo,entrenamiento,cardio,gps,series,fondo,trote,rutas,carrera,fitness
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
