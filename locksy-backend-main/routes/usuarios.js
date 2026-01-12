/*
    path: api/usuarios
*/
const { Router } = require("express");
const { validarJWT } = require("../middlewares/validar-jwt");

const {
  getUsuarios,
  getUsuario,
  recoveryPasswordS1,
  recoveryPasswordS2,
  validarPreguntas,
  updateUsuario,
  cambiarClave,
  report,
  getPagos,
  registrarPago,
  registrarPreguntas,
  blockUsers,
  unBlockUsers,
  registerEmailCheck,
  obtenerPublicKey,
  actualizarPublicKey,
  actualizarKeys,
  registerFCMToken,
} = require("../controllers/usuarios");
var multer = require("multer");
const fileStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "./uploads");
  },

  filename: (req, file, cb) => {
    cb(
      null,
      `${new Date().getTime()}-${String(file.originalname).replaceAll(
        " ",
        "-"
      )}`
    );
  },
});

const upload = multer({ storage: fileStorage });

const router = Router();

// Define a route to handle file upload
router.post("/upload", upload.array("files"), (req, res) => {
  let resp = [];
  const fullUrl = `${req.protocol}://${req.get("host")}`;

  if (req.files.length) {
    resp = req.files.reduce((a, b) => {
      a = [...a, { path: `${fullUrl}/${b.path}` }];
      return a;
    }, []);
  }

  return res.json({
    data: resp,
    message: "Media Upload successfully",
  });
});

router.get("/", validarJWT, getUsuarios);

router.post("/getUsuario", validarJWT, getUsuario);
router.post("/recoveryPasswordS1", recoveryPasswordS1);
router.post("/updateUsuario", validarJWT, updateUsuario);
router.post("/register-fcm-token", validarJWT, registerFCMToken);
router.post("/add-to-block", validarJWT, blockUsers);
router.post("/unblock-user", validarJWT, unBlockUsers);

router.get("/recoverPassword", recoveryPasswordS2);
router.post("/recoverPassword2", validarPreguntas);
router.post("/cambiarClave", cambiarClave);

router.post("/registrarPreguntas", registrarPreguntas);
router.post("/registrarPago", registrarPago);
router.post("/getPagos", getPagos);

router.post("/report", report);
router.post("/email-check", registerEmailCheck);

// New routes for public key management
router.get("/:id/public-key", validarJWT, obtenerPublicKey);
router.post("/me/public-key", validarJWT, actualizarPublicKey);
router.post("/me/keys", validarJWT, actualizarKeys);

module.exports = router;
