const { Router } = require("express");
const { validarJWT } = require("../middlewares/validar-jwt");

const {
  createContacto,
  getContactos,
  getListadoContactos,
  activateContacto,
  dropContacto,
  recoverPassword,
  updatContactDisappearTime,
  rejectCallHandler,
} = require("../controllers/contactos");

const router = Router();

router.post("/", validarJWT, createContacto);
router.post("/getContactos", validarJWT, getContactos);
router.post("/getListadoContactos", validarJWT, getListadoContactos);
router.post("/activateContacto", validarJWT, activateContacto);
router.post("/dropContacto", validarJWT, dropContacto);
router.post("/update-disappear-time", validarJWT, updatContactDisappearTime);
router.post("/reject-call", validarJWT, rejectCallHandler);

module.exports = router;
