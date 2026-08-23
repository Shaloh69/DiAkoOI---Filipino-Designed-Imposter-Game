import { buildApp } from './app.js';
import { parseEnv } from './env.js';
import { createPool } from './lib/database.js';
import { runMigrations } from './lib/migrate.js';

const env = parseEnv();

// Migrations run before the app serves. Without this the schema simply does
// not exist and every word-bank query answers 503 — which the contract tests
// caught immediately, because a 503 on a documented read is a server error
// however tidy its error body is.
if (env.DATABASE_URL !== undefined) {
  const pool = createPool(env.DATABASE_URL);
  if (pool !== null) {
    try {
      const applied = await runMigrations(pool);
      if (applied.length > 0) {
        // eslint-disable-next-line no-console
        console.log(`migrations applied: ${applied.join(', ')}`);
      }
    } finally {
      await pool.end();
    }
  }
}

const app = await buildApp(env);

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => {
    void app.close().then(() => process.exit(0));
  });
}

try {
  await app.listen({ port: env.API_PORT, host: env.API_HOST });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
