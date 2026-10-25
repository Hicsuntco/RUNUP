-- À COLLER DANS LA CONSOLE NEON (SQL Editor), EN UNE FOIS.
--
-- Deux temps : les trois tables des pages de course, puis les neuf courses que l'app connaît
-- d'avance. Tout est idempotent — `IF NOT EXISTS` et `ON CONFLICT DO NOTHING` — donc le relancer
-- ne crée rien en double et ne touche à rien d'existant.

-- ===== 1. LES TABLES =====

CREATE TABLE IF NOT EXISTS races (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  -- Le nom replié. Jamais affiché, jamais modifié à la main.
  name_key TEXT NOT NULL,
  city TEXT,
  race_date DATE NOT NULL,
  -- NULL pour une épreuve dont la distance n'est pas un nombre (un trail « 3 boucles », un relais).
  distance_km NUMERIC,
  elevation_gain_m INTEGER,
  -- 'run' | 'trail' | 'hyrox' | 'triathlon' | 'duathlon' — la même famille que `GoalType`, pour
  -- que la page sache quoi afficher (un D+ n'a de sens que sur un trail).
  discipline TEXT NOT NULL DEFAULT 'run',
  website TEXT,
  -- NULL pour les courses semées par l'app ; sinon la personne qui l'a créée.
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  -- Semée par l'app (les grandes courses françaises) plutôt que créée par quelqu'un. Sert à les
  -- faire remonter en premier dans la recherche, et à ne jamais les laisser supprimer.
  is_seeded BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_races_name_date ON races (name_key, race_date);
-- La recherche porte sur le nom replié ; la liste « bientôt » porte sur la date.
CREATE INDEX IF NOT EXISTS idx_races_date ON races (race_date);

-- QUI PRÉPARE CETTE COURSE.
--
-- `shares_training` est un OPT-IN EXPLICITE, et il est faux par défaut. Montrer à des inconnus
-- où quelqu'un en est de son entraînement n'est pas la même chose que lui montrer qu'il court la
-- même course : la seconde est l'objet de la page, la première est une donnée personnelle. Le
-- serveur ne rend le volume de personne tant que cette case n'est pas cochée.
--
-- `target_pace_sec_per_km` est DÉRIVÉ du chrono visé et de la distance, côté application, au
-- moment où la personne s'inscrit à la page. Stocké plutôt que recalculé, parce que c'est lui qui
-- trie la mise en relation et qu'un tri ne doit pas dépendre d'une analyse de chaîne à chaque
-- requête.
CREATE TABLE IF NOT EXISTS race_followers (
  race_id UUID NOT NULL REFERENCES races(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_chrono TEXT,
  target_pace_sec_per_km INTEGER,
  shares_training BOOLEAN NOT NULL DEFAULT false,
  looking_for_partner BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (race_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_race_followers_user ON race_followers (user_id);
-- La mise en relation trie par écart d'allure : l'index la rend utile même sur une grosse course.
CREATE INDEX IF NOT EXISTS idx_race_followers_pace ON race_followers (race_id, target_pace_sec_per_km);

-- LE FIL DE LA PAGE : les conseils, les recherches de partenaire, et les dossards.
--
-- UNE SEULE TABLE pour les trois, et c'est délibéré. Ce sont trois sujets d'une même
-- conversation — on ne va pas sur la page d'une course pour « consulter la rubrique dossards »,
-- on y va pour voir ce qui s'y dit. Trois tables auraient fait trois écrans, trois listes vides
-- à remplir, et trois endroits où modérer.
--
-- `parent_id` porte les réponses. C'est aussi le SEUL canal de contact entre deux personnes :
-- l'app n'a pas de messagerie, donc on répond sous l'annonce, en public. Pour un dossard, c'est
-- une protection autant qu'une limite — une négociation qui se tient devant tout le monde est
-- une négociation qu'on peut signaler.
--
-- LES DOSSARDS, ET CE QUE L'APP NE FAIT PAS. Elle affiche une annonce et met deux personnes en
-- contact. Elle n'encaisse rien, ne reverse rien, ne garantit rien, et ne vérifie aucun dossard.
-- La plupart des organisateurs INTERDISENT le transfert : courir sous le nom d'un autre, c'est la
-- disqualification, et surtout des secours qui liraient le mauvais dossier médical. L'app le dit
-- sur chaque annonce plutôt que de faire comme si la question ne se posait pas.
CREATE TABLE IF NOT EXISTS race_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id UUID NOT NULL REFERENCES races(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- NULL pour un message de premier niveau, sinon le message auquel il répond.
  parent_id UUID REFERENCES race_posts(id) ON DELETE CASCADE,
  -- 'message' | 'bib_offer' | 'bib_wanted' | 'partner'
  kind TEXT NOT NULL DEFAULT 'message',
  text TEXT NOT NULL,
  -- Retiré par son auteur. On ne supprime pas la ligne : une réponse sous une annonce effacée
  -- deviendrait un message sans contexte.
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_race_posts_race ON race_posts (race_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_race_posts_parent ON race_posts (parent_id, created_at);


-- ===== 2. LES NEUF COURSES SEMÉES =====

INSERT INTO races (name, name_key, city, race_date, distance_km, elevation_gain_m, discipline, website, created_by, is_seeded)
SELECT v.name, v.name_key, v.city, v.race_date::date, v.distance_km::numeric, v.elevation_gain_m::int,
       v.discipline, v.website, NULL, true
FROM (VALUES
  ('Marathon des Alpes-Maritimes Nice-Cannes', 'marathon des alpes maritimes nice cannes', 'Nice', '2026-11-08', 42.195, NULL, 'run', 'https://www.marathon06.com'),
  ('SaintéLyon', 'saintelyon', 'Saint-Étienne', '2026-11-28', 78, 2000, 'trail', 'https://www.saintelyon.com'),
  ('Semi-Marathon de Paris', 'semi marathon de paris', 'Paris', '2027-03-07', 21.0975, NULL, 'run', NULL),
  ('EcoTrail Paris', 'ecotrail paris', 'Paris', '2027-03-20', NULL, NULL, 'trail', NULL),
  ('Marathon de Paris', 'marathon de paris', 'Paris', '2027-04-04', 42.195, NULL, 'run', NULL),
  ('Marathon du Mont-Blanc', 'marathon du mont blanc', 'Chamonix', '2027-06-27', NULL, NULL, 'trail', 'https://www.marathonmontblanc.fr'),
  ('TCS London Marathon', 'tcs london marathon', 'London', '2027-04-25', 42.195, NULL, 'run', 'https://www.tcslondonmarathon.com'),
  ('Generali Berlin Marathon', 'generali berlin marathon', 'Berlin', '2027-09-26', 42.195, NULL, 'run', NULL),
  ('TCS New York City Marathon', 'tcs new york city marathon', 'New York', '2027-11-07', 42.195, NULL, 'run', 'https://www.nyrr.org')
) AS v (name, name_key, city, race_date, distance_km, elevation_gain_m, discipline, website)
ON CONFLICT (name_key, race_date) DO NOTHING;

-- ===== 3. VÉRIFICATION (facultatif) =====
-- Devrait rendre 9 lignes, de la plus proche à la plus lointaine.
SELECT name, city, race_date, distance_km, discipline
FROM races
WHERE is_seeded
ORDER BY race_date;
