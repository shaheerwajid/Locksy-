/*
 * Refresh Token Model
 * Stores hashed refresh tokens with device tracking
 */

const { Schema, model } = require('mongoose');
const crypto = require('crypto');

const RefreshTokenSchema = Schema({
  user: {
    type: Schema.Types.ObjectId,
    ref: 'Usuario',
    required: true,
    index: true,
  },
  tokenHash: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  issuedAt: {
    type: Date,
    default: Date.now,
    required: true,
  },
  expiresAt: {
    type: Date,
    required: true,
    index: { expireAfterSeconds: 0 }, // TTL index for automatic expiration
  },
  revoked: {
    type: Boolean,
    default: false,
    index: true,
  },
  revokedAt: {
    type: Date,
    default: null,
  },
  deviceId: {
    type: String,
    default: 'unknown',
  },
  userAgent: {
    type: String,
    default: '',
  },
  ipAddress: {
    type: String,
    default: '',
  },
}, {
  timestamps: true,
});

/**
 * Create token hash from plain token
 */
RefreshTokenSchema.statics.hashToken = function(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
};

/**
 * Find token by hash
 */
RefreshTokenSchema.statics.findByToken = async function(token) {
  const tokenHash = this.hashToken(token);
  return this.findOne({ tokenHash, revoked: false });
};

/**
 * Revoke token
 */
RefreshTokenSchema.methods.revoke = async function() {
  this.revoked = true;
  this.revokedAt = new Date();
  return this.save();
};

/**
 * Check if token is expired
 */
RefreshTokenSchema.methods.isExpired = function() {
  return this.expiresAt < new Date();
};

/**
 * Check if token is valid
 */
RefreshTokenSchema.methods.isValid = function() {
  return !this.revoked && !this.isExpired();
};

module.exports = model('RefreshToken', RefreshTokenSchema);

