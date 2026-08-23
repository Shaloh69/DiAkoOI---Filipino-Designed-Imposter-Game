-- DiAkoOi schema, v1.
--
-- What is deliberately absent: any table for telemetry, and any column that
-- could hold a photograph of a person. Selfies live in device memory only
-- (01-DESIGN.md §4b) and v1 collects no telemetry at all (ADR 0015).

CREATE TABLE IF NOT EXISTS schema_migrations (
  version     TEXT PRIMARY KEY,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Attachments (01-DESIGN.md §16b)
--
-- Content-addressed by SHA-256: dedup, integrity, no collisions. **That is
-- not the security control.** The bytes are encrypted at rest with AES-256-GCM
-- and the key never enters this table — only the per-object nonce and tag,
-- which are useless without it.
CREATE TABLE IF NOT EXISTS attachments (
  sha256        CHAR(64) PRIMARY KEY,
  content_type  TEXT        NOT NULL
                            CHECK (content_type IN ('image/png','image/jpeg','image/webp')),
  byte_length   INTEGER     NOT NULL CHECK (byte_length > 0),
  -- Ciphertext, nonce and auth tag. Storing the tag separately keeps the
  -- ciphertext column exactly the plaintext length, which makes a size check
  -- against the declared limit meaningful.
  ciphertext    BYTEA       NOT NULL,
  nonce         BYTEA       NOT NULL,
  auth_tag      BYTEA       NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Feedback (01-DESIGN.md §16a)
--
-- User-initiated and explicitly consented to, which is a different thing from
-- a party guest's face captured incidentally at onboarding. The separation is
-- the point: this pipeline must never become a reason to loosen §4b.
CREATE TABLE IF NOT EXISTS feedback (
  id                UUID PRIMARY KEY,
  category          TEXT        NOT NULL
                                CHECK (category IN ('bug','suggestion','content','other')),
  message           TEXT        NOT NULL CHECK (length(message) BETWEEN 1 AND 4000),
  app_version       TEXT,
  -- Device MODEL, never a device identifier. Nothing here distinguishes one
  -- installation from another.
  device_model      TEXT,
  contact_email     TEXT,
  -- When the user wrote it, which may be long before it was delivered: the
  -- app queues reports offline and retries (12-HOSTING.md §2c).
  occurred_at       TIMESTAMPTZ,
  received_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  attachment_sha256 CHAR(64)
                    REFERENCES attachments(sha256) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS feedback_received_at_idx
  ON feedback (received_at DESC);

-- ─────────────────────────────────────────────────────────────────────────
-- Word bank (01-DESIGN.md §13, §14)
--
-- The server copy is an UPDATE, not a dependency. The app ships a complete
-- bundle and plays a full game having never reached this table.
CREATE TABLE IF NOT EXISTS word_bank_versions (
  content_version TEXT PRIMARY KEY,
  published_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_current      BOOLEAN     NOT NULL DEFAULT false
);

-- Exactly one current version, enforced by the database rather than by
-- application discipline.
CREATE UNIQUE INDEX IF NOT EXISTS word_bank_versions_one_current
  ON word_bank_versions ((is_current)) WHERE is_current;

CREATE TABLE IF NOT EXISTS word_bank_entries (
  content_version   TEXT    NOT NULL REFERENCES word_bank_versions(content_version) ON DELETE CASCADE,
  topic_id          TEXT    NOT NULL CHECK (topic_id ~ '^[a-z][a-z0-9_]{1,31}$'),
  word              TEXT    NOT NULL CHECK (length(word) BETWEEN 1 AND 80),
  clue_tight        TEXT    NOT NULL CHECK (length(clue_tight) BETWEEN 1 AND 200),
  clue_standard     TEXT    NOT NULL CHECK (length(clue_standard) BETWEEN 1 AND 200),
  clue_loose        TEXT    NOT NULL CHECK (length(clue_loose) BETWEEN 1 AND 200),
  difficulty_rating SMALLINT NOT NULL DEFAULT 3 CHECK (difficulty_rating BETWEEN 1 AND 5),
  region            TEXT    NOT NULL DEFAULT 'national'
                            CHECK (region IN ('national','luzon','visayas','mindanao')),
  -- A word cannot repeat within a topic in one version: §13b forbids a repeat
  -- inside a session, and the bank is where that starts.
  PRIMARY KEY (content_version, topic_id, word)
);

CREATE INDEX IF NOT EXISTS word_bank_entries_topic_idx
  ON word_bank_entries (content_version, topic_id);
