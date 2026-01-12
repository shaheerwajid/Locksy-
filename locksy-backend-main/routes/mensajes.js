/*
    Path: /api/mensajes
*/
const { Router } = require('express');
const { validarJWT } = require('../middlewares/validar-jwt');
const { obtenerChat, crearMensaje } = require('../controllers/mensajes');
const router = Router();

router.get('/:de', validarJWT, obtenerChat);
router.post('/', validarJWT, crearMensaje);

module.exports = router;