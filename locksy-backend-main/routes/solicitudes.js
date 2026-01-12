/*
    Path: /api/solicitudes
*/
const { Router } = require('express');
const { validarJWT } = require('../middlewares/validar-jwt');
const { buscarSolicitudes } = require('../controllers/solicitudes');
const router = Router();

router.get('/:para', validarJWT, buscarSolicitudes);
module.exports = router;