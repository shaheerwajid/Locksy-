const { Router } = require('express');
const { validarJWT } = require('../middlewares/validar-jwt');
const { uploadFiles, getavatars, getgruposimg, subirArchivos, getFile } = require('../controllers/uploads');
var multer = require('multer');
var upload = multer({ dest: 'uploads/' });

const router = Router();

router.post('/upload-file', validarJWT, uploadFiles);
router.get('/getavatars', validarJWT, getavatars);
router.get('/getgruposimg', validarJWT, getgruposimg);

router.post('/subirArchivos', validarJWT, upload.any(), subirArchivos);
router.get('/getFile', getFile);

module.exports = router;