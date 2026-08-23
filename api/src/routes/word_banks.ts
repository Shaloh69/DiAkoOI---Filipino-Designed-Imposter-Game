import type { FastifyInstance } from 'fastify';
import type { Pool } from 'pg';

import { ErrorCode, sendData, sendError } from '../lib/envelope.js';
import { wordBankParamsSchema, wordBankQuerySchema } from '../lib/schemas.js';

interface Deps {
  readonly pool: Pool | null;
}

interface SummaryRow {
  readonly topic_id: string;
  readonly word_count: string;
}

interface EntryRow {
  readonly topic_id: string;
  readonly word: string;
  readonly clue_tight: string;
  readonly clue_standard: string;
  readonly clue_loose: string;
  readonly difficulty_rating: number;
  readonly region: string;
}

const unavailable = 'The word bank is unavailable.';

/**
 * Word-bank delivery.
 *
 * **The server copy is an update, not a dependency** (CLAUDE.md §Hard rules).
 * A client that never reaches these endpoints plays a complete game from its
 * bundled bank, so every failure here is allowed to be silent on the app side.
 */
export const registerWordBankRoutes = (
  app: FastifyInstance,
  { pool }: Deps,
): void => {
  app.get('/v1/word-banks', async (request, reply) => {
    const query = wordBankQuerySchema.safeParse(request.query);
    if (!query.success) {
      return sendError(
        reply,
        400,
        ErrorCode.validationFailed,
        'The query parameters failed validation.',
        query.error.issues.map((issue) => ({
          path: issue.path.join('.') || '(root)',
          message: issue.message,
        })),
      );
    }

    if (pool === null) {
      return sendError(reply, 503, ErrorCode.databaseUnavailable, unavailable);
    }

    try {
      const version = await pool.query<{ content_version: string }>(
        'SELECT content_version FROM word_bank_versions WHERE is_current LIMIT 1',
      );
      const current = version.rows[0]?.content_version;
      if (current === undefined) {
        // No published bank yet. Null rather than an empty string: "" is not
        // a version, and a client comparing it against its bundled version
        // would be comparing against a value that never existed.
        return sendData(request, reply, {
          contentVersion: null,
          topics: [],
        });
      }

      // A matching `since` returns an empty topics array rather than a 304:
      // the client always gets a body it can parse, which is one fewer branch
      // in the offline-first path that matters most.
      if (query.data.since === current) {
        return sendData(request, reply, {
          contentVersion: current,
          topics: [],
        });
      }

      const summaries = await pool.query<SummaryRow>(
        `SELECT topic_id, COUNT(*)::text AS word_count
           FROM word_bank_entries
          WHERE content_version = $1
          GROUP BY topic_id
          ORDER BY topic_id`,
        [current],
      );

      return sendData(request, reply, {
        contentVersion: current,
        topics: summaries.rows.map((row) => ({
          topicId: row.topic_id,
          wordCount: Number(row.word_count),
          contentVersion: current,
        })),
      });
    } catch {
      return sendError(reply, 503, ErrorCode.databaseUnavailable, unavailable);
    }
  });

  app.get('/v1/word-banks/:topic', async (request, reply) => {
    const params = wordBankParamsSchema.safeParse(request.params);
    if (!params.success) {
      return sendError(
        reply,
        400,
        ErrorCode.validationFailed,
        'The topic id failed validation.',
        params.error.issues.map((issue) => ({
          path: issue.path.join('.') || '(root)',
          message: issue.message,
        })),
      );
    }

    if (pool === null) {
      return sendError(reply, 503, ErrorCode.databaseUnavailable, unavailable);
    }

    try {
      const version = await pool.query<{ content_version: string }>(
        'SELECT content_version FROM word_bank_versions WHERE is_current LIMIT 1',
      );
      const current = version.rows[0]?.content_version;
      if (current === undefined) {
        return sendError(
          reply,
          404,
          ErrorCode.notFound,
          'No word bank has been published.',
        );
      }

      const entries = await pool.query<EntryRow>(
        `SELECT topic_id, word, clue_tight, clue_standard, clue_loose,
                difficulty_rating, region
           FROM word_bank_entries
          WHERE content_version = $1 AND topic_id = $2
          ORDER BY word`,
        [current, params.data.topic],
      );

      if (entries.rows.length === 0) {
        return sendError(
          reply,
          404,
          ErrorCode.notFound,
          `No topic "${params.data.topic}" in the current word bank.`,
        );
      }

      return sendData(request, reply, {
        topicId: params.data.topic,
        contentVersion: current,
        words: entries.rows.map((row) => ({
          topicId: row.topic_id,
          word: row.word,
          clues: {
            tight: row.clue_tight,
            standard: row.clue_standard,
            loose: row.clue_loose,
          },
          difficultyRating: row.difficulty_rating,
          region: row.region,
        })),
      });
    } catch {
      return sendError(reply, 503, ErrorCode.databaseUnavailable, unavailable);
    }
  });
};
