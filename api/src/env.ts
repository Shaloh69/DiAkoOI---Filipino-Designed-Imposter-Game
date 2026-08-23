import { z } from 'zod';

// Zod at every boundary (CLAUDE.md §Conventions) — process.env is a boundary.
const envSchema = z.object({
  NODE_ENV: z
    .enum(['development', 'test', 'production'])
    .default('development'),
  API_PORT: z.coerce.number().int().positive().default(3000),
  API_HOST: z.string().min(1).default('0.0.0.0'),
  // Optional: the health probe reports `not_configured` rather than failing,
  // so the API scaffold runs without a database.
  DATABASE_URL: z.string().url().optional(),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(60),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(60_000),
  // Feedback is a write to a residential host, so it gets its own tighter
  // limit than reads do (12-HOSTING.md §4).
  FEEDBACK_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(5),
  FEEDBACK_RATE_LIMIT_WINDOW_MS: z.coerce
    .number()
    .int()
    .positive()
    .default(60_000),
  // AES-256 key as 64 hex characters. Optional so the scaffold runs without
  // one; when it is absent the API REFUSES attachments rather than storing
  // them in the clear (01-DESIGN.md §16b).
  ATTACHMENT_KEY: z
    .string()
    .regex(/^[0-9a-fA-F]{64}$/, 'must be 32 bytes as hex')
    .optional(),
  // Body cap. Below what a camera photograph needs and above what a phone
  // screenshot does.
  MAX_BODY_BYTES: z.coerce.number().int().positive().default(3_500_000),
});

export type Env = z.infer<typeof envSchema>;

/**
 * Parses process.env, treating an empty value as absent.
 *
 * Compose writes `VAR: ${VAR:-}` as an empty string rather than omitting the
 * key, and `''` is not `undefined` to Zod — so an unset optional secret failed
 * validation and took the container down on boot. Blank means "not set" here,
 * which is what every shell that produced it meant.
 */
export const parseEnv = (source: NodeJS.ProcessEnv = process.env): Env => {
  const cleaned: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(source)) {
    if (value === undefined || value === '') continue;
    cleaned[key] = value;
  }
  return envSchema.parse(cleaned);
};
