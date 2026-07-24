// Report + block — the other half of App Store guideline 1.2 alongside the content filter in
// lib/moderation.js: a way for users to flag objectionable club names/display names/activities,
// and a way to stop seeing a specific person's content without needing to leave the club
// entirely. Reports aren't auto-actioned (there's no automated moderation queue at this scale) —
// they land in the `reports` table for the developer to review directly.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling, isUuid } = require('../../lib/http');

const REPORT_TARGET_TYPES = new Set(['user', 'club', 'activity', 'comment']);

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  switch (req.query.action) {
    case 'report':
      return handleReport(req, res, userId);
    case 'block':
      return handleBlock(req, res, userId);
    case 'unblock':
      return handleUnblock(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

async function handleReport(req, res, userId) {
  const { targetType, targetId, reason } = req.body || {};
  const cleanReason = typeof reason === 'string' ? reason.trim().slice(0, 1000) : '';
  if (!REPORT_TARGET_TYPES.has(targetType) || !isUuid(targetId) || !cleanReason) {
    return res.status(400).json({ error: 'bad_request' });
  }
  await sql`
    INSERT INTO reports (reporter_id, target_type, target_id, reason)
    VALUES (${userId}, ${targetType}, ${targetId}, ${cleanReason})
  `;
  res.status(201).json({ ok: true });
}

async function handleBlock(req, res, userId) {
  const { userId: blockedId } = req.body || {};
  if (!isUuid(blockedId) || blockedId === userId) return res.status(400).json({ error: 'bad_request' });
  await sql`
    INSERT INTO blocks (blocker_id, blocked_id) VALUES (${userId}, ${blockedId})
    ON CONFLICT DO NOTHING
  `;
  res.status(200).json({ ok: true });
}

async function handleUnblock(req, res, userId) {
  const { userId: blockedId } = req.body || {};
  if (!isUuid(blockedId)) return res.status(400).json({ error: 'bad_request' });
  await sql`DELETE FROM blocks WHERE blocker_id = ${userId} AND blocked_id = ${blockedId}`;
  res.status(200).json({ ok: true });
}
