-- Les questions ouvertes de l'app, et le SQL qui y répond.
--
-- # POURQUOI CE FICHIER EXISTE
--
-- L'audit d'octobre 2026 a laissé plusieurs décisions « en attente de données ». Les données
-- existaient — l'app les envoie depuis des mois — mais rien ne permettait d'en tirer une réponse :
-- pas d'endpoint de lecture (api/events.js n'accepte que des POST, délibérément), donc pas de
-- tableau de bord, donc une question par requête à réécrire de mémoire chaque fois.
--
-- Chaque bloc ci-dessous répond à UNE question de l'audit, se colle tel quel dans la console SQL
-- de Neon, et dit comment lire sa sortie. Toutes ont été exécutées sur un jeu d'essai dont la
-- réponse était connue d'avance (voir le commentaire de chaque bloc) : ce ne sont pas des
-- requêtes écrites puis livrées sans tourner.
--
-- # DEUX RÈGLES QUI VALENT POUR TOUTES
--
-- 1. **L'identité est `COALESCE(user_id::text, anonymous_id)`.** La partie décisive de
--    l'entonnoir se passe AVANT qu'un compte existe : l'onboarding tourne de bout en bout sans
--    connexion. Compter sur `user_id` seul jetterait exactement les gens qu'on cherche.
--
-- 2. **On compte des PERSONNES, pas des événements.** Quelqu'un qui revient sur une étape la
--    « voit » deux fois ; un `COUNT(*)` en ferait deux personnes et gonflerait la fuite d'un
--    cran. D'où `COUNT(DISTINCT …)` partout.
--
-- Et un avertissement de date : les onze événements ajoutés le 6 octobre 2026 (entonnoir
-- d'abonnement, `session_moved`, `account_switched_fresh`, `club_action_taken`) étaient JETÉS par
-- le serveur avant cette date — voir l'en-tête de `KNOWN_EVENTS` dans api/events.js. Les blocs
-- qui les utilisent ne renvoient rien d'antérieur au déploiement qui les a ajoutés.


-- ═════════════════════════════════════════════════════════════════════════════════════════════
-- 1. OÙ L'ONBOARDING PERD DU MONDE
-- ═════════════════════════════════════════════════════════════════════════════════════════════
--
-- La question que l'audit posait pour savoir s'il faut raccourcir les neuf étapes — et surtout
-- LAQUELLE couper. Couper au hasard est pire que ne rien couper : chaque étape alimente le plan.
--
-- `name` plutôt que `step` pour identifier l'étape : l'index se remet à pointer sur une autre
-- question dès qu'on en insère ou qu'on en retire une, alors que le nom survit. C'est ce qui
-- rend ce tableau comparable avant et après un raccourcissement.
--
-- Lecture : `pct_perdu` est la part des gens qui ont VU l'étape et ne l'ont jamais finie. La
-- ligne la plus haute est celle à travailler. Vérifié sur un jeu d'essai à fuite connue
-- (10 → 10, 10 → 8, 8 → 3, 3 → 3) : rend bien 0 %, 20 %, 62,5 %, 0 %.
WITH vues AS (
  SELECT props->>'name'                                        AS etape,
         MIN((props->>'step')::int)                            AS rang,
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id)) AS vues
  FROM events
  WHERE name = 'onboarding_step_viewed'
    AND created_at > now() - interval '30 days'
    AND props ->> 'name' IS NOT NULL
  GROUP BY 1
),
faites AS (
  SELECT props->>'name'                                        AS etape,
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id)) AS faites
  FROM events
  WHERE name = 'onboarding_step_completed'
    AND created_at > now() - interval '30 days'
    AND props ->> 'name' IS NOT NULL
  GROUP BY 1
)
SELECT v.rang,
       v.etape,
       v.vues,
       COALESCE(f.faites, 0)                                           AS faites,
       v.vues - COALESCE(f.faites, 0)                                  AS perdues,
       ROUND(100.0 * (v.vues - COALESCE(f.faites, 0)) / v.vues, 1)     AS pct_perdu
FROM vues v
LEFT JOIN faites f ON f.etape = v.etape
ORDER BY v.rang, v.etape;


-- ═════════════════════════════════════════════════════════════════════════════════════════════
-- 2. LE CLUB EST-IL VIVANT, OU SEULEMENT REJOINT
-- ═════════════════════════════════════════════════════════════════════════════════════════════
--
-- LA question de l'audit : le Club pèse seize pour cent de l'app, et sa valeur dépend du nombre
-- de gens dedans. `club_created` et `club_joined` mesuraient l'entrée ; `club_action_taken` (6
-- octobre 2026) mesure enfin ce qu'on y fait.
--
-- Le dénominateur est volontairement « les gens ENTRÉS dans un club », pas tous les utilisateurs :
-- un geste de club par quelqu'un qui n'a rejoint aucun club (ça existe — le fil des amis et les
-- itinéraires partagés n'exigent pas de club) répondrait à une autre question.
--
-- Lecture : un chiffre. La part des gens entrés dans un club qui y ont fait au moins un geste
-- délibéré. Vérifié sur un jeu d'essai à 5 entrés dont 2 actifs, plus un actif hors club qui ne
-- doit pas compter : rend bien 40 %.
WITH entres AS (
  SELECT DISTINCT COALESCE(user_id::text, anonymous_id) AS qui
  FROM events
  WHERE name IN ('club_joined', 'club_created')
    AND created_at > now() - interval '90 days'
),
actifs AS (
  SELECT DISTINCT COALESCE(user_id::text, anonymous_id) AS qui
  FROM events
  WHERE name = 'club_action_taken'
    AND created_at > now() - interval '90 days'
)
SELECT COUNT(*)                                                   AS entres_dans_un_club,
       COUNT(a.qui)                                               AS dont_au_moins_un_geste,
       ROUND(100.0 * COUNT(a.qui) / NULLIF(COUNT(*), 0), 1)       AS pct_actifs
FROM entres e
LEFT JOIN actifs a ON a.qui = e.qui;


-- ── 2b. ET QUELS GESTES, pour savoir ce qui porte le Club ────────────────────────────────────
--
-- Une proportion basse ne dit pas s'il faut réduire le Club ou le réparer. Ce tableau-là le dit :
-- si tout le volume est dans `kudos`, le Club est un bouton « j'aime » avec un serveur derrière ;
-- si les itinéraires et les sorties de groupe portent, c'est une vraie fonctionnalité sociale.
--
-- Lecture : `personnes` compte plus que `gestes` — dix kudos d'une seule personne ne font pas un
-- club vivant.
SELECT props->>'kind'                                        AS geste,
       COUNT(*)                                              AS gestes,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id)) AS personnes
FROM events
WHERE name = 'club_action_taken'
  AND created_at > now() - interval '90 days'
GROUP BY 1
ORDER BY personnes DESC, gestes DESC;


-- ═════════════════════════════════════════════════════════════════════════════════════════════
-- 3. POURQUOI PERSONNE NE PAYE
-- ═════════════════════════════════════════════════════════════════════════════════════════════
--
-- Trois maladies possibles, trois remèdes opposés, et le tableau des ventes d'Apple ne montre que
-- l'issue : personne n'atteint le mur de paiement, on le voit et on repart, ou l'achat casse.
-- Les huit événements qui les distinguent existaient côté app depuis des mois et n'arrivaient
-- nulle part (voir api/events.js) — ce bloc ne répond donc que sur la période qui suit le
-- déploiement du 6 octobre 2026.
--
-- Lecture de haut en bas, en personnes. L'écart le plus large entre deux lignes consécutives est
-- la maladie. Et `paywall_products_unavailable` est à part : ce sont les ouvertures où l'app n'a
-- rien pu vendre et s'est déverrouillée quand même — l'app donnée, littéralement. Ces gens-là ne
-- se plaignent pas, ils utilisent l'app.
-- Vérifié sur un jeu d'essai à 10 / 4 / 3 / 1 / 1 / 1.
SELECT etape, personnes FROM (
  SELECT 1 AS rang, 'mur de paiement vu'          AS etape,
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id)) AS personnes
  FROM events WHERE name = 'paywall_shown'       AND created_at > now() - interval '90 days'
  UNION ALL
  SELECT 2, 'formule choisie',
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id))
  FROM events WHERE name = 'paywall_plan_selected' AND created_at > now() - interval '90 days'
  UNION ALL
  SELECT 3, 'achat lancé',
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id))
  FROM events WHERE name = 'purchase_started'    AND created_at > now() - interval '90 days'
  UNION ALL
  SELECT 4, 'achat abouti',
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id))
  FROM events WHERE name = 'purchase_completed'  AND created_at > now() - interval '90 days'
  UNION ALL
  SELECT 5, 'refusé dans la feuille Apple',
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id))
  FROM events WHERE name = 'purchase_cancelled'  AND created_at > now() - interval '90 days'
  UNION ALL
  SELECT 6, 'achat en panne',
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id))
  FROM events WHERE name = 'purchase_failed'     AND created_at > now() - interval '90 days'
  UNION ALL
  SELECT 7, 'app donnée (rien à vendre)',
         COUNT(DISTINCT COALESCE(user_id::text, anonymous_id))
  FROM events WHERE name = 'paywall_products_unavailable' AND created_at > now() - interval '90 days'
) f
ORDER BY rang;


-- ═════════════════════════════════════════════════════════════════════════════════════════════
-- 0. D'ABORD : RETIRER LA LIGNE DE SYNTHÈSE
-- ═════════════════════════════════════════════════════════════════════════════════════════════
--
-- Numéroté zéro parce qu'il passe AVANT les autres, et pas par ordre d'importance : cette ligne
-- fausse la réponse de tous les blocs ci-dessus.
--
-- `00000000-0000-4000-8000-000000000000` n'est pas un identifiant que l'app produit. C'est un
-- `anonymous_id` posé à la main pour éprouver les requêtes de ce fichier — un jeu d'essai dont la
-- réponse était connue d'avance, inséré en production parce que c'est là que les requêtes
-- tournent. Il a fait son travail, et il compte désormais comme une personne dans chaque
-- `COUNT(DISTINCT …)`.
--
-- Sur une base jeune, une personne inventée sur dix déplace un pourcentage de dix points.
--
-- Regarder d'abord ce qui va partir : on ne supprime pas en production sans avoir lu.
SELECT name, COUNT(*) AS lignes, MIN(created_at)::date AS premiere, MAX(created_at)::date AS derniere
FROM events
WHERE anonymous_id = '00000000-0000-4000-8000-000000000000'
GROUP BY 1
ORDER BY 1;

-- Puis supprimer. Vérifié sur un jeu d'essai contenant deux lignes de synthèse (un conseil météo
-- et une étape d'onboarding) parmi huit lignes réelles : rend bien `DELETE 2`, et le bloc 5
-- ci-dessous repasse de 4 personnes à 3.
DELETE FROM events WHERE anonymous_id = '00000000-0000-4000-8000-000000000000';


-- ═════════════════════════════════════════════════════════════════════════════════════════════
-- 5. iOS RÉVEILLE-T-IL VRAIMENT L'APP POUR LA MÉTÉO
-- ═════════════════════════════════════════════════════════════════════════════════════════════
--
-- LA question que le conseil météo de la veille laisse ouverte, et elle ne se répond pas en
-- relisant le code.
--
-- Le conseil doit arriver LA VEILLE au soir, pour qu'on puisse organiser son lendemain. Donner
-- cette information le matin même ne sert plus à rien : la journée est déjà prise. Or une app iOS
-- ne décide pas de s'exécuter : elle demande un réveil (`BGAppRefreshTask`) et le système accorde
-- ou n'accorde pas, selon la batterie, l'habitude d'usage et son humeur propre. Personne ne peut
-- l'affirmer depuis le code — et un simulateur, qui accorde tout, prouve le contraire de ce qu'on
-- cherche.
--
-- D'où la distinction portée par l'événement : `source = 'background'` est un conseil envoyé par
-- un réveil système, `source = 'app'` un conseil envoyé parce que quelqu'un a ouvert l'app. Seule
-- la première colonne dit que la fonctionnalité existe.
--
-- COMMENT LIRE, dans cet ordre :
--
-- 1. **Pas de ligne `background` du tout** → iOS ne réveille jamais l'app. La fonctionnalité
--    s'est silencieusement réduite à « quand tu ouvres l'app », c'est-à-dire exactement ce
--    qu'elle existait pour dépasser. Il faut alors changer de mécanisme, pas attendre.
-- 2. **Une ligne `background`, mais `pour_demain` à zéro** → les réveils arrivent, mais jamais
--    dans la fenêtre du soir. C'est le créneau de `WeatherBackgroundRefresh.prochainReveil` qu'il
--    faut déplacer, pas le mécanisme.
-- 3. **`jours` bien plus petit que le nombre de jours écoulés** → les réveils sont accordés, mais
--    rarement. Le conseil de la veille devient une loterie, et c'est pire qu'une absence : on
--    apprend à ne pas compter dessus.
--
-- Il faut quelques jours de données : un réveil par jour au mieux, et iOS met du temps à
-- apprendre les habitudes d'une app neuve. Une lecture faite le lendemain du déploiement ne
-- prouve rien.
--
-- Vérifié sur un jeu d'essai à réponse connue — 4 conseils par ouverture sur 3 jours pour 3
-- personnes dont 2 pour demain, et 3 conseils par réveil sur 3 jours pour 2 personnes dont 2
-- pour demain : rend exactement ça.
SELECT COALESCE(props->>'source', '(absente)')                   AS origine,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id))      AS personnes,
       COUNT(*)                                                   AS annonces,
       COUNT(DISTINCT created_at::date)                           AS jours,
       COUNT(*) FILTER (WHERE props->>'target' = 'tomorrow')      AS pour_demain,
       MIN(created_at)::date                                      AS premiere,
       MAX(created_at)::date                                      AS derniere
FROM events
WHERE name = 'weather_advice_sent'
  AND created_at > now() - interval '90 days'
GROUP BY 1
ORDER BY 1;

-- Et le détail de ce que les réveils ont envoyé, quand il y en a. `nature` dit si le conseil de
-- la veille a tenu : `advice` est un premier conseil, `amended` une rectification de dernière
-- minute, `cancelled` un démenti. Une majorité de `amended` et `cancelled` sur `background`
-- voudrait dire que la prévision de la veille au soir n'est pas assez fiable pour être annoncée
-- aussi tôt — un résultat qu'aucune relecture de code ne donnera.
SELECT COALESCE(props->>'source', '(absente)') AS origine,
       COALESCE(props->>'nature', '(absente)') AS nature,
       COUNT(*)                                AS annonces
FROM events
WHERE name = 'weather_advice_sent'
  AND created_at > now() - interval '90 days'
GROUP BY 1, 2
ORDER BY 1, 2;
