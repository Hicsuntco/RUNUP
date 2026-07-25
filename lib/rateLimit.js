// Shared per-user (or per-IP) daily cap, backed by the same `coach_usage` table already used by
// the coach endpoint, login, activity-create, and avatar-upload caps — gives every other write
// endpoint (club join, signup, event creation) the same protection instead of each one
// reimplementing the INSERT ... ON CONFLICT dance. Fails open on a counter error: the cap must
// never take the underlying feature down with it.
const { sql } = require('./db');

async function underDailyCap(key, limit) {
  try {
    const { rows } = await sql`
      INSERT INTO coach_usage (key, day, count) VALUES (${key}, CURRENT_DATE, 1)
      ON CONFLICT (key, day) DO UPDATE SET count = coach_usage.count + 1
      RETURNING count
    `;
    return !rows[0] || rows[0].count <= limit;
  } catch {
    return true;
  }
}

module.exports = { underDailyCap };
