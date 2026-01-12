const { Router } = require('express');
const { pruebaDeyner } = require('../controllers/pruebas');

const router = Router();

router.get('/pruebaDeyner', pruebaDeyner);

module.exports = router;