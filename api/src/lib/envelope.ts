import { randomUUID } from 'node:crypto';
import type { FastifyReply, FastifyRequest } from 'fastify';

/**
 * The two response shapes the contract documents, and the only two the API
 * ever sends: `{ data, meta }` on success, `{ error: { code, message } }` on
 * failure (CLAUDE.md §Conventions).
 *
 * Both live here so a handler cannot invent a third by accident — which is
 * the most common way a contract and an implementation drift apart.
 */
export interface Meta {
  readonly requestId: string;
  readonly timestamp: string;
}

export const buildMeta = (request: FastifyRequest): Meta => ({
  requestId: request.id ?? randomUUID(),
  timestamp: new Date().toISOString(),
});

export const sendData = <T>(
  request: FastifyRequest,
  reply: FastifyReply,
  data: T,
  status = 200,
): FastifyReply =>
  reply.status(status).send({ data, meta: buildMeta(request) });

export interface ErrorDetail {
  readonly path: string;
  readonly message: string;
}

/** Stable, machine-readable codes. Clients branch on these, not on prose. */
export const ErrorCode = {
  validationFailed: 'VALIDATION_FAILED',
  notFound: 'NOT_FOUND',
  methodNotAllowed: 'METHOD_NOT_ALLOWED',
  payloadTooLarge: 'PAYLOAD_TOO_LARGE',
  unsupportedMedia: 'UNSUPPORTED_MEDIA_TYPE',
  rateLimited: 'RATE_LIMITED',
  databaseUnavailable: 'DATABASE_UNAVAILABLE',
  internal: 'INTERNAL_ERROR',
} as const;

export type ErrorCodeValue = (typeof ErrorCode)[keyof typeof ErrorCode];

export const sendError = (
  reply: FastifyReply,
  status: number,
  code: ErrorCodeValue,
  message: string,
  details?: readonly ErrorDetail[],
): FastifyReply =>
  reply.status(status).send({
    error: details === undefined ? { code, message } : { code, message, details },
  });
