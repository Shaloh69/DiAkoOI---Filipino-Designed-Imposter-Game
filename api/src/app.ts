import rateLimit from '@fastify/rate-limit';
import Fastify, {
  type FastifyError,
  type FastifyInstance,
  type FastifyReply,
  type FastifyRequest,
} from 'fastify';

import type { Env } from './env.js';
import { createPool } from './lib/database.js';
import { registerHealthRoute } from './routes/health.js';

const ROUTABLE_METHODS = [
  'DELETE',
  'GET',
  'HEAD',
  'OPTIONS',
  'PATCH',
  'POST',
  'PUT',
] as const;

/**
 * A documented path reached with an undocumented method is 405, not 404.
 * Fastify answers 404 for both, which the contract tests correctly flag.
 */
const respondNotRoutable = (
  app: FastifyInstance,
  request: FastifyRequest,
  reply: FastifyReply,
): void => {
  const url = request.url.split('?')[0] ?? request.url;
  const allowed = ROUTABLE_METHODS.filter(
    (method) => method !== request.method && app.hasRoute({ method, url }),
  );

  if (allowed.length > 0) {
    reply
      .status(405)
      .header('allow', allowed.join(', '))
      .send({
        error: {
          code: 'METHOD_NOT_ALLOWED',
          message: `Method ${request.method} is not allowed for ${url}`,
        },
      });
    return;
  }

  reply
    .status(404)
    .send({ error: { code: 'NOT_FOUND', message: 'Route not found' } });
};

const isUnroutableMethod = (
  app: FastifyInstance,
  request: FastifyRequest,
): boolean => {
  const url = request.url.split('?')[0] ?? request.url;
  const method = request.method as (typeof ROUTABLE_METHODS)[number];

  return (
    !app.hasRoute({ method, url }) &&
    ROUTABLE_METHODS.some((other) => app.hasRoute({ method: other, url }))
  );
};

export const buildApp = async (env: Env): Promise<FastifyInstance> => {
  const app: FastifyInstance = Fastify({
    logger: env.NODE_ENV !== 'test',
    // Trust the Cloudflare tunnel in front of the public API.
    trustProxy: true,
  });

  await app.register(rateLimit, {
    max: env.RATE_LIMIT_MAX,
    timeWindow: env.RATE_LIMIT_WINDOW_MS,
  });

  const pool = createPool(env.DATABASE_URL);
  const startedAt = Date.now();

  app.addHook('onClose', async () => {
    await pool?.end();
  });

  // Every error leaves as { error: { code, message } } — the documented shape.
  // 5xx messages come from the status, never from the thrown error, so an
  // internal message can never leak to a caller.
  app.setErrorHandler((error: FastifyError, request, reply) => {
    // Methods Fastify parses but we do not route (QUERY, for example) fail
    // during request handling rather than reaching the not-found handler,
    // surfacing an FST_ERR_* code and the wrong status. Answer 405 instead.
    if (isUnroutableMethod(app, request)) {
      respondNotRoutable(app, request, reply);
      return;
    }

    const statusCode = error.statusCode ?? 500;
    const code =
      error.code ?? (statusCode === 429 ? 'RATE_LIMITED' : 'INTERNAL_ERROR');
    const message = statusCode >= 500 ? 'Internal server error' : error.message;

    reply.status(statusCode).send({ error: { code, message } });
  });

  app.setNotFoundHandler((request, reply) => {
    respondNotRoutable(app, request, reply);
  });

  registerHealthRoute(app, { pool, startedAt });

  return app;
};
