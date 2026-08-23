import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type { Pool } from 'pg';

import { parseKey, seal, sha256Hex } from '../lib/crypto.js';
import { ErrorCode, sendData, sendError } from '../lib/envelope.js';
import { feedbackRequestSchema } from '../lib/schemas.js';

/**
 * Postgres SQLSTATE class 22 is "data exception" — a value the database
 * cannot represent. That is the CLIENT's problem, not an outage, and
 * reporting it as one sends a caller away to retry something that will never
 * work while hiding a real bug behind a plausible message.
 */
const isDataException = (error: unknown): boolean =>
  typeof error === 'object' &&
  error !== null &&
  'code' in error &&
  typeof (error as { code: unknown }).code === 'string' &&
  (error as { code: string }).code.startsWith('22');

/**
 * Normalises any RFC 3339 instant to UTC.
 *
 * The contract says `format: date-time`, which permits offsets up to ±23:59.
 * Postgres TIMESTAMPTZ does not — `+22:48` is a valid timestamp the database
 * refuses. The offset carries nothing we need beyond the instant, so it is
 * converted rather than rejected.
 */
const toUtc = (value: string | undefined): string | null => {
  if (value === undefined) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
};

interface Deps {
  readonly pool: Pool | null;
  readonly attachmentKeyHex: string | undefined;
}

/**
 * POST /v1/feedback — user-initiated and explicitly consented to.
 *
 * A screenshot the user chose to attach is a different consent model from a
 * party guest's face captured incidentally at onboarding, and this pipeline
 * must never become a reason to loosen §4b (01-DESIGN.md §16a).
 */
export const registerFeedbackRoute = (
  app: FastifyInstance,
  { pool, attachmentKeyHex }: Deps,
): void => {
  app.post('/v1/feedback', async (request, reply) => {
    const parsed = feedbackRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      return sendError(
        reply,
        400,
        ErrorCode.validationFailed,
        'The request body failed validation.',
        parsed.error.issues.map((issue) => ({
          path: issue.path.join('.') || '(root)',
          message: issue.message,
        })),
      );
    }

    if (pool === null) {
      // The app treats this exactly like being offline: it queues the report
      // and retries later, with no dialog (12-HOSTING.md §2c).
      return sendError(
        reply,
        503,
        ErrorCode.databaseUnavailable,
        'Feedback storage is unavailable. Try again later.',
      );
    }

    const body = parsed.data;
    let attachmentSha256: string | undefined;

    if (body.attachment !== undefined) {
      if (attachmentKeyHex === undefined) {
        // Refusing beats storing it in the clear. An attachment written
        // unencrypted because a key was missing is invisible; a 503 is not.
        return sendError(
          reply,
          503,
          ErrorCode.databaseUnavailable,
          'Attachment storage is unavailable.',
        );
      }

      const bytes = Buffer.from(body.attachment.dataBase64, 'base64');
      if (bytes.length === 0) {
        return sendError(
          reply,
          400,
          ErrorCode.validationFailed,
          'The attachment was not valid base64.',
          [{ path: 'attachment.dataBase64', message: 'not decodable' }],
        );
      }

      // Content-addressed for dedup and integrity; encrypted because THAT is
      // the security control (01-DESIGN.md §16b).
      attachmentSha256 = sha256Hex(bytes);
      const sealed = seal(bytes, parseKey(attachmentKeyHex));

      try {
        await pool.query(
          `INSERT INTO attachments
             (sha256, content_type, byte_length, ciphertext, nonce, auth_tag)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (sha256) DO NOTHING`,
          [
            attachmentSha256,
            body.attachment.contentType,
            bytes.length,
            sealed.ciphertext,
            sealed.nonce,
            sealed.authTag,
          ],
        );
      } catch (error) {
        if (isDataException(error)) {
          return sendError(
            reply,
            400,
            ErrorCode.validationFailed,
            'The attachment contained a value the server cannot store.',
          );
        }
        return sendError(
          reply,
          503,
          ErrorCode.databaseUnavailable,
          'Attachment storage is unavailable.',
        );
      }
    }

    const id = randomUUID();
    try {
      const result = await pool.query<{ received_at: Date }>(
        `INSERT INTO feedback
           (id, category, message, app_version, device_model, contact_email,
            occurred_at, attachment_sha256)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
         RETURNING received_at`,
        [
          id,
          body.category,
          body.message,
          body.appVersion ?? null,
          body.deviceModel ?? null,
          body.contactEmail ?? null,
          toUtc(body.occurredAt),
          attachmentSha256 ?? null,
        ],
      );

      return sendData(
        request,
        reply,
        {
          id,
          receivedAt:
            result.rows[0]?.received_at.toISOString() ??
            new Date().toISOString(),
          ...(attachmentSha256 === undefined ? {} : { attachmentSha256 }),
        },
        201,
      );
    } catch (error) {
      if (isDataException(error)) {
        return sendError(
          reply,
          400,
          ErrorCode.validationFailed,
          'The report contained a value the server cannot store.',
        );
      }
      return sendError(
        reply,
        503,
        ErrorCode.databaseUnavailable,
        'Feedback storage is unavailable. Try again later.',
      );
    }
  });
};
