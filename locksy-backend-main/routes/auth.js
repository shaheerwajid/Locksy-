/*
    path: api/login
*/
const { Router } = require("express");
const { check } = require("express-validator");

const {
  crearUsuario,
  login,
  renewToken,
  refreshToken,
  logout,
  forgotPassword,
  verifyResetOTP,
  resetPassword,
} = require("../controllers/auth");
const { validarCampos } = require("../middlewares/validar-campos");
const { validarJWT } = require("../middlewares/validar-jwt");

const router = Router();

// Registration route (without OTP)
router.post(
  "/new",
  [
    check("nombre", "El nombre es necesario").not().isEmpty(),
    check("password", "La contraseña es necesario").not().isEmpty(),
    check("email", "El correo es necesario").isEmail(),
    validarCampos,
  ],
  crearUsuario
);

// Login route - handle root path
// When router is mounted at /login, this matches /api/login
router.post(
  "/",
  [
    check("password", "La contraseña es obligatoria").not().isEmpty(),
    check("email", "El correo es obligatorio").isEmail(),
    validarCampos,
  ],
  login
);

router.get("/renew", validarJWT, renewToken);

// New routes for refresh tokens
router.post("/refresh", refreshToken);
router.post("/logout", validarJWT, logout);

// Password reset routes
router.post(
  "/forgot-password",
  [
    check("email", "El correo es necesario").isEmail(),
    validarCampos,
  ],
  forgotPassword
);

router.post(
  "/verify-reset-otp",
  [
    check("email", "El correo es necesario").isEmail(),
    check("otpCode", "El código OTP es necesario").not().isEmpty(),
    validarCampos,
  ],
  verifyResetOTP
);

router.post(
  "/reset-password",
  [
    check("email", "El correo es necesario").isEmail(),
    check("newPassword", "La nueva contraseña es necesaria").not().isEmpty(),
    check("otpCode", "El código OTP es necesario").not().isEmpty(),
    validarCampos,
  ],
  resetPassword
);

module.exports = router;
