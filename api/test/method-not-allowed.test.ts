import { readFileSync } from 'node:fs';
import { METHODS, request as httpRequest } from 'node:http';
import type { AddressInfo } from 'node:net';
import { fileURLToPath } from 'node:url';

import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { parse } from 'yaml';

import { buildApp } from '../src/app.js';
import { parseEnv } from '../src/env.js';

// Exhaustive and generated from the contract rather than hand-listed, so it
// cannot drift as paths are added. For EVERY path in openapi.yaml, every HTTP
// method the spec does not document must answer 405 with an accurate Allow
// header.
//
// This exists because the first Schemathesis run found 404-instead-of-405, and
// fixing it took two separate code paths — the not-found handler and the error
// handler. When a routing fix needs two locations, assume a third.
//
// Deliberately uses a raw socket rather than supertest: supertest cannot send a
// non-standard verb, and the QUERY case failed during request parsing, before
// any handler ran. A test that cannot express the failing input cannot catch it.

const specPath = fileURLToPath(new URL('../openapi.yaml', import.meta.url));

interface OpenApiDocument {
  readonly paths: Record<string, Record<string, unknown>>;
}

const spec = parse(readFileSync(specPath, 'utf8')) as OpenApiDocument;

/** Keys under a path item that are operations rather than metadata. */
const OPERATION_KEYS = new Set([
  'get',
  'put',
  'post',
  'delete',
  'options',
  'head',
  'patch',
  'trace',
]);

/**
 * Methods to probe. Beyond the standard verbs this includes QUERY — the case
 * that bypassed the not-found handler — plus PROPFIND and BREW, because a
 * router can treat an unknown verb differently from a known-but-unrouted one.
 */
const PROBE_METHODS = [
  'GET',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'OPTIONS',
  'HEAD',
  'TRACE',
  'QUERY',
  'PROPFIND',
  'BREW',
] as const;

/**
 * Node's HTTP parser only recognises the 35 methods in `http.METHODS`. Anything
 * else — BREW, here — is rejected by llhttp with 400 before a single line of
 * application code runs, so 405 is not reachable for it at any layer we own.
 * Split rather than dropped, so the boundary is asserted instead of assumed.
 */
const DELIVERABLE_METHODS = PROBE_METHODS.filter((method) =>
  METHODS.includes(method),
);
const UNRECOGNISED_METHODS = PROBE_METHODS.filter(
  (method) => !METHODS.includes(method),
);

const documentedPaths = Object.entries(spec.paths).map(([path, item]) => {
  const documented = Object.keys(item)
    .filter((key) => OPERATION_KEYS.has(key.toLowerCase()))
    .map((key) => key.toUpperCase());

  // Fastify answers HEAD for any GET route, so HEAD is routable whenever GET
  // is documented even though the spec does not list it.
  const allowed = new Set(documented);
  if (allowed.has('GET')) allowed.add('HEAD');

  return { path, documented, allowed: [...allowed].sort() };
});

interface RawResponse {
  readonly status: number;
  readonly allow: readonly string[];
  readonly body: unknown;
}

const send = (
  port: number,
  method: string,
  path: string,
): Promise<RawResponse> =>
  new Promise((resolve, reject) => {
    const req = httpRequest(
      {
        host: '127.0.0.1',
        port,
        method,
        path,
        headers: { 'content-type': 'application/json' },
        // A fresh socket per request: an unrecognised method makes Node destroy
        // the connection, and a pooled agent would surface that as ECONNRESET
        // on a later, unrelated request.
        agent: false,
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => {
          const raw = Buffer.concat(chunks).toString('utf8');
          let body: unknown = raw;
          try {
            body = JSON.parse(raw) as unknown;
          } catch {
            // Left as the raw string; assertions report it as-is.
          }
          resolve({
            status: res.statusCode ?? 0,
            allow: (res.headers.allow ?? '')
              .split(',')
              .map((value) => value.trim())
              .filter((value) => value.length > 0)
              .sort(),
            body,
          });
        });
      },
    );
    req.on('error', reject);
    req.end();
  });

describe('undocumented methods on documented paths', () => {
  let app: FastifyInstance;
  let port: number;

  beforeAll(async () => {
    app = await buildApp(parseEnv({ NODE_ENV: 'test' }));
    await app.listen({ port: 0, host: '127.0.0.1' });
    port = (app.server.address() as AddressInfo).port;
  });

  afterAll(async () => {
    await app.close();
  });

  it('reads at least one path from openapi.yaml', () => {
    expect(documentedPaths.length).toBeGreaterThan(0);
  });

  for (const { path, documented, allowed } of documentedPaths) {
    const undocumented = DELIVERABLE_METHODS.filter(
      (method) => !allowed.includes(method),
    );

    describe(`${path} (spec documents ${documented.join(', ')})`, () => {
      for (const method of undocumented) {
        it(`${method} is 405 with an accurate Allow header`, async () => {
          const response = await send(port, method, path);

          expect(response.status).toBe(405);
          // Allow must list exactly what is routable, so a client can act on
          // it rather than guess.
          expect(response.allow).toEqual(allowed);

          if (method === 'HEAD') {
            // RFC 9110: a HEAD response carries no body. The status and the
            // Allow header are the whole answer, and asserting a body here
            // would be asserting that the server break HTTP.
            expect(response.body).toBe('');
            return;
          }

          expect(response.body).toEqual({
            error: {
              code: 'METHOD_NOT_ALLOWED',
              message: expect.stringContaining(method) as unknown as string,
            },
          });
        });
      }

      for (const method of allowed) {
        it(`${method} is routable and is not 405`, async () => {
          const response = await send(port, method, path);
          expect(response.status).not.toBe(405);
        });
      }

      // Documents a real boundary found by this test: BREW returned 400, not
      // 405. That is Node's parser refusing an unrecognised method token, not
      // a routing defect — see DELIVERABLE_METHODS. Pinned so the behaviour is
      // explained rather than rediscovered.
      for (const method of UNRECOGNISED_METHODS) {
        it(`${method} is rejected by the HTTP parser before routing`, async () => {
          const response = await send(port, method, path);
          expect(response.status).toBe(400);
        });
      }
    });
  }
});
