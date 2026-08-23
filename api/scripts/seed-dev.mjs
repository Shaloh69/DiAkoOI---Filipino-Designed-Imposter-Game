#!/usr/bin/env node
// Publishes a tiny word bank so the read endpoints have something to serve.
//
// **Development and contract testing only.** Without a published version
// `GET /v1/word-banks/{topic}` answers 404 to everything, and schemathesis
// warns that it "repeatedly returned 404, preventing tests from reaching your
// API's core logic" — a contract run that never reaches a 200 has not tested
// the 200.
//
// The content here is deliberately obvious scaffolding, not authored words:
// the real bank is a human deliverable (docs/02-CONTENT-PH.md) and nothing
// generated should be mistakable for it.
import { Pool } from 'pg';

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error('DATABASE_URL is not set');
  process.exit(1);
}

const version = process.env.SEED_VERSION ?? 'dev-seed';
const topics = ['pagkain', 'aktor', 'kpop'];

const pool = new Pool({ connectionString });

try {
  await pool.query('BEGIN');

  // Exactly one current version is enforced by a partial unique index, so the
  // old one has to be stood down before the new one is raised.
  await pool.query('UPDATE word_bank_versions SET is_current = false');
  await pool.query(
    `INSERT INTO word_bank_versions (content_version, is_current)
     VALUES ($1, true)
     ON CONFLICT (content_version) DO UPDATE SET is_current = true`,
    [version],
  );

  for (const topicId of topics) {
    for (let i = 0; i < 5; i += 1) {
      await pool.query(
        `INSERT INTO word_bank_entries
           (content_version, topic_id, word, clue_tight, clue_standard, clue_loose)
         VALUES ($1,$2,$3,$4,$5,$6)
         ON CONFLICT DO NOTHING`,
        [
          version,
          topicId,
          `DEV ${topicId} ${i}`,
          `dev tight ${i}`,
          `dev standard ${i}`,
          `dev loose ${i}`,
        ],
      );
    }
  }

  await pool.query('COMMIT');
  console.log(`seeded ${version}: ${topics.length} topics x 5 words`);
} catch (error) {
  await pool.query('ROLLBACK');
  console.error(error);
  process.exit(1);
} finally {
  await pool.end();
}
