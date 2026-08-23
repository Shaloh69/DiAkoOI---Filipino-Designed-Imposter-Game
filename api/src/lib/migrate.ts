import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Pool } from 'pg';

/**
 * Applies every migration not yet recorded, in filename order.
 *
 * Deliberately trivial: no down-migrations, no checksums. A beta with one
 * operator does not need them, and a migration framework that nobody
 * exercises is a dependency pretending to be a safety net.
 */
const migrationsDir = join(dirname(fileURLToPath(import.meta.url)), '../migrations');

export const runMigrations = async (pool: Pool): Promise<readonly string[]> => {
  await pool.query(
    'CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now())',
  );

  const applied = new Set(
    (await pool.query<{ version: string }>('SELECT version FROM schema_migrations'))
      .rows.map((row) => row.version),
  );

  const files = readdirSync(migrationsDir)
    .filter((name) => name.endsWith('.sql'))
    .sort();

  const ran: string[] = [];
  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = readFileSync(join(migrationsDir, file), 'utf8');
    // One transaction per migration: a half-applied schema is worse than a
    // failed deploy, because the next run starts from an unknown place.
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
      await client.query('COMMIT');
      ran.push(file);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
  return ran;
};
