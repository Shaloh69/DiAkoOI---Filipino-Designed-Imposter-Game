import type { FastifyInstance } from 'fastify';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { buildApp } from '../src/app.js';
import { parseEnv } from '../src/env.js';

describe('GET /v1/health', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await buildApp(parseEnv({ NODE_ENV: 'test' }));
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns the documented { data, meta } envelope', async () => {
    const response = await request(app.server).get('/v1/health').expect(200);

    expect(response.body).toMatchObject({
      data: {
        status: 'ok',
        // No DATABASE_URL in the test env, so the probe reports this rather
        // than failing — see api/openapi.yaml.
        database: 'not_configured',
      },
    });
    expect(response.body.data.uptimeSeconds).toBeGreaterThanOrEqual(0);
    expect(typeof response.body.meta.requestId).toBe('string');
    expect(Number.isNaN(Date.parse(response.body.meta.timestamp))).toBe(false);
  });

  it('returns the documented error shape for an unknown route', async () => {
    const response = await request(app.server).get('/v1/nope').expect(404);

    expect(response.body).toEqual({
      error: { code: 'NOT_FOUND', message: 'Route not found' },
    });
  });

  // A documented path with an undocumented method is 405, not 404 — caught by
  // Schemathesis's unsupported-methods check before this test existed.
  it('returns 405 with an Allow header for an undocumented method', async () => {
    const response = await request(app.server).post('/v1/health').expect(405);

    expect(response.headers.allow).toBe('GET, HEAD');
    expect(response.body.error.code).toBe('METHOD_NOT_ALLOWED');
  });
});
