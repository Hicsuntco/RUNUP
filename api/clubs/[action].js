// Consolidated into one dynamic route ([action] = create | join | leave | mine) instead of 4
// separate files — see api/auth/[action].js for why. /api/clubs/create, /join, /leave, /mine
// still work exactly as before.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');
const { containsObjectionableContent } = require('../../lib/moderation');

module.exports = withErrorHandling(async function handler(req, res) {
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  switch (req.query.action) {
    case 'create':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleCreate(req, res, userId);
    case 'join':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleJoin(req, res, userId);
    case 'leave':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleLeave(req, res, userId);
    case 'mine':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleMine(req, res, userId);
    case 'createChallenge':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleCreateChallenge(req, res, userId);
    case 'updateBio':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleUpdateBio(req, res, userId);
    case 'syncBadges':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleSyncBadges(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

// Must match `ClubBadgeCatalog.all` keys on the client — anything else is silently dropped rather
// than trusted, since a tampered client could otherwise write arbitrary junk keys here.
const KNOWN_BADGES = new Set(['streak3', 'interval3', 'earlyRun', 'elevation300']);

function randomInviteCode() {
  // No 0/O/1/I — avoids ambiguity when a code is read aloud or typed by hand.
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
  return code;
}

// Creates a club and auto-joins the creator. v1: a user can only be in one club at a time.
async function handleCreate(req, res, userId) {
  const { rows: already } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  if (already.length > 0) return res.status(409).json({ error: 'already_in_club' });

  const { name } = req.body || {};
  if (!name || !name.trim()) return res.status(400).json({ error: 'bad_request' });
  if (containsObjectionableContent(name)) return res.status(422).json({ error: 'objectionable_content' });

  let club;
  // Retry on the astronomically rare invite_code collision instead of trusting a single attempt.
  for (let attempt = 0; attempt < 5 && !club; attempt++) {
    const code = randomInviteCode();
    try {
      const { rows } = await sql`
        INSERT INTO clubs (name, invite_code, created_by)
        VALUES (${name.trim()}, ${code}, ${userId})
        RETURNING id, name, invite_code
      `;
      club = rows[0];
    } catch (e) {
      if (!String(e.message).includes('invite_code')) throw e;
    }
  }
  if (!club) return res.status(500).json({ error: 'could_not_create' });

  await sql`INSERT INTO club_members (club_id, user_id) VALUES (${club.id}, ${userId})`;
  res.status(201).json({ id: club.id, name: club.name, inviteCode: club.invite_code });
}

async function handleJoin(req, res, userId) {
  const { rows: already } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  if (already.length > 0) return res.status(409).json({ error: 'already_in_club' });

  const { inviteCode } = req.body || {};
  if (!inviteCode) return res.status(400).json({ error: 'bad_request' });

  const { rows } = await sql`SELECT id, name FROM clubs WHERE invite_code = ${String(inviteCode).trim().toUpperCase()}`;
  const club = rows[0];
  if (!club) return res.status(404).json({ error: 'not_found' });

  await sql`INSERT INTO club_members (club_id, user_id) VALUES (${club.id}, ${userId})`;
  res.status(200).json({ id: club.id, name: club.name });
}

async function handleLeave(req, res, userId) {
  await sql`DELETE FROM club_members WHERE user_id = ${userId}`;
  res.status(200).json({ ok: true });
}

// Any member can set the club's active challenge — replaces the one before it (a club has at
// most one active challenge at a time, kept simple rather than juggling several in parallel).
async function handleCreateChallenge(req, res, userId) {
  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id;
  if (!clubId) return res.status(409).json({ error: 'not_in_club' });

  const { title, targetKm, endDate } = req.body || {};
  const target = Number(targetKm);
  if (!title || !title.trim() || !Number.isFinite(target) || target <= 0 || !endDate) {
    return res.status(400).json({ error: 'bad_request' });
  }
  if (containsObjectionableContent(title)) return res.status(422).json({ error: 'objectionable_content' });

  const { rows } = await sql`
    INSERT INTO challenges (club_id, created_by, title, target_km, end_date)
    VALUES (${clubId}, ${userId}, ${title.trim()}, ${target}, ${endDate})
    RETURNING id, title, target_km, end_date, created_at
  `;
  const challenge = rows[0];
  res.status(201).json({
    id: challenge.id,
    title: challenge.title,
    targetKm: Number(challenge.target_km),
    progressKm: 0,
    endDate: challenge.end_date,
  });
}

// The user's club (if any) plus a real, computed leaderboard — ranked by each member's actual
// xp_total, not a fixed/mocked position. Returns { club: null } if the user hasn't joined or
// created a club yet.
async function handleMine(req, res, userId) {
  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  if (memberRows.length === 0) return res.status(200).json({ club: null, leaderboard: [] });

  const clubId = memberRows[0].club_id;
  const { rows: clubRows } = await sql`SELECT id, name, invite_code FROM clubs WHERE id = ${clubId}`;
  const club = clubRows[0];

  // Rank is computed over every member first (a subquery), then blocked users are filtered out
  // of the outer result — so someone you've blocked disappears from your view, but everyone
  // else's rank number still reflects their true position rather than shifting to fill the gap.
  // bio/joined_at/activities_count/badge_keys power the real club-profile screen — real per-member
  // data (join date already tracked, activity count a plain COUNT scoped to this club, badges a
  // real array_agg over `user_badges`) instead of anything computed only from this device's own
  // local history.
  const { rows: leaderboard } = await sql`
    SELECT id, name, xp_total, rank, bio, joined_at, activities_count, badge_keys FROM (
      SELECT u.id, u.name, u.xp_total, u.bio, cm.joined_at,
             RANK() OVER (ORDER BY u.xp_total DESC) AS rank,
             (SELECT COUNT(*)::int FROM activities a WHERE a.user_id = u.id AND a.club_id = cm.club_id) AS activities_count,
             COALESCE((SELECT array_agg(ub.badge_key) FROM user_badges ub WHERE ub.user_id = u.id), ARRAY[]::text[]) AS badge_keys
      FROM club_members cm
      JOIN users u ON u.id = cm.user_id
      WHERE cm.club_id = ${clubId}
    ) ranked
    WHERE id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
    ORDER BY xp_total DESC
  `;

  const { rows: countRows } = await sql`SELECT COUNT(*)::int AS count FROM club_members WHERE club_id = ${clubId}`;

  // The most recent still-active challenge (if any), with real collective progress: every
  // 'run' activity logged to this club since the challenge was created, summed — not a running
  // counter that could drift from what actually got posted.
  const { rows: challengeRows } = await sql`
    SELECT c.id, c.title, c.target_km, c.end_date,
           COALESCE((
             SELECT SUM(a.distance_km) FROM activities a
             WHERE a.club_id = ${clubId} AND a.type = 'run' AND a.distance_km IS NOT NULL
               AND a.created_at >= c.created_at
           ), 0) AS progress_km
    FROM challenges c
    WHERE c.club_id = ${clubId} AND c.end_date >= CURRENT_DATE
    ORDER BY c.created_at DESC
    LIMIT 1
  `;
  const challenge = challengeRows[0];

  res.status(200).json({
    club: { id: club.id, name: club.name, inviteCode: club.invite_code, memberCount: countRows[0].count },
    leaderboard: leaderboard.map((r) => ({
      id: r.id, name: r.name, xp: r.xp_total, rank: Number(r.rank), isMe: r.id === userId,
      bio: r.bio || null,
      joinedAt: r.joined_at,
      activitiesCount: r.activities_count,
      badgeKeys: r.badge_keys || [],
    })),
    challenge: challenge ? {
      id: challenge.id,
      title: challenge.title,
      targetKm: Number(challenge.target_km),
      progressKm: Number(challenge.progress_km),
      endDate: challenge.end_date,
    } : null,
  });
}

// A short, optional, self-authored status shown on the caller's own club profile — only ever the
// caller's own row (there's no targetId; the token is the identity), same moderation as club
// names and challenge titles.
async function handleUpdateBio(req, res, userId) {
  const { bio } = req.body || {};
  const trimmed = (bio || '').trim().slice(0, 140);
  if (trimmed && containsObjectionableContent(trimmed)) return res.status(422).json({ error: 'objectionable_content' });
  await sql`UPDATE users SET bio = ${trimmed || null} WHERE id = ${userId}`;
  res.status(200).json({ ok: true, bio: trimmed || null });
}

// Upserts real, permanent achievements from keys the client computed locally (streak, run
// history, elevation — data only the client has). Never deletes: once earned, a badge stays
// earned even if the underlying streak later resets, same as any other achievement system.
// Unknown keys are silently dropped rather than trusted, since a tampered client could otherwise
// write arbitrary junk here.
async function handleSyncBadges(req, res, userId) {
  const { badgeKeys } = req.body || {};
  if (!Array.isArray(badgeKeys)) return res.status(400).json({ error: 'bad_request' });
  const valid = [...new Set(badgeKeys)].filter((k) => KNOWN_BADGES.has(k));
  await Promise.all(
    valid.map((key) => sql`
      INSERT INTO user_badges (user_id, badge_key) VALUES (${userId}, ${key})
      ON CONFLICT DO NOTHING
    `)
  );
  res.status(200).json({ ok: true });
}
