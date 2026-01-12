const { response } = require("express");
const bcrypt = require("bcryptjs");

const Usuario = require("../models/usuario");
const {
  generateAccessToken,
  generateRefreshToken,
  refreshAccessToken,
  revokeRefreshToken,
  revokeAllRefreshTokens,
  revokeDeviceRefreshTokens,
  REFRESH_TOKEN_COOKIE_AGE
} = require("../helpers/tokens");
const { isValidPublicKey } = require("../helpers/cryptoServer");
const { encryptPrivateKey, decryptPrivateKey } = require("../helpers/keyEncryption");
const { generateOTP, getOTPExpiration, isOTPExpired } = require("../helpers/otp");
const { sendOTPEmail, sendPasswordResetOTPEmail } = require("../services/email/otpEmail");

function generateNum(min, max) {
  return Math.floor(Math.random() * (max - min + 1) + min);
}

function generateStr() {
  var letras = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  var cant = letras.length;
  var rng = generateNum(0, letras.length - 1);
  return letras.substring(rng, rng + 1);
}

function generateCode() {
  var codigo = "";

  for (let i = 0; i < 5; i++) {
    var str = generateStr();
    var num = generateNum(0, 9);
    // while (codigo.includes(str)) {
    //     str = generateStr();
    // }
    // while (codigo.includes(num)) {
    //     num = generateNum(0, 9);
    // }
    codigo += str + num;
  }
  // res.send(codigo);
  return codigo;
}

const crearUsuario = async (req, res = response) => {
  const { email, password, publicKey, privateKey, deviceId } = req.body;
  try {
    // Check if email exists
    const existeEmail = await Usuario.findOne({ email });

    if (existeEmail) {
      // Check if user already has password (already registered)
      if (existeEmail.password) {
        return res.status(400).json({
          ok: false,
          msg: "ERR101", // Email already registered
        });
      }

      // User exists but has no password (incomplete previous attempt or similar)
      // We will update this user
    }

    // Validate password is provided
    if (!password || password.trim() === '') {
      return res.status(400).json({
        ok: false,
        msg: "Password is required",
      });
    }

    let usuario;

    if (existeEmail) {
      // Update existing user
      usuario = existeEmail;
      usuario.nombre = req.body.nombre || usuario.nombre;
    } else {
      // Create new user
      usuario = new Usuario(req.body);
    }

    // Validate and store public key if provided
    if (publicKey) {
      if (!isValidPublicKey(publicKey)) {
        return res.status(400).json({
          ok: false,
          msg: "Invalid public key format",
        });
      }
      usuario.publicKey = publicKey;
    }

    // Encrypt and store private key if provided (password-encrypted storage)
    if (privateKey) {
      try {
        // Encrypt private key with password-derived key
        const encryptedPrivateKey = encryptPrivateKey(privateKey, password);
        usuario.encryptedPrivateKey = encryptedPrivateKey;
        console.log('[Auth] Private key encrypted and stored for user:', email);
      } catch (error) {
        console.error('[Auth] Error encrypting private key:', error);
        return res.status(500).json({
          ok: false,
          msg: "Error encrypting private key",
        });
      }
    }

    // Encriptar contraseña
    const salt = bcrypt.genSaltSync();
    usuario.password = bcrypt.hashSync(password, salt);
    usuario.avatar = "ninja.png";
    usuario.nuevo = "true";
    usuario.emailVerified = true; // Auto-verify email since we removed OTP

    var codigo = generateCode();
    var existeCodigo = true;

    while (existeCodigo) {
      codigo = generateCode();
      usuario.codigoContacto = codigo;
      existeCodigo = await Usuario.findOne({ codigo });
    }

    await usuario.save();

    // Generate tokens
    const accessToken = await generateAccessToken(usuario.id);
    const deviceIdFinal = deviceId || req.headers['x-device-id'] || 'unknown';
    const userAgent = req.headers['user-agent'] || '';
    const ipAddress = req.ip || req.connection.remoteAddress || '';

    const { refreshToken, expiresAt } = await generateRefreshToken(
      usuario.id,
      deviceIdFinal,
      userAgent,
      ipAddress
    );

    // Set refresh token as HttpOnly Secure cookie
    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: REFRESH_TOKEN_COOKIE_AGE,
    });

    res.json({
      ok: true,
      usuario: {
        ...usuario.toJSON(),
        publicKey: usuario.publicKey,
        // Note: privateKey is sent back during registration since frontend just generated it
        // For subsequent logins, privateKey will be decrypted and sent
        privateKey: privateKey || null, // Send back the privateKey if provided (frontend already has it)
      },
      accessToken,
      expiresIn: process.env.ACCESS_TOKEN_EXPIRY || '15m',
    });
  } catch (error) {
    console.error('Create user error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({
      ok: false,
      msg: "ERR102",
    });
  }
};

const login = async (req, res = response) => {
  const { email, password, deviceId, fcmToken } = req.body;
  try {
    // Find user and explicitly select encryptedPrivateKey (it's excluded by default)
    const usuarioDB = await Usuario.findOne({ email })
      .select('+encryptedPrivateKey')
      .populate("blockUsers", "-password -blockUsers");

    if (!usuarioDB) {
      return res.status(404).json({
        ok: false,
        msg: "Email no encontrado",
      });
    }

    // Validar el password
    const validPassword = bcrypt.compareSync(password, usuarioDB.password);
    if (!validPassword) {
      return res.status(400).json({
        ok: false,
        msg: "La contraseña no es valida",
      });
    }

    // Decrypt private key if it exists
    let decryptedPrivateKey = null;
    if (usuarioDB.encryptedPrivateKey) {
      try {
        decryptedPrivateKey = decryptPrivateKey(usuarioDB.encryptedPrivateKey, password);
        console.log('[Auth] ✅ Private key decrypted successfully for user:', email);
      } catch (error) {
        console.error('[Auth] ❌ Error decrypting private key:', error);
        console.error('[Auth] Error details:', error.message);
        // Don't fail login if decryption fails - user might need to regenerate keys
        // But log the error for debugging
        decryptedPrivateKey = null;
      }
    } else {
      console.log('[Auth] ⚠️ User does not have encryptedPrivateKey in database:', email);
      console.log('[Auth] This is likely an old account created before password-encrypted key storage was implemented.');
      console.log('[Auth] User will need to regenerate keys or use existing keys from secure storage.');
    }

    // Generate tokens
    const accessToken = await generateAccessToken(usuarioDB.id);
    const deviceIdFinal = deviceId || req.headers['x-device-id'] || 'unknown';
    const userAgent = req.headers['user-agent'] || '';
    const ipAddress = req.ip || req.connection.remoteAddress || '';

    const { refreshToken, expiresAt } = await generateRefreshToken(
      usuarioDB.id,
      deviceIdFinal,
      userAgent,
      ipAddress
    );

    // Save FCM token if provided
    if (fcmToken && fcmToken.trim() !== '') {
      usuarioDB.firebaseid = fcmToken.trim();
      await usuarioDB.save();
      console.log('[Auth] FCM token saved for user:', email);
    }

    // Set refresh token as HttpOnly Secure cookie
    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: REFRESH_TOKEN_COOKIE_AGE,
    });

    // Prepare response usuario object
    // Include decrypted privateKey if available
    const responseUsuario = {
      ...usuarioDB.toJSON(),
      publicKey: usuarioDB.publicKey,
      privateKey: decryptedPrivateKey, // Send decrypted private key to device (null if not available)
    };

    // Log privateKey status for debugging
    if (decryptedPrivateKey) {
      console.log('[Auth] ✅ Sending decrypted privateKey to client (length:', decryptedPrivateKey.length, ')');
    } else {
      console.log('[Auth] ⚠️ NOT sending privateKey - user does not have encryptedPrivateKey or decryption failed');
      console.log('[Auth] User email:', email);
      console.log('[Auth] Has encryptedPrivateKey:', !!usuarioDB.encryptedPrivateKey);
    }

    res.json({
      ok: true,
      usuario: responseUsuario,
      accessToken,
      expiresIn: process.env.ACCESS_TOKEN_EXPIRY || '15m',
    });
  } catch (error) {
    console.error('Login error:', error);
    console.error('Error stack:', error.stack);
    console.error('Error message:', error.message);
    console.error('Error name:', error.name);
    // Return more detailed error in development
    const errorMessage = process.env.NODE_ENV === 'production'
      ? "ERR102"
      : `ERR102: ${error.message || error.toString()}`;
    return res.status(500).json({
      ok: false,
      msg: errorMessage,
      error: process.env.NODE_ENV !== 'production' ? {
        message: error.message,
        name: error.name,
        stack: error.stack
      } : undefined
    });
  }
};

const renewToken = async (req, res = response) => {
  try {
    const uid = req.uid;
    // Generate new access token (keep existing refresh token)
    const accessToken = await generateAccessToken(uid);
    const usuario = await Usuario.findById(uid).populate(
      "blockUsers",
      "-password -blockUsers"
    );

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: "Usuario no encontrado"
      });
    }

    res.json({
      ok: true,
      usuario: {
        ...usuario.toJSON(),
        publicKey: usuario.publicKey,
      },
      accessToken,
      expiresIn: process.env.ACCESS_TOKEN_EXPIRY || '15m',
    });
  } catch (error) {
    console.error('Error renewing token:', error);
    return res.status(500).json({
      ok: false,
      msg: "Error al renovar token"
    });
  }
};

// Keep pruebaDeyner for backward compatibility if it exists
const pruebaDeyner = async (req, res = response) => {
  res.json({
    ok: true,
    msg: "Test endpoint",
  });
};

// New endpoint: Refresh access token using refresh token
const refreshToken = async (req, res = response) => {
  try {
    // Get refresh token from cookie or body
    const refreshToken = req.cookies?.refreshToken || req.body?.refreshToken;

    if (!refreshToken) {
      return res.status(400).json({
        ok: false,
        msg: "Refresh token es requerido",
      });
    }

    const deviceId = req.body?.deviceId || req.headers['x-device-id'] || 'unknown';
    const userAgent = req.headers['user-agent'] || '';
    const ipAddress = req.ip || req.connection.remoteAddress || '';

    const result = await refreshAccessToken(refreshToken, deviceId, userAgent, ipAddress);

    if (!result.valid) {
      // Clear invalid cookie
      res.clearCookie('refreshToken');
      return res.status(401).json({
        ok: false,
        msg: "Refresh token inválido",
      });
    }

    // Get user data
    const usuario = await Usuario.findById(result.uid).populate(
      "blockUsers",
      "-password -blockUsers"
    );

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: "Usuario no encontrado",
      });
    }

    // Set new refresh token cookie (rotated)
    res.cookie('refreshToken', result.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: result.cookieAge,
    });

    res.json({
      ok: true,
      usuario: {
        ...usuario.toJSON(),
        publicKey: usuario.publicKey,
      },
      accessToken: result.accessToken,
      expiresIn: process.env.ACCESS_TOKEN_EXPIRY || '15m',
    });
  } catch (error) {
    console.error('Error refreshing token:', error);
    return res.status(500).json({
      ok: false,
      msg: "Error al refrescar token",
    });
  }
};

// New endpoint: Logout (revoke refresh tokens)
const logout = async (req, res = response) => {
  const refreshToken = req.cookies?.refreshToken || req.body?.refreshToken;
  const { deviceId, revokeAll } = req.body;

  try {
    if (revokeAll) {
      // Revoke all tokens for user
      const uid = req.uid;
      await revokeAllRefreshTokens(uid);
    } else if (deviceId) {
      // Revoke tokens for specific device
      const uid = req.uid;
      await revokeDeviceRefreshTokens(uid, deviceId);
    } else if (refreshToken) {
      // Revoke specific token
      await revokeRefreshToken(refreshToken);
    }

    // Clear cookie
    res.clearCookie('refreshToken');

    res.json({
      ok: true,
      msg: "Sesión cerrada exitosamente",
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      ok: false,
      msg: "Error al cerrar sesión",
    });
  }
};

/**
 * Forgot Password - Send OTP for password reset
 * Only works for registered users (users with passwords)
 */
const forgotPassword = async (req, res = response) => {
  const { email } = req.body;

  try {
    // Find user - must be a registered user (has password)
    const usuario = await Usuario.findOne({ email })
      .select('+password +resetOtpCode +resetOtpExpiresAt +resetOtpAttempts');

    if (!usuario) {
      // Don't reveal if email exists for security
      return res.json({
        ok: true,
        msg: "If the email exists, an OTP has been sent",
      });
    }

    // Check if user is registered (has password)
    if (!usuario.password) {
      // User exists but not registered - don't reveal this
      return res.json({
        ok: true,
        msg: "If the email exists, an OTP has been sent",
      });
    }

    // Generate reset OTP
    const resetOtpCode = generateOTP();
    const resetOtpExpiresAt = getOTPExpiration();

    // Update user with reset OTP
    usuario.resetOtpCode = resetOtpCode;
    usuario.resetOtpExpiresAt = resetOtpExpiresAt;
    usuario.resetOtpAttempts = 0;
    usuario.resetOtpVerified = false; // Reset verification status
    await usuario.save();

    // Send reset OTP email
    try {
      await sendPasswordResetOTPEmail(email, usuario.nombre, resetOtpCode);
      console.log(`[Password Reset] OTP sent to ${email}`);
    } catch (emailError) {
      console.error('[Password Reset] Error sending email:', emailError);
      // Still return success - OTP is stored in DB, user can request resend
    }

    res.json({
      ok: true,
      msg: "If the email exists, an OTP has been sent",
      expiresIn: 15, // minutes
    });
  } catch (error) {
    console.error('Forgot password error:', error);
    res.status(500).json({
      ok: false,
      msg: "ERR102",
    });
  }
};

/**
 * Verify Password Reset OTP
 */
const verifyResetOTP = async (req, res = response) => {
  const { email, otpCode } = req.body;

  try {
    const usuario = await Usuario.findOne({ email })
      .select('+password +resetOtpCode +resetOtpExpiresAt +resetOtpAttempts +resetOtpVerified');

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: "ERR103", // Email not found
      });
    }

    // Check if user is registered
    if (!usuario.password) {
      return res.status(400).json({
        ok: false,
        msg: "User is not registered",
      });
    }

    // Check if OTP exists
    if (!usuario.resetOtpCode) {
      return res.status(400).json({
        ok: false,
        msg: "ERR109", // No reset OTP requested
      });
    }

    // Check if OTP is expired
    if (isOTPExpired(usuario.resetOtpExpiresAt)) {
      return res.status(400).json({
        ok: false,
        msg: "ERR105", // OTP expired
      });
    }

    // Check attempts
    if (usuario.resetOtpAttempts >= 5) {
      return res.status(400).json({
        ok: false,
        msg: "ERR106", // Too many attempts
      });
    }

    // Verify OTP
    if (!usuario.resetOtpCode || usuario.resetOtpCode !== otpCode) {
      usuario.resetOtpAttempts = (usuario.resetOtpAttempts || 0) + 1;
      await usuario.save();

      const attemptsRemaining = 5 - usuario.resetOtpAttempts;
      return res.status(400).json({
        ok: false,
        msg: "ERR107", // Invalid OTP
        attemptsRemaining: attemptsRemaining > 0 ? attemptsRemaining : 0,
      });
    }

    // OTP is valid - mark as verified
    usuario.resetOtpVerified = true;
    // Don't clear OTP yet - will be cleared after password reset
    await usuario.save();

    res.json({
      ok: true,
      msg: "Reset OTP verified successfully",
    });
  } catch (error) {
    console.error('Verify reset OTP error:', error);
    res.status(500).json({
      ok: false,
      msg: "ERR102",
    });
  }
};

/**
 * Reset Password - After OTP verification
 */
const resetPassword = async (req, res = response) => {
  const { email, newPassword, otpCode } = req.body;

  try {
    // Find user
    const usuario = await Usuario.findOne({ email })
      .select('+password +resetOtpCode +resetOtpExpiresAt +resetOtpAttempts +resetOtpVerified');

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: "ERR103", // Email not found
      });
    }

    // Check if user is registered
    if (!usuario.password) {
      return res.status(400).json({
        ok: false,
        msg: "User is not registered",
      });
    }

    // Validate new password
    if (!newPassword || newPassword.trim() === '') {
      return res.status(400).json({
        ok: false,
        msg: "New password is required",
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        ok: false,
        msg: "Password must be at least 6 characters",
      });
    }

    // Verify OTP again (double check)
    if (!usuario.resetOtpCode) {
      return res.status(400).json({
        ok: false,
        msg: "ERR109", // No reset OTP requested
      });
    }

    if (isOTPExpired(usuario.resetOtpExpiresAt)) {
      return res.status(400).json({
        ok: false,
        msg: "ERR105", // OTP expired
      });
    }

    if (usuario.resetOtpCode !== otpCode) {
      return res.status(400).json({
        ok: false,
        msg: "ERR107", // Invalid OTP
      });
    }

    // Check if OTP was verified
    if (!usuario.resetOtpVerified) {
      return res.status(400).json({
        ok: false,
        msg: "OTP must be verified first",
      });
    }

    // Reset password
    const salt = bcrypt.genSaltSync();
    usuario.password = bcrypt.hashSync(newPassword, salt);

    // If user has encrypted private key, we need to re-encrypt it with new password
    // Note: This requires the old password to decrypt, which we don't have
    // So we'll clear the encrypted private key - user will need to regenerate keys
    if (usuario.encryptedPrivateKey) {
      console.log('[Password Reset] Clearing encrypted private key - user will need to regenerate keys');
      usuario.encryptedPrivateKey = undefined;
    }

    // Clear reset OTP fields
    usuario.resetOtpCode = undefined;
    usuario.resetOtpExpiresAt = undefined;
    usuario.resetOtpAttempts = 0;
    usuario.resetOtpVerified = false;

    await usuario.save();

    // Revoke all refresh tokens for security
    try {
      await revokeAllRefreshTokens(usuario.id);
      console.log('[Password Reset] All refresh tokens revoked for user:', email);
    } catch (tokenError) {
      console.error('[Password Reset] Error revoking tokens:', tokenError);
      // Continue anyway - password is reset
    }

    res.json({
      ok: true,
      msg: "Password reset successfully",
    });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({
      ok: false,
      msg: "ERR102",
    });
  }
};

module.exports = {
  crearUsuario,
  login,
  renewToken,
  refreshToken,
  logout,
  sendOTP,
  verifyOTP,
  forgotPassword,
  verifyResetOTP,
  resetPassword,
};
