import { z } from 'zod';

/**
 * Zod at every boundary (CLAUDE.md §Conventions), mirroring `openapi.yaml`.
 *
 * The spec is the contract and this is its runtime enforcement; a contract
 * test (`schemathesis`) is what keeps the two honest, because two hand-written
 * descriptions of the same shape drift silently otherwise.
 */
/**
 * Length in **code points**, which is what JSON Schema `maxLength` counts.
 *
 * JavaScript's `.length` counts UTF-16 code *units*, so every astral character
 * — every emoji, and scripts like 𝒎𝒂𝒕𝒉𝒆𝒎𝒂𝒕𝒊𝒄𝒂𝒍 italic — counts twice. Using
 * `.max()` directly made the implementation stricter than its own contract:
 * a 2,000-emoji message inside the documented 4,000 limit was rejected. The
 * contract test found it; a human writing feedback in emoji would have found
 * it too, and would have been told nothing useful.
 */
const codePoints = (value: string): number => [...value].length;

const maxCodePoints = (limit: number) =>
  (value: string): boolean => codePoints(value) <= limit;

/**
 * Postgres `TEXT` cannot hold a NUL byte, so one has to be refused at the
 * boundary. Letting it reach the insert produced a 503 that claimed the
 * database was unavailable when it was fine — a client data problem reported
 * as a server outage, which is the wrong status and the wrong signal.
 */
const noNulBytes = (value: string): boolean => !value.includes('\u0000');

const text = (limit: number) =>
  z
    .string()
    .refine(maxCodePoints(limit), `must be at most ${limit} characters`)
    .refine(noNulBytes, 'must not contain a NUL byte');

export const topicIdSchema = z
  .string()
  .regex(/^[a-z][a-z0-9_]{1,31}$/, 'must be a lowercase topic id');

/**
 * Media types a *screenshot* comes in.
 *
 * This list is a privacy boundary, not a convenience. Selfies never leave
 * device memory (01-DESIGN.md §4b); a feedback screenshot is something the
 * user deliberately chose to send, and the two must not be confusable.
 */
export const attachmentContentTypes = [
  'image/png',
  'image/jpeg',
  'image/webp',
] as const;

/**
 * ~2MB of base64, which is ~2.1MB of image.
 *
 * Sized so a screenshot of a phone screen fits comfortably and a camera
 * photograph does not. That is a deliberate ceiling, and a test asserts a
 * selfie-shaped payload is refused by it.
 */
export const maxAttachmentBase64 = 2_800_000;

/**
 * Canonical base64: four characters per three bytes, padded.
 *
 * Mirrors the `pattern` in `openapi.yaml`. A shorter or misaligned string
 * decodes to nothing, and the two descriptions have to agree or the contract
 * test finds the gap — which is exactly how this one was found.
 */
const base64Pattern =
  /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;

export const feedbackAttachmentSchema = z.object({
  contentType: z.enum(attachmentContentTypes),
  // Base64 is ASCII by definition, so code units and code points agree here
  // and a plain .max() is correct.
  dataBase64: z
    .string()
    .min(4)
    .max(maxAttachmentBase64)
    .regex(base64Pattern, 'must be canonical base64'),
});

export const feedbackRequestSchema = z
  .object({
    category: z.enum(['bug', 'suggestion', 'content', 'other']),
    message: text(4000).min(1),
    appVersion: text(32).optional(),
    // Device MODEL only. Never an identifier — nothing stored here
    // distinguishes one installation from another (01-DESIGN.md §16a).
    deviceModel: text(64).optional(),
    // Deliberately permissive, and matched to the contract rather than to an
    // idea of correctness. `openapi.yaml` says `format: email`, and Zod's
    // stricter check rejected addresses the spec accepts — an implementation
    // stricter than its own contract is a contract violation. The failure
    // mode also matters: this field exists so a user can be replied to, and
    // rejecting a real address is worse than accepting an unusable one.
    contactEmail: text(254)
      // Mirrors openapi.yaml exactly, and avoids \\s on purpose: Zod and
      // the contract-test validator disagree about which Unicode characters
      // are whitespace, which surfaced as an intermittent failure.
      .regex(/^[^@\u0000]+@[^@\u0000]+$/, 'must look like an email address')
      .optional(),
    attachment: feedbackAttachmentSchema.optional(),
    // `offset: true` because the contract says `format: date-time`, which is
    // RFC 3339 and permits a zone offset. Zod defaults to UTC-only, so a
    // perfectly valid `+08:00` from a phone in Manila was rejected — the
    // second place the implementation was stricter than its own spec.
    occurredAt: z.iso.datetime({ offset: true }).optional(),
  })
  // Rejecting unknown keys rather than stripping them: a client sending a
  // field we do not expect should be told, not silently half-processed.
  .strict();

export type FeedbackRequest = z.infer<typeof feedbackRequestSchema>;

export const wordBankQuerySchema = z
  .object({
    // Mirrors the ContentVersion schema in openapi.yaml. A version is
    // something the server generated and the client echoes back, so it has a
    // known shape — "any string" admitted control characters the
    // implementation refused, which is a contract mismatch either way.
    since: z
      .string()
      .regex(/^[A-Za-z0-9._-]{1,64}$/, 'must be a content version')
      .optional(),
  })
  .strict();

export const wordBankParamsSchema = z.object({ topic: topicIdSchema }).strict();
