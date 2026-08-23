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
});

export type Env = z.infer<typeof envSchema>;

export const parseEnv = (source: NodeJS.ProcessEnv = process.env): Env =>
  envSchema.parse(source);
