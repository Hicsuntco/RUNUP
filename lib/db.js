// Every query in this backend goes through this `sql` tagged-template — Neon's serverless driver
// talks to Postgres over HTTP (fetch) instead of a raw TCP connection, which is what you want in
// a Vercel serverless function: no connection pool to exhaust across concurrent invocations.
// `DATABASE_URL` is set automatically once Neon Postgres storage is attached to the Vercel
// project (Storage tab → Marketplace Database Providers → Neon); `POSTGRES_URL` is accepted too
// since some Vercel Postgres integrations name it that instead.
const { neon } = require('@neondatabase/serverless');

const connectionString = process.env.DATABASE_URL || process.env.POSTGRES_URL;
const rawSql = connectionString ? neon(connectionString) : null;

// Wraps Neon's `sql` (which resolves to a plain rows array) so every call site in this backend
// can keep using the `@vercel/postgres`-style `const { rows } = await sql\`...\`` shape.
async function sql(strings, ...values) {
  if (!rawSql) throw new Error('missing env DATABASE_URL');
  const rows = await rawSql(strings, ...values);
  return { rows };
}

module.exports = { sql };
