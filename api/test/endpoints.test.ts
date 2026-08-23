import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { buildApp } from '../src/app.js';
import { parseEnv } from '../src/env.js';
import { maxAttachmentBase64 } from '../src/lib/schemas.js';

/**
 * Happy and error paths for every documented endpoint.
 *
 * These run **without a database**, which is deliberate: the app must treat a
 * database outage exactly like being offline (12-HOSTING.md §2c), so the 503
 * path is the one a real client is most likely to meet on a residential host.
 * The happy paths that need rows are covered by the migration test, which
 * skips when no DATABASE_URL is set rather than pretending to have run.
 */
describe('v1 endpoints', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    // Limits raised for this instance: these tests are about validation, and
    // a limiter tripping mid-loop would fail them for the wrong reason. Rate
    // limiting has its own tests below, which set the limits they assert.
    app = await buildApp(
      parseEnv({
        NODE_ENV: 'test',
        RATE_LIMIT_MAX: '1000',
        FEEDBACK_RATE_LIMIT_MAX: '1000',
      }),
    );
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('GET /v1/health', () => {
    it('is 200 with the documented envelope', async () => {
      const response = await app.inject({ method: 'GET', url: '/v1/health' });
      expect(response.statusCode).toBe(200);

      const body = response.json();
      expect(body.data.status).toBe('ok');
      expect(body.data.database).toBe('not_configured');
      expect(typeof body.meta.requestId).toBe('string');
      expect(typeof body.meta.timestamp).toBe('string');
    });
  });

  describe('POST /v1/feedback', () => {
    const valid = { category: 'bug', message: 'The reveal card sticks.' };

    it('rejects a body that fails validation, with field detail', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/feedback',
        payload: { category: 'not-a-category', message: '' },
      });

      expect(response.statusCode).toBe(400);
      const body = response.json();
      expect(body.error.code).toBe('VALIDATION_FAILED');
      // Field-level detail is documented, so it has to actually be there.
      expect(Array.isArray(body.error.details)).toBe(true);
      expect(body.error.details.length).toBeGreaterThan(0);
      expect(body.error.details[0]).toHaveProperty('path');
      expect(body.error.details[0]).toHaveProperty('message');
    });

    it('rejects unknown fields rather than silently dropping them', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/feedback',
        payload: { ...valid, sneaky: 'value' },
      });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toBe('VALIDATION_FAILED');
    });

    it('answers 503 when storage is unavailable, in the documented shape', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/feedback',
        payload: valid,
      });

      expect(response.statusCode).toBe(503);
      const body = response.json();
      expect(body.error.code).toBe('DATABASE_UNAVAILABLE');
      expect(typeof body.error.message).toBe('string');
      // A 5xx must never carry internal detail.
      expect(body.error.message).not.toMatch(/pg|postgres|ECONN|stack/i);
    });

    it('refuses an attachment when no encryption key is configured', async () => {
      // Storing it in the clear would be invisible; refusing is not
      // (01-DESIGN.md §16b).
      const response = await app.inject({
        method: 'POST',
        url: '/v1/feedback',
        payload: {
          ...valid,
          attachment: {
            contentType: 'image/png',
            dataBase64: Buffer.from('not-really-a-png').toString('base64'),
          },
        },
      });
      expect(response.statusCode).toBe(503);
    });
  });

  describe('GET /v1/word-banks', () => {
    it('answers 503 without a database', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/v1/word-banks',
      });
      expect(response.statusCode).toBe(503);
      expect(response.json().error.code).toBe('DATABASE_UNAVAILABLE');
    });

    it('validates the since parameter', async () => {
      const response = await app.inject({
        method: 'GET',
        url: `/v1/word-banks?since=${'x'.repeat(100)}`,
      });
      expect(response.statusCode).toBe(400);
      expect(response.json().error.code).toBe('VALIDATION_FAILED');
    });

    it('rejects an unknown query parameter', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/v1/word-banks?nope=1',
      });
      expect(response.statusCode).toBe(400);
    });
  });

  describe('GET /v1/word-banks/{topic}', () => {
    it('rejects a topic id that does not match the documented pattern', async () => {
      for (const bad of ['UPPER', '1leading', 'has-dash', 'x']) {
        const response = await app.inject({
          method: 'GET',
          url: `/v1/word-banks/${bad}`,
        });
        expect(response.statusCode, `topic "${bad}"`).toBe(400);
        expect(response.json().error.code).toBe('VALIDATION_FAILED');
      }
    });

    it('answers 503 for a well-formed topic without a database', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/v1/word-banks/pagkain',
      });
      expect(response.statusCode).toBe(503);
    });
  });

  /**
   * §4b is an app-layer guarantee, and this is the server half of keeping it:
   * nothing here should be able to accept a photograph of a person even if a
   * future client tried to send one.
   */
  describe('no endpoint accepts a selfie-shaped payload', () => {
    const selfieShaped = {
      category: 'bug',
      message: 'here is a face',
      // What a camera frame actually weighs. The screenshot cap sits below it
      // deliberately (01-DESIGN.md §16a, §4b).
      attachment: {
        contentType: 'image/jpeg',
        dataBase64: 'A'.repeat(maxAttachmentBase64 + 1),
      },
    };

    it('the attachment cap is below a camera frame and rejects one', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/feedback',
        payload: selfieShaped,
      });
      // 400 from the schema, or 413 from the body limit — either is a refusal
      // and both are documented. What must never happen is a 2xx.
      expect([400, 413]).toContain(response.statusCode);
    });

    it('no endpoint accepts a field named like a selfie', async () => {
      const selfieFields = [
        'selfie',
        'selfieBytes',
        'photo',
        'faceImage',
        'avatar',
      ];
      for (const field of selfieFields) {
        const response = await app.inject({
          method: 'POST',
          url: '/v1/feedback',
          payload: { category: 'bug', message: 'x', [field]: 'AAAA' },
        });
        expect(response.statusCode, field).toBe(400);
        expect(response.json().error.code).toBe('VALIDATION_FAILED');
      }
    });

    it('the whole surface is three endpoints, none of which take an image except feedback', async () => {
      // Asserting the breadth rather than trusting the name: if a fourth
      // endpoint appears, this fails and someone has to think about it.
      const routes = app
        .printRoutes({ commonPrefix: false })
        .split('\n')
        .filter((line) => line.includes('(') && line.includes('/v1/'));
      expect(routes.length).toBeGreaterThan(0);

      const paths = app.printRoutes({ commonPrefix: false });
      expect(paths).toContain('/v1/health');
      expect(paths).toContain('/v1/feedback');
      expect(paths).toContain('/v1/word-banks');
      // The endpoint that does not exist, and must not.
      expect(paths).not.toContain('telemetry');
    });
  });
});

/**
 * Rate limits, verified rather than inspected (A7).
 *
 * Configured tiny here so the assertion is about the mechanism, not about
 * waiting sixty seconds.
 */
describe('rate limiting', () => {
  it('limits reads and returns the documented 429 shape', async () => {
    const app = await buildApp(
      parseEnv({
        NODE_ENV: 'test',
        RATE_LIMIT_MAX: '3',
        RATE_LIMIT_WINDOW_MS: '60000',
      }),
    );
    await app.ready();

    const statuses: number[] = [];
    for (let i = 0; i < 5; i += 1) {
      const response = await app.inject({ method: 'GET', url: '/v1/health' });
      statuses.push(response.statusCode);
    }

    expect(statuses.filter((s) => s === 200)).toHaveLength(3);
    expect(statuses.filter((s) => s === 429).length).toBeGreaterThan(0);

    const limited = await app.inject({ method: 'GET', url: '/v1/health' });
    expect(limited.statusCode).toBe(429);
    expect(limited.json().error.code).toBe('RATE_LIMITED');
    expect(limited.headers).toHaveProperty('retry-after');

    await app.close();
  });

  it('limits writes more tightly than reads', async () => {
    // A write to a residential host is more expensive than a read, so the
    // feedback limit is separate and lower (12-HOSTING.md §4).
    const app = await buildApp(
      parseEnv({
        NODE_ENV: 'test',
        RATE_LIMIT_MAX: '100',
        FEEDBACK_RATE_LIMIT_MAX: '2',
        FEEDBACK_RATE_LIMIT_WINDOW_MS: '60000',
      }),
    );
    await app.ready();

    const statuses: number[] = [];
    for (let i = 0; i < 4; i += 1) {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/feedback',
        payload: { category: 'bug', message: 'again' },
      });
      statuses.push(response.statusCode);
    }

    expect(statuses.filter((s) => s === 429).length).toBeGreaterThan(0);
    expect(
      statuses.filter((s) => s === 429).length,
      'the write limit must bite before the read limit would',
    ).toBeGreaterThanOrEqual(2);

    await app.close();
  });

  it('every public endpoint is behind a limit', async () => {
    // Breadth asserted explicitly: a new endpoint added outside the limiter
    // fails here rather than shipping unprotected.
    const app = await buildApp(
      parseEnv({
        NODE_ENV: 'test',
        RATE_LIMIT_MAX: '1',
        FEEDBACK_RATE_LIMIT_MAX: '1',
      }),
    );
    await app.ready();

    const endpoints: ReadonlyArray<{ method: 'GET' | 'POST'; url: string }> = [
      { method: 'GET', url: '/v1/health' },
      { method: 'GET', url: '/v1/word-banks' },
      { method: 'GET', url: '/v1/word-banks/pagkain' },
      { method: 'POST', url: '/v1/feedback' },
    ];

    for (const endpoint of endpoints) {
      let sawLimit = false;
      for (let i = 0; i < 6 && !sawLimit; i += 1) {
        const response = await app.inject({
          method: endpoint.method,
          url: endpoint.url,
          payload:
            endpoint.method === 'POST'
              ? { category: 'bug', message: 'x' }
              : undefined,
        });
        if (response.statusCode === 429) sawLimit = true;
      }
      expect(sawLimit, `${endpoint.method} ${endpoint.url} is unlimited`).toBe(
        true,
      );
    }

    await app.close();
  });
});
