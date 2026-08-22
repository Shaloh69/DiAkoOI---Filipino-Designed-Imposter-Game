import { Pool } from 'pg';

export type DatabaseStatus = 'up' | 'down' | 'not_configured';

/**
 * A lazily created pool. Phase 7 replaces this with migrations and real
 * repositories; for now it exists so `docker compose up -d` proves the api ->
 * postgres wiring actually works.
 */
export const createPool = (connectionString: string | undefined): Pool | null =>
  connectionString === undefined
    ? null
    : new Pool({ connectionString, max: 4, connectionTimeoutMillis: 2_000 });

export const checkDatabase = async (
  pool: Pool | null,
): Promise<DatabaseStatus> => {
  if (pool === null) return 'not_configured';
  try {
    await pool.query('SELECT 1');
    return 'up';
  } catch {
    return 'down';
  }
};
