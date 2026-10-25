-- GÉNÉRÉ PAR db/semer_courses.js — NE PAS MODIFIER À LA MAIN.
-- Relancer `node db/semer_courses.js` après avoir mis la liste à jour dans ce script.
--
-- Les 9 courses que l'app connaît d'avance. Tout le reste se crée depuis l'app, par les
-- coureurs eux-mêmes : une page de course n'a pas besoin d'un catalogue mondial pour servir, elle
-- a besoin que la course que TOI tu prépares existe.
--
-- `created_by` reste NULL : personne n'a créé ces pages, elles étaient là. `is_seeded` les fait
-- passer avant les saisies approximatives du même événement dans la recherche.
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
