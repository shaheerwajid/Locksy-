const { Schema, model } = require("mongoose");

const UsuarioSchema = Schema({
  codigoContacto: {
    type: String,
    required: false,
    default: "",
  },
  nuevo: {
    type: String,
  },
  nombre: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
  },
  password: {
    type: String,
    required: false, // Optional - will be set during registration after OTP verification
  },
  lastSeen: {
    type: Date,
    default: () => new Date(),
  },
  online: {
    type: Boolean,
    default: false,
  },
  firebaseid: {
    type: String,
  },
  // Password-encrypted private key storage
  // Private key is encrypted with a key derived from the user's password
  // This allows the key to be securely stored and retrieved across devices
  encryptedPrivateKey: {
    type: String,
    required: false, // Optional - may not exist for older users
    select: false, // Don't include in default queries (security)
  },
  publicKey: {
    type: String,
    required: false, // Optional - user may not have set up encryption yet
    validate: {
      validator: function(v) {
        if (!v) return true; // Allow empty/null
        // Validate public key format using crypto helper
        try {
          const { isValidPublicKey } = require('../helpers/cryptoServer');
          return isValidPublicKey(v);
        } catch (error) {
          return false;
        }
      },
      message: 'Invalid RSA public key format'
    }
  },
  avatar: {
    type: String,
    default: "",
  },
  blockUsers: [
    {
      type: Schema.Types.ObjectId,
      ref: 'Usuario', // Reference to the User model
    }
  ],
  // OTP Verification fields
  emailVerified: {
    type: Boolean,
    default: false,
  },
  otpCode: {
    type: String,
    required: false,
    select: false, // Don't include in default queries (security)
  },
  otpExpiresAt: {
    type: Date,
    required: false,
  },
  otpAttempts: {
    type: Number,
    default: 0,
  },
  // Password Reset OTP fields (separate from registration OTP)
  resetOtpCode: {
    type: String,
    required: false,
    select: false, // Don't include in default queries (security)
  },
  resetOtpExpiresAt: {
    type: Date,
    required: false,
  },
  resetOtpAttempts: {
    type: Number,
    default: 0,
  },
  resetOtpVerified: {
    type: Boolean,
    default: false,
  }
});

UsuarioSchema.method("toJSON", function () {
  const { __v, _id, password, encryptedPrivateKey, otpCode, resetOtpCode, ...object } = this.toObject();
  object.uid = _id;
  // Ensure privateKey, encryptedPrivateKey, and OTP codes are never exposed
  delete object.privateKey;
  delete object.encryptedPrivateKey;
  delete object.otpCode;
  delete object.resetOtpCode;
  return object;
});

module.exports = model("Usuario", UsuarioSchema);
