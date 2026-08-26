// Shared visibility rules for activity interaction (kudos/comments) — used by both
// api/activities/[action].js (club feed) and api/friends/[action].js (friends feed), since an
// activity is now reachable through either relationship and both need the same answer to
// "can this person see/interact with that post".
const { sql } = require('./db');

async function isBlockedEitherWay(userA, userB) {
  const { rows } = await sql`
    SELECT 1 FROM blocks
    WHERE (blocker_id = ${userA} AND blocked_id = ${userB})
       OR (blocker_id = ${userB} AND blocked_id = ${userA})
    LIMIT 1
  `;
  return rows.length > 0;
}

// True when `viewerId` may see/kudos/comment an activity posted by `posterId` — either they're
// CURRENTLY clubmates (the activity's club_id, checked against the viewer's live membership, not
// whatever club the poster happened to be in when they posted) or the viewer follows the poster
// (accepted, one-way is enough — that's the whole point of a follow feed), and neither has
// blocked the other. Not mutual: a friends feed only ever shows people YOU follow, so this checks
// that direction specifically rather than either side following the other.
async function canViewActivity(viewerId, posterId, activityClubId) {
  if (viewerId === posterId) return true;
  if (await isBlockedEitherWay(viewerId, posterId)) return false;
  if (activityClubId) {
    const { rows } = await sql`SELECT 1 FROM club_members WHERE user_id = ${viewerId} AND club_id = ${activityClubId}`;
    if (rows.length > 0) return true;
  }
  const { rows } = await sql`
    SELECT 1 FROM follows WHERE follower_id = ${viewerId} AND followee_id = ${posterId} AND status = 'accepted'
  `;
  return rows.length > 0;
}

// Les métriques réelles d'une sortie, telles que les deux fils (club et amis) les renvoient.
// Chaque champ est INDÉPENDAMMENT nullable, et c'est voulu : une activité postée avant la
// migration n'en a aucune, un post de type "badge" n'est pas une course, une sortie saisie à la
// main n'a ni dénivelé ni tracé. Le client omet la colonne correspondante au lieu d'afficher un
// « 0 km » ou un « --:-- » qui laisserait croire à une mesure. `isPersonalRecord` est le seul
// champ ramené à un booléen strict : l'absence d'information n'est pas un record.
function activityMetrics(row) {
  return {
    distanceKm: row.distance_km === null || row.distance_km === undefined ? null : Number(row.distance_km),
    durationSeconds: row.duration_seconds ?? null,
    avgPace: row.avg_pace || null,
    elevationGainM: row.elevation_gain_m ?? null,
    isPersonalRecord: row.is_personal_record === true,
    // Voir `activities.content_key` dans db/schema.sql : l'identifiant qui permet à l'appareil
    // qui lit de recomposer la phrase dans SA langue, au lieu d'afficher celle de l'autrice.
    contentKey: row.content_key || null,
  };
}

module.exports = { isBlockedEitherWay, canViewActivity, activityMetrics };
