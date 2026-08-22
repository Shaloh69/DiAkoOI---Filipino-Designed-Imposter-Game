import type { FastifyInstance } from 'fastify';
import type { Pool } from 'pg';

import { checkDatabase } from '../lib/database.js';

interface HealthRouteOptions {
  readonly pool: Pool | null;
  readonly startedAt: number;
}

export const registerHealthRoute = (
  app: FastifyInstance,
  { pool, startedAt }: HealthRouteOptions,
): void => {
  app.get('/v1/health', async (request) => {
    const database = await checkDatabase(pool);

    // Shape is fixed by api/openapi.yaml — success is always { data, meta }.
    return {
      data: {
        status: 'ok',
        uptimeSeconds: (Date.now() - startedAt) / 1_000,
        database,
      },
      meta: {
        requestId: request.id,
        timestamp: new Date().toISOString(),
      },
    };
  });
};
