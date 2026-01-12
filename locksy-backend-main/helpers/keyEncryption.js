/*
 * Password-Based Key Encryption Helper
 * Encrypts/decrypts private keys using password-derived keys
 * Uses PBKDF2 for key derivation and AES-256-GCM for encryption
 */

const crypto = require('crypto');

// Constants for key derivation and encryption
const PBKDF2_ITERATIONS = 100000; // High iteration count for security
const KEY_LENGTH = 32; // 256 bits for AES-256
const SALT_LENGTH = 16; // 128 bits for salt
const IV_LENGTH = 12; // 96 bits for GCM IV
const TAG_LENGTH = 16; // 128 bits for GCM auth tag
const ALGORITHM = 'aes-256-gcm';

/**
 * Derive encryption key from password using PBKDF2
 * @param {string} password - User's password
 * @param {Buffer} salt - Salt for key derivation
 * @returns {Buffer} - Derived key (32 bytes for AES-256)
 */
function deriveKeyFromPassword(password, salt) {
  return crypto.pbkdf2Sync(
    password,
    salt,
    PBKDF2_ITERATIONS,
    KEY_LENGTH,
    'sha256'
  );
}

/**
 * Encrypt private key with password-derived key
 * @param {string} privateKey - Private key in PEM format
 * @param {string} password - User's password
 * @returns {string} - Encrypted private key (base64 encoded: salt + iv + tag + ciphertext)
 */
function encryptPrivateKey(privateKey, password) {
  if (!privateKey || !password) {
    throw new Error('Private key and password are required');
  }

  // Generate random salt and IV
  const salt = crypto.randomBytes(SALT_LENGTH);
  const iv = crypto.randomBytes(IV_LENGTH);

  // Derive encryption key from password
  const key = deriveKeyFromPassword(password, salt);

  // Create cipher
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  // Encrypt private key
  let encrypted = cipher.update(privateKey, 'utf8');
  encrypted = Buffer.concat([encrypted, cipher.final()]);

  // Get authentication tag
  const tag = cipher.getAuthTag();

  // Combine: salt (16) + iv (12) + tag (16) + encrypted data
  const combined = Buffer.concat([salt, iv, tag, encrypted]);

  // Return base64 encoded
  return combined.toString('base64');
}

/**
 * Decrypt private key using password
 * @param {string} encryptedPrivateKey - Encrypted private key (base64 encoded)
 * @param {string} password - User's password
 * @returns {string} - Decrypted private key in PEM format
 */
function decryptPrivateKey(encryptedPrivateKey, password) {
  if (!encryptedPrivateKey || !password) {
    throw new Error('Encrypted private key and password are required');
  }

  try {
    // Decode from base64
    const combined = Buffer.from(encryptedPrivateKey, 'base64');

    // Extract components
    const salt = combined.slice(0, SALT_LENGTH);
    const iv = combined.slice(SALT_LENGTH, SALT_LENGTH + IV_LENGTH);
    const tag = combined.slice(
      SALT_LENGTH + IV_LENGTH,
      SALT_LENGTH + IV_LENGTH + TAG_LENGTH
    );
    const encrypted = combined.slice(SALT_LENGTH + IV_LENGTH + TAG_LENGTH);

    // Derive decryption key from password
    const key = deriveKeyFromPassword(password, salt);

    // Create decipher
    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(tag);

    // Decrypt
    let decrypted = decipher.update(encrypted);
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    return decrypted.toString('utf8');
  } catch (error) {
    throw new Error(`Failed to decrypt private key: ${error.message}`);
  }
}

module.exports = {
  encryptPrivateKey,
  decryptPrivateKey,
};



