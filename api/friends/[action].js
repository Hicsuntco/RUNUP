// Real friends/follow graph, independent of clubs — search | follow | unfollow | respond |
// removeFollower | list | feed | setPrivate | updateProfile. Consolidated into one dynamic
// route, same pattern as api/clubs/[action].js and api/activities/[action].js.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling, isUuid } = require('../../lib/http');
const { sendPushToUser } = require('../../lib/apns');
const { isBlockedEitherWay, activityMetrics } = require('../../lib/social');
const { underDailyCap } = require('../../lib/rateLimit');
const { containsObjectionableContent } = require('../../lib/moderation');

module.exports = withErrorHandling(async function handler(req, res) {
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  switch (req.query.action) {
    case 'search':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleSearch(req, res, userId);
    case 'follow':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleFollow(req, res, userId);
    case 'unfollow':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleUnfollow(req, res, userId);
    case 'respond':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRespond(req, res, userId);
    case 'removeFollower':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRemoveFollower(req, res, userId);
    case 'list':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleList(req, res, userId);
    case 'feed':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleFeed(req, res, userId);
    case 'setPrivate':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleSetPrivate(req, res, userId);
    case 'updateProfile':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleUpdateProfile(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

function mapUser(row) {
  return {
    id: row.id,
    name: row.name,
    lastName: row.last_name || null,
    username: row.username || null,
    avatarBase64: row.avatar_data || null,
    avatarUrl: row.avatar_url || null,
    isPrivate: row.is_private,
    followStatus: row.follow_status || null,
  };
}

const USERNAME_RE = /^[a-z0-9_]{3,20}$/;

// Finds real accounts to follow — a first name alone can't disambiguate ("which Léo?"), so this
// tries three things depending on what looks like was typed:
//   - contains "@": an EXACT (never partial) email match — an email is never substring-searchable,
//     so this can't be used to harvest the directory the way name/username search could.
//   - otherwise: a username prefix match (an explicit, chosen handle — the only fully reliable
//     way to find one specific person) OR a fuzzy "prénom nom" match against name + last_name.
// Excludes herself and anyone blocked either way. `followStatus` (from the CALLER's point of
// view — is *she* already following this result) lets the client show the right button state
// (Suivre / Demande envoyée / Abonné·e) without a second round trip per row.
async function handleSearch(req, res, userId) {
  const raw = typeof req.query.q === 'string' ? req.query.q.trim().slice(0, 60) : '';
  if (raw.length < 2) return res.status(200).json({ items: [] });

  // Same daily cap every write path in this file uses. Search is a read, but it's the one endpoint
  // that walks the whole user directory (the ILIKE branch below), so it's what a script would
  // hammer to enumerate accounts one prefix at a time — and each call is an unindexed scan of
  // `users`. 300/day is far past any real use: the client searches as she types, so looking
  // someone up costs a handful of requests. Counted after the <2 char guard so keystrokes that
  // never reach the database don't burn the quota.
  if (!(await underDailyCap('search:' + userId, 300))) return res.status(429).json({ error: 'too_many_requests' });

  let rows;
  if (raw.includes('@')) {
    ({ rows } = await sql`
      SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private, f.status AS follow_status
      FROM users u
      LEFT JOIN follows f ON f.follower_id = ${userId} AND f.followee_id = u.id
      WHERE u.id != ${userId} AND lower(u.email) = lower(${raw})
        AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
        AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
      LIMIT 5
    `);
  } else {
    const usernameQuery = raw.replace(/^@/, '');
    ({ rows } = await sql`
      SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private, f.status AS follow_status
      FROM users u
      LEFT JOIN follows f ON f.follower_id = ${userId} AND f.followee_id = u.id
      WHERE u.id != ${userId}
        AND (
          lower(u.username) LIKE lower(${usernameQuery + '%'})
          OR (u.name || ' ' || COALESCE(u.last_name, '')) ILIKE ${'%' + raw + '%'}
        )
        AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
        AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
      ORDER BY u.name ASC
      LIMIT 20
    `);
  }
  res.status(200).json({ items: rows.map(mapUser) });
}

// Sets the caller's own chosen handle and/or last name — both optional, either can be sent alone.
// `username` is validated (lowercase letters/digits/underscore, 3-20 chars) and must be globally
// unique (case-insensitively — see the DB's functional unique index); `lastName` gets the same
// content filter as every other user-visible free-text field.
async function handleUpdateProfile(req, res, userId) {
  const { username, lastName } = req.body || {};
  const updates = {};

  if (username !== undefined) {
    if (username === null || username === '') {
      updates.username = null;
    } else {
      const cleanUsername = typeof username === 'string' ? username.trim().toLowerCase() : '';
      if (!USERNAME_RE.test(cleanUsername)) return res.status(400).json({ error: 'bad_username' });
      if (containsObjectionableContent(cleanUsername)) return res.status(422).json({ error: 'objectionable_content' });
      updates.username = cleanUsername;
    }
  }
  if (lastName !== undefined) {
    if (lastName === null || lastName === '') {
      updates.lastName = null;
    } else {
      const cleanLastName = typeof lastName === 'string' ? lastName.trim().slice(0, 60) : '';
      if (!cleanLastName) return res.status(400).json({ error: 'bad_request' });
      if (containsObjectionableContent(cleanLastName)) return res.status(422).json({ error: 'objectionable_content' });
      updates.lastName = cleanLastName;
    }
  }
  if (Object.keys(updates).length === 0) return res.status(400).json({ error: 'bad_request' });

  try {
    if ('username' in updates) await sql`UPDATE users SET username = ${updates.username} WHERE id = ${userId}`;
    if ('lastName' in updates) await sql`UPDATE users SET last_name = ${updates.lastName} WHERE id = ${userId}`;
  } catch (e) {
    if (String(e.message).includes('uniq_users_username_lower')) {
      return res.status(409).json({ error: 'username_taken' });
    }
    throw e;
  }
  res.status(200).json({ ok: true });
}

// Follows a real account — instant ('accepted') unless they've gone private, in which case it's
// a request they must approve (see `respond`). Idempotent on the (follower_id, followee_id) pair:
// re-tapping "Suivre" on an already pending/accepted target just returns the current state.
async function handleFollow(req, res, userId) {
  const { userId: targetId } = req.body || {};
  if (!isUuid(targetId) || targetId === userId) return res.status(400).json({ error: 'bad_request' });
  if (await isBlockedEitherWay(userId, targetId)) return res.status(404).json({ error: 'not_found' });
  if (!(await underDailyCap('follow:' + userId, 150))) return res.status(429).json({ error: 'too_many_requests' });

  const { rows: targetRows } = await sql`SELECT is_private FROM users WHERE id = ${targetId}`;
  const target = targetRows[0];
  if (!target) return res.status(404).json({ error: 'not_found' });

  const status = target.is_private ? 'pending' : 'accepted';
  const { rows: inserted } = await sql`
    INSERT INTO follows (follower_id, followee_id, status) VALUES (${userId}, ${targetId}, ${status})
    ON CONFLICT (follower_id, followee_id) DO NOTHING
    RETURNING status
  `;
  if (inserted.length === 0) {
    const { rows: existing } = await sql`SELECT status FROM follows WHERE follower_id = ${userId} AND followee_id = ${targetId}`;
    return res.status(200).json({ status: existing[0]?.status || status });
  }

  // Before the response — Vercel may freeze the function once it's sent.
  const { rows: me } = await sql`SELECT name FROM users WHERE id = ${userId}`;
  const myName = me[0]?.name || 'Quelqu’un';
  await sendPushToUser(sql, targetId, {
    title: 'Amis',
    body: status === 'pending' ? `${myName} a demandé à te suivre` : `${myName} te suit maintenant`,
  });

  res.status(200).json({ status: inserted[0].status });
}

async function handleUnfollow(req, res, userId) {
  const { userId: targetId } = req.body || {};
  if (!isUuid(targetId)) return res.status(400).json({ error: 'bad_request' });
  await sql`DELETE FROM follows WHERE follower_id = ${userId} AND followee_id = ${targetId}`;
  res.status(200).json({ ok: true });
}

// The FOLLOWEE approves/declines a request targeting them — the only case a follow needs a
// second step (private accounts). Accept flips the row to 'accepted'; decline just deletes it,
// same as the requester never having followed at all.
async function handleRespond(req, res, userId) {
  const { userId: followerId, accept } = req.body || {};
  if (!isUuid(followerId) || typeof accept !== 'boolean') return res.status(400).json({ error: 'bad_request' });

  if (!accept) {
    await sql`DELETE FROM follows WHERE follower_id = ${followerId} AND followee_id = ${userId} AND status = 'pending'`;
    return res.status(200).json({ ok: true });
  }

  const { rows } = await sql`
    UPDATE follows SET status = 'accepted' WHERE follower_id = ${followerId} AND followee_id = ${userId} AND status = 'pending'
    RETURNING follower_id
  `;
  if (rows.length === 0) return res.status(404).json({ error: 'not_found' });

  const { rows: me } = await sql`SELECT name FROM users WHERE id = ${userId}`;
  await sendPushToUser(sql, followerId, {
    title: 'Amis',
    body: `${me[0]?.name || 'Quelqu’un'} a accepté ta demande`,
  });

  res.status(200).json({ ok: true });
}

// Lets the FOLLOWEE remove someone following them without either side unfollowing the other —
// same distinction most social apps make between "unfollow" (my side) and "remove follower"
// (their side).
async function handleRemoveFollower(req, res, userId) {
  const { userId: followerId } = req.body || {};
  if (!isUuid(followerId)) return res.status(400).json({ error: 'bad_request' });
  await sql`DELETE FROM follows WHERE follower_id = ${followerId} AND followee_id = ${userId}`;
  res.status(200).json({ ok: true });
}

async function handleList(req, res, userId) {
  const { rows: meRows } = await sql`SELECT is_private FROM users WHERE id = ${userId}`;
  const { rows: following } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private
    FROM follows f JOIN users u ON u.id = f.followee_id
    WHERE f.follower_id = ${userId} AND f.status = 'accepted'
    ORDER BY u.name ASC
  `;
  const { rows: followers } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private
    FROM follows f JOIN users u ON u.id = f.follower_id
    WHERE f.followee_id = ${userId} AND f.status = 'accepted'
    ORDER BY u.name ASC
  `;
  const { rows: incoming } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private
    FROM follows f JOIN users u ON u.id = f.follower_id
    WHERE f.followee_id = ${userId} AND f.status = 'pending'
    ORDER BY f.created_at ASC
  `;
  res.status(200).json({
    isPrivate: meRows[0]?.is_private || false,
    following: following.map(mapUser),
    followers: followers.map(mapUser),
    incomingRequests: incoming.map(mapUser),
  });
}

// Real activities from people she follows — same response shape as api/activities/feed (club
// feed) so the client renders both with the same row component, just sourced from the follow
// graph instead of club membership. One-way: only accepted follows in HER OWN follower→followee
// direction, matching `canViewActivity` in lib/social.js so a post visible here is always also
// kudos/comment-able there.
async function handleFeed(req, res, userId) {
  const { rows } = await sql`
    SELECT a.id, a.text, a.created_at, u.name, u.id AS user_id, u.avatar_data, u.avatar_url,
           a.distance_km, a.duration_seconds, a.avg_pace, a.elevation_gain_m, a.is_personal_record,
           (SELECT COUNT(*)::int FROM activity_kudos k WHERE k.activity_id = a.id) AS kudos,
           EXISTS(SELECT 1 FROM activity_kudos k WHERE k.activity_id = a.id AND k.user_id = ${userId}) AS kudoed_by_me,
           (SELECT COUNT(*)::int FROM activity_comments c WHERE c.activity_id = a.id) AS comments_count
    FROM activities a
    JOIN users u ON u.id = a.user_id
    JOIN follows f ON f.follower_id = ${userId} AND f.followee_id = a.user_id AND f.status = 'accepted'
    WHERE a.user_id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
    ORDER BY a.created_at DESC
    LIMIT 50
  `;
  res.status(200).json({
    items: rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      name: r.name,
      avatarBase64: r.avatar_data || null,
      avatarUrl: r.avatar_url || null,
      text: r.text,
      createdAt: r.created_at,
      ...activityMetrics(r),
      kudos: r.kudos,
      kudoedByMe: r.kudoed_by_me,
      commentsCount: r.comments_count,
    })),
  });
}

async function handleSetPrivate(req, res, userId) {
  const { isPrivate } = req.body || {};
  if (typeof isPrivate !== 'boolean') return res.status(400).json({ error: 'bad_request' });
  await sql`UPDATE users SET is_private = ${isPrivate} WHERE id = ${userId}`;
  res.status(200).json({ ok: true });
}
