import { z } from 'zod';

/**
 * Zod at every boundary (CLAUDE.md §Conventions), mirroring `openapi.yaml`.
 *
 * The spec is the contract and this is its runtime enforcement; a contract
 * test (`schemathesis`) is what keeps the two honest, because two hand-written
 * descriptions of the same shape drift silently otherwise.
 */
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

export const feedbackAttachmentSchema = z.object({
  contentType: z.enum(attachmentContentTypes),
  dataBase64: z.string().min(1).max(maxAttachmentBase64),
});

export const feedbackRequestSchema = z
  .object({
    category: z.enum(['bug', 'suggestion', 'content', 'other']),
    message: z.string().min(1).max(4000),
    appVersion: z.string().max(32).optional(),
    // Device MODEL only. Never an identifier — nothing stored here
    // distinguishes one installation from another (01-DESIGN.md §16a).
    deviceModel: z.string().max(64).optional(),
    contactEmail: z.email().max(254).optional(),
    attachment: feedbackAttachmentSchema.optional(),
    occurredAt: z.iso.datetime().optional(),
  })
  // Rejecting unknown keys rather than stripping them: a client sending a
  // field we do not expect should be told, not silently half-processed.
  .strict();

export type FeedbackRequest = z.infer<typeof feedbackRequestSchema>;

export const wordBankQuerySchema = z
  .object({ since: z.string().min(1).max(64).optional() })
  .strict();

export const wordBankParamsSchema = z.object({ topic: topicIdSchema }).strict();
