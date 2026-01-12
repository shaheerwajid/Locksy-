/*
 * Server-Side Crypto Utilities
 * RSA Public Key Validation and Helpers
 * NOTE: Private keys are NEVER stored or handled on the server
 */

const crypto = require('crypto');

/**
 * Validate RSA public key format (PEM)
 * @param {string} pem - Public key in PEM format
 * @returns {boolean} - True if valid RSA public key
 */
function isValidPublicKey(pem) {
  if (!pem || typeof pem !== 'string') {
    return false;
  }

  // Basic PEM format check
  if (!pem.includes('-----BEGIN') || !pem.includes('-----END')) {
    return false;
  }

  try {
    // Try to create a public key object
    const publicKey = crypto.createPublicKey(pem);
    
    // Verify it's an RSA key
    if (publicKey.asymmetricKeyType !== 'rsa') {
      return false;
    }

    // Verify key size (should be at least 2048 bits)
    const keyDetails = publicKey.asymmetricKeyDetails;
    if (keyDetails && keyDetails.modulusLength < 2048) {
      return false;
    }

    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Extract public key info (for logging/validation)
 * @param {string} pem - Public key in PEM format
 * @returns {object|null} - Key info or null if invalid
 */
function getPublicKeyInfo(pem) {
  if (!isValidPublicKey(pem)) {
    return null;
  }

  try {
    const publicKey = crypto.createPublicKey(pem);
    return {
      type: publicKey.asymmetricKeyType,
      modulusLength: publicKey.asymmetricKeyDetails?.modulusLength || null,
    };
  } catch (error) {
    return null;
  }
}

/**
 * Validate encrypted message structure (server-side validation only)
 * Server cannot decrypt - only validates format
 * @param {string} ciphertext - Base64 encoded ciphertext
 * @returns {boolean} - True if format is valid
 */
function isValidCiphertext(ciphertext) {
  if (!ciphertext || typeof ciphertext !== 'string') {
    return false;
  }

  // Basic validation: should be base64 encoded string
  try {
    const decoded = Buffer.from(ciphertext, 'base64');
    // Minimum size check (encrypted data should be at least 100 bytes)
    // RSA 2048-bit produces 256 bytes, but we allow smaller for flexibility
    if (decoded.length < 100) {
      return false;
    }
    return true;
  } catch (error) {
    return false;
  }
}

module.exports = {
  isValidPublicKey,
  getPublicKeyInfo,
  isValidCiphertext,
};

