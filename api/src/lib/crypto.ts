import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';

/**
 * Attachment storage, per 01-DESIGN.md §16b.
 *
 * **Two different things, and both are wanted.** Content addressing by
 * SHA-256 gives dedup, integrity and collision-free names — and is explicitly
 * *not* a security control, because hashing is one-way and hashing an image
 * destroys it. Encryption at rest is the actual protection.
 *
 * AES-256-GCM rather than CBC: it authenticates as well as encrypts, so a
 * tampered ciphertext fails to decrypt rather than returning plausible
 * garbage.
 */
export const sha256Hex = (bytes: Buffer): string =>
  createHash('sha256').update(bytes).digest('hex');

export interface SealedBytes {
  readonly ciphertext: Buffer;
  readonly nonce: Buffer;
  readonly authTag: Buffer;
}

const KEY_BYTES = 32;
const NONCE_BYTES = 12;

/**
 * Parses the configured key. Throws rather than defaulting: an attachment
 * encrypted with a fallback key is worse than one the server refused to
 * accept, because only the second is visible.
 */
export const parseKey = (hex: string): Buffer => {
  const key = Buffer.from(hex, 'hex');
  if (key.length !== KEY_BYTES) {
    throw new Error(
      `ATTACHMENT_KEY must be ${KEY_BYTES} bytes as hex (${KEY_BYTES * 2} characters)`,
    );
  }
  return key;
};

export const seal = (plaintext: Buffer, key: Buffer): SealedBytes => {
  const nonce = randomBytes(NONCE_BYTES);
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return { ciphertext, nonce, authTag: cipher.getAuthTag() };
};

export const open = (sealed: SealedBytes, key: Buffer): Buffer => {
  const decipher = createDecipheriv('aes-256-gcm', key, sealed.nonce);
  decipher.setAuthTag(sealed.authTag);
  return Buffer.concat([
    decipher.update(sealed.ciphertext),
    decipher.final(),
  ]);
};

/**
 * A short-lived signed URL for one attachment (§16b).
 *
 * The signature covers the hash AND the expiry, so neither can be edited
 * independently — extending the window means forging the signature.
 */
export const signAttachmentUrl = (
  sha256: string,
  expiresAtEpochSeconds: number,
  key: Buffer,
): string => {
  const payload = `${sha256}.${expiresAtEpochSeconds}`;
  const signature = createHash('sha256')
    .update(Buffer.concat([key, Buffer.from(payload, 'utf8')]))
    .digest('hex');
  return `/v1/attachments/${sha256}?expires=${expiresAtEpochSeconds}&sig=${signature}`;
};
