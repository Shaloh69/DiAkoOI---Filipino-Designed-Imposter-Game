import rateLimit from '@fastify/rate-limit';
import Fastify, {
  type FastifyError,
  type FastifyInstance,
  type FastifyReply,
  type FastifyRequest,
} from 'fastify';

import type { Env } from './env.js';
import { createPool } from './lib/database.js';
import { registerFeedbackRoute } from './routes/feedback.js';
import { registerHealthRoute } from './routes/health.js';
import { registerWordBankRoutes } from './routes/word_banks.js';

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
 * Every route pattern the app has registered, filled by an `onRoute` hook.
 *
 * `app.hasRoute` only matches a literal URL, so it cannot answer "is this
 * path routable under some other method" for a **parameterised** route:
 * `/v1/word-banks/pagkain` is not literally `/v1/word-banks/:topic`. Without
 * this, every parameterised path answered 404 where the contract says 405.
 */
interface RoutePattern {
  readonly method: string;
  readonly segments: readonly string[];
}

const isParam = (segment: string): boolean =>
  segment.startsWith(':') || segment.startsWith('*');

const matchesPattern = (
  pattern: RoutePattern,
  segments: readonly string[],
): boolean =>
  pattern.segments.length === segments.length &&
  pattern.segments.every(
    (part, index) => isParam(part) || part === segments[index],
  );

/**
 * A documented path reached with an undocumented method is 405, not 404.
 * Fastify answers 404 for both, which the contract tests correctly flag.
 */
const respondNotRoutable = (
  routes: readonly RoutePattern[],
  request: FastifyRequest,
  reply: FastifyReply,
): void => {
  const url = request.url.split('?')[0] ?? request.url;
  const segments = url.split('/').filter((part) => part.length > 0);
  const routable = new Set(
    routes
      .filter((pattern) => matchesPattern(pattern, segments))
      .map((pattern) => pattern.method),
  );
  const allowed = ROUTABLE_METHODS.filter(
    (method) => method !== request.method && routable.has(method),
  );

  if (allowed.length > 0) {
    reply.status(405).header('allow', allowed.join(', ')).send({
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
  routes: readonly RoutePattern[],
  request: FastifyRequest,
): boolean => {
  const url = request.url.split('?')[0] ?? request.url;
  const segments = url.split('/').filter((part) => part.length > 0);
  const matching = routes.filter((pattern) =>
    matchesPattern(pattern, segments),
  );

  return (
    matching.length > 0 &&
    !matching.some((pattern) => pattern.method === request.method)
  );
};

export const buildApp = async (env: Env): Promise<FastifyInstance> => {
  const app: FastifyInstance = Fastify({
    logger: env.NODE_ENV !== 'test',
    // Trust the Cloudflare tunnel in front of the public API.
    trustProxy: true,
    // Fastify answers an oversize body with 413 before a handler runs, which
    // is what the contract documents.
    bodyLimit: env.MAX_BODY_BYTES,
  });

  await app.register(rateLimit, {
    max: env.RATE_LIMIT_MAX,
    timeWindow: env.RATE_LIMIT_WINDOW_MS,
  });

  const routes: RoutePattern[] = [];
  app.addHook('onRoute', (route) => {
    const methods = Array.isArray(route.method) ? route.method : [route.method];
    const segments = route.url.split('/').filter((part) => part.length > 0);
    for (const method of methods) routes.push({ method, segments });
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
    if (isUnroutableMethod(routes, request)) {
      respondNotRoutable(routes, request, reply);
      return;
    }

    const statusCode = error.statusCode ?? 500;
    // Map Fastify's own codes onto the documented vocabulary. A client
    // branching on `code` should never see an FST_ERR_* string, because that
    // is not in the contract.
    const code =
      statusCode === 429
        ? 'RATE_LIMITED'
        : statusCode === 413
          ? 'PAYLOAD_TOO_LARGE'
          : statusCode === 415
            ? 'UNSUPPORTED_MEDIA_TYPE'
            : statusCode === 400
              ? 'VALIDATION_FAILED'
              : statusCode >= 500
                ? 'INTERNAL_ERROR'
                : (error.code ?? 'INTERNAL_ERROR');
    const message = statusCode >= 500 ? 'Internal server error' : error.message;

    reply.status(statusCode).send({ error: { code, message } });
  });

  app.setNotFoundHandler((request, reply) => {
    respondNotRoutable(routes, request, reply);
  });

  registerHealthRoute(app, { pool, startedAt });
  registerWordBankRoutes(app, { pool });
  // Writes get their own, tighter limit — see FEEDBACK_RATE_LIMIT_MAX.
  await app.register(async (scope) => {
    await scope.register(rateLimit, {
      max: env.FEEDBACK_RATE_LIMIT_MAX,
      timeWindow: env.FEEDBACK_RATE_LIMIT_WINDOW_MS,
    });
    registerFeedbackRoute(scope, {
      pool,
      attachmentKeyHex: env.ATTACHMENT_KEY,
    });
  });

  return app;
};
