/**
 * OTP Helper Functions
 * Generate and validate OTP codes for email verification
 */

/**
 * Generate a 6-digit OTP code
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Check if OTP is expired (15 minutes validity)
 */
function isOTPExpired(expiresAt) {
  if (!expiresAt) return true;
  return new Date() > new Date(expiresAt);
}

/**
 * Create OTP expiration date (15 minutes from now)
 */
function getOTPExpiration() {
  const expiresAt = new Date();
  expiresAt.setMinutes(expiresAt.getMinutes() + 15);
  return expiresAt;
}

module.exports = {
  generateOTP,
  isOTPExpired,
  getOTPExpiration,
};

