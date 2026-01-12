/*
 * General Helper Functions
 * NOTE: Encryption/decryption functions removed - encryption is now client-side only (E2E)
 * 
 * DEPRECATED: The encrypt/decrypt functions were used for password recovery links.
 * These should be replaced with JWT-based token system in the future.
 * For now, we keep a legacy compatibility function but mark it as deprecated.
 */

// LEGACY: Password recovery link encoding (DEPRECATED - should use JWT tokens)
// This is NOT cryptographic encryption - just URL-safe encoding for recovery links
// TODO: Replace with JWT-based password recovery tokens
const crypto = require('crypto');

/**
 * DEPRECATED: Legacy password recovery link encoding
 * This is NOT secure encryption - it's just encoding for URL compatibility
 * Replace with JWT tokens for password recovery instead
 * @deprecated Use JWT tokens for password recovery instead
 */
function encodeRecoveryLink(text) {
  // Simple base64 encoding for URL compatibility (NOT encryption)
  return Buffer.from(text).toString('base64url');
}

/**
 * DEPRECATED: Legacy password recovery link decoding
 * @deprecated Use JWT token verification instead
 */
function decodeRecoveryLink(encoded) {
  try {
    return Buffer.from(encoded, 'base64url').toString('utf-8');
  } catch (error) {
    return null;
  }
}

// Export functions for backward compatibility
// NOTE: These are kept for password recovery flow but should be replaced
module.exports = {
  // Keep legacy functions for password recovery (to be replaced)
  encrypt: encodeRecoveryLink, // DEPRECATED - backward compat only
  decrypt: decodeRecoveryLink, // DEPRECATED - backward compat only
};

/*
String.prototype.getBytes = function () {
    var bytes = [];
    for (var i = 0; i < this.length; ++i) {
        bytes.push(this.charCodeAt(i));
    }
    return bytes;
};
*/