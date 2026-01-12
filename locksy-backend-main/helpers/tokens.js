/*
 * Token Management
 * Access tokens (short-lived) + Refresh tokens (long-lived with rotation)
 */

const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const RefreshToken = require('../models/refreshToken');

const ACCESS_TOKEN_EXPIRY = process.env.ACCESS_TOKEN_EXPIRY || '15m'; // 15 minutes
const REFRESH_TOKEN_EXPIRY_DAYS = parseInt(process.env.REFRESH_TOKEN_EXPIRY_DAYS || '7'); // 7 days
const REFRESH_TOKEN_COOKIE_AGE = parseInt(process.env.REFRESH_TOKEN_COOKIE_AGE || '604800000'); // 7 days in ms

/**
 * Generate access token (short-lived)
 */
function generateAccessToken(uid) {
  return new Promise((resolve, reject) => {
    const payload = { uid, type: 'access' };
    jwt.sign(
      payload,
      process.env.JWT_KEY,
      { expiresIn: ACCESS_TOKEN_EXPIRY },
      (err, token) => {
        if (err) {
          reject('No se pudo generar el access token');
        } else {
          resolve(token);
        }
      }
    );
  });
}

/**
 * Generate refresh token and store in database
 */
async function generateRefreshToken(uid, deviceId = null, userAgent = '', ipAddress = '') {
  // Generate random refresh token
  const refreshToken = crypto.randomBytes(64).toString('hex');
  const tokenHash = RefreshToken.hashToken(refreshToken);

  // Calculate expiration
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_EXPIRY_DAYS);

  // Store in database
  const refreshTokenDoc = new RefreshToken({
    user: uid,
    tokenHash,
    issuedAt: new Date(),
    expiresAt,
    deviceId: deviceId || 'unknown',
    userAgent,
    ipAddress,
  });

  await refreshTokenDoc.save();

  return {
    refreshToken,
    expiresAt,
    cookieAge: REFRESH_TOKEN_COOKIE_AGE,
  };
}

/**
 * Verify and refresh access token
 * Implements token rotation (revokes old token, creates new one)
 */
async function refreshAccessToken(refreshToken, deviceId = null, userAgent = '', ipAddress = '') {
  try {
    // Find token by hash
    const tokenDoc = await RefreshToken.findByToken(refreshToken);

    if (!tokenDoc) {
      return { valid: false, error: 'Invalid refresh token' };
    }

    // Check if token is valid
    if (!tokenDoc.isValid()) {
      return { valid: false, error: 'Refresh token expired or revoked' };
    }

    const uid = tokenDoc.user.toString();

    // Revoke old token (rotation)
    await tokenDoc.revoke();

    // Generate new access token
    const accessToken = await generateAccessToken(uid);

    // Generate new refresh token (rotation)
    const newRefreshTokenData = await generateRefreshToken(uid, deviceId, userAgent, ipAddress);

    return {
      valid: true,
      accessToken,
      refreshToken: newRefreshTokenData.refreshToken,
      expiresAt: newRefreshTokenData.expiresAt,
      cookieAge: newRefreshTokenData.cookieAge,
      uid,
    };
  } catch (error) {
    console.error('Error refreshing token:', error);
    return { valid: false, error: error.message };
  }
}

/**
 * Revoke refresh token
 */
async function revokeRefreshToken(refreshToken) {
  try {
    const tokenDoc = await RefreshToken.findByToken(refreshToken);
    if (tokenDoc) {
      await tokenDoc.revoke();
      return true;
    }
    return false;
  } catch (error) {
    console.error('Error revoking refresh token:', error);
    return false;
  }
}

/**
 * Revoke all refresh tokens for a user
 */
async function revokeAllRefreshTokens(uid) {
  try {
    const result = await RefreshToken.updateMany(
      { user: uid, revoked: false },
      { revoked: true, revokedAt: new Date() }
    );
    return result.modifiedCount;
  } catch (error) {
    console.error('Error revoking all refresh tokens:', error);
    return 0;
  }
}

/**
 * Revoke refresh tokens for a specific device
 */
async function revokeDeviceRefreshTokens(uid, deviceId) {
  try {
    const result = await RefreshToken.updateMany(
      { user: uid, deviceId, revoked: false },
      { revoked: true, revokedAt: new Date() }
    );
    return result.modifiedCount;
  } catch (error) {
    console.error('Error revoking device refresh tokens:', error);
    return 0;
  }
}

/**
 * Verify access token
 */
function verifyAccessToken(token) {
  try {
    const decoded = jwt.verify(token, process.env.JWT_KEY);
    if (decoded.type !== 'access') {
      return [false, null];
    }
    return [true, decoded.uid];
  } catch (error) {
    return [false, null];
  }
}

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  refreshAccessToken,
  revokeRefreshToken,
  revokeAllRefreshTokens,
  revokeDeviceRefreshTokens,
  verifyAccessToken,
  ACCESS_TOKEN_EXPIRY,
  REFRESH_TOKEN_COOKIE_AGE,
};

